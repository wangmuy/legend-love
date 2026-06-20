-- tools/extract_war_sta.lua — 战斗配置数据提取
-- war.sta 格式：186 字节/条战斗记录，共 200 条
local extract = {}

function extract.run(dataDir, outputFile)
    local f = io.open(dataDir .. "/war.sta", "rb")
    if not f then error("Cannot open war.sta") end
    local data = f:read("*a")
    f:close()

    local RECORD_SIZE = 186
    local COUNT = #data / RECORD_SIZE
    local wars = {}
    for i = 0, COUNT - 1 do
        local off = i * RECORD_SIZE
        local id = data:byte(off + 1) + data:byte(off + 2) * 256
        if id ~= 65535 then
            local name = ""
            for j = 1, 10 do
                local b = data:byte(off + 2 + j) or 0
                if b ~= 0 then name = name .. string.char(b) end
            end
            local entry = { ["代号"] = id, ["名称"] = name }
            -- 敌人（20 个）
            local enemies = {}
            for j = 0, 19 do
                local eid = data:byte(off + 68 + j * 2) + data:byte(off + 69 + j * 2) * 256
                if eid ~= 0 then
                    local ex = data:byte(off + 108 + j * 2) + data:byte(off + 109 + j * 2) * 256
                    local ey = data:byte(off + 148 + j * 2) + data:byte(off + 149 + j * 2) * 256
                    table.insert(enemies, { ["代号"] = eid, ["X"] = ex, ["Y"] = ey })
                end
            end
            entry["敌人"] = enemies
            table.insert(wars, entry)
        end
    end

    local json = require("extract_scenes").encodeJson or encodeJson
    -- ... 写入 outputFile
    print("Extracted " .. #wars .. " wars")
    return wars
end

return extract
