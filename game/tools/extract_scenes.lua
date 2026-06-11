local extract = {}

local function escapeJsonString(s)
    local result = s:gsub("\\", "\\\\")
    result = result:gsub('"', '\\"')
    result = result:gsub("\n", "\\n")
    result = result:gsub("\r", "\\r")
    result = result:gsub("\t", "\\t")
    local buf = {}
    for i = 1, #result do
        local byte = result:byte(i)
        if byte < 0x20 then
            buf[#buf + 1] = string.format("\\u%04x", byte)
        else
            buf[#buf + 1] = result:sub(i, i)
        end
    end
    return table.concat(buf)
end

local function encodeJson(val, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local childPad = string.rep("  ", indent + 1)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "number" then
        if val == math.floor(val) then
            return tostring(val)
        end
        return tostring(val)
    elseif t == "string" then
        return '"' .. escapeJsonString(val) .. '"'
    elseif t == "table" then
        local isArray = true
        local maxIdx = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k < 1 then
                isArray = false
                break
            end
            if k > maxIdx then
                maxIdx = k
            end
        end
        if isArray then
            local parts = {}
            for i = 1, #val do
                parts[i] = encodeJson(val[i], indent + 1)
            end
            if #parts == 0 then
                return "[]"
            end
            return "[\n" .. childPad .. table.concat(parts, ",\n" .. childPad) .. "\n" .. pad .. "]"
        else
            local parts = {}
            local keys = {}
            for k, _ in pairs(val) do
                table.insert(keys, k)
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = val[k]
                table.insert(parts, encodeJson(k) .. ": " .. encodeJson(v, indent + 1))
            end
            if #parts == 0 then
                return "{}"
            end
            return "{\n" .. childPad .. table.concat(parts, ",\n" .. childPad) .. "\n" .. pad .. "}"
        end
    else
        return tostring(val)
    end
end

local function readU16(data, offset)
    return data:byte(offset + 1) + data:byte(offset + 2) * 256
end

local function readString(data, offset, length)
    local str = data:sub(offset + 1, offset + length)
    return str:match("^[^%z]+") or ""
end

local function inferType(name)
    if name == "" then return "outdoor" end
    if name:find("[客栈店楼]") then return "inn" end
    if name:find("[洞穴墓]") then return "cave" end
    if name:find("[寺庙庵]") then return "temple" end
    if name:find("[铺坊市]") then return "shop" end
    if name:find("[居宅庄]") then return "house" end
    return "outdoor"
end

local function readIdx(filename)
    local f = io.open(filename, "rb")
    if not f then
        error("Cannot open " .. filename)
    end
    local data = f:read(24)
    f:close()
    if not data or #data < 24 then
        error("idx file too short: " .. filename)
    end
    local idx = {0}
    for i = 1, 6 do
        idx[i] = readU16(data, (i - 1) * 4) + readU16(data, (i - 1) * 4 + 2) * 65536
    end
    return idx
end

local function readGrp(filename, offset, size)
    local f = io.open(filename, "rb")
    if not f then
        error("Cannot open " .. filename)
    end
    f:seek("set", offset)
    local data = f:read(size)
    f:close()
    if not data or #data < size then
        error("grp file too short: " .. filename .. " (expected " .. size .. " bytes, got " .. tostring(#data) .. ")")
    end
    return data
end

local function readSceneHead(data, offset)
    local id = readU16(data, offset)
    if id == 65535 then
        return nil
    end
    local name = readString(data, offset + 2, 20)
    local exitScene = readU16(data, offset + 26)
    local exitData = {}
    if exitScene ~= 0 and exitScene ~= 65535 then
        for j = 0, 2 do
            local ex = readU16(data, offset + 42 + j * 2)
            local ey = readU16(data, offset + 48 + j * 2)
            if ex ~= 65535 and ey ~= 65535 then
                local entry = {
                    ["方向"] = "跳转",
                    ["目标场景"] = exitScene,
                    ["X"] = ex,
                    ["Y"] = ey,
                }
                if j < 2 then
                    entry["目标X"] = readU16(data, offset + 54 + j * 2)
                    entry["目标Y"] = readU16(data, offset + 56 + j * 2)
                end
                table.insert(exitData, entry)
            end
        end
    end
    return {
        id = id,
        name = name,
        exitScene = exitScene,
        exitData = exitData,
        entranceX = readU16(data, offset + 38),
        entranceY = readU16(data, offset + 40),
        mapX = readU16(data, offset + 30),
        mapY = readU16(data, offset + 32),
        mapX2 = readU16(data, offset + 34),
        mapY2 = readU16(data, offset + 36),
        exitMusic = readU16(data, offset + 22),
        enterMusic = readU16(data, offset + 24),
        enterCondition = readU16(data, offset + 28),
    }
end

function extract.run(dataDir, outputFile)
    local idxPath = dataDir .. "/ranger.idx"
    local grpPath = dataDir .. "/ranger.grp"

    local idx = readIdx(idxPath)
    local sceneStart = idx[3]
    local sceneEnd = idx[4]
    local sceneCount = (sceneEnd - sceneStart) / 62

    local data = readGrp(grpPath, sceneStart, sceneEnd - sceneStart)

    local scenes = {}
    for i = 0, sceneCount - 1 do
        local offset = i * 62
        local sh = readSceneHead(data, offset)
        if sh then
            local entry = {
                ["代号"] = sh.id,
                ["名称"] = sh.name,
                ["类型"] = inferType(sh.name),
                ["宽度"] = 64,
                ["高度"] = 64,
                ["出口"] = sh.exitData,
                ["入口"] = { ["地图X"] = sh.mapX, ["地图Y"] = sh.mapY, ["地图X2"] = sh.mapX2, ["地图Y2"] = sh.mapY2 },
                ["出口音乐"] = sh.exitMusic,
                ["入口音乐"] = sh.enterMusic,
                ["进入条件"] = sh.enterCondition,
                ["NPC"] = {},
                ["物品"] = {},
                ["事件"] = {},
            }
            table.insert(scenes, entry)
        end
    end

    local result = {
        version = "1.0",
        extracted = os.date("%Y-%m-%d"),
        total = #scenes,
        scenes = scenes,
    }

    local json = encodeJson(result)
    local f = io.open(outputFile, "w")
    if not f then
        error("Cannot write " .. outputFile)
    end
    f:write(json)
    f:write("\n")
    f:close()
    print("Extracted " .. #scenes .. " scenes to " .. outputFile)
end

if arg and arg[0] and arg[0]:match("extract_scenes%.lua$") then
    local dataDir = arg[1] or "data"
    local outputFile = arg[2] or "engine-web/data-web/scenes.json"
    extract.run(dataDir, outputFile)
end

return extract
