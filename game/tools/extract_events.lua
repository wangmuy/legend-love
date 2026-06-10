-- tools/extract_events.lua
-- Extract D* event data from alldef.grp
-- Each scene has 200 tile events, each event has 11 int16 fields

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function get16(data, offset)
    local b1 = data:byte(offset + 1) or 0
    local b2 = data:byte(offset + 2) or 0
    local n = b1 + b2 * 256
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

local FIELD_NAMES = {
    "passable", "unknown1", "eventSpace", "eventTouch", "eventExtra",
    "tileStart", "tileEnd", "tileCurrent", "animDelay", "x", "y",
}

local SCENE_IDS_FILE = "engine-web/data-web/scenes.json"
local OUTPUT_FILE = "engine-web/data-web/events.json"

local function main()
    local inputPath = "data/alldef.grp"
    local data = readFile(inputPath)
    if not data then
        print("ERROR: Cannot open " .. inputPath)
        return
    end
    print("Reading " .. inputPath .. " (" .. #data .. " bytes)")

    local totalInts = math.floor(#data / 2)
    local eventsPerScene = 200
    local fieldsPerEvent = 11
    local numScenes = math.floor(totalInts / (eventsPerScene * fieldsPerEvent))

    -- Try to read scene IDs from scenes.json for mapping
    local sceneIds = {}
    local scenesData = readFile(SCENE_IDS_FILE)
    if scenesData then
        for sid in scenesData:gmatch('"id"[%s:]*([0-9]+)') do
            sceneIds[#sceneIds + 1] = tonumber(sid)
        end
    end
    print("Scene IDs loaded: " .. #sceneIds .. " (from " .. SCENE_IDS_FILE .. ")")

    if numScenes == 0 and #sceneIds > 0 then
        numScenes = #sceneIds
    end
    if numScenes == 0 then
        numScenes = math.floor(totalInts / (eventsPerScene * fieldsPerEvent))
    end
    print("Events per scene: " .. eventsPerScene .. ", scenes: " .. numScenes)

    local allEvents = {}
    local eventCount = 0

    for si = 0, numScenes - 1 do
        local sceneId = sceneIds[si + 1] or si
        local baseIdx = si * eventsPerScene * fieldsPerEvent

        for ei = 0, eventsPerScene - 1 do
            local evBase = baseIdx + ei * fieldsPerEvent
            local ev = { sceneId = sceneId, tileIndex = ei }
            for fi = 0, fieldsPerEvent - 1 do
                local val = get16(data, (evBase + fi) * 2)
                ev[FIELD_NAMES[fi + 1]] = val
            end
            allEvents[eventCount + 1] = ev
            eventCount = eventCount + 1
        end
    end

    -- Build JSON
    local lines = {}
    lines[#lines + 1] = "{"
    lines[#lines + 1] = '  "version": "1.0",'
    lines[#lines + 1] = '  "extracted": "' .. os.date("%Y-%m-%d") .. '",'
    lines[#lines + 1] = '  "total": ' .. eventCount .. ','
    lines[#lines + 1] = '  "events": ['

    local entries = {}
    for i = 1, eventCount do
        local ev = allEvents[i]
        local parts = {}
        parts[#parts + 1] = '"sceneId":' .. ev.sceneId
        parts[#parts + 1] = '"tileIndex":' .. ev.tileIndex
        for _, name in ipairs(FIELD_NAMES) do
            parts[#parts + 1] = '"' .. name .. '":' .. ev[name]
        end
        table.insert(entries, "    {" .. table.concat(parts, ",") .. "}")
    end
    lines[#lines + 1] = table.concat(entries, ",\n")
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
    print("Wrote " .. OUTPUT_FILE .. " (" .. eventCount .. " events)")
end

main()
