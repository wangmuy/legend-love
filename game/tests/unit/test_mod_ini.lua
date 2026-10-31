-- test_mod_ini.lua
-- ModIni 单元测试（allmods-ini-parser）
--
-- 覆盖:
--   * 19 个 MOD 的真实 kysmod.ini 全部解析成功（无报错）
--   * 抽样断言: mingdong 分辨率 960x660、GodsDevils EXP_RATE=4、pascal 640x440
--   * typo 键名 SCENCEAMI / 拼写变体 SCENEAMI 均映射到 CC.SceneAmi
--   * 容错路径: 空文件、缺段、未知键、注释、BOM
--   * Apply 只覆盖 ini 中出现的键

local TestHelper = require("tests.test_helper")
local ModIni = require("framework.mod_ini")

local TestModIni = {}

-- 定位 reference/allmods（相对 game/ 的上一级）
local function modsRoot()
    -- 允许测试从 game/ 或仓库根运行
    local candidates = {
        "../reference/allmods/",
        "reference/allmods/",
        "../../reference/allmods/",
    }
    for _, c in ipairs(candidates) do
        local f = io.open(c .. "kys-pascal/kysmod.ini", "rb")
        if f then f:close(); return c end
    end
    return nil
end

local ALL_MODS = {
    "kys-pascal", "kys-Dragon", "kys-RiverLake", "kys-ptt", "kys-pineapple",
    "kys-dream", "kys-pig", "kys-books", "kys-BookCalamity", "kys-zheng",
    "kys-loving", "kys-awaken", "kys-SweeOan", "kys-HeavenSword",
    "kys-lostbook", "kys-GodsDevils", "kys-lyff", "kys-pig3dos",
    "kys-mingdong", "kys-stronger",
}

-- 解析纯文本的辅助
local function parse(text)
    return ModIni.ParseText(text)
end

-- ============================================================
-- 解析器基础行为
-- ============================================================

function TestModIni.testParseBasic()
    local r = parse([[
; comment line
[system]
RESOLUTIONX = 960
RESOLUTIONY = 660
WALK_speed = 28

[constant]
MAX_ITEM_AMOUNT = 330
]])
    TestHelper.assertEquals(nil, r.CONFIG.Width, "RESOLUTIONX 不映射 CONFIG.Width（窗口尺寸由 config.lua 决定）")
    TestHelper.assertEquals(nil, r.CONFIG.Height, "RESOLUTIONY 不映射 CONFIG.Height")
    TestHelper.assertEquals(nil, r.CC.ScreenW, "RESOLUTIONX 不映射 CC.ScreenW")
    TestHelper.assertEquals(nil, r.CC.ScreenH, "RESOLUTIONY 不映射 CC.ScreenH")
    TestHelper.assertEquals(2, #r.unknown, "RESOLUTIONX/Y 进入 unknown（无害保留）")
    TestHelper.assertEquals(28, r.CC.WalkSpeed, "WALK_speed -> CC.WalkSpeed")
    TestHelper.assertEquals(330, r.CC.MaxItemAmount, "MAX_ITEM_AMOUNT -> CC.MaxItemAmount")
    TestHelper.assertEquals(330, r.CC.MyThingNum, "MAX_ITEM_AMOUNT -> CC.MyThingNum")
end

function TestModIni.testTyposAndVariants()
    -- mingdong 的 typo 键名 SCENCEAMI
    local r1 = parse("[system]\nSCENCEAMI = 2\n")
    TestHelper.assertEquals(2, r1.CC.SceneAmi, "SCENCEAMI (typo) -> CC.SceneAmi")
    TestHelper.assertEquals(0, #r1.unknown, "SCENCEAMI 不应进入 unknown")

    -- 其余 MOD 的拼写 SCENEAMI
    local r2 = parse("[system]\nSCENEAMI = 2\n")
    TestHelper.assertEquals(2, r2.CC.SceneAmi, "SCENEAMI -> CC.SceneAmi")
    TestHelper.assertEquals(0, #r2.unknown, "SCENEAMI 不应进入 unknown")

    -- 拼写变体 BEGIN_SCENCE / BEGIN_SCENE
    local r3 = parse("[constant]\nBEGIN_SCENCE = 121\nBEGIN_SCENE = 121\n")
    TestHelper.assertEquals(121, r3.CC.NewGameSceneID, "BEGIN_SCENE -> CC.NewGameSceneID")
    TestHelper.assertEquals(0, #r3.unknown, "BEGIN_SCEN* 不应进入 unknown")
end

function TestModIni.testBeginSxSySwap()
    -- 原版 x/y 与 love2d 相反: BEGIN_Sx -> CC.NewGameSceneY, BEGIN_Sy -> CC.NewGameSceneX
    local r = parse("[constant]\nBEGIN_Sx = 20\nBEGIN_Sy = 19\n")
    TestHelper.assertEquals(20, r.CC.NewGameSceneY, "BEGIN_Sx -> CC.NewGameSceneY")
    TestHelper.assertEquals(19, r.CC.NewGameSceneX, "BEGIN_Sy -> CC.NewGameSceneX")
end

function TestModIni.testMaxProListDynamic()
    local r = parse("[constant]\nMaxProList43 = 600\nMaxProList58 = 1\n")
    TestHelper.assertEquals(600, r.CC.MaxProList43, "MaxProList43 -> CC.MaxProList43")
    TestHelper.assertEquals(1, r.CC.MaxProList58, "MaxProList58 -> CC.MaxProList58")
    TestHelper.assertEquals(0, #r.unknown, "MaxProList43..58 不应进入 unknown")
end

function TestModIni.testUnknownKeys()
    local r = parse("[system]\nFOO_BAR = 1\n[bogus]\nX = 2\n")
    TestHelper.assertEquals(2, #r.unknown, "未知键/未知段进入 unknown")
    local found = {}
    for _, u in ipairs(r.unknown) do found[u.key] = u.value end
    TestHelper.assertEquals("1", found["foo_bar"], "未知键原值保留")
    TestHelper.assertEquals("2", found["x"], "未知段键原值保留")
end

function TestModIni.testNegativeSceneIndexIgnored()
    -- kys-loving 在 kysmod.ini 中声明 BEGIN_SCENE = -1 / BEGIN_EVENT = -1，
    -- 表示“不指定”。引擎会直接用 CC.NewGameSceneID 索引 JY.Scene[]，
    -- 若照搬 -1 会崩溃，因此负值必须被忽略（保持引擎默认 70）。
    local r = parse("[constant]\nBEGIN_SCENE = -1\nBEGIN_EVENT = -1\nBEGIN_Sx = 20\nBEGIN_Sy = 19\n")
    TestHelper.assertEquals(nil, r.CC.NewGameSceneID, "BEGIN_SCENE=-1 被忽略（不覆盖默认）")
    TestHelper.assertEquals(nil, r.CC.NewGameEvent, "BEGIN_EVENT=-1 被忽略")
    TestHelper.assertEquals(19, r.CC.NewGameSceneX, "BEGIN_Sy -> CC.NewGameSceneX 仍生效")
    TestHelper.assertEquals(20, r.CC.NewGameSceneY, "BEGIN_Sx -> CC.NewGameSceneY 仍生效")

    -- 正值必须照常覆盖（dream=121, mingdong=70）
    local r2 = parse("[constant]\nBEGIN_SCENE = 121\nBEGIN_EVENT = 691\n")
    TestHelper.assertEquals(121, r2.CC.NewGameSceneID, "正数 BEGIN_SCENE 正常覆盖")
    TestHelper.assertEquals(691, r2.CC.NewGameEvent, "正数 BEGIN_EVENT 正常覆盖")
end

function TestModIni.testEmptyAndMissing()
    local r0 = parse("")
    TestHelper.assertEquals(0, #r0.unknown, "空文件不报错")
    TestHelper.assertEquals(nil, r0.CONFIG.Width, "空文件无覆盖")

    -- 缺失段: 只有 [system]，没有 [constant]
    local r1 = parse("[system]\nWALK_speed = 800\n")
    TestHelper.assertEquals(800, r1.CC.WalkSpeed, "缺段仍解析已有段")
    TestHelper.assertEquals(nil, r1.CC.MaxItemAmount, "缺段对应表缺项")

    -- 缺 '=' 的行、无段落的键、注释
    local r2 = parse("garbage line\nKEY_ONLY\n; comment\n[system]\n\nA = 1\n")
    TestHelper.assertEquals(1, #r2.unknown, "无段落的键进入 unknown（KEY_ONLY）")
end

function TestModIni.testBOMAndCRLF()
    local text = "\239\187\191[system]\r\nWALK_speed = 1024\r\nWALK_speed2 = 768\r\n"
    local r = parse(text)
    TestHelper.assertEquals(1024, r.CC.WalkSpeed, "BOM+CRLF: WALK_speed")
    TestHelper.assertEquals(768, r.CC.WalkSpeed2, "BOM+CRLF: WALK_speed2")
end

function TestModIni.testInlineComment()
    local r = parse("[system]\nWALK_speed = 20 ; speed comment\n")
    TestHelper.assertEquals(20, r.CC.WalkSpeed, "行尾注释被剥离")
end

function TestModIni.testApplyOnlyOverridesPresent()
    local savedCONFIG = _G.CONFIG
    local savedCC = _G.CC
    _G.CONFIG = { Width = 1024, Height = 768, Debug = 0 }
    _G.CC = { ScreenW = 1024, ScreenH = 768, MyThingNum = 200 }

    local parsed = parse("[system]\nWALK_speed = 960\n")
    ModIni.Apply(parsed)

    TestHelper.assertEquals(1024, _G.CONFIG.Width, "Apply 不动窗口宽（分辨率不映射）")
    TestHelper.assertEquals(768, _G.CONFIG.Height, "Apply 不动窗口高")
    TestHelper.assertEquals(1024, _G.CC.ScreenW, "Apply 不动 CC.ScreenW")
    TestHelper.assertEquals(960, _G.CC.WalkSpeed, "Apply 覆盖 CC.WalkSpeed")
    TestHelper.assertEquals(200, _G.CC.MyThingNum, "Apply 不覆盖未出现的 MyThingNum")
    TestHelper.assertEquals(0, _G.CONFIG.Debug, "Apply 不覆盖未出现的 Debug")

    _G.CONFIG = savedCONFIG
    _G.CC = savedCC
end

-- ============================================================
-- 真实 ini 文件: 19 个 MOD 全部解析成功
-- ============================================================

function TestModIni.testAllRealIniParse()
    local root = modsRoot()
    if not root then
        TestHelper.assertTrue(false, "找不到 reference/allmods（测试环境缺少 MOD 数据）")
        return
    end

    local ok = 0
    local failures = {}
    for _, mod in ipairs(ALL_MODS) do
        local path = root .. mod .. "/kysmod.ini"
        local parsed, err = ModIni.Load(path)
        if parsed then
            ok = ok + 1
            -- 每个真实 ini 至少应有 [system] 与 [constant] 解析结果
            TestHelper.assertNotNil(parsed.raw["system"], mod .. " 有 [system] 段")
        else
            failures[#failures + 1] = mod .. ": " .. tostring(err)
        end
    end
    TestHelper.assertEquals(#ALL_MODS, ok,
        "19 个 MOD 的 kysmod.ini 全部解析成功" ..
        (#failures > 0 and (" (失败: " .. table.concat(failures, ", ") .. ")") or ""))
end

function TestModIni.testMingdongSampleValues()
    local root = modsRoot()
    if not root then return end
    local r = ModIni.Load(root .. "kys-mingdong/kysmod.ini")
    TestHelper.assertNotNil(r, "mingdong ini 解析成功")
    TestHelper.assertEquals(nil, r.CONFIG.Width, "mingdong 分辨率不映射 CONFIG.Width")
    TestHelper.assertEquals(nil, r.CONFIG.Height, "mingdong 分辨率不映射 CONFIG.Height")
    TestHelper.assertEquals(2, r.CC.SceneAmi, "mingdong SCENCEAMI=2 (typo 键)")
    TestHelper.assertEquals(330, r.CC.MaxItemAmount, "mingdong MAX_ITEM_AMOUNT=330")
    TestHelper.assertEquals(9999, r.CC.MaxHP, "mingdong MAX_HP=9999")
    TestHelper.assertEquals(28, r.CC.WalkSpeed, "mingdong WALK_speed=28")
end

function TestModIni.testGodsDevilsSampleValues()
    local root = modsRoot()
    if not root then return end
    local r = ModIni.Load(root .. "kys-GodsDevils/kysmod.ini")
    TestHelper.assertNotNil(r, "GodsDevils ini 解析成功")
    TestHelper.assertEquals(4, r.CC.ExpRate, "GodsDevils EXP_RATE=4")
    TestHelper.assertEquals(2, r.CC.SceneAmi, "GodsDevils SCENEAMI=2")
end

function TestModIni.testPascalSampleValues()
    local root = modsRoot()
    if not root then return end
    local r = ModIni.Load(root .. "kys-pascal/kysmod.ini")
    TestHelper.assertNotNil(r, "pascal ini 解析成功")
    TestHelper.assertEquals(nil, r.CONFIG.Width, "pascal 分辨率不映射（保持 1024x768 窗口）")
    TestHelper.assertEquals(nil, r.CONFIG.Height, "pascal 分辨率不映射")
    TestHelper.assertEquals(100, r.CC.ExpRate, "pascal EXP_RATE=100")
    TestHelper.assertEquals(7, r.CC.MaxWeaponMatch, "pascal MAX_WEAPON_MATCH=7")
    TestHelper.assertEquals(80, r.CC.MinKnowledge, "pascal MIN_KNOWLEDGE=80")
    TestHelper.assertEquals(200, r.CC.MaxItemAmount, "pascal MAX_ITEM_AMOUNT=200")
end

function TestModIni.testNoKnownKeyLeaksToUnknown()
    local root = modsRoot()
    if not root then return end
    -- 所有已知键（含 typo/变体）都不应进入 unknown
    local known = {
        -- 注: resolutionx/resolutiony 已刻意不映射（窗口尺寸由 config.lua 决定），
        -- 故不列入本表；它们进入 unknown 是预期行为。
        ["walk_speed"] = true,
        ["walk_speed2"] = true, ["battle_speed"] = true, ["smooth"] = true,
        ["glhr"] = true, ["mmapami"] = true, ["sceneami"] = true,
        ["scenceami"] = true, ["semireal"] = true, ["kdef_script"] = true,
        ["simple"] = true, ["expand_ground"] = true, ["exit_game"] = true,
        ["night_effect"] = true, ["wmp_4_pic"] = true, ["hires_text"] = true,
        ["renderer"] = true, ["exp_rate"] = true, ["modversion"] = true,
        ["volume"] = true, ["volumewav"] = true, ["sound3d"] = false, -- sound3d 未映射
        ["begin_scene"] = true, ["begin_scence"] = true, ["begin_sx"] = true,
        ["begin_sy"] = true, ["begin_event"] = true,
        ["softstar_begin_talk"] = true, ["softstar_num_talk"] = true,
        ["begin_battle_role_pic"] = true, ["begin_leave_event"] = true,
        ["max_physical_power"] = true, ["money_id"] = true, ["compass_id"] = true,
        ["max_level"] = true, ["max_weapon_match"] = true, ["min_knowledge"] = true,
        ["max_item_amount"] = true, ["life_hurt"] = true, ["max_hp"] = true,
        ["max_mp"] = true, ["poison_hurt"] = true, ["max_add_pro"] = true,
        ["item_begin_pic"] = true,
    }
    local leaks = {}
    for _, mod in ipairs(ALL_MODS) do
        local r = ModIni.Load(root .. mod .. "/kysmod.ini")
        if r then
            for _, u in ipairs(r.unknown) do
                local isMaxPro = u.key:match("^maxprolist%d+$") ~= nil
                if known[u.key] == true or isMaxPro then
                    leaks[#leaks + 1] = mod .. ":" .. u.key
                end
            end
        end
    end
    TestHelper.assertEquals(0, #leaks,
        "已知键不泄漏到 unknown" .. (#leaks > 0 and (" (泄漏: " .. table.concat(leaks, ", ") .. ")") or ""))
end

function TestModIni.runAll()
    print("\n========================================")
    print("ModIni Unit Tests")
    print("========================================")

    TestHelper.resetCounts()
    TestModIni.testParseBasic()
    TestModIni.testTyposAndVariants()
    TestModIni.testBeginSxSySwap()
    TestModIni.testMaxProListDynamic()
    TestModIni.testUnknownKeys()
    TestModIni.testEmptyAndMissing()
    TestModIni.testNegativeSceneIndexIgnored()
    TestModIni.testBOMAndCRLF()
    TestModIni.testInlineComment()
    TestModIni.testApplyOnlyOverridesPresent()
    TestModIni.testAllRealIniParse()
    TestModIni.testMingdongSampleValues()
    TestModIni.testGodsDevilsSampleValues()
    TestModIni.testPascalSampleValues()
    TestModIni.testNoKnownKeyLeaksToUnknown()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_mod_ini.lua$") then
    TestModIni.runAll()
end

return TestModIni
