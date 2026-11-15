-- test_pathfind.lua
-- A* 寻路的单元测试（REQ-MS3-3 / REQ-MS3-4）
--
-- pathfind.lua 是纯算法（零引擎依赖），可以用合成地图完全测试。

local TestHelper = require("tests.test_helper")
local TestPathfind = {}

local Pathfind = require("framework.pathfind")

--- 用一组"墙"坐标构造 isWalkable
-- @param walls table { ["x,y"] = true }
-- @param w, h number 地图范围
local function makeWalkable(walls, w, h)
    w = w or 20
    h = h or 20
    walls = walls or {}
    return function(x, y)
        if x < 0 or y < 0 or x >= w or y >= h then return false end
        return not walls[x .. "," .. y]
    end
end

-- ============================================================
-- 基础路径
-- ============================================================

function TestPathfind.testStraightLine()
    print("\n=== Test: 直线路径 ===")
    local path = Pathfind.find(0, 0, 5, 0, makeWalkable())
    TestHelper.assertNotNil(path, "能找到路径")
    TestHelper.assertEquals(6, #path, "5 步 → 6 个点（含起点）")
    TestHelper.assertEquals(0, path[1].x, "起点 x")
    TestHelper.assertEquals(0, path[1].y, "起点 y")
    TestHelper.assertEquals(5, path[#path].x, "终点 x")
    TestHelper.assertEquals(0, path[#path].y, "终点 y")
end

function TestPathfind.testPathIsContiguous()
    print("\n=== Test: 路径连续（每步只走一格）===")
    local path = Pathfind.find(2, 2, 10, 10, makeWalkable())
    TestHelper.assertNotNil(path, "能找到路径")
    for i = 2, #path do
        local dx = math.abs(path[i].x - path[i - 1].x)
        local dy = math.abs(path[i].y - path[i - 1].y)
        TestHelper.assertEquals(1, dx + dy,
            "第 " .. i .. " 步只能移动一格（曼哈顿距离 1）")
    end
end

function TestPathfind.testStartEqualsGoal()
    print("\n=== Test: 起点等于终点 ===")
    local path = Pathfind.find(5, 5, 5, 5, makeWalkable())
    TestHelper.assertNotNil(path, "返回路径而不是 nil")
    TestHelper.assertEquals(1, #path, "只含起点")
    TestHelper.assertEquals(5, path[1].x, "坐标正确")
end

function TestPathfind.testSingleStep()
    print("\n=== Test: 单步 ===")
    local path = Pathfind.find(0, 0, 0, 1, makeWalkable())
    TestHelper.assertNotNil(path, "能找到")
    TestHelper.assertEquals(2, #path, "2 个点")
end

-- ============================================================
-- 绕障
-- ============================================================

function TestPathfind.testAvoidObstacle()
    print("\n=== Test: 绕开障碍 ===")
    -- 在 (1,0) 放一堵墙，从 (0,0) 到 (2,0) 必须绕
    local walls = { ["1,0"] = true }
    local path = Pathfind.find(0, 0, 2, 0, makeWalkable(walls))
    TestHelper.assertNotNil(path, "能找到绕行路径")
    TestHelper.assertTrue(#path > 3, "路径比直线长（绕路了）")
    -- 路径上不能有墙
    for _, p in ipairs(path) do
        TestHelper.assertTrue(walls[p.x .. "," .. p.y] == nil,
            "路径不含墙 (" .. p.x .. "," .. p.y .. ")")
    end
end

function TestPathfind.testAvoidWallLine()
    print("\n=== Test: 绕过一堵长墙 ===")
    local walls = {}
    for y = -1, 5 do walls["3," .. y] = true end
    local path = Pathfind.find(0, 0, 6, 0, makeWalkable(walls))
    TestHelper.assertNotNil(path, "能找到绕行路径")
    for _, p in ipairs(path) do
        TestHelper.assertTrue(walls[p.x .. "," .. p.y] == nil, "不穿墙")
    end
end

-- ============================================================
-- 失败情形
-- ============================================================

function TestPathfind.testGoalUnwalkable()
    print("\n=== Test: 终点不可站立 ===")
    local walls = { ["5,5"] = true }
    local path, err = Pathfind.find(0, 0, 5, 5, makeWalkable(walls))
    TestHelper.assertEquals(nil, path, "返回 nil")
    TestHelper.assertEquals("goal-unwalkable", err, "原因是终点不可站立")
end

function TestPathfind.testNoPathIsolated()
    print("\n=== Test: 完全隔离（无路）===")
    -- 把 (5,5) 用墙围死
    local walls = {
        ["4,5"] = true, ["6,5"] = true, ["5,4"] = true, ["5,6"] = true,
    }
    local path, err = Pathfind.find(0, 0, 5, 5, makeWalkable(walls))
    TestHelper.assertEquals(nil, path, "返回 nil")
    TestHelper.assertEquals("no-path", err, "原因是不连通")
end

function TestPathfind.testExceededMaxNodes()
    print("\n=== Test: 超过 maxNodes 上限 ===")
    -- 目标放在一个被完全隔离的小区域，maxNodes 设很小
    local walls = {
        ["4,5"] = true, ["6,5"] = true, ["5,4"] = true, ["5,6"] = true,
    }
    local path, err = Pathfind.find(0, 0, 5, 5, makeWalkable(walls), { maxNodes = 10 })
    TestHelper.assertEquals(nil, path, "返回 nil")
    TestHelper.assertEquals("exceeded-max-nodes", err, "原因是超过上限")
end

function TestPathfind.testBadArgs()
    print("\n=== Test: 非法参数 ===")
    local p1, e1 = Pathfind.find(nil, 0, 5, 5, makeWalkable())
    TestHelper.assertEquals(nil, p1, "nil 起点返回 nil")
    TestHelper.assertEquals("bad-args", e1, "原因是参数非法")

    local p2, e2 = Pathfind.find(0, 0, 5, 5, nil)
    TestHelper.assertEquals(nil, p2, "nil isWalkable 返回 nil")
    TestHelper.assertEquals("bad-args", e2, "原因是参数非法")
end

-- ============================================================
-- 最优性
-- ============================================================

function TestPathfind.testPathIsShortest()
    print("\n=== Test: 路径是最短的 ===")
    -- 无障碍时，路径长度应等于曼哈顿距离 + 1
    local path = Pathfind.find(0, 0, 4, 3, makeWalkable())
    TestHelper.assertEquals(4 + 3 + 1, #path,
        "无阻碍时路径点数 = 曼哈顿距离 + 1")
end

function TestPathfind.testNegativeCoordinates()
    print("\n=== Test: 负坐标 ===")
    local wf = function(x, y)
        return x >= -10 and x <= 10 and y >= -10 and y <= 10
    end
    local path = Pathfind.find(-5, -3, 2, 4, wf)
    TestHelper.assertNotNil(path, "负坐标也能寻路")
    TestHelper.assertEquals(-5, path[1].x, "起点 x")
    TestHelper.assertEquals(-3, path[1].y, "起点 y")
    TestHelper.assertEquals(2, path[#path].x, "终点 x")
end

-- ============================================================
-- 性能（REQ-MS3-4）
-- ============================================================

function TestPathfind.testPerformanceVisibleRange()
    print("\n=== Test: 可见范围（约 2400 格）的性能 ===")
    -- 用 50x50 的无障碍地图（2500 格）模拟可见范围
    local wf = makeWalkable({}, 50, 50)
    local t0 = os.clock()
    local path = Pathfind.find(0, 0, 45, 45, wf)
    local elapsed = (os.clock() - t0) * 1000

    TestHelper.assertNotNil(path, "能找到路径")
    TestHelper.assertTrue(elapsed < 200,
        string.format("可见范围寻路 < 200ms（实际 %.1f ms）", elapsed))
    print(string.format("  → 实际耗时 %.2f ms，路径 %d 点", elapsed, #path))
end

function TestPathfind.testPerformanceBlockedSearch()
    print("\n=== Test: 阻断搜索的性能（maxNodes 生效）===")
    -- 50x50 全开放，但目标被围死 → 要搜完 2500 格才能确认
    local walls = {
        ["46,46"] = true, ["44,46"] = true, ["45,45"] = true, ["45,47"] = true,
    }
    local wf = makeWalkable(walls, 50, 50)
    local t0 = os.clock()
    local path, err = Pathfind.find(0, 0, 45, 46, wf)
    local elapsed = (os.clock() - t0) * 1000

    TestHelper.assertEquals(nil, path, "不可达")
    TestHelper.assertEquals("no-path", err, "真实不连通（未超上限）")
    TestHelper.assertTrue(elapsed < 500,
        string.format("阻断搜索 < 500ms（实际 %.1f ms）", elapsed))
    print(string.format("  → 实际耗时 %.2f ms（搜索了整张 50x50 图）", elapsed))
end

function TestPathfind.runAll()
    print("\n" .. string.rep("=", 60))
    print("A* 寻路测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestPathfind.testStraightLine()
    TestPathfind.testPathIsContiguous()
    TestPathfind.testStartEqualsGoal()
    TestPathfind.testSingleStep()

    TestPathfind.testAvoidObstacle()
    TestPathfind.testAvoidWallLine()

    TestPathfind.testGoalUnwalkable()
    TestPathfind.testNoPathIsolated()
    TestPathfind.testExceededMaxNodes()
    TestPathfind.testBadArgs()

    TestPathfind.testPathIsShortest()
    TestPathfind.testNegativeCoordinates()

    TestPathfind.testPerformanceVisibleRange()
    TestPathfind.testPerformanceBlockedSearch()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_pathfind.lua$") then
    TestPathfind.runAll()
end

return TestPathfind
