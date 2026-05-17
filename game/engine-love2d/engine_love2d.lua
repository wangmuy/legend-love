-- engine_love2d.lua
-- Love2D 引擎实现 - 实现 EngineAPI 接口
-- 内部委托给 lib_love.lua 的现有实现

local EngineAPI = require("engine-love2d.engine_api")
local lib = require("engine-love2d.lib_love")

-- 将 lib_love 中的函数映射到 EngineAPI 各模块
-- render 模块
EngineAPI.render.text = function(x, y, str, color, size)
    lib.DrawStr(x, y, str, color, size)
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

EngineAPI.render.present = function()
    lib.ShowSurface()
end

EngineAPI.render.presentAndWait = function(delay)
    lib.ShowSlow(delay)
end

-- sprite 模块
EngineAPI.sprite.initSprites = function()
    -- 原 lib_love 中 PicInit 加载调色板
    -- 新引擎不需要调色板概念，保留空实现
end

EngineAPI.sprite.loadArchive = function(idxFile, grpFile, archiveId)
    lib.PicLoadFile(idxFile, grpFile, archiveId)
end

EngineAPI.sprite.getSize = function(archiveId, spriteId)
    return lib.PicGetXY(archiveId, spriteId)
end

EngineAPI.sprite.draw = function(archiveId, spriteId, x, y, flags, alpha)
    lib.PicLoadCache(archiveId, spriteId, x, y, flags, alpha)
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

EngineAPI.map.drawMain = function(playerX, playerY, playerPic)
    lib.DrawMMap(playerX, playerY, playerPic)
end

EngineAPI.map.drawScene = function(sceneId, x, y, offX, offY, playerPic)
    lib.DrawSMap(sceneId, x, y, offX, offY, playerPic)
end

EngineAPI.map.drawBattle = function(flag, x, y, v1, v2, v3)
    lib.DrawWarMap(flag, x, y, v1, v2, v3)
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

-- time 模块
EngineAPI.time.sleep = function(millis)
    lib.Delay(millis)
end

EngineAPI.time.getTime = function()
    return lib.GetTime()
end

-- file 模块
EngineAPI.file.open = function(filename, mode)
    local FileUtil = require("framework.lib_file")
    return FileUtil.open(filename, mode)
end

EngineAPI.file.remove = function(filename)
    local FileUtil = require("framework.lib_file")
    return FileUtil.remove(filename)
end

EngineAPI.file.getSize = function(filename)
    local FileUtil = require("framework.lib_file")
    return FileUtil.getsize(filename)
end

EngineAPI.file.exists = function(filename)
    local info = love.filesystem.getInfo(filename)
    return info ~= nil
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

-- 设置全局 lib 变量指向 EngineAPI，保持向后兼容
-- 使用 __index 元表：EngineAPI 上找不到的函数，回退到 lib_love 原始实现
_G.EngineAPI = EngineAPI
_G.lib = setmetatable(EngineAPI, { __index = lib })

-- 向后兼容：添加 lib_love 中已有的函数，供现有代码直接调用
EngineAPI.SetDrawLoopFlag = function(flag)
    if lib.SetDrawLoopFlag then
        lib.SetDrawLoopFlag(flag)
    end
end

EngineAPI.PicInit = function(paletteFile)
    lib.PicInit(paletteFile)
end

EngineAPI.ShowSurface = function(flag)
    lib.ShowSurface(flag)
end

EngineAPI.ShowSlow = function(delay, flag)
    lib.ShowSlow(delay, flag)
end

EngineAPI.LoadPicture = function(filename, x, y)
    lib.LoadPicture(filename, x, y)
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

return EngineAPI