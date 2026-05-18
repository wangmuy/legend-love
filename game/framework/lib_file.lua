-- lib_file.lua - File operation wrapper for LÖVE compatibility
-- Provides io/os compatible functions that work in both .love and development mode

local FileUtil = {}

local function hasLoveFS()
    return EngineAPI and EngineAPI.file
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

local function toLoveOpenMode(mode)
    if mode and mode:find("+", 1, true) then
        return "c"
    end
    if mode and mode:find("w", 1, true) then
        return "w"
    end
    if mode and mode:find("a", 1, true) then
        return "a"
    end
    return "r"
end

-- File open wrapper - handles both EngineAPI.file and io.open
-- Returns a file handle compatible object
function FileUtil.open(filepath, mode)
    mode = mode or "r"

    if hasLoveFS() then
        local writable = isWriteMode(mode)
        local hasExisting = EngineAPI.file.exists(filepath)

        if not hasExisting and not writable then
            return nil
        end

        if writable then
            local parent = filepath:match("^(.*)/[^/]+$")
            if parent and parent ~= "" then
                EngineAPI.file.createDirectory(parent)
            end
        end

        local rawHandle = EngineAPI.file.openFile(filepath, toLoveOpenMode(mode))
        if rawHandle then
            return FileUtil.wrapHandle(rawHandle, true)
        end
    end

    local native = io.open(filepath, mode)
    if native then
        return FileUtil.wrapHandle(native, false)
    end
    return nil
end

-- Lines iterator wrapper - compatible with io.lines
function FileUtil.lines(filepath)
    if not hasLoveFS() then
        return function() return nil end
    end
    return EngineAPI.file.lines(filepath)
end

-- Remove file wrapper - handles both os.remove and love.filesystem.remove
function FileUtil.remove(filepath)
    if not hasLoveFS() then
        return false, "EngineAPI.file unavailable"
    end
    return EngineAPI.file.remove(filepath)
end

-- Read entire file - wrapper that works in both modes
function FileUtil.read(filepath)
    if not hasLoveFS() then
        return nil, "EngineAPI.file unavailable"
    end
    return EngineAPI.file.read(filepath)
end

-- Write entire file - wrapper that works in both modes
function FileUtil.write(filepath, content, mode)
    if not hasLoveFS() then
        return nil, "EngineAPI.file unavailable"
    end
    return EngineAPI.file.write(filepath, content, mode)
end

-- File exists check - wrapper
function FileUtil.exists(filepath)
    if not hasLoveFS() then
        return false
    end
    return EngineAPI.file.exists(filepath)
end

-- Create directory - wrapper
function FileUtil.createdir(dirpath)
    if not hasLoveFS() then
        return false
    end
    return EngineAPI.file.createDirectory(dirpath)
end

-- Get file size - wrapper
function FileUtil.getsize(filepath)
    if not hasLoveFS() then
        return nil
    end
    return EngineAPI.file.getSize(filepath)
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
    if self._isLove and self._handle and self._handle.loveStream then
        local f = self._handle.file
        format = normalizeReadFormat(format)
        if type(format) == "number" then
            return f:read(format)
        elseif format == "*all" or format == "a" then
            local cur = f:tell()
            local size = f:getSize()
            local remain = size - cur
            if remain <= 0 then
                return ""
            end
            return f:read(remain)
        elseif format == "*line" or format == "l" then
            local chars = {}
            while true do
                local ch = f:read(1)
                if ch == nil or ch == "" then
                    if #chars == 0 then
                        return nil
                    end
                    return table.concat(chars)
                end
                if ch == "\n" then
                    return table.concat(chars)
                end
                chars[#chars + 1] = ch
            end
        elseif format == "*number" or format == "n" then
            local line = self:read("*line")
            return tonumber(line)
        else
            return self:read("*line")
        end
    end

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
    if self._isLove and self._handle and self._handle.loveStream then
        local parts = { ... }
        local chunk = ""
        for i = 1, #parts do
            chunk = chunk .. tostring(parts[i])
        end
        return self._handle.file:write(chunk)
    end

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
    if self._isLove and self._handle and self._handle.loveStream then
        return self._handle.file:close()
    end

    if self._isLove and type(self._handle.content) == "string" then
        local h = self._handle
        if h.closed then
            return true
        end
        if h.dirty and hasLoveFS() then
            EngineAPI.file.write(h.path, h.content)
        end
        h.closed = true
        return true
    else
        return self._handle:close()
    end
end

function FileUtil.FileHandle:flush()
    if self._isLove and self._handle and self._handle.loveStream then
        local f = self._handle.file
        if f.flush then
            return f:flush()
        end
        return true
    end

    if self._isLove and type(self._handle.content) == "string" then
        local h = self._handle
        if h.closed then
            return nil
        end
        if h.dirty and hasLoveFS() then
            EngineAPI.file.write(h.path, h.content)
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

    if self._isLove and self._handle and self._handle.loveStream then
        local f = self._handle.file
        local base
        if whence == "set" then
            base = 0
        elseif whence == "cur" then
            base = f:tell()
        elseif whence == "end" then
            base = f:getSize()
        else
            return nil
        end
        local newPos = base + offset
        if newPos < 0 then
            newPos = 0
        end
        f:seek(newPos)
        return newPos
    end

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
    if self._isLove and self._handle and self._handle.loveStream then
        local function iterator()
            return self:read("*line")
        end
        return iterator
    end

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
