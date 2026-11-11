-- tools/smap_tool.lua
-- grp 贴图（smap.grp / smap.idx / mmap.col）通用提取与排查工具。
--
-- 解码与 lib_love.lua 的 LoadPic/PicLoadFile 完全一致:
--   idx 文件: 每条目 4 字节小端 = 该图结束偏移; 第 k 图(0-based)范围 = entry[k-1]..entry[k]
--   显示 picid(偶数) -> 图序号 slot = floor(picid/2)
--   帧头 8 字节: w, h (u16), xoff, yoff (i16)
--   RLE 每行: count=u8; while offset<count: trans=u8; solid=u8; solid 个调色板索引 u8
--   调色板 mmap.col: 256 项 x 3 字节 (r,g,b) 0..63 -> *4
--
-- 用法（在仓库根目录或任意目录执行，data 目录为第一个参数）:
--   lua tools/smap_tool.lua extract <data目录> <输出目录> <picid...>   提取帧为 P6 PPM（真实调色板 RGB）
--   lua tools/smap_tool.lua extract <data目录> <输出目录> <picid...> --gray  输出调色板索引灰度（便于脚本 diff）
--   lua tools/smap_tool.lua scan <data目录> <中心偏移> [半径=400]      在 grp 偏移附近寻找有效帧头
--   lua tools/smap_tool.lua hexdump <data目录> <偏移...> [每段长度=32]  按 grp 偏移十六进制 dump
--   lua tools/smap_tool.lua entries <data目录> <图序号...>              打印 idx 条目/帧头（1-based 图序号 = slot+1）
--
-- 示例:
--   lua tools/smap_tool.lua extract game/data /tmp/frames 6890 6932 4988
--   lua tools/smap_tool.lua scan game/data 1228382
--   lua tools/smap_tool.lua entries game/data 3446 3467

local sub = arg[1]
if not sub then
    io.write("usage: lua tools/smap_tool.lua <extract|scan|hexdump|entries> ...\n")
    os.exit(1)
end

local function readAll(p)
    local f = assert(io.open(p, "rb"), "cannot open " .. p)
    local s = f:read("a")
    f:close()
    return s
end

local function ushortl(s, o) return (s:byte(o) or 0) + (s:byte(o + 1) or 0) * 256 end
local function sshortl(s, o) local v = ushortl(s, o) if v >= 32768 then v = v - 65536 end return v end
local function uintl(s, o)
    local b = 0
    for i = 0, 3 do b = b + (s:byte(o + i) or 0) * (256 ^ i) end
    return b
end

-- 调色板: mmap.col 256 项 x 3 字节 (r,g,b) 0..63
local function loadPalette(data)
    local p = assert(io.open(data .. "/mmap.col", "rb"), "no palette: " .. data .. "/mmap.col")
    local raw = p:read(256 * 3)
    p:close()
    local pal = {}
    for i = 1, 256 do
        local o = (i - 1) * 3 + 1
        pal[i] = { (raw:byte(o) or 0) * 4, (raw:byte(o + 1) or 0) * 4, (raw:byte(o + 2) or 0) * 4 }
    end
    return pal
end

local function loadGrp(data)
    local idxb = readAll(data .. "/smap.idx")
    local grpb = readAll(data .. "/smap.grp")
    return idxb, grpb
end

-- 图序号 slot (0-based) 的 grp 偏移范围（lua 1-based）
local function slotRange(idxb, grpb, slot)
    local off1 = (slot == 0) and 1 or uintl(idxb, (slot - 1) * 4 + 1) + 1
    local off2 = uintl(idxb, slot * 4 + 1) + 1
    if off2 > #grpb then off2 = #grpb end
    return off1, off2
end

-- 解码 [off1, off2] 内的一帧, 返回 w,h,xoff,yoff,px([y][x]={r,g,b}) 或 nil,原因
local function decodeFrame(grpb, off1, off2, pal, gray)
    local w = ushortl(grpb, off1)
    local h = ushortl(grpb, off1 + 2)
    local xo = sshortl(grpb, off1 + 4)
    local yo = sshortl(grpb, off1 + 6)
    if w < 1 or w > 2048 or h < 1 or h > 2048 or off2 <= off1 then
        return nil, string.format("bad header w=%d h=%d off=%d..%d", w, h, off1, off2)
    end
    local px = {}
    local pos = off1 + 8
    for y = 1, h do
        if pos > off2 then return nil, "truncated (row " .. y .. ")" end
        local count = grpb:byte(pos) or 0
        pos = pos + 1
        local x = 0
        local off = 0
        while off < count do
            if pos + 1 > off2 then return nil, "truncated (run in row " .. y .. ")" end
            local trans = grpb:byte(pos) or 0
            pos = pos + 1
            off = off + 1
            x = x + trans
            local solid = grpb:byte(pos) or 0
            pos = pos + 1
            off = off + 1
            for _ = 1, solid do
                if pos > off2 then return nil, "truncated (pixel in row " .. y .. ")" end
                local pidx = (grpb:byte(pos) or 0) + 1
                pos = pos + 1
                off = off + 1
                if x >= 1 and x <= w then
                    if not px[y] then px[y] = {} end
                    if gray then
                        px[y][x] = { pidx - 1, pidx - 1, pidx - 1 }  -- 调色板索引
                    else
                        px[y][x] = pal[pidx]
                    end
                end
                x = x + 1
            end
        end
    end
    return { w = w, h = h, xoff = xo, yoff = yo, px = px }, nil
end

local function writePPM(path, frame, gray)
    local out = assert(io.open(path, "wb"), "cannot open " .. path)
    out:write(string.format("P6\n%d %d\n255\n", frame.w, frame.h))
    for y = 1, frame.h do
        local line = {}
        for x = 1, frame.w do
            local c = frame.px[y] and frame.px[y][x]
            if c then line[x] = string.char(c[1], c[2], c[3]) else line[x] = "\0\0\0" end
        end
        out:write(table.concat(line))
    end
    out:close()
end

local function parseInts(args, start)
    local nums = {}
    for i = start, #args do
        local n = tonumber(args[i])
        if not n then io.write("bad number: " .. args[i] .. "\n") os.exit(1) end
        nums[#nums + 1] = math.floor(n)
    end
    return nums
end

if sub == "extract" then
    local data = assert(arg[2], "usage: extract <datadir> <outdir> <picid...> [--gray]")
    local outdir = assert(arg[3], "usage: extract <datadir> <outdir> <picid...> [--gray]")
    local gray = (arg[#arg] == "--gray")
    local picids = {}
    for i = 4, #arg - (gray and 1 or 0) do picids[#picids + 1] = tonumber(arg[i]) end
    assert(#picids > 0, "need at least one picid")

    local idxb, grpb = loadGrp(data)
    local pal = gray and nil or loadPalette(data)

    local os_ = require "os"
    os_.execute(("mkdir -p %q"):format(outdir))

    local okCount = 0
    for _, picid in ipairs(picids) do
        local slot = math.floor(picid / 2)
        local off1, off2 = slotRange(idxb, grpb, slot)
        local frame, err = decodeFrame(grpb, off1, off2, pal, gray)
        if not frame then
            print(string.format("pic %d: SKIP (%s)", picid, err))
        else
            local path = string.format("%s/frame_%d.ppm", outdir, picid)
            writePPM(path, frame, gray)
            okCount = okCount + 1
            print(string.format("pic %d: w=%d h=%d xoff=%d yoff=%d -> %s", picid, frame.w, frame.h, frame.xoff, frame.yoff, path))
        end
    end
    print(string.format("extract: %d/%d ok", okCount, #picids))

elseif sub == "scan" then
    local data = assert(arg[2], "usage: scan <datadir> <center> [radius]")
    local center = assert(tonumber(arg[3]), "need center offset (1-based)")
    local radius = tonumber(arg[4]) or 400
    local _, grpb = loadGrp(data)
    local found = 0
    for delta = 0, radius do
        for _, off1 in ipairs({ center + delta, center - delta }) do
            if off1 >= 1 and off1 + 8 <= #grpb then
                local w, h = ushortl(grpb, off1), ushortl(grpb, off1 + 2)
                local xo, yo = sshortl(grpb, off1 + 4), sshortl(grpb, off1 + 6)
                if w >= 1 and w <= 1024 and h >= 1 and h <= 1024
                    and math.abs(xo) <= 1024 and math.abs(yo) <= 1024 then
                    print(string.format("offset=%d (center %+d): w=%d h=%d xoff=%d yoff=%d",
                        off1, off1 - center, w, h, xo, yo))
                    found = found + 1
                    if found >= 20 then goto done end
                end
            end
        end
    end
    if found == 0 then print("no valid header within +/-" .. radius) end
    ::done::

elseif sub == "hexdump" then
    local data = assert(arg[2], "usage: hexdump <datadir> <offset...> [--len N=32]")
    local _, grpb = loadGrp(data)
    local offsets, len = {}, 32
    for i = 3, #arg do
        if arg[i] == "--len" then len = assert(tonumber(arg[i + 1]), "need len value after --len")
        else
            local n = tonumber(arg[i])
            if not n then io.write("bad offset: " .. arg[i] .. "\n") os.exit(1) end
            offsets[#offsets + 1] = n
        end
    end
    assert(#offsets > 0, "need at least one offset")
    for _, off in ipairs(offsets) do
        local hex, ascii = {}, {}
        for i = 1, len do
            local b = grpb:byte(off + i - 1)
            if not b then break end
            hex[#hex + 1] = string.format("%02x", b)
            ascii[#ascii + 1] = (b >= 32 and b < 127) and string.char(b) or "."
        end
        print(string.format("@%d: %s  [%s]", off, table.concat(hex, " "), table.concat(ascii)))
    end

elseif sub == "entries" then
    local data = assert(arg[2], "usage: entries <datadir> <slot...>   (slot = 0-based 图序号, 显示picid/2)")
    local idxb, grpb = loadGrp(data)
    local nums = parseInts(arg, 3)
    assert(#nums > 0, "need at least one slot")
    for _, slot in ipairs(nums) do
        local e = uintl(idxb, slot * 4 + 1)
        local off1, off2 = slotRange(idxb, grpb, slot)
        local hdr = "oob"
        if off2 > off1 then
            local w, h = ushortl(grpb, off1), ushortl(grpb, off1 + 2)
            local xo, yo = sshortl(grpb, off1 + 4), sshortl(grpb, off1 + 6)
            hdr = string.format("w=%d h=%d xoff=%d yoff=%d", w, h, xo, yo)
        end
        print(string.format("slot %d (picid %d): entry=%d range=%d..%d %s",
            slot, slot * 2, e, off1, off2, hdr))
    end

else
    io.write("unknown subcommand: " .. sub .. " (expect extract|scan|hexdump|entries)\n")
    os.exit(1)
end
