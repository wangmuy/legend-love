-- test_interact.lua
-- 交互目标（不可站立但可交互）的测试（REQ-MS3-6）
--
-- 覆盖两条同构路径：
--   大地图 → CanEnterScene（进场景）
--   小场景 → GetS(...,3) + GetD(...,0)（触发事件）

local TestHelper = require("tests.test_helper")
local TestInteract = {}

local function freshInteract()
    package.loaded["framework.interact"] = nil
    return require("framework.interact")
end

local function installGlobals(opts)
    opts = opts or {}
    local saved = {
        JY = rawget(_G, "JY"),
        CC = rawget(_G, "CC"),
        GetS = rawget(_G, "GetS"),
        GetD = rawget(_G, "GetD"),
        CanEnterScene = rawget(_G, "CanEnterScene"),
        EventExecuteSync = rawget(_G, "EventExecuteSync"),
        GetMyPic = rawget(_G, "GetMyPic"),
        lib = rawget(_G, "lib"),
    }
    rawset(_G, "JY", {
        SubScene = opts.subScene or 1,
        SubSceneX = 0, SubSceneY = 0,
        MyPic = 0, MmapMusic = 0,
        Base = { ["人X"] = opts.px or 10, ["人Y"] = opts.py or 10,
                 ["人X1"] = opts.px or 10, ["人Y1"] = opts.py or 10,
                 ["人方向"] = 0 },
        oldSMapX = -1, oldSMapY = -1,
    })
    rawset(_G, "lib", { Debug = function() end })
    rawset(_G, "GetMyPic", function() return 2494 end)
    return saved
end

local function restoreGlobals(saved)
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

-- ============================================================
-- directionOf
-- ============================================================

function TestInteract.testDirectionOf()
    print("\n=== Test: 位移 → 方向码 ===")
    local I = freshInteract()
    TestHelper.assertEquals(0, I.directionOf(0, -1), "上 = 0")
    TestHelper.assertEquals(1, I.directionOf(1, 0), "右 = 1")
    TestHelper.assertEquals(2, I.directionOf(-1, 0), "左 = 2")
    TestHelper.assertEquals(3, I.directionOf(0, 1), "下 = 3")
    TestHelper.assertEquals(nil, I.directionOf(1, 1), "斜向 = nil")
    TestHelper.assertEquals(nil, I.directionOf(0, 0), "原地 = nil")
end

-- ============================================================
-- probe：大地图
-- ============================================================

function TestInteract.testProbeScene()
    print("\n=== Test: 大地图识别可进入的场景 ===")
    local I = freshInteract()
    rawset(_G, "CanEnterScene", function(x, y)
        if x == 50 and y == 60 then return 7 end
        return -1
    end)

    local kind, payload = I.probe("MMAP", 50, 60)
    TestHelper.assertEquals("scene", kind, "识别为场景")
    TestHelper.assertEquals(7, payload, "场景 id 透传")

    local k2 = I.probe("MMAP", 51, 61)
    TestHelper.assertEquals(nil, k2, "普通格不是交互目标")
end

function TestInteract.testProbeSceneRespectsCondition()
    print("\n=== Test: 场景进入条件被尊重（不自行重写）===")
    local I = freshInteract()
    -- CanEnterScene 内部已处理「进入条件=1 不可进」；这里模拟它返回 -1
    rawset(_G, "CanEnterScene", function() return -1 end)
    local kind = I.probe("MMAP", 50, 60)
    TestHelper.assertEquals(nil, kind,
        "不可进的门不是交互目标（复用 CanEnterScene 的判定）")
end

-- ============================================================
-- probe：小场景
-- ============================================================

function TestInteract.testProbeEvent()
    print("\n=== Test: 小场景识别可触发的事件 ===")
    local saved = installGlobals({ subScene = 1 })
    local I = freshInteract()
    rawset(_G, "GetS", function(scene, x, y, layer)
        if layer == 3 and x == 20 and y == 21 then return 5 end
        return -1
    end)
    rawset(_G, "GetD", function(scene, d, i)
        if i == 0 then return 0 end     -- 0 = 可通行（非障碍）
        return 0
    end)

    local kind, payload = I.probe("SMAP", 20, 21)
    TestHelper.assertEquals("event", kind, "识别为事件")
    TestHelper.assertEquals(5, payload, "事件 id 透传")
    restoreGlobals(saved)
end

function TestInteract.testProbeEventBlockedByD()
    print("\n=== Test: D* 不可通行的事件仍是交互目标（关键）===")
    local saved = installGlobals({ subScene = 1 })
    local I = freshInteract()
    rawset(_G, "GetS", function(scene, x, y, layer)
        if layer == 3 then return 12 end
        return -1
    end)
    -- D[id][0] ~= 0 = 不可通行 = 实体（NPC / 箱子 / 招牌）
    --
    -- 这正是它的特征：站不上去，所以要「站旁边交互」。
    -- 我曾把它误判成「纯障碍」而过滤掉，导致箱子打不开、NPC 不对话。
    -- 键盘 SPACE 分支不在 D 数据上做任何过滤，鼠标也不能做。
    rawset(_G, "GetD", function(scene, d, i)
        if i == 0 then return 1 end
        return 0
    end)

    local kind, payload = I.probe("SMAP", 20, 21)
    TestHelper.assertEquals("event", kind,
        "D* 不可通行的事件（箱子/NPC）必须能被识别为交互目标")
    TestHelper.assertEquals(12, payload, "事件 id 透传")
    restoreGlobals(saved)
end

function TestInteract.testProbePureObstacleNotTarget()
    print("\n=== Test: 纯障碍（无事件层）不是交互目标 ===")
    local saved = installGlobals({ subScene = 1 })
    local I = freshInteract()
    -- 墙：事件层为 -1，说明没有任何事件挂在这里
    rawset(_G, "GetS", function(scene, x, y, layer)
        if layer == 3 then return -1 end
        return 1
    end)
    rawset(_G, "GetD", function() return 0 end)

    local kind = I.probe("SMAP", 20, 21)
    TestHelper.assertEquals(nil, kind,
        "没有事件数据的墙不是交互目标（该红闪）")
    restoreGlobals(saved)
end

function TestInteract.testProbeNoEvent()
    print("\n=== Test: 没有事件的格子 ===")
    local saved = installGlobals({ subScene = 1 })
    local I = freshInteract()
    rawset(_G, "GetS", function() return -1 end)
    rawset(_G, "GetD", function() return 0 end)
    local kind = I.probe("SMAP", 20, 21)
    TestHelper.assertEquals(nil, kind, "无事件 → nil")
    restoreGlobals(saved)
end

-- ============================================================
-- findApproach
-- ============================================================

function TestInteract.testFindApproachSingle()
    print("\n=== Test: 找唯一的可走邻格 ===")
    local I = freshInteract()
    local ax, ay = I.findApproach(10, 10, function(x, y)
        return x == 9 and y == 10
    end)
    TestHelper.assertEquals(9, ax, "x")
    TestHelper.assertEquals(10, ay, "y")
end

function TestInteract.testFindApproachPrefersNearOrigin()
    print("\n=== Test: 距离相同时选离起点近的 ===")
    local I = freshInteract()
    -- 左右都可走，起点在右侧 → 应选右侧
    local ax, ay = I.findApproach(10, 10, function(x, y)
        return (x == 9 and y == 10) or (x == 11 and y == 10)
    end, 20, 10)
    TestHelper.assertEquals(11, ax, "选右侧（离起点近）")
end

function TestInteract.testFindApproachRadius()
    print("\n=== Test: 半径 2 内能找到 ===")
    local I = freshInteract()
    local ax = I.findApproach(10, 10, function(x, y)
        return x == 8 and y == 10
    end)
    TestHelper.assertEquals(8, ax, "半径 2 找到")
end

function TestInteract.testFindApproachTooFar()
    print("\n=== Test: 超出半径返回 nil ===")
    local I = freshInteract()
    local ax = I.findApproach(10, 10, function(x, y)
        return x == 7 and y == 10
    end)
    TestHelper.assertEquals(nil, ax, "半径 3 超出上限 → nil")
end

function TestInteract.testFindApproachNoWalkable()
    print("\n=== Test: 周围全不可走 ===")
    local I = freshInteract()
    local ax = I.findApproach(10, 10, function() return false end)
    TestHelper.assertEquals(nil, ax, "全不可走 → nil")
end

-- ============================================================
-- trigger
-- ============================================================

function TestInteract.testTriggerSceneFacesTarget()
    print("\n=== Test: 触发场景时先面朝目标 ===")
    local saved = installGlobals({ px = 10, py = 10 })
    local I = freshInteract()

    rawset(_G, "CanEnterScene", function(x, y)
        if x == 10 and y == 11 then return 3 end
        return -1
    end)
    local entered = nil
    package.loaded["framework.game_states"] = nil
    local GS = require("framework.game_states")
    GS._enterSubScene = function(id) entered = id end

    local ok = I.trigger("MMAP", 10, 11)   -- 目标在自己下方
    TestHelper.assertTrue(ok, "触发成功")
    TestHelper.assertEquals(3, entered, "调用了 enterSubScene(3)")
    TestHelper.assertEquals(3, rawget(_G, "JY").Base["人方向"],
        "面朝下方（3），与键盘按 SPACE 一致")
    restoreGlobals(saved)
end

function TestInteract.testTriggerRequiresAdjacent()
    print("\n=== Test: 必须相邻才能触发 ===")
    local saved = installGlobals({ px = 10, py = 10 })
    local I = freshInteract()
    rawset(_G, "CanEnterScene", function() return 3 end)

    local ok = I.trigger("MMAP", 15, 10)   -- 距离 5
    TestHelper.assertFalse(ok, "不相邻 → 不触发（防止隔空进门）")
    restoreGlobals(saved)
end

function TestInteract.testTriggerEvent()
    print("\n=== Test: 触发场景内事件 ===")
    local saved = installGlobals({ px = 20, py = 20 })
    local I = freshInteract()

    rawset(_G, "GetS", function(scene, x, y, layer)
        if layer == 3 and x == 20 and y == 21 then return 9 end
        return -1
    end)
    rawset(_G, "GetD", function() return 0 end)

    local executed = nil
    rawset(_G, "EventExecuteSync", function(id, flag)
        executed = { id = id, flag = flag }
    end)

    local ok = I.trigger("SMAP", 20, 21)
    TestHelper.assertTrue(ok, "触发成功")
    TestHelper.assertEquals(9, executed.id, "执行了事件 9")
    TestHelper.assertEquals(1, executed.flag, "flag=1（与键盘 SPACE 一致）")
    restoreGlobals(saved)
end

-- ============================================================
-- plan（组合）
-- ============================================================

function TestInteract.testPlanScene()
    print("\n=== Test: plan 返回接近点 ===")
    local I = freshInteract()
    rawset(_G, "CanEnterScene", function(x, y)
        if x == 50 and y == 60 then return 2 end
        return -1
    end)

    local walkable = function(x, y) return x == 50 and y == 61 end
    local plan = I.plan("MMAP", 50, 60, 50, 55, walkable)

    TestHelper.assertNotNil(plan, "有方案")
    TestHelper.assertEquals("scene", plan.kind, "kind")
    TestHelper.assertEquals(2, plan.payload, "场景 id")
    TestHelper.assertEquals(50, plan.ax, "接近点 x")
    TestHelper.assertEquals(61, plan.ay, "接近点 y")
end

function TestInteract.testPlanNilForPlainTile()
    print("\n=== Test: 普通格没有交互方案 ===")
    local I = freshInteract()
    rawset(_G, "CanEnterScene", function() return -1 end)
    local plan = I.plan("MMAP", 50, 60, 50, 55, function() return true end)
    TestHelper.assertEquals(nil, plan, "普通格 → nil")
end

function TestInteract.runAll()
    print("\n" .. string.rep("=", 60))
    print("交互目标测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestInteract.testDirectionOf()

    TestInteract.testProbeScene()
    TestInteract.testProbeSceneRespectsCondition()
    TestInteract.testProbeEvent()
    TestInteract.testProbeEventBlockedByD()
    TestInteract.testProbePureObstacleNotTarget()
    TestInteract.testProbeNoEvent()

    TestInteract.testFindApproachSingle()
    TestInteract.testFindApproachPrefersNearOrigin()
    TestInteract.testFindApproachRadius()
    TestInteract.testFindApproachTooFar()
    TestInteract.testFindApproachNoWalkable()

    TestInteract.testTriggerSceneFacesTarget()
    TestInteract.testTriggerRequiresAdjacent()
    TestInteract.testTriggerEvent()

    TestInteract.testPlanScene()
    TestInteract.testPlanNilForPlainTile()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_interact.lua$") then
    TestInteract.runAll()
end

return TestInteract
