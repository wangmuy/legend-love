-- tools/filter_web_data.lua
-- 过滤 Web MUD 不需要的字段（图像/音效相关），缩小 JSON 体积

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*a")
    f:close()
    return c
end

local function writeFile(path, content)
    local f = io.open(path, "w")
    if not f then
        os.execute("mkdir -p engine-web/data-web")
        f = io.open(path, "w")
    end
    f:write(content)
    f:close()
end

-- field filters per data type: keys to REMOVE from each record
local FILTERS = {
    chars = {
        "头像代号",
        "出招动画帧数",
        "出招动画延迟",
        "武功音效延迟",
    },
    items = {
        "暗器动画编号",
        "显示物品说明",
    },
    skills = {
        "出招音效",
        "武功动画&音效",
        "未知1", "未知2", "未知3", "未知4", "未知5",
    },
    scenes = {
        "出口音乐",
        "入口音乐",
    },
}

local function removeFields(record, keys)
    if type(record) ~= "table" then return record end
    for _, k in ipairs(keys) do
        record[k] = nil
    end
    return record
end

local function trimTrailingComma(str)
    -- Remove trailing comma before closing brace/bracket in JSON
    str = str:gsub(",\n(%s*[]}])", "\n%1")
    return str
end

local function filterJSON(inputPath, outputPath, recordKeys, removeKeys)
    local content = readFile(inputPath)
    if not content then
        print("  SKIP (not found): " .. inputPath)
        return
    end

    local filtered = content

    -- Process each record in the array
    -- Use a Lua-based approach: parse the JSON as Lua table
    local ok, data = pcall(loadstring or load, "return " .. content)
    if not ok then
        print("  PARSE FAILED: " .. inputPath)
        return
    end

    local fn = load("return " .. content, "filter")
    if not fn then
        print("  LOAD FAILED: " .. inputPath)
        return
    end
    local ok2, data2 = pcall(fn)
    if not ok2 then
        print("  EXEC FAILED: " .. inputPath)
        return
    end

    local records = data2[recordKeys]
    if not records then
        print("  NO ARRAY '" .. recordKeys .. "' in: " .. inputPath)
        return
    end

    local removed = 0
    for i = 1, #records do
        local before = 0
        for k in pairs(records[i]) do before = before + 1 end
        removeFields(records[i], removeKeys)
        local after = 0
        for k in pairs(records[i]) do after = after + 1 end
        removed = removed + (before - after)
    end

    -- Re-encode to JSON
    -- Use a simple manual JSON encoder
    local function encode(v, indent)
        indent = indent or ""
        local t = type(v)
        if t == "nil" then return "null"
        elseif t == "boolean" then return tostring(v)
        elseif t == "number" then return tostring(v)
        elseif t == "string" then
            local s = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
            return '"' .. s .. '"'
        elseif t == "table" then
            local isArray = true
            local maxN = 0
            for k in pairs(v) do
                if type(k) ~= "number" or k < 1 then isArray = false; break end
                if k > maxN then maxN = k end
            end
            if isArray and maxN == #v then
                local parts = {}
                for i = 1, #v do
                    parts[i] = indent .. "  " .. encode(v[i], indent .. "  ")
                end
                if #parts == 0 then return "[]" end
                return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
            else
                local parts = {}
                local keys = {}
                for k in pairs(v) do keys[#keys + 1] = k end
                table.sort(keys)
                for _, k in ipairs(keys) do
                    local val = v[k]
                    if val ~= nil then
                        local ks
                        if type(k) == "number" then ks = '"' .. k .. '"'
                        else ks = '"' .. k:gsub('"', '\\"') .. '"' end
                        parts[#parts + 1] = indent .. "  " .. ks .. ": " .. encode(val, indent .. "  ")
                    end
                end
                if #parts == 0 then return "{}" end
                return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
            end
        else
            return tostring(v)
        end
    end

    local result = "{\n"
    local fields = {}
    for k, v in pairs(data2) do
        if k ~= recordKeys then
            fields[#fields + 1] = '  ' .. encode(k) .. ": " .. encode(v, "  ")
        end
    end
    fields[#fields + 1] = '  ' .. encode(recordKeys) .. ": " .. encode(data2[recordKeys], "  ")
    result = result .. table.concat(fields, ",\n") .. "\n}\n"

    writeFile(outputPath, result)
    print("  " .. inputPath .. " → filtered, removed " .. removed .. " fields")
end

local function main()
    print("")
    print("=== Filtering Web MUD data ===")
    print("")

    for _, name in ipairs({"chars", "items", "skills", "scenes"}) do
        local keys = FILTERS[name]
        if keys then
            local recordKey = (name == "scenes") and "scenes" or name
            filterJSON(
                "engine-web/data-web/" .. name .. ".json",
                "engine-web/data-web/" .. name .. ".json",
                recordKey,
                keys
            )
        end
    end

    print("")
    print("Done.")
end

main()