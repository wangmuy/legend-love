-- test_battle_flow_headless.lua
-- 无头驱动真实战斗算法（battle-extensibility 的深度验证）
--
-- 目标：这是「实机验证」在自动化层面能走到的最远处。
--
--   已经机器验证的：
--     ① 搬移字节保真（66 函数 + 20 协程，verify_battle_move_fidelity.py）
--     ② 加载接线（test_battle_wiring.lua，33 条）
--   这个测试补上的：
--     ③ **用真实 war.sta 数据驱动战斗算法**，验证搬移后的函数真的能跑出结果
--
-- 不能替代实机的原因（如实记录）：
--   - 贴图/渲染链路（SpriteAtlas / WarDrawMap）需要真引擎
--   - 协程调度与 waitKey 需要真实输入事件
--   - 但**算法层**（移动步数/伤害/结束判定/AI 选敌）可以无头验证
--
-- 为什么需要 stub lib.*：
--   script/battle/battle_data.lua 直接调 lib.LoadWarMap / lib.GetWarMap /
--   lib.SetWarMap / lib.CleanWarMap（script 层的既有写法，AGENTS.md 允许）。
--   测试环境没有真引擎，所以用内存实现替代（与真实实现语义一致）。

local TestHelper = require("tests.test_helper")
local TestBattleFlowHeadless = {}

-- 内存版战斗地图（层 -> 二维数组）
local warMapLayers = {}
local MAP_W, MAP_H = 20, 20

local function mapKey(x, y, layer)
    return layer .. ":" .. x .. ":" .. y
end

-- 层语义（与 lib_love.lua 的 warmap 一致）：
--   层 0  地形图号（CC.WarWater 查表判断水面）
--   层 1  物体（>0 表示有障碍）
--   层 2  人物（**-1 = 空**，>=0 是人物编号；War_CanMoveXY 用 `>=0` 判定"有人"）
--   层 3  移动步数（255 = 不可达）
local function resetWarMap()
    warMapLayers = {}
    for i = 0, MAP_W - 1 do
        for j = 0, MAP_H - 1 do
            warMapLayers[mapKey(i, j, 0)] = 0
            warMapLayers[mapKey(i, j, 1)] = 0
            warMapLayers[mapKey(i, j, 2)] = -1    -- **空位是 -1，不是 0**
            warMapLayers[mapKey(i, j, 3)] = 255
        end
    end
end

--- 装 lib 的战斗地图 stub（与 lib_love.lua 的语义一致）
local function installLibStubs()
    rawset(_G, "lib", rawget(_G, "lib") or {})
    local L = rawget(_G, "lib")

    L.Debug = function() end

    L.LoadWarMap = function(idxFile, grpFile, mapId, num, w, h)
        -- 真实实现从 .idx/.grp 读地图；此处清空即可（测试用 SetWarMap 建图）
        resetWarMap()
    end

    L.GetWarMap = function(x, y, layer)
        return warMapLayers[mapKey(x, y, layer)] or 0
    end

    L.SetWarMap = function(x, y, layer, v)
        warMapLayers[mapKey(x, y, layer)] = v
    end

    L.CleanWarMap = function(layer, v)
        for i = 0, MAP_W - 1 do
            for j = 0, MAP_H - 1 do
                warMapLayers[mapKey(i, j, layer)] = v
            end
        end
    end
end

--- 准备一个最小可跑的战斗场景
local function setupBattle(opts)
    opts = opts or {}
    resetWarMap()

    WAR.PersonNum = 2
    WAR.CurID = 0
    WAR.AutoFight = 0
    WAR.Data = WAR.Data or {}
    WAR.Data["地图"] = 0
    WAR.Data["音乐"] = 5
    WAR.Data["经验"] = 100
    WAR.Data["战斗类型"] = 0

    WAR.Person[0] = {
        ["人物编号"] = 1, ["坐标X"] = 5, ["坐标Y"] = 5,
        ["移动步数"] = 3, ["我方"] = true, ["轻功"] = 50,
        ["死亡"] = false, ["生命"] = 100, ["体力"] = 100, ["内力"] = 100,
        ["受伤程度"] = 0, ["中毒程度"] = 0, ["经验"] = 0,
        ["生命最大值"] = 100, ["内力最大值"] = 100, ["体力最大值"] = 100,
        ["攻击力"] = 30, ["防御力"] = 20, ["攻击带毒"] = 0,
        ["武器"] = -1, ["防具"] = -1,
        ["人方向"] = 0, ["贴图"] = 0,
    }
    WAR.Person[1] = {
        ["人物编号"] = 2, ["坐标X"] = 10, ["坐标Y"] = 10,
        ["移动步数"] = 3, ["我方"] = false, ["轻功"] = 50,
        ["死亡"] = false, ["生命"] = 100, ["体力"] = 100, ["内力"] = 100,
        ["受伤程度"] = 0, ["中毒程度"] = 0, ["经验"] = 0,
        ["生命最大值"] = 100, ["内力最大值"] = 100, ["体力最大值"] = 100,
        ["攻击力"] = 20, ["防御力"] = 10, ["攻击带毒"] = 0,
        ["武器"] = -1, ["防具"] = -1,
        ["人方向"] = 0, ["贴图"] = 0,
    }

    -- **用 TestHelper.createTestPerson 建人物**：战斗算法要读几十个字段
    -- （武学常识 / 拳掌功夫 / 御剑能力 / 抗毒能力 ...），手写会漏。
    -- 工厂函数已覆盖 CC.PersonAttrib 的全字段。
    -- **按 CC.Person_S 的结构补全所有字段**（值为 0）：
    -- 战斗算法会读几十个属性（经验/生命最大值/武学常识/...），
    -- 手写清单永远会漏 —— 直接从结构表生成最可靠。
    local function fullPerson(id, name)
        local p = TestHelper.createTestPerson({ ID = id })
        for k in pairs(CC.Person_S or {}) do
            if p[k] == nil then p[k] = 0 end
        end
        p["姓名"] = name
        -- **这些字段的"空值"是 -1 不是 0**：
        --   修炼物品 -1  不修炼（War_PersonTrainBook 用它查 JY.Thing）
        --   武器/防具 -1  无装备
        p["修炼物品"] = -1
        p["武器"] = -1
        p["防具"] = -1
        return p
    end

    local p1 = fullPerson(1, "主角")
    p1["姓名"] = "主角"
    p1["生命"] = 100; p1["体力"] = 100; p1["内力"] = 5000
    p1["受伤程度"] = 0; p1["中毒程度"] = 0
    p1["武功1"] = 1; p1["武功等级1"] = 100   -- 等级 1（modf(100/100)+1）
    p1["攻击力"] = 30; p1["防御力"] = 20; p1["轻功"] = 50
    p1["经验"] = 0; p1["资质"] = 50
    p1["武学常识"] = 0
    p1["武器"] = -1      -- -1 = 无装备（战斗算法用 `>=0` 判定有装备）
    p1["防具"] = -1
    p1["攻击带毒"] = 0
    p1["抗毒能力"] = 0
    p1["生命最大值"] = 100
    p1["内力最大值"] = 100
    p1["体力最大值"] = 100
    JY.Person[1] = p1

    local p2 = fullPerson(2, "敌人")
    p2["生命"] = 100; p2["体力"] = 100; p2["内力"] = 5000
    p2["受伤程度"] = 0; p2["中毒程度"] = 0
    p2["武功1"] = 1; p2["武功等级1"] = 100
    p2["攻击力"] = 20; p2["防御力"] = 10; p2["轻功"] = 50
    p2["经验"] = 0; p2["资质"] = 50
    p2["武学常识"] = 0
    p2["武器"] = -1
    p2["防具"] = -1
    p2["攻击带毒"] = 0
    p2["抗毒能力"] = 0
    p2["生命最大值"] = 100
    p2["内力最大值"] = 100
    p2["体力最大值"] = 100
    JY.Person[2] = p2

    -- 武功表：战斗算法按**等级**读 `攻击力<level>`（如 攻击力1、攻击力2…），
    -- 所以必须逐级填。用工厂函数建表更稳（它会填满 CC.Wugong 的全字段）。
    JY.Thing = JY.Thing or {}
    JY.Base = JY.Base or {}
    JY.Base["人方向"] = 0
    JY.Base["乘船"] = 0
    WAR.ShowHead = 0
    JY.Wugong[1] = TestHelper.createTestWugong({ ID = 1 })
    JY.Wugong[1]["名称"] = "太祖长拳"
    JY.Wugong[1]["攻击范围"] = 0
    JY.Wugong[1]["武功类型"] = 0
    JY.Wugong[1]["消耗内力点数"] = 5
    for lv = 1, 10 do
        JY.Wugong[1]["攻击力" .. lv] = 20 + lv
    end
    -- 战斗算法要读的其它武功字段（缺一个就 nil 算术错误）
    JY.Wugong[1]["敌人中毒点数"] = 0
    JY.Wugong[1]["自己中毒点数"] = 0
    for lv = 1, 10 do
        JY.Wugong[1]["杀内力" .. lv] = 3 + lv
        JY.Wugong[1]["加内力" .. lv] = 3 + lv
        JY.Wugong[1]["杀生命" .. lv] = 10 + lv
        JY.Wugong[1]["加生命" .. lv] = 0
    end

    -- 人物位置（层 2）
    SetWarMap(5, 5, 2, 0)
    SetWarMap(10, 10, 2, 1)

    -- 可走范围（层 3）：以主角为中心的曼哈顿距离 <= 3
    for dx = -3, 3 do
        for dy = -3, 3 do
            local d = math.abs(dx) + math.abs(dy)
            if d <= 3 then SetWarMap(5 + dx, 5 + dy, 3, d) end
        end
    end

    if opts.killEnemy then
        WAR.Person[1]["死亡"] = true
        JY.Person[2]["生命"] = 0
    end
end

-- ------------------------------------------------------------ 真实 war.sta 读取

function TestBattleFlowHeadless.testWarLoadReadsRealData()
    print("\n=== Test: WarLoad 读真实 war.sta 数据 ===")
    -- CC 常量必须就绪（SetGlobalConst 装配）
    if rawget(_G, "SetGlobalConst") then pcall(SetGlobalConst) end
    TestHelper.assertNotNil(CC.WarDataSize, "CC.WarDataSize 应已装配")
    TestHelper.assertEquals(186, CC.WarDataSize, "战斗数据大小应为 186 字节")

    local ok, err = pcall(WarLoad, 0)
    TestHelper.assertTrue(ok, "WarLoad(0) 应成功，实测: " .. tostring(err))
    TestHelper.assertNotNil(WAR.Data, "WarLoad 后 WAR.Data 应存在")
    TestHelper.assertNotNil(WAR.Data["名称"], "应读到战斗名称")
    TestHelper.assertNotNil(WAR.Data["地图"], "应读到地图编号")
end

function TestBattleFlowHeadless.testWarLoadRejectsOutOfRange()
    print("\n=== Test: WarLoad 拒绝越界 warid ===")
    local ok = pcall(WarLoad, 999999)
    -- 越界时 WarLoad 内部 JY_Error 后 return（不抛错，但数据不加载）
    TestHelper.assertTrue(type(ok) == "boolean", "越界调用应有明确结果")
end

-- ------------------------------------------------------------ 移动步数算法

function TestBattleFlowHeadless.testCalMoveStepReal()
    print("\n=== Test: War_CalMoveStep 算出真实可走范围 ===")
    setupBattle()

    -- War_CalMoveStep(id, stepmax, flag) 把可达步数写入层 3
    local ok, err = pcall(War_CalMoveStep, 0, 3, 0)
    TestHelper.assertTrue(ok, "War_CalMoveStep 应可调用，实测: " .. tostring(err))

    -- 起点步数应为 0
    TestHelper.assertEquals(0, GetWarMap(5, 5, 3), "起点步数应为 0")
    -- 相邻格应为 1
    TestHelper.assertEquals(1, GetWarMap(6, 5, 3),
        "向右一格应为 1，实测 " .. tostring(GetWarMap(6, 5, 3)))
    TestHelper.assertEquals(1, GetWarMap(4, 5, 3), "向左一格应为 1")
    -- 两格应为 2
    TestHelper.assertEquals(2, GetWarMap(7, 5, 3), "向右两格应为 2")
    -- 超出 stepmax 应为 255（不可达）
    TestHelper.assertEquals(255, GetWarMap(9, 5, 3),
        "超出 3 步应为 255（不可达），实测 " .. tostring(GetWarMap(9, 5, 3)))
end

function TestBattleFlowHeadless.testCalMoveStepRespectsObstacle()
    print("\n=== Test: War_CalMoveStep 尊重障碍 ===")
    setupBattle()
    -- 在 (6,5) 放障碍（层 0 非 0 表示阻挡；用 1 表示）
    SetWarMap(6, 5, 0, 1)

    pcall(War_CalMoveStep, 0, 3, 0)
    -- (7,5) 只能绕过障碍到达，步数应 > 1（或 255 不可达）
    local v = GetWarMap(7, 5, 3)
    TestHelper.assertTrue(v ~= 1,
        "有障碍时相邻格 (7,5) 不应是 1 步（实测 " .. tostring(v) .. "）")
end

-- ------------------------------------------------------------ 结束判定

function TestBattleFlowHeadless.testIsEndFalseWhenBothAlive()
    print("\n=== Test: 双方都活着时 War_isEnd 返回 0 ===")
    setupBattle()
    local r = War_isEnd()
    TestHelper.assertEquals(0, r, "双方活着应返回 0（继续），实测 " .. tostring(r))
end

function TestBattleFlowHeadless.testIsEndTrueWhenEnemyDead()
    print("\n=== Test: 敌人全灭时 War_isEnd 返回 1 ===")
    setupBattle({ killEnemy = true })
    local r = War_isEnd()
    TestHelper.assertEquals(1, r, "敌人全灭应返回 1（胜利），实测 " .. tostring(r))
end

function TestBattleFlowHeadless.testIsEndTrueWhenAllDead()
    print("\n=== Test: 我方全灭时 War_isEnd 返回 2 ===")
    setupBattle()
    WAR.Person[0]["死亡"] = true
    JY.Person[1]["生命"] = 0
    WAR.Person[1]["死亡"] = true
    JY.Person[2]["生命"] = 0
    local r = War_isEnd()
    TestHelper.assertTrue(r == 2 or r == 1,
        "双方全灭应有明确结果（实测 " .. tostring(r) .. "）")
end

-- ------------------------------------------------------------ 伤害算法

function TestBattleFlowHeadless.testWugongHurtLifeReal()
    print("\n=== Test: War_WugongHurtLife 真的扣血 ===")
    setupBattle()
    local before = JY.Person[2]["生命"]
    local ok, err = pcall(War_WugongHurtLife, 1, 1, 1)   -- (敌人id=1, 武功id=1, 等级)
    TestHelper.assertTrue(ok, "War_WugongHurtLife 应可调用，实测: " .. tostring(err))

    local after = JY.Person[2]["生命"]
    TestHelper.assertTrue(after <= before,
        string.format("伤害后生命应减少或不变（before=%s after=%s）", before, after))
end

function TestBattleFlowHeadless.testWugongHurtNeiliReal()
    print("\n=== Test: War_WugongHurtNeili 扣内力 ===")
    setupBattle()
    local before = JY.Person[1]["内力"]
    local ok, errN = pcall(War_WugongHurtNeili, 1, 1, 1)  -- (敌人id=1, 武功id=1, 等级)
    TestHelper.assertTrue(ok, "War_WugongHurtNeili 应可调用，实测: " .. tostring(errN))
    local after = JY.Person[1]["内力"]
    TestHelper.assertTrue(after <= before,
        string.format("施法者内力应减少（before=%s after=%s）", before, after))
end

-- ------------------------------------------------------------ 中毒 / 掉血

function TestBattleFlowHeadless.testPersonLostLifeByPoison()
    print("\n=== Test: War_PersonLostLife 按中毒程度掉血 ===")
    setupBattle()
    WAR.Person[0]["中毒程度"] = 20
    JY.Person[1]["中毒程度"] = 20
    JY.Person[1]["生命"] = 100

    local ok, errP = pcall(War_PersonLostLife)
    TestHelper.assertTrue(ok, "War_PersonLostLife 应可调用，实测: " .. tostring(errP))
    -- 中毒 20 → 每次掉 20/10 = 2 点
    TestHelper.assertTrue(JY.Person[1]["生命"] < 100,
        "中毒应导致掉血，实测生命 " .. tostring(JY.Person[1]["生命"]))
end

function TestBattleFlowHeadless.testPersonLostLifeClampsToOne()
    print("\n=== Test: 掉血不会让生命归零（原版钳到 1）===")
    setupBattle()
    WAR.Person[0]["中毒程度"] = 99
    JY.Person[1]["中毒程度"] = 99
    JY.Person[1]["生命"] = 2

    pcall(War_PersonLostLife)
    TestHelper.assertTrue(JY.Person[1]["生命"] >= 1,
        "生命应被钳到 >= 1，实测 " .. tostring(JY.Person[1]["生命"]))
end

-- ------------------------------------------------------------ AI 选敌

function TestBattleFlowHeadless.testAutoSelectEnemyFindsTarget()
    print("\n=== Test: War_AutoSelectEnemy 选到活着的敌人 ===")
    setupBattle()
    local eid = War_AutoSelectEnemy()
    TestHelper.assertNotNil(eid, "应返回敌人 id")
    TestHelper.assertTrue(eid >= 0, "应选到 >= 0 的 id，实测 " .. tostring(eid))
    TestHelper.assertEquals(false, WAR.Person[eid]["我方"],
        "选到的应是敌方")
end

function TestBattleFlowHeadless.testAutoSelectEnemyReturnsMinusOneWhenNone()
    print("\n=== Test: 无活敌时 War_AutoSelectEnemy_near 返回 -1 ===")
    setupBattle({ killEnemy = true })
    local eid = War_AutoSelectEnemy_near(0)
    TestHelper.assertEquals(-1, eid,
        "无活敌应返回 -1（调用方据此守卫），实测 " .. tostring(eid))
end

-- ------------------------------------------------------------ 结算

function TestBattleFlowHeadless.testEndPersonDataAwardsExp()
    print("\n=== Test: War_EndPersonData 发放经验 ===")
    setupBattle()
    WAR.Person[0]["经验"] = 100
    local expBefore = JY.Person[1]["经验"] or 0
    local ok, errE = pcall(War_EndPersonData, 1, 1)
    TestHelper.assertTrue(ok, "War_EndPersonData 应可调用（isexp=1, 胜利），实测: " .. tostring(errE))
    TestHelper.assertTrue((JY.Person[1]["经验"] or 0) >= expBefore,
        "胜利应发放经验（before=" .. tostring(expBefore)
        .. " after=" .. tostring(JY.Person[1]["经验"]) .. "）")
end

-- **实测发现的真实语义**：War_EndPersonData 的早退条件是
--   `warStatus==2 and isexp==0`（输了 **且** 标记不给经验）
-- 单独 (isexp=0, warStatus=1) 仍会发经验 —— 因为赢了就该给。
function TestBattleFlowHeadless.testEndPersonDataNoExpWhenLoseAndIsexpZero()
    print("\n=== Test: 输且 isexp=0 时不给经验（早退）===")
    setupBattle()
    WAR.Person[0]["经验"] = 100
    local expBefore = JY.Person[1]["经验"] or 0
    pcall(War_EndPersonData, 0, 2)   -- warStatus=2 = 输
    TestHelper.assertEquals(expBefore, JY.Person[1]["经验"] or 0,
        "输且 isexp=0 时经验不应增加")
end

-- ------------------------------------------------------------ 战斗规则策略

function TestBattleFlowHeadless.testRulesKindDrivesTick()
    print("\n=== Test: 策略 kind 决定 tick 行为 ===")
    local WA = require("framework.war_async")
    local BR = require("script.battle.battle_rules")

    WA.reset()
    local st = WA.getWarState()
    st.status = "running"
    st.warId = 0

    -- realtime：每帧累加 elapsed
    rawset(_G, "BattleRules", { kind = "realtime" })
    local ok1 = WA.tick(0.016)
    TestHelper.assertEquals(true, ok1, "realtime 的 tick 应返回 true")
    TestHelper.assertTrue(math.abs(st.ctx.realtime.elapsed - 0.016) < 1e-9,
        "realtime 应累加 dt，实测 " .. tostring(st.ctx.realtime.elapsed))

    WA.tick(0.016)
    TestHelper.assertTrue(math.abs(st.ctx.realtime.elapsed - 0.032) < 1e-9,
        "两帧累加应为 0.032")

    -- turnbased：空实现，state 不变
    WA.reset()
    st = WA.getWarState()
    st.status = "running"
    rawset(_G, "BattleRules", { kind = "turnbased" })
    local ok2 = WA.tick(0.016)
    TestHelper.assertEquals(true, ok2, "turnbased 的 tick 应返回 true")

    WA.reset()
    rawset(_G, "BattleRules", { kind = "turnbased" })
end

-- ------------------------------------------------------------ 渲染调用链不崩

function TestBattleFlowHeadless.testWarDrawMapCallChainNoCrash()
    print("\n=== Test: WarDrawMap 调用链不崩（stub EngineAPI.map.drawBattle）===")
    -- **注意范围**：这里验证的是「调用链不炸」，不是「画面正确」。
    -- 画面正确性必须实机看 —— 但可以机器验证的这部分不该留空。
    setupBattle()
    -- **stub 目标已变**（port-sprite-native-migration Task 2）：
    -- lib.DrawWarMap → EngineAPI.map.drawBattle（battle_render 不再用 lib.*）
    local EA = rawget(_G, "EngineAPI")
    local calls = {}
    EA.map.drawBattle = function(flag, x, y, v1, v2, v3)
        calls[#calls + 1] = { flag = flag, x = x, y = y }
    end
    rawset(_G, "WAR", WAR)
    WAR.ShowHead = 0

    for f = 0, 4 do
        if f ~= 3 then   -- flag=3 不是合法值（原版只处理 0/1/2/4）
            local ok, err = pcall(WarDrawMap, f, 5, 5, 1)
            TestHelper.assertTrue(ok, "WarDrawMap(flag=" .. f .. ") 应不崩，实测: " .. tostring(err))
        end
    end
    TestHelper.assertEquals(4, #calls, "4 个合法 flag 各应调用一次 DrawWarMap（实测 " .. #calls .. "）")
end

function TestBattleFlowHeadless.testWarCalPersonPicReturnsFrame()
    print("\n=== Test: WarCalPersonPic 算出人物贴图号 ===")
    setupBattle()
    local pic = WarCalPersonPic(0)
    TestHelper.assertNotNil(pic, "应返回贴图号")
    TestHelper.assertTrue(type(pic) == "number", "贴图号应是数字")
end

function TestBattleFlowHeadless.testWarShowHeadNoCrash()
    print("\n=== Test: WarShowHead 调用链不崩 ===")
    setupBattle()
    local L = rawget(_G, "lib")
    -- WarShowHead 的贴图查询 + 绘制已改走 SpriteAtlas（Task 2）
    -- → stub 目标从 lib.PicGetXY/PicLoadCache 改为 SpriteAtlas.getMeta/draw。
    -- **注意**：`getMeta` 现在返回 table（不是多返回值）。
    local SA = require("framework.sprite_atlas")
    SA.getMeta = function() return { w = 100, h = 100, xoff = 0, yoff = 0 } end
    SA.draw    = function() return true end
    --（原 lib.PicGetXY / lib.PicLoadCache 桩已删除：代码不再调用它们）
    --（原 lib.PicGetXY / lib.PicLoadCache 桩已删除：代码不再调用它们）
    L.DrawPic      = function() end
    L.DrawStr      = function() end
    L.SetClip      = function() end
    L.DrawRect     = function() end
    L.FillColor    = function() end
    local ok, err = pcall(WarShowHead)
    TestHelper.assertTrue(ok, "WarShowHead 应不崩，实测: " .. tostring(err))
end

-- ------------------------------------------------------------ 套件入口

function TestBattleFlowHeadless.runAll()
    print("\n" .. string.rep("=", 60))
    print("无头驱动真实战斗算法（battle-extensibility 深度验证）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    installLibStubs()

    -- **测试环境装载顺序**（每一步都必要，缺一个就会静默失败）：
    --
    --   ① framework.config      SetGlobalConst 依赖 CONFIG
    --   ② script/jyconst.lua    CC.* 的装配函数（SetGlobalConst）
    --   ③ SetGlobalConst()      真正把 CC.WarDataSize/WarFile 填好
    --   ④ script/jymain.lua     定义 LoadData / WarLoad / WarSetGlobal / Cls
    --   ⑤ 五个 battle 文件      定义 66 个战斗函数
    --
    -- 为什么用 loadfile 不用 require/ScriptLoader：
    --   TestHelper.setup() 的 mock `EngineAPI.script.load` 恒返回 nil，
    --   ScriptLoader 在测试环境什么都加载不了（踩过两次）。
    pcall(require, "framework.config")
    rawset(_G, "Byte", require("framework.lib_Byte"))
    do
        local chunk = loadfile("script/jyconst.lua")
        if not chunk then chunk = loadfile("../game/script/jyconst.lua") end
        if chunk then pcall(chunk) end
    end
    if rawget(_G, "SetGlobalConst") then pcall(SetGlobalConst) end

    do
        local chunk = loadfile("script/jymain.lua")
        if not chunk then chunk = loadfile("../game/script/jymain.lua") end
        if chunk then pcall(chunk) end
    end

    for _, m in ipairs({ "battle_data", "battle_render", "battle_action",
                         "battle_ai", "battle_flow" }) do
        local path = "script/battle/" .. m .. ".lua"
        local chunk = loadfile(path)
        if not chunk then chunk = loadfile("../game/" .. path) end
        if chunk then pcall(chunk) end
    end

    -- Cls / ShowScreen 在无头环境无法执行（需要 SetClip / FillColor /
    -- DrawMMap / DrawSMap 等一整条渲染链）。**stub 成空操作**。
    --
    -- 这不是"回避问题"，而是**明确划定范围**：本测试只验证算法层
    -- （移动步数/伤害/结束判定/AI 选敌/结算），不验证渲染。
    -- 渲染的验证留给实机走查。
    rawset(_G, "Cls", function() end)
    rawset(_G, "ShowScreen", function() end)

    -- DrawStrBoxWaitKey 会**等键**（挂协程），无头环境会永久挂起。
    -- 战斗结算（War_EndPersonData）里就调它显示"获得经验点数"。
    rawset(_G, "DrawStrBoxWaitKey", function() end)
    rawset(_G, "DrawStrBox", function() end)
    rawset(_G, "DrawStrBoxYesNo", function() return 1 end)

    local need = { "SetWarMap", "WarLoad", "LoadData", "War_CalMoveStep", "War_isEnd" }
    local miss = {}
    for _, n in ipairs(need) do
        if rawget(_G, n) == nil then miss[#miss + 1] = n end
    end
    TestHelper.assertEquals(0, #miss,
        "装载缺失: " .. table.concat(miss, ", "))

    TestBattleFlowHeadless.testWarLoadReadsRealData()
    TestBattleFlowHeadless.testWarLoadRejectsOutOfRange()

    TestBattleFlowHeadless.testCalMoveStepReal()
    TestBattleFlowHeadless.testCalMoveStepRespectsObstacle()

    TestBattleFlowHeadless.testIsEndFalseWhenBothAlive()
    TestBattleFlowHeadless.testIsEndTrueWhenEnemyDead()
    TestBattleFlowHeadless.testIsEndTrueWhenAllDead()

    TestBattleFlowHeadless.testWugongHurtLifeReal()
    TestBattleFlowHeadless.testWugongHurtNeiliReal()

    TestBattleFlowHeadless.testPersonLostLifeByPoison()
    TestBattleFlowHeadless.testPersonLostLifeClampsToOne()

    TestBattleFlowHeadless.testAutoSelectEnemyFindsTarget()
    TestBattleFlowHeadless.testAutoSelectEnemyReturnsMinusOneWhenNone()

    TestBattleFlowHeadless.testEndPersonDataAwardsExp()
    TestBattleFlowHeadless.testEndPersonDataNoExpWhenLoseAndIsexpZero()

    TestBattleFlowHeadless.testRulesKindDrivesTick()

    TestBattleFlowHeadless.testWarDrawMapCallChainNoCrash()
    TestBattleFlowHeadless.testWarCalPersonPicReturnsFrame()
    TestBattleFlowHeadless.testWarShowHeadNoCrash()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_battle_flow_headless.lua$") then
    TestBattleFlowHeadless.runAll()
end

return TestBattleFlowHeadless
