-- test_battle_rules.lua
-- 战斗规则策略测试（change: battle-extensibility Task 3/4）
--
-- 守的坑（design.md ADR-BE-002 / ADR-BE-004）：
--   ① battle_rules 六个字段齐全（kind/init/tick/requestAction/onKey/isOver）
--   ② kind 的三种合法值都能取到对应策略
--   ③ turnbased 的 tick 是空实现（零回归的前提）
--   ④ atb / realtime 只留骨架（不假装已实现）
--   ⑤ dt 从 war_async.tick 传进 strategy.tick，且值正确
--   ⑥ 非战斗状态 tick 不做事
--   ⑦ tick 返回**策略的真实结果**（不是 pcall 成功与否 —— 实测踩过）

local TestHelper = require("tests.test_helper")
local TestBattleRules = {}

local function fresh()
    package.loaded["script.battle.battle_rules"] = nil
    package.loaded["framework.war_async"] = nil
    return require("script.battle.battle_rules"), require("framework.war_async")
end

-- ------------------------------------------------------------ 六字段契约

function TestBattleRules.testSixFieldsPresent()
    print("\n=== Test: 六字段契约齐全 ===")
    local BR = fresh()
    BR = require("script.battle.battle_rules")
    for _, f in ipairs({ "kind", "init", "tick", "requestAction", "onKey", "isOver" }) do
        TestHelper.assertNotNil(BR[f], "battle_rules 缺字段: " .. f)
    end
end

function TestBattleRules.testKindValues()
    print("\n=== Test: kind 三种合法值 ===")
    local BR = require("script.battle.battle_rules")
    TestHelper.assertEquals("turnbased", BR.KIND_TURNBASED, "常量 turnbased")
    TestHelper.assertEquals("atb", BR.KIND_ATB, "常量 atb")
    TestHelper.assertEquals("realtime", BR.KIND_REALTIME, "常量 realtime")
end

function TestBattleRules.testGetReturnsStrategyByKind()
    print("\n=== Test: get(kind) 返回对应策略 ===")
    local BR = require("script.battle.battle_rules")

    for _, kind in ipairs({ "turnbased", "atb", "realtime" }) do
        local s = BR.get(kind)
        TestHelper.assertNotNil(s, "get(" .. kind .. ") 应返回策略")
        TestHelper.assertEquals(kind, s.kind, "策略的 kind 应为 " .. kind)
        TestHelper.assertEquals("function", type(s.init), kind .. ".init 应为函数")
        TestHelper.assertEquals("function", type(s.tick), kind .. ".tick 应为函数")
        TestHelper.assertEquals("function", type(s.requestAction), kind .. ".requestAction 应为函数")
        TestHelper.assertEquals("function", type(s.onKey), kind .. ".onKey 应为函数")
        TestHelper.assertEquals("function", type(s.isOver), kind .. ".isOver 应为函数")
    end
end

function TestBattleRules.testGetDefaultsToTurnbased()
    print("\n=== Test: get(nil) 默认 turnbased ===")
    local BR = require("script.battle.battle_rules")
    local s = BR.get(nil)
    TestHelper.assertEquals("turnbased", s.kind, "缺省应为 turnbased")
end

function TestBattleRules.testCurrentReadsGlobal()
    print("\n=== Test: current() 读全局 BattleRules 的 kind ===")
    local BR = require("script.battle.battle_rules")

    rawset(_G, "BattleRules", { kind = "realtime" })
    local s1 = BR.current()
    TestHelper.assertEquals("realtime", s1.kind, "应读到全局的 realtime")

    rawset(_G, "BattleRules", nil)
    local s2 = BR.current()
    TestHelper.assertEquals("turnbased", s2.kind, "全局缺失时默认 turnbased")

    rawset(_G, "BattleRules", { kind = "turnbased" })
end

-- ------------------------------------------------------------ 各策略行为

function TestBattleRules.testTurnbasedTickIsNoop()
    print("\n=== Test: turnbased 的 tick 是空实现 ===")
    local BR = require("script.battle.battle_rules")
    local s = BR.get("turnbased")
    local ctx = { turn = 0 }
    -- 空实现：不该改 ctx 的任何业务字段
    local r = s.tick(ctx, 0.016)
    TestHelper.assertEquals(true, r, "turnbased.tick 应返回 true（处理了但什么都不做）")
    TestHelper.assertEquals(0, ctx.turn, "turnbased.tick 不该改 ctx.turn")
end

function TestBattleRules.testTurnbasedIsOverAlwaysFalse()
    print("\n=== Test: turnbased 的 isOver 恒 false（结束判定归 battle_flow）===")
    local BR = require("script.battle.battle_rules")
    local s = BR.get("turnbased")
    TestHelper.assertEquals(false, s.isOver({}), "turnbased.isOver 应恒 false")
end

function TestBattleRules.testRealtimeTickAccumulates()
    print("\n=== Test: realtime 的 tick 累加 elapsed ===")
    local BR = require("script.battle.battle_rules")
    local s = BR.get("realtime")
    local ctx = {}
    TestHelper.assertTrue(s.init(ctx), "realtime.init 应成功")
    TestHelper.assertNotNil(ctx.realtime, "init 应创建 ctx.realtime")

    s.tick(ctx, 0.016)
    TestHelper.assertTrue(math.abs(ctx.realtime.elapsed - 0.016) < 1e-9,
        "elapsed 应为 0.016，实测 " .. tostring(ctx.realtime.elapsed))
    s.tick(ctx, 0.034)
    TestHelper.assertTrue(math.abs(ctx.realtime.elapsed - 0.050) < 1e-9,
        "两次累加应为 0.050，实测 " .. tostring(ctx.realtime.elapsed))
end

function TestBattleRules.testATBTickIsSkeleton()
    print("\n=== Test: atb 只是骨架（不真实现计时条）===")
    local BR = require("script.battle.battle_rules")
    local s = BR.get("atb")
    local ctx = {}
    TestHelper.assertTrue(s.init(ctx), "atb.init 应成功")
    TestHelper.assertNotNil(ctx.atb, "init 应创建 ctx.atb")
    -- 骨架：tick 返回 true 但不改变 atb 表内容
    local r = s.tick(ctx, 0.016)
    TestHelper.assertEquals(true, r, "atb.tick 骨架返回 true")
end

function TestBattleRules.testInitRejectsBadCtx()
    print("\n=== Test: init 对非法 ctx 返回 false（不崩）===")
    local BR = require("script.battle.battle_rules")
    for _, kind in ipairs({ "turnbased", "atb", "realtime" }) do
        local s = BR.get(kind)
        TestHelper.assertEquals(false, s.init(nil), kind .. ".init(nil) 应返回 false")
        TestHelper.assertEquals(false, s.init("x"), kind .. ".init(字符串) 应返回 false")
    end
end

-- ------------------------------------------------------------ dt 传播

function TestBattleRules.testWarAsyncTickPropagatesDT()
    print("\n=== Test: war_async.tick 把 dt 传给策略 ===")
    local BR, WA = fresh()

    WA.reset()
    local st = WA.getWarState()
    st.status = "running"
    st.warId = 1

    rawset(_G, "BattleRules", { kind = "realtime" })
    local ok = WA.tick(0.016)
    TestHelper.assertEquals(true, ok, "战斗中的 tick 应返回 true")
    TestHelper.assertNotNil(st.ctx, "ctx 应被创建")
    TestHelper.assertNotNil(st.ctx.realtime, "init 应已调用（realtime 表存在）")
    TestHelper.assertTrue(math.abs(st.ctx.realtime.elapsed - 0.016) < 1e-9,
        "dt 应传进 tick，elapsed 实测 " .. tostring(st.ctx.realtime.elapsed))

    -- 第二帧累加
    WA.tick(0.034)
    TestHelper.assertTrue(math.abs(st.ctx.realtime.elapsed - 0.050) < 1e-9,
        "两帧累加应为 0.050")

    WA.reset()
    rawset(_G, "BattleRules", { kind = "turnbased" })
end

function TestBattleRules.testTickIgnoresNonRunning()
    print("\n=== Test: 非战斗状态 tick 不做事 ===")
    local BR, WA = fresh()
    WA.reset()

    TestHelper.assertEquals(false, WA.tick(0.016), "idle 状态应返回 false")

    local st = WA.getWarState()
    st.status = "ended"
    TestHelper.assertEquals(false, WA.tick(0.016), "ended 状态应返回 false")

    st.status = "running"
    TestHelper.assertEquals(true, WA.tick(0.016), "running 状态应返回 true")
    WA.reset()
end

function TestBattleRules.testTickRejectsBadDT()
    print("\n=== Test: 非法 dt 被拒绝 ===")
    local BR, WA = fresh()
    WA.reset()
    local st = WA.getWarState()
    st.status = "running"

    TestHelper.assertEquals(false, WA.tick(0), "dt=0 应拒绝")
    TestHelper.assertEquals(false, WA.tick(-1), "dt<0 应拒绝")
    TestHelper.assertEquals(false, WA.tick(nil), "nil 应拒绝")
    TestHelper.assertEquals(false, WA.tick("x"), "字符串应拒绝")
    WA.reset()
end

function TestBattleRules.testTickReturnsStrategyResult()
    print("\n=== Test: tick 返回策略的真实结果（不是 pcall 成功）===")
    local BR, WA = fresh()

    WA.reset()
    local st = WA.getWarState()
    st.status = "running"

    -- 替换策略为「tick 明确返回 false」
    rawset(_G, "BattleRules", { kind = "turnbased" })
    package.loaded["script.battle.battle_rules"] = nil
    BR = require("script.battle.battle_rules")
    local savedGet = BR.get
    local savedCurrent = BR.current   -- **必须一起保存/恢复**
    BR.get = function(kind)
        return {
            kind = "turnbased",
            init = function() return true end,
            tick = function() return false end,   -- 明确拒绝
            requestAction = function() return true end,
            onKey = function() return true end,
            isOver = function() return false end,
        }
    end
    BR.current = function() return BR.get("turnbased") end

    TestHelper.assertEquals(false, WA.tick(0.016),
        "策略返回 false 时 tick 必须返回 false（不能误报 true）")

    BR.get = savedGet
    BR.current = savedCurrent
    WA.reset()
end

function TestBattleRules.testInitCalledOnceOnly()
    print("\n=== Test: init 只调一次（懒初始化）===")
    local BR, WA = fresh()
    WA.reset()
    local st = WA.getWarState()
    st.status = "running"

    rawset(_G, "BattleRules", { kind = "turnbased" })
    package.loaded["script.battle.battle_rules"] = nil
    BR = require("script.battle.battle_rules")

    local initCalls = 0
    local savedGet = BR.get
    local savedCurrent = BR.current   -- **必须一起保存/恢复**
    BR.get = function()
        return {
            kind = "turnbased",
            init = function() initCalls = initCalls + 1 return true end,
            tick = function() return true end,
            requestAction = function() return true end,
            onKey = function() return true end,
            isOver = function() return false end,
        }
    end
    BR.current = function() return BR.get() end

    WA.tick(0.016)
    WA.tick(0.016)
    WA.tick(0.016)
    TestHelper.assertEquals(1, initCalls,
        "init 应只调 1 次，实测 " .. initCalls .. " 次")

    BR.get = savedGet
    BR.current = savedCurrent
    WA.reset()
end

-- 套件入口

function TestBattleRules.runAll()
    print("\n" .. string.rep("=", 60))
    print("战斗规则策略测试（ADR-BE-002 / ADR-BE-004）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestBattleRules.testSixFieldsPresent()
    TestBattleRules.testKindValues()
    TestBattleRules.testGetReturnsStrategyByKind()
    TestBattleRules.testGetDefaultsToTurnbased()
    TestBattleRules.testCurrentReadsGlobal()

    TestBattleRules.testTurnbasedTickIsNoop()
    TestBattleRules.testTurnbasedIsOverAlwaysFalse()
    TestBattleRules.testRealtimeTickAccumulates()
    TestBattleRules.testATBTickIsSkeleton()
    TestBattleRules.testInitRejectsBadCtx()

    TestBattleRules.testWarAsyncTickPropagatesDT()
    TestBattleRules.testTickIgnoresNonRunning()
    TestBattleRules.testTickRejectsBadDT()
    TestBattleRules.testTickReturnsStrategyResult()
    TestBattleRules.testInitCalledOnceOnly()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_battle_rules.lua$") then
    TestBattleRules.runAll()
end

return TestBattleRules
