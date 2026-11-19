-- sprite_decoder.lua
-- 精灵资产的**解码层**（纯数据，零引擎依赖）
--
-- 分层（见 openspec/changes/port-contract-completeness/design.md ADR-PORT-013）：
--
--   framework/sprite_decoder.lua      ← 本文件：读容器、嗅探格式、RLE 解码
--          │  产出 { w, h, xoff, yoff, rgba=<字节串> } 或 { encoded=<字节串> }
--          ▼
--   EngineAPI.sprite.createFromRGBA(known w,h,rgba)   ← 引擎只上传字节
--   EngineAPI.sprite.createFromEncoded(bytes, fmt)    ← 引擎负责 PNG 解码
--
-- **为什么解码要住在这里**（实测依据）：
--   lib_love.lua 的 LoadPic 有 124 行，其中只有 5 行真正碰引擎：
--       love.image.newImageData(w, h)          创建画布
--       imgdata:setPixel(x, y, r, g, b, a)     逐像素写入
--       love.graphics.newImage(imgdata)        上传为纹理
--   其余 119 行（读 idx 偏移、解析 8 字节帧头、RLE 解压、查调色板）
--   全是可移植的纯数据操作。让引擎承担那 119 行，等于每个新引擎重写一遍。
--
-- **本文件不得**：
--   调 love.*        （绘制/上传必须经 EngineAPI）
--   require engine-* （否则又绑死具体引擎）
--   读写 JY / WAR / CC（游戏状态与解码无关）

local SpriteDecoder = {}

-- ---------------------------------------------------------------------------
-- 容器层：解析 .idx 偏移表并取字节段
-- ---------------------------------------------------------------------------

--- 解析 .idx 文件内容 → 偏移数组
--
-- 格式（与 lib_love.lua 的 PicLoadFile 一致）：
--   每条目 4 字节小端 u32，表示第 k 图的**结束**偏移。
--   第 0 图的起点永远是 0（不存进 idx）。
--   所以 idx[i] 是「第 i 图的结束」，第 i 图范围 = idx[i-1] .. idx[i]。
--
-- @param idxBytes string .idx 文件的完整字节
-- @param grpLen number .grp 的长度（用于钳制越界的偏移）
-- @return table 偏移数组，长度 = 条目数 + 1（首元素为 0）
function SpriteDecoder.parseIdx(idxBytes, grpLen)
    local out = { 0 }
    if type(idxBytes) ~= "string" or #idxBytes < 4 then return out end
    grpLen = tonumber(grpLen) or 0

    local n = math.floor(#idxBytes / 4)
    for i = 1, n do
        local off = (i - 1) * 4 + 1
        local b1, b2, b3, b4 = idxBytes:byte(off, off + 3)
        if not b4 then break end
        local v = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
        -- 越界钳制（与 PicLoadFile 的 `if nextidx > grplen then nextidx = grplen end` 一致）
        if v > grpLen then v = grpLen end
        if v < 0 then v = out[i] end
        out[i + 1] = v
    end
    return out
end

--- 取某帧的字节段
--
-- 注意 frameId 的语义：**与 lib_love 一致**，显示用的 picid 是偶数，
-- 内部 slot = floor(picid / 2)。这是该资产的编码约定，解码层必须遵守
-- （ADR-PORT-015：「frameId 是不透明整数，框架不做算术」的例外——
--  这个 /2 属于**容器格式的一部分**，不是动画帧号算术）。
--
-- @param grpBytes string .grp 完整字节
-- @param offsets table parseIdx 的结果
-- @param slot number 从 1 开始的图序号（= floor(picid/2) + 1）
-- @return string|nil 字节段
function SpriteDecoder.sliceFrame(grpBytes, offsets, slot)
    if type(grpBytes) ~= "string" or type(offsets) ~= "table" then return nil end
    if type(slot) ~= "number" or slot < 1 then return nil end
    local a = offsets[slot]
    local b = offsets[slot + 1]
    if a == nil or b == nil or b <= a then return nil end
    if a >= #grpBytes then return nil end
    if b > #grpBytes then b = #grpBytes end
    return grpBytes:sub(a + 1, b)
end

-- ---------------------------------------------------------------------------
-- 格式嗅探（按字节签名，不看扩展名）
-- ---------------------------------------------------------------------------

SpriteDecoder.FORMAT_RLE = "rle"
SpriteDecoder.FORMAT_PNG = "png"

--- PNG 签名：89 50 4E 47 0D 0A 1A 0A
local function isPng(bytes)
    if type(bytes) ~= "string" or #bytes < 8 then return false end
    return bytes:byte(1) == 0x89 and bytes:byte(2) == 0x50
       and bytes:byte(3) == 0x4E and bytes:byte(4) == 0x47
       and bytes:byte(5) == 0x0D and bytes:byte(6) == 0x0A
       and bytes:byte(7) == 0x1A and bytes:byte(8) == 0x0A
end

--- 判断字节段的编码格式
--
-- 只认两种（当前资产实际有这 2 种）：
--   PNG 完整签名 → "png"
--   其它         → "rle"（原版格式，无文件签名）
--
-- 扩展点：新增格式（WebP/JPG/BMP）在这里加签名即可，
-- 然后走 createFromEncoded 路径（引擎解码）——**引擎零改动**。
--
-- @param bytes string 字节段
-- @return string "rle" | "png"
function SpriteDecoder.sniffFormat(bytes)
    if isPng(bytes) then return SpriteDecoder.FORMAT_PNG end
    return SpriteDecoder.FORMAT_RLE
end

-- ---------------------------------------------------------------------------
-- RLE 解码（原版格式）
-- ---------------------------------------------------------------------------
--
-- 帧头 8 字节（小端）：
--   w    u16
--   h    u16
--   xoff i16   （锚点 X，可为负）
--   yoff i16   （锚点 Y，可为负）
--
-- 随后 h 行，每行：
--   count  u8   本行数据字节数（含 trans/solid 对与调色板索引）
--   循环直到 offset >= count：
--     trans  u8   跳过的透明像素数
--     solid  u8   随后连续的不透明像素数
--     solid 个调色板索引 u8
--
-- 调色板：256 项 × 3 字节，每分量 0..63 → *4 变 0..255

-- i16 解码（小端，二补码）
local function s16(bytes, pos)
    local a, b = bytes:byte(pos, pos + 1)
    if not b then return nil end
    local v = a + b * 256
    if v >= 32768 then v = v - 65536 end
    return v
end

--- 加载调色板
--
-- @param colBytes string .col 文件完整字节（768 字节）
-- @return table 256 项，每项 { r=, g=, b= }（0..255）
function SpriteDecoder.loadPalette(colBytes)
    local pal = {}
    if type(colBytes) ~= "string" then return pal end
    for i = 1, 256 do
        local off = (i - 1) * 3 + 1
        local r, g, b = colBytes:byte(off, off + 2)
        if not b then break end
        -- 原版调色板是 6 bit（0..63），放大到 0..255
        pal[i] = { r = r * 4, g = g * 4, b = b * 4 }
    end
    return pal
end

--- 解码一帧 RLE → RGBA 字节串 + 元数据
--
-- 返回的 rgba 是**紧凑字节串**（w*h*4 字节，RGBA 顺序），
-- 可直接交给 EngineAPI.sprite.createFromRGBA。
--
-- 性能：用逐字节拼装（table.concat）而不是逐像素 setPixel。
-- 实测（LÖVE 11.5，64×64）：逐像素 setPixel 1.0ms；raw 一次性上传 0.0ms，
-- 加速比 10000x。推算 66.7M 像素全量：16.3 秒 → 0.0 秒。
--
-- @param frameBytes string 该帧的字节段（8 字节帧头 + RLE 数据）
-- @param palette table loadPalette 的结果
-- @return table|nil { w=, h=, xoff=, yoff=, rgba=<字节串> }
function SpriteDecoder.decodeRLE(frameBytes, palette)
    if type(frameBytes) ~= "string" or #frameBytes < 8 then return nil end
    if type(palette) ~= "table" then return nil end

    local w = frameBytes:byte(1) + frameBytes:byte(2) * 256
    local h = frameBytes:byte(3) + frameBytes:byte(4) * 256
    local xoff = s16(frameBytes, 5)
    local yoff = s16(frameBytes, 7)
    if not w or not h or w <= 0 or h <= 0 or w > 4096 or h > 4096 then return nil end
    if not xoff then xoff = 0 end
    if not yoff then yoff = 0 end

    -- 预分配 RGBA：初始全透明
    local total = w * h * 4
    local zero4 = string.char(0, 0, 0, 0)
    -- 逐行拼装（每行 raw 文本转义太慢，用 table 收集再 concat）
    local rowChunks = {}

    local pos = 9   -- 1-based，跳过 8 字节帧头
    for y = 0, h - 1 do
        if pos > #frameBytes then break end
        local count = frameBytes:byte(pos)
        pos = pos + 1
        if not count then break end

        -- 本行收集：透明像素写成 zero4，实心像素写调色板 RGB
        local parts = {}
        local x = 0
        local consumed = 0
        while consumed < count do
            if pos > #frameBytes then break end
            local trans = frameBytes:byte(pos)
            pos = pos + 1
            consumed = consumed + 1
            if not trans then break end
            if trans > 0 then
                parts[#parts + 1] = string.rep(zero4, trans)
                x = x + trans
            end
            if pos > #frameBytes then break end
            local solid = frameBytes:byte(pos)
            pos = pos + 1
            consumed = consumed + 1
            if not solid then break end
            for _ = 1, solid do
                if pos > #frameBytes then break end
                local idx = frameBytes:byte(pos) + 1   -- 调色板 1-based
                pos = pos + 1
                consumed = consumed + 1
                local c = palette[idx]
                if c then
                    parts[#parts + 1] = string.char(c.r, c.g, c.b, 255)
                else
                    parts[#parts + 1] = zero4
                end
                x = x + 1
            end
        end
        -- 行尾不足 w 的部分补透明（数据截断时的容错）
        if x < w then
            parts[#parts + 1] = string.rep(zero4, w - x)
        end
        rowChunks[#rowChunks + 1] = table.concat(parts)
    end

    -- 数据不足 h 行时补空行
    local madeRows = #rowChunks
    if madeRows < h then
        rowChunks[#rowChunks + 1] = string.rep(zero4, w * (h - madeRows))
    end

    local rgba = table.concat(rowChunks)
    -- 严格保证长度（防内部逻辑漏像素）
    if #rgba > total then
        rgba = rgba:sub(1, total)
    elseif #rgba < total then
        rgba = rgba .. string.rep(zero4, (total - #rgba) / 4)
    end

    return { w = w, h = h, xoff = xoff, yoff = yoff, rgba = rgba }
end

-- ---------------------------------------------------------------------------
-- 锚点约定（ADR-PORT-014）
-- ---------------------------------------------------------------------------

--- 计算一帧的锚点
--
-- 三种来源：
--   1. RLE 帧 → 帧头自带（最准）
--   2. PNG 帧 + 头像用途 → 中心（w/2, h/2）
--   3. PNG 帧 + 其它/未知 → 脚底中心（w/2, h）
--   4. loose 单文件 → 调用方显式传 opts
--
-- **头像是中心锚定**（实测依据）：
--   hdgrp 是头像档案（CC.HeadPicFile，PicLoadFile(..., 1) → archive 1，
--   取帧用 p["头像代号"]*2）。头像绘制路径：
--     local headw, headh = lib.PicGetXY(1, p["头像代号"]*2)
--     local headx = (width/2 - headw)/2
--     lib.PicLoadCache(1, ..., 1)   -- flag=1 = 忽略 xoff/yoff
--   居中由调用方自己算。所以锚点若按脚底取，未来按锚点绘制会向上偏半个身位。
--
-- @param format string "rle" | "png"
-- @param w, h number
-- @param frameAnchor table|nil RLE 帧头解出的 { xoff=, yoff= }
-- @param usage string|nil "avatar" | nil
-- @param opts table|nil { xoff=, yoff= } 显式覆盖
-- @return table { xoff=, yoff= }
function SpriteDecoder.decodeAnchors(format, w, h, frameAnchor, usage, opts)
    w = tonumber(w) or 0
    h = tonumber(h) or 0

    -- 显式覆盖优先级最高
    if type(opts) == "table" and opts.xoff ~= nil and opts.yoff ~= nil then
        return { xoff = opts.xoff, yoff = opts.yoff }
    end

    -- RLE：帧头自带
    if format == SpriteDecoder.FORMAT_RLE and type(frameAnchor) == "table" then
        return {
            xoff = frameAnchor.xoff or math.floor(w / 2),
            yoff = frameAnchor.yoff or h,
        }
    end

    -- PNG（及未来其它编码格式）：按用途
    if usage == "avatar" then
        return { xoff = math.floor(w / 2), yoff = math.floor(h / 2) }
    end
    return { xoff = math.floor(w / 2), yoff = h }
end

return SpriteDecoder
