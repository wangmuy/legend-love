-- tools/extract_base.lua
-- Extract base game data from ranger.grp (first 836 bytes)
-- Base_S structure defined in jyconst.lua: 乘船, 人X/Y, 方向, 队伍, 物品栏

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function getU16(data, offset)
    local b1 = data:byte(offset + 1) or 0
    local b2 = data:byte(offset + 2) or 0
    return b1 + b2 * 256
end

local function get16(data, offset)
    local n = getU16(data, offset)
    if n > 32767 then n = n - 65536 end
    return n
end

local function getStr(data, offset, length)
    local bytes = {}
    for i = 1, length do
        local b = data:byte(offset + i)
        if not b or b == 0 then break end
        bytes[#bytes + 1] = string.char(b)
    end
    return table.concat(bytes)
end

local function escapeJSON(text)
    local result = text:gsub("\\", "\\\\")
    result = result:gsub('"', '\\"')
    result = result:gsub("\n", "\\n")
    result = result:gsub("\r", "\\r")
    result = result:gsub("\t", "\\t")
    return result
end

local OUTPUT_FILE = "engine-web/data-web/config.json"

local function main()
    local grpPath = "data/ranger.grp"
    local data = readFile(grpPath)
    if not data then
        print("ERROR: Cannot open " .. grpPath)
        return
    end

    local baseSize = 836
    if #data < baseSize then
        print("ERROR: ranger.grp too small (" .. #data .. " bytes, expected >= " .. baseSize .. ")")
        return
    end

    local ship = getU16(data, 0)       -- 乘船 (offset 0)
    local px = get16(data, 4)          -- 人X (offset 4)
    local py = get16(data, 6)          -- 人Y (offset 6)
    local px1 = get16(data, 8)         -- 人X1 (offset 8)
    local py1 = get16(data, 10)        -- 人Y1 (offset 10)
    local face = get16(data, 12)       -- 人方向 (offset 12)
    local shipX = get16(data, 14)      -- 船X (offset 14)
    local shipY = get16(data, 16)      -- 船Y (offset 16)
    local shipX1 = get16(data, 18)     -- 船X1 (offset 18)
    local shipY1 = get16(data, 20)     -- 船Y1 (offset 20)
    local shipFace = get16(data, 22)   -- 船方向 (offset 22)

    -- Team members (offsets 24-35, 6 slots)
    local team = {}
    for i = 0, 5 do
        team[i + 1] = get16(data, 24 + i * 2)
    end

    -- Items (offsets 36-155, 30 slots, each 4 bytes: id + count)
    -- Actually looking at jyconst.lua more carefully:
    -- 物品1=36, 物品数量1=38, 物品2=40, 物品数量2=42 ...
    -- But the struct only defines 30 items
    local items = {}
    for i = 0, 29 do
        local itemId = get16(data, 36 + i * 4)
        local itemCount = get16(data, 36 + i * 4 + 2)
        if itemId > 0 then
            items[#items + 1] = { id = itemId, count = itemCount }
        end
    end

    local config = {
        version = "1.0",
        extracted = os.date("%Y-%m-%d"),
        my = { px = px, py = py, px1 = px1, py1 = py1, face = face },
        ship = { enabled = ship > 0, x = shipX, y = shipY, x1 = shipX1, y1 = shipY1, face = shipFace },
        team = team,
        items = items,
        baseSize = baseSize,
    }

    -- Build JSON manually
    local function encode(v)
        local t = type(v)
        if t == "nil" then return "null"
        elseif t == "boolean" then return tostring(v)
        elseif t == "number" then return tostring(v)
        elseif t == "string" then return '"' .. escapeJSON(v) .. '"'
        elseif t == "table" then
            local isArray = true
            for k in pairs(v) do
                if type(k) ~= "number" or k < 1 then isArray = false; break end
            end
            if isArray then
                local parts = {}
                for _, val in ipairs(v) do
                    parts[#parts + 1] = encode(val)
                end
                return "[" .. table.concat(parts, ",") .. "]"
            else
                local parts = {}
                local keys = {}
                for k in pairs(v) do keys[#keys + 1] = k end
                table.sort(keys)
                for _, k in ipairs(keys) do
                    parts[#parts + 1] = '"' .. k .. '":' .. encode(v[k])
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
        else
            return tostring(v)
        end
    end

    local json = encode(config) .. "\n"
    local f = io.open(OUTPUT_FILE, "w")
    if not f then
        os.execute("mkdir -p engine-web/data-web")
        f = io.open(OUTPUT_FILE, "w")
    end
    f:write(json)
    f:close()
    print("Wrote " .. OUTPUT_FILE)
end

main()