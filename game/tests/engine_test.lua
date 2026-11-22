-- engine_test.lua
-- 命令行测试引擎 - 实现 EngineAPI 接口
-- 所有渲染/音频为空操作，输入返回预设值
-- 用于 CI/CD 和单元测试，无需显示器

-- 裸名 require 别名（script/jymain.lua:15-16 的 `require "lib_file"` 等）：
-- 注册逻辑的唯一来源是 framework/require_aliases.lua（幂等，可重复 require）。
--
-- 测试桩也要注册：`tests.engine_test` 是「引擎实现」之一，
-- 与 engine_mud / engine_web 并列跑 conformance 检查；
-- 一旦有测试用本桩去跑 script 层（如 headless 引导），
-- 少了这条就会死在 `module 'lib_file' not found`。
require("framework.require_aliases")

local EngineAPI = require("engine-love2d.engine_api")

-- 调用日志
EngineAPI._callLog = {}
EngineAPI._logEnabled = false

local function logCall(funcName, ...)
    if EngineAPI._logEnabled then
        table.insert(EngineAPI._callLog, { func = funcName, args = { ... } })
    end
end

-- 预设按键队列
local keyQueue = {}

--- 设置预设按键队列
function EngineAPI._setKeyQueue(keys)
    keyQueue = keys or {}
end

--- 清空调用日志
function EngineAPI._clearLog()
    EngineAPI._callLog = {}
end

--------------------------------------------------------------------
-- render 模块 - 所有函数为空操作
--------------------------------------------------------------------
EngineAPI.render.text = function(x, y, str, color, size)
    logCall("render.text", x, y, str, color, size)
end

EngineAPI.render.fillRect = function(x1, y1, x2, y2, color)
    logCall("render.fillRect", x1, y1, x2, y2, color)
end

EngineAPI.render.rectOutline = function(x1, y1, x2, y2, color)
    logCall("render.rectOutline", x1, y1, x2, y2, color)
end

EngineAPI.render.drawBackground = function(x1, y1, x2, y2, brightness)
    logCall("render.drawBackground", x1, y1, x2, y2, brightness)
end

EngineAPI.render.setClip = function(x1, y1, x2, y2)
    logCall("render.setClip", x1, y1, x2, y2)
    EngineAPI.render._clip = { x = x1, y = y1, w = (x2 - x1), h = (y2 - y1) }
end

EngineAPI.render.getClip = function()
    logCall("render.getClip")
    -- 与 setClip 对称：未设过裁剪时返回屏幕全尺寸哨兵
    return EngineAPI.render._clip or { x = 0, y = 0, w = 1024, h = 768 }
end

EngineAPI.render.present = function()
    logCall("render.present")
end

--- 可注入的渲染尺寸（虚拟手柄等需要）
EngineAPI.render._width = 1024
EngineAPI.render._height = 768

EngineAPI.render.getWidth = function()
    return EngineAPI.render._width
end

EngineAPI.render.getHeight = function()
    return EngineAPI.render._height
end

EngineAPI.render.presentAndWait = function(delay)
    logCall("render.presentAndWait", delay)
end

EngineAPI.render.setDrawLoopFlag = function(flag)
    logCall("render.setDrawLoopFlag", flag)
end

EngineAPI.render.beginFrame = function()
    logCall("render.beginFrame")
end

EngineAPI.render.endFrame = function()
    logCall("render.endFrame")
end

--------------------------------------------------------------------
-- sprite 模块 - 只保留 createFromRGBA/drawHandle 等格式透明契约
--------------------------------------------------------------------

EngineAPI.sprite.initSprites = function()
    logCall("sprite.initSprites")
end

-- **`sprite.loadArchive` / `sprite.draw` / `sprite.drawTinted` 已删除**
-- （port-legacy-picture-removal）：零消费者。

-- 可注入的纹理创建（测试多格式路径用）
EngineAPI.sprite._failCreate = false

EngineAPI.sprite.createFromRGBA = function(w, h, rgbaBytes, opts)
    logCall("sprite.createFromRGBA", w, h)
    if EngineAPI.sprite._failCreate then return nil end
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return nil end
    if type(rgbaBytes) ~= "string" or #rgbaBytes < w * h * 4 then return nil end
    opts = opts or {}
    return { w = w, h = h, xoff = opts.xoff or 0, yoff = opts.yoff or 0,
             rgbaLen = #rgbaBytes }
end

EngineAPI.sprite.createFromEncoded = function(bytes, formatHint, opts)
    logCall("sprite.createFromEncoded", formatHint)
    if EngineAPI.sprite._failCreate then return nil end
    if type(bytes) ~= "string" or bytes == "" then return nil end
    opts = opts or {}
    -- 测试桩不做真实解码，返回一个标记格式的 handle
    return { w = 10, h = 10, xoff = opts.xoff or 0, yoff = opts.yoff or 0,
             format = formatHint }
end

--- 绘制独立图片：测试桩记录调用
EngineAPI.sprite._pictureCalls = {}
EngineAPI.sprite.drawPictureFile = function(filename, x, y, opts)
    logCall("sprite.drawPictureFile", filename, x, y)
    table.insert(EngineAPI.sprite._pictureCalls, { filename, x, y })
    return true
end

--- 绘制句柄：测试桩记录调用
EngineAPI.sprite._handleDraws = {}
EngineAPI.sprite.drawHandle = function(handle, x, y, flags, alpha)
    logCall("sprite.drawHandle", x, y)
    -- 记录 flags/alpha：云层与 map_render 都要断言「flag 位 / alpha 值」
    table.insert(EngineAPI.sprite._handleDraws,
        { handle = handle, x = x, y = y, flags = flags, alpha = alpha })
    return type(handle) == "table"
end

EngineAPI.sprite.drawHandleTinted = function(handle, x, y, color, alpha)
    logCall("sprite.drawHandleTinted", x, y)
    return type(handle) == "table"
end

EngineAPI.sprite.getMeta = function(handle)
    if type(handle) ~= "table" then return nil end
    return { w = handle.w or 0, h = handle.h or 0,
             xoff = handle.xoff or 0, yoff = handle.yoff or 0 }
end

--------------------------------------------------------------------
-- map 模块 - load* 正常加载数据，draw* 为空操作
--------------------------------------------------------------------
EngineAPI.map.loadMain = function(earthFile, surfaceFile, buildingFile, buildXFile, buildYFile, width, height, x, y)
    logCall("map.loadMain", earthFile, surfaceFile, buildingFile, buildXFile, buildYFile, width, height, x, y)
end

EngineAPI.map.loadScene = function(sFile, tmpFile, num, width, height, dFile, dNum1, dNum2)
    logCall("map.loadScene", sFile, tmpFile, num, width, height, dFile, dNum1, dNum2)
end

EngineAPI.map.saveScene = function(sFile, dFile)
    logCall("map.saveScene", sFile, dFile)
end

EngineAPI.map.loadBattle = function(idxFile, grpFile, mapId, num, width, height)
    logCall("map.loadBattle", idxFile, grpFile, mapId, num, width, height)
end

EngineAPI.map.drawMain = function(playerX, playerY, playerPic)
    logCall("map.drawMain", playerX, playerY, playerPic)
end

--- 可注入的地图瓦片（测试用）
EngineAPI.map._tiles = {}
EngineAPI.map._sceneTiles = {}
EngineAPI.map._sceneEventData = {}
EngineAPI.map._battleTiles = {}
EngineAPI.map.getTile = function(x, y, layer)
    logCall("map.getTile", x, y, layer)
    local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(layer)
    local v = EngineAPI.map._tiles[key]
    if v == nil then return -1 end
    return v
end

EngineAPI.map.setTile = function(x, y, layer, value)
    logCall("map.setTile", x, y, layer, value)
    EngineAPI.map._tiles[tostring(x) .. "," .. tostring(y) .. "," .. tostring(layer)] = value
end

EngineAPI.map.getSceneTile = function(sceneId, x, y, layer)
    logCall("map.getSceneTile", sceneId, x, y, layer)
    local key = tostring(sceneId) .. "," .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(layer)
    local v = EngineAPI.map._sceneTiles[key]
    if v == nil then return 0 end
    return v
end

EngineAPI.map.setSceneTile = function(sceneId, x, y, layer, value)
    logCall("map.setSceneTile", sceneId, x, y, layer, value)
    EngineAPI.map._sceneTiles[tostring(sceneId) .. "," .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(layer)] = value
end

EngineAPI.map.getSceneEventData = function(sceneId, eventId, field)
    logCall("map.getSceneEventData", sceneId, eventId, field)
    local v = EngineAPI.map._sceneEventData[tostring(sceneId) .. "," .. tostring(eventId) .. "," .. tostring(field)]
    if v == nil then return 0 end
    return v
end

EngineAPI.map.setSceneEventData = function(sceneId, eventId, field, value)
    logCall("map.setSceneEventData", sceneId, eventId, field, value)
    EngineAPI.map._sceneEventData[tostring(sceneId) .. "," .. tostring(eventId) .. "," .. tostring(field)] = value
end

EngineAPI.map.getBattleTile = function(x, y, layer)
    logCall("map.getBattleTile", x, y, layer)
    local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(layer)
    local v = EngineAPI.map._battleTiles[key]
    if v == nil then return 0 end
    return v
end

EngineAPI.map.setBattleTile = function(x, y, layer, value)
    logCall("map.setBattleTile", x, y, layer, value)
    EngineAPI.map._battleTiles[tostring(x) .. "," .. tostring(y) .. "," .. tostring(layer)] = value
end

EngineAPI.map.clearBattleTile = function(layer, value)
    logCall("map.clearBattleTile", layer, value)
    EngineAPI.map._battleTiles = {}
end

EngineAPI.map.getSceneSize = function()
    logCall("map.getSceneSize")
    return EngineAPI.map._sceneSize or { w = 64, h = 64 }
end

EngineAPI.sprite.clearPictureCache = function()
    logCall("sprite.clearPictureCache")
end

EngineAPI.map.loadClouds = function(idxFile, grpFile)
    logCall("map.loadClouds", idxFile, grpFile)
end

EngineAPI.map.getBattleSize = function()
    logCall("map.getBattleSize")
    return EngineAPI.map._battleSize or { w = 64, h = 64 }
end

EngineAPI.map.drawClouds = function(mx, my)
    logCall("map.drawClouds", mx, my)
end

EngineAPI.map.unload = function()
    logCall("map.unload")
end

EngineAPI.map.tickClouds = function()
    logCall("map.tickClouds")
end

EngineAPI.map.drawScene = function(sceneId, x, y, offX, offY, playerPic)
    logCall("map.drawScene", sceneId, x, y, offX, offY, playerPic)
end

EngineAPI.map.drawBattle = function(flag, x, y, v1, v2, v3)
    logCall("map.drawBattle", flag, x, y, v1, v2, v3)
end

--------------------------------------------------------------------
-- input 模块 - getKey 返回 -1，waitForKey 从预设队列返回值
--------------------------------------------------------------------
EngineAPI.input.getKey = function()
    logCall("input.getKey")
    return -1
end

EngineAPI.input.waitForKey = function()
    logCall("input.waitForKey")
    if #keyQueue > 0 then
        return table.remove(keyQueue, 1)
    end
    return -1
end

EngineAPI.input.setKeyRepeat = function(delay, interval)
    logCall("input.setKeyRepeat", delay, interval)
end

-- 鼠标（REQ-MS1-2）：可注入位置与按键状态
EngineAPI.input._mouseX = -1
EngineAPI.input._mouseY = -1
EngineAPI.input._mouseDown = {}

EngineAPI.input.mousePosition = function()
    return EngineAPI.input._mouseX, EngineAPI.input._mouseY
end

EngineAPI.input.mouseButton = function(button)
    logCall("input.mouseButton", button)
    return EngineAPI.input._mouseDown[tonumber(button) or 1] == true
end

-- 物理轴 / 能力 / 指针 / 动作（input-action-layer Task 2）
--
-- 测试桩需要**可注入**：测试里要能模拟"摇杆推到底"或"没有手柄"，
-- 所以轴值与能力都放在可写字段上，而不是硬编码返回值。
EngineAPI.input._axes = {}          -- name -> -1..1
EngineAPI.input._capabilities = { pointer = true, touch = false, gamepad = false, vr = false }
EngineAPI.input._actionQueue = {}    -- 预置动作队列（pollAction 从这里取）

EngineAPI.input.getAxis = function(name)
    logCall("input.getAxis", name)
    local v = EngineAPI.input._axes[name]
    if type(v) ~= "number" then return 0 end
    if v < -1 then return -1 elseif v > 1 then return 1 end
    return v
end

EngineAPI.input.getCapabilities = function()
    logCall("input.getCapabilities")
    local c = EngineAPI.input._capabilities
    return { pointer = c.pointer, touch = c.touch, gamepad = c.gamepad, vr = c.vr }
end

EngineAPI.input.getPointerPosition = function()
    logCall("input.getPointerPosition")
    return EngineAPI.input.mousePosition()
end

EngineAPI.input.enableKeyRepeat = function(delay, interval)
    logCall("input.enableKeyRepeat", delay, interval)
end

EngineAPI.input.pollAction = function()
    logCall("input.pollAction")
    if #EngineAPI.input._actionQueue > 0 then
        return table.remove(EngineAPI.input._actionQueue, 1)
    end
    return nil
end

-- 触摸点：可注入（测试虚拟手柄时用）
EngineAPI.input._touches = {}
EngineAPI.input.getTouches = function()
    logCall("input.getTouches")
    return EngineAPI.input._touches
end

--------------------------------------------------------------------
-- audio 模块 - 所有函数为空操作
--------------------------------------------------------------------
EngineAPI.audio.playMusic = function(filename)
    logCall("audio.playMusic", filename)
end

EngineAPI.audio.playSFX = function(filename)
    logCall("audio.playSFX", filename)
end

EngineAPI.audio.stopMusic = function()
    logCall("audio.stopMusic")
end

EngineAPI.audio.playSequence = function(filenameOrId, opts)
    logCall("audio.playSequence")
    return true
end

-- 播放视频：测试桩无视频能力 → 返回 false（与 LÖVE 实现一致）
EngineAPI.audio.playVideo = function(filename, skipKey)
    logCall("audio.playVideo", filename)
    return false
end

-- 音量（REQ-VOL-1）：测试引擎记录调用并保存状态，
-- 这样测试既能断言「框架真的调到了引擎」，又能验证读写回读。
EngineAPI.audio.setMusicVolume = function(value)
    logCall("audio.setMusicVolume", value)
    EngineAPI.audio._musicVolume = tonumber(value) or EngineAPI.audio._musicVolume
end

EngineAPI.audio.getMusicVolume = function()
    return EngineAPI.audio._musicVolume
end

EngineAPI.audio.setSFXVolume = function(value)
    logCall("audio.setSFXVolume", value)
    EngineAPI.audio._sfxVolume = tonumber(value) or EngineAPI.audio._sfxVolume
end

EngineAPI.audio.getSFXVolume = function()
    return EngineAPI.audio._sfxVolume
end

EngineAPI.audio._musicVolume = 64
EngineAPI.audio._sfxVolume = 90

--------------------------------------------------------------------
-- time 模块 - sleep 直接返回，getTime 返回 os.clock
--------------------------------------------------------------------
EngineAPI.time.sleep = function(millis)
    logCall("time.sleep", millis)
    -- 不等待，直接返回
end

EngineAPI.time.getTime = function()
    return os.clock() * 1000
end

EngineAPI.time.getTimeSeconds = function()
    return os.clock()
end

--------------------------------------------------------------------
-- file 模块 - 正常实现
--------------------------------------------------------------------
EngineAPI.file.open = function(filename, mode)
    logCall("file.open", filename, mode)
    return io.open(filename, mode)
end

EngineAPI.file.openFile = function(filename, mode)
    logCall("file.openFile", filename, mode)
    return io.open(filename, mode or "r")
end

EngineAPI.file.remove = function(filename)
    logCall("file.remove", filename)
    return os.remove(filename)
end

EngineAPI.file.getSize = function(filename)
    logCall("file.getSize", filename)
    local f = io.open(filename, "rb")
    if f then
        local size = f:seek("end")
        f:close()
        return size
    end
    return -1
end

EngineAPI.file.exists = function(filename)
    logCall("file.exists", filename)
    local f = io.open(filename, "r")
    if f then
        f:close()
        return true
    end
    return false
end

EngineAPI.file.getInfo = function(filename)
    logCall("file.getInfo", filename)
    local f = io.open(filename, "rb")
    if not f then
        return nil
    end
    local size = f:seek("end")
    f:close()
    return { size = size, modtime = nil, type = "file" }
end

EngineAPI.file.read = function(filename)
    logCall("file.read", filename)
    local f = io.open(filename, "rb")
    if f then
        local content = f:read("*a")
        f:close()
        return content
    end
    return nil
end

EngineAPI.file.write = function(filename, content, mode)
    logCall("file.write", filename, content, mode)
    mode = mode or "w"
    local f = io.open(filename, mode)
    if f then
        f:write(content)
        f:close()
        return true
    end
    return false
end

EngineAPI.file.lines = function(filename)
    logCall("file.lines", filename)
    local f = io.open(filename, "r")
    if f then
        return f:lines()
    end
    return function() end
end

EngineAPI.file.createDirectory = function(dirpath)
    logCall("file.createDirectory", dirpath)
    local ok, Fs = pcall(require, "framework.fs_compat")
    if ok and Fs then return Fs.makeDirectory(dirpath) end
end

-- 目录原语：无头引擎跑在宿主文件系统上，用 fs_compat 的跨平台实现。
-- （engine_api.lua 里的同名声明是空函数，不覆盖就会让 ModData.dirExists
--   恒为 false —— 那正是 Windows 上 MOD 路径回退整组失败的根因之一。）
EngineAPI.file.directoryExists = function(dirpath)
    logCall("file.directoryExists", dirpath)
    local ok, Fs = pcall(require, "framework.fs_compat")
    if ok and Fs then return Fs.directoryExists(dirpath) end
    return false
end

EngineAPI.file.listDirectory = function(dirpath)
    logCall("file.listDirectory", dirpath)
    local ok, Fs = pcall(require, "framework.fs_compat")
    if ok and Fs then return Fs.listDirectory(dirpath) end
    return {}
end

--------------------------------------------------------------------
-- script 模块 - 正常 loadfile
--------------------------------------------------------------------
EngineAPI.script.load = function(path)
    logCall("script.load", path)
    local candidates = { path, "game/" .. path }
    for _, p in ipairs(candidates) do
        local chunk, err = loadfile(p)
        if chunk then
            return chunk
        end
    end
    return nil, "failed to load: " .. tostring(path)
end

--------------------------------------------------------------------
-- font 模块 - 返回存根对象
--------------------------------------------------------------------
--- 可注入的字体度量
--
-- **默认返回 nil（不是从 love stub 量）**：
-- 测试环境的 love stub 里 newFont 返回的 getWidth 恒为 1
-- （test_mod_boot 的 installLoveStub），若这里去量真实宽度，
-- 会让 TextBoxLayout.textWidth 返回垃圾值 1，进而把全量测试里
-- 所有菜单框宽算成 1+边框 —— 实测真的踩到了（6 条断言连锁失败）。
--
-- 需要真实度量的测试显式注入 _measureWidth；不需要的一律拿 nil 走 em 估算。
EngineAPI.font._measureWidth = nil

EngineAPI.font.measureText = function(str, size, fontName)
    if type(EngineAPI.font._measureWidth) == "function" then
        return EngineAPI.font._measureWidth(str, size, fontName)
    end
    return nil
end

EngineAPI.font.get = function(fontName, size)
    logCall("font.get", fontName, size)
    return { name = fontName, size = size }
end

--------------------------------------------------------------------
-- color 模块 - 正常实现
--------------------------------------------------------------------
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

--------------------------------------------------------------------
-- debug 模块 - 打印到控制台
--------------------------------------------------------------------
EngineAPI.debug.log = function(...)
    logCall("debug.log", ...)
    print(...)
end

--------------------------------------------------------------------
-- coroutine 模块
--------------------------------------------------------------------
EngineAPI.coroutine.isRunning = function()
    local co, ismain = coroutine.running()
    if co == nil then return false end
    if ismain == true then return false end
    return true
end
--------------------------------------------------------------------
-- 向后兼容
--------------------------------------------------------------------
EngineAPI.SetDrawLoopFlag = function(flag) end
EngineAPI.PicInit = function() end
EngineAPI.ShowSurface = function() end
EngineAPI.ShowSlow = function() end
EngineAPI.LoadPicture = function() end

-- 设置全局 lib
_G.EngineAPI = EngineAPI
_G.lib = setmetatable(EngineAPI, { __index = {
    Debug = function(...) EngineAPI.debug.log(...) end,
    GetTime = EngineAPI.time.getTime,
    Delay = EngineAPI.time.sleep,
} })

EngineAPI.init = function() end

EngineAPI.app = EngineAPI.app or {}

EngineAPI.app.toggleFullscreen = function()
    logCall("app.toggleFullscreen")
    EngineAPI.app._fullscreen = not EngineAPI.app._fullscreen
    return true
end
EngineAPI.app.quit = function()
    logCall("app.quit")
end

EngineAPI.app.install = function(runtimeTable)
    logCall("app.install")
    local ok, Boot = pcall(require, "framework.boot")
    if not ok or not Boot then return false end
    return Boot.install(runtimeTable)
end

EngineAPI.app.requestQuit = function()
    logCall("app.requestQuit")
    local ok, Boot = pcall(require, "framework.boot")
    if ok and Boot and type(Boot.requestQuit) == "function" then
        return Boot.requestQuit()
    end
    return false
end

EngineAPI.app.setMusicTemplate = function(template, startOffset)
    logCall("app.setMusicTemplate", template, startOffset)
    EngineAPI.app._musicTemplate = (type(template) == "string" and template ~= "")
        and template or nil
    EngineAPI.app._musicStartOffset = tonumber(startOffset) or 0
end

EngineAPI.app.getMusicTemplate = function()
    return EngineAPI.app._musicTemplate, EngineAPI.app._musicStartOffset
end

---------------------------------------------------------------------
-- system 模块（REQ-MS1-1）- 平台名可注入，便于测试各平台分支
--
-- 用**闭包变量**存平台名，不用表字段。
--
-- 原因（踩过的坑）：engine_test.lua 与 engine_mud.lua 都 require 同一个
-- engine_api 表并往上挂实现，而 TestHelper.mockEngineAPI 会把 _G.EngineAPI
-- 指向另一个新表。若 getOS 写成「读 EngineAPI.system._os」，一旦表被替换/
-- 重新加载，读到的就是另一个表（字段为 nil → 返回 "unknown"），
-- 表现为「全量跑失败、单跑通过」。
-- 闭包变量不依赖任何表，天然免疫。
---------------------------------------------------------------------
EngineAPI.system = EngineAPI.system or {}

local testOS = "Windows"

--- 注入平台名（测试用）
-- @param name string
function EngineAPI.system.setOS(name)
    testOS = name or "Windows"
end

EngineAPI.system.getOS = function()
    logCall("system.getOS")
    return testOS
end

return EngineAPI