-- format_spec.lua -- 格式字段级覆盖验证（REQ-FMT-1..7）
--
-- 目的：把"每个文件的每个字节都被归类"从人工承诺变成机器保证。
--
-- 核心模型（见 allmods-slice0c-format-spec/design.md ADR-001）：
--   所有格式统一为「区间集合」：
--     静态字段 {offset, size}          → [offset, offset+size)
--     动态字段 {from="offsets", to=...} → 由 offset 表展开
--   验证 = 排序后断言：首起 0、末至 filesize、无重叠、无缺口。
--
-- 每个字段必须标注 needed 与 consumer（needed=true 时）。
--
-- 用法：
--   cd game && lua tools/format_spec.lua --all
--   cd game && lua tools/format_spec.lua --format hdgrp
--   cd game && lua tools/format_spec.lua --mod pascal

local M = {}

-- 跨平台文件系统原语（Windows 上 io.popen 走 cmd.exe，POSIX 命令不可用）
local Fs = require("framework.fs_compat")

M.REPO_ROOT = ".."
M.MODS_SRC  = M.REPO_ROOT .. "/reference/allmods"

-- ============================================================
-- 基础 IO
-- ============================================================
local function readFile(p)
    -- 走 fs_compat：MOD 源里有中文文件名（如 "不使用.png"），
    -- Windows 的 io.open 打不开这类 UTF-8 路径。
    return Fs.readFile(p)
end
M.readFile = readFile

local function fileSize(p)
    local f = io.open(p, "rb")
    if f then
        local s = f:seek("end")
        f:close()
        return s
    end
    -- 非 ASCII 路径：io.open 失败时用 fs_compat 桥接读取
    if p:find("[\128-\255]") then
        local d = Fs.readFile(p)
        if d then return #d end
    end
    return nil
end
M.fileSize = fileSize

-- uint32 LE
local function u32(d, o)
    if not d or o + 4 > #d then return nil end
    return d:byte(o + 1) + d:byte(o + 2) * 256
         + d:byte(o + 3) * 65536 + d:byte(o + 4) * 16777216
end
M.u32 = u32

local function i32(d, o)
    local v = u32(d, o)
    if not v then return nil end
    if v >= 2147483648 then v = v - 4294967296 end
    return v
end
M.i32 = i32

-- ============================================================
-- offset 表读取（REQ-FMT-1.3）
-- 支持多段：segments = {{offset=字节偏移, count=项数}, ...}
-- ============================================================
function M.readOffsets(idxData, segments)
    local out = {}
    if not idxData then return out end
    if not segments then
        -- 默认：整个文件是一段 uint32 数组
        local n = math.floor(#idxData / 4)
        for i = 0, n - 1 do out[#out + 1] = u32(idxData, i * 4) end
        return out
    end
    for _, seg in ipairs(segments) do
        for i = 0, seg.count - 1 do
            out[#out + 1] = u32(idxData, seg.offset + i * 4)
        end
    end
    return out
end

-- ============================================================
-- 区间物化（REQ-FMT-1.1）
-- 返回 intervals = {{start, stop, name}, ...}
-- ============================================================
function M.materialize(spec, ctx)
    local iv = {}
    if not spec then return iv end

    -- 静态字段
    for _, f in ipairs(spec.fields or {}) do
        local start = f.offset
        local size  = f.size
        if f.size_from then
            size = ctx[f.size_from]
        end
        if start and size then
            iv[#iv + 1] = { start = start, stop = start + size, name = f.name, spec = f }
        end
    end

    -- 动态字段（由 offset 表展开）
    for _, f in ipairs(spec.dynamic or {}) do
        local offs = ctx[f.from]
        if offs then
            local lo = f.index_from or 1
            local hi = f.index_to or #offs
            for i = lo, hi do
                local a = offs[i]
                local b = offs[i + 1]
                if a and b and b > a then
                    iv[#iv + 1] = { start = a, stop = b,
                                    name = string.format("%s[%d]", f.name, i), spec = f }
                end
            end
            -- 末项延伸到 filesize（若声明）
            if f.extend_tail and offs[hi] then
                iv[#iv + 1] = { start = offs[hi], stop = ctx.filesize,
                                name = f.name .. "[tail]", spec = f }
            end
        end
    end

    -- 尾部字段
    if spec.tail then
        local start = spec.tail.offset_from
            and ctx[spec.tail.offset_from]
            or spec.tail.offset
        if start then
            iv[#iv + 1] = { start = start, stop = ctx.filesize,
                            name = spec.tail.name or "tail", spec = spec.tail }
        end
    end

    return iv
end

-- ============================================================
-- 覆盖验证（REQ-FMT-1.2 / REQ-FMT-2）
-- ============================================================
function M.verifyIntervals(intervals, filesize)
    table.sort(intervals, function(a, b)
        if a.start ~= b.start then return a.start < b.start end
        return a.stop < b.stop
    end)

    local gaps, overlaps = {}, {}
    local cursor = 0
    for _, iv in ipairs(intervals) do
        if iv.start > cursor then
            gaps[#gaps + 1] = { start = cursor, ["end"] = iv.start }
        elseif iv.start < cursor then
            overlaps[#overlaps + 1] = {
                start = iv.start, ["end"] = math.min(cursor, iv.stop),
                name = iv.name,
            }
        end
        if iv.stop > cursor then cursor = iv.stop end
    end
    if cursor < filesize then
        gaps[#gaps + 1] = { start = cursor, ["end"] = filesize }
    end

    return {
        ok = (#gaps == 0 and #overlaps == 0),
        gaps = gaps,
        overlaps = overlaps,
        covered = cursor,
        filesize = filesize,
        count = #intervals,
    }
end

-- 统一的「文件缺失」返回值。
--
-- 必须带齐 gaps/overlaps/covered/count 等字段：调用方（测试与 CLI）普遍直接
-- 读 r.gaps、#r.overlaps，若早退分支只返回 {ok,error}，缺文件会从一句清晰的
-- 「缺失 xxx」退化成 nil 索引崩溃（新克隆没有 reference/ 时的实际表现）。
-- @param msg string 错误说明
-- @param extra table|nil 额外字段（如 orphan_idx）
local function missingResult(msg, extra)
    local res = {
        ok = false,
        error = msg,
        gaps = {},
        overlaps = {},
        covered = 0,
        filesize = 0,
        count = 0,
        idx_count = 0,
        idx_tail = 0,
    }
    if extra then
        for k, v in pairs(extra) do res[k] = v end
    end
    return res
end
M.missingResult = missingResult

-- 对单个文件按 spec 验证
function M.verifyCoverage(path, spec, ctxOverride)
    local data = readFile(path)
    if not data then
        return missingResult("cannot read " .. path)
    end
    local ctx = { filesize = #data }
    if ctxOverride then
        for k, v in pairs(ctxOverride) do ctx[k] = v end
    end
    ctx.filesize = #data

    -- 按 spec 需要读取 offset 表
    for name, segs in pairs(spec.offsets or {}) do
        local srcFile = spec.idx_file or path
        local d = (srcFile == path) and data or readFile(srcFile)
        ctx[name] = M.readOffsets(d, segs)
    end

    local iv = M.materialize(spec, ctx)
    local res = M.verifyIntervals(iv, #data)
    res.path = path
    return res
end

-- ============================================================
-- 格式规格表（REQ-FMT-3..5）
-- 每个 spec 形如：
--   { family = "...", files = {"hdgrp.idx"}, offsets = {...}, fields = {...} }
-- 或成对：
--   { family = "...", idx_file = "...", grp_file = "..." }
-- ============================================================

local function F(name, offset, size, needed, consumer)
    return { name = name, offset = offset, size = size,
             needed = needed ~= false, consumer = consumer }
end

local function D(name, from, needed, consumer, opts)
    local d = { name = name, from = from,
                needed = needed ~= false, consumer = consumer }
    if opts then for k, v in pairs(opts) do d[k] = v end end
    return d
end

-- ---- 通用 idx 规格：N × uint32 offset 数组 ----
local function idxSpec(family, consumer, countHint)
    return {
        family = family,
        layout = "uint32_offset_array",
        offsets = { self = nil },  -- 自身即 offset 表
        fields = {
            { name = "offset_entry", dynamic = true,
              needed = true, consumer = consumer,
              unit = 4, count_from = "filesize/4" },
        },
    }
end

-- ---- idx_grp_rle：hdgrp / eft / warfld / cloud / title / fight ----
local function rleGrpSpec(consumer)
    return {
        family = "idx_grp_rle",
        layout = "offset_table_plus_payload",
        offsets = { offs = nil },   -- 由 idx_file 读取
        dynamic = {
            D("rle_record", "offs", true, consumer, { extend_tail = false }),
        },
        tail = { name = "tail", offset_from = nil },  -- 由 offs[last] 决定，见 verifyPair
    }
end

-- ============================================================
-- 成对验证：idx（offset 表）+ grp（payload）
-- ============================================================
-- 规则：idx 的每个 uint32 恰好覆盖 idx 文件本身（4 字节/项），
--       grp 由 offs[i]..offs[i+1] 覆盖，末项延伸到 filesize。
function M.verifyPair(idxPath, grpPath, opts)
    opts = opts or {}
    local idxData = readFile(idxPath)
    if not idxData then
        return missingResult("missing idx: " .. idxPath)
    end
    local grpData = readFile(grpPath)
    if not grpData then
        -- fight/ 下有 .idx 无 .grp 的情况（如 dream）：显式归类为 DEAD_FILE
        return missingResult("missing grp: " .. grpPath, { orphan_idx = true })
    end

    -- 1) idx 自身：必须能被 4 整除（否则有残余字节）
    local idxOk = (#idxData % 4 == 0)
    local n = math.floor(#idxData / 4)

    -- 2) grp：offsets 展开
    local offs = M.readOffsets(idxData, opts.segments)
    local iv = {}
    local firstOff = offs[1]
    if firstOff and firstOff > 0 then
        -- 头部区间（首个 offset 之前）
        iv[#iv + 1] = { start = 0, stop = firstOff, name = "header" }
    end
    for i = 1, n do
        local a = offs[i]
        local b = offs[i + 1] or #grpData
        if a and b and b > a then
            iv[#iv + 1] = { start = a, stop = b,
                            name = string.format("record[%d]", i) }
        end
    end

    local res = M.verifyIntervals(iv, #grpData)
    res.idx_ok = idxOk
    res.idx_count = n
    res.idx_size = #idxData
    res.idx_tail = #idxData - n * 4
    if not idxOk then res.ok = false end
    return res
end

-- ============================================================
-- 定长网格：earth.002 等
-- ============================================================
function M.verifyGrid(path, cellSize, expectedCells)
    local data = readFile(path)
    if not data then return missingResult("missing " .. path) end
    local cells = math.floor(#data / cellSize)
    local iv = {}
    for i = 0, cells - 1 do
        iv[#iv + 1] = { start = i * cellSize, stop = (i + 1) * cellSize,
                        name = "cell[" .. i .. "]" }
    end
    local res = M.verifyIntervals(iv, #data)
    res.cells = cells
    if #data % cellSize ~= 0 then
        res.ok = false
        res.error = string.format("size %d not divisible by %d (rem %d)",
            #data, cellSize, #data % cellSize)
    elseif expectedCells and cells ~= expectedCells then
        res.ok = false
        res.error = string.format("cell count %d != expected %d", cells, expectedCells)
    end
    return res
end

-- ============================================================
-- 定长记录表：war.sta（N × 186，N 随 MOD 变化）
-- ============================================================
function M.verifyFixedRecords(path, recSize)
    local data = readFile(path)
    if not data then return missingResult("missing " .. path) end
    local count = math.floor(#data / recSize)
    local iv = {}
    for i = 0, count - 1 do
        iv[#iv + 1] = { start = i * recSize, stop = (i + 1) * recSize,
                        name = "record[" .. i .. "]" }
    end
    local res = M.verifyIntervals(iv, #data)
    res.records = count
    if #data % recSize ~= 0 then
        -- 尾部残余字节：显式归类为 tail（而非报缺口）
        local rem = #data % recSize
        local tailStart = count * recSize
        iv[#iv + 1] = { start = tailStart, stop = #data, name = "tail" }
        res = M.verifyIntervals(iv, #data)
        res.records = count
        res.tail = rem
    end
    return res
end

-- ============================================================
-- 存档网格：save/allsin.grp（S 层）与 save/alldef.grp（D 层）
-- ============================================================
-- 真实结构（引擎为权威，非推测）：
--   S 层：s_size = SWidth * SHeight * 6 * SceneNum   字节 = uint16 数 × 2
--   D 层：d_size = DNum   * 11      * SceneNum   字节 = uint16 数 × 2
--   两者均由 Byte.LoadToTable16 一次性定长载入（lib_love.lua:899/904）。
--
-- verifyGrid 只能校验“能被 cell 整除”，**不能**验证几何自洽。
-- 这里额外做两件事（才有鉴别力）：
--   1. 反推出的场景数必须是**正整数**且字节数**完全守恒**（无 tail）；
--   2. 可选交叉校验：传入 otherScenes 时，两独立公式算出的场景数必须相等。
--      因为 allsin 与 alldef 的维度因子完全不同（64*64*6=24576 vs
--      200*11=2200），两者同时凑出同一个整数 N 的概率极低，
--      故这是一个**强判别**（非“数量相等代替集合相等”）。
function M.verifySaveGrid(path, grid)
    local data = readFile(path)
    if not data then return missingResult("missing " .. path) end
    local bytes = #data
    local unit                            -- 单个“场景单元”的字节数
    local cellsPerScene                   -- 每场景 uint16 单元数
    if grid.x then
        cellsPerScene = grid.x * grid.y * grid.levels
        unit = cellsPerScene * 2
    elseif grid.dnum then
        cellsPerScene = grid.dnum * grid.dnum2
        unit = cellsPerScene * 2
    else
        return { ok = false, error = "grid spec missing x/levels or dnum/dnum2" }
    end

    -- 1) 整除性（含 tail 显式报告）
    local rem = bytes % unit
    local scenes = math.floor(bytes / unit)

    -- 2) 区间完整覆盖（每场景一个区间，不允许 tail）
    local iv = {}
    for i = 0, scenes - 1 do
        iv[#iv + 1] = { start = i * unit, stop = (i + 1) * unit,
                        name = "scene[" .. i .. "]" }
    end
    local res = M.verifyIntervals(iv, bytes)
    res.scenes = scenes
    res.scene_bytes = unit
    res.cells_per_scene = cellsPerScene
    res.tail = rem
    res.bytes = bytes

    if rem ~= 0 then
        res.ok = false
        res.error = string.format(
            "size %d not a multiple of scene size %d (rem %d); " ..
            "grid formula %d cells/scene is wrong for this file",
            bytes, unit, rem, cellsPerScene)
    elseif scenes == 0 then
        res.ok = false
        res.error = "zero scenes"
    end
    return res
end

-- ============================================================
-- 调色板：mmap.col（768 = 256 × RGB）
-- ============================================================
function M.verifyPalette(path)
    local data = readFile(path)
    if not data then return missingResult("missing " .. path) end
    local iv = {}
    for i = 0, 255 do
        iv[#iv + 1] = { start = i * 3, stop = i * 3 + 3, name = "rgb[" .. i .. "]" }
    end
    local res = M.verifyIntervals(iv, #data)
    res.colors = 256
    if #data ~= 768 then res.ok = false; res.error = "size != 768" end
    return res
end

-- ============================================================
-- 文本文件：按行区间覆盖
-- ============================================================
function M.verifyText(path)
    local data = readFile(path)
    if not data then return missingResult("missing " .. path) end
    local iv = {}
    local o = 0
    local i = 0
    while o < #data do
        local nl = data:find("\n", o + 1, true)
        local stop = nl and nl or #data
        i = i + 1
        iv[#iv + 1] = { start = o, stop = stop, name = "line[" .. i .. "]" }
        o = stop
    end
    local res = M.verifyIntervals(iv, #data)
    res.lines = i
    return res
end

-- ============================================================
-- WAV：RIFF chunk 遍历
-- ============================================================
function M.verifyWav(path)
    local d = readFile(path)
    if not d then return missingResult("missing " .. path) end
    if #d == 0 then
        -- 空文件：显式归类（RiverLake 有 28 个声明但空白的 wav）
        return { ok = true, empty = true, chunks = 0, covered = 0, filesize = 0 }
    end
    if d:sub(1, 4) ~= "RIFF" then
        return { ok = false, error = "no RIFF (magic=" .. d:sub(1, 4):gsub("%c", "?") .. ")" }
    end
    local iv = { { start = 0, stop = 12, name = "RIFF_header" } }
    local o = 12
    local i = 0
    local sawData = false
    -- 不因 data 而 break：部分 MOD 在 data 之后还有 LIST/INFO 元数据块
    while o + 8 <= #d do
        local id = d:sub(o + 1, o + 4)
        local sz = u32(d, o + 4)
        if not sz then break end
        local adv = 8 + sz + (sz % 2)
        i = i + 1
        iv[#iv + 1] = { start = o, stop = math.min(o + adv, #d),
                        name = "chunk[" .. i .. "]:" .. id }
        o = o + adv
        if id == "data" then sawData = true end
    end
    local res = M.verifyIntervals(iv, #d)
    res.chunks = i
    res.saw_data = sawData
    return res
end

-- ============================================================
-- PNG：签名 + chunk 遍历
-- ============================================================
local PNG_SIG = "\137PNG\r\n\26\n"
M.PNG_SIG = PNG_SIG

function M.verifyPng(path)
    local d = readFile(path)
    if not d then return missingResult("missing " .. path) end
    if d:sub(1, 8) ~= PNG_SIG then
        return { ok = false, error = "bad signature" }
    end
    local iv = { { start = 0, stop = 8, name = "signature" } }
    local o = 8
    local i = 0
    while o + 8 <= #d do
        local sz = d:byte(o + 1) * 16777216 + d:byte(o + 2) * 65536
                 + d:byte(o + 3) * 256 + d:byte(o + 4)
        local id = d:sub(o + 5, o + 8)
        local adv = 12 + sz
        i = i + 1
        iv[#iv + 1] = { start = o, stop = math.min(o + adv, #d),
                        name = "chunk[" .. i .. "]:" .. id }
        o = o + adv
        if id == "IEND" then break end
    end
    local res = M.verifyIntervals(iv, #d)
    res.chunks = i
    return res
end

-- ============================================================
-- ranger 分段：6 段 offset 表 + 段记录
-- 布局（记录大小）随 MOD 变化，从 offset 表推导
-- ============================================================
M.RANGER_VANILLA = { 202, 260, 62, 146, 30 }
M.RANGER_MOD     = { 182, 190, 52, 136, 50 }

function M.verifyRanger(idxPath, grpPath)
    local idxData = readFile(idxPath)
    local grpData = readFile(grpPath)
    if not idxData or not grpData then
        return missingResult("missing file")
    end
    if #idxData ~= 24 then
        return { ok = false, error = "ranger.idx size != 24 (got " .. #idxData .. ")" }
    end

    local offs = {}
    for i = 0, 5 do offs[#offs + 1] = u32(idxData, i * 4) end

    local iv = { { start = 0, stop = offs[1], name = "header" } }
    for i = 1, 5 do
        iv[#iv + 1] = { start = offs[i], stop = offs[i + 1],
                        name = "seg" .. i }
    end
    local res = M.verifyIntervals(iv, #grpData)

    -- 推导记录大小（delta / count），两种布局都验证
    res.segments = {}
    for i = 1, 5 do
        local delta = offs[i + 1] - offs[i]
        local vRec = M.RANGER_VANILLA[i]
        local mRec = M.RANGER_MOD[i]
        res.segments[i] = {
            delta = delta,
            vanilla_count = delta / vRec,
            mod_count = delta / mRec,
        }
    end
    res.offsets = offs
    return res
end

-- ============================================================
-- 格式族注册表（供 --all 遍历）
-- ============================================================
-- 每项：{ name, kind, idx, grp, ... }
M.FORMATS = {
    { name = "hdgrp",   family = "idx_grp_rle", idx = "resource/hdgrp.idx",   grp = "resource/hdgrp.grp",
      consumer = "lib_love.PicLoadFile" },
    { name = "eft",     family = "idx_grp_rle", idx = "resource/eft.idx",     grp = "resource/eft.grp",
      consumer = "lib_love.PicLoadFile" },
    { name = "warfld",  family = "idx_grp_rle", idx = "resource/warfld.idx",  grp = "resource/warfld.grp",
      consumer = "lib_love.PicLoadFile" },
    { name = "cloud",   family = "idx_grp_rle", idx = "resource/cloud.idx",   grp = "resource/cloud.grp",
      consumer = "lib_love.PicLoadFile" },
    { name = "title",   family = "idx_grp_rle", idx = "resource/title.idx",   grp = "resource/title.grp",
      consumer = "lib_love.PicLoadFile" },
    { name = "mmap",    family = "idx_grp_rle", idx = "resource/mmap.idx",    grp = "resource/mmap.grp",
      consumer = "lib_love.PicLoadFile", segments = { { offset = 0, count = 3731 } } },
    { name = "talk",    family = "idx_grp_text", idx = "resource/talk.idx",   grp = "resource/talk.grp",
      consumer = "jymain.ReadTalk" },
    -- kdef 是「构建期」消费：mod_build.lua:892 的 local function extractKdef
    -- 把 kdef.grp 的字节码翻译成事件脚本（ove/）。运行时不再读 kdef.*。
    -- 注意 extractKdef 是 local，不是 mod_build 的导出字段。
    { name = "kdef",    family = "idx_grp_bytecode", idx = "resource/kdef.idx", grp = "resource/kdef.grp",
      consumer = "mod_build.extractKdef (build-time，local 函数)" },
    { name = "smap",    family = "bare_idx_grp", idx = "resource/sdx",        grp = "resource/smp",
      consumer = "lib_love.LoadSMap" },
    { name = "wmap",    family = "bare_idx_grp", idx = "resource/wdx",        grp = "resource/wmp",
      consumer = "lib_love.LoadWarMap" },
    { name = "ranger",  family = "ranger_seg",   idx = "save/ranger.idx",     grp = "save/ranger.grp",
      consumer = "jymain.LoadRecord" },
    -- save_slot 族（存档槽 s1..3 / d1..3，[1..3] 指标）：
    -- 与 ranger 同构（uint32 offset 表 + 分段负载），复用 verifyPair。
    -- 仅 books / pig3dos / pineapple 等少数 MOD 提供，故 optional。
    { name = "save_r1", family = "save_slot",    idx = "save/r1.idx",         grp = "save/r1.grp",
      consumer = "jymain.LoadRecord(R_IDXFilename[1])", optional = true },
    { name = "save_r2", family = "save_slot",    idx = "save/r2.idx",         grp = "save/r2.grp",
      consumer = "jymain.LoadRecord(R_IDXFilename[2])", optional = true },
    { name = "save_r3", family = "save_slot",    idx = "save/r3.idx",         grp = "save/r3.grp",
      consumer = "jymain.LoadRecord(R_IDXFilename[3])", optional = true },
    { name = "save_s1", family = "save_slot",    idx = "save/s1.idx",         grp = "save/s1.grp",
      consumer = "jymain.LoadRecord(S_Filename[1])", optional = true },
    { name = "save_s2", family = "save_slot",    idx = "save/s2.idx",         grp = "save/s2.grp",
      consumer = "jymain.LoadRecord(S_Filename[2])", optional = true },
    { name = "save_s3", family = "save_slot",    idx = "save/s3.idx",         grp = "save/s3.grp",
      consumer = "jymain.LoadRecord(S_Filename[3])", optional = true },
    { name = "save_d1", family = "save_slot",    idx = "save/d1.idx",         grp = "save/d1.grp",
      consumer = "jymain.LoadRecord(D_Filename[1])", optional = true },
    { name = "save_d2", family = "save_slot",    idx = "save/d2.idx",         grp = "save/d2.grp",
      consumer = "jymain.LoadRecord(D_Filename[2])", optional = true },
    { name = "save_d3", family = "save_slot",    idx = "save/d3.idx",         grp = "save/d3.grp",
      consumer = "jymain.LoadRecord(D_Filename[3])", optional = true },
}

M.SIMPLE_FORMATS = {
    { name = "earth",    kind = "grid",    file = "resource/earth.002",    cell = 2, cells = 230400,
      consumer = "lib_love.LoadMMap_Sub", allow_tail = true },
    { name = "surface",  kind = "grid",    file = "resource/surface.002",  cell = 2, cells = 230400,
      consumer = "lib_love.LoadMMap_Sub", allow_tail = true },
    { name = "building", kind = "grid",    file = "resource/building.002", cell = 2, cells = 230400,
      consumer = "lib_love.LoadMMap_Sub", allow_tail = true },
    { name = "buildx",   kind = "grid",    file = "resource/buildx.002",   cell = 2, cells = 230400,
      consumer = "lib_love.LoadMMap_Sub", allow_tail = true },
    { name = "buildy",   kind = "grid",    file = "resource/buildy.002",   cell = 2, cells = 230400,
      consumer = "lib_love.LoadMMap_Sub", allow_tail = true },
    { name = "war",      kind = "fixed",   file = "resource/war.sta",      rec = 186,
      consumer = "jymain.WarLoad" },
    { name = "palette",  kind = "palette", file = "resource/mmap.col",
      consumer = "lib_love.LoadMMap" },
    { name = "kysmod",   kind = "text",    file = "kysmod.ini",
      consumer = "framework.mod_ini" },
    -- ============================================================
    -- save_grid 族（allsin / alldef）：**定长 uint16 网格**，非 offset 表
    -- ============================================================
    -- 引擎证据（不是推测）：
    --   jymain.lua:1835  lib.LoadSMap(sFile, TempS, JY.SceneNum, CC.SWidth,
    --                                  CC.SHeight, dFile, CC.DNum, 11)
    --   lib_love.lua:898 s_size = S_XMax*S_YMax*6*S_Num
    --   lib_love.lua:899 Byte.LoadToTable16(Sfilename, s_size, 0, true)
    --   lib_love.lua:903 d_size = D_Num1*D_Num2*S_Num
    --   lib_love.lua:904 Byte.LoadToTable16(Dfilename, d_size, 0, true)
    -- ⇒ 直接按 (维度 × 场景数) 定长直读，**完全不读 .idx**。
    --
    -- 实测对账（pascal）：
    --   allsin.grp = 64*64*6*100*2 = 4,915,200 = 文件实际字节 ✅
    --   alldef.grp = 200*11*100*2 =   440,000 = 文件实际字节 ✅
    --
    -- save/allsin.idx / alldef.idx 是编辑器副产物（步长恒为单场景字节的
    -- end-offset 表，pascal 84 项只覆盖 100 个场景中的 84 个），引擎零消费，
    -- 因此**不能**用 verifyPair（那会把首 49152 B 误当 header、末 786432 B
    -- 误当“末项延伸”，从而给出语义错误的 ok=true）。
    -- 改用 verifyGrid：单场景字节随 MOD 变化，故不硬编码，由验证器反推并校验。
    { name = "allsin",   kind = "grid_save", file = "save/allsin.grp",
      consumer = "lib_love.LoadSMap", grid = { x = 64, y = 64, levels = 6 },
      optional = true },
    { name = "alldef",   kind = "grid_save", file = "save/alldef.grp",
      consumer = "lib_love.LoadSMap", grid = { dnum = 200, dnum2 = 11 },
      optional = true },
}

-- ============================================================
-- 批量验证（REQ-FMT-6）
-- ============================================================
local function listModDirs()
    local out = {}
    -- 枚举 <MODS_SRC>/kys-* 目录（跨平台，不依赖 ls）
    if not Fs.directoryExists(M.MODS_SRC) then return out end
    for _, name in ipairs(Fs.listDirectory(M.MODS_SRC)) do
        if name:match("^kys%-.+") and Fs.directoryExists(M.MODS_SRC .. "/" .. name) then
            out[#out + 1] = M.MODS_SRC .. "/" .. name
        end
    end
    table.sort(out)
    return out
end

function M.verifyAll(opts)
    opts = opts or {}
    local mods = listModDirs()
    local results = {}
    local total, gaps = 0, 0

    for _, modDir in ipairs(mods) do
        local slug = modDir:match("([^/]+)$"):gsub("^kys%-", "")
        if not opts.mod or opts.mod == slug then
            -- 成对格式
            for _, f in ipairs(M.FORMATS) do
                if not opts.format or opts.format == f.name then
                    -- optional 格式：源侧本身不提供时跳过（不计 gap、不计 checked）
                    if f.optional and not fileSize(modDir .. "/" .. f.idx) then
                        -- 缺失即设计预期，不产生记录（由 ABSENT_EXPECTED / 审计器负责证据）
                    else
                    local res = M.verifyPair(modDir .. "/" .. f.idx,
                                             modDir .. "/" .. f.grp,
                                             { segments = f.segments })
                    -- 有 idx 无 grp：MOD 打包残留（如 HeavenSword 的 r1.idx
                    -- 与 ranger.idx 字节相同、真数据在 ranger.grp）。
                    -- 与 fight/ 一致，归为 ORPHAN_IDX 而不算缺口。
                    if res.orphan_idx and f.optional then
                        res.ok = true
                        res.category = "ORPHAN_IDX"
                        res.dead_file = true
                    end
                    total = total + 1
                    if not res.ok then gaps = gaps + 1 end
                    res.mod = slug; res.format = f.name; res.family = f.family
                    results[#results + 1] = res
                    end
                end
            end
            -- 简单格式
            for _, f in ipairs(M.SIMPLE_FORMATS) do
                if not opts.format or opts.format == f.name then
                    local path = modDir .. "/" .. f.file
                    if fileSize(path) then
                        local res
                        if f.kind == "grid" then
                            res = M.verifyGrid(path, f.cell, f.cells)
                            if res and f.allow_tail and #(readFile(path) or "") % f.cell ~= 0 then
                                -- 尾部残余字节：显式归类，不报缺口
                                local data = readFile(path)
                                local cells = math.floor(#data / f.cell)
                                local iv = {}
                                for i = 0, cells - 1 do
                                    iv[#iv + 1] = { start = i * f.cell,
                                                    stop = (i + 1) * f.cell,
                                                    name = "cell[" .. i .. "]" }
                                end
                                iv[#iv + 1] = { start = cells * f.cell, stop = #data,
                                                name = "tail" }
                                res = M.verifyIntervals(iv, #data)
                                res.cells = cells
                                res.tail = #data - cells * f.cell
                            end
                        elseif f.kind == "fixed" then
                            res = M.verifyFixedRecords(path, f.rec)
                        elseif f.kind == "grid_save" then
                            res = M.verifySaveGrid(path, f.grid)
                        elseif f.kind == "palette" then
                            res = M.verifyPalette(path)
                        elseif f.kind == "text" then
                            res = M.verifyText(path)
                        end
                        if res then
                            total = total + 1
                            if not res.ok then gaps = gaps + 1 end
                            res.mod = slug; res.format = f.name; res.family = f.kind
                            results[#results + 1] = res
                        end
                    end
                end
            end
        end
    end

    -- ---------------------------------------------------------
    -- 交叉校验：allsin 与 alldef 反推出的场景数必须相等
    -- ---------------------------------------------------------
    -- 两文件维度因子完全不同（24576 vs 2200 个 uint16/场景），
    -- 若网格公式错了，几乎不可能同时凑出同一整数。
    local byMod = {}
    for _, r in ipairs(results) do
        if r.format == "allsin" or r.format == "alldef" then
            byMod[r.mod] = byMod[r.mod] or {}
            byMod[r.mod][r.format] = r
        end
    end
    for mod, pair in pairs(byMod) do
        if pair.allsin and pair.alldef and pair.allsin.ok and pair.alldef.ok then
            if pair.allsin.scenes ~= pair.alldef.scenes then
                pair.allsin.ok = false
                pair.alldef.ok = false
                pair.allsin.error = string.format(
                    "scene count mismatch: allsin=%d alldef=%d",
                    pair.allsin.scenes, pair.alldef.scenes)
                pair.alldef.error = pair.allsin.error
                gaps = gaps + 2
            else
                pair.allsin.cross_checked = true
                pair.alldef.cross_checked = true
            end
        end
    end

    return results, total, gaps
end

-- 全量验证（结构化 + 多文件族）
function M.verifyEverything(opts)
    opts = opts or {}
    local r1, t1, g1 = M.verifyAll(opts)
    local r2, t2, g2 = M.verifyMultiFile(opts)
    local results = {}
    for _, r in ipairs(r1) do results[#results + 1] = r end
    for _, r in ipairs(r2) do results[#results + 1] = r end
    return results, t1 + t2, g1 + g2
end

-- list/*.bin：C 引擎事件表（Lua 引擎未接入，PENDING）
-- 记录结构未定：按 4 字节单元覆盖（最大公约数），残余字节显式归入 tail。
-- 目的：即使结构未定，也保证“每个字节都被归类”。
-- list/*.bin：定长 uint16 记录数组（REQ-LBIN-3）。
-- 语义证据：effect.bin = 逐效果帧数表（sum == eft.idx 段数，全 20 MOD 中 14 精确成立）；
-- match.bin = 武器/武功/攻击力三元组（CC.ExtraOffense）；
-- leave.bin / levelup.bin 同为 uint16 数组。故记录单位 = 2 字节，不是 4。
-- 奇数字节必须显式报 gap——原先按 4 字节切分会把 1~3 字节尾部静默归给 "tail"，
-- 对一个「uint16 数组」而言这是错的口径。
function M.verifyBinTable(path)
    local d = readFile(path)
    if not d then return missingResult("missing " .. path) end
    local unit = 2
    local n = math.floor(#d / unit)
    local iv = {}
    for i = 0, n - 1 do
        iv[#iv + 1] = { start = i * unit, stop = (i + 1) * unit,
                        name = "u16[" .. i .. "]" }
    end
    local res = M.verifyIntervals(iv, #d)
    res.records = n
    res.tail = #d - n * unit
    res.unit = unit
    -- 空文件对一个 uint16 记录表无意义（0 条记录不能被当作「完整覆盖」）。
    -- 必须显式判失败，否则「零字节」与「全部被验证」无法区分。
    if n == 0 then
        res.ok = false
        res.error = "empty file (0 records)"
    end
    return res
end

-- ============================================================
-- 多文件族：fight/*、sound/*、head/*
-- ============================================================
local function listFiles(dir, pattern)
    -- 只列文件名（不含子目录），跨平台
    return Fs.listFiles(dir, pattern)
end
M.listFiles = listFiles

-- fight/ 每个 .idx 配一个同名 .grp；返回逐对结果 + 孤儿文件列表
function M.verifyFightDir(modDir)
    local dir = modDir .. "/fight"
    local idxs = listFiles(dir, "%.idx$")
    local grps = listFiles(dir, "%.grp$")
    local results, orphans = {}, {}

    local grpSet = {}
    for _, g in ipairs(grps) do grpSet[g:gsub("%.grp$", "")] = true end
    local idxSet = {}
    for _, x in ipairs(idxs) do idxSet[x:gsub("%.idx$", "")] = true end

    for _, x in ipairs(idxs) do
        local base = x:gsub("%.idx$", "")
        local res = M.verifyPair(dir .. "/" .. base .. ".idx",
                                 dir .. "/" .. base .. ".grp")
        res.name = base
        results[#results + 1] = res
    end
    for _, g in ipairs(grps) do
        local base = g:gsub("%.grp$", "")
        if not idxSet[base] then orphans[#orphans + 1] = g end
    end
    return results, orphans
end

-- sound/ 全部 wav 验证
function M.verifySoundDir(modDir)
    local dir = modDir .. "/sound"
    local wavs = listFiles(dir, "%.wav$")
    local results = {}
    for _, w in ipairs(wavs) do
        local res = M.verifyWav(dir .. "/" .. w)
        res.name = w
        results[#results + 1] = res
    end
    return results
end

-- 给定目录下全部 PNG 验证
function M.verifyPngDir(dir)
    local pngs = listFiles(dir, "%.png$")
    local results = {}
    for _, w in ipairs(pngs) do
        local res = M.verifyPng(dir .. "/" .. w)
        res.name = w
        results[#results + 1] = res
    end
    return results
end

-- 多文件族批量（REQ-FMT-6）
function M.verifyMultiFile(opts)
    opts = opts or {}
    local mods = listModDirs()
    local results, total, bad = {}, 0, 0
    local function push(r)
        total = total + 1
        if not r.ok then bad = bad + 1 end
        results[#results + 1] = r
    end

    for _, modDir in ipairs(mods) do
        local slug = modDir:match("([^/]+)$"):gsub("^kys%-", "")
        if not opts.mod or opts.mod == slug then
            if not opts.format or opts.format == "fight" then
                local rs, orphans = M.verifyFightDir(modDir)
                for _, r in ipairs(rs) do
                    -- 孤儿 idx（无配对 grp）属已知死文件，归入 ORPHAN_IDX 而非缺口
                    if r.orphan_idx then
                        r.ok = true
                        r.category = "ORPHAN_IDX"
                        r.dead_file = true
                    end
                    r.mod = slug; r.format = "fight"; r.family = "idx_grp_rle"
                    push(r)
                end
                for _, g in ipairs(orphans) do
                    push({ mod = slug, format = "fight", family = "idx_grp_rle",
                           name = g, ok = true, category = "ORPHAN_GRP", dead_file = true })
                end
            end
            if not opts.format or opts.format == "sound" then
                for _, r in ipairs(M.verifySoundDir(modDir)) do
                    r.mod = slug; r.format = "sound"; r.family = "wav_pcm"
                    push(r)
                end
            end
            if not opts.format or opts.format == "png" then
                for _, sub in ipairs({ "head", "item", "eft", "resource" }) do
                    for _, r in ipairs(M.verifyPngDir(modDir .. "/" .. sub)) do
                        r.mod = slug; r.format = "png"; r.family = "png_image"
                        push(r)
                    end
                end
            end
            if not opts.format or opts.format == "list" then
                for _, b in ipairs(M.listFiles(modDir .. "/list", "%.bin$")) do
                    local r = M.verifyBinTable(modDir .. "/list/" .. b)
                    r.name = b; r.mod = slug; r.format = "list"
                    r.family = "bin_table"
                    push(r)
                end
            end
        end
    end
    return results, total, bad
end

-- ============================================================
-- CLI
-- ============================================================
local function main(args)
    local opts = {}
    for i, a in ipairs(args) do
        if a == "--mod" then opts.mod = args[i + 1]
        elseif a == "--format" then opts.format = args[i + 1] end
    end

    local results, total, gaps = M.verifyEverything(opts)

    -- 统计格式族
    local fams = {}
    for _, r in ipairs(results) do fams[r.family or "?"] = true end
    local nfam = 0
    for _ in pairs(fams) do nfam = nfam + 1 end

    local failed = {}
    for _, r in ipairs(results) do
        if not r.ok then failed[#failed + 1] = r end
    end

    print(string.format("formats=%d checked=%d gaps=%d",
        nfam, total, #failed))
    for _, r in ipairs(failed) do
        local detail = r.error or ""
        if r.gaps and #r.gaps > 0 then
            detail = string.format("gaps=%d 首个=[%d,%d)",
                #r.gaps, r.gaps[1].start, r.gaps[1]["end"])
        elseif r.overlaps and #r.overlaps > 0 then
            detail = string.format("overlaps=%d 首个=[%d,%d) %s",
                #r.overlaps, r.overlaps[1].start, r.overlaps[1]["end"],
                tostring(r.overlaps[1].name))
        end
        print(string.format("  [FAIL] %-14s %-12s %s", r.mod, r.format, detail))
    end

    if #failed > 0 then os.exit(1) end
    os.exit(0)
end

if arg and arg[0] and arg[0]:match("format_spec") then
    main(arg)
end

return M
