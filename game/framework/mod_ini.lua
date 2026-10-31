-- mod_ini.lua
-- kysmod.ini 解析器与 CONFIG/CC 覆盖映射（allmods-ini-parser，Contract A）
--
-- 设计要点：
--   * 纯解析模块，不依赖引擎（framework 层，可被 engine_test / MUD 复用）
--   * 容错：缺失段/缺失键/未知键/typo 键名均不报错
--   * typo 键名（如 mingdong 的 SCENCEAMI）在映射表中显式登记
--
-- API:
--   ModIni.Load(path)   -> { CONFIG = {...}, CC = {...}, unknown = {...}, raw = {...} }
--   ModIni.Apply(parsed) -> nil   把覆盖写入全局 CONFIG / CC
--   ModIni.ParseText(text) -> 同上（便于测试，不读文件）
--   ModIni.Mapping()     -> 映射表只读副本

local ModIni = {}

-- ============================================================
-- 默认 IO 适配（可在测试中替换 ModIni.readFile）
-- ============================================================

-- 读取文本文件内容；失败返回 nil, err
function ModIni.readFile(path)
    local f, err = io.open(path, "rb")
    if not f then
        return nil, err or ("cannot open " .. tostring(path))
    end
    local content = f:read("*a")
    f:close()
    return content
end

-- ============================================================
-- 键名映射表
--
-- 结构: SECTION_MAP[section][ini_key_lowercase] = { target = "CONFIG"|"CC", key = "..." }
--   * 同一 ini 键可映射到多个目标（用数组形式: { {"CONFIG","Width"}, {"CC","ScreenW"} }）
--   * 值统一为字符串；数值转换由数值型白名单 NUMERIC_KEYS 决定
--   * 大小写不敏感（查表前 lowercase）
-- ============================================================

-- 数值型键（映射后做 tonumber 转换）。其余保持字符串。
local NUMERIC_KEYS = {
    -- CONFIG
    ["CONFIG.Width"] = true,
    ["CONFIG.Height"] = true,
    ["CONFIG.MasterVolume"] = true,
    ["CONFIG.SoundVolume"] = true,
    ["CONFIG.KeyRepeatDelay"] = true,
    ["CONFIG.KeyRepeatInterval"] = true,
    -- CC（数值）
    ["CC.ScreenW"] = true,
    ["CC.ScreenH"] = true,
    ["CC.MyThingNum"] = true,
    ["CC.NewGameSceneID"] = true,
    ["CC.NewGameSceneX"] = true,
    ["CC.NewGameSceneY"] = true,
    ["CC.NewGameEvent"] = true,
    ["CC.SoftStarBeginTalk"] = true,
    ["CC.SoftStarNumTalk"] = true,
    ["CC.MaxPhysicalPower"] = true,
    ["CC.MoneyID"] = true,
    ["CC.CompassID"] = true,
    ["CC.BeginLeaveEvent"] = true,
    ["CC.BeginBattleRolePic"] = true,
    ["CC.MaxLevel"] = true,
    ["CC.MaxWeaponMatch"] = true,
    ["CC.MinKnowledge"] = true,
    ["CC.MaxItemAmount"] = true,
    ["CC.LifeHurt"] = true,
    ["CC.MaxHP"] = true,
    ["CC.MaxMP"] = true,
    ["CC.PoisonHurt"] = true,
    ["CC.MaxAddPro"] = true,
    ["CC.WalkSpeed"] = true,
    ["CC.WalkSpeed2"] = true,
    ["CC.BattleSpeed"] = true,
    ["CC.Smooth"] = true,
    ["CC.Glhr"] = true,
    ["CC.MMapAmi"] = true,
    ["CC.SceneAmi"] = true,
    ["CC.SemiReal"] = true,
    ["CC.KdefScript"] = true,
    ["CC.Simple"] = true,
    ["CC.ExpandGround"] = true,
    ["CC.ExitGame"] = true,
    ["CC.NightEffect"] = true,
    ["CC.WMP4Pic"] = true,
    ["CC.HiresText"] = true,
    ["CC.Renderer"] = true,
    ["CC.MODVersion"] = true,
    ["CC.ExpRate"] = true,
    ["CC.ItemBeginPic"] = true,
    ["CC.ChineseFontSize"] = true,
    ["CC.EnglishFontSize"] = true,
    ["CC.VirtualCrossX"] = true,
    ["CC.VirtualCrossY"] = true,
    ["CC.VirtualAX"] = true,
    ["CC.VirtualAY"] = true,
    ["CC.VirtualBX"] = true,
    ["CC.VirtualBY"] = true,
}

-- 不可为负的数值键：负数表示“未设置”，而引擎会直接用该值索引数组
-- （如 JY.Scene[CC.NewGameSceneID]）。若照搬会崩溃，因此保持引擎默认值。
-- 数据驱动：只按“值为负”判定，与 MOD 名无关。
local NON_NEGATIVE_KEYS = {
    ["CC.NewGameSceneID"] = true,
    ["CC.NewGameEvent"]   = true,
    ["CC.SoftStarBeginTalk"] = true,
    ["CC.BeginLeaveEvent"]   = true,
}

local function isNumericKey(qualified)
    if NUMERIC_KEYS[qualified] then return true end
    -- 动态: CC.MaxProList43..58
    return qualified:match("^CC%.MaxProList%d+$") ~= nil
end

-- 映射表：section(lower) -> key(lower) -> { {target,key}, ... }
local SECTION_MAP = {
    system = {
        -- RESOLUTIONX/Y 不映射：
        -- 原版 C 引擎（base 分支）从不读 kysmod.ini，窗口尺寸只来自 config.lua
        -- 的 CONFIG.Width/Height（1024x768）。kysmod.ini 的 RESOLUTIONX/Y
        -- 是 AllMod-Launcher.exe（独立 Windows 启动器）的窗口提示，与游戏逻辑无关。
        -- 映射到 CONFIG.Width/Height 会把窗口缩到 640x440，属错误适配。
        -- 详见 openspec/changes/allmods-ini-parser/reports/resolution-mapping.md
        volume        = { {"CONFIG", "MasterVolume"} },
        -- 兼容拼写变体
        volume2       = { {"CONFIG", "MasterVolume"} },
        volumewav     = { {"CONFIG", "SoundVolume"} },
        -- 走路/战斗速度
        walk_speed    = { {"CC", "WalkSpeed"} },
        walk_speed2   = { {"CC", "WalkSpeed2"} },
        battle_speed  = { {"CC", "BattleSpeed"} },
        -- 开关
        smooth        = { {"CC", "Smooth"} },
        glhr          = { {"CC", "Glhr"} },
        mmapami       = { {"CC", "MMapAmi"} },
        -- 注意: 两个 MOD 拼写不同（mingdong=SCENCEAMI，其余=SCENEAMI），均显式登记
        sceneami      = { {"CC", "SceneAmi"} },
        scenceami     = { {"CC", "SceneAmi"} },
        semireal      = { {"CC", "SemiReal"} },
        kdef_script   = { {"CC", "KdefScript"} },
        simple        = { {"CC", "Simple"} },
        expand_ground = { {"CC", "ExpandGround"} },
        exit_game     = { {"CC", "ExitGame"} },
        night_effect  = { {"CC", "NightEffect"} },
        wmp_4_pic     = { {"CC", "WMP4Pic"} },
        hires_text    = { {"CC", "HiresText"} },
        renderer      = { {"CC", "Renderer"} },
        exp_rate      = { {"CC", "ExpRate"} },
        modversion    = { {"CC", "MODVersion"} },
        chinese_font_size = { {"CC", "ChineseFontSize"} },
        english_font_size = { {"CC", "EnglishFontSize"} },
        virtualcrossx = { {"CC", "VirtualCrossX"} },
        virtualcrossy = { {"CC", "VirtualCrossY"} },
        virtualax     = { {"CC", "VirtualAX"} },
        virtualay     = { {"CC", "VirtualAY"} },
        virtualbx     = { {"CC", "VirtualBX"} },
        virtualby     = { {"CC", "VirtualBY"} },
    },
    music = {
        volume    = { {"CONFIG", "MasterVolume"} },
        volumewav = { {"CONFIG", "SoundVolume"} },
    },
    constant = {
        -- 新游戏入口
        begin_scene        = { {"CC", "NewGameSceneID"} },
        begin_scence       = { {"CC", "NewGameSceneID"} },  -- 拼写变体
        begin_sx           = { {"CC", "NewGameSceneY"} },    -- 原版 x/y 与 love2d 相反
        begin_sy           = { {"CC", "NewGameSceneX"} },
        begin_event        = { {"CC", "NewGameEvent"} },
        -- 软体娃娃对话
        softstar_begin_talk = { {"CC", "SoftStarBeginTalk"} },
        softstar_num_talk   = { {"CC", "SoftStarNumTalk"} },
        -- 战斗/人物
        begin_battle_role_pic = { {"CC", "BeginBattleRolePic"} },
        begin_leave_event     = { {"CC", "BeginLeaveEvent"} },
        max_physical_power    = { {"CC", "MaxPhysicalPower"} },
        money_id              = { {"CC", "MoneyID"} },
        compass_id            = { {"CC", "CompassID"} },
        max_level             = { {"CC", "MaxLevel"} },
        max_weapon_match      = { {"CC", "MaxWeaponMatch"} },
        min_knowledge         = { {"CC", "MinKnowledge"} },
        max_item_amount       = { {"CC", "MaxItemAmount"}, {"CC", "MyThingNum"} },
        life_hurt             = { {"CC", "LifeHurt"} },
        max_hp                = { {"CC", "MaxHP"} },
        max_mp                = { {"CC", "MaxMP"} },
        poison_hurt           = { {"CC", "PoisonHurt"} },
        max_add_pro           = { {"CC", "MaxAddPro"} },
        item_begin_pic        = { {"CC", "ItemBeginPic"} },
        -- MaxProList43..58 → CC.MaxProList43..58（逐键动态处理，见 lookup）
    },
}

-- 返回映射表只读副本（供测试/文档）
function ModIni.Mapping()
    local copy = {}
    for sec, m in pairs(SECTION_MAP) do
        copy[sec] = {}
        for k, v in pairs(m) do
            local arr = {}
            for i, t in ipairs(v) do arr[i] = { t[1], t[2] } end
            copy[sec][k] = arr
        end
    end
    return copy
end

-- MaxProList43..58 动态映射：返回 {target,key} 或 nil
local function lookupMapping(section, key)
    local m = SECTION_MAP[section]
    if m and m[key] then
        return m[key]
    end
    -- 动态: MaxProListNN（NN=43..58）→ CC.MaxProListNN
    if section == "constant" then
        local nn = key:match("^maxprolist(%d+)$")
        if nn then
            local n = tonumber(nn)
            if n and n >= 43 and n <= 58 then
                return { {"CC", "MaxProList" .. nn} }
            end
        end
    end
    return nil
end

-- ============================================================
-- 解析
-- ============================================================

-- 把原始文本解析为 { section -> { key=value } }
-- 容错: 忽略空行/; # 注释/无段落的键/无 '=' 的行
function ModIni.ParseIniText(text)
    local sections = {}
    local order = {}
    local cur = nil
    if type(text) ~= "string" then return sections, order end

    -- 去掉 UTF-8 BOM
    text = text:gsub("^\239\187\191", "")

    for rawline in text:gmatch("[^\r\n]*") do
        local line = rawline:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= ";" and line:sub(1, 1) ~= "#" then
            local sec = line:match("^%[(.-)%]")
            if sec then
                cur = sec:gsub("^%s+", ""):gsub("%s+$", ""):lower()
                if not sections[cur] then
                    sections[cur] = {}
                    order[#order + 1] = cur
                end
            else
                local k, v = line:match("^([%w_]+)%s*=%s*(.-)%s*$")
                if k and cur then
                    -- 去掉行尾注释（; 后的内容），但保留值内可能的其它字符
                    v = v:gsub("%s*;.*$", "")
                    sections[cur][k:lower()] = v
                end
            end
        end
    end
    return sections, order
end

-- 将解析结果映射为 {CONFIG, CC, unknown, raw}
function ModIni.Map(sections, order)
    local result = { CONFIG = {}, CC = {}, unknown = {}, raw = sections }

    local function setTarget(target, key, value)
        local qualified = target .. "." .. key
        if isNumericKey(qualified) then
            local n = tonumber(value)
            if n ~= nil then value = n end
        end
        result[target][key] = value
    end

    for _, sec in ipairs(order or {}) do
        local kv = sections[sec]
        if kv then
            for k, v in pairs(kv) do
                local mapping = lookupMapping(sec, k)
                if mapping then
                    for _, t in ipairs(mapping) do
                        local qualified = t[1] .. "." .. t[2]
                        -- 负数表示“未设置”的索引键必须忽略，否则引擎会用 -1
                        -- 去索引数组而崩溃（kys-loving: BEGIN_SCENE = -1）。
                        local skip = false
                        if NON_NEGATIVE_KEYS[qualified] then
                            local n = tonumber(v)
                            if n ~= nil and n < 0 then skip = true end
                        end
                        if not skip then
                            setTarget(t[1], t[2], v)
                        end
                    end
                else
                    result.unknown[#result.unknown + 1] = {
                        section = sec, key = k, value = v,
                    }
                end
            end
        end
    end
    return result
end

function ModIni.ParseText(text)
    local sections, order = ModIni.ParseIniText(text)
    return ModIni.Map(sections, order)
end

-- 读取并解析文件；失败返回 nil, err
function ModIni.Load(path)
    local text, err = ModIni.readFile(path)
    if not text then
        return nil, err
    end
    return ModIni.ParseText(text)
end

-- ============================================================
-- 应用覆盖
-- ============================================================

-- 把 parsed.CONFIG / parsed.CC 覆盖到全局 CONFIG / CC（只覆盖出现的键）
-- 未激活/未解析时保持默认值不变（REQ-INI-3）
function ModIni.Apply(parsed)
    if type(parsed) ~= "table" then return end
    local gCONFIG = rawget(_G, "CONFIG")
    local gCC = rawget(_G, "CC")

    if gCONFIG and type(parsed.CONFIG) == "table" then
        for k, v in pairs(parsed.CONFIG) do
            gCONFIG[k] = v
        end
    end
    if gCC and type(parsed.CC) == "table" then
        for k, v in pairs(parsed.CC) do
            gCC[k] = v
        end
    end
end

return ModIni
