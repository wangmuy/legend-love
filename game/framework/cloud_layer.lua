-- cloud_layer.lua
-- 主地图「飘云」图层的**纯逻辑**（零引擎依赖）
--
-- 分层（change: port-legacy-picture-removal Task 3）：
--
--   framework/cloud_layer.lua     ← 本文件：解码 + 烘焙 + 60 朵漂移 + 屏幕坐标
--          │  只调两个格式透明契约
--          ▼
--   EngineAPI.sprite.createFromRGBA(w, h, rgbaBytes, opts)  引擎只上传字节
--   EngineAPI.sprite.drawHandle(handle, x, y, flags, alpha)  引擎只认句柄
--
-- **为什么从 lib_love 搬过来**（实测依据）：
--   旧的云子系统 190 行全住在引擎里，但只有 2 行真碰引擎
--   （`love.image.newImageData` 与 `love.graphics.draw`）。其余是：
--     * 帧 RLE 解码（纯数据）→ 复用 framework/sprite_decoder.lua
--     * 逐像素 mix 烘焙（纯数据）
--     * 60 朵随机字段（纯逻辑）
--     * 40ms 漂移 + 越界重生（纯逻辑）
--     * 屏幕坐标公式（纯数学）
--   不搬的话，换引擎要重写这 190 行 —— slice 的目标就没达成。
--
-- **解码等价性已实测**（2026-11-21，真实 cloud.idx/cloud.grp 9 帧）：
--   旧的「行内状态机」解码 vs `SpriteDecoder.decodeRLE` 的「成对」解码，
--   9/9 帧的 {w, h, xoff, yoff, 非透明像素数} 完全一致 → 可安全复用。
--
-- **本文件不得**：
--   调 love.*
--   require engine-*
--   读写 JY / WAR / MMap 数据（主角坐标由调用方传入）

local SpriteDecoder = require("framework.sprite_decoder")

local CloudLayer = {}

-- ---------------------------------------------------------------------------
-- 常量（与原版/旧实现逐字一致）
-- ---------------------------------------------------------------------------

local CLOUD_AMOUNT = 60
local TICK_MS = 40                 -- 原版 next_time3 = now + 40
local CLOUD_WORLD_X = 17280        -- 2 * MWidth * XScale（加载时按 CC 重算）
local CLOUD_WORLD_Y = 8640         -- MHeight * XScale（注意是 XScale，不是 YScale）

CloudLayer.CLOUD_AMOUNT = CLOUD_AMOUNT
CloudLayer.TICK_MS = TICK_MS

-- ---------------------------------------------------------------------------
-- 内部状态
-- ---------------------------------------------------------------------------

local frames = {}        -- frames[picnum] = { w=, h=, xoff=, yoff=, rgba=<w*h*4 字节> }
local list = {}          -- list[i] = { Picnum, Positionx, Positiony, Speedx, Speedy,
                         --            Alpha, mixR, mixG, mixB, mixAlpha, handle }
local picAmount = 0
local nextTick = 0
local worldX = CLOUD_WORLD_X
local worldY = CLOUD_WORLD_Y

local function engine()
    return rawget(_G, "EngineAPI")
end

local function nowMs()
    local EA = engine()
    if EA and EA.time and EA.time.getTime then
        local ok, v = pcall(EA.time.getTime)
        if ok and type(v) == "number" then return v end
    end
    return 0
end

-- ---------------------------------------------------------------------------
-- 解码：一帧 RLE → { w, h, xoff, yoff, pixels }
-- ---------------------------------------------------------------------------
--
-- 保留 `pixels` 形态（而不是直接给 rgba 字节）是因为**烘焙**要逐像素改色：
--   每朵云的色调 mix 不同，同一帧要烘 60 次，不能复用同一份 RGBA。
--
-- @param grpBytes string .grp 全量字节
-- @param offsets table SpriteDecoder.parseIdx 的结果
-- @param slot number 1 基帧号
-- @param palette table SpriteDecoder.loadPalette 的结果
-- @return table|nil { w=, h=, xoff=, yoff=, pixels={{x,y,r,g,b},...} }
local function decodeFrame(grpBytes, offsets, slot, palette)
    local bytes = SpriteDecoder.sliceFrame(grpBytes, offsets, slot)
    if not bytes then return nil end
    if SpriteDecoder.sniffFormat(bytes) ~= SpriteDecoder.FORMAT_RLE then return nil end

    local d = SpriteDecoder.decodeRLE(bytes, palette)
    if not d then return nil end

    -- rgba（4 字节/像素）→ pixels 列表（只收非透明像素）
    -- 透明像素在烘焙后仍是透明的（alpha=0），跳过它们不改变输出。
    local pixels = {}
    local rgba = d.rgba
    local w, h = d.w, d.h
    for y = 0, h - 1 do
        local rowBase = y * w * 4
        for x = 0, w - 1 do
            local i = rowBase + x * 4 + 1
            local a = rgba:byte(i + 3)
            if a and a > 0 then
                pixels[#pixels + 1] = {
                    x, y,
                    rgba:byte(i), rgba:byte(i + 1), rgba:byte(i + 2),
                }
            end
        end
    end
    return { w = w, h = h, xoff = d.xoff or 0, yoff = d.yoff or 0, pixels = pixels }
end

-- ---------------------------------------------------------------------------
-- 烘焙：把调色板像素朝色调 (mixR,mixG,mixB) 混合 mixAlpha%
-- ---------------------------------------------------------------------------
--
-- 精确复刻原版 DrawRLE8Pic：
--   pix = (mixAlpha * mixColor + (100 - mixAlpha) * pix) / 100
--
-- @return string|nil RGBA 字节串（w*h*4），alpha 恒为 255（整体透明度由绘制时施加）
local function bakeRGBA(frame, mixR, mixG, mixB, mixAlpha)
    if not frame then return nil end
    local w, h = frame.w, frame.h
    if w <= 0 or h <= 0 then return nil end

    -- 预填全透明（未绘制像素 alpha=0）
    local zero4 = string.char(0, 0, 0, 0)
    local rows = {}
    for _ = 1, h do rows[#rows + 1] = string.rep(zero4, w) end
    local grid = {}
    for y = 0, h - 1 do grid[y] = {} end

    for _, p in ipairs(frame.pixels) do
        local x, y, r, g, b = p[1], p[2], p[3], p[4], p[5]
        local nr = (mixAlpha * mixR + (100 - mixAlpha) * r) / 100
        local ng = (mixAlpha * mixG + (100 - mixAlpha) * g) / 100
        local nb = (mixAlpha * mixB + (100 - mixAlpha) * b) / 100
        local row = grid[y]
        if row then
            row[x] = string.char(
                math.floor(nr + 0.5),
                math.floor(ng + 0.5),
                math.floor(nb + 0.5),
                255)
        end
    end

    for y = 0, h - 1 do
        local row = grid[y]
        local parts = {}
        for x = 0, w - 1 do
            parts[#parts + 1] = row[x] or zero4
        end
        rows[y + 1] = table.concat(parts)
    end
    return table.concat(rows)
end

CloudLayer.bakeRGBA = bakeRGBA

-- ---------------------------------------------------------------------------
-- 加载
-- ---------------------------------------------------------------------------

--- 加载云贴图并初始化 60 朵云
--
-- 调用方（`EngineAPI.map.loadClouds`）在 `Init_MMap` 之后调用一次。
--
-- @param idxFile string .idx 路径
-- @param grpFile string .grp 路径
-- @param paletteFile string|nil .col 路径（缺省用 CC.PaletteFile）
-- @return number 实际解出的帧数（0 表示资源缺失，静默降级）
function CloudLayer.load(idxFile, grpFile, paletteFile)
    local EA = engine()
    if not (EA and EA.file and EA.file.read) then return 0 end

    local okIdx, idxBytes = pcall(EA.file.read, idxFile)
    local okGrp, grpBytes = pcall(EA.file.read, grpFile)
    if not okIdx or type(idxBytes) ~= "string" or not okGrp or type(grpBytes) ~= "string" then
        list = {}
        frames = {}
        picAmount = 0
        return 0
    end

    local CC = rawget(_G, "CC") or {}
    if type(paletteFile) ~= "string" then paletteFile = CC.PaletteFile end
    local palette = nil
    if type(paletteFile) == "string" then
        local okPal, colBytes = pcall(EA.file.read, paletteFile)
        if okPal and type(colBytes) == "string" then
            palette = SpriteDecoder.loadPalette(colBytes)
        end
    end
    if not palette then
        list = {}
        frames = {}
        picAmount = 0
        return 0
    end

    local offsets = SpriteDecoder.parseIdx(idxBytes, #grpBytes)

    local CONFIG = rawget(_G, "CONFIG") or {}
    worldX = (CC.MWidth or 480) * (CONFIG.XScale or 18) * 2
    worldY = (CC.MHeight or 480) * (CONFIG.XScale or 18)

    list = {}
    frames = {}
    picAmount = 0
    nextTick = nowMs()

    -- 云 idx 是「每帧一个贴图」布局（原版 DrawCPic 不做 /2）：
    --   帧 num(0 基) 占 [idx[num+1], idx[num+2])
    local n = 0
    while offsets[n + 1] ~= nil and offsets[n + 2] ~= nil
            and offsets[n + 2] > offsets[n + 1] do
        frames[n] = decodeFrame(grpBytes, offsets, n + 1, palette)
        if frames[n] then picAmount = picAmount + 1 end
        n = n + 1
    end

    for i = 1, CLOUD_AMOUNT do
        CloudLayer.createOne(i, true)
    end
    return picAmount
end

-- ---------------------------------------------------------------------------
-- 生成 / 漂移
-- ---------------------------------------------------------------------------

--- 重生一朵云（原版 CloudCreateOnSide：Positionx=0，从左侧进入）
--
-- **随机调用顺序必须逐字保留**，否则同一 seed 下的云位置与旧版不同：
--   Picnum → Alpha → mixR → mixG → mixB → mixAlpha → Positiony → Speedx
--
-- @param i number 1..CLOUD_AMOUNT
-- @param scatter boolean|nil true 时额外把 Positionx 随机散布（= CloudCreate）
function CloudLayer.createOne(i, scatter)
    if i < 1 or i > CLOUD_AMOUNT then return nil end
    local c = list[i] or {}
    list[i] = c

    c.Picnum = (picAmount > 0) and math.random(0, picAmount - 1) or 0
    c.Alpha = 10 + math.random(0, 49)
    c.mixR = math.random(0, 255)
    c.mixG = math.random(0, 255)
    c.mixB = math.random(0, 255)
    c.mixAlpha = 10 + math.random(0, 49)
    c.Positionx = 0
    c.Positiony = math.random(0, worldY - 1)
    c.Speedx = 1 + math.random(0, 2)
    c.Speedy = 0

    c.handle = nil
    local frame = frames[c.Picnum]
    if frame then
        local rgba = bakeRGBA(frame, c.mixR, c.mixG, c.mixB, c.mixAlpha)
        local EA = engine()
        if rgba and EA and EA.sprite and EA.sprite.createFromRGBA then
            local ok, h = pcall(EA.sprite.createFromRGBA, frame.w, frame.h, rgba,
                                { xoff = 0, yoff = 0 })
            if ok then c.handle = h end
        end
    end

    if scatter then
        c.Positionx = math.random(0, worldX - 1)
    end
    return c
end

--- 40ms 漂移 tick（受 `CC.MMapAmi > 0` 门控）
-- @return number 本次移动了几朵云（0 表示窗口未到或被门控关掉）
function CloudLayer.tick()
    if picAmount == 0 then return 0 end
    local CC = rawget(_G, "CC")
    if CC == nil or CC.MMapAmi == nil or CC.MMapAmi <= 0 then return 0 end

    local now = nowMs()
    if now - nextTick <= 0 then return 0 end
    nextTick = now + TICK_MS

    local moved = 0
    for i = 1, CLOUD_AMOUNT do
        local c = list[i]
        if c ~= nil then
            c.Positionx = c.Positionx + c.Speedx
            c.Positiony = c.Positiony + c.Speedy
            if c.Positionx > worldX - 1 or c.Positionx < 0
                or c.Positiony > worldY - 1 or c.Positiony < 0 then
                CloudLayer.createOne(i, false)
            end
            moved = moved + 1
        end
    end
    return moved
end

--- 每朵云在屏幕上的位置（纯数学，供绘制与测试共用）
--
-- 【x 轴符号为什么不能照抄原版】
-- 原版 kys 地形投影：sx = -18*(i-Mx) + 18*(j-My) + CENTER_X
-- 本项目（Mac 血缘）是其水平镜像：sx = 18*(i-j) - 18*(mx-my) + W/2
-- 云是「世界锚定」图层，必须与地形同步滚动 → x 的玩家项取 -(mx*X - my*X)。
-- 照抄原版会让云以 +18*(mx-my) 反向滑动（历史 bug：云跟着主角左右偏移）。
-- y 轴两边都是 9*(i+j)，无镜像，保持一致。
--
-- @param c table 云
-- @param mx, my number 主角格坐标
-- @return number x, y, alpha0to1
function CloudLayer.screenPos(c, mx, my)
    local CONFIG = rawget(_G, "CONFIG") or {}
    local XS = CONFIG.XScale or 18
    local YS = CONFIG.YScale or 9
    local W = CONFIG.Width or 1024
    local H = CONFIG.Height or 768
    local centerX = math.floor(W / 2)
    local centerY = math.floor(H / 2)

    local px = c.Positionx - (mx * XS - my * XS + worldY - centerX)
    local py = c.Positiony - (mx * YS + my * YS + YS - centerY)
    local x = px - (c.xoff or 0)
    local y = py - (c.yoff or 0)
    -- 原版 Alpha 是「背景透出百分比」，云自身不透明度 = (100-Alpha)/100
    local a = (100 - c.Alpha) / 100
    return x, y, a
end

--- 绘制全部云（只调 `sprite.drawHandle`）
-- @param mx, my number 主角格坐标
-- @return number 实际画了几朵
function CloudLayer.draw(mx, my)
    if picAmount == 0 or #list == 0 then return 0 end
    local EA = engine()
    if not (EA and EA.sprite and EA.sprite.drawHandle) then return 0 end

    local drawn = 0
    for i = 1, CLOUD_AMOUNT do
        local c = list[i]
        if c ~= nil and c.handle ~= nil and c.Picnum >= 0 and c.Picnum < picAmount then
            local x, y, a = CloudLayer.screenPos(c, mx, my)
            -- 契约 alpha 是 0-255；flag 0x1 = 忽略锚点（云锚点恒为 0，无影响）
            local alpha255 = math.floor(a * 255 + 0.5)
            local ok = pcall(EA.sprite.drawHandle, c.handle, x, y, 0x1, alpha255)
            if ok then drawn = drawn + 1 end
        end
    end
    return drawn
end

-- ---------------------------------------------------------------------------
-- 观察 / 重置（测试与调试用）
-- ---------------------------------------------------------------------------

--- 返回内部云表（只读观察，勿改）
function CloudLayer.getList()
    return list
end

--- 返回解出的帧表（只读观察）
function CloudLayer.getFrames()
    return frames
end

--- 帧数
function CloudLayer.frameCount()
    return picAmount
end

--- 重置全部状态（场景切换 / 测试隔离）
function CloudLayer.reset()
    list = {}
    frames = {}
    picAmount = 0
    nextTick = 0
end

--- 强制设置 tick 基准（测试用：让 40ms 窗口可控）
function CloudLayer._setNextTick(ms)
    nextTick = ms
end

--- 世界尺寸（测试用）
function CloudLayer.worldSize()
    return worldX, worldY
end

return CloudLayer
