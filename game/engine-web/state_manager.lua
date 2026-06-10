-- state_manager.lua
-- Field name mapping + game state persistence for Web MUD
-- English keys (dataCache) ↔ Chinese keys (JY.*)

-- Mapping: English → Chinese for each struct type
_G.fieldMap = {
    person = {
        id = "代号", name = "姓名", title = "外号",
        sex = "性别", level = "等级", hpGrowth = "生命增长", exp = "经验",
        hp = "生命", maxHp = "生命最大值",
        mp = "内力", maxMp = "内力最大值",
        attack = "攻击力", speed = "轻功", defence = "防御力",
        medical = "医疗能力", poison = "用毒能力",
        antiPoison = "解毒能力", antiPoisonResist = "抗毒能力",
        fist = "拳掌功夫", sword = "御剑能力", blade = "耍刀技巧",
        special = "特殊兵器", hidden = "暗器技巧",
        martialKnowledge = "武学常识", morality = "品德",
        poisonAttack = "攻击带毒", doubleAttack = "左右互搏", fame = "声望",
        aptitude = "资质", wounded = "受伤程度", poisoned = "中毒程度",
        stamina = "体力", innerType = "内力性质",
        practicePoints = "物品修炼点数", weapon = "武器", armour = "防具",
        trainingItem = "修炼物品", trainingPoints = "修炼点数",
    },
    -- person arrays: skills[1..10]→武功1..10, skillLevels[1..10]→武功等级1..10
    --              items[1..4]→携带物品1..4, itemCounts[1..4]→携带物品数量1..4
    --              attackAnimFrames[1..5]→出招动画帧数1..5
    --              attackAnimDelays[1..5]→出招动画延迟1..5
    --              soundDelays[1..5]→武功音效延迟1..5
    personArrays = {
        skills = { prefix = "武功", count = 10 },
        skillLevels = { prefix = "武功等级", count = 10 },
        items = { prefix = "携带物品", count = 4 },
        itemCounts = { prefix = "携带物品数量", count = 4 },
        attackAnimFrames = { prefix = "出招动画帧数", count = 5 },
        attackAnimDelays = { prefix = "出招动画延迟", count = 5 },
        soundDelays = { prefix = "武功音效延迟", count = 5 },
    },
    thing = {
        id = "代号", name = "名称", name2 = "名称2", desc = "物品说明",
        learnedSkill = "练出武功",
        user = "使用人", equipType = "装备类型", itemType = "类型",
        unknown5 = "未知5", unknown6 = "未知6", unknown7 = "未知7",
        addHp = "加生命", addMaxHp = "加生命最大值",
        addPoison = "加中毒解毒", addStamina = "加体力",
        changeInnerType = "改变内力性质",
        addMp = "加内力", addMaxMp = "加内力最大值",
        addAttack = "加攻击力", addSpeed = "加轻功", addDefence = "加防御力",
        addMedical = "加医疗能力", addPoisonSkill = "加用毒能力",
        addAntiPoison = "加解毒能力", addAntiPoisonResist = "加抗毒能力",
        addFist = "加拳掌功夫", addSword = "加御剑能力", addBlade = "加耍刀技巧",
        addSpecial = "加特殊兵器", addHidden = "加暗器技巧",
        addMartialKnowledge = "加武学常识", addMorality = "加品德",
        addAttackCount = "加攻击次数", addPoisonAttack = "加攻击带毒",
        practiceUser = "仅修炼人物",
        needInnerType = "需内力性质", needMp = "需内力",
        needAttack = "需攻击力", needSpeed = "需轻功",
        needPoisonSkill = "需用毒能力", needMedical = "需医疗能力",
        needAntiPoison = "需解毒能力",
        needFist = "需拳掌功夫", needSword = "需御剑能力", needBlade = "需耍刀技巧",
        needSpecial = "需特殊兵器", needHidden = "需暗器技巧",
        needAptitude = "需资质", needExp = "需经验",
        craftNeedExp = "练出物品需经验", needMaterial = "需材料",
    },
    thingArrays = {
        craftItems = { prefix = "练出物品", count = 5 },
        craftCounts = { prefix = "需要物品数量", count = 5 },
    },
    skill = {
        id = "代号", name = "名称",
        skillType = "武功类型", damageType = "伤害类型",
        range = "攻击范围", mpCost = "消耗内力点数", poison = "敌人中毒点数",
    },
    skillArrays = {
        powers = { prefix = "攻击力", count = 10 },
        moveRange = { prefix = "移动范围", count = 10 },
        damageRange = { prefix = "杀伤范围", count = 10 },
        addMp = { prefix = "加内力", count = 10 },
        killMp = { prefix = "杀内力", count = 10 },
    },
    scene = {
        id = "代号", name = "名称",
        jumpScene = "跳转场景", enterCondition = "进入条件",
    },
    shop = {
        itemsList = { prefix = "物品", count = 5 },
        countsList = { prefix = "物品数量", count = 5 },
        pricesList = { prefix = "物品价格", count = 5 },
    },
}

-- Build reverse (Chinese→English) mapping
_G.fieldMapCN = {}
do
    local function makeReverseStruct(enTable, cnPrefix)
        local rev = {}
        for en, cn in pairs(enTable) do
            rev[cn] = en
        end
        return rev
    end
    _G.fieldMapCN.person = makeReverseStruct(_G.fieldMap.person)
    _G.fieldMapCN.thing = makeReverseStruct(_G.fieldMap.thing)
    _G.fieldMapCN.skill = makeReverseStruct(_G.fieldMap.skill)
    _G.fieldMapCN.scene = makeReverseStruct(_G.fieldMap.scene)
end

-- Convert a single record from English keys → Chinese keys
function toChineseKeys(record, map, arrayMap)
    local result = {}
    -- Scalar fields
    for en, cn in pairs(map) do
        if record[en] ~= nil then
            result[cn] = record[en]
        end
    end
    -- Array fields
    if arrayMap then
        for en, cfg in pairs(arrayMap) do
            local arr = record[en]
            if type(arr) == "table" then
                for i = 1, cfg.count do
                    if arr[i] ~= nil then
                        result[cfg.prefix .. i] = arr[i]
                    end
                end
            end
        end
    end
    return result
end

-- Convert a single record from Chinese keys → English keys
function toEnglishKeys(record, map, arrayMap)
    local result = {}
    -- Build reverse scalar map
    local cn2en = {}
    for en, cn in pairs(map) do
        cn2en[cn] = en
    end
    -- Match scalar fields
    for cn, val in pairs(record) do
        if cn2en[cn] then
            result[cn2en[cn]] = val
        end
    end
    -- Match array fields
    if arrayMap then
        for en, cfg in pairs(arrayMap) do
            local arr = {}
            for i = 1, cfg.count do
                local cnKey = cfg.prefix .. i
                if record[cnKey] ~= nil then
                    arr[i] = record[cnKey]
                end
            end
            if next(arr) then
                result[en] = arr
            end
        end
    end
    return result
end

-- Convert all records in dataCache (English) to JY.* tables (Chinese)
-- Returns tables ready for use by game scripts
function buildJYTables()
    local JY = {}
    JY.Base = {}
    JY.Person = {}
    JY.Thing = {}
    JY.Scene = {}
    JY.Wugong = {}
    JY.Shop = {}

    -- Characters: dataCache.chars → JY.Person
    if _G.dataCache and _G.dataCache.chars then
        for i, rec in ipairs(_G.dataCache.chars) do
            JY.Person[rec.id] = toChineseKeys(rec, _G.fieldMap.person, _G.fieldMap.personArrays)
        end
    end

    -- Items: dataCache.items → JY.Thing
    if _G.dataCache and _G.dataCache.items then
        for i, rec in ipairs(_G.dataCache.items) do
            JY.Thing[rec.id] = toChineseKeys(rec, _G.fieldMap.thing, _G.fieldMap.thingArrays)
        end
    end

    -- Skills: dataCache.skills → JY.Wugong
    if _G.dataCache and _G.dataCache.skills then
        for i, rec in ipairs(_G.dataCache.skills) do
            JY.Wugong[rec.id] = toChineseKeys(rec, _G.fieldMap.skill, _G.fieldMap.skillArrays)
        end
    end

    -- Scenes: dataCache.scenes → JY.Scene
    if _G.dataCache and _G.dataCache.scenes then
        for i, rec in ipairs(_G.dataCache.scenes) do
            local cn = toChineseKeys(rec, _G.fieldMap.scene)
            cn["名称"] = rec.name
            if rec.entrance then
                cn["入口X"] = rec.entrance.mapX or 0
                cn["入口Y"] = rec.entrance.mapY or 0
                cn["外景入口X1"] = rec.entrance.mapX or 0
                cn["外景入口Y1"] = rec.entrance.mapY or 0
                cn["外景入口X2"] = rec.entrance.mapX2 or 0
                cn["外景入口Y2"] = rec.entrance.mapY2 or 0
            end
            if rec.exits and #rec.exits > 0 then
                cn["跳转场景"] = rec.exits[1].toSceneId or 0
                for j, exit in ipairs(rec.exits) do
                    if j <= 3 then
                        cn["出口X" .. j] = exit.x or 0
                        cn["出口Y" .. j] = exit.y or 0
                    end
                    if j <= 2 then
                        cn["跳转口X" .. j] = exit.targetX or 0
                        cn["跳转口Y" .. j] = exit.targetY or 0
                    end
                end
            end
            JY.Scene[rec.id] = cn
        end
    end

    -- Base: dataCache.config → JY.Base
    if _G.dataCache and _G.dataCache.config then
        local cfg = _G.dataCache.config
        JY.Base["乘船"] = (cfg.ship and cfg.ship.enabled) and 1 or 0
        JY.Base["无用"] = 0
        if cfg.my then
            JY.Base["人X"] = cfg.my.px or 0
            JY.Base["人Y"] = cfg.my.py or 0
            JY.Base["人X1"] = cfg.my.px1 or 0
            JY.Base["人Y1"] = cfg.my.py1 or 0
            JY.Base["人方向"] = cfg.my.face or 0
        end
        if cfg.ship then
            JY.Base["船X"] = cfg.ship.x or 0
            JY.Base["船Y"] = cfg.ship.y or 0
            JY.Base["船X1"] = cfg.ship.x1 or 0
            JY.Base["船Y1"] = cfg.ship.y1 or 0
            JY.Base["船方向"] = cfg.ship.face or 0
        end
        if cfg.team then
            for i = 1, 6 do
                JY.Base["队伍" .. i] = cfg.team[i] or 0
            end
        end
    end

    -- Shops: dataCache.shops → JY.Shop
    if _G.dataCache and _G.dataCache.shops then
        for i, rec in ipairs(_G.dataCache.shops) do
            local sid = rec.id or (i - 1)
            local shop = {}
            if rec.items then
                for j, item in ipairs(rec.items) do
                    if j <= 5 then
                        shop["物品" .. j] = item.id or 0
                        shop["物品数量" .. j] = item.count or 0
                        shop["物品价格" .. j] = item.price or 0
                    end
                end
            end
            JY.Shop[sid] = shop
        end
    end

    return JY
end

-- Convert string keys that look like integers back to numeric keys
-- Needed because JSON serializes Lua numeric key 0 as string key "0"
function restoreNumericKeys(tbl)
    if type(tbl) ~= "table" then return tbl end
    local result = {}
    local allNumeric = true
    for k, v in pairs(tbl) do
        local nk = tonumber(k)
        if nk and type(k) == "string" and tostring(nk) == k then
            result[nk] = restoreNumericKeys(v)
        else
            allNumeric = false
            result[k] = restoreNumericKeys(v)
        end
    end
    return result
end

-- Persistence helpers
local SAVE_KEY_PREFIX = "save_"

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

    -- Serialize to JSON (simple manual encoder to avoid dependency)
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

    -- Restore JY tables
    if not _G.JY then _G.JY = {} end
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
    return false
end

-- Simple JSON encoder for saving (handles tables with numeric + string keys)
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
                    -- Keys must be quoted in JSON
                    parts[#parts + 1] = encodeSimpleJSON(tostring(k)) .. ":" .. encodeSimpleJSON(v)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return tostring(val)
    end
end

-- Expose globals for JS bridge
_G.toChineseKeys = toChineseKeys
_G.toEnglishKeys = toEnglishKeys
_G.buildJYTables = buildJYTables
_G.saveGameState = saveGameState
_G.loadGameState = loadGameState
_G.listSaveSlots = listSaveSlots
_G.deleteSaveSlot = deleteSaveSlot
_G.encodeSimpleJSON = encodeSimpleJSON

return {
    fieldMap = _G.fieldMap,
    fieldMapCN = _G.fieldMapCN,
    toChineseKeys = toChineseKeys,
    toEnglishKeys = toEnglishKeys,
    buildJYTables = buildJYTables,
    saveGameState = saveGameState,
    loadGameState = loadGameState,
    listSaveSlots = listSaveSlots,
    deleteSaveSlot = deleteSaveSlot,
    encodeSimpleJSON = encodeSimpleJSON,
}