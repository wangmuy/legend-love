-- tools/midiinfo.lua — 纯 Lua MIDI 探针（时长 / 格式 / 音色程序 / 音符数）
--
-- 为什么需要：原版音乐的门禁要断言「OGG 时长应当贴近 MIDI 母带长度」，
-- 而系统里不一定有 ffprobe/timidity，也不能指望 Python。MIDI 时长完全
-- 可以由 tempo map 精确算出来，纯 Lua 就够。
--
-- 解析要点（RFC 格式）：
--   * 头块 MThd: format(u16) ntrks(u16) division(u16)
--   * 轨块 MTrk: 变长 VLQ delta-time + 事件
--   * 时长 = Σ 每段 delta_tick × (当前 us/quarter ÷ division)
--     其中 us/quarter 由 FF 51 03 tempo 事件更新（默认 500000 = 120 BPM）
--
-- 用法:
--   lua tools/midiinfo.lua game/sound/game01.mid [更多文件...]
--   lua tools/midiinfo.lua --duration game/sound/game01.mid   # 只打印秒数
--   lua tools/midiinfo.lua --json game/sound/*.mid
--
-- 注意：故意**不**用 Lua 5.3 的位运算语法，保证 5.1 能跑。

local M = {}

local function readU16(s, i)
    local a, b = s:byte(i, i + 1)
    if not a or not b then return nil end
    return a * 256 + b
end

local function readU32(s, i)
    local a, b, c, d = s:byte(i, i + 3)
    if not a then return nil end
    return ((a * 256 + b) * 256 + c) * 256 + d
end

-- 变长整数：每字节 7 位有效，最高位为 1 表示还有后续
local function readVLQ(s, i)
    local v = 0
    while true do
        local c = s:byte(i)
        if not c then return nil, i end
        i = i + 1
        v = v * 128 + (c % 128)
        if c < 128 then return v, i end
    end
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil, "无法打开" end
    local s = f:read("*a")
    f:close()
    return s
end

-- 返回 table 或 nil, err
function M.parse(path)
    local s, err = readFile(path)
    if not s then return nil, err end
    if #s < 14 or s:sub(1, 4) ~= "MThd" then return nil, "不是 MIDI（缺 MThd）" end

    local hlen = readU32(s, 5)
    if not hlen or hlen < 6 then return nil, "头块长度异常" end
    local fmt = readU16(s, 9)
    local ntrk = readU16(s, 11)
    local div = readU16(s, 13)
    if not fmt or not ntrk or not div then return nil, "头块字段不全" end
    if div == 0 then return nil, "division=0 无法换算时长" end

    -- 非整数 division 表示 SMPTE 时间码格式（高字节为负），时长算法不同；
    -- 本项目的曲目都是 97/120 这类节拍型 division，遇到 SMPTE 直接报错更安全。
    if div >= 0x8000 then return nil, "SMPTE 时间码 division 未支持" end

    local i = 8 + hlen
    local lastTick = 0
    local tempos = {}      -- { {tick=, us=}, ... }
    local programs = {}    -- set
    local notes = 0

    while i + 8 <= #s do
        local cid = s:sub(i, i + 3)
        if cid ~= "MTrk" then i = i + 1
        else
            local tlen = readU32(s, i + 4)
            if not tlen then break end
            i = i + 8
            local stop = i + tlen - 1
            if stop > #s then stop = #s end
            local tick = 0
            local running = nil
            while i <= stop do
                local dt
                dt, i = readVLQ(s, i)
                if not dt then break end
                tick = tick + dt
                local st = s:byte(i)
                if not st then break end
                if st >= 0x80 then
                    i = i + 1
                    if st < 0xF0 then running = st else running = nil end
                elseif running then
                    st = running
                else
                    i = i + 1
                    dt = nil
                end

                if dt then
                    local hi = math.floor(st / 16)
                    if st == 0xFF then
                        local mt = s:byte(i)
                        i = i + 1
                        local ln
                        ln, i = readVLQ(s, i)
                        if not ln then break end
                        if mt == 0x51 and ln == 3 then
                            local a, b, c = s:byte(i, i + 2)
                            if a then
                                tempos[#tempos + 1] = { tick = tick, us = (a * 256 + b) * 256 + c }
                            end
                        elseif mt == 0x2F then
                            break
                        end
                        i = i + ln
                    elseif st == 0xF0 or st == 0xF7 then
                        local ln
                        ln, i = readVLQ(s, i)
                        if not ln then break end
                        i = i + ln
                    elseif hi == 8 or hi == 9 or hi == 10 or hi == 11 or hi == 14 then
                        -- 0x90 且力度 > 0 才是 note-on（力度 0 是 note-off）
                        if hi == 9 then
                            local note, vel = s:byte(i, i + 1)
                            if note and vel and vel > 0 then notes = notes + 1 end
                        end
                        i = i + 2
                    elseif hi == 12 or hi == 13 then
                        if hi == 12 then
                            local prog = s:byte(i)
                            if prog then programs[prog] = true end
                        end
                        i = i + 1
                    else
                        i = i + 1
                    end
                end
            end
            if tick > lastTick then lastTick = tick end
            i = stop + 1
        end
    end

    table.sort(tempos, function(a, b) return a.tick < b.tick end)

    -- tempo map 积分出秒数
    local seconds = 0
    local at = 0
    local usPerQ = 500000           -- 默认 120 BPM
    for _, t in ipairs(tempos) do
        seconds = seconds + (t.tick - at) * (usPerQ / 1000000) / div
        at = t.tick
        usPerQ = t.us
    end
    seconds = seconds + (lastTick - at) * (usPerQ / 1000000) / div

    local progList = {}
    for p in pairs(programs) do progList[#progList + 1] = p end
    table.sort(progList)

    return {
        path = path,
        format = fmt,
        tracks = ntrk,
        division = div,
        ticks = lastTick,
        duration = seconds,
        programs = progList,
        notes = notes,
        tempoEvents = #tempos,
    }
end

-- ---------------- CLI ----------------
local args = { ... }
if #args > 0 then
    local mode = "table"
    local files = {}
    for _, a in ipairs(args) do
        if a == "--duration" then mode = "duration"
        elseif a == "--json" then mode = "json"
        elseif a == "--help" or a == "-h" then mode = "help"
        else files[#files + 1] = a end
    end

    if mode == "help" then
        print("用法: lua tools/midiinfo.lua [--duration|--json] <file.mid>...")
    elseif mode == "duration" then
        for _, f in ipairs(files) do
            local info, err = M.parse(f)
            if not info then
                io.stderr:write(string.format("%s: %s\n", f, tostring(err)))
                os.exit(1)
            end
            print(string.format("%.3f", info.duration))
        end
    else
        local first = true
        if mode == "json" then io.write("[\n") end
        for _, f in ipairs(files) do
            local info, err = M.parse(f)
            if not info then
                io.stderr:write(string.format("%s: %s\n", f, tostring(err)))
                os.exit(1)
            end
            if mode == "json" then
                if not first then io.write(",\n") end
                first = false
                io.write(string.format(
                    '  {"path":"%s","format":%d,"tracks":%d,"division":%d,"ticks":%d,"duration":%.4f,"notes":%d,"programs":[%s]}',
                    f, info.format, info.tracks, info.division, info.ticks,
                    info.duration, info.notes,
                    table.concat(info.programs, ",")))
            else
                print(string.format("%-34s fmt=%d trk=%2d div=%3d ticks=%6d dur=%7.2fs notes=%5d programs=%s",
                    f, info.format, info.tracks, info.division, info.ticks,
                    info.duration, info.notes,
                    "[" .. table.concat(info.programs, ",") .. "]"))
            end
        end
        if mode == "json" then io.write("\n]\n") end
    end
end

return M
