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
            ["代号"] = readField(grpData, offset, CC.Person_S["代号"]),
            ["姓名"] = readField(grpData, offset, CC.Person_S["姓名"]),
            ["外号"] = readField(grpData, offset, CC.Person_S["外号"]),
            ["头像代号"] = readField(grpData, offset, CC.Person_S["头像代号"]),
            ["性别"] = readField(grpData, offset, CC.Person_S["性别"]),
            ["等级"] = readField(grpData, offset, CC.Person_S["等级"]),
            ["生命增长"] = readField(grpData, offset, CC.Person_S["生命增长"]),
            ["经验"] = readField(grpData, offset, CC.Person_S["经验"]),
            ["生命"] = readField(grpData, offset, CC.Person_S["生命"]),
            ["生命最大值"] = readField(grpData, offset, CC.Person_S["生命最大值"]),
            ["内力"] = readField(grpData, offset, CC.Person_S["内力"]),
            ["内力最大值"] = readField(grpData, offset, CC.Person_S["内力最大值"]),
            ["攻击力"] = readField(grpData, offset, CC.Person_S["攻击力"]),
            ["轻功"] = readField(grpData, offset, CC.Person_S["轻功"]),
            ["防御力"] = readField(grpData, offset, CC.Person_S["防御力"]),
            ["医疗能力"] = readField(grpData, offset, CC.Person_S["医疗能力"]),
            ["用毒能力"] = readField(grpData, offset, CC.Person_S["用毒能力"]),
            ["解毒能力"] = readField(grpData, offset, CC.Person_S["解毒能力"]),
            ["抗毒能力"] = readField(grpData, offset, CC.Person_S["抗毒能力"]),
            ["拳掌功夫"] = readField(grpData, offset, CC.Person_S["拳掌功夫"]),
            ["御剑能力"] = readField(grpData, offset, CC.Person_S["御剑能力"]),
            ["耍刀技巧"] = readField(grpData, offset, CC.Person_S["耍刀技巧"]),
            ["特殊兵器"] = readField(grpData, offset, CC.Person_S["特殊兵器"]),
            ["暗器技巧"] = readField(grpData, offset, CC.Person_S["暗器技巧"]),
            ["武学常识"] = readField(grpData, offset, CC.Person_S["武学常识"]),
            ["品德"] = readField(grpData, offset, CC.Person_S["品德"]),
            ["攻击带毒"] = readField(grpData, offset, CC.Person_S["攻击带毒"]),
            ["左右互搏"] = readField(grpData, offset, CC.Person_S["左右互搏"]),
            ["声望"] = readField(grpData, offset, CC.Person_S["声望"]),
            ["资质"] = readField(grpData, offset, CC.Person_S["资质"]),
            ["受伤程度"] = readField(grpData, offset, CC.Person_S["受伤程度"]),
            ["中毒程度"] = readField(grpData, offset, CC.Person_S["中毒程度"]),
            ["体力"] = readField(grpData, offset, CC.Person_S["体力"]),
            ["内力性质"] = readField(grpData, offset, CC.Person_S["内力性质"]),
            ["物品修炼点数"] = readField(grpData, offset, CC.Person_S["物品修炼点数"]),
            ["武器"] = readField(grpData, offset, CC.Person_S["武器"]),
            ["防具"] = readField(grpData, offset, CC.Person_S["防具"]),
            ["修炼物品"] = readField(grpData, offset, CC.Person_S["修炼物品"]),
            ["修炼点数"] = readField(grpData, offset, CC.Person_S["修炼点数"]),
            ["出招动画帧数"] = attackAnimFrames,
            ["出招动画延迟"] = attackAnimDelays,
            ["武功音效延迟"] = soundDelays,
            ["武功"] = {},
            ["携带物品"] = {},
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
            ["代号"] = readField(grpData, offset, CC.Thing_S["代号"]),
            ["名称"] = readField(grpData, offset, CC.Thing_S["名称"]),
            ["名称2"] = readField(grpData, offset, CC.Thing_S["名称2"]),
            ["物品说明"] = readField(grpData, offset, CC.Thing_S["物品说明"]),
            ["练出武功"] = readField(grpData, offset, CC.Thing_S["练出武功"]),
            ["暗器动画编号"] = readField(grpData, offset, CC.Thing_S["暗器动画编号"]),
            ["使用人"] = readField(grpData, offset, CC.Thing_S["使用人"]),
            ["装备类型"] = readField(grpData, offset, CC.Thing_S["装备类型"]),
            ["显示物品说明"] = readField(grpData, offset, CC.Thing_S["显示物品说明"]),
            ["类型"] = readField(grpData, offset, CC.Thing_S["类型"]),
            ["未知5"] = readField(grpData, offset, CC.Thing_S["未知5"]),
            ["未知6"] = readField(grpData, offset, CC.Thing_S["未知6"]),
            ["未知7"] = readField(grpData, offset, CC.Thing_S["未知7"]),
            ["加生命"] = readField(grpData, offset, CC.Thing_S["加生命"]),
            ["加生命最大值"] = readField(grpData, offset, CC.Thing_S["加生命最大值"]),
            ["加中毒解毒"] = readField(grpData, offset, CC.Thing_S["加中毒解毒"]),
            ["加体力"] = readField(grpData, offset, CC.Thing_S["加体力"]),
            ["改变内力性质"] = readField(grpData, offset, CC.Thing_S["改变内力性质"]),
            ["加内力"] = readField(grpData, offset, CC.Thing_S["加内力"]),
            ["加内力最大值"] = readField(grpData, offset, CC.Thing_S["加内力最大值"]),
            ["加攻击力"] = readField(grpData, offset, CC.Thing_S["加攻击力"]),
            ["加轻功"] = readField(grpData, offset, CC.Thing_S["加轻功"]),
            ["加防御力"] = readField(grpData, offset, CC.Thing_S["加防御力"]),
            ["加医疗能力"] = readField(grpData, offset, CC.Thing_S["加医疗能力"]),
            ["加用毒能力"] = readField(grpData, offset, CC.Thing_S["加用毒能力"]),
            ["加解毒能力"] = readField(grpData, offset, CC.Thing_S["加解毒能力"]),
            ["加抗毒能力"] = readField(grpData, offset, CC.Thing_S["加抗毒能力"]),
            ["加拳掌功夫"] = readField(grpData, offset, CC.Thing_S["加拳掌功夫"]),
            ["加御剑能力"] = readField(grpData, offset, CC.Thing_S["加御剑能力"]),
            ["加耍刀技巧"] = readField(grpData, offset, CC.Thing_S["加耍刀技巧"]),
            ["加特殊兵器"] = readField(grpData, offset, CC.Thing_S["加特殊兵器"]),
            ["加暗器技巧"] = readField(grpData, offset, CC.Thing_S["加暗器技巧"]),
            ["加武学常识"] = readField(grpData, offset, CC.Thing_S["加武学常识"]),
            ["加品德"] = readField(grpData, offset, CC.Thing_S["加品德"]),
            ["加攻击次数"] = readField(grpData, offset, CC.Thing_S["加攻击次数"]),
            ["加攻击带毒"] = readField(grpData, offset, CC.Thing_S["加攻击带毒"]),
            ["仅修炼人物"] = readField(grpData, offset, CC.Thing_S["仅修炼人物"]),
            ["需内力性质"] = readField(grpData, offset, CC.Thing_S["需内力性质"]),
            ["需内力"] = readField(grpData, offset, CC.Thing_S["需内力"]),
            ["需攻击力"] = readField(grpData, offset, CC.Thing_S["需攻击力"]),
            ["需轻功"] = readField(grpData, offset, CC.Thing_S["需轻功"]),
            ["需用毒能力"] = readField(grpData, offset, CC.Thing_S["需用毒能力"]),
            ["需医疗能力"] = readField(grpData, offset, CC.Thing_S["需医疗能力"]),
            ["需解毒能力"] = readField(grpData, offset, CC.Thing_S["需解毒能力"]),
            ["需拳掌功夫"] = readField(grpData, offset, CC.Thing_S["需拳掌功夫"]),
            ["需御剑能力"] = readField(grpData, offset, CC.Thing_S["需御剑能力"]),
            ["需耍刀技巧"] = readField(grpData, offset, CC.Thing_S["需耍刀技巧"]),
            ["需特殊兵器"] = readField(grpData, offset, CC.Thing_S["需特殊兵器"]),
            ["需暗器技巧"] = readField(grpData, offset, CC.Thing_S["需暗器技巧"]),
            ["需资质"] = readField(grpData, offset, CC.Thing_S["需资质"]),
            ["需经验"] = readField(grpData, offset, CC.Thing_S["需经验"]),
            ["练出物品需经验"] = readField(grpData, offset, CC.Thing_S["练出物品需经验"]),
            ["需材料"] = readField(grpData, offset, CC.Thing_S["需材料"]),
            ["练出物品"] = craftItems,
            ["需要物品数量"] = craftCounts,
            ["效果"] = {},
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
            ["代号"] = readField(grpData, offset, CC.Wugong_S["代号"]),
            ["名称"] = readField(grpData, offset, CC.Wugong_S["名称"]),
            ["未知1"] = readField(grpData, offset, CC.Wugong_S["未知1"]),
            ["未知2"] = readField(grpData, offset, CC.Wugong_S["未知2"]),
            ["未知3"] = readField(grpData, offset, CC.Wugong_S["未知3"]),
            ["未知4"] = readField(grpData, offset, CC.Wugong_S["未知4"]),
            ["未知5"] = readField(grpData, offset, CC.Wugong_S["未知5"]),
            ["出招音效"] = readField(grpData, offset, CC.Wugong_S["出招音效"]),
            ["武功类型"] = readField(grpData, offset, CC.Wugong_S["武功类型"]),
            ["武功动画&音效"] = readField(grpData, offset, CC.Wugong_S["武功动画&音效"]),
            ["伤害类型"] = readField(grpData, offset, CC.Wugong_S["伤害类型"]),
            ["攻击范围"] = readField(grpData, offset, CC.Wugong_S["攻击范围"]),
            ["消耗内力点数"] = readField(grpData, offset, CC.Wugong_S["消耗内力点数"]),
            ["敌人中毒点数"] = readField(grpData, offset, CC.Wugong_S["敌人中毒点数"]),
            ["攻击力"] = powers,
            ["移动范围"] = moveRange,
            ["杀伤范围"] = damageRange,
            ["加内力"] = addMp,
            ["杀内力"] = killMp,
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
                p["武功"][#p["武功"] + 1] = { ["代号"] = sid, ["等级"] = slvl }
            end
        end

        for ii = 1, 4 do
            local itemKey = "携带物品" .. ii
            local countKey = "携带物品数量" .. ii
            local iid = readField(grpData, personBase + i * CC.PersonSize, CC.Person_S[itemKey])
            if iid and iid > 0 then
                local icount = readField(grpData, personBase + i * CC.PersonSize, CC.Person_S[countKey])
                p["携带物品"][#p["携带物品"] + 1] = { ["代号"] = iid, ["数量"] = icount }
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

    local charEntries = {}
    for i = 0, personNum - 1 do
        charEntries[#charEntries + 1] = chars[i]
    end

    local itemEntries = {}
    for i = 0, thingNum - 1 do
        itemEntries[#itemEntries + 1] = items[i]
    end

    local skillEntries = {}
    for i = 0, wugongNum - 1 do
        skillEntries[#skillEntries + 1] = skills[i]
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
