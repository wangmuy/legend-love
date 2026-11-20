-- sprite_atlas.lua
-- 精灵图集的**加载与句柄管理**（纯数据 + 句柄，零引擎依赖）
--
-- 分层（design.md ADR-PORT-013 / 014 的接线层）：
--
--   framework/sprite_atlas.lua        ← 本文件：读容器 → 逐帧 decode → 拿 handle
--          │
--          ▼  只调三个 EngineAPI 契约（都是格式透明的）
--   EngineAPI.sprite.createFromRGBA(w, h, rgbaBytes, opts)   引擎只上传字节
--   EngineAPI.sprite.createFromEncoded(bytes, formatHint)    引擎只解码图片
--   EngineAPI.sprite.drawHandle(handle, x, y, flags, alpha)  引擎只认句柄
--
-- **为什么需要这一层**（这是"引擎看不见 .idx/.grp"的关键）：
--   现有接线 `sprite.loadArchive(idxFile, grpFile, archiveId)` 把
--   **两个文件名**交给引擎，引擎必须自己解析 .idx 偏移表、维护
--   picFileCache 注册表。换容器格式时引擎要重写解析。
--
--   本层把「容器解析 + 帧编号映射」全部收回 framework，
--   引擎只拿到 handle（它自己定义的、不透明的表/整数）。
--   → 换任何容器格式（PNG 图集 / Aseprite JSON / 自定义打包）
--     只需改本文件，**引擎零改动**。
--
-- **懒加载**：`load()` 只解析 .idx 偏移表（很小），不建纹理。
--   第一次 `get(handleId)` 才 decode + createFromRGBA。
--   依据实测：真实精灵档案 20.6 M 像素 → RGBA 全解 79 MB，
--   但单个 .grp（hdgrp 113 帧）全解只需 1.1 MB，而实际同时显示的帧数很少。
--
-- **本文件不得**：
--   调 love.*
--   require engine-*
--   读写 JY / WAR / CC

local SpriteDecoder = require("framework.sprite_decoder")

local SpriteAtlas = {}

-- ---------------------------------------------------------------------------
-- 档案注册表：atlasId -> atlas 对象
-- ---------------------------------------------------------------------------
--
-- 为什么保留数字 atlasId 而不是让调用方直接持有 atlas 对象：
--   现有代码里 `EngineAPI.sprite.draw(2, item.id*2, ...)` 这种
--   archiveId 是**散布在业务逻辑里的常量**（2 = 物品档案，0 = 主地图）。
--   一次性改成对象传递会动 9 处 war_async + 2 处 item_async，
--   风险大于收益。所以保留数字 id，但**解析归 framework**。
local atlases = {}

-- ---------------------------------------------------------------------------
-- 档案加载
-- ---------------------------------------------------------------------------

--- 加载一个精灵档案（懒加载：只解析偏移表）
--
-- @param atlasId number 档案编号（与既有代码的 archiveId 一致）
-- @param opts table {
--     idxFile = string,      -- .idx 路径
--     grpFile = string,      -- .grp 路径
--     paletteFile = string,  -- .col 路径（可选；RLE 帧需要）
--     usage = string,        -- "avatar" | nil（影响 PNG 帧的锚点，ADR-PORT-014）
--   }
-- @return table|nil atlas 对象
function SpriteAtlas.load(atlasId, opts)
    if type(atlasId) ~= "number" then return nil end
    opts = opts or {}
    if type(opts.idxFile) ~= "string" or type(opts.grpFile) ~= "string" then
        return nil
    end

    local EngineAPI = rawget(_G, "EngineAPI")
    if not EngineAPI or not EngineAPI.file or not EngineAPI.file.read then
        return nil
    end

    -- 读容器（纯字节，不解码）
    local okIdx, idxBytes = pcall(EngineAPI.file.read, opts.idxFile)
    if not okIdx or type(idxBytes) ~= "string" then return nil end
    local okGrp, grpBytes = pcall(EngineAPI.file.read, opts.grpFile)
    if not okGrp or type(grpBytes) ~= "string" then return nil end

    local offsets = SpriteDecoder.parseIdx(idxBytes, #grpBytes)

    -- 调色板（RLE 帧必需；PNG 帧不需要）
    local palette = nil
    if type(opts.paletteFile) == "string" then
        local okPal, colBytes = pcall(EngineAPI.file.read, opts.paletteFile)
        if okPal and type(colBytes) == "string" then
            palette = SpriteDecoder.loadPalette(colBytes)
        end
    end

    local atlas = {
        id          = atlasId,
        offsets     = offsets,
        grpBytes    = grpBytes,
        palette     = palette,
        usage       = opts.usage,
        cache       = {},        -- handleId -> handle（已创建的纹理）
        meta        = {},        -- handleId -> { w, h, xoff, yoff }
        frameCount  = #offsets - 1,
    }
    atlases[atlasId] = atlas
    return atlas
end

--- 兼容既有调用形态：loadArchive(idxFile, grpFile, atlasId)
--
-- **保留这个签名是为了让 9 处既有调用点零改动**（war_async.lua）。
-- 但它内部**不再把文件名交给引擎** —— 容器解析全在本层完成。
-- 这是"引擎看不见 .idx/.grp"的关键过渡：调用点不变，透明度已提升。
--
-- @param idxFile string .idx 路径
-- @param grpFile string .grp 路径
-- @param atlasId number 档案编号
-- @param opts table|nil 额外选项（paletteFile / usage）
-- @return table|nil atlas
function SpriteAtlas.loadArchive(idxFile, grpFile, atlasId, opts)
    opts = opts or {}
    opts.idxFile = idxFile
    opts.grpFile = grpFile
    return SpriteAtlas.load(atlasId, opts)
end

--- 取一个已加载的档案
-- @return table|nil
function SpriteAtlas.get(atlasId)
    return atlases[atlasId]
end

--- 卸载档案（释放纹理引用）
function SpriteAtlas.unload(atlasId)
    atlases[atlasId] = nil
end

--- 清空全部档案（测试 / 场景重置用）
function SpriteAtlas.clear()
    atlases = {}
end

-- ---------------------------------------------------------------------------
-- 帧解码（懒加载）
-- ---------------------------------------------------------------------------

-- frameId → slot 的映射
--
-- **这是容器格式的一部分**：原版资产的 picid 是偶数，内部 slot = picid/2 + 1
-- （lib_love.lua 的 PicLoadCache / PicGetXY 都是 `math.floor(picid/2)` + 1）。
-- 所以这不是"动画帧号算术"（ADR-PORT-015 禁止的那种），
-- 而是**容器编号约定**，必须在本层消化。
local function frameToSlot(frameId)
    if type(frameId) ~= "number" or frameId < 0 then return nil end
    return math.floor(frameId / 2) + 1
end

--- 解码一帧（内部）
--
-- @return table|nil { format=, w=, h=, xoff=, yoff=, rgba= } 或 { format="png", bytes= }
local function decodeFrame(atlas, slot)
    local bytes = SpriteDecoder.sliceFrame(atlas.grpBytes, atlas.offsets, slot)
    if not bytes then return nil end

    local fmt = SpriteDecoder.sniffFormat(bytes)
    if fmt == SpriteDecoder.FORMAT_PNG then
        -- 引擎解码路径：本层只做嗅探，不做 PNG 解压（无 zlib）
        return { format = "png", bytes = bytes }
    end

    -- RLE：本层解码（纯 Lua，零引擎依赖）
    if not atlas.palette then return nil end
    local d = SpriteDecoder.decodeRLE(bytes, atlas.palette)
    if not d then return nil end
    return {
        format = "rle",
        w = d.w, h = d.h,
        xoff = d.xoff, yoff = d.yoff,
        rgba = d.rgba,
    }
end

--- 取一个句柄（不存在则创建纹理）
--
-- @param atlasId number
-- @param frameId number 容器的帧编号（既有代码里的 picid）
-- @return table|nil 句柄（可直接传给 sprite.drawHandle）
function SpriteAtlas.getHandle(atlasId, frameId)
    local atlas = atlases[atlasId]
    if not atlas then return nil end

    local slot = frameToSlot(frameId)
    if not slot or slot < 1 or slot > atlas.frameCount then return nil end

    local cached = atlas.cache[slot]
    if cached then return cached end

    local d = decodeFrame(atlas, slot)
    if not d then return nil end

    local EngineAPI = rawget(_G, "EngineAPI")
    if not EngineAPI or not EngineAPI.sprite then return nil end

    local anchors = SpriteDecoder.decodeAnchors(
        d.format, d.w or 0, d.h or 0,
        d.format == "rle" and { xoff = d.xoff, yoff = d.yoff } or nil,
        atlas.usage, nil)
    local opts = { xoff = anchors.xoff, yoff = anchors.yoff }

    local handle = nil
    if d.format == "png" then
        if EngineAPI.sprite.createFromEncoded then
            handle = EngineAPI.sprite.createFromEncoded(d.bytes, "png", opts)
        end
    else
        if EngineAPI.sprite.createFromRGBA then
            handle = EngineAPI.sprite.createFromRGBA(d.w, d.h, d.rgba, opts)
        end
    end

    if not handle then return nil end
    atlas.cache[slot] = handle

    -- **PNG 帧的真实尺寸只能从引擎 handle 回读**（d.w/d.h 是 nil，因为
    -- framework 不做 PNG 解压）。
    --
    -- 原实现写 `w = d.w or 0` → PNG 帧存成 0×0 → 之后所有读 meta 的地方
    -- 都拿到 0 → 头像居中算成 (100-0)/2 = 50（错位）。
    --
    -- 为什么这里必须修而不能只在 getMeta 兜底：meta 缓存是共享的，
    -- 一旦 getHandle 写进 0×0，getMeta 的兜底也会读到 0×0。
    local realW, realH = d.w, d.h
    if (realW == nil or realH == nil)
        and EngineAPI.sprite.getMeta
        and d.format == "png" then
        local okMeta, em = pcall(EngineAPI.sprite.getMeta, handle)
        if okMeta and type(em) == "table" then
            realW = em.w or 0
            realH = em.h or 0
        end
    end

    atlas.meta[slot] = {
        w = realW or 0,
        h = realH or 0,
        xoff = anchors.xoff,
        yoff = anchors.yoff,
    }
    return handle
end

--- 取一帧的元数据（不解码纹理）
--
-- 注意：PNG 帧的 w/h 需要引擎解码才知道，所以可能返回 nil。
-- RLE 帧的 w/h 从帧头直接读。
--
-- @return table|nil { w=, h=, xoff=, yoff= }
function SpriteAtlas.getMeta(atlasId, frameId)
    local atlas = atlases[atlasId]
    if not atlas then return nil end
    local slot = frameToSlot(frameId)
    if not slot then return nil end

    local cachedMeta = atlas.meta[slot]
    if cachedMeta then return cachedMeta end

    -- RLE 帧可以不解码纹理就知道尺寸（帧头 8 字节）
    local bytes = SpriteDecoder.sliceFrame(atlas.grpBytes, atlas.offsets, slot)
    if not bytes then return nil end
    if SpriteDecoder.sniffFormat(bytes) == SpriteDecoder.FORMAT_PNG then
        -- **PNG 帧兜底走 getHandle**（它会解码 + 把真实 w/h 写进 meta 缓存）
        --
        -- 原实现 `return nil`，理由是「PNG 必须引擎解码才知道尺寸」——
        -- 这个理由成立，但**正确性优先**：实测 hdgrp 的 PNG 帧是 slot 59/111，
        -- 而 r1.grp 里人物 59 的头像代号就是 59（picid=118 → slot=59）→
        -- 头像尺寸会拿到 nil，居中计算崩。
        --
        -- 代价可忽略：真实数据里 115 个 slot 只有 2 个是 PNG，
        -- 且 getHandle 有 cache，第二次调用不会再解码。
        local handle = SpriteAtlas.getHandle(atlasId, frameId)
        if handle then
            local cached = atlas.meta[slot]
            if cached then return cached end
        end
        -- 引擎不支持解码（MUD/Web 返回 w=0 的 handle）→ 返回 0×0 而非 nil，
        -- 让调用方能走统一的"尺寸未知"分支（不是崩溃）。
        return { w = 0, h = 0, xoff = 0, yoff = 0 }
    end
    local d = SpriteDecoder.decodeRLE(bytes, atlas.palette)
    if not d then return nil end
    local anchors = SpriteDecoder.decodeAnchors(
        "rle", d.w, d.h, { xoff = d.xoff, yoff = d.yoff }, atlas.usage, nil)
    local meta = { w = d.w, h = d.h, xoff = anchors.xoff, yoff = anchors.yoff }
    atlas.meta[slot] = meta
    return meta
end

--- 绘制一帧（**新 API，引擎只看 handle**）
--
-- @param atlasId number
-- @param frameId number
-- @param x, y number
-- @param flags number|nil（0x1 忽略锚点 / 0x2 alpha / 0x4 全黑 / 0x8 全白）
-- @param alpha number|nil
-- @return boolean 是否真的画了
function SpriteAtlas.draw(atlasId, frameId, x, y, flags, alpha)
    local handle = SpriteAtlas.getHandle(atlasId, frameId)
    if not handle then return false end
    local EngineAPI = rawget(_G, "EngineAPI")
    if not EngineAPI or not EngineAPI.sprite then return false end
    if not EngineAPI.sprite.drawHandle then return false end
    local ok, _ = pcall(EngineAPI.sprite.drawHandle, handle, x, y, flags, alpha)
    return ok
end

--- 绘制一帧（染色版）
-- @return boolean
function SpriteAtlas.drawTinted(atlasId, frameId, x, y, color, alpha)
    local handle = SpriteAtlas.getHandle(atlasId, frameId)
    if not handle then return false end
    local EngineAPI = rawget(_G, "EngineAPI")
    if not EngineAPI or not EngineAPI.sprite then return false end
    if not EngineAPI.sprite.drawHandleTinted then return false end
    local ok, _ = pcall(EngineAPI.sprite.drawHandleTinted, handle, x, y, color, alpha)
    return ok
end

--- 统计（调试 / 测试用）
-- @return table { atlases=N, handles=M }
function SpriteAtlas.stats()
    local n, handles = 0, 0
    for _ in pairs(atlases) do n = n + 1 end
    for _, a in pairs(atlases) do
        for _ in pairs(a.cache) do handles = handles + 1 end
    end
    return { atlases = n, handles = handles }
end

return SpriteAtlas
