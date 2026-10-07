-- data_loader.lua
-- JSON parser + data loader + cache for Web MUD
-- Runs inside Fengari Lua VM (Lua 5.3)

_G.initDataSource = {}
_G.rawDataCache = {}
_G.rawDataCache = {}

function parseJSON(str)
    local pos = 1

    local skipWS, parseString, parseNumber, parseValue, parseObject, parseArray

    skipWS = function()
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
                pos = pos + 1
            else break end
        end
    end

    parseString = function()
        pos = pos + 1
        local result = {}
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(result)
            elseif c == '\\' then
                pos = pos + 1
                local esc = str:sub(pos, pos)
                if esc == '"' then result[#result+1] = '"'
                elseif esc == '\\' then result[#result+1] = '\\'
                elseif esc == '/' then result[#result+1] = '/'
                elseif esc == 'b' then result[#result+1] = '\b'
                elseif esc == 'f' then result[#result+1] = '\f'
                elseif esc == 'n' then result[#result+1] = '\n'
                elseif esc == 'r' then result[#result+1] = '\r'
                elseif esc == 't' then result[#result+1] = '\t'
                elseif esc == 'u' then
                    local hex = str:sub(pos+1, pos+4)
                    local code = tonumber(hex, 16)
                    result[#result+1] = string.char(code)
                    pos = pos + 4
                end
                pos = pos + 1
            else
                result[#result+1] = c
                pos = pos + 1
            end
        end
        error("Unterminated string")
    end

    parseNumber = function()
        local start = pos
        if str:sub(pos, pos) == '-' then pos = pos + 1 end
        while pos <= #str do
            local c = str:sub(pos, pos)
            if (c >= '0' and c <= '9') or c == '.' then
                pos = pos + 1
            else break end
        end
        local numStr = str:sub(start, pos - 1)
        if numStr:find("%.") then
            return tonumber(numStr)
        else
            return tonumber(numStr)
        end
    end

    parseValue = function()
        skipWS()
        if pos > #str then error("Unexpected end") end
        local c = str:sub(pos, pos)
        if c == '"' then return parseString()
        elseif c == '{' then return parseObject()
        elseif c == '[' then return parseArray()
        elseif c == 't' then pos = pos + 4; return true
        elseif c == 'f' then pos = pos + 5; return false
        elseif c == 'n' then pos = pos + 4; return nil
        else return parseNumber() end
    end

    parseObject = function()
        local obj = {}
        pos = pos + 1
        skipWS()
        if str:sub(pos, pos) == '}' then pos = pos + 1; return obj end
        while true do
            skipWS()
            local key = parseString()
            skipWS()
            if str:sub(pos, pos) ~= ':' then error("Expected ':'") end
            pos = pos + 1
            local value = parseValue()
            obj[key] = value
            skipWS()
            local c = str:sub(pos, pos)
            if c == ',' then pos = pos + 1
            elseif c == '}' then pos = pos + 1; return obj
            else error("Expected ',' or '}'") end
        end
    end

    parseArray = function()
        local arr = {}
        pos = pos + 1
        skipWS()
        if str:sub(pos, pos) == ']' then pos = pos + 1; return arr end
        while true do
            arr[#arr + 1] = parseValue()
            skipWS()
            local c = str:sub(pos, pos)
            if c == ',' then pos = pos + 1
            elseif c == ']' then pos = pos + 1; return arr
            else error("Expected ',' or ']'") end
        end
    end

    skipWS()
    local result = parseValue()
    skipWS()
    return result
end

local totalDataSize = 0

function loadJSON(cacheKey, jsonString)
    local ok, result = pcall(parseJSON, jsonString)
    if not ok then
        return false, result
    end
    _G.initDataSource[cacheKey] = result
    _G.rawDataCache[cacheKey] = jsonString
    totalDataSize = totalDataSize + #jsonString
    return true
end

function finalizeDataLoad()
    _G.initDataSource._loaded = true
    _G.initDataSource._fileCount = 11
    _G.initDataSource._totalSize = totalDataSize
    initDataCompat()
end

function getData(cacheKey)
    return _G.initDataSource[cacheKey]
end

setmetatable(_G.initDataSource, {
    __index = function(_, key)
        if type(key) == "string" then
            local baseKey = key:match("/(.-)%.json$")
            if baseKey then
                return _G.initDataSource[baseKey]
            end
        end
        return nil
    end
})

function getDataStatus()
    return {
        loaded = _G.initDataSource._loaded or false,
        files = _G.initDataSource._fileCount or 0,
        size = _G.initDataSource._totalSize or 0,
    }
end

function initDataCompat()
    _G.initDataSourcePaths = {
        ["data-web/dialogues.json"] = "dialogues",
        ["data-web/scenes.json"] = "scenes",
        ["data-web/chars.json"] = "chars",
        ["data-web/items.json"] = "items",
        ["data-web/skills.json"] = "skills",
        ["data-web/entrances.json"] = "entrances",
        ["data-web/wmap.json"] = "wmap",
        ["data-web/events.json"] = "events",
        ["data-web/config.json"] = "config",
        ["data-web/shops.json"] = "shops",
        ["data-web/wars.json"] = "wars",
    }
end

-- JS-exposed globals
_G.loadJSONChunk = loadJSON
_G.finalizeDataLoad = finalizeDataLoad
_G.getDataStatus = getDataStatus
