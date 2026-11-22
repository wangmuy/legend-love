-- engine_love2d.lua
-- Love2D 引擎实现 - 实现 EngineAPI 接口
-- 内部委托给 lib_love.lua 的现有实现

-- 原版游戏脚本以裸名 require 框架模块（如 require "lib_file"），
-- 而 Love2D 只能解析 framework.xxx 点号路径，因此为这些裸名注册别名。
-- 与 engine-web/web_game_bridge.lua 的裸名别名机制保持一致。
-- 必须在 main.lua 加载 script/jymain.lua 之前完成（本模块先于其被 require）。
local frameworkAliases = {
    lib_file = true,
    script_loader = true,
    coroutine_scheduler = true,
    war_async = true,
    event_executor = true,
}
for bareName in pairs(frameworkAliases) do
    if not package.preload[bareName] then
        package.preload[bareName] = function()
            return require("framework." .. bareName)
        end
    end
end

local EngineAPI = require("engine-love2d.engine_api")
local lib = require("engine-love2d.lib_love")

-- 将 lib_love 中的函数映射到 EngineAPI 各模块
-- render 模块
-- fontname 必须透传：原版 luafun.c:25 是
--   JY_DrawStr(x, y, str, color, size, fontname)
-- 六个参数全传。丢掉 fontname 会让中文回落到 LÖVE 内置字体（无中文字形）。
EngineAPI.render.text = function(x, y, str, color, size, fontname)
    lib.DrawStr(x, y, str, color, size, fontname)
end

EngineAPI.render.fillRect = function(x1, y1, x2, y2, color)
    lib.FillColor(x1, y1, x2, y2, color)
end

EngineAPI.render.rectOutline = function(x1, y1, x2, y2, color)
    lib.DrawRect(x1, y1, x2, y2, color)
end

EngineAPI.render.drawBackground = function(x1, y1, x2, y2, brightness)
    lib.Background(x1, y1, x2, y2, brightness)
end

EngineAPI.render.setClip = function(x1, y1, x2, y2)
    lib.SetClip(x1, y1, x2, y2)
end
EngineAPI.render.getClip = function()
    if love and love.graphics and love.graphics.getScissor then
        local x, y, w, h = love.graphics.getScissor()
        if x == nil then
            return { x = 0, y = 0, w = CONFIG.Width, h = CONFIG.Height }
        end
        return { x = x, y = y, w = w, h = h }
    end
    return { x = 0, y = 0, w = CONFIG.Width, h = CONFIG.Height }
end


EngineAPI.render.present = function()
    lib.ShowSurface()
end

EngineAPI.render.presentAndWait = function(delay)
    lib.ShowSlow(delay)
end

--- 告知引擎「当前在帧绘制回调内」（入口程序在 love.draw 前后置位）
--
-- 为什么现在才补契约：原实现 `main.lua` 直接调全局 `lib.SetDrawLoopFlag`，
-- 而 `lib` 是 `_G` 上的兼容层（port-compat-layer-removal 要删除它）。
-- 语义逐字转发到 `lib_love.SetDrawLoopFlag`（它控制 ShowSurface 是否 present）。
EngineAPI.render.setDrawLoopFlag = function(flag)
    if lib.SetDrawLoopFlag then
        lib.SetDrawLoopFlag(flag)
    end
end

--- 取渲染目标尺寸（逻辑像素）
--
-- 实测（Windows 150% 缩放下）：love.graphics.getDimensions() 返回 1024×768，
-- 与 DrawString/DrawRect 同一坐标空间，无需 DPI 换算。
-- 但 Godot/Android 会变，所以契约必须走查询而非编译期常量。
EngineAPI.render.getWidth = function()
    if love and love.graphics and love.graphics.getWidth then
        local w = love.graphics.getWidth()
        if type(w) == "number" and w > 0 then return w end
    end
    -- 兜底：引擎异常时给哨兵值而不是 nil（调用方无需做 nil 判断）
    local CC = rawget(_G, "CC")
    if CC and type(CC.ScreenW) == "number" and CC.ScreenW > 0 then return CC.ScreenW end
    return 1024
end

EngineAPI.render.getHeight = function()
    if love and love.graphics and love.graphics.getHeight then
        local h = love.graphics.getHeight()
        if type(h) == "number" and h > 0 then return h end
    end
    local CC = rawget(_G, "CC")
    if CC and type(CC.ScreenH) == "number" and CC.ScreenH > 0 then return CC.ScreenH end
    return 768
end

-- sprite 模块
--
-- **paletteFile 现在无需引擎处理**（port-legacy-picture-removal Task 6）：
--   原版 `PicInit` 的唯一作用是加载 256 色调色板，因为 RLE 精灵的像素值是
--   调色板索引。现在 RLE 解码在 `framework/sprite_decoder.lua`，
--   调色板由 `SpriteAtlas.loadArchive({paletteFile=...})` 自己读
--   （`SpriteDecoder.loadPalette`，同样 ×4 放大）。
--   所以引擎侧**不再需要调色板** —— 不是"静默丢弃"，是职责已转移。
EngineAPI.sprite.initSprites = function(paletteFile)
    if paletteFile ~= nil and EngineAPI.debug and EngineAPI.debug.log then
        -- 留一条日志便于排查「以为引擎会加载调色板」的误解
        EngineAPI.debug.log("sprite.initSprites: palette handled by framework "
                            .. "(sprite_decoder.loadPalette), ignored: " .. tostring(paletteFile))
    end
end

-- **`sprite.loadArchive` / `sprite.draw` / `sprite.drawTinted` 已删除**
-- （port-legacy-picture-removal）：三者在 framework/script 里零消费者，
-- 新链路走 `SpriteAtlas` → `sprite.createFromRGBA` / `drawHandle`
-- （引擎不再需要解析 .idx/.grp，也不再维护 picFileCache）。

-- ADR-PORT-013：从原始 RGBA 字节创建纹理
--
-- 实测（LÖVE 11.5）：
--   love.image.newImageData(w, h, "rgba8", rawBytes)   可用（4 参数形式）
--   性能：逐像素 setPixel 1.0ms / raw 一次性 0.0ms（64x64，加速比 10000x）
--   注意：ImageData 没有 setPixels 方法；只有 setPixel / getPixel / paste / mapPixel
EngineAPI.sprite.createFromRGBA = function(w, h, rgbaBytes, opts)
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return nil end
    if type(rgbaBytes) ~= "string" then return nil end
    if #rgbaBytes < w * h * 4 then return nil end   -- 数据不足，拒绝而不是崩

    local ok, imgdata = pcall(love.image.newImageData, w, h, "rgba8", rgbaBytes)
    if not ok or not imgdata then return nil end

    local ok2, img = pcall(love.graphics.newImage, imgdata,
        { mipmaps = false, linear = false, dpiscale = 1 })
    if not ok2 or not img then return nil end

    opts = opts or {}
    return {
        img   = img,
        w     = w,
        h     = h,
        xoff  = opts.xoff or 0,
        yoff  = opts.yoff or 0,
    }
end

-- ADR-PORT-014：从编码后的图片字节创建纹理（引擎负责解码）
--
-- LÖVE 11.5 的 love.image.newImageData 支持 PNG/JPG/BMP/TGA（实测 PNG/JPG 均 OK）。
-- 不支持 WebP（需要额外库），所以若 formatHint 是 webp 会被 pcall 拦住并返回 nil。
EngineAPI.sprite.createFromEncoded = function(bytes, formatHint, opts)
    if type(bytes) ~= "string" or bytes == "" then return nil end
    if not (love and love.filesystem and love.filesystem.newFileData) then return nil end

    -- 用 formatHint 生成文件名：多数解码器靠字节嗅探，但给个扩展名更稳
    local ext = type(formatHint) == "string" and formatHint ~= "" and formatHint or "png"
    local ok, fd = pcall(love.filesystem.newFileData, bytes, "encoded." .. ext)
    if not ok or not fd then return nil end

    local ok2, imgdata = pcall(love.image.newImageData, fd)
    if not ok2 or not imgdata then return nil end

    local w = imgdata:getWidth()
    local h = imgdata:getHeight()
    if not w or not h or w <= 0 or h <= 0 then return nil end

    local ok3, img = pcall(love.graphics.newImage, imgdata,
        { mipmaps = false, linear = false, dpiscale = 1 })
    if not ok3 or not img then return nil end

    opts = opts or {}
    return {
        img  = img,
        w    = w,
        h    = h,
        xoff = opts.xoff or 0,
        yoff = opts.yoff or 0,
    }
end

--- 绘制独立图片文件（非 .grp 档案）
--
-- x/y 传 -1 表示屏幕居中（既有调用方约定）。
EngineAPI.sprite.drawPictureFile = function(filename, x, y, opts)
    if type(filename) ~= "string" or filename == "" then return false end
    if not (love and love.graphics and love.graphics.newImage) then return false end

    -- 按文件名缓存（既有 LoadPicture 的行为）
    local cache = EngineAPI.sprite._picCache
    if not cache then
        cache = {}
        EngineAPI.sprite._picCache = cache
    end
    if opts ~= nil and opts.cache == false then cache[filename] = nil end

    local pic = cache[filename]
    if not pic then
        local ok, img = pcall(love.graphics.newImage, filename)
        if not ok or not img then return false end
        pic = img
        cache[filename] = pic
    end

    local w = EngineAPI.render.getWidth()
    local h = EngineAPI.render.getHeight()
    if x == -1 then x = math.floor((w - pic:getWidth()) / 2) end
    if y == -1 then y = math.floor((h - pic:getHeight()) / 2) end
    love.graphics.draw(pic, x, y)
    return true
end

--- 绘制纹理句柄（格式透明）
--
-- handle 结构由 createFromRGBA/createFromEncoded 产生：
--   { img=löve Image, w=, h=, xoff=, yoff= }
-- 引擎不需要知道这个纹理来自 .idx/.grp 还是 PNG 图集。
--- 清空「按文件名缓存的整图」
--
-- **修了一个活体缺陷**（port-legacy-picture-removal Task 6）：
--   原实现调 `lib.ClearPictureCache()`，清的是 lib_love 里的 `pictureCache`
--   （旧 `LoadPicture` 用的表，已随旧贴图子系统删除）；
--   而真正在用的 `drawPictureFile` 用的是 `EngineAPI.sprite._picCache`
--   （本文件 188-191 行）—— **两张不同的表**。
--   于是 `jymain.lua` 调 `clearPictureCache()` 想清整图缓存时，
--   `_picCache` 纹丝不动（内存只增不减，且换图不生效）。
EngineAPI.sprite.clearPictureCache = function()
    EngineAPI.sprite._picCache = {}
end

EngineAPI.sprite.drawHandle = function(handle, x, y, flags, alpha)
    if type(handle) ~= "table" or not handle.img then return false end
    flags = flags or 0

    local xnew, ynew = x, y
    -- 0x1 位为 0 时应用锚点（与原版 PicLoadCache 一致：flag=1 = 忽略锚点）
    if bit32 and bit32.band(flags, 0x1) == 0 then
        xnew = x - (handle.xoff or 0)
        ynew = y - (handle.yoff or 0)
    end

    -- 颜色位与 alpha 位**独立判断**（与 `PicLoadCache` 逐位一致）
    --
    -- **原实现是 elseif 链（互斥）**，那是错的：`PicLoadCache` 里
    -- hasAlpha / isBlack / isWhite 三个判断互相独立：
    --
    --   flag = 0x6（移动范围高亮）= black + alpha
    --   旧 PicLoadCache → r,g,b=0 且 a = 128/255 → **半透明黑**
    --   互斥版 drawHandle → r,g,b=0 且 a = 1  → **不透明黑**
    --
    -- 实测：`DrawWarMap` 的 flag=1/2 分支正是传 `2+4`（= 0x6）和
    -- alpha 128/64。互斥语义会让「移动范围」从半透明高亮变成实心黑块。
    local r, g, b, a = 1, 1, 1, 1
    -- 跨版本位测试：Lua 5.4/5.5 没有 bit32，用整除法等价实现
    local function hasBit(v, m)
        if bit32 and bit32.band then return bit32.band(v, m) ~= 0 end
        return math.floor(v / m) % 2 == 1
    end
    if hasBit(flags, 0x4) then r, g, b = 0, 0, 0
    elseif hasBit(flags, 0x8) then r, g, b = 1, 1, 1 end
    if hasBit(flags, 0x2) then a = (alpha or 128) / 255 end

    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(handle.img, xnew, ynew)
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

--- 绘制纹理句柄（染色）
EngineAPI.sprite.drawHandleTinted = function(handle, x, y, color, alpha)
    if type(handle) ~= "table" or not handle.img then return false end
    local xnew = x - (handle.xoff or 0)
    local ynew = y - (handle.yoff or 0)
    local r, g, b = 1, 1, 1
    if type(color) == "table" then
        r, g, b = color.r or 1, color.g or 1, color.b or 1
    end
    local a = (alpha ~= nil) and (alpha / 255) or 1
    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(handle.img, xnew, ynew)
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

EngineAPI.sprite.getMeta = function(handle)
    if type(handle) ~= "table" then return nil end
    return {
        w    = handle.w or 0,
        h    = handle.h or 0,
        xoff = handle.xoff or 0,
        yoff = handle.yoff or 0,
    }
end

-- map 模块
EngineAPI.map.loadMain = function(earthFile, surfaceFile, buildingFile, buildXFile, buildYFile, width, height, x, y)
    lib.LoadMMap(earthFile, surfaceFile, buildingFile, buildXFile, buildYFile, width, height, x, y)
end

EngineAPI.map.loadScene = function(sFile, tmpFile, num, width, height, dFile, dNum1, dNum2)
    lib.LoadSMap(sFile, tmpFile, num, width, height, dFile, dNum1, dNum2)
end

EngineAPI.map.saveScene = function(sFile, dFile)
    lib.SaveSMap(sFile, dFile)
end

EngineAPI.map.loadBattle = function(idxFile, grpFile, mapId, num, width, height)
    lib.LoadWarMap(idxFile, grpFile, mapId, num, width, height)
end

--- 读取地图瓦片（layer 编号与原版 GetMMap 的 flag 完全一致）
EngineAPI.map.getTile = function(x, y, layer)
    return lib.GetMMap(x, y, layer)
end

EngineAPI.map.unload = function()
    lib.UnloadMMap()
end

--- 云层三条契约全部转发 `framework/cloud_layer.lua`
--
-- 为什么搬 framework（port-legacy-picture-removal Task 4）：
--   旧实现 190 行住在 lib_love，但只有 2 行真碰引擎
--   （`love.image.newImageData` / `love.graphics.draw`）。
--   现在解码复用 `framework/sprite_decoder`、烘焙产出 RGBA 字节、
--   绘制走 `sprite.drawHandle` —— 引擎只剩「上传字节」与「画句柄」。
local function cloudLayer()
    local ok, mod = pcall(require, "framework.cloud_layer")
    if ok and mod then return mod end
    return nil
end

EngineAPI.map.tickClouds = function()
    local CL = cloudLayer()
    if CL then return CL.tick() end
end

EngineAPI.map.getSceneSize = function()
    -- S_XMax / S_YMax 在 lib_love.lua 是 **local** → 经框架暴露的访问器读取
    if lib.GetSceneSize then return lib.GetSceneSize() end
    -- 兜底：用调用方传的 CC.SWidth/SHeight（正常情况下二者相同）
    local CC = rawget(_G, "CC") or {}
    return { w = CC.SWidth or 64, h = CC.SHeight or 64 }
end

EngineAPI.map.loadClouds = function(idxFile, grpFile)
    local CL = cloudLayer()
    if CL then
        local CC = rawget(_G, "CC")
        return CL.load(idxFile, grpFile, CC and CC.PaletteFile or nil)
    end
end

EngineAPI.map.getBattleSize = function()
    if lib.GetBattleSize then return lib.GetBattleSize() end
    return { w = 64, h = 64 }
end

EngineAPI.map.drawClouds = function(mx, my)
    local CL = cloudLayer()
    if CL then return CL.draw(mx, my) end
end

EngineAPI.map.setTile = function(x, y, layer, value)
    -- 消费者：framework/map_render.lua 的 buildingSort（深度排序时临时占用）
    -- `SetMMap` 在 lib_love.lua 是 **local**，外部调不到 → 经 lib.JY_SetMMap 桥接
    if lib.JY_SetMMap then lib.JY_SetMMap(x, y, layer, value) end
end

EngineAPI.map.getSceneTile = function(sceneId, x, y, layer)
    return lib.GetS(sceneId, x, y, layer)
end

EngineAPI.map.setSceneTile = function(sceneId, x, y, layer, value)
    lib.SetS(sceneId, x, y, layer, value)
end

EngineAPI.map.getSceneEventData = function(sceneId, eventId, field)
    return lib.GetD(sceneId, eventId, field)
end

EngineAPI.map.setSceneEventData = function(sceneId, eventId, field, value)
    lib.SetD(sceneId, eventId, field, value)
end

EngineAPI.map.getBattleTile = function(x, y, layer)
    return lib.GetWarMap(x, y, layer)
end

EngineAPI.map.setBattleTile = function(x, y, layer, value)
    lib.SetWarMap(x, y, layer, value)
end

EngineAPI.map.clearBattleTile = function(layer, value)
    lib.CleanWarMap(layer, value)
end


--- 三个地图绘制契约 —— 全部转发 `framework/map_render.lua`
--
-- 原实现是 `lib.DrawMMap/DrawSMap/DrawWarMap`（363 行，住在引擎里），
-- `.idx/.grp` **不透明**：内部经 `JY_LoadPic` = `PicLoadCache` 读 `picFileCache`，
-- 新引擎要重写整套 RLE 解码 + 档案缓存才能实现这些契约。
--
-- 现在投影数学住 framework（用 `sprite.drawHandle` 画已解好的 handle），
-- 引擎不再持有等距投影逻辑。
--
-- **逃生舱已改为显式失败**（port-legacy-picture-removal Task 5）：
--   原来 framework 模块缺失时回退 `lib.DrawMMap/DrawSMap/DrawWarMap`。
--   但旧实现的 `PicLoadCache` flag 位语义与新 `drawHandle` **不同**
--   （为此专门修过 drawHandle 的互斥判断），静默回退会产生
--   「有点不对但不崩」的画面，比崩溃更难定位。
--   这个 fallback 掩盖的真问题是「`.love` 打包漏了 map_render.lua」——
--   应该立刻报错。
local function mapRender()
    local ok, MR = pcall(require, "framework.map_render")
    if ok and MR then return MR end
    local msg = "framework.map_render missing (packaging bug?): " .. tostring(MR)
    if EngineAPI.debug and EngineAPI.debug.log then
        EngineAPI.debug.log("map.draw*: " .. msg)
    end
    error(msg, 2)
end

--- 主地图绘制
EngineAPI.map.drawMain = function(playerX, playerY, playerPic)
    local MR = mapRender()
    if not MR.drawMain then error("map_render.drawMain missing", 2) end
    MR.drawMain(playerX, playerY, playerPic)
end

--- 场景地图绘制
EngineAPI.map.drawScene = function(sceneId, x, y, offX, offY, playerPic)
    local MR = mapRender()
    if not MR.drawScene then error("map_render.drawScene missing", 2) end
    MR.drawScene(sceneId, x, y, offX, offY, playerPic)
end

--- 战斗地图绘制
--
-- **注意 flag=1/2 的语义**：原实现传 `JY_LoadPic(0, 0, x, y, 2+4, 128)` ——
-- 即「变黑 + alpha」，在 `PicLoadCache` 里两者**独立**生效（半透明黑高亮）。
-- 为此同步修了 `sprite.drawHandle` 的位判断（原来用 elseif 链互斥，
-- 会把移动范围画成不透明黑块）。
EngineAPI.map.drawBattle = function(flag, x, y, v1, v2, v3)
    local MR = mapRender()
    if not MR.drawBattle then error("map_render.drawBattle missing", 2) end
    MR.drawBattle(flag, x, y, v1, v2, v3)
end

-- input 模块
EngineAPI.input.getKey = function()
    return lib.GetKey()
end

EngineAPI.input.waitForKey = function()
    -- 在协程中由 async_globals 替换，此处保留阻塞版本
    while true do
        local key = lib.GetKey()
        if key ~= -1 then
            return key
        end
        lib.Delay(20)
    end
end

EngineAPI.input.setKeyRepeat = function(delay, interval)
    lib.EnableKeyRepeat(delay, interval)
end

-- 鼠标（REQ-MS1-2）
--
-- 契约是「返回**逻辑坐标**，与 DrawString/DrawRect 同一空间」。
-- 实测（Windows 150% 缩放 + conf.lua 的 highdpi/usedpiscale 都开）：
--   setPosition(1023,767) → getPosition 返回 (1023,767)，比值 1.000
-- 即 LÖVE 已按 DPI-aware 处理，此处**不需要任何换算**。
-- 若未来在 macOS/Android 上实测发现返回物理像素，在这一行加换算即可，
-- 契约与所有调用方都不受影响。
EngineAPI.input.mousePosition = function()
    if not (love and love.mouse and love.mouse.getPosition) then
        return -1, -1
    end
    local ok, mx, my = pcall(love.mouse.getPosition)
    if not ok or type(mx) ~= "number" then
        return -1, -1
    end
    return mx, my
end

EngineAPI.input.mouseButton = function(button)
    if not (love and love.mouse and love.mouse.isDown) then
        return false
    end
    local ok, down = pcall(love.mouse.isDown, tonumber(button) or 1)
    return ok and down == true
end

-- 轴名闭集（与 SDL / Godot / Unreal 一致），见 engine_api 的注释
local VALID_AXES = {
    leftx = true, lefty = true, rightx = true, righty = true,
    triggerleft = true, triggerright = true,
}

--- 读一个物理轴（每帧状态查询）
--
-- 取第一个已连接手柄。没有手柄/轴名非法时返回 0 —— 宽容失败，
-- 让上层无需区分「没设备」和「摇杆在中位」。
EngineAPI.input.getAxis = function(name)
    if type(name) ~= "string" or not VALID_AXES[name] then return 0 end
    if not (love and love.joystick and love.joystick.getJoysticks) then return 0 end
    local ok, sticks = pcall(love.joystick.getJoysticks)
    if not ok or type(sticks) ~= "table" or #sticks == 0 then return 0 end
    local j = sticks[1]
    if not j or not j.getGamepadAxis then return 0 end
    local ok2, v = pcall(j.getGamepadAxis, j, name)
    if not ok2 or type(v) ~= "number" then return 0 end
    -- 防御：某些驱动会给出略超出 [-1,1] 的值
    if v < -1 then v = -1 elseif v > 1 then v = 1 end
    return v
end

--- 查询输入能力
--
-- vr = false 是契约留槽（ADR-7）：事件结构允许 source="vr" 与 ray 字段，
-- 但当前没有任何 VR 实现，所以能力如实报 false。
EngineAPI.input.getCapabilities = function()
    return {
        pointer = (love and love.mouse and love.mouse.getPosition) ~= nil,
        touch   = (love and love.touch and love.touch.getTouches) ~= nil,
        gamepad = (love and love.joystick and love.joystick.getJoysticks) ~= nil,
        vr      = false,
    }
end

--- 指针位置（设备无关的「位置」语义）
--
-- 当前实现委托 mousePosition()：桌面与 Android 接鼠标时都走它。
-- 将来接触摸/VR 射线时在本函数内合并优先级，契约不变。
EngineAPI.input.getPointerPosition = function()
    return EngineAPI.input.mousePosition()
end

--- 取一个语义动作（事件通道）
--
-- 委托 InputManager.getAction()。用 pcall 是因为 engine_love2d 也被
-- 纯引擎测试加载（此时 framework 可能未初始化），不能因缺模块而崩。
EngineAPI.input.enableKeyRepeat = function(delay, interval)
    lib.EnableKeyRepeat(delay, interval)
end

EngineAPI.input.pollAction = function()
    local ok, IM = pcall(require, "framework.input_manager")
    if not ok or not IM or not IM.getAction then return nil end
    return IM.getAction()
end

--- 读取当前所有触摸点
--
-- **用 LÖVE 11.5 的正确 API**（实测确认）：
--   love.touch.getTouches()     → 返回 id 列表
--   love.touch.getPosition(id)  → 返回归一化坐标（0..1）
--
-- 不能用 0.10.x 的 getTouchCount() / getTouch(i)：实测在 11.5 上
-- 它们是 nil，调用会报 "attempt to call field 'getTouchCount' (a nil value)"。
-- （参考库 reference/MobileControlsLibrary 的 README 正是老 API，照抄会崩。）
--
-- 返回绝对像素坐标（乘屏幕尺寸），与布局表同一坐标系。
--
-- @return table { {id=, x=, y=}, ... }
EngineAPI.input.getTouches = function()
    local out = {}
    if not (love and love.touch and love.touch.getTouches) then return out end
    if not (love.graphics and love.graphics.getWidth) then return out end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local ok, ids = pcall(love.touch.getTouches)
    if not ok or type(ids) ~= "table" then return out end

    for _, id in ipairs(ids) do
        local ok2, nx, ny = pcall(love.touch.getPosition, id)
        if ok2 and type(nx) == "number" and type(ny) == "number" then
            out[#out + 1] = { id = id, x = nx * sw, y = ny * sh }
        end
    end
    return out
end

-- audio 模块
EngineAPI.audio.playMusic = function(filename)
    lib.PlayMIDI(filename)
end

EngineAPI.audio.playSFX = function(filename)
    lib.PlayWAV(filename)
end

EngineAPI.audio.stopMusic = function()
    lib.PlayMIDI("")
end

--- 播放序列音频（按索引 → 文件名由引擎按 CC.MIDIFile 模板生成）
--
-- 注意：这里不做 CC.MIDIFile 的拼接 —— 那是**游戏层知道的事**
-- （CC 是游戏常量）。调用方传**已拼好的文件名**或 id 都合法，
-- 但契约要求传文件名（见下方实现选择）。
--
-- 实现选择：与 playMusic(filename) 同一条路径。
-- 原版 lib.PlayMIDI 收的就是文件名（jymain.lua:2250 已拼好）。
EngineAPI.audio.playSequence = function(filenameOrId, opts)
    if type(filenameOrId) == "string" then
        lib.PlayMIDI(filenameOrId)
        return true
    end
    return false
end

--- 播放视频（原版 PlayMPEG 只是 PlayMIDI 的别名，无真实视频渲染）
--
-- 实测：lib_love.lua:879 `function PlayMPEG(filename) PlayMIDI(filename) end`
-- 即整个项目从没真正播过 MPEG —— 它只是把 .mpg 当音频载入。
-- 所以契约照实实现：走音频路径，返回 true。
EngineAPI.audio.playVideo = function(filename, skipKey)
    lib.PlayMPEG(filename)
    return true
end

-- 音量（REQ-VOL-1 / REQ-VOL-2）：量程 0-128，增益线性 value/128。
-- 实现在 lib_love.lua（它持有 currentMusic 与源路径解析）。
EngineAPI.audio.setMusicVolume = function(value)
    lib.SetMusicVolume(value)
end

EngineAPI.audio.getMusicVolume = function()
    return lib.GetMusicVolume()
end

EngineAPI.audio.setSFXVolume = function(value)
    lib.SetSFXVolume(value)
end

EngineAPI.audio.getSFXVolume = function()
    return lib.GetSFXVolume()
end

-- time 模块
EngineAPI.time.sleep = function(millis)
    lib.Delay(millis)
end

EngineAPI.time.getTime = function()
    return lib.GetTime()
end

EngineAPI.time.getTimeSeconds = function()
    return love.timer.getTime()
end

-- file 模块（直接使用 love.filesystem，不委托 lib_file）
EngineAPI.file.open = function(filename, mode)
    if love and love.filesystem and love.filesystem.newFile then
        return love.filesystem.newFile(filename, mode or "r")
    end
    return io.open(filename, mode or "r")
end

EngineAPI.file.openFile = function(filename, mode)
    if love and love.filesystem and love.filesystem.newFile then
        local f = love.filesystem.newFile(filename)
        if f then
            local ok = f:open(mode or "r")
            if ok then
                return { file = f, mode = mode or "r", loveStream = true }
            end
        end
    end
    return io.open(filename, mode or "r")
end

EngineAPI.file.remove = function(filename)
    if love and love.filesystem and love.filesystem.remove then
        return love.filesystem.remove(filename)
    end
    return os.remove(filename)
end

EngineAPI.file.getSize = function(filename)
    local info = love.filesystem.getInfo(filename)
    if info then
        return info.size
    end
    return -1
end

EngineAPI.file.exists = function(filename)
    local info = love.filesystem.getInfo(filename)
    return info ~= nil
end

EngineAPI.file.getInfo = function(filename)
    if love and love.filesystem and love.filesystem.getInfo then
        return love.filesystem.getInfo(filename)
    end
    local f = io.open(filename, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return { size = size, modtime = nil, type = "file" }
end

EngineAPI.file.read = function(filename)
    if love and love.filesystem and love.filesystem.read then
        return love.filesystem.read(filename)
    end
    local f = io.open(filename, "rb")
    if f then
        local content = f:read("*a")
        f:close()
        return content
    end
    return nil
end

EngineAPI.file.write = function(filename, content, mode)
    mode = mode or "w"
    if love and love.filesystem and love.filesystem.write then
        return love.filesystem.write(filename, content, mode == "a" and #content or nil)
    end
    local f = io.open(filename, mode)
    if f then
        f:write(content)
        f:close()
        return true
    end
    return false
end

EngineAPI.file.lines = function(filename)
    if love and love.filesystem and love.filesystem.lines then
        return love.filesystem.lines(filename)
    end
    local f = io.open(filename, "r")
    if f then
        return f:lines()
    end
    return function() end
end

EngineAPI.file.createDirectory = function(dirpath)
    if love and love.filesystem and love.filesystem.createDirectory then
        return love.filesystem.createDirectory(dirpath)
    end
end

-- 目录存在性 / 目录列举
--
-- 必须走 love.filesystem，不能用 io.popen 调 shell：
--   * Android 上没有 /bin/sh，也没有 ls/test；
--   * .love 打包后资源只在 love.filesystem 的虚拟文件系统里可见，
--     磁盘路径根本不存在；
--   * Windows 上 io.popen 走 cmd.exe，POSIX 命令全部失效。
-- love.filesystem.getInfo 的 type 字段是 "file" / "directory" / "symlink"，
-- 因此 getDirectoryItems 天然只列真实子项（不含 "." 与 ".."）。
EngineAPI.file.directoryExists = function(dirpath)
    if not dirpath or dirpath == "" then return false end
    if love and love.filesystem and love.filesystem.getInfo then
        local ok, info = pcall(love.filesystem.getInfo, dirpath)
        if ok and info and info.type == "directory" then
            return true
        end
        return false
    end
    -- 无 love.filesystem（纯 Lua 测试环境）：退回 fs_compat
    local ok, Fs = pcall(require, "framework.fs_compat")
    if ok and Fs then return Fs.directoryExists(dirpath) end
    return false
end

EngineAPI.file.listDirectory = function(dirpath)
    if not dirpath or dirpath == "" then return {} end
    if love and love.filesystem and love.filesystem.getDirectoryItems then
        local ok, items = pcall(love.filesystem.getDirectoryItems, dirpath)
        if ok and type(items) == "table" then
            return items
        end
        return {}
    end
    local ok, Fs = pcall(require, "framework.fs_compat")
    if ok and Fs then return Fs.listDirectory(dirpath) end
    return {}
end

-- script 模块
EngineAPI.script.load = function(path)
    -- 优先使用 love.filesystem.load（支持 .love 打包）
    if love and love.filesystem and love.filesystem.load then
        local chunk, err = love.filesystem.load(path)
        if chunk then
            return chunk
        end
        -- 回退：尝试加 game/ 前缀
        local chunk2, err2 = love.filesystem.load("game/" .. path)
        if chunk2 then
            return chunk2
        end
        -- 回退到 loadfile
        return loadfile(path) or loadfile("game/" .. path), err2
    end
    return loadfile(path) or loadfile("game/" .. path)
end

-- font 模块
--- 量文本真实像素宽度
--
-- TextBoxLayout.textWidth 会优先用它；本函数返回 nil 时那边退回 em 估算。
--
-- **返回值合理性校验是必须的**：测试环境里的 love stub（
-- test_mod_boot 的 installLoveStub / tests.mod_boot_harness）把
-- `newFont()` 的 `getWidth` 桩成恒返回 1。若这里照单全收，
-- TextBoxLayout.textWidth 就返回 1，全量测试里所有菜单框宽会塌成
-- 1 + 边框（实测连砸 6 条断言）。
--
-- 判据：宽度必须 > 0 且 >= 字号的 0.4 倍（任何真实字体最窄字形也不会低于此）。
-- 不满足就返回 nil，让调用方走 em 估算 —— 宁可略粗也不给垃圾值。
EngineAPI.font.measureText = function(str, size, fontName)
    if type(str) ~= "string" or str == "" then return 0 end
    if type(size) ~= "number" or size <= 0 then return nil end
    local okFont, font = pcall(EngineAPI.font.get, fontName, size)
    if not okFont or not font then return nil end
    local okW, w = pcall(font.getWidth, font, str)
    if not okW or type(w) ~= "number" then return nil end
    -- 合理性下限：一号字最窄也有约 0.4em（simsun 全角 1em、半角 0.5em；
    -- 即使换非等宽字体，任何单字符也不会窄于 0.4em）
    local minExpected = #str * size * 0.4
    if w < minExpected then return nil end
    return w
end

EngineAPI.font.get = function(fontName, size)
    -- lib_love 内部有 getFont 函数，但未导出
    -- 使用 love.graphics.newFont 直接实现
    if fontName == nil then
        return love.graphics.newFont(size or 20)
    end
    local success, font = pcall(function() return love.graphics.newFont(fontName, size or 20) end)
    if success then
        return font
    end
    return love.graphics.newFont(20)
end

-- dialog 模块
--
-- 对话框排版与绘制。排版算法本身在 framework/dialog_layout.lua（纯函数），
-- 本模块只负责：
--   ① 提供真实字体度量（font:getWidth / getHeight），这是 Love2D 独有的能力；
--   ② 决定 6 个 flag 的锚点坐标（屏幕尺寸相关，mud/web 不需要）；
--   ③ 实际绘制（头像框 + 对话框 + 文本行）。
--
-- 为什么 measure 必须是纯函数：它会被单测直接调用，且每帧不应重算。
-- 调用方（framework/talk_async.lua）在进入新页时 measure 一次并缓存 layout。
local DialogLayout = require("framework.dialog_layout")

-- 对话框布局常量（与原版 TalkEx 对齐）
local DLG_PICW, DLG_PICH = 100, 100          -- 最大头像宽高
local DLG_BOXPICW, DLG_BOXPICH = 110, 110    -- 头像框 = pic + 10
local DLG_DX, DLG_DY = 2, 2                  -- 屏幕边距
local DLG_PAD = 5                            -- 框内边距
local DLG_MINLINES = 3                       -- 框高按 3 行算（不足留空）
local DLG_MAXW = nil                         -- 延迟计算（依赖 CC.ScreenW）

local function dlgMaxWidth()
    if DLG_MAXW == nil then
        local screenW = (CC and CC.ScreenW) or 1024
        DLG_MAXW = screenW - 2 * DLG_DX - DLG_BOXPICW - 2
    end
    return DLG_MAXW
end

-- 绘制带背景的方框（引擎内自绘，不依赖 script/jymain.lua 的 DrawBox）
--
-- 复刻 script/jymain.lua:2079 DrawBox 的视觉：先填半透明黑底再描两道凹角白边。
-- 引擎不能 require script 层（依赖方向：engine → framework/script 单向），
-- 所以这里用 lib.Background / lib.DrawRect 原语重写同一效果。
local function dlgDrawBox(x1, y1, x2, y2, color)
    local s = 4
    lib.Background(x1, y1 + s, x1 + s, y2 - s, 128)
    lib.Background(x1 + s, y1, x2 - s, y2, 128)
    lib.Background(x2 - s, y1 + s, x2, y2 - s, 128)

    local r, g, b = EngineAPI.color.unpack(color % 0x1000000)
    -- 内层深色描边
    local dark = EngineAPI.color.pack(
        math.floor(r * 255 / 2),
        math.floor(g * 255 / 2),
        math.floor(b * 255 / 2))

    local function box1(bx1, by1, bx2, by2, col)
        local ss = 4
        local segs = {
            { bx1 + ss, by1, bx2 - ss, by1 },
            { bx2 - ss, by1, bx2 - ss, by1 + ss },
            { bx2 - ss, by1 + ss, bx2, by1 + ss },
            { bx2, by1 + ss, bx2, by2 - ss },
            { bx2, by2 - ss, bx2 - ss, by2 - ss },
            { bx2 - ss, by2 - ss, bx2 - ss, by2 },
            { bx2 - ss, by2, bx1 + ss, by2 },
            { bx1 + ss, by2, bx1 + ss, by2 - ss },
            { bx1 + ss, by2 - ss, bx1, by2 - ss },
            { bx1, by2 - ss, bx1, by1 + ss },
            { bx1, by1 + ss, bx1 + ss, by1 + ss },
            { bx1 + ss, by1 + ss, bx1 + ss, by1 },
        }
        for _, sg in ipairs(segs) do
            lib.DrawRect(sg[1], sg[2], sg[3], sg[4], col)
        end
    end

    box1(x1 + 1, y1 + 1, x2, y2, dark)
    box1(x1, y1, x2 - 1, y2 - 1, color)
end

-- 取字体：优先真实字体名，回退 LÖVE 内置
local function dlgFont(size)
    local fontname = (CC and CC.FontName) or nil
    local ok, font = pcall(function()
        return lib.getFont(fontname, size)
    end)
    if ok and font then
        return font
    end
    return love.graphics.newFont(size)
end

-- 由框宽和 flag 计算锚点坐标
local function dlgBoxes(flag, boxW, boxH)
    local screenW = (CC and CC.ScreenW) or 1024
    local screenH = (CC and CC.ScreenH) or 768
    local rightHeadX = screenW - 1 - DLG_DX - DLG_BOXPICW
    local bottomY = screenH - DLG_DY - DLG_BOXPICH
    local leftTalkX = DLG_DX + DLG_BOXPICW + 2
    -- 右锚定：talkx 随实际框宽重算，保证右边界贴住头像框
    local rightTalkX = screenW - 1 - DLG_DX - DLG_BOXPICW - boxW - 2

    -- flag 语义（与原版 xy 表一致）：
    --   0 左上+头像   1 右下+头像   2 左上无头像
    --   3 右下+头像   4 右上+头像   5 左下+头像
    local anchors = {
        [0] = { headX = DLG_DX, headY = DLG_DY,               talkX = leftTalkX,  talkY = DLG_DY,      showHead = true },
        [1] = { headX = rightHeadX, headY = bottomY,          talkX = rightTalkX, talkY = bottomY,     showHead = true },
        [2] = { headX = DLG_DX, headY = DLG_DY,               talkX = leftTalkX,  talkY = DLG_DY,      showHead = false },
        [3] = { headX = rightHeadX, headY = bottomY,          talkX = rightTalkX, talkY = bottomY,     showHead = true },
        [4] = { headX = rightHeadX, headY = DLG_DY,           talkX = rightTalkX, talkY = DLG_DY,      showHead = true },
        [5] = { headX = DLG_DX, headY = bottomY,              talkX = leftTalkX,  talkY = bottomY,     showHead = true },
    }
    local a = anchors[flag] or anchors[0]

    local result = {
        textBox = { x = a.talkX, y = a.talkY, w = boxW, h = boxH },
        showHead = a.showHead,
    }
    if a.showHead then
        result.headBox = { x = a.headX, y = a.headY, w = DLG_BOXPICW, h = DLG_BOXPICH }
    end
    return result
end

--- 排版计算（纯函数：不绘制、不阻塞、不写全局状态）
EngineAPI.dialog.measure = function(spec)
    spec = spec or {}
    local text = spec.text or ""
    local headId = spec.headId or -1
    local flag = spec.flag or 0
    if flag < 0 or flag > 5 then
        flag = 0
    end

    local size = (CC and CC.DefaultFont) or 24
    local font = dlgFont(size)

    -- 真实像素测量：自适应字体 / 字号 / 分辨率的关键
    local widthFn
    if font and font.getWidth then
        widthFn = function(s)
            return font:getWidth(s)
        end
    else
        widthFn = DialogLayout.emWidthFn(size)
    end

    -- 行高取真实 getHeight（实测 27，≠ 字号 24）。
    -- 若直接拿 CC.DefaultFont 当行高，每行差 3px，3 行累计 9px，下行会被上行挤压。
    local lineHeight = size
    if font and font.getHeight then
        local ok, h = pcall(function() return font:getHeight() end)
        if ok and h and h > 0 then
            lineHeight = h
        end
    end
    if lineHeight < size then
        lineHeight = size * 1.125   -- 回退估算：24 * 1.125 = 27
    end

    local lay = DialogLayout.layoutText(text, {
        size = size,
        pad = DLG_PAD,
        minWidth = 12 * size + 10,
        maxWidth = dlgMaxWidth(),
        linesPerPage = DLG_MINLINES,
        widthFn = widthFn,
    })

    local boxes = dlgBoxes(flag, lay.width, DLG_BOXPICH)
    if not boxes.showHead then
        headId = -1
    end

    -- 行 y 坐标：按 3 行固定算边距，不足 3 行则顶部对齐、下方留空。
    -- talkBorder = (110 - 3*27) / 4 = 7.25
    local border = (DLG_BOXPICH - DLG_MINLINES * lineHeight) / (DLG_MINLINES + 1)
    local lineY = {}
    for i = 1, #lay.lines do
        lineY[i] = boxes.textBox.y + DLG_PAD + border + (i - 1) * lineHeight
    end

    return {
        width = lay.width,
        height = DLG_BOXPICH,
        lineHeight = lineHeight,
        lines = lay.lines,
        pages = lay.pages,
        linesPerPage = lay.linesPerPage,
        headId = headId,
        flag = flag,
        headBox = boxes.headBox,
        textBox = boxes.textBox,
        border = border,
        lineY = lineY,
        fontSize = size,
    }
end

--- 绘制对话（只能在 love.draw() 内调用）
EngineAPI.dialog.draw = function(spec, layout)
    if not layout then
        return
    end
    local size = layout.fontSize or ((CC and CC.DefaultFont) or 24)
    local color = (_G and _G.C_WHITE) or 0xFFFFFF

    -- 头像框 + 头像
    if layout.showHead ~= false and layout.headId and layout.headId >= 0 and layout.headBox then
        local hb = layout.headBox
        dlgDrawBox(hb.x, hb.y, hb.x + hb.w, hb.y + hb.h, color)
        -- 头像贴图（archive 1 = HeadPic 档案）
        --
        -- **原来走 `lib.PicGetXY` / `lib.PicLoadCache`** —— 那两个读
        -- 引擎的 `picFileCache`，而 `SpriteAtlas.loadArchive` 不写它。
        -- 所以摘掉 `LoadArchiveBoth` 的双写后头像就不见了（实测：右下角框变空）。
        --
        -- 现在改走 `SpriteAtlas`：`getMeta` 拿尺寸算居中，`draw` 画 handle。
        -- 与 `battle_render` / `map_render` 的迁移是同一套约定。
        local SA = nil
        do
            local okSA, mod = pcall(require, "framework.sprite_atlas")
            if okSA then SA = mod end
        end
        if SA and SA.getMeta then
            local meta = SA.getMeta(1, layout.headId * 2)
            local w = meta and meta.w or 0
            local h = meta and meta.h or 0
            local offX = (DLG_PICW - w) / 2
            local offY = (DLG_PICH - h) / 2
            SA.draw(1, layout.headId * 2, hb.x + 5 + offX, hb.y + 5 + offY, 0x1)
        else
            -- **显式降级：不画头像**（port-legacy-picture-removal Task 2）
            --
            -- 原来这里退回 `lib.PicGetXY` / `lib.PicLoadCache`（读 picFileCache）。
            -- 那条链已随旧贴图子系统一起拆除，且退回它只会掩盖
            -- 「framework 模块缺失」这个真问题（换引擎时看起来「还能跑」，
            -- 实际仍要重写 RLE 解码）。
            -- 宁可少一个头像也要让失败可见。
            if EngineAPI.debug and EngineAPI.debug.log then
                EngineAPI.debug.log("dialog.draw: framework.sprite_atlas unavailable, "
                                    .. "skipping head picture (headId=" .. tostring(layout.headId) .. ")")
            end
        end
    end

    -- 对话框（框宽由 measure 决定，随内容自适应）
    local tb = layout.textBox
    dlgDrawBox(tb.x, tb.y, tb.x + tb.w, tb.y + tb.h, color)

    -- 文本行：行距用真实行高 lineHeight（27），不是 CC.DefaultFont（24）
    local fontname = (CC and CC.FontName) or nil
    for i, line in ipairs(layout.lines) do
        if line and line ~= "" then
            lib.DrawStr(tb.x + DLG_PAD, layout.lineY[i], line, color, size, fontname)
        end
    end
end

--- 清除对话状态（幂等）
EngineAPI.dialog.clear = function()
    -- 无引擎侧缓存状态；layout 由调用方持有
end

-- color 模块
EngineAPI.color.pack = function(r, g, b)
    return r * 65536 + g * 256 + b
end

EngineAPI.color.unpack = function(color)
    color = color % (65536 * 256)
    local r = math.floor(color / 65536)
    color = color % 65536
    local g = math.floor(color / 256)
    local b = color % 256
    return r / 255, g / 255, b / 255
end

-- debug 模块
EngineAPI.debug.log = function(...)
    lib.Debug(...)
end

-- coroutine 模块
-- 注意：LuaJIT/Lua5.1 的 coroutine.running() 在主线程也返回非 nil
-- （返回主线程对象 + ismain=true），所以不能只用 ~= nil 判断。
-- 必须用第二个返回值 ismain 排除主线程；Lua5.2+ 主线程返回 nil。
EngineAPI.coroutine.isRunning = function()
    local co, ismain = coroutine.running()
    if co == nil then return false end
    if ismain == true then return false end
    return true
end
-- 只暴露 EngineAPI 这一个全局。
--
-- **`_G.lib` 已删除**（port-compat-layer-removal）：
--   它曾经是 `setmetatable(EngineAPI, { __index = lib })` —— 等价于把
--   `lib` 与 `EngineAPI` 变成**同一张表**，于是任何 `lib.xxx = ...` 都会
--   往 EngineAPI 写一个契约外的键（`async_globals` 的 Delay 补丁就这么错了位）。
--   实测依据：27808 个事件脚本（1018 基础 + 20 MOD 的 26790）零 `lib.*`，
--   framework/script/入口 也已零 `lib.*` → 这条回退通道没有消费者了。
_G.EngineAPI = EngineAPI

-- 向后兼容：添加 lib_love 中已有的函数，供现有代码直接调用
EngineAPI.SetDrawLoopFlag = function(flag)
    if lib.SetDrawLoopFlag then
        lib.SetDrawLoopFlag(flag)
    end
end

-- **已删除的偷渡键**（port-legacy-picture-removal Task 6）：
--   `EngineAPI.PicInit`     → 调色板归 framework（见 sprite.initSprites）
--   `EngineAPI.LoadPicture` → 用 `sprite.drawPictureFile`（真正在用的那个）
-- 它们从来不是契约（engine_api.lua 没声明），只是 lib_love 的透传。

EngineAPI.ShowSurface = function(flag)
    lib.ShowSurface(flag)
end

EngineAPI.ShowSlow = function(delay, flag)
    lib.ShowSlow(delay, flag)
end

-- Love2D 引擎初始化
EngineAPI.init = function()
    if love.graphics then
        love.graphics.setBlendMode("alpha")
        love.graphics.setDefaultFilter("nearest", "nearest")
        love.graphics.setBackgroundColor(0, 0, 0, 1)
    end
    math.randomseed(os.time())
    math.random()
end

EngineAPI.app = EngineAPI.app or {}
EngineAPI.app.toggleFullscreen = function()
    lib.FullScreen()
    return true
end

EngineAPI.app.quit = function()
    love.event.quit()
end

-- system 模块（REQ-MS1-1）
--
-- love.system.getOS() 返回 "Windows"|"Linux"|"OS X"|"Android"|"iOS"。
-- 注意 LÖVE 用的是 "OS X" 而不是 "macOS"，这里统一成 "macOS"，
-- 让调用方的字符串判断与文档一致（只此一处做映射）。
EngineAPI.system = EngineAPI.system or {}
EngineAPI.system.getOS = function()
    if not (love and love.system and love.system.getOS) then
        return "unknown"
    end
    local ok, osName = pcall(love.system.getOS)
    if not ok or type(osName) ~= "string" then
        return "unknown"
    end
    if osName == "OS X" then
        return "macOS"
    end
    return osName
end

return EngineAPI