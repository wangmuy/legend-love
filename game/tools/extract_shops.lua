-- tools/extract_shops.lua
-- Extract shop data from ranger.grp (5 shops, 30 bytes each)
-- Located at idx[5] (offsets[5]) in ranger.idx

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

local function readIdx(path)
    local data = readFile(path)
    if not data or #data < 24 then return nil end
    local idx = {0}
    for i = 1, 6 do
        idx[i] = getU16(data, (i - 1) * 4) + getU16(data, (i - 1) * 4 + 2) * 65536
    end
    return idx
end

local function escapeJSON(text)
    local result = text:gsub("\\", "\\\\")
    result = result:gsub('"', '\\"')
    result = result:gsub("\n", "\\n")
    result = result:gsub("\r", "\\r")
    result = result:gsub("\t", "\\t")
    return result
end

local OUTPUT_FILE = "engine-web/data-web/shops.json"

local function main()
    local idxPath = "data/ranger.idx"
    local grpPath = "data/ranger.grp"

    local idx = readIdx(idxPath)
    if not idx then
        print("ERROR: Cannot read " .. idxPath)
        return
    end

    local shopStart = idx[5]
    local shopEnd = idx[6]
    local shopSize = 30
    local numShops = math.floor((shopEnd - shopStart) / shopSize)

    local data = readFile(grpPath)
    if not data then
        print("ERROR: Cannot open " .. grpPath)
        return
    end

    print("Shops: offset " .. shopStart .. " to " .. shopEnd .. " (" .. numShops .. " shops, " .. shopSize .. " bytes each)")

    local shops = {}
    for i = 0, numShops - 1 do
        local offset = shopStart + i * shopSize
        -- Shop struct: 15 × s16 fields
        -- Fields: itemId1..10 (offsets 0-18), itemCount1..5 (offsets 20-28)
        local items = {}
        for j = 0, 9 do
            local itemId = get16(data, offset + j * 2)
                if itemId > 0 and itemId < 1000 then
                    local count = 0
                    if j < 5 then
                        count = get16(data, offset + 20 + j * 2)
                    end
                    items[#items + 1] = { id = itemId, count = count }
                end
        end
        shops[i + 1] = { shopId = i, items = items }
    end

    -- Build JSON
    local lines = {}
    lines[#lines + 1] = "{"
    lines[#lines + 1] = '  "version": "1.0",'
    lines[#lines + 1] = '  "extracted": "' .. os.date("%Y-%m-%d") .. '",'
    lines[#lines + 1] = '  "total": ' .. numShops .. ','
    lines[#lines + 1] = '  "shops": ['

    local entries = {}
    for i, shop in ipairs(shops) do
        local comma = (i < #shops) and "," or ""
        local itemParts = {}
        for _, it in ipairs(shop.items) do
            itemParts[#itemParts + 1] = '{"id":' .. it.id .. ',"count":' .. it.count .. '}'
        end
        local itemsStr = "[" .. table.concat(itemParts, ",") .. "]"
        entries[#entries + 1] = '    {"shopId":' .. shop.shopId .. ',"items":' .. itemsStr .. '}' .. comma
    end
    lines[#lines + 1] = table.concat(entries, "\n")
    lines[#lines + 1] = "  ]"
    lines[#lines + 1] = "}"

    local json = table.concat(lines, "\n")
    local f = io.open(OUTPUT_FILE, "w")
    if not f then
        os.execute("mkdir -p engine-web/data-web")
        f = io.open(OUTPUT_FILE, "w")
    end
    f:write(json)
    f:close()
    print("Wrote " .. OUTPUT_FILE .. " (" .. numShops .. " shops)")
end

main()