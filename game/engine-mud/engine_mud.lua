-- engine_mud.lua
-- 命令行测试引擎 - 实现 EngineAPI 接口
-- 所有渲染/音频为空操作，输入返回预设值
-- 用于 CI/CD 和单元测试，无需显示器

-- 裸名 require 别名（script/jymain.lua:15-16 的 `require "lib_file"` 等）：
-- 注册逻辑的唯一来源是 framework/require_aliases.lua。
--
-- **为什么 MUD 引擎也必须有**：MUD 引擎原先完全没有这段注册，所以它
-- 根本跑不了 script 层 —— 一旦入口 require jymain 就死在
-- `module 'lib_file' not found`。契约里现在把「require 别名模块」
-- 写进了新引擎实现清单（见 engine_api.lua），这是四个引擎的共同前提。
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
end
EngineAPI.render.getClip = function()
    logCall("render.getClip")
    return { x = 0, y = 0, w = 1024, h = 768 }   -- MUD 无图形：返回哨兵值
end

EngineAPI.render.present = function()
    logCall("render.present")
end

--- 取渲染尺寸：MUD 引擎无真实图形，返回哨兵值（ADR-PORT-007）
EngineAPI.render.getWidth = function()
    logCall("render.getWidth")
    return 1024
end

EngineAPI.render.getHeight = function()
    logCall("render.getHeight")
    return 768
end

EngineAPI.render.presentAndWait = function(delay)
    logCall("render.presentAndWait", delay)
end

--- 帧绘制回调标志：MUD 无屏幕，只需记录（便于测试断言入口确实调到了契约）
EngineAPI.render.setDrawLoopFlag = function(flag)
    logCall("render.setDrawLoopFlag", flag)
end

--- 帧绘制回调边界（MUD 无屏幕，只记录 —— 便于测试断言入口调到了契约）
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
-- （port-legacy-picture-removal）：零消费者，容器解析归 framework/sprite_atlas。

--- 从 RGBA 字节创建纹理：MUD 无纹理概念，返回哨兵 handle
EngineAPI.sprite.createFromRGBA = function(w, h, rgbaBytes, opts)
    logCall("sprite.createFromRGBA", w, h)
    -- 参数校验必须与 LOVE 实现一致（契约行为一致性，ADR-PORT-007）
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return nil end
    if type(rgbaBytes) ~= "string" or #rgbaBytes < w * h * 4 then return nil end
    opts = opts or {}
    return { w = w, h = h, xoff = opts.xoff or 0, yoff = opts.yoff or 0 }
end

--- 从编码字节创建纹理：MUD 无解码能力
EngineAPI.sprite.createFromEncoded = function(bytes, formatHint, opts)
    logCall("sprite.createFromEncoded", formatHint)
    if type(bytes) ~= "string" or bytes == "" then return nil end
    opts = opts or {}
    return { w = 0, h = 0, xoff = opts.xoff or 0, yoff = opts.yoff or 0 }
end

--- 绘制独立图片：MUD 无图形概念
EngineAPI.sprite.drawPictureFile = function(filename, x, y, opts)
    logCall("sprite.drawPictureFile", filename, x, y)
    return false
end

--- 绘制句柄：MUD 无图形，返回 false
EngineAPI.sprite.drawHandle = function(handle, x, y, flags, alpha)
    logCall("sprite.drawHandle")
    return false
end

EngineAPI.sprite.drawHandleTinted = function(handle, x, y, color, alpha)
    logCall("sprite.drawHandleTinted")
    return false
end

--- 取元数据：MUD 返回创建时记录的哨兵值
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

--- 地图瓦片：MUD 无地图数据，返回越界哨兵 -1
EngineAPI.map.getTile = function(x, y, layer)
    logCall("map.getTile", x, y, layer)
    return -1
end
EngineAPI.map.setTile = function(x, y, layer, value)
    logCall("map.setTile", x, y, layer, value)
end

EngineAPI.map.getSceneTile = function(sceneId, x, y, layer)
    logCall("map.getSceneTile", sceneId, x, y, layer)
    return 0
end

EngineAPI.map.setSceneTile = function(sceneId, x, y, layer, value)
    logCall("map.setSceneTile", sceneId, x, y, layer, value)
end

EngineAPI.map.getSceneEventData = function(sceneId, eventId, field)
    logCall("map.getSceneEventData", sceneId, eventId, field)
    return 0
end

EngineAPI.map.setSceneEventData = function(sceneId, eventId, field, value)
    logCall("map.setSceneEventData", sceneId, eventId, field, value)
end

EngineAPI.map.getBattleTile = function(x, y, layer)
    logCall("map.getBattleTile", x, y, layer)
    return 0
end

EngineAPI.map.setBattleTile = function(x, y, layer, value)
    logCall("map.setBattleTile", x, y, layer, value)
end

EngineAPI.map.clearBattleTile = function(layer, value)
    logCall("map.clearBattleTile", layer, value)
end

EngineAPI.map.getSceneSize = function()
    logCall("map.getSceneSize")
    return { w = 64, h = 64 }
end

EngineAPI.app = EngineAPI.app or {}

EngineAPI.app.toggleFullscreen = function()
    logCall("app.toggleFullscreen")
    return false          -- MUD 无图形
end

--- 退出（MUD 是命令行宿主：设标志，由 main 循环读取）
EngineAPI.app.quit = function()
    logCall("app.quit")
    EngineAPI.app._quitRequested = true
end

--- 装好运行时（MUD 也走同一条启动链 —— 这本身是个可执行文档：
--- 「换引擎要做什么」在 MUD 里看得最清楚，因为它没有任何图形特例）
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

--- 音乐模板注册（port-audio-semantics）：MUD 无音频，只记录便于回读
EngineAPI.app.setMusicTemplate = function(template, startOffset)
    logCall("app.setMusicTemplate", template, startOffset)
    EngineAPI.app._musicTemplate = (type(template) == "string" and template ~= "")
        and template or nil
    EngineAPI.app._musicStartOffset = tonumber(startOffset) or 0
end

EngineAPI.app.getMusicTemplate = function()
    return EngineAPI.app._musicTemplate, EngineAPI.app._musicStartOffset
end

EngineAPI.sprite.clearPictureCache = function()
    logCall("sprite.clearPictureCache")
end

EngineAPI.map.loadClouds = function(idxFile, grpFile)
    logCall("map.loadClouds", idxFile, grpFile)
end

EngineAPI.map.getBattleSize = function()
    logCall("map.getBattleSize")
    return { w = 64, h = 64 }
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

-- 鼠标（REQ-MS1-2）：MUD 引擎无鼠标，返回 -1,-1 而非 nil
-- （调用方无需做 nil 判断，且 -1 天然落在屏幕外，可被坐标范围检查过滤）
EngineAPI.input.mousePosition = function()
    logCall("input.mousePosition")
    return -1, -1
end

EngineAPI.input.mouseButton = function(button)
    logCall("input.mouseButton", button)
    return false
end

-- 物理轴 / 能力 / 指针 / 动作（input-action-layer Task 2）
--
-- MUD 引擎是纯文本，四者如实降级：
--   getAxis        恒 0（无摇杆）
--   getCapabilities 全 false（不假装有能力）
--   getPointerPosition 与 mousePosition 同语义
--   pollAction     走预设队列（文本引擎里"按键"由脚本注入）

EngineAPI.input.getAxis = function(name)
    logCall("input.getAxis", name)
    return 0
end

EngineAPI.input.getCapabilities = function()
    logCall("input.getCapabilities")
    return { pointer = false, touch = false, gamepad = false, vr = false }
end

EngineAPI.input.getPointerPosition = function()
    logCall("input.getPointerPosition")
    return -1, -1
end

EngineAPI.input.enableKeyRepeat = function(delay, interval)
    logCall("input.enableKeyRepeat", delay, interval)
end

EngineAPI.input.pollAction = function()
    logCall("input.pollAction")
    return nil
end

--- 触摸点：MUD 引擎无触摸
EngineAPI.input.getTouches = function()
    logCall("input.getTouches")
    return {}
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

--- 按游戏音乐编号播放（port-audio-semantics 的语义必须 4 引擎一致）
--
-- **只收 number**：收字符串说明调用方走错了契约（应改用 playMusic）。
-- MUD 无音频，但仍然要如实返回 false —— 「无能力」和「参数错」要能区分，
-- 否则调用方无法判断该不该重试。
EngineAPI.audio.playSequence = function(id, opts)
    logCall("audio.playSequence", id)
    if type(id) ~= "number" then return false end
    if id < 0 then return false end
    return false          -- MUD 无音频
end

--- 播放视频：MUD 无视频能力 → 如实返回 false（port-audio-semantics）
EngineAPI.audio.playVideo = function(filename, skipKey)
    logCall("audio.playVideo", filename)
    return false
end

-- 音量（REQ-VOL-1）：MUD 引擎无音频，4 个函数为 no-op 但保留状态，
-- 便于测试断言「框架确实调到了引擎」，也让 Settings 的读写有回读。
local mudMusicVolume = 64
local mudSFXVolume = 90

EngineAPI.audio.setMusicVolume = function(value)
    mudMusicVolume = tonumber(value) or mudMusicVolume
    logCall("audio.setMusicVolume", value)
end

EngineAPI.audio.getMusicVolume = function()
    return mudMusicVolume
end

EngineAPI.audio.setSFXVolume = function(value)
    mudSFXVolume = tonumber(value) or mudSFXVolume
    logCall("audio.setSFXVolume", value)
end

EngineAPI.audio.getSFXVolume = function()
    return mudSFXVolume
end

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

-- 本地墙上时间格式化（framework-io-portability）
--
-- 与 getTime 的区别：getTime 是**单调计时**（os.clock，进程/CPU 起算），
-- 不是纪元秒 → 算不出真实日期。日期格式化只能由引擎提供，见
-- engine_api.lua 的 time.formatNow。MUD 跑在宿主 Lua 上，直接用 os.date。
EngineAPI.time.formatNow = function(fmt)
    fmt = fmt or "%Y-%m-%d %H:%M"
    local ok, s = pcall(os.date, fmt)
    if ok and type(s) == "string" then return s end
    return ""
end

--------------------------------------------------------------------
-- file 模块 - 正常实现
--------------------------------------------------------------------
EngineAPI.file.open = function(filename, mode)
    logCall("file.open", filename, mode)
    return io.open(filename, mode)
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

-- 目录存在性 / 列举：MUD 引擎跑在终端，直接用宿主文件系统的跨平台原语
--- 读整个文件（MUD 是「纯 Lua 参考实现」，用 io 完全合适）
--
-- **为什么 MUD 必须实现全部 file 契约**：它是新引擎作者的**参考样板**。
-- 实测（2026-11-22 复审计）：MUD 此前缺 7 个契约（app.quit / file.read /
-- file.write / file.createDirectory / file.lines / file.openFile /
-- time.getTimeSeconds），全靠 engine_api.lua 的空桩继承 ——
-- 而空桩返回 nil，等于「调用成功但什么也没干」。
--
-- 更糟的是**测试也没抓到**：`test_engine_conformance` 用
-- `require` 后查 `mod[mod][fn] == nil`，但 MUD 与 engine_api 是
-- **同一张表**（都 `local EngineAPI = require("engine-love2d.engine_api")`），
-- 所以它永远查不出缺失 —— 这条断言是空转的（另有 task 修）。
EngineAPI.file.read = function(filename)
    logCall("file.read", filename)
    local f = io.open(filename, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

EngineAPI.file.write = function(filename, content, mode)
    logCall("file.write", filename, mode)
    local m = (mode == "a" or mode == "ab") and "ab" or "wb"
    local f = io.open(filename, m)
    if not f then return false end
    f:write(content or "")
    f:close()
    return true
end

EngineAPI.file.openFile = function(filename, mode)
    logCall("file.openFile", filename, mode)
    return io.open(filename, mode or "rb")
end

--- 逐行迭代（返回迭代器；取不到文件时返回 nil）
EngineAPI.file.lines = function(filename)
    logCall("file.lines", filename)
    local f = io.open(filename, "r")
    if not f then return nil end
    return function()
        local line = f:read("*l")
        if line == nil then f:close() end
        return line
    end
end

--- 建目录（MUD 无跨平台 API；两种 shell 语法都试）
EngineAPI.file.createDirectory = function(dirpath)
    logCall("file.createDirectory", dirpath)
    if type(dirpath) ~= "string" or dirpath == "" then return false end
    local safe = dirpath:gsub('"', "")
    local r1 = os.execute('mkdir "' .. safe .. '" 2>NUL')
    if r1 == 0 or r1 == true then return true end
    local r2 = os.execute('mkdir -p "' .. safe .. '" 2>/dev/null')
    return (r2 == 0 or r2 == true)
end

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
--- MUD 无字体度量能力，返回 nil 让 TextBoxLayout 退回 em 估算
EngineAPI.font.measureText = function(str, size, fontName)
    logCall("font.measureText")
    return nil
end

EngineAPI.font.get = function(fontName, size)
    logCall("font.get", fontName, size)
    return { name = fontName, size = size }
end

--------------------------------------------------------------------
-- dialog 模块 - 空实现（MUD 无图形对话框，只需记录调用）
--------------------------------------------------------------------
-- MUD 引擎是纯文本输出，对话框的「框宽 / 框高 / 行高 / 锚点」全都无意义。
-- 排版算法在 framework/dialog_layout.lua（引擎无关纯函数），
-- 需要对话框语义的引擎才调它；mud 只需把调用记录下来便于调试。
EngineAPI.dialog = {}

EngineAPI.dialog.measure = function(spec)
    logCall("dialog.measure", spec and spec.text, spec and spec.flag)
    return nil
end

EngineAPI.dialog.draw = function(spec, layout)
    logCall("dialog.draw", spec and spec.text, layout and layout.width)
end

EngineAPI.dialog.clear = function()
    logCall("dialog.clear")
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
    return coroutine.running() ~= nil
end
--------------------------------------------------------------------
-- 向后兼容
--------------------------------------------------------------------
EngineAPI.SetDrawLoopFlag = function(flag) end
EngineAPI.PicInit = function() end
EngineAPI.ShowSurface = function() end
EngineAPI.ShowSlow = function() end
EngineAPI.LoadPicture = function() end

-- 只暴露 EngineAPI。
--
-- **`_G.lib` 已删除**（port-compat-layer-removal）：实测本文件自身零 `lib.`
-- 引用，且 framework/script/入口 已零 `lib.*` → 这条兼容层无消费者。
_G.EngineAPI = EngineAPI

-- system 模块（REQ-MS1-1）：MUD 引擎无平台概念
EngineAPI.system = EngineAPI.system or {}
--- 单调计时（秒）。MUD 用 os.clock —— 与 LÖVE 的 love.timer.getTime 同语义
--- （从进程启动算起，**不是** Unix 纪元秒；拿它算日期只会得到 1970-01-01）
EngineAPI.time.getTimeSeconds = function()
    return os.clock()
end

EngineAPI.system.getOS = function()
    return "unknown"
end

EngineAPI.init = function() end

return EngineAPI