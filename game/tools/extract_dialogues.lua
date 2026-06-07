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

local function readGrp(path)
    local file = io.open(path, "rb")
    if not file then error("Cannot open " .. path) end
    local data = file:read("*a")
    file:close()
    return data
end

local function stripTrailingCRLF(text)
    return text:gsub("[\r\n]+$", "")
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
    local idxPath = "script/oldtalk.idx"
    local grpPath = "script/oldtalk.grp"
    local outputPath = "engine-web/data-web/dialogues.json"

    print("Reading " .. idxPath .. " ...")
    local offsets = readIdx(idxPath)
    print("  Found " .. #offsets .. " idx entries")

    print("Reading " .. grpPath .. " ...")
    local grpData = readGrp(grpPath)
    print("  Grp file size: " .. #grpData .. " bytes")

    local dialogues = {}
    for i = 1, #offsets do
        local start = (i == 1) and 0 or offsets[i - 1]
        local endPos = offsets[i]
        if start > #grpData then
            dialogues[i] = { id = i - 1, text = "" }
        else
            if endPos > #grpData then endPos = #grpData end
            local raw = grpData:sub(start + 1, endPos)
            raw = stripTrailingCRLF(raw)
            dialogues[i] = { id = i - 1, text = raw }
        end
    end

    local lines = {}
    lines[#lines + 1] = "{"
    lines[#lines + 1] = '  "version": "1.0",'
    lines[#lines + 1] = '  "extracted": "2026-06-07",'
    lines[#lines + 1] = '  "total": ' .. #dialogues .. ','
    lines[#lines + 1] = '  "dialogues": ['
    for i, d in ipairs(dialogues) do
        local comma = (i < #dialogues) and "," or ""
        lines[#lines + 1] = '    { "id": ' .. d.id .. ', "text": "' .. escapeJSON(d.text) .. '" }' .. comma
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
    print("Wrote " .. outputPath .. " (" .. #dialogues .. " dialogues)")
end

main()
