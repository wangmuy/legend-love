-- test_battle_wiring.lua
-- 战斗模块加载接线集成测试（battle-extensibility Task 2/5 的残余风险）
--
-- 为什么需要这个测试：
--   `verify_battle_move_fidelity.py` 已经证明 66 个函数 + 20 个协程
--   **逐字节一致**（逻辑没变）。所以「零回归」的残余风险只剩一个：
--   **加载接线是否正确** —— 文件能否被加载、全局函数是否可用、
--   协程转发是否拿得到实现、加载顺序是否满足依赖。
--
--   这个测试就是盯这一点。它是「实机验证」在自动化层面的替代品：
--   实机验证要证明的是「战斗能跑」，而这里证明「战斗的零件都在位」。
--
-- **注意加载方式**：这里用 `loadfile` 而不是 `ScriptLoader.load`。
--   `TestHelper.setup()` 装的 mock `EngineAPI.script.load` 恒返回 nil
--   （测试环境没有真引擎），所以 ScriptLoader 在测试里什么都加载不了。
--   生产代码走 ScriptLoader（为了 MOD 回退链），测试走 loadfile ——
--   两者加载的是同一个文件，所以"零件在位"这个断言依然有效。

local TestHelper = require("tests.test_helper")
local TestBattleWiring = {}

-- 战斗文件按加载顺序
local BATTLE_MODULES = {
    "battle_data", "battle_render", "battle_action", "battle_ai",
    "battle_flow", "battle_rules",
}

-- 66 个全局函数（按模块分组）
local BATTLE_FUNCS = {
    battle_data = {
        "GetWarMap", "SetWarMap", "CleanWarMap", "WarLoadMap",
    },
    battle_render = {
        "WarDrawMap", "WarShowHead", "WarCalPersonPic",
    },
    battle_action = {
        "War_PersonLostLife", "War_isEnd", "War_CalMoveStep", "War_FindNextStep",
        "War_CanMoveXY", "War_MovePerson", "War_FightMenu", "War_Fight_Sub",
        "War_FightSelectType0", "War_FightSelectType1", "War_FightSelectType2",
        "War_FightSelectType3", "War_Direct", "War_WugongHurtLife",
        "War_WugongHurtNeili", "War_UseAnqi", "War_AnqiHurt",
    },
    battle_ai = {
        "War_GetMinNeiLi", "War_AutoMenu", "War_Auto", "War_Think",
        "War_ThinkDrug", "War_ThinkDoctor", "War_AutoFight", "War_AutoSelectWugong",
        "War_AutoSelectEnemy", "War_AutoSelectEnemy_near", "War_AutoMove",
        "War_GetCanFightEnemyXY", "War_AutoCalMaxEnemyMap", "War_AutoCalMaxEnemy",
        "War_AutoExecuteFight", "War_AutoEscape", "War_AutoEatDrug", "War_AutoDoctor",
    },
    battle_flow = {
        "War_EndPersonData", "War_AddPersonLevel", "War_PersonTrainBook",
        "War_PersonTrainDrug", "WarSelectTeam", "WarSelectMenu", "WarSelectEnemy",
        "WarPersonSort", "WarSetPerson", "War_Manual", "War_Manual_Sub",
        "War_MoveMenu", "War_SelectMove", "War_ShowFight", "War_PoisonMenu",
        "War_PoisonHurt", "War_DecPoisonMenu", "War_DoctorMenu", "War_ExecuteMenu",
        "War_ExecuteMenu_Sub", "War_ThingMenu", "War_RestMenu", "War_WaitMenu",
        "War_StatusMenu",
    },
}

-- 20 个协程（由 war_async 惰性转发暴露）
local COROUTINES = {
    "War_ManualCoroutine", "War_Manual_SubCoroutine", "War_AutoMoveCoroutine",
    "War_AutoCoroutine", "War_SettlementCoroutine", "War_GameOverCoroutine",
    "War_AttackCoroutine", "War_Fight_ExecuteCoroutine", "War_Fight_SubCoroutine",
    "War_MoveCoroutine", "War_MovePersonCoroutine", "War_ShowFightCoroutine",
    "War_PoisonCoroutine", "War_DecPoisonCoroutine", "War_DoctorCoroutine",
    "War_ExecuteMenu_SubCoroutine", "War_ExecuteMenuCoroutine",
    "War_ThingMenuCoroutine", "War_StatusMenuCoroutine", "SelectTargetCoroutine",
}

local function readFile(rel)
    local f = io.open(rel, "r")
    if not f then f = io.open("../game/" .. rel, "r") end
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

--- 用 loadfile 直接加载 battle 文件（绕开测试环境的 mock script.load）
local function loadBattleModules()
    for _, m in ipairs({ "battle_data", "battle_render", "battle_action",
                         "battle_ai", "battle_flow" }) do
        local path = "script/battle/" .. m .. ".lua"
        local chunk = loadfile(path)
        if not chunk then chunk = loadfile("../game/" .. path) end
        if chunk then pcall(chunk) end
    end
end

-- ------------------------------------------------------------ 文件存在

function TestBattleWiring.testAllBattleFilesExist()
    print("\n=== Test: 六个 battle 文件都存在 ===")
    local missing = {}
    for _, m in ipairs(BATTLE_MODULES) do
        local path = "script/battle/" .. m .. ".lua"
        if not readFile(path) then missing[#missing + 1] = path end
    end
    TestHelper.assertEquals(0, #missing,
        "缺失: " .. table.concat(missing, ", "))
end

-- ------------------------------------------------------------ 全局函数可用

function TestBattleWiring.testAll66FunctionsAvailable()
    print("\n=== Test: 66 个战斗函数全部可用（加载接线正确）===")
    local total, missing = 0, {}
    for module, fns in pairs(BATTLE_FUNCS) do
        for _, name in ipairs(fns) do
            total = total + 1
            if rawget(_G, name) == nil then
                missing[#missing + 1] = module .. ":" .. name
            end
        end
    end
    TestHelper.assertEquals(66, total, "断言清单应覆盖 66 个函数")
    TestHelper.assertEquals(0, #missing,
        "缺失 " .. #missing .. " 个: " .. table.concat(missing, ", "))
end

-- ------------------------------------------------------------ 协程转发

function TestBattleWiring.testCoroutineForwardingAllPresent()
    print("\n=== Test: 20 个协程转发全部可用 ===")
    local WA = require("framework.war_async")
    local missing = {}
    for _, name in ipairs(COROUTINES) do
        if type(WA[name]) ~= "function" then
            missing[#missing + 1] = name
        end
    end
    TestHelper.assertEquals(0, #missing,
        "转发缺失 " .. #missing .. " 个: " .. table.concat(missing, ", "))
end

function TestBattleWiring.testCoroutineModuleExportsAll()
    print("\n=== Test: battle_flow_coroutines 模块导出 20 个函数 ===")
    local mod = require("script.battle.battle_flow_coroutines")
    TestHelper.assertNotNil(mod, "应能 require 协程模块")

    local n = 0
    for _, name in ipairs(COROUTINES) do
        if type(mod[name]) == "function" then n = n + 1 end
    end
    TestHelper.assertEquals(20, n, "模块应导出 20 个函数，实测 " .. n)
end

function TestBattleWiring.testForwardingIsLazy()
    print("\n=== Test: 转发确实拿得到实现（可调用）===")
    local WA = require("framework.war_async")
    TestHelper.assertEquals("function", type(WA.War_ManualCoroutine),
        "转发应是函数")

    -- 转发内部 pcall 查表；只要模块在，转发就应能取到真实函数。
    -- 这里不真的跑战斗（那需要 WAR/JY 全套状态），只验证"取得到"。
    local mod = require("script.battle.battle_flow_coroutines")
    TestHelper.assertEquals("function", type(mod.War_ManualCoroutine),
        "模块里的 War_ManualCoroutine 应是真函数")
end

-- ------------------------------------------------------------ battle_rules

function TestBattleWiring.testBattleRulesLoadable()
    print("\n=== Test: battle_rules 可加载且六字段齐全 ===")
    local BR = require("script.battle.battle_rules")
    TestHelper.assertNotNil(BR, "应能 require battle_rules")
    for _, f in ipairs({ "kind", "init", "tick", "requestAction", "onKey", "isOver" }) do
        TestHelper.assertNotNil(BR[f], "battle_rules 缺 " .. f)
    end
    TestHelper.assertEquals("turnbased", BR.kind, "默认 kind 应为 turnbased")
end

-- ------------------------------------------------------------ 加载顺序

function TestBattleWiring.testLoadOrderInJymain()
    print("\n=== Test: jymain.lua 的加载顺序符合依赖方向 ===")
    local src = readFile("script/jymain.lua")
    TestHelper.assertNotNil(src, "应能读 jymain.lua")

    local order = { "battle_data", "battle_render", "battle_action",
                    "battle_ai", "battle_flow" }
    local lastPos = 0
    for _, m in ipairs(order) do
        local pos = src:find('"' .. m .. '"', 1, true)
        TestHelper.assertNotNil(pos, "jymain 应加载 " .. m)
        TestHelper.assertTrue(pos > lastPos,
            m .. " 的加载位置应是递增的（依赖方向 data→render→action→ai→flow）")
        lastPos = pos
    end
end

function TestBattleWiring.testLoadUsesScriptLoader()
    print("\n=== Test: 加载走 ScriptLoader（MOD 可覆盖）===")
    local src = readFile("script/jymain.lua")
    TestHelper.assertNotNil(src, "应能读 jymain.lua")
    TestHelper.assertNotNil(src:find("BattleLoader", 1, true),
        "应使用 BattleLoader（经 ModData.ScriptFile 解析）")
    TestHelper.assertNotNil(src:find("script_loader", 1, true),
        "应 require framework.script_loader")
end

-- ------------------------------------------------------------ framework 无战斗算法

function TestBattleWiring.testNoBattleAlgorithmInFramework()
    print("\n=== Test: framework/ 里没有战斗算法定义（阶段 2C 成果）===")
    local files = { "framework/war_async.lua", "framework/game_states.lua",
                    "framework/jymain_adapter.lua" }
    for _, p in ipairs(files) do
        local src = readFile(p)
        if src then
            local defs = 0
            for line in src:gmatch("[^\r\n]+") do
                local code = line:gsub("^%s*%-%-.*$", "")
                if code:match("^%s*function%s+War_") then defs = defs + 1 end
            end
            TestHelper.assertEquals(0, defs, p .. " 不应定义 War_* 函数")
        end
    end
end

-- ------------------------------------------------------------ 套件入口

function TestBattleWiring.runAll()
    print("\n" .. string.rep("=", 60))
    print("战斗模块加载接线集成测试（Task 2/5 残余风险）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    -- 模拟 jymain 的加载段（用 loadfile 绕开测试环境的 mock script.load）
    loadBattleModules()

    TestBattleWiring.testAllBattleFilesExist()
    TestBattleWiring.testAll66FunctionsAvailable()
    TestBattleWiring.testCoroutineForwardingAllPresent()
    TestBattleWiring.testCoroutineModuleExportsAll()
    TestBattleWiring.testForwardingIsLazy()
    TestBattleWiring.testBattleRulesLoadable()
    TestBattleWiring.testLoadOrderInJymain()
    TestBattleWiring.testLoadUsesScriptLoader()
    TestBattleWiring.testNoBattleAlgorithmInFramework()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_battle_wiring.lua$") then
    TestBattleWiring.runAll()
end

return TestBattleWiring
