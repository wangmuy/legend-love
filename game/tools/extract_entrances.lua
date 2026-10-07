local function readIdx(path)
    local file = io.open(path, "rb")
    if not file then error("Cannot open " .. path) end
    local data = file:read("*a")
    file:close()
    local offsets = {}
    for i = 1, #data, 4 do
        local b1, b2, b3, b4 = data:byte(i, i + 3)
        local offset = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
        offsets[#offsets + 1] = offset
    end
    return offsets
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then error("Cannot open " .. path) end
    local data = file:read("*a")
    file:close()
    return data
end

local function readU16(data, offset)
    local b1 = data:byte(offset + 1)
    local b2 = data:byte(offset + 2)
    if not b1 or not b2 then return 0 end
    return b1 + b2 * 256
end

local function readName(data, offset, maxLen)
    local buf = {}
    for i = 1, maxLen do
        local b = data:byte(offset + i)
        if not b or b == 0 then break end
        buf[#buf + 1] = string.char(b)
    end
    return table.concat(buf)
end

local function escapeJSON(text)
    local result = text:gsub("\\", "\\\\")
    result = result:gsub('"', '\\"')
    result = result:gsub("\n", "\\n")
    result = result:gsub("\r", "\\r")
    result = result:gsub("\t", "\\t")
    return result
end

local function main()
    local idxPath = "data/ranger.idx"
    local grpPath = "data/ranger.grp"
    local outputPath = "engine-web/data-web/entrances.json"
    local sceneSize = 62
    local MWidth = 480

    print("Reading " .. idxPath .. " ...")
    local offsets = readIdx(idxPath)
    print("  Found " .. #offsets .. " idx entries")

    local sceneStart = offsets[3]
    local sceneEnd = offsets[4]
    local sceneDataSize = sceneEnd - sceneStart
    local numScenes = math.floor(sceneDataSize / sceneSize)
    print("  Scene data: offset " .. sceneStart .. " to " .. sceneEnd)
    print("  Scene count: " .. numScenes)

    print("Reading " .. grpPath .. " ...")
    local grpData = readFile(grpPath)
    print("  Grp file size: " .. #grpData .. " bytes")

    local function readSceneField(sceneIdx, fieldOffset, fieldType, fieldLen)
        local absOffset = sceneStart + sceneIdx * sceneSize + fieldOffset
        if fieldType == "u16" then
            return readU16(grpData, absOffset)
        elseif fieldType == "str" then
            return readName(grpData, absOffset, fieldLen)
        end
        return 0
    end

    local entrances = {}
    local seenCoords = {}

    for i = 0, numScenes - 1 do
        local sceneId = readSceneField(i, 0, "u16")
        local name = readSceneField(i, 2, "str", 20)
        local mapX1 = readSceneField(i, 30, "u16")
        local mapY1 = readSceneField(i, 32, "u16")
        local mapX2 = readSceneField(i, 34, "u16")
        local mapY2 = readSceneField(i, 36, "u16")

        local function addEntrance(x, y)
            if x > 0 and y > 0 and x < MWidth and y < MWidth then
                local key = x * 10000 + y
                if not seenCoords[key] then
                    seenCoords[key] = true
                    entrances[#entrances + 1] = {
                        mapX = x,
                        mapY = y,
                        sceneIdx = i,
                        sceneId = sceneId,
                        name = name
                    }
                end
            end
        end

        addEntrance(mapX1, mapY1)
        addEntrance(mapX2, mapY2)
    end

    table.sort(entrances, function(a, b)
        if a.mapY ~= b.mapY then return a.mapY < b.mapY end
        return a.mapX < b.mapX
    end)

    local lines = {}
    lines[#lines + 1] = "{"
    lines[#lines + 1] = '  "version": "1.0",'
    lines[#lines + 1] = '  "extracted": "2026-06-07",'
    lines[#lines + 1] = '  "total": ' .. #entrances .. ','
    lines[#lines + 1] = '  "entrances": ['
    for i, e in ipairs(entrances) do
        local comma = (i < #entrances) and "," or ""
        lines[#lines + 1] = '    { "mapX": ' .. e.mapX
            .. ', "mapY": ' .. e.mapY
            .. ', "sceneIdx": ' .. e.sceneIdx
            .. ', "sceneId": ' .. e.sceneId
            .. ', "name": "' .. escapeJSON(e.name) .. '" }' .. comma
    end
    lines[#lines + 1] = "  ]"
    lines[#lines + 1] = "}"

    local json = table.concat(lines, "\n")

    local outFile = io.open(outputPath, "w")
    if not outFile then
        os.execute("mkdir -p engine-web/data-web")
        outFile = io.open(outputPath, "w")
    end
    outFile:write(json)
    outFile:close()
    print("Wrote " .. outputPath .. " (" .. #entrances .. " entrances)")
end

main()