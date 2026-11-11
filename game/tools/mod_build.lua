-- tools/mod_build.lua
-- Build-time extractor for allmods-compat MODs (Contract C).
--
-- Usage:  lua tools/mod_build.lua <kys-<mod>>   (run from game/)
--
-- Produces, under game/mods/<mod>/:
--   data/                     resource/fight/save flattened (lowercased), + kysmod.ini
--   script/oldevent/oldevent_0..n-1.lua   extracted from kdef.grp (no fishedit text dep)
--   script/old_talk.lua       decoded from talk.grp
--   diff.md                   data-diff report vs game/data/
--
-- REQ-BUILD-1..5.

local BUILD = {}

-- 跨平台文件系统原语（Windows 上 io.popen 走 cmd.exe，POSIX 命令不可用）
local Fs = require("framework.fs_compat")

-- ---------------------------------------------------------------------------
-- paths / io helpers
-- ---------------------------------------------------------------------------

-- repo root = parent of game/ (this file lives at game/tools/mod_build.lua)
local function scriptDir()
    local info = debug.getinfo(1, "S").source:sub(2)
    return info:match("^(.*)[/\\][^/\\]*$") or "."
end

local GAME_DIR = scriptDir() .. "/.."
local REPO_DIR = GAME_DIR .. "/.."
local REF_DIR = REPO_DIR .. "/reference/allmods"


local function join(...)
    local parts = { ... }
    return table.concat(parts, "/")
end

local function readFile(path)
    -- 走 fs_compat：MOD 源里有中文文件名（如 "ranger - 副本.idx"），
    -- Windows 上 io.open 打不开这类 UTF-8 路径，会导致文件被静默跳过。
    return Fs.readFile(path)
end

-- ---------------------------------------------------------------------------
-- games.ini (launcher manifest)
--
-- UTF-8 with BOM. Format:
--   [games]
--   0 = <label>: kys-<mod>
--   ...
--   current =0
-- Some labels carry a human "problem" annotation, e.g.
--   "天书劫（好像有问题）" / "问情篇（好像不太正常）" /
--   "金庸水浒传dos版（不可能正常）" / "真龙苏醒（不确定正不正常）"
-- Those MODs must exit non-zero with an explanatory stderr message (REQ-BUILD-4).
-- ---------------------------------------------------------------------------

local PROBLEM_MARKERS = { "有问题", "正常" }

-- Parse games.ini into an ordered list of { index=, label=, mod=, problem= }.
local function parseGamesIni()
    local raw = readFile(REF_DIR .. "/games.ini")
    if not raw then return {} end
    raw = raw:gsub("^\239\187\191", "")  -- strip UTF-8 BOM
    local games = {}
    for line in raw:gmatch("[^\r\n]+") do
        local idx, label, mod = line:match("^%s*(%d+)%s*=%s*(.-)%s*:%s*(kys[%w_%-]+)%s*$")
        if idx then
            local problem = nil
            for _, m in ipairs(PROBLEM_MARKERS) do
                if label:find(m, 1, true) then problem = label; break end
            end
            games[#games + 1] = {
                index = tonumber(idx),
                label = label,
                mod = mod,
                problem = problem,
            }
        end
    end
    return games
end

function BUILD.ParseGamesIni() return parseGamesIni() end

local function writeFile(path, data)
    -- 走 fs_compat：产物里可能出现含中文的名字（MOD 源的
    -- "ranger - 副本.idx" 会被拍平到 data/），Windows 的 io.open 写不了。
    if not Fs.writeFile(path, data) then
        error("writeFile failed: " .. tostring(path))
    end
end

-- 4 字节小端 uint32（用于 oldtalk.idx 偏移表）
local function packU32(n)
    n = n % 4294967296
    local b1 = n % 256; n = math.floor(n / 256)
    local b2 = n % 256; n = math.floor(n / 256)
    local b3 = n % 256; n = math.floor(n / 256)
    local b4 = n % 256
    return string.char(b1, b2, b3, b4)
end

local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

-- 目录判定 / 列举 / 建删目录：统一走 fs_compat（Windows / Linux / macOS）。
-- 旧实现用 io.popen("ls ...") + os.execute("mkdir -p ...")，在 Windows 上
-- （cmd.exe）全部失效，导致构建链在 Windows 上直接不可用。
local function isDir(path)
    return Fs.directoryExists(path)
end

local function listDir(path)
    if not Fs.directoryExists(path) then return nil end
    return Fs.listDirectory(path)
end

local function mkdirp(path)
    Fs.makeDirectory(path)
end

-- Remove a build output directory so a rebuild never leaves stale files behind
-- (e.g. pre-alias sdx/smp or a removed sound/). Only paths under game/mods/ are
-- ever passed in.
local function rmdirp(path)
    Fs.removeTree(path)
end

local function fileSize(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local n = f:seek("end")
    f:close()
    return n
end

-- ---------------------------------------------------------------------------
-- binary readers
-- ---------------------------------------------------------------------------

local function u16le(data, off)  -- off is 1-based byte index
    local b1 = data:byte(off) or 0
    local b2 = data:byte(off + 1) or 0
    return b1 + b2 * 256
end

local function i16le(data, off)
    local n = u16le(data, off)
    if n > 32767 then n = n - 65536 end
    return n
end

local function u32le(data, off)
    local b1 = data:byte(off) or 0
    local b2 = data:byte(off + 1) or 0
    local b3 = data:byte(off + 2) or 0
    local b4 = data:byte(off + 3) or 0
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

-- Read a .idx offset array (4-byte LE uint32) and slice the .grp into entries.
-- Entry k spans [idx[k-1] (k==0 -> 0), idx[k]).
local function readIndexedEntries(idxPath, grpPath)
    local idx = readFile(idxPath)
    local grp = readFile(grpPath)
    if not idx or not grp then return nil end
    local offsets = {}
    for i = 1, #idx - 3, 4 do
        offsets[#offsets + 1] = u32le(idx, i)
    end
    local entries = {}
    for k = 1, #offsets do
        local startOff = (k == 1) and 0 or offsets[k - 1]
        local endOff = offsets[k]
        entries[k] = grp:sub(startOff + 1, endOff)  -- 1-based sub
    end
    return entries, offsets
end

-- ---------------------------------------------------------------------------
-- kdef arity table (verified against binary; NOT the Lua signatures)
-- opcodes 0..67
-- ---------------------------------------------------------------------------

local ARITY = {
    [0]=0,  [1]=3,  [2]=2,  [3]=13, [4]=3,  [5]=2,  [6]=4,  [7]=0,
    [8]=1,  [9]=2,  [10]=1, [11]=2, [12]=0, [13]=0, [14]=0, [15]=1,
    [16]=3, [17]=5, [18]=3, [19]=2, [20]=2, [21]=1, [22]=0, [23]=2,
    [24]=0, [25]=4, [26]=5, [27]=3, [28]=5, [29]=5, [30]=4, [31]=3,
    [32]=2, [33]=3, [34]=2, [35]=4, [36]=3, [37]=1, [38]=4, [39]=1,
    [40]=1, [41]=3, [42]=2, [43]=3, [44]=6, [45]=2, [46]=2, [47]=2,
    [48]=2, [49]=2, [50]=7, [51]=0, [52]=0, [53]=0, [54]=0, [55]=4,
    [56]=1, [57]=0, [58]=0, [59]=0, [60]=5, [61]=2, [62]=6, [63]=2,
    [64]=0, [65]=0, [66]=1, [67]=1,
}

-- Conditional (block-opening) opcodes. The LAST param decides direction:
--   last == 0 -> "==false" (是则跳转到)   last ~= 0 -> "==true" (否则跳转到)
local CONDITIONAL = {
    [4]=true,[5]=true,[6]=true,[9]=true,[11]=true,[16]=true,[18]=true,
    [20]=true,[28]=true,[29]=true,[31]=true,[36]=true,[42]=true,[43]=true,
    [50]=true,[55]=true,[60]=true,[61]=true,
}

-- Parse one kdef entry into a flat list of {op=, args={...}}.
local function parseKdefEntry(entry)
    local out = {}
    local n = #entry
    local i = 1  -- 1-based byte index
    while i + 1 <= n do
        local op = i16le(entry, i)
        if op == -1 then break end
        local ar = ARITY[op]
        if ar == nil then
            return nil, string.format("unknown opcode %d at byte %d", op, i - 1)
        end
        if i + 1 + ar * 2 - 1 > n then
            return nil, string.format("truncated opcode %d at byte %d", op, i - 1)
        end
        local args = {}
        for a = 1, ar do
            args[a] = i16le(entry, i + a * 2)
        end
        out[#out + 1] = { op = op, args = args }
        i = i + 2 + ar * 2
    end
    return out
end

-- ---------------------------------------------------------------------------
-- talk codec
--
-- Encoding (reverse-engineered from 6 MODs with talkutf8.txt ground truth):
--   * each CJK char: 2 bytes = bitwise-NOT of its Big5 code (0xff - b1, 0xff - b2)
--   * 0xd5                -> '*'  (line break marker)
--   * single byte b whose 0xff-b is printable ASCII -> chr(0xff-b)
--   * rare explicit codes (0x0625..0x0628) -> 恒 墻 裏 銹
-- ---------------------------------------------------------------------------

local TALK_OVERRIDE = {
    ["0625"] = "恒",
    ["0626"] = "墻",
    ["0627"] = "裏",
    ["0628"] = "銹",
}

local function byteHex(b)
    return string.format("%02x", b)
end

-- Build a Big5 decoder table: big5 2-byte value -> UTF-8 char.
-- Lua 5.4 has utf8.char; we compute Big5 -> Unicode via a small table built at
-- runtime is impractical. Instead we rely on a static map generated from
-- tools/talk_big5.lua (committed). If unavailable, we emit '?' for CJK.
local BIG5 = nil
local function loadBig5()
    if BIG5 ~= nil then return BIG5 end
    BIG5 = false
    local ok, mod = pcall(dofile, GAME_DIR .. "/tools/talk_big5.lua")
    if ok and type(mod) == "table" then BIG5 = mod end
    return BIG5
end

local function decodeBig5Pair(b1, b2)
    local map = loadBig5()
    if not map then return nil end
    local v = b1 * 256 + b2
    return map[v]
end

-- Decode one talk entry (raw bytes, without trailing 0x00) into a UTF-8 string.
function BUILD.DecodeTalk(raw)
    local out = {}
    local i = 1
    local n = #raw
    while i <= n do
        local b = raw:byte(i)
        if b == 0xd5 then
            out[#out + 1] = "*"
            i = i + 1
        elseif i + 1 <= n then
            local key = byteHex(b) .. byteHex(raw:byte(i + 1))
            local ov = TALK_OVERRIDE[key]
            if ov then
                out[#out + 1] = ov
                i = i + 2
            else
                local ch = decodeBig5Pair(0xff - b, 0xff - raw:byte(i + 1))
                if ch then
                    out[#out + 1] = ch
                    i = i + 2
                else
                    local c = 0xff - b
                    if c >= 0x20 and c < 0x7f then
                        out[#out + 1] = string.char(c)
                        i = i + 1
                    else
                        out[#out + 1] = "?"
                        i = i + 2
                    end
                end
            end
        else
            local c = 0xff - b
            if c >= 0x20 and c < 0x7f then
                out[#out + 1] = string.char(c)
            else
                out[#out + 1] = "?"
            end
            i = i + 1
        end
    end
    return table.concat(out)
end

-- ---------------------------------------------------------------------------
-- lua emission helpers
-- ---------------------------------------------------------------------------

local function luaString(s)
    -- Use long-bracket form; guard against embedded ]] by using [==[ ]==].
    local eq = "=="
    while s:find("]" .. eq .. "]", 1, true) do eq = eq .. "=" end
    return "[" .. eq .. "[" .. s .. "]" .. eq .. "]"
end

local function fmtArgs(args)
    if #args == 0 then return "" end
    local parts = {}
    for i = 1, #args do parts[i] = tostring(args[i]) end
    return table.concat(parts, ",")
end

-- Note text generator. Comments may differ from the original extractor per DoD.
local NOTE = {
    [0]  = function() return "空语句(清屏)" end,
    [1]  = function(a) return string.format("说话: 对话编号%d", a[1]) end,
    [2]  = function(a) return string.format("得到物品[编号%d][%d]", a[1], a[2]) end,
    [3]  = function(a) return "修改事件定义:当前场景:场景事件编号" end,
    [4]  = function(a) return string.format("是否使用物品[编号%d]？", a[1]) end,
    [5]  = function() return "是否选择战斗？" end,
    [6]  = function(a) return string.format("战斗[%d]", a[1]) end,
    [7]  = function() return "块结束" end,
    [8]  = function() return "切换大地图音乐" end,
    [9]  = function() return "是否要求加入?" end,
    [10] = function(a) return string.format("加入人物[编号%d]", a[1]) end,
    [11] = function() return "是否住宿" end,
    [12] = function() return "住宿休息" end,
    [13] = function() return "重新显示场景" end,
    [14] = function() return "场景变黑" end,
    [15] = function() return "战斗失败，死亡" end,
    [16] = function(a) return string.format("队伍是否有[编号%d]", a[1]) end,
    [17] = function(a) return string.format("修改场景贴图:层%d坐标%d,%d", a[1], a[2], a[3]) end,
    [18] = function(a) return string.format("是否有物品[编号%d]", a[1]) end,
    [19] = function(a) return string.format("主角移动至%d,%d", a[1], a[2]) end,
    [20] = function() return "队伍是否满？" end,
    [21] = function(a) return string.format("[编号%d]离队", a[1]) end,
    [22] = function(a) return string.format("内力降为%d", a[1]) end,
    [23] = function(a) return string.format("设置人物[编号%d]用毒能力[%d]", a[1], a[2]) end,
    [24] = function() return "空指令24" end,
    [25] = function(a) return string.format("场景移动%d,%d-%d,%d", a[1], a[2], a[3], a[4]) end,
    [26] = function() return "增加场景事件编号的三个触发事件编号" end,
    [27] = function(a) return "显示动画" end,
    [28] = function(a) return string.format("判断WWW品德%d,%d", a[1], a[2]) end,
    [29] = function(a) return string.format("判断WWW武力%d,%d", a[1], a[2]) end,
    [30] = function(a) return string.format("主角走动%d,%d-%d,%d", a[1], a[2], a[3], a[4]) end,
    [31] = function(a) return string.format("判断银子是否够%d", a[1]) end,
    [32] = function(a) return string.format("物品[编号%d]+[%d]", a[1], a[2]) end,
    [33] = function(a) return string.format("人物%d学会武功%d", a[1], a[2]) end,
    [34] = function(a) return string.format("人物%d增加资质%d", a[1], a[2]) end,
    [35] = function(a) return string.format("设置人物%d武功%d攻击力%d", a[1], a[2], a[3]) end,
    [36] = function(a) return string.format("主角性别是否为%d", a[1]) end,
    [37] = function(a) return string.format("增加道德%d", a[1]) end,
    [38] = function() return "修改图层贴图" end,
    [39] = function(a) return string.format("打开场景%d", a[1]) end,
    [40] = function(a) return string.format("改变主角站立方向%d", a[1]) end,
    [41] = function(a) return string.format("人物%d得到物品%d", a[1], a[2]) end,
    [42] = function() return "队伍中是否有女性" end,
    [43] = function(a) return string.format("是否有物品%d", a[1]) end,
    [44] = function() return "显示动画" end,
    [45] = function(a) return string.format("人物%d增加轻功%d", a[1], a[2]) end,
    [46] = function(a) return string.format("人物%d增加内力%d", a[1], a[2]) end,
    [47] = function(a) return string.format("人物%d增加攻击力%d", a[1], a[2]) end,
    [48] = function(a) return string.format("人物%d增加生命%d", a[1], a[2]) end,
    [49] = function(a) return string.format("人物%d内力属性%d", a[1], a[2]) end,
    [50] = function() return "新指令，暂时没有解释" end,
    [51] = function() return "问软体娃娃" end,
    [52] = function() return "看道德" end,
    [53] = function() return "看声望" end,
    [54] = function() return "开放其它场景" end,
    [55] = function(a) return string.format("事件%d编号%d是否为%d", a[1], a[2], a[3]) end,
    [56] = function(a) return string.format("提高声望值%d", a[1]) end,
    [57] = function() return "高昌迷宫劈门" end,
    [58] = function() return "武道大会比武" end,
    [59] = function() return "全体队员离队并找不着" end,
    [60] = function(a) return string.format("判断场景%d事件位置%d是否有贴图%d", a[1], a[2], a[3]) end,
    [61] = function(a) return string.format("判断是否放完%d本书", a[1]) end,
    [62] = function() return "播放进入时空机动画" end,
    [63] = function(a) return string.format("设置人物%d性别%d", a[1], a[2]) end,
    [64] = function() return "韦小宝卖东西" end,
    [65] = function() return "韦小宝去其它客栈" end,
    [66] = function(a) return string.format("播放音乐%d", a[1]) end,
    [67] = function(a) return string.format("播放音效%d", a[1]) end,
}

local function noteFor(op, args)
    local fn = NOTE[op]
    if not fn then return string.format("指令%d", op) end
    local ok, s = pcall(fn, args)
    if not ok then return string.format("指令%d", op) end
    return s
end

-- Jump-offset argument index per conditional opcode.
--
-- Reverse-engineered from the kys-pascal baseline (1018 events): the jump
-- offset of a conditional is the *first non-zero* argument at index >= K(op).
-- The offset is the word length of the block body, so the block ends at
--   label = word_index + arity + 1 + offset
-- (word_index = index of the opcode word; arity words follow it).
-- This reproduces 1014/1018 events of the original fishedit extraction exactly.
local JUMP_K = {
    [4]=2, [5]=1, [6]=2, [9]=1, [11]=1, [16]=2, [18]=2, [20]=1,
    [28]=4, [29]=4, [31]=2, [36]=2, [42]=1, [43]=2, [50]=6,
    [55]=3, [60]=4, [61]=1,
}

-- First non-zero argument at index >= k (1-based). Returns 0 if none.
local function jumpOffset(op, args)
    local k = JUMP_K[op] or 1
    local ar = ARITY[op]
    for j = k, ar do
        if args[j] and args[j] ~= 0 then return args[j] end
    end
    return 0
end

-- Render one kdef entry into an oldevent_<k>.lua body.
--
-- Structure (matches the original fishedit extraction):
--   * a conditional opcode emits `if instruct_N(...) ==true/false then`
--     (last param == 0 -> ==false, else ==true) and opens a block
--   * opcode 7 emits `do return; end` and terminates the innermost block
--   * a block without an op7 terminator is closed at its jump target
--     (word position wi + arity + 1 + offset)
--   * the block is closed with `end    --:LabelN`
function BUILD.RenderEvent(k, instrs)
    -- Annotate each instruction with its word index (opcode word position).
    local n = #instrs
    local wi = {}
    local w = 0
    for i = 1, n do
        wi[i] = w
        w = w + 1 + ARITY[instrs[i].op]
    end
    local totalWords = w

    -- Index of the first instruction whose word index >= wordEnd.
    local function idxAfter(wordEnd)
        for j = 1, n do
            if wi[j] >= wordEnd then return j end
        end
        return n + 1
    end

    -- Effective block end (word position) for a conditional instruction.
    -- If the block contains an op7 terminator at the current nesting level, the
    -- block ends right after that op7; otherwise it ends at the jump target.
    -- This distinguishes flat guard chains (event 655) from nested blocks that
    -- have no op7 (event 530).
    --
    -- Computed iteratively from the last instruction backwards so that nested
    -- (later) blocks are already resolved when their parent is processed; this
    -- avoids unbounded recursion on deep/malformed event data.
    local bendCache = {}
    for i = n, 1, -1 do
        local ins = instrs[i]
        if CONDITIONAL[ins.op] then
            -- op28's jump offset points one word before the end of its body (the
            -- terminating op7 is part of the body), unlike other conditionals.
            local base = (ins.op == 28) and 2 or 1
            local je = wi[i] + ARITY[ins.op] + base + jumpOffset(ins.op, ins.args)
            local j = i + 1
            local resolved = nil
            while j <= n and wi[j] < je do
                local op = instrs[j].op
                if op == 7 then
                    resolved = wi[j] + 1
                    break
                elseif CONDITIONAL[op] then
                    local sub = bendCache[j]
                    local nj = idxAfter(sub or je)
                    if nj <= j then nj = j + 1 end  -- guard: always advance
                    j = nj
                else
                    j = j + 1
                end
            end
            bendCache[i] = resolved or je
        end
    end
    local function blockEnd(i)
        return bendCache[i]
    end

    local lines = {}
    lines[#lines + 1] = string.format("--function oldevent_%d()", k)
    local level = 1
    local labelSeq = 0

    -- Emit instructions [i, ...) whose word index < stopWord. Returns the next
    -- instruction index that is not part of this block.
    local function emit(i, stopWord)
        while i <= n and wi[i] < stopWord do
            local ins = instrs[i]
            local op = ins.op
            local args = ins.args
            local indent = string.rep("    ", level)
            if CONDITIONAL[op] then
                local bend = blockEnd(i)
                if bend > stopWord then bend = stopWord end
                local last = args[#args]
                local value = (last == 0) and "false" or "true"
                local label = labelSeq
                labelSeq = labelSeq + 1
                lines[#lines + 1] = ""
                lines[#lines + 1] = indent .. "if instruct_" .. op .. "(" ..
                    fmtArgs(args) .. ") ==" .. value .. " then   --" .. noteFor(op, args)
                level = level + 1
                i = emit(i + 1, bend)
                level = level - 1
                lines[#lines + 1] = string.rep("    ", level) ..
                    "end    --:Label" .. label
                lines[#lines + 1] = ""
            elseif op == 7 then
                lines[#lines + 1] = indent .. "do return; end"
                i = i + 1
            else
                lines[#lines + 1] = indent .. "instruct_" .. op .. "(" ..
                    fmtArgs(args) .. ");   --" .. noteFor(op, args)
                i = i + 1
            end
        end
        return i
    end

    emit(1, totalWords)
    lines[#lines + 1] = "--end"
    lines[#lines + 1] = ""
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- REQ-BUILD-1: resource flattening
-- ---------------------------------------------------------------------------

-- Editor byproducts that must be ignored.
local IGNORE_DIRS = { head = true, item = true, eft = true }
local IGNORE_FILES = { [".ds_store"] = true }

-- REQ-LBIN-1: list/ 下只有这两个文件有引擎消费方（经 CC.Effect / CC.ExtraOffense
-- 的硬编码替代，见 allmods-list-bin-support/design.md ADR-1）。它们必须进产物
-- data/，运行时由 ModData.LoadEffectTable() 惰性装载。
-- leave.bin / levelup.bin / *.txt 引擎零引用 ⇒ 明文不进产物（LEGACY）。
local LIST_COPY_WHITELIST = { ["effect.bin"] = true, ["match.bin"] = true }

-- ---------------------------------------------------------------------------
-- REQ-MIDI-2: MOD MIDI music, copied verbatim and renumbered.
--
-- MOD sources ship music/<id>.mid, while the engine requests
-- string.format(CC.MIDIFile, id + 1) (jymain.lua:2162). Sampling all 20 MODs
-- showed music/<id>.mid is the correct pairing: <id> resolves 94.6% of every
-- referenced id vs 90.5% for <id+1>, and several MODs ship music/0.mid (an
-- <id+1> rule would ask for -1.mid, which cannot exist). The remaining 20
-- misses are all in one MOD whose referenced range (24..51) exceeds its
-- shipped files (0..23) -- a source-data gap, not a numbering issue.
--
-- So the build renames <id>.mid -> game<id+1>.mid (LÖVE's "%02d" is a minimum
-- width, so 81 -> game82). Paths are written as music/game<NN>.mid, matching
-- the runtime's "mods/<slug>/music/game%02d" + extension probe.
--
-- .sf2 (soundfont) is a conversion input, not a product: it stays behind as
-- BUILD_INPUT (see mod_audit).
--
-- .mp3 is copied as well: LÖVE decodes it natively (measured: dream/24.mp3
-- 266.72s, pineapple/37.mp3 248.08s, both audible) and the runtime extension
-- probe already includes it. Both shipped .mp3 files sit at ids that no source
-- currently references, but the 537 unreferenced .mid are shipped too -- same
-- "ship everything" rule, and it keeps a future MOD revision playable.
-- The two extensions cannot collide: no MOD ships both <id>.mid and <id>.mp3.
-- ---------------------------------------------------------------------------
local function flattenMusic(modDir, outMusic)
    if not outMusic then return 0 end
    local srcDir = modDir .. "/music"
    local names = listDir(srcDir) or {}
    local n = 0
    for _, name in ipairs(names) do
        -- Lua patterns have no alternation operator ("|" is a literal), so
        -- capture the extension and test it against a whitelist instead.
        local id, ext = name:match("^(%d+)%.([%a%d]+)$")
        if id and (ext == "mid" or ext == "mp3") then
            local data = readFile(srcDir .. "/" .. name)
            if data then
                mkdirp(outMusic)
                local dest = string.format("%s/game%02d.%s", outMusic, tonumber(id) + 1, ext)
                writeFile(dest, data)
                n = n + 1
            end
        end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Resource file aliases (REQ-ALIAS-1).
--
-- The MOD source data uses the original C engine (kys.exe) file names, while the
-- Lua engine uses descriptive names. The authoritative mapping comes from
-- reference/allmods/UPedit/UPedit.ini, [File] section:
--     File2=resource\sdx,resource\smp,场景贴图     (scene map tiles)
--     File3=resource\wdx,resource\wmp,战斗贴图     (battle map tiles)
--     SMAPIDX=resource\sdx    SMAPGRP=resource\smp
-- (UPedit.ini's WarMapIDX/WarMapGRP also say sdx/smp -- that is a copy-paste
--  bug in the editor; the Lua engine reads wmap.* for battle maps and the
--  wdx/wmp payloads differ from sdx/smp, confirmed by md5.)
--
-- Only files from resource/ (kind == "data") are aliased; fight/ and save/ are
-- left untouched (REQ-ALIAS-2).
-- ---------------------------------------------------------------------------
local ALIAS_MAP = {
    ["sdx"] = "smap.idx",
    ["smp"] = "smap.grp",
    ["wdx"] = "wmap.idx",
    ["wmp"] = "wmap.grp",
}

-- The set of alias *target* names; used by buildDiff() to suppress the
-- spurious "missing from MOD" report for files that are actually provided
-- under their C-engine name (REQ-ALIAS-4).
local ALIAS_TARGETS = {}
for _, v in pairs(ALIAS_MAP) do ALIAS_TARGETS[v] = true end

-- The set of alias *source* names; used by buildDiff() to suppress the
-- spurious "MOD only" report for files that were renamed (REQ-ALIAS-4).
local ALIAS_SOURCES = {}
for k in pairs(ALIAS_MAP) do ALIAS_SOURCES[k] = true end

-- Apply the alias map to a flattened (lowercased) relative path. Only the file
-- name is considered; subdirectories (if any) are preserved.
local function applyAlias(destRel)
    local dir, name = destRel:match("^(.*/)([^/]+)$")
    if not name then dir, name = "", destRel end
    local target = ALIAS_MAP[name]
    if target then return dir .. target end
    return destRel
end

-- save/ 目录中哪些文件是“基础模板”（进 data/，供 LoadRecord(0) 读取），
-- 哪些是“用户存档”（进 save/，供 LoadRecord(1..N)/SaveRecord 读写）。
--   模板：ranger.idx/ranger.grp、alldef.*、allsin.*、allsinbk.*
--   用户存档：rN.grp / dN.grp / sN.grp / rN.idx（N 为数字，含 r11 这类）
local SAVE_TEMPLATE = {
    ["ranger.idx"] = true, ["ranger.grp"] = true,
    ["alldef.grp"] = true, ["alldef.idx"] = true,
    ["allsin.grp"] = true, ["allsin.idx"] = true,
    ["allsinbk.grp"] = true,
}

-- 判断 save/ 下的文件名是否为“用户存档”（Lua 模式不支持 | 交替，故分开写）
local function isSaveSlotFile(name)
    local lower = name:lower()
    local base, ext = lower:match("^([rds]%d+)%.([a-z]+)$")
    if not base then return false end
    return ext == "grp" or ext == "idx"
end

-- Returns the list of source files to flatten (relative paths) for a MOD dir.
-- resource/ files keep their relative path (flat, no subdirs in practice);
-- fight/ contents and save/ templates are flattened to the data/ top level
-- (the engine reads data/fightNNN.grp and data/alldef.grp etc. directly).
-- save/ user saves are routed to the MOD's own save/ dir (kind="save").
local function collectDataFiles(modDir)
    local files = {}
    local function walk(dir, rel, kind)
        local items = listDir(dir)
        if not items then return end
        for _, name in ipairs(items) do
            if name ~= "." and name ~= ".." then
                local full = dir .. "/" .. name
                local relPath = rel == "" and name or (rel .. "/" .. name)
                local lower = name:lower()
                -- directory?
                local isdir = isDir(full)
                if isdir then
                    local top = relPath:match("^([^/]+)")
                    if not IGNORE_DIRS[top:lower()] then
                        walk(full, relPath, kind)
                    end
                else
                    if not IGNORE_FILES[lower] and not lower:match("^%.") then
                        -- save/ 下区分模板（→ data/）与用户存档（→ save/）
                        local fileKind = kind
                        if kind == "save-template" then
                            if isSaveSlotFile(name) then
                                fileKind = "save"
                            else
                                fileKind = "data"
                            end
                        elseif kind == "list-whitelist" then
                            -- REQ-LBIN-1: 只有 effect.bin / match.bin 进产物
                            if not LIST_COPY_WHITELIST[lower] then
                                fileKind = nil
                            else
                                fileKind = "data"
                            end
                        end
                        if fileKind then
                            files[#files + 1] = { src = full, rel = relPath, kind = fileKind }
                        end
                    end
                end
            end
        end
    end
    walk(modDir .. "/resource", "", "data")
    -- fight/ 的内容拍平到 data/ 顶层（引擎直接读 data/fightNNN.grp）
    walk(modDir .. "/fight", "", "data")
    -- save/：基础模板 → data/；用户存档 → save/（各 MOD 隔离）
    walk(modDir .. "/save", "", "save-template")
    -- sound/：MOD 音效，复制到 mods/<mod>/sound/（REQ-SOUND-1）
    walk(modDir .. "/sound", "", "sound")
    -- list/：只有 effect.bin / match.bin 有消费方（REQ-LBIN-1），白名单搬运
    walk(modDir .. "/list", "", "list-whitelist")
    -- music/：MOD 自带 MIDI，构建期重命名为 game<id+1>.mid（REQ-MIDI-2）
    --         在 flattenResources 里由 flattenMusic 单独处理，不在 walk 里做
    return files
end

-- 把 MOD 源文件拍平到 outData（kind="data"）与 outSave（kind="save"）。
-- 返回 dataCount, saveCount。
-- ---------------------------------------------------------------------------
-- Big5 -> UTF-8 conversion of the MOD definition data (ranger.grp)--
-- The MOD ranger.grp strings are Big5; the engine renders UTF-8. Fixed-width
-- fields cannot hold the UTF-8 form (41% overflow), so we replace each string
-- field with a fixed-width hint (e.g. "P0002") and emit the real UTF-8 values
-- to a side table. The .grp keeps its exact size, so numeric offsets are safe.
-- ---------------------------------------------------------------------------

-- Returns newGrpData (or nil), report (or nil,err).
local function convertRangerFile(grpData, modDir)
    local ok, E = pcall(require, "tools.mod_encoding")
    if not ok or not E then return nil, "mod_encoding not loadable" end

    -- ranger.idx lives next to ranger.grp (under save/ in the MOD source tree)
    local idxData = readFile(modDir .. "/save/ranger.idx")
    if not idxData then return nil, "missing save/ranger.idx" end
    local offs = E.ParseIdx(idxData)

    -- A few MODs ship an idx that does not describe their own ranger.grp
    -- (kys-zheng's idx points at a 138596-byte save while the grp is 114242
    -- bytes). Repair it from the bytes before converting; well-formed MODs are
    -- returned untouched.
    local repaired, repairReason = E.RepairIdx(grpData, offs)
    if repaired then
        offs = repaired
    elseif repairReason then
        return nil, "idx repair failed: " .. repairReason
    end

    local newGrp, side, report = E.ConvertRanger(grpData, offs)
    report.idxRepaired = repairReason
    report.idxOffsets = offs
    if #newGrp ~= #grpData then
        return nil, string.format("size changed %d -> %d", #grpData, #newGrp)
    end
    if #report.overflows > 0 then
        return nil, "hint overflow: " .. table.concat(report.overflows, "; ")
    end
    return newGrp, { side = side, report = report }
end

-- Human-readable summary of the Big5 -> UTF-8 conversion (per segment).
local function buildEncodingReport(slug, enc)
    local r = enc.report
    local lines = {
        "# 编码转换报告: " .. slug,
        "",
        "MOD 原始 `save/ranger.grp` 的字符串字段为 **Big5**，引擎按 UTF-8 渲染。",
        "构建期将其转换为 UTF-8，**不截断**：`ranger.grp` 字符串区写入固定宽度 hint，",
        "真实字符串写入旁路表 `data/ranger.str`。文件大小保持不变，数值偏移零风险。",
        "",
        "## 统计",
        "",
        "| 项 | 值 |",
        "|---|---|",
        string.format("| 转换字段数 | %d |", r.converted),
        string.format("| 去重复用数 | %d |", r.dedup),
        string.format("| 旁路表条目 | %d |", r.converted - r.dedup),
        string.format("| 截断字段数 | 0 |"),
        string.format("| hint 溢出 | %d |", #r.overflows),
        "",
        "## 分段明细",
        "",
        "| 段 | 记录数 | 字符串字段 | 转换 | 去重 |",
        "|---|---|---|---|---|",
    }
    for _, segName in ipairs({ "Person", "Thing", "Scene", "Wugong" }) do
        local st = r.perSeg[segName]
        if st then
            lines[#lines + 1] = string.format("| %s | %d | %d | %d | %d |",
                segName, st.records, st.fields, st.converted, st.dedup)
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "## hint 格式"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "| 字段 | 前缀 | 示例 |"
    lines[#lines + 1] = "|---|---|---|"
    lines[#lines + 1] = "| Person.姓名 | `P` | `P0002` |"
    lines[#lines + 1] = "| Person.外号 | `N` | `N0003` |"
    lines[#lines + 1] = "| Thing.名 | `T` | `T0005` |"
    lines[#lines + 1] = "| Thing.名2 | `T2` | `T20006` |"
    lines[#lines + 1] = "| Thing.说明 | `TD` | `TD0007` |"
    lines[#lines + 1] = "| Scene.名称 | `S` | `S0008` |"
    lines[#lines + 1] = "| Wugong.名称 | `W` | `W0009` |"
    lines[#lines + 1] = ""
    if #r.overflows > 0 then
        lines[#lines + 1] = "## ⚠ 异常"
        lines[#lines + 1] = ""
        for _, o in ipairs(r.overflows) do
            lines[#lines + 1] = "- " .. o
        end
        lines[#lines + 1] = ""
    end
    return table.concat(lines, "\n")
end

local function flattenResources(modDir, outData, outSave, outSound, outMusic)
    mkdirp(outData)
    if outSave then mkdirp(outSave) end
    if outSound then mkdirp(outSound) end
    if outMusic then mkdirp(outMusic) end
    local files = collectDataFiles(modDir)
    local count = 0
    local saveCount = 0
    local soundCount = 0
    local encReport = nil
    local pendingIdx = nil
    -- Track written destination paths so an alias collision (REQ-ALIAS-3) can
    -- be reported instead of silently overwriting.
    local written = {}
    local aliasesUsed = {}
    for _, f in ipairs(files) do
        -- lowercase normalization of the file name (subdirs preserved when present)
        local rel = f.rel
        local parts = {}
        for seg in rel:gmatch("[^/]+") do parts[#parts + 1] = seg:lower() end
        local destRel = table.concat(parts, "/")
        local base = outData
        if f.kind == "save" then base = outSave or outData
        elseif f.kind == "sound" then base = outSound or outData end
        -- resource/ files (kind == "data") may carry a C-engine name that the
        -- Lua engine knows under a different name (REQ-ALIAS-1).
        local aliased = false
        if f.kind == "data" and ALIAS_MAP[destRel] then
            local target = applyAlias(destRel)
            aliasesUsed[#aliasesUsed + 1] = { from = destRel, to = target }
            destRel = target
            aliased = true
        end
        local dest = base .. "/" .. destRel
        -- REQ-ALIAS-3: only an *alias* may not silently overwrite an existing
        -- destination. Pre-existing duplicates unrelated to aliasing (e.g.
        -- RiverLake ships alldef.grp in both resource/ and save/) keep the
        -- historical "last write wins" behaviour.
        if aliased and written[dest] then
            return nil, nil, nil,
                string.format("alias conflict: %s already written (alias target of %s)",
                    dest, f.src)
        end
        written[dest] = true
        local dir = dest:match("^(.*)/[^/]*$")
        if dir then mkdirp(dir) end
        local data = readFile(f.src)
        if data then
            -- Big5 -> UTF-8 conversion for the definition data (ranger.grp).
            -- The .grp is rewritten in place with fixed-width hints; the real
            -- UTF-8 strings go to a sibling ranger.str side table.
            if destRel == "ranger.grp" then
                local newData, encRep = convertRangerFile(data, modDir)
                if newData then
                    data = newData
                    encReport = encRep
                end
            end
            writeFile(dest, data)
            -- When the shipped ranger.idx did not describe this ranger.grp the
            -- build emitted a repaired layout; remember it so it can be
            -- persisted AFTER the copy loop (a later ranger.idx copy would
            -- otherwise clobber the repaired file).
            if destRel == "ranger.grp" and encReport and encReport.report
                and encReport.report.idxRepaired then
                pendingIdx = pendingIdx or {}
                pendingIdx[#pendingIdx + 1] = { base = base, offs = encReport.report.idxOffsets }
            end
            if f.kind == "save" then
                saveCount = saveCount + 1
            elseif f.kind == "sound" then
                soundCount = soundCount + 1
            else
                count = count + 1
            end
        end
    end
    -- Persist any repaired ranger.idx now that every source file has been
    -- copied, so the runtime reads the correct segment boundaries.
    if pendingIdx then
        for _, p in ipairs(pendingIdx) do
            local buf = {}
            for i = 1, 6 do
                local v = p.offs[i]
                buf[#buf + 1] = string.char(
                    v % 256,
                    math.floor(v / 256) % 256,
                    math.floor(v / 65536) % 256,
                    math.floor(v / 16777216) % 256)
            end
            writeFile(p.base .. "/ranger.idx", table.concat(buf))
        end
    end
    -- kysmod.ini
    local ini = readFile(modDir .. "/kysmod.ini")
    if ini then
        writeFile(outData .. "/kysmod.ini", ini)
        count = count + 1
    end
    -- REQ-MIDI-2: MOD MIDI music -> mods/<slug>/music/game<id+1>.mid
    local musicCount = flattenMusic(modDir, outMusic)
    return count, saveCount, encReport, nil, soundCount, aliasesUsed, musicCount
end

-- ---------------------------------------------------------------------------
-- REQ-BUILD-2: kdef extraction
-- ---------------------------------------------------------------------------

local function extractKdef(modDir, outScript)
    local entries = readIndexedEntries(modDir .. "/resource/kdef.idx",
                                       modDir .. "/resource/kdef.grp")
    if not entries then return nil, "missing kdef.grp/kdef.idx" end
    local outDir = outScript .. "/oldevent"
    mkdirp(outDir)
    local n = 0
    for k = 0, #entries - 1 do
        local instrs, err = parseKdefEntry(entries[k + 1])
        if not instrs then
            return nil, string.format("event %d: %s", k, err)
        end
        local lua = BUILD.RenderEvent(k, instrs)
        writeFile(outDir .. string.format("/oldevent_%d.lua", k), lua)
        n = n + 1
    end
    return n
end

-- ---------------------------------------------------------------------------
-- REQ-BUILD-3: talk extraction
-- ---------------------------------------------------------------------------

local function extractTalk(modDir, outScript)
    local entries = readIndexedEntries(modDir .. "/resource/talk.idx",
                                       modDir .. "/resource/talk.grp")
    if not entries then return nil, "missing talk.grp/talk.idx" end
    local lines = {}
    lines[#lines + 1] = "oldtalk={};"
    -- 运行时 ReadTalk 读 script/oldtalk.grp（UTF-8 文本，每行一条）+ oldtalk.idx（4字节小端偏移）
    local grpParts = {}
    local idxParts = {}
    local offset = 0
    for k = 1, #entries do
        local raw = entries[k]
        -- 条目终止符因 MOD 而异：
        --   * 原版/pascal 约定：末尾 0x00
        --   * mingdong 等约定：末尾 0xff，且可能多 1 个杂散字节
        -- 先试 0x00 约定；无尾 0x00 时再用 0xff 约定。
        local trimmed = raw
        local n0 = 0
        while #trimmed > 0 and trimmed:byte(#trimmed) == 0x00 do
            trimmed = trimmed:sub(1, #trimmed - 1); n0 = n0 + 1
        end
        if n0 == 0 then
            -- 0xff 约定：先去掉尾部连续 0xff，再处理“0xff + 1 杂散字节”
            while #trimmed > 0 and trimmed:byte(#trimmed) == 0xff do
                trimmed = trimmed:sub(1, #trimmed - 1)
            end
            if #trimmed >= 2 and trimmed:byte(#trimmed - 1) == 0xff then
                trimmed = trimmed:sub(1, #trimmed - 1)
                while #trimmed > 0 and trimmed:byte(#trimmed) == 0xff do
                    trimmed = trimmed:sub(1, #trimmed - 1)
                end
            end
        end
        raw = trimmed
        local text = BUILD.DecodeTalk(raw)
        lines[#lines + 1] = string.format("oldtalk[%d]=%s;", k, luaString(text))
        -- oldtalk.grp 行：文本 + CRLF（与原版 script/oldtalk.grp 一致）
        grpParts[#grpParts + 1] = text .. "\r\n"
        offset = offset + #text + 2  -- +CRLF
        -- oldtalk.idx 条目：与运行时 GenTalkIdx 语义一致——
        --   idx[k] = 读完第 k 行后的字节偏移（即第 k 行结束处，含 CRLF）
        -- 对应 ReadTalk：talkid==0 → [0, idx[0])；talkid>0 → [idx[talkid-1], idx[talkid])
        idxParts[#idxParts + 1] = packU32(offset)
    end
    lines[#lines + 1] = ""
    writeFile(outScript .. "/old_talk.lua", table.concat(lines, "\n"))
    writeFile(outScript .. "/oldtalk.grp", table.concat(grpParts))
    writeFile(outScript .. "/oldtalk.idx", table.concat(idxParts))
    return #entries
end

-- ---------------------------------------------------------------------------
-- REQ-BUILD-4: data diff report
-- ---------------------------------------------------------------------------

local function countFights(modDir)
    local dir = modDir .. "/fight"
    local items = listDir(dir)
    if not items then return 0 end
    local seen = {}
    for _, name in ipairs(items) do
        local id = name:match("^fight(%d+)%.grp$")
        if id then seen[tonumber(id)] = true end
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    return n
end

local function hdgrpCount(path)
    local data = readFile(path)
    if not data then return nil end
    return math.floor(#data / 4)
end

-- ---------------------------------------------------------------------------
-- REQ-BUILD-5: kys-pascal baseline verification
--
-- Compares the events produced by this tool for kys-pascal against the
-- committed reference extraction in game/script/oldevent/. A structural
-- signature (if/instr/ret/end sequence) is used so that comment text (which
-- the DoD allows to differ) is ignored.
--
-- Three events are documented, justified deviations (see KNOWN_DEVIATIONS):
--   * 320 - the original extraction renders a same-target conditional pair as
--           if/else; this tool emits the equivalent nested form.
--   * 655 - the original extraction DROPS two `instruct_43` guards that are
--           present in kdef.grp; this tool is faithful to the binary.
--   * 691 - the original extraction DROPS a duplicated `instruct_27`; this tool
--           is faithful to the binary.
local KNOWN_DEVIATIONS = {
    [320] = "原版提取器将同目标的相邻条件渲染为 if/else（等价嵌套形式）",
    [655] = "原版提取器丢弃了 2 个 instruct_43 守卫（二进制中存在）",
    [691] = "原版提取器丢弃了重复的 instruct_27（二进制中存在）",
}

-- Extract a structural signature from an oldevent lua source string.
local function structSig(src)
    local sig = {}
    for line in src:gmatch("[^\n]*") do
        local s = line:gsub("^%s+", "")
        if s:match("^if instruct_") then sig[#sig + 1] = "if"
        elseif s:match("^instruct_") then sig[#sig + 1] = "instr"
        elseif s:match("^do return") then sig[#sig + 1] = "ret"
        elseif s:match("^end") then sig[#sig + 1] = "end" end
    end
    return table.concat(sig, ",")
end

-- Verify the kys-pascal baseline. Returns ok, details.
function BUILD.VerifyBaseline()
    local modDir = REF_DIR .. "/kys-pascal"
    local outScript = GAME_DIR .. "/mods/pascal/script"
    local refDir = GAME_DIR .. "/script/oldevent"
    local entries = readIndexedEntries(modDir .. "/resource/kdef.idx",
        modDir .. "/resource/kdef.grp")
    local nEvents = entries and #entries or 0
    local diffs, known = {}, {}
    for k = 0, nEvents - 1 do
        local refPath = string.format("%s/oldevent_%d.lua", refDir, k)
        local outPath = string.format("%s/oldevent/oldevent_%d.lua", outScript, k)
        local refSrc = readFile(refPath)
        local outSrc = readFile(outPath)
        if not refSrc then
            diffs[#diffs + 1] = { k = k, reason = "reference missing" }
        elseif not outSrc then
            diffs[#diffs + 1] = { k = k, reason = "output missing" }
        elseif structSig(refSrc) ~= structSig(outSrc) then
            if KNOWN_DEVIATIONS[k] then
                known[#known + 1] = { k = k, reason = KNOWN_DEVIATIONS[k] }
            else
                diffs[#diffs + 1] = { k = k, reason = "structural mismatch" }
            end
        end
    end
    return #diffs == 0, {
        events = nEvents,
        mismatches = diffs,
        known = known,
    }
end

local function dataFileSet(dir)
    local set = {}
    local items = listDir(dir)
    if not items then return set end
    for _, name in ipairs(items) do set[name:lower()] = true end
    return set
end

local function buildDiff(mod, modDir, outData, aliasesUsed)
    local lines = {}
    lines[#lines + 1] = string.format("# %s 数据差异报告", mod)
    lines[#lines + 1] = ""

    -- file add/remove vs game/data/
    local base = dataFileSet(GAME_DIR .. "/data")
    local modSet = dataFileSet(outData)
    local added, removed = {}, {}
    -- Alias-transformed files: the C-engine source name (sdx/smp/...) must not
    -- be reported as "MOD only", and its Lua-engine target name (smap.idx/...)
    -- must not be reported as "missing from MOD" (REQ-ALIAS-4).
    local aliasedTargets, aliasedSources = {}, {}
    for _, a in ipairs(aliasesUsed or {}) do
        aliasedTargets[a.to] = true
        aliasedSources[a.from] = true
    end
    for k in pairs(modSet) do
        if not base[k] and not aliasedSources[k] then added[#added + 1] = k end
    end
    for k in pairs(base) do
        if not modSet[k] and not aliasedTargets[k] then removed[#removed + 1] = k end
    end
    table.sort(added); table.sort(removed)

    lines[#lines + 1] = "## 资源别名转换"
    if aliasesUsed and #aliasesUsed > 0 then
        local sorted = {}
        for _, a in ipairs(aliasesUsed) do sorted[#sorted + 1] = a end
        table.sort(sorted, function(x, y) return x.from < y.from end)
        for _, a in ipairs(sorted) do
            lines[#lines + 1] = string.format("- %s → %s", a.from, a.to)
        end
    else
        lines[#lines + 1] = "- （无）"
    end
    lines[#lines + 1] = ""

    lines[#lines + 1] = "## 文件差异（vs game/data/）"
    lines[#lines + 1] = string.format("- MOD 独有: %d", #added)
    for _, f in ipairs(added) do lines[#lines + 1] = "  - + " .. f end
    lines[#lines + 1] = string.format("- 基准独有: %d", #removed)
    for _, f in ipairs(removed) do lines[#lines + 1] = "  - - " .. f end
    lines[#lines + 1] = ""

    -- hdgrp entry count
    local modHd = hdgrpCount(outData .. "/hdgrp.idx")
    local baseHd = hdgrpCount(GAME_DIR .. "/data/hdgrp.idx")
    lines[#lines + 1] = "## hdgrp 条目数"
    lines[#lines + 1] = string.format("- MOD: %s", modHd and tostring(modHd) or "n/a")
    lines[#lines + 1] = string.format("- 基准: %s", baseHd and tostring(baseHd) or "n/a")
    lines[#lines + 1] = ""

    -- fight count
    lines[#lines + 1] = "## fight 数量"
    lines[#lines + 1] = string.format("- MOD: %d", countFights(modDir))
    lines[#lines + 1] = ""

    -- ini diff
    lines[#lines + 1] = "## ini 差异"
    local modIni = readFile(modDir .. "/kysmod.ini")
    local baseIni = readFile(REF_DIR .. "/kys-pascal/kysmod.ini")
    if modIni and baseIni and modIni == baseIni then
        lines[#lines + 1] = "- 与 kys-pascal 相同"
    else
        lines[#lines + 1] = "- 与 kys-pascal 不同（详见 kysmod.ini）"
    end
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- main
-- ---------------------------------------------------------------------------

function BUILD.Build(mod, opts)
    opts = opts or {}
    local modDir = REF_DIR .. "/" .. mod
    -- 注意：不能用 exists()（io.open 探测）判目录 —— Windows 上 io.open 打开
    -- 目录会失败，而 Linux 上会成功，导致同一份代码在两个平台行为相反。
    if not isDir(modDir) then
        return nil, "MOD 目录不存在: " .. modDir
    end
    -- output slug = MOD name without the "kys-" prefix (e.g. kys-mingdong -> mingdong)
    local slug = mod:gsub("^kys%-", "")
    local outRoot = GAME_DIR .. "/mods/" .. slug
    local outData = outRoot .. "/data"
    local outScript = outRoot .. "/script"
    local outSave = outRoot .. "/save"
    local outSound = outRoot .. "/sound"
    local outMusic = outRoot .. "/music"
    -- Rendered audio must survive a rebuild.
    --
    -- mods/<slug>/music/ can hold two kinds of file: the .mid/.mp3 copied from
    -- the MOD source, and a pre-rendered .ogg produced out-of-band with a real
    -- SoundFont (see tools/render-music.sh). LÖVE's bundled libmodplug ignores
    -- SoundFonts, so those .ogg files are the only way to get non-thin audio;
    -- rendering takes minutes per MOD, so losing them on every rebuild would be
    -- painful. They are preserved across the rmdirp() below.
    --
    -- Only product-side renders exist (measured: reference/allmods ships zero
    -- music/*.ogg), so anything .ogg here is a render, never a source copy.
    local preservedOgg = {}
    for _, name in ipairs(listDir(outMusic) or {}) do
        if name:match("%.ogg$") then
            local data = readFile(outMusic .. "/" .. name)
            if data then preservedOgg[name] = data end
        end
    end
    -- Clean the previous output so renamed/removed source files do not linger
    -- (e.g. sdx/smp left over from a pre-alias build).
    rmdirp(outRoot)
    mkdirp(outData)
    mkdirp(outScript)
    mkdirp(outSave)
    mkdirp(outSound)
    mkdirp(outMusic)

    local report = {}

    local nFiles, nSaves, enc, ferr, nSounds, aliasesUsed, nMusic =
        flattenResources(modDir, outData, outSave, outSound, outMusic)
    if ferr then return nil, ferr end
    report.files = nFiles
    report.saves = nSaves
    report.sounds = nSounds or 0
    report.music = nMusic or 0
    report.aliases = aliasesUsed or {}

    -- Restore pre-rendered .ogg files wiped by rmdirp() above.
    local restored = 0
    for name, data in pairs(preservedOgg) do
        writeFile(outMusic .. "/" .. name, data)
        restored = restored + 1
    end
    report.renderedOgg = restored

    -- Big5 -> UTF-8 side table + encoding report
    if enc then
        local E = require("tools.mod_encoding")
        writeFile(outData .. "/ranger.str", E.SerializeSideTable(enc.side))
        writeFile(outRoot .. "/encoding-report.md", buildEncodingReport(slug, enc))
        report.encoded = enc.report.converted
        report.encodingReport = outRoot .. "/encoding-report.md"
    end

    local nEvents, kerr = extractKdef(modDir, outScript)
    if not nEvents then return nil, "kdef 提取失败: " .. tostring(kerr) end
    report.events = nEvents

    local nTalk, terr = extractTalk(modDir, outScript)
    if not nTalk then return nil, "talk 提取失败: " .. tostring(terr) end
    report.talk = nTalk

    local diff = buildDiff(slug, modDir, outData, aliasesUsed)
    writeFile(outRoot .. "/diff.md", diff)
    report.diff = outRoot .. "/diff.md"

    return report
end

-- CLI (only when executed as the main script, not dofile'd)
local args = { ... }
local mod = args[1]
if mod == "--all" then
    -- Build every MOD in games.ini. MODs annotated as problematic in games.ini
    -- are still built (best effort) but the process exits non-zero with an
    -- explanation on stderr (REQ-BUILD-4).
    local games = parseGamesIni()
    local failed, problems = {}, {}
    for _, g in ipairs(games) do
        local report, err = BUILD.Build(g.mod)
        if not report then
            failed[#failed + 1] = string.format("%s: %s", g.mod, tostring(err))
            io.stderr:write(string.format("[mod_build] %s FAILED: %s\n", g.mod, tostring(err)))
        else
            print(string.format("[mod_build] %-14s data=%d saves=%d sound=%d events=%d talk=%d",
                g.mod, report.files, report.saves or 0, report.sounds or 0,
                report.events, report.talk))
            if g.problem then
                problems[#problems + 1] = g.mod
                io.stderr:write(string.format(
                    "[mod_build] %s: 数据异常（games.ini 标注: %s）\n", g.mod, g.problem))
            end
        end
    end
    print(string.format("[mod_build] all: %d mods, %d build failures, %d annotated-problematic",
        #games, #failed, #problems))
    if #failed > 0 or #problems > 0 then
        os.exit(1)
    end
elseif mod == "--verify-pascal" then
    local ok, details = BUILD.VerifyBaseline()
    print(string.format("[mod_build] pascal baseline: events=%d, mismatches=%d, known-deviations=%d",
        details.events, #details.mismatches, #details.known))
    for _, d in ipairs(details.known) do
        print(string.format("  [known] event %d: %s", d.k, d.reason))
    end
    for _, d in ipairs(details.mismatches) do
        print(string.format("  [FAIL] event %d: %s", d.k, d.reason))
    end
    if ok then
        print("[mod_build] pascal baseline: PASS")
    else
        io.stderr:write("[mod_build] pascal baseline: FAIL\n")
        os.exit(1)
    end
elseif mod ~= nil then
    local report, err = BUILD.Build(mod)
    if not report then
        io.stderr:write("BUILD FAILED: " .. tostring(err) .. "\n")
        os.exit(1)
    end
    print(string.format("[mod_build] %s: data files=%d, saves=%d, sound=%d, events=%d, talk=%d",
        mod, report.files, report.saves or 0, report.sounds or 0, report.events, report.talk))
    print("[mod_build] diff -> " .. report.diff)
end

return BUILD
