-- lib_file.lua - File operation wrapper for LÖVE compatibility
-- Provides io/os compatible functions that work in both .love and development mode

local FileUtil = {}

local function hasLoveFS()
    return love and love.filesystem
end

local function isWriteMode(mode)
    return mode and (mode:find("w", 1, true) or mode:find("a", 1, true) or mode:find("+", 1, true))
end

local function normalizeReadFormat(format)
    if format == nil then
        return "*line"
    end
    return format
end

-- File open wrapper - handles both io.open and love.filesystem
-- Returns a file handle compatible object
function FileUtil.open(filepath, mode)
    mode = mode or "r"

    if not hasLoveFS() then
        return nil
    end

    local info = love.filesystem.getInfo(filepath)
    local hasExisting = info ~= nil
    local writable = isWriteMode(mode)

    if not hasExisting and not writable then
        return nil
    end

    local content = ""
    if hasExisting and mode:find("w", 1, true) == nil then
        local okRead, existing = pcall(function()
            return love.filesystem.read(filepath)
        end)
        if okRead and type(existing) == "string" then
            content = existing
        elseif not writable then
            return nil
        end
    end

    -- r+ requires existing file
    if mode:find("+", 1, true) and mode:find("r", 1, true) and not hasExisting then
        return nil
    end

    if mode:find("w", 1, true) then
        content = ""
    end

    local pos = 1
    if mode:find("a", 1, true) then
        pos = #content + 1
    end

    if writable then
        local parent = filepath:match("^(.*)/[^/]+$")
        if parent and parent ~= "" then
            love.filesystem.createDirectory(parent)
        end
    end

    return FileUtil.wrapHandle({
        path = filepath,
        mode = mode,
        content = content,
        pos = pos,
        closed = false,
        dirty = false,
    }, true)
end

-- Lines iterator wrapper - compatible with io.lines
function FileUtil.lines(filepath)
    if not hasLoveFS() then
        return function() return nil end
    end
    -- Try love.filesystem.lines first
    if love.filesystem.getInfo(filepath) then
        return love.filesystem.lines(filepath)
    end

    return function() return nil end
end

-- Remove file wrapper - handles both os.remove and love.filesystem.remove
function FileUtil.remove(filepath)
    if not hasLoveFS() then
        return false, "love.filesystem unavailable"
    end
    -- Try love.filesystem.remove first
    local success = pcall(function()
        return love.filesystem.remove(filepath)
    end)
    
    if success then
        return true
    end
    
    return false, "remove failed"
end

-- Read entire file - wrapper that works in both modes
function FileUtil.read(filepath)
    if not hasLoveFS() then
        return nil, "love.filesystem unavailable"
    end
    -- Try love.filesystem.read first
    local success, content = pcall(function()
        return love.filesystem.read(filepath)
    end)
    
    if success and content then
        return content
    end
    
    return nil, "Could not read file: " .. filepath
end

-- Write entire file - wrapper that works in both modes
function FileUtil.write(filepath, content, mode)
    mode = mode or "w"
    if not hasLoveFS() then
        return nil, "love.filesystem unavailable"
    end
    
    -- Try love.filesystem.write first
    local success, err = pcall(function()
        return love.filesystem.write(filepath, content)
    end)
    
    if success then
        return true
    end
    
    return nil, err or "Could not write file: " .. filepath
end

-- File exists check - wrapper
function FileUtil.exists(filepath)
    if not hasLoveFS() then
        return false
    end
    -- Try love.filesystem.getInfo first
    local info = love.filesystem.getInfo(filepath)
    if info then
        return true
    end

    return false
end

-- Create directory - wrapper (works in love.writePath only for love mode)
function FileUtil.createdir(dirpath)
    if not hasLoveFS() then
        return false
    end
    -- In love mode, we can only create in save directory or write directory
    local success = pcall(function()
        return love.filesystem.createDirectory(dirpath)
    end)
    
    if success then
        return true
    end
    
    return false
end

-- Get file size - wrapper
function FileUtil.getsize(filepath)
    if not hasLoveFS() then
        return nil
    end
    -- Try love.filesystem.getInfo first
    local info = love.filesystem.getInfo(filepath)
    if info then
        return info.size
    end

    return nil
end

-- Wrapper object for file handle - provides common methods
FileUtil.FileHandle = {}
FileUtil.FileHandle.__index = FileUtil.FileHandle

function FileUtil.wrapHandle(handle, isLoveHandle)
    local self = setmetatable({}, FileUtil.FileHandle)
    self._handle = handle
    self._isLove = isLoveHandle
    return self
end

function FileUtil.FileHandle:read(format)
    if self._isLove and type(self._handle.content) == "string" then
        local h = self._handle
        if h.closed then
            return nil
        end
        format = normalizeReadFormat(format)
        if type(format) == "number" then
            if h.pos > #h.content then
                return nil
            end
            local s = h.content:sub(h.pos, h.pos + format - 1)
            h.pos = h.pos + #s
            if s == "" then
                return nil
            end
            return s
        elseif format == "*line" or format == "l" then
            if h.pos > #h.content then
                return nil
            end
            local startPos = h.pos
            local nl = h.content:find("\n", startPos, true)
            if nl then
                local line = h.content:sub(startPos, nl - 1)
                h.pos = nl + 1
                return line
            end
            local line = h.content:sub(startPos)
            h.pos = #h.content + 1
            return line
        elseif format == "*all" or format == "a" then
            if h.pos > #h.content then
                return ""
            end
            local s = h.content:sub(h.pos)
            h.pos = #h.content + 1
            return s
        elseif format == "*number" or format == "n" then
            local line = self:read("*line")
            return tonumber(line)
        else
            return self:read("*line")
        end
    else
        return self._handle:read(format)
    end
end

function FileUtil.FileHandle:write(...)
    if self._isLove and type(self._handle.content) == "string" then
        local h = self._handle
        if h.closed then
            return nil
        end
        local parts = { ... }
        local chunk = ""
        for i = 1, #parts do
            chunk = chunk .. tostring(parts[i])
        end
        local before = ""
        if h.pos > 1 then
            before = h.content:sub(1, h.pos - 1)
        end
        local afterStart = h.pos + #chunk
        local after = ""
        if afterStart <= #h.content then
            after = h.content:sub(afterStart)
        end
        h.content = before .. chunk .. after
        h.pos = h.pos + #chunk
        h.dirty = true
        return true
    else
        return self._handle:write(...)
    end
end

function FileUtil.FileHandle:close()
    if self._isLove and type(self._handle.content) == "string" then
        local h = self._handle
        if h.closed then
            return true
        end
        if h.dirty and hasLoveFS() then
            love.filesystem.write(h.path, h.content)
        end
        h.closed = true
        return true
    else
        return self._handle:close()
    end
end

function FileUtil.FileHandle:flush()
    if self._isLove and type(self._handle.content) == "string" then
        local h = self._handle
        if h.closed then
            return nil
        end
        if h.dirty and hasLoveFS() then
            love.filesystem.write(h.path, h.content)
            h.dirty = false
        end
        return true
    end
    if self._handle.flush then
        return self._handle:flush()
    end
    return true
end

function FileUtil.FileHandle:seek(whence, offset)
    whence = whence or "cur"
    offset = offset or 0
    if self._isLove and type(self._handle.content) == "string" then
        local h = self._handle
        if h.closed then
            return nil
        end
        local base
        if whence == "set" then
            base = 0
        elseif whence == "cur" then
            base = h.pos - 1
        elseif whence == "end" then
            base = #h.content
        else
            return nil
        end
        local newPos0 = base + offset
        if newPos0 < 0 then
            newPos0 = 0
        end
        h.pos = newPos0 + 1
        return newPos0
    else
        return self._handle:seek(whence, offset)
    end
end

function FileUtil.FileHandle:lines()
    if self._isLove and type(self._handle.content) == "string" then
        local function iterator()
            return self:read("*line")
        end
        return iterator
    else
        return self._handle:lines()
    end
end

return FileUtil
