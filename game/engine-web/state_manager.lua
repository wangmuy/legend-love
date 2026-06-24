-- state_manager.lua
-- Game state persistence for Web MUD
-- JY.* tables use Chinese keys matching CC.*_S in jyconst.lua
-- initDataSource also uses Chinese keys (from extraction pipeline)

local SAVE_KEY_PREFIX = "save_"

function initGameState()
    if not rawget(_G, "JY") then rawset(_G, "JY", {}) end
    local dc = _G.initDataSource
    if not dc then return end

    -- Characters: initDataSource.chars → JY.Person (copy directly, keys already Chinese)
    JY.Person = {}
    if dc.chars then
        local charList = dc.chars["chars"] or dc.chars
        if type(charList) == "table" then
            for _, rec in ipairs(charList) do
                if type(rec) == "table" and rec["代号"] ~= nil then
                    JY.Person[rec["代号"]] = rec
                end
            end
        end
    end

    -- Items: initDataSource.items → JY.Thing
    JY.Thing = {}
    if dc.items then
        local itemList = dc.items["items"] or dc.items
        if type(itemList) == "table" then
            for _, rec in ipairs(itemList) do
                if type(rec) == "table" and rec["代号"] ~= nil then
                    JY.Thing[rec["代号"]] = rec
                end
            end
        end
    end

    -- Skills: initDataSource.skills → JY.Wugong
    JY.Wugong = {}
    if dc.skills then
        local skillList = dc.skills["skills"] or dc.skills
        if type(skillList) == "table" then
            for _, rec in ipairs(skillList) do
                if type(rec) == "table" and rec["代号"] ~= nil then
                    JY.Wugong[rec["代号"]] = rec
                end
            end
        end
    end

    -- Scenes: initDataSource.scenes → JY.Scene (flatten nested structure)
    JY.Scene = {}
    if dc.scenes then
        for _, rec in ipairs(dc.scenes or {}) do
            local cn = {
                ["代号"] = rec["代号"],
                ["名称"] = rec["名称"],
            }
            if rec["入口"] then
                cn["入口X"] = rec["入口"]["地图X"] or 0
                cn["入口Y"] = rec["入口"]["地图Y"] or 0
                cn["外景入口X1"] = rec["入口"]["地图X"] or 0
                cn["外景入口Y1"] = rec["入口"]["地图Y"] or 0
                cn["外景入口X2"] = rec["入口"]["地图X2"] or 0
                cn["外景入口Y2"] = rec["入口"]["地图Y2"] or 0
            end
            cn["跳转场景"] = 0
            if rec["出口"] and #rec["出口"] > 0 then
                cn["跳转场景"] = rec["出口"][1]["目标场景"] or 0
                for j, exit in ipairs(rec["出口"]) do
                    if j <= 3 then
                        cn["出口X" .. j] = exit["X"] or 0
                        cn["出口Y" .. j] = exit["Y"] or 0
                    end
                    if j <= 2 then
                        cn["跳转口X" .. j] = exit["目标X"] or 0
                        cn["跳转口Y" .. j] = exit["目标Y"] or 0
                    end
                end
            end
            cn["进入条件"] = rec["进入条件"] or 0
            JY.Scene[rec["代号"]] = cn
        end
    end

    -- Base: initDataSource.config → JY.Base (flatten nested structure)
    JY.Base = {}
    if dc.config then
        local cfg = dc.config
        JY.Base["乘船"] = (cfg["船"] and cfg["船"]["启用"]) and 1 or 0
        JY.Base["无用"] = 0
        local pl = cfg["玩家"] or {}
        JY.Base["人X"] = pl["X"] or 0
        JY.Base["人Y"] = pl["Y"] or 0
        JY.Base["人X1"] = pl["X1"] or 0
        JY.Base["人Y1"] = pl["Y1"] or 0
        JY.Base["人方向"] = pl["方向"] or 0
        local sh = cfg["船"] or {}
        JY.Base["船X"] = sh["X"] or 0
        JY.Base["船Y"] = sh["Y"] or 0
        JY.Base["船X1"] = sh["X1"] or 0
        JY.Base["船Y1"] = sh["Y1"] or 0
        JY.Base["船方向"] = sh["方向"] or 0
        if cfg["队伍"] then
            for i = 1, 6 do
                JY.Base["队伍" .. i] = cfg["队伍"][i] or 0
            end
        end
        if cfg["物品"] then
            for i, item in ipairs(cfg["物品"]) do
                if i <= 30 then
                    JY.Base["物品" .. i] = item["代号"] or 0
                    JY.Base["物品数量" .. i] = item["数量"] or 0
                end
            end
        end
    end

    -- Shops: initDataSource.shops → JY.Shop
    JY.Shop = {}
    if dc.shops then
        for i, rec in ipairs(dc.shops) do
            local sid = rec["店铺代号"] or (i - 1)
            local shop = {}
            if rec["物品"] then
                for j, item in ipairs(rec["物品"]) do
                    if j <= 5 then
                        shop["物品" .. j] = item["代号"] or 0
                        shop["物品数量" .. j] = item["数量"] or 0
                        shop["物品价格" .. j] = item["价格"] or 0
                    end
                end
            end
            JY.Shop[sid] = shop
        end
    end
end

-- Convert string keys that look like integers back to numeric keys
-- Needed because JSON serializes Lua numeric key 0 as string key "0"
function restoreNumericKeys(tbl)
    if type(tbl) ~= "table" then return tbl end
    local result = {}
    for k, v in pairs(tbl) do
        local nk = tonumber(k)
        if nk and type(k) == "string" and tostring(nk) == k then
            result[nk] = restoreNumericKeys(v)
        else
            result[k] = restoreNumericKeys(v)
        end
    end
    return result
end

function saveGameState(slotId)
    slotId = slotId or 0
    local data = {
        version = "1",
        timestamp = os.time() or 0,
    }
    local ref = _G.JY
    if ref then
        data.base = ref.Base
        data.persons = ref.Person
        data.things = ref.Thing
        data.scenes = ref.Scene
        data.wugongs = ref.Wugong
        data.shops = ref.Shop
    end

    local json = encodeSimpleJSON(data)
    if _G.JSBridge and _G.JSBridge.save then
        _G.JSBridge.save(SAVE_KEY_PREFIX .. tostring(slotId), json)
        return true
    end
    return false
end

function loadGameState(slotId)
    slotId = slotId or 0
    if not _G.JSBridge or not _G.JSBridge.load then
        return false
    end
    local json = _G.JSBridge.load(SAVE_KEY_PREFIX .. tostring(slotId))
    if not json or json == "" then
        return false
    end
    local ok, data = pcall(parseJSON, json)
    if not ok or not data then
        return false
    end

    if not rawget(_G, "JY") then rawset(_G, "JY", {}) end
    local restoreMap = {
        base = "Base",
        persons = "Person",
        things = "Thing",
        scenes = "Scene",
        wugongs = "Wugong",
        shops = "Shop",
    }
    for jsonKey, jyKey in pairs(restoreMap) do
        local src = data[jsonKey]
        if src then
            _G.JY[jyKey] = restoreNumericKeys(src)
        end
    end
    return true
end

function listSaveSlots()
    if _G.JSBridge and _G.JSBridge.listSaves then
        return _G.JSBridge.listSaves()
    end
    return {}
end

function deleteSaveSlot(slotId)
    slotId = slotId or 0
    if _G.JSBridge and _G.JSBridge.delete then
        _G.JSBridge.delete(SAVE_KEY_PREFIX .. tostring(slotId))
        return true
    end
end

-- Simple JSON encoder for saving
function encodeSimpleJSON(val)
    local t = type(val)
    if t == "nil" then return "null"
    elseif t == "boolean" then return tostring(val)
    elseif t == "number" then
        if val == math.floor(val) and val < 9007199254740992 and val > -9007199254740992 then
            return tostring(val)
        end
        return string.format("%g", val)
    elseif t == "string" then
        local s = val:gsub("\\", "\\\\")
        s = s:gsub('"', '\\"')
        s = s:gsub("\n", "\\n")
        s = s:gsub("\r", "\\r")
        s = s:gsub("\t", "\\t")
        return '"' .. s .. '"'
    elseif t == "table" then
        local isArray = true
        local maxIdx = 0
        for k in pairs(val) do
            if type(k) ~= "number" or k < 1 then isArray = false; break end
            if k > maxIdx then maxIdx = k end
        end
        if isArray and maxIdx > 0 then
            local parts = {}
            for i = 1, maxIdx do
                parts[i] = encodeSimpleJSON(val[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        elseif isArray and maxIdx == 0 then
            return "[]"
        else
            local parts = {}
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = val[k]
                if v ~= nil then
                    parts[#parts + 1] = encodeSimpleJSON(tostring(k)) .. ":" .. encodeSimpleJSON(v)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return tostring(val)
    end
end

-- Expose globals
_G.initGameState = initGameState
_G.saveGameState = saveGameState
_G.loadGameState = loadGameState
_G.listSaveSlots = listSaveSlots
_G.deleteSaveSlot = deleteSaveSlot
_G.encodeSimpleJSON = encodeSimpleJSON
_G.restoreNumericKeys = restoreNumericKeys

return {
    initGameState = initGameState,
    saveGameState = saveGameState,
    loadGameState = loadGameState,
    listSaveSlots = listSaveSlots,
    deleteSaveSlot = deleteSaveSlot,
    encodeSimpleJSON = encodeSimpleJSON,
    restoreNumericKeys = restoreNumericKeys,
}