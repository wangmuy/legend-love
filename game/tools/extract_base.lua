-- tools/extract_base.lua
-- Extract base game data from ranger.grp (first 836 bytes)

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

    local ship = getU16(data, 0)
    local px = get16(data, 4)
    local py = get16(data, 6)
    local px1 = get16(data, 8)
    local py1 = get16(data, 10)
    local face = get16(data, 12)
    local shipX = get16(data, 14)
    local shipY = get16(data, 16)
    local shipX1 = get16(data, 18)
    local shipY1 = get16(data, 20)
    local shipFace = get16(data, 22)

    local team = {}
    for i = 0, 5 do
        team[i + 1] = get16(data, 24 + i * 2)
    end

    local items = {}
    for i = 0, 29 do
        local itemId = get16(data, 36 + i * 4)
        local itemCount = get16(data, 36 + i * 4 + 2)
        if itemId > 0 then
            items[#items + 1] = { ["代号"] = itemId, ["数量"] = itemCount }
        end
    end

    local config = {
        ["版本"] = "1.0",
        ["提取时间"] = os.date("%Y-%m-%d"),
        ["玩家"] = { ["X"] = px, ["Y"] = py, ["X1"] = px1, ["Y1"] = py1, ["方向"] = face },
        ["船"] = { ["启用"] = ship > 0, ["X"] = shipX, ["Y"] = shipY, ["X1"] = shipX1, ["Y1"] = shipY1, ["方向"] = shipFace },
        ["队伍"] = team,
        ["物品"] = items,
        ["数据大小"] = baseSize,
    }

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
                    parts[#parts + 1] = '"' .. escapeJSON(k) .. '":' .. encode(v[k])
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