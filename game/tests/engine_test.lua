-- engine_test.lua
-- 命令行测试引擎 - 实现 EngineAPI 接口
-- 所有渲染/音频为空操作，输入返回预设值
-- 用于 CI/CD 和单元测试，无需显示器

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

EngineAPI.render.present = function()
    logCall("render.present")
end

EngineAPI.render.presentAndWait = function(delay)
    logCall("render.presentAndWait", delay)
end

--------------------------------------------------------------------
-- sprite 模块 - loadArchive 解析尺寸但不创建纹理，draw 为空操作
--------------------------------------------------------------------
local spriteSizes = {}

EngineAPI.sprite.initSprites = function()
    logCall("sprite.initSprites")
end

EngineAPI.sprite.loadArchive = function(idxFile, grpFile, archiveId)
    logCall("sprite.loadArchive", idxFile, grpFile, archiveId)
    -- 解析 idx 文件获取尺寸信息
    local f = io.open(idxFile, "rb")
    if f then
        local idxLen = f:seek("end")
        f:close()
        local num = math.floor(idxLen / 4)
        spriteSizes[archiveId] = { num = num, width = 64, height = 64 }
    end
end

EngineAPI.sprite.getSize = function(archiveId, spriteId)
    logCall("sprite.getSize", archiveId, spriteId)
    local info = spriteSizes[archiveId]
    if info then
        return info.width, info.height, 0, 0
    end
    return 64, 64, 0, 0
end

EngineAPI.sprite.draw = function(archiveId, spriteId, x, y, flags, alpha)
    logCall("sprite.draw", archiveId, spriteId, x, y, flags, alpha)
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
    return coroutine.running() ~= nil
end

EngineAPI.coroutine.yieldPoint = function()
    if coroutine.running() then
        coroutine.yield()
    end
end

EngineAPI.coroutine.waitFor = function(condition, timeout)
    local start = EngineAPI.time.getTime()
    while not condition() do
        if timeout and EngineAPI.time.getTime() - start > timeout then
            return false
        end
        if coroutine.running() then
            coroutine.yield()
        end
    end
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

return EngineAPI