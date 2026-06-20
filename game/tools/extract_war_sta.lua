-- tools/extract_war_sta.lua — 战斗配置数据提取
-- war.sta 格式：186 字节/条战斗记录，共 200 条
local extract = {}

function extract.run(dataDir, outputFile)
    local f = io.open(dataDir .. "/war.sta", "rb")
    if not f then error("Cannot open war.sta") end
    local data = f:read("*a")
    f:close()

    local RECORD_SIZE = 186
    local COUNT = math.floor(#data / RECORD_SIZE)
    local wars = {}
    for i = 0, (COUNT - 1) * RECORD_SIZE, RECORD_SIZE do
        local id = data:byte(i + 1) + data:byte(i + 2) * 256
        if id ~= 0 and id ~= 65535 then
            local name = ""
            for j = 1, 10 do
                local b = data:byte(i + 2 + j) or 0
                if b >= 32 and b <= 126 then name = name .. string.char(b) end
            end
            local entry = { ["代号"] = id, ["名称"] = name }
            local enemies = {}
            for j = 0, 19 do
                local eid = data:byte(i + 67 + j * 2) + data:byte(i + 68 + j * 2) * 256
                if eid ~= 0 then
                    local ex = data:byte(i + 107 + j * 2) + data:byte(i + 108 + j * 2) * 256
                    local ey = data:byte(i + 147 + j * 2) + data:byte(i + 148 + j * 2) * 256
                    table.insert(enemies, { ["代号"] = eid, ["X"] = ex, ["Y"] = ey })
                end
            end
            entry["敌人"] = enemies
            table.insert(wars, entry)
        end
    end

    -- 手动 JSON 序列化
    local parts = {}
    for _, w in ipairs(wars) do
        local en = {}
        for _, e in ipairs(w["敌人"]) do
            table.insert(en, '{"代号":' .. e["代号"] .. ',"X":' .. e["X"] .. ',"Y":' .. e["Y"] .. '}')
        end
        table.insert(parts, '{"代号":' .. w["代号"] .. ',"名称":"' .. (w["名称"] or "") .. '","敌人":[' .. table.concat(en, ",") .. ']}')
    end

    local json = '{"version":"1.0","total":' .. #wars .. ',"wars":[' .. table.concat(parts, ",") .. ']}'
    local fout = io.open(outputFile, "w")
    if fout then
        fout:write(json)
        fout:write("\n")
        fout:close()
    end
    print("Extracted " .. #wars .. " wars to " .. outputFile)
    return wars
end

if arg and arg[0]:match("extract_war_sta%.lua$") then
    local dataDir = arg[1] or "data"
    local outputFile = arg[2] or "engine-web/data-web/wars.json"
    extract.run(dataDir, outputFile)
end

return extract
