-- engine_web.lua
-- Web/terminal EngineAPI implementation for Fengari Lua VM in browser
-- All engine operations mapped to ANSI output + JSBridge communication

local EngineAPI = {}

--------------------------------------------------------------------------------
-- render - ANSI text rendering
--------------------------------------------------------------------------------
EngineAPI.render = {}
local renderBuffer = {}

local function colorToAnsi(color)
    if not color then return "\027[37m" end
    local r, g, b
    if type(color) == "number" then
        r = math.floor(color / 65536)
        g = math.floor((color % 65536) / 256)
        b = color % 256
    else
        r = math.floor(color[1] * 255)
        g = math.floor(color[2] * 255)
        b = math.floor(color[3] * 255)
    end
    if r > 200 and g > 200 and b > 200 then return "\027[37m"
    elseif r > 200 and g < 100 and b < 100 then return "\027[31m"
    elseif r > 200 and g > 100 and b < 50 then return "\027[33m"
    elseif r < 50 and g < 50 and b < 50 then return "\027[30m"
    elseif r > 100 and g > 100 and b < 100 then return "\027[93m"
    else return "\027[37m" end
end

function EngineAPI.render.text(x, y, str, color, size)
    table.insert(renderBuffer, colorToAnsi(color) .. tostring(str) .. "\027[0m")
end

function EngineAPI.render.fillRect(x1, y1, x2, y2, color) end

function EngineAPI.render.rectOutline(x1, y1, x2, y2, color) end

function EngineAPI.render.drawBackground(x1, y1, x2, y2, brightness)
    if not brightness or brightness == 0 then
        table.insert(renderBuffer, "\027[2J\027[40m")
    else
        table.insert(renderBuffer, "\027[2J\027[40m")
    end
end

function EngineAPI.render.setClip(x1, y1, x2, y2) end

function EngineAPI.render.present()
    local output = table.concat(renderBuffer, "\n") .. "\027[0m"
    renderBuffer = {}
    if _G.JSBridge and _G.JSBridge.write then
        _G.JSBridge.write(output)
    end
end

function EngineAPI.render.presentAndWait(delay)
    EngineAPI.render.present()
    pcall(coroutine.yield)
end

--------------------------------------------------------------------------------
-- sprite - no-op
--------------------------------------------------------------------------------
EngineAPI.sprite = {}

function EngineAPI.sprite.initSprites() end

function EngineAPI.sprite.loadArchive(idxFile, grpFile, archiveId)
    return true
end

function EngineAPI.sprite.getSize(archiveId, spriteId)
    return 0, 0, 0, 0
end

function EngineAPI.sprite.draw(archiveId, spriteId, x, y, flags, alpha) end

--------------------------------------------------------------------------------
-- map - no-op
--------------------------------------------------------------------------------
EngineAPI.map = {}

function EngineAPI.map.loadMain(earthFile, surfaceFile, buildingFile, buildXFile, buildYFile, width, height, x, y) end

function EngineAPI.map.loadScene(sFile, tmpFile, num, width, height, dFile, dNum1, dNum2) end

function EngineAPI.map.saveScene(sFile, dFile) end

function EngineAPI.map.loadBattle(idxFile, grpFile, mapId, num, width, height) end

function EngineAPI.map.drawMain(playerX, playerY, playerPic) end

function EngineAPI.map.drawScene(sceneId, x, y, offX, offY, playerPic) end

function EngineAPI.map.drawBattle(flag, x, y, v1, v2, v3) end

--------------------------------------------------------------------------------
-- input - JSBridge event stream
--------------------------------------------------------------------------------
EngineAPI.input = {}

function EngineAPI.input.getKey()
    if _G.JSBridge and _G.JSBridge.getEventCount and _G.JSBridge.getEventCount() > 0 then
        local evt = _G.JSBridge.getEvent()
        if evt then
            if type(evt) == "number" then return evt end
            if type(evt) == "string" then return tonumber(evt) or evt:byte() end
            return -1
        end
    end
    return -1
end

function EngineAPI.input.waitForKey()
    while true do
        if _G.JSBridge and _G.JSBridge.getEventCount and _G.JSBridge.getEventCount() > 0 then
            local evt = _G.JSBridge.getEvent()
            if evt then
                if type(evt) == "number" then return evt end
                if type(evt) == "string" then return tonumber(evt) or evt:byte() end
                return -1
            end
        end
        pcall(coroutine.yield)
    end
end

function EngineAPI.input.setKeyRepeat(delay, interval) end

--------------------------------------------------------------------------------
-- audio - no-op
--------------------------------------------------------------------------------
EngineAPI.audio = {}

function EngineAPI.audio.playMusic(filename) end

function EngineAPI.audio.playSFX(filename) end

function EngineAPI.audio.stopMusic() end

--------------------------------------------------------------------------------
-- time - coroutine-based timing
--------------------------------------------------------------------------------
EngineAPI.time = {}

function EngineAPI.time.sleep(millis)
    pcall(coroutine.yield)
end

function EngineAPI.time.getTime()
    return os.clock() * 1000
end

function EngineAPI.time.getTimeSeconds()
    return os.clock()
end

--------------------------------------------------------------------------------
-- file - dataCache based read-only file system
--------------------------------------------------------------------------------
EngineAPI.file = {}

function EngineAPI.file.open(filename, mode)
    if mode and mode:sub(1, 1) == "r" then
        local content = _G.dataCache and _G.dataCache[filename]
        if content then
            local handle = {
                _content = content,
                _pos = 1,
                read = function(self, fmt)
                    if fmt == "*a" or fmt == "*all" then
                        return self._content
                    end
                    if fmt == "*l" or fmt == "*line" then
                        if self._pos > #self._content then return nil end
                        local _, e = self._content:find("\n", self._pos)
                        if e then
                            local line = self._content:sub(self._pos, e - 1)
                            self._pos = e + 1
                            return line
                        else
                            local line = self._content:sub(self._pos)
                            self._pos = #self._content + 1
                            return line
                        end
                    end
                    if type(fmt) == "number" then
                        local chunk = self._content:sub(self._pos, self._pos + fmt - 1)
                        self._pos = self._pos + fmt
                        return chunk
                    end
                    return self._content
                end,
                close = function() end,
                seek = function(_, whence, offset)
                    if whence == "set" then
                        self._pos = (offset or 0) + 1
                    elseif whence == "end" then
                        self._pos = #self._content - (offset or 0)
                    else
                        self._pos = self._pos + (offset or 0)
                    end
                    return self._pos - 1
                end
            }
            return handle
        end
        return nil
    end
    return nil
end

function EngineAPI.file.openFile(filename, mode)
    return EngineAPI.file.open(filename, mode)
end

function EngineAPI.file.remove(filename) end

function EngineAPI.file.getSize(filename)
    local content = _G.dataCache and _G.dataCache[filename]
    if content then
        return #content
    end
    return -1
end

function EngineAPI.file.exists(filename)
    return _G.dataCache and _G.dataCache[filename] ~= nil
end

function EngineAPI.file.read(filename)
    if _G.dataCache then
        return _G.dataCache[filename]
    end
    return nil
end

function EngineAPI.file.write(filename, content, mode) end

function EngineAPI.file.lines(filename)
    local content = _G.dataCache and _G.dataCache[filename]
    if not content then
        return function() return nil end
    end
    local lines = {}
    for line in content:gmatch("([^\n]*)\n?") do
        table.insert(lines, line)
    end
    local i = 0
    return function()
        i = i + 1
        return lines[i]
    end
end

function EngineAPI.file.createDirectory(dirpath) end

--------------------------------------------------------------------------------
-- script - load Lua code from dataCache
--------------------------------------------------------------------------------
EngineAPI.script = {}

function EngineAPI.script.load(path)
    local source = _G.dataCache and _G.dataCache[path]
    if not source then
        return nil, "Script not found: " .. tostring(path)
    end
    local chunk, err = load(source, path)
    if not chunk then
        return nil, err
    end
    return chunk
end

--------------------------------------------------------------------------------
-- font - stub
--------------------------------------------------------------------------------
EngineAPI.font = {}

function EngineAPI.font.get(fontName, size)
    return { name = fontName or "monospace", size = size or 14 }
end

--------------------------------------------------------------------------------
-- color - pack/unpack tools
--------------------------------------------------------------------------------
EngineAPI.color = {}

function EngineAPI.color.pack(r, g, b)
    return r * 65536 + g * 256 + b
end

function EngineAPI.color.unpack(color)
    local r = math.floor(color / 65536)
    local g = math.floor((color % 65536) / 256)
    local b = color % 256
    return r / 255, g / 255, b / 255
end

--------------------------------------------------------------------------------
-- debug - log via JSBridge
--------------------------------------------------------------------------------
EngineAPI.debug = {}

function EngineAPI.debug.log(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[i] = tostring(v)
    end
    local msg = table.concat(parts, "\t")
    if _G.JSBridge and _G.JSBridge.write then
        _G.JSBridge.write("[DEBUG] " .. msg .. "\n")
    end
end

--------------------------------------------------------------------------------
-- coroutine - coroutine utilities
--------------------------------------------------------------------------------
EngineAPI.coroutine = {}

function EngineAPI.coroutine.isRunning()
    return coroutine.running() ~= nil
end

function EngineAPI.coroutine.yieldPoint()
    pcall(coroutine.yield)
end

function EngineAPI.coroutine.waitFor(condition, timeout)
    local start = EngineAPI.time.getTime()
    while not condition() do
        if timeout then
            local elapsed = EngineAPI.time.getTime() - start
            if elapsed >= timeout then
                return false
            end
        end
        pcall(coroutine.yield)
    end
    return true
end

--------------------------------------------------------------------------------
-- app - application control
--------------------------------------------------------------------------------
EngineAPI.app = {}

function EngineAPI.app.quit() end

--------------------------------------------------------------------------------
-- Global setup
--------------------------------------------------------------------------------
_G.EngineAPI = EngineAPI

_G.lib = setmetatable({}, {
    __index = function(_, key)
        if key == "Debug" then return EngineAPI.debug.log end
        if key == "GetTime" then return EngineAPI.time.getTime end
        if key == "Delay" then return EngineAPI.time.sleep end
        for _, mod in pairs(EngineAPI) do
            if type(mod) == "table" and mod[key] then
                return mod[key]
            end
        end
        return nil
    end
})

return EngineAPI
