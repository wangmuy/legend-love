local function readFile(path)
    local file = io.open(path, "rb")
    if not file then error("Cannot open " .. path) end
    local data = file:read("*a")
    file:close()
    return data
end

local function readIdx(path)
    local data = readFile(path)
    local offsets = {}
    offsets[0] = 0
    for i = 1, #data, 4 do
        local b1, b2, b3, b4 = data:byte(i, i + 3)
        offsets[#offsets + 1] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end
    return offsets
end

local function trim(str)
    return str:match("^[%z ]*(.-)[%z ]*$") or ""
end

local function escapeJSON(str)
    local result = str:gsub("\\", "\\\\")
    result = result:gsub('"', '\\"')
    result = result:gsub("\n", "\\n")
    result = result:gsub("\r", "\\r")
    result = result:gsub("\t", "\\t")
    return result
end

local function get16(data, offset)
    local idx = offset + 1
    local b1 = data:byte(idx) or 0
    local b2 = data:byte(idx + 1) or 0
    local n = b1 + b2 * 256
    return n > 32767 and n - 65536 or n
end

local function getu16(data, offset)
    local idx = offset + 1
    local b1 = data:byte(idx) or 0
    local b2 = data:byte(idx + 1) or 0
    return b1 + b2 * 256
end

local function getstr(data, offset, length)
    local idx = offset + 1
    local bytes = {}
    for i = 0, length - 1 do
        local c = data:byte(idx + i)
        if not c or c == 0 then break end
        bytes[#bytes + 1] = string.char(c)
    end
    return table.concat(bytes, "")
end

local function readField(data, baseOffset, fieldDef)
    local offset, ftype, length = fieldDef[1], fieldDef[2], fieldDef[3]
    if ftype == 2 then
        return trim(getstr(data, baseOffset + offset, length))
    elseif ftype == 1 then
        return getu16(data, baseOffset + offset)
    else
        return get16(data, baseOffset + offset)
    end
end

local function writeJSON(path, content)
    local outFile = io.open(path, "w")
    if not outFile then
        os.execute("mkdir -p engine-web/data-web")
        outFile = io.open(path, "w")
    end
    outFile:write(content)
    outFile:close()
    print("Wrote " .. path)
end

local function main()
    CONFIG = {
        Debug = 0, Width = 1024, Height = 768, Type = 1, Rotate = 0,
        XScale = 18, YScale = 9,
        DataPath = "data/", PicturePath = "pic/", SoundPath = "sound/",
        ScriptPath = "script/", FontName = "simsun.ttf",
        FastShowScreen = 0,
    }
    dofile("script/jyconst.lua")
    SetGlobalConst()

    print("Reading ranger.idx ...")
    local idx = readIdx("data/ranger.idx")
    print("  idx[0]=" .. idx[0] .. " idx[1]=" .. idx[1] .. " idx[2]=" .. idx[2] ..
          " idx[3]=" .. idx[3] .. " idx[4]=" .. idx[4] .. " idx[5]=" .. idx[5])

    local grpData = readFile("data/ranger.grp")
    print("  ranger.grp size: " .. #grpData .. " bytes")

    local personNum = math.floor((idx[2] - idx[1]) / CC.PersonSize)
    local thingNum = math.floor((idx[3] - idx[2]) / CC.ThingSize)
    local sceneNum = math.floor((idx[4] - idx[3]) / CC.SceneSize)
    local wugongNum = math.floor((idx[5] - idx[4]) / CC.WugongSize)
    print("  PersonNum=" .. personNum .. " ThingNum=" .. thingNum ..
          " SceneNum=" .. sceneNum .. " WugongNum=" .. wugongNum)

    local personBase = idx[1]
    local thingBase = idx[2]
    local sceneBase = idx[3]
    local wugongBase = idx[4]

    local function extractPerson(i)
        local offset = personBase + i * CC.PersonSize
        local attackAnimFrames = {}
        local attackAnimDelays = {}
        local soundDelays = {}
        for ai = 1, 5 do
            attackAnimFrames[ai] = readField(grpData, offset, CC.Person_S["出招动画帧数" .. ai])
            attackAnimDelays[ai] = readField(grpData, offset, CC.Person_S["出招动画延迟" .. ai])
            soundDelays[ai] = readField(grpData, offset, CC.Person_S["武功音效延迟" .. ai])
        end
        return {
            id = readField(grpData, offset, CC.Person_S["代号"]),
            name = readField(grpData, offset, CC.Person_S["姓名"]),
            title = readField(grpData, offset, CC.Person_S["外号"]),
            headId = readField(grpData, offset, CC.Person_S["头像代号"]),
            sex = readField(grpData, offset, CC.Person_S["性别"]),
            level = readField(grpData, offset, CC.Person_S["等级"]),
            hpGrowth = readField(grpData, offset, CC.Person_S["生命增长"]),
            exp = readField(grpData, offset, CC.Person_S["经验"]),
            hp = readField(grpData, offset, CC.Person_S["生命"]),
            maxHp = readField(grpData, offset, CC.Person_S["生命最大值"]),
            mp = readField(grpData, offset, CC.Person_S["内力"]),
            maxMp = readField(grpData, offset, CC.Person_S["内力最大值"]),
            attack = readField(grpData, offset, CC.Person_S["攻击力"]),
            speed = readField(grpData, offset, CC.Person_S["轻功"]),
            defence = readField(grpData, offset, CC.Person_S["防御力"]),
            medical = readField(grpData, offset, CC.Person_S["医疗能力"]),
            poison = readField(grpData, offset, CC.Person_S["用毒能力"]),
            antiPoison = readField(grpData, offset, CC.Person_S["解毒能力"]),
            antiPoisonResist = readField(grpData, offset, CC.Person_S["抗毒能力"]),
            fist = readField(grpData, offset, CC.Person_S["拳掌功夫"]),
            sword = readField(grpData, offset, CC.Person_S["御剑能力"]),
            blade = readField(grpData, offset, CC.Person_S["耍刀技巧"]),
            special = readField(grpData, offset, CC.Person_S["特殊兵器"]),
            hidden = readField(grpData, offset, CC.Person_S["暗器技巧"]),
            martialKnowledge = readField(grpData, offset, CC.Person_S["武学常识"]),
            morality = readField(grpData, offset, CC.Person_S["品德"]),
            poisonAttack = readField(grpData, offset, CC.Person_S["攻击带毒"]),
            doubleAttack = readField(grpData, offset, CC.Person_S["左右互搏"]),
            fame = readField(grpData, offset, CC.Person_S["声望"]),
            aptitude = readField(grpData, offset, CC.Person_S["资质"]),
            wounded = readField(grpData, offset, CC.Person_S["受伤程度"]),
            poisoned = readField(grpData, offset, CC.Person_S["中毒程度"]),
            stamina = readField(grpData, offset, CC.Person_S["体力"]),
            innerType = readField(grpData, offset, CC.Person_S["内力性质"]),
            practicePoints = readField(grpData, offset, CC.Person_S["物品修炼点数"]),
            weapon = readField(grpData, offset, CC.Person_S["武器"]),
            armour = readField(grpData, offset, CC.Person_S["防具"]),
            trainingItem = readField(grpData, offset, CC.Person_S["修炼物品"]),
            trainingPoints = readField(grpData, offset, CC.Person_S["修炼点数"]),
            attackAnimFrames = attackAnimFrames,
            attackAnimDelays = attackAnimDelays,
            soundDelays = soundDelays,
            skills = {},
            items = {},
        }
    end

    local function extractThing(i)
        local offset = thingBase + i * CC.ThingSize
        local craftItems = {}
        local craftCounts = {}
        for ci = 1, 5 do
            craftItems[ci] = readField(grpData, offset, CC.Thing_S["练出物品" .. ci])
            craftCounts[ci] = readField(grpData, offset, CC.Thing_S["需要物品数量" .. ci])
        end
        return {
            id = readField(grpData, offset, CC.Thing_S["代号"]),
            name = readField(grpData, offset, CC.Thing_S["名称"]),
            name2 = readField(grpData, offset, CC.Thing_S["名称2"]),
            desc = readField(grpData, offset, CC.Thing_S["物品说明"]),
            learnedSkill = readField(grpData, offset, CC.Thing_S["练出武功"]),
            throwAnim = readField(grpData, offset, CC.Thing_S["暗器动画编号"]),
            user = readField(grpData, offset, CC.Thing_S["使用人"]),
            equipType = readField(grpData, offset, CC.Thing_S["装备类型"]),
            displayDesc = readField(grpData, offset, CC.Thing_S["显示物品说明"]),
            itemType = readField(grpData, offset, CC.Thing_S["类型"]),
            unknown5 = readField(grpData, offset, CC.Thing_S["未知5"]),
            unknown6 = readField(grpData, offset, CC.Thing_S["未知6"]),
            unknown7 = readField(grpData, offset, CC.Thing_S["未知7"]),
            addHp = readField(grpData, offset, CC.Thing_S["加生命"]),
            addMaxHp = readField(grpData, offset, CC.Thing_S["加生命最大值"]),
            addPoison = readField(grpData, offset, CC.Thing_S["加中毒解毒"]),
            addStamina = readField(grpData, offset, CC.Thing_S["加体力"]),
            changeInnerType = readField(grpData, offset, CC.Thing_S["改变内力性质"]),
            addMp = readField(grpData, offset, CC.Thing_S["加内力"]),
            addMaxMp = readField(grpData, offset, CC.Thing_S["加内力最大值"]),
            addAttack = readField(grpData, offset, CC.Thing_S["加攻击力"]),
            addSpeed = readField(grpData, offset, CC.Thing_S["加轻功"]),
            addDefence = readField(grpData, offset, CC.Thing_S["加防御力"]),
            addMedical = readField(grpData, offset, CC.Thing_S["加医疗能力"]),
            addPoisonSkill = readField(grpData, offset, CC.Thing_S["加用毒能力"]),
            addAntiPoison = readField(grpData, offset, CC.Thing_S["加解毒能力"]),
            addAntiPoisonResist = readField(grpData, offset, CC.Thing_S["加抗毒能力"]),
            addFist = readField(grpData, offset, CC.Thing_S["加拳掌功夫"]),
            addSword = readField(grpData, offset, CC.Thing_S["加御剑能力"]),
            addBlade = readField(grpData, offset, CC.Thing_S["加耍刀技巧"]),
            addSpecial = readField(grpData, offset, CC.Thing_S["加特殊兵器"]),
            addHidden = readField(grpData, offset, CC.Thing_S["加暗器技巧"]),
            addMartialKnowledge = readField(grpData, offset, CC.Thing_S["加武学常识"]),
            addMorality = readField(grpData, offset, CC.Thing_S["加品德"]),
            addAttackCount = readField(grpData, offset, CC.Thing_S["加攻击次数"]),
            addPoisonAttack = readField(grpData, offset, CC.Thing_S["加攻击带毒"]),
            practiceUser = readField(grpData, offset, CC.Thing_S["仅修炼人物"]),
            needInnerType = readField(grpData, offset, CC.Thing_S["需内力性质"]),
            needMp = readField(grpData, offset, CC.Thing_S["需内力"]),
            needAttack = readField(grpData, offset, CC.Thing_S["需攻击力"]),
            needSpeed = readField(grpData, offset, CC.Thing_S["需轻功"]),
            needPoisonSkill = readField(grpData, offset, CC.Thing_S["需用毒能力"]),
            needMedical = readField(grpData, offset, CC.Thing_S["需医疗能力"]),
            needAntiPoison = readField(grpData, offset, CC.Thing_S["需解毒能力"]),
            needFist = readField(grpData, offset, CC.Thing_S["需拳掌功夫"]),
            needSword = readField(grpData, offset, CC.Thing_S["需御剑能力"]),
            needBlade = readField(grpData, offset, CC.Thing_S["需耍刀技巧"]),
            needSpecial = readField(grpData, offset, CC.Thing_S["需特殊兵器"]),
            needHidden = readField(grpData, offset, CC.Thing_S["需暗器技巧"]),
            needAptitude = readField(grpData, offset, CC.Thing_S["需资质"]),
            needExp = readField(grpData, offset, CC.Thing_S["需经验"]),
            craftNeedExp = readField(grpData, offset, CC.Thing_S["练出物品需经验"]),
            needMaterial = readField(grpData, offset, CC.Thing_S["需材料"]),
            craftItems = craftItems,
            craftCounts = craftCounts,
            effect = {},
        }
    end

    local function extractWugong(i)
        local offset = wugongBase + i * CC.WugongSize
        local powers = {}
        local moveRange = {}
        local damageRange = {}
        local addMp = {}
        local killMp = {}
        for lvl = 1, 10 do
            local key = "攻击力" .. lvl
            if CC.Wugong_S[key] then
                powers[lvl] = readField(grpData, offset, CC.Wugong_S[key])
            end
            moveRange[lvl] = readField(grpData, offset, CC.Wugong_S["移动范围" .. lvl])
            damageRange[lvl] = readField(grpData, offset, CC.Wugong_S["杀伤范围" .. lvl])
            addMp[lvl] = readField(grpData, offset, CC.Wugong_S["加内力" .. lvl])
            killMp[lvl] = readField(grpData, offset, CC.Wugong_S["杀内力" .. lvl])
        end
        return {
            id = readField(grpData, offset, CC.Wugong_S["代号"]),
            name = readField(grpData, offset, CC.Wugong_S["名称"]),
            unknown1 = readField(grpData, offset, CC.Wugong_S["未知1"]),
            unknown2 = readField(grpData, offset, CC.Wugong_S["未知2"]),
            unknown3 = readField(grpData, offset, CC.Wugong_S["未知3"]),
            unknown4 = readField(grpData, offset, CC.Wugong_S["未知4"]),
            unknown5 = readField(grpData, offset, CC.Wugong_S["未知5"]),
            soundEffect = readField(grpData, offset, CC.Wugong_S["出招音效"]),
            skillType = readField(grpData, offset, CC.Wugong_S["武功类型"]),
            animEffect = readField(grpData, offset, CC.Wugong_S["武功动画&音效"]),
            damageType = readField(grpData, offset, CC.Wugong_S["伤害类型"]),
            range = readField(grpData, offset, CC.Wugong_S["攻击范围"]),
            mpCost = readField(grpData, offset, CC.Wugong_S["消耗内力点数"]),
            poison = readField(grpData, offset, CC.Wugong_S["敌人中毒点数"]),
            powers = powers,
            moveRange = moveRange,
            damageRange = damageRange,
            addMp = addMp,
            killMp = killMp,
        }
    end

    print("Extracting persons ...")
    local chars = {}
    for i = 0, personNum - 1 do
        local p = extractPerson(i)

        for si = 1, 10 do
            local skillKey = "武功" .. si
            local levelKey = "武功等级" .. si
            local sid = readField(grpData, personBase + i * CC.PersonSize, CC.Person_S[skillKey])
            if sid and sid > 0 then
                local slvl = readField(grpData, personBase + i * CC.PersonSize, CC.Person_S[levelKey])
                p.skills[#p.skills + 1] = { id = sid, level = slvl }
            end
        end

        for ii = 1, 4 do
            local itemKey = "携带物品" .. ii
            local countKey = "携带物品数量" .. ii
            local iid = readField(grpData, personBase + i * CC.PersonSize, CC.Person_S[itemKey])
            if iid and iid > 0 then
                local icount = readField(grpData, personBase + i * CC.PersonSize, CC.Person_S[countKey])
                p.items[#p.items + 1] = { id = iid, count = icount }
            end
        end

        chars[i] = p
    end
    print("  Extracted " .. personNum .. " persons")

    print("Extracting items ...")
    local items = {}
    for i = 0, thingNum - 1 do
        items[i] = extractThing(i)
    end
    print("  Extracted " .. thingNum .. " items")

    print("Extracting skills ...")
    local skills = {}
    for i = 0, wugongNum - 1 do
        skills[i] = extractWugong(i)
    end
    print("  Extracted " .. wugongNum .. " skills")

    local jsonTable

    local function jsonVal(v)
        if type(v) == "string" then
            return '"' .. escapeJSON(v) .. '"'
        elseif type(v) == "table" then
            return jsonTable(v)
        else
            return tostring(v)
        end
    end

    jsonTable = function(t, indent)
        indent = indent or 2
        local pad = string.rep(" ", indent)
        local closePad = string.rep(" ", indent - 2)

        local isArray = true
        local maxKey = -1
        for k, _ in pairs(t) do
            if type(k) ~= "number" or k ~= math.floor(k) then
                isArray = false
                break
            end
            if k > maxKey then maxKey = k end
        end
        if isArray and maxKey ~= #t then
            isArray = false
        end

        local lines = {}
        if isArray then
            lines[#lines + 1] = "["
            local entries = {}
            for i = 1, #t do
                entries[#entries + 1] = pad .. jsonVal(t[i])
            end
            lines[#lines + 1] = table.concat(entries, ",\n")
            lines[#lines + 1] = closePad .. "]"
        else
            lines[#lines + 1] = "{"
            local entries = {}
            local keys = {}
            for k, _ in pairs(t) do
                keys[#keys + 1] = k
            end
            table.sort(keys, function(a, b)
                if type(a) == "number" and type(b) == "number" then return a < b end
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                local v = t[k]
                if type(v) == "table" and next(v) == nil then
                    local keyStr
                    if type(k) == "number" then
                        keyStr = '"' .. k .. '"'
                    else
                        keyStr = '"' .. escapeJSON(tostring(k)) .. '"'
                    end
                    entries[#entries + 1] = pad .. keyStr .. ": {}"
                else
                    local keyStr
                    if type(k) == "number" then
                        keyStr = '"' .. k .. '"'
                    else
                        keyStr = '"' .. escapeJSON(tostring(k)) .. '"'
                    end
                    entries[#entries + 1] = pad .. keyStr .. ": " .. jsonVal(v, indent + 2)
                end
            end
            lines[#lines + 1] = table.concat(entries, ",\n")
            lines[#lines + 1] = closePad .. "}"
        end
        return table.concat(lines, "\n")
    end

    local function buildCharEntry(p)
        local entry = {
            id = p.id,
            name = p.name,
            title = p.title,
            headId = p.headId,
            sex = p.sex,
            level = p.level,
            hpGrowth = p.hpGrowth,
            exp = p.exp,
            hp = p.hp,
            maxHp = p.maxHp,
            mp = p.mp,
            maxMp = p.maxMp,
            attack = p.attack,
            speed = p.speed,
            defence = p.defence,
            medical = p.medical,
            poison = p.poison,
            antiPoison = p.antiPoison,
            antiPoisonResist = p.antiPoisonResist,
            fist = p.fist,
            sword = p.sword,
            blade = p.blade,
            special = p.special,
            hidden = p.hidden,
            martialKnowledge = p.martialKnowledge,
            morality = p.morality,
            poisonAttack = p.poisonAttack,
            doubleAttack = p.doubleAttack,
            fame = p.fame,
            aptitude = p.aptitude,
            wounded = p.wounded,
            poisoned = p.poisoned,
            stamina = p.stamina,
            innerType = p.innerType,
            practicePoints = p.practicePoints,
            weapon = p.weapon,
            armour = p.armour,
            trainingItem = p.trainingItem,
            trainingPoints = p.trainingPoints,
            attackAnimFrames = p.attackAnimFrames,
            attackAnimDelays = p.attackAnimDelays,
            soundDelays = p.soundDelays,
        }
        local skillArr = {}
        for _, s in ipairs(p.skills) do
            skillArr[#skillArr + 1] = s
        end
        entry.skills = skillArr
        local itemArr = {}
        for _, it in ipairs(p.items) do
            itemArr[#itemArr + 1] = it
        end
        entry.items = itemArr
        return entry
    end

    local function buildItemEntry(it)
        local entry = {
            id = it.id,
            name = it.name,
            name2 = it.name2,
            desc = it.desc,
            learnedSkill = it.learnedSkill,
            throwAnim = it.throwAnim,
            user = it.user,
            itemType = it.itemType,
            equipType = it.equipType,
            displayDesc = it.displayDesc,
            unknown5 = it.unknown5,
            unknown6 = it.unknown6,
            unknown7 = it.unknown7,
            addHp = it.addHp,
            addMaxHp = it.addMaxHp,
            addPoison = it.addPoison,
            addStamina = it.addStamina,
            changeInnerType = it.changeInnerType,
            addMp = it.addMp,
            addMaxMp = it.addMaxMp,
            addAttack = it.addAttack,
            addSpeed = it.addSpeed,
            addDefence = it.addDefence,
            addMedical = it.addMedical,
            addPoisonSkill = it.addPoisonSkill,
            addAntiPoison = it.addAntiPoison,
            addAntiPoisonResist = it.addAntiPoisonResist,
            addFist = it.addFist,
            addSword = it.addSword,
            addBlade = it.addBlade,
            addSpecial = it.addSpecial,
            addHidden = it.addHidden,
            addMartialKnowledge = it.addMartialKnowledge,
            addMorality = it.addMorality,
            addAttackCount = it.addAttackCount,
            addPoisonAttack = it.addPoisonAttack,
            practiceUser = it.practiceUser,
            needInnerType = it.needInnerType,
            needMp = it.needMp,
            needAttack = it.needAttack,
            needSpeed = it.needSpeed,
            needPoisonSkill = it.needPoisonSkill,
            needMedical = it.needMedical,
            needAntiPoison = it.needAntiPoison,
            needFist = it.needFist,
            needSword = it.needSword,
            needBlade = it.needBlade,
            needSpecial = it.needSpecial,
            needHidden = it.needHidden,
            needAptitude = it.needAptitude,
            needExp = it.needExp,
            craftNeedExp = it.craftNeedExp,
            needMaterial = it.needMaterial,
            craftItems = it.craftItems,
            craftCounts = it.craftCounts,
        }
        return entry
    end

    local function buildSkillEntry(sk)
        local entry = {
            id = sk.id,
            name = sk.name,
            unknown1 = sk.unknown1,
            unknown2 = sk.unknown2,
            unknown3 = sk.unknown3,
            unknown4 = sk.unknown4,
            unknown5 = sk.unknown5,
            soundEffect = sk.soundEffect,
            skillType = sk.skillType,
            animEffect = sk.animEffect,
            damageType = sk.damageType,
            range = sk.range,
            mpCost = sk.mpCost,
            poison = sk.poison,
        }
        if sk.powers and next(sk.powers) then
            local p = {}
            for i, v in ipairs(sk.powers) do
                p[i] = v
            end
            entry.powers = p
        end
        if sk.moveRange and next(sk.moveRange) then
            local mr = {}
            for i, v in ipairs(sk.moveRange) do
                mr[i] = v
            end
            entry.moveRange = mr
        end
        if sk.damageRange and next(sk.damageRange) then
            local dr = {}
            for i, v in ipairs(sk.damageRange) do
                dr[i] = v
            end
            entry.damageRange = dr
        end
        if sk.addMp and next(sk.addMp) then
            local am = {}
            for i, v in ipairs(sk.addMp) do
                am[i] = v
            end
            entry.addMp = am
        end
        if sk.killMp and next(sk.killMp) then
            local km = {}
            for i, v in ipairs(sk.killMp) do
                km[i] = v
            end
            entry.killMp = km
        end
        return entry
    end

    local charEntries = {}
    for i = 0, personNum - 1 do
        charEntries[#charEntries + 1] = buildCharEntry(chars[i])
    end

    local itemEntries = {}
    for i = 0, thingNum - 1 do
        itemEntries[#itemEntries + 1] = buildItemEntry(items[i])
    end

    local skillEntries = {}
    for i = 0, wugongNum - 1 do
        skillEntries[#skillEntries + 1] = buildSkillEntry(skills[i])
    end

    local dateStr = os.date("%Y-%m-%d")
    local dateStrEscaped = escapeJSON(dateStr)

    local charsJson = '{\n' ..
        '  "version": "1.0",\n' ..
        '  "extracted": "' .. dateStrEscaped .. '",\n' ..
        '  "total": ' .. personNum .. ',\n' ..
        '  "chars": ' .. jsonTable(charEntries) .. '\n' ..
        '}'
    writeJSON("engine-web/data-web/chars.json", charsJson)

    local itemsJson = '{\n' ..
        '  "version": "1.0",\n' ..
        '  "extracted": "' .. dateStrEscaped .. '",\n' ..
        '  "total": ' .. thingNum .. ',\n' ..
        '  "items": ' .. jsonTable(itemEntries) .. '\n' ..
        '}'
    writeJSON("engine-web/data-web/items.json", itemsJson)

    local skillsJson = '{\n' ..
        '  "version": "1.0",\n' ..
        '  "extracted": "' .. dateStrEscaped .. '",\n' ..
        '  "total": ' .. wugongNum .. ',\n' ..
        '  "skills": ' .. jsonTable(skillEntries) .. '\n' ..
        '}'
    writeJSON("engine-web/data-web/skills.json", skillsJson)

    print("Done.")
end

main()
