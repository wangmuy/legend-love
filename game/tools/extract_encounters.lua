-- Extracts battle map and encounter data from game binary files
-- Run: cd game && lua tools/extract_encounters.lua
-- Produces: engine-web/data-web/wmap.json

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function readS16LE(data, offset)
    local b1 = data:byte(offset + 1)
    local b2 = data:byte(offset + 2)
    if not b1 or not b2 then return 0 end
    local n = b1 + b2 * 256
    if n > 32767 then n = n - 65536 end
    return n
end

local function readStr(data, offset, length)
    local bytes = {data:byte(offset + 1, offset + length)}
    local chars = {}
    for _, b in ipairs(bytes) do
        if b == 0 then break end
        if b >= 32 then
            chars[#chars + 1] = string.char(b)
        end
    end
    return table.concat(chars)
end

local function escapeJSON(text)
    local result = {}
    for i = 1, #text do
        local b = text:byte(i)
        if b == 92 then
            result[#result + 1] = "\\\\"
        elseif b == 34 then
            result[#result + 1] = '\\"'
        elseif b == 10 then
            result[#result + 1] = "\\n"
        elseif b == 13 then
            result[#result + 1] = "\\r"
        elseif b == 9 then
            result[#result + 1] = "\\t"
        elseif b < 32 then
            result[#result + 1] = string.format("\\u%04x", b)
        elseif b >= 128 then
            result[#result + 1] = string.format("\\u%04x", b)
        else
            result[#result + 1] = string.char(b)
        end
    end
    return table.concat(result)
end

local function writeJSON(outputPath, data)
    local function encode(v)
        local t = type(v)
        if t == "nil" then return "null"
        elseif t == "boolean" then return tostring(v)
        elseif t == "number" then return tostring(v)
        elseif t == "string" then return '"' .. escapeJSON(v) .. '"'
        elseif t == "table" then
            local isArray = true
            for k in pairs(v) do
                if type(k) ~= "number" or k ~= math.floor(k) or k <= 0 then
                    isArray = false
                    break
                end
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
                    parts[#parts + 1] = encode(k) .. ":" .. encode(v[k])
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
        else
            return tostring(v)
        end
    end
    local json = encode(data)
    local f = io.open(outputPath, "w")
    if not f then
        os.execute("mkdir -p engine-web/data-web")
        f = io.open(outputPath, "w")
    end
    f:write(json)
    f:write("\n")
    f:close()
    print("Wrote " .. outputPath)
end

local function main()
    print("=== Extracting Encounter Data ===\n")

    --------------------------------------------------------
    -- 1. Scan fight*.grp files for battle definitions
    --------------------------------------------------------
    local maps = {}
    for i = 0, 200 do
        local filename = string.format("data/fight%03d.grp", i)
        local f = io.open(filename, "rb")
        if f then
            f:close()
            table.insert(maps, {
                id = i,
                name = "fight" .. string.format("%03d", i),
                file = "fight" .. string.format("%03d", i) .. ".grp"
            })
        end
    end
    print("Found " .. #maps .. " fight*.grp files")

    --------------------------------------------------------
    -- 2. Parse warfld.idx/grp for battle map list
    --------------------------------------------------------
    local warfldIdxData = readFile("data/warfld.idx")
    local warfldGrpData = readFile("data/warfld.grp")
    local battleMaps = {}

    if warfldIdxData and warfldGrpData then
        local idxCount = math.floor(#warfldIdxData / 4)
        local mapSize = 64 * 64 * 6 * 2

        -- Map 0 always starts at offset 0
        battleMaps[0] = { id = 0, offset = 0, size = mapSize }

        -- Maps 1+ use idx entries
        for i = 1, idxCount do
            local offset_pos = (i - 1) * 4 + 1
            local b1, b2, b3, b4 = warfldIdxData:byte(offset_pos, offset_pos + 3)
            local offset = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
            battleMaps[i] = { id = i, offset = offset, size = mapSize }
        end

        local physicalMaps = {}
        for id, info in pairs(battleMaps) do
            if info.offset + info.size <= #warfldGrpData then
                table.insert(physicalMaps, { id = id, offset = info.offset })
            end
        end
        table.sort(physicalMaps, function(a, b) return a.id < b.id end)
        print("Battle maps in warfld: " .. #physicalMaps .. " (idx entries: " .. idxCount .. ")")
    else
        print("Could not read warfld files")
    end

    --------------------------------------------------------
    -- 3. Parse war.sta for encounter configuration
    --------------------------------------------------------
    local warData = readFile("data/war.sta")
    local encounters = {}
    local totalRecords = 0

    if warData then
        local recordSize = 186
        local numRecords = math.floor(#warData / recordSize)
        totalRecords = numRecords
        print("\nwar.sta: " .. #warData .. " bytes, " .. numRecords .. " records (" .. recordSize .. " bytes each)")

        for i = 0, numRecords - 1 do
            local offset = i * recordSize
            local warId = readS16LE(warData, offset)          -- 代号
            local name = readStr(warData, offset + 2, 10)     -- 名称
            local mapId = readS16LE(warData, offset + 12)     -- 地图

            -- Read enemies (20 slots, signed 16-bit each at offsets 66-104)
            local enemies = {}
            for j = 1, 20 do
                local enemyId = readS16LE(warData, offset + 66 + (j - 1) * 2)
                if enemyId > 0 then
                    local ex = readS16LE(warData, offset + 106 + (j - 1) * 2)
                    local ey = readS16LE(warData, offset + 146 + (j - 1) * 2)
                    table.insert(enemies, { id = enemyId, x = ex, y = ey })
                end
            end

            -- Read player characters (6 slots, at offsets 18-29)
            local players = {}
            for j = 1, 6 do
                local pid = readS16LE(warData, offset + 18 + (j - 1) * 2)
                if pid > 0 then
                    table.insert(players, pid)
                end
            end

            local entry = {
                id = warId,
                name = name,
                mapId = mapId,
                enemies = enemies,
                players = players
            }
            table.insert(encounters, entry)
        end

        -- Count battles with enemies
        local withEnemies = 0
        for _, e in ipairs(encounters) do
            if #e.enemies > 0 then
                withEnemies = withEnemies + 1
            end
        end
        print("  Records with enemies: " .. withEnemies .. " / " .. totalRecords)
    else
        print("Could not open data/war.sta")
    end

    --------------------------------------------------------
    -- 4. Build output
    --------------------------------------------------------
    local output = {
        version = "1.0",
        extracted = "2026-06-07",
        maps = maps,
        battleMaps = {},
        encounters = {}
    }

    for _, bm in pairs(battleMaps) do
        table.insert(output.battleMaps, { id = bm.id, offset = bm.offset, size = bm.size })
    end
    table.sort(output.battleMaps, function(a, b) return a.id < b.id end)

    for _, e in ipairs(encounters) do
        local enc = {
            id = e.id,
            name = e.name,
            mapId = e.mapId,
            enemies = {}
        }
        for _, enemy in ipairs(e.enemies) do
            table.insert(enc.enemies, { id = enemy.id, x = enemy.x, y = enemy.y })
        end
        enc.players = e.players
        table.insert(output.encounters, enc)
    end

    writeJSON("engine-web/data-web/wmap.json", output)

    print("\n=== Summary ===")
    print("  fight*.grp files: " .. #maps)
    print("  Battle maps (warfld): " .. #output.battleMaps)
    print("  Encounter records (war.sta): " .. #output.encounters)
    print("Done.")
end

main()