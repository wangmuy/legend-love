-- test_battle_mouse.lua
-- 战斗中鼠标支持（REQ-MS4-1）
--
-- 关键区别：
--   地图点击 → A* 找路 → 逐步移动主角
--   战斗点击 → 挪光标（WAR.MoveCursorX/Y）→ 注入空格确认
--
-- 两者坐标反解公式相同（同一套等轴 i1/j1），
-- 但相机不同：战斗相机 = WAR.Person[WAR.CurID].坐标X/Y。

local TestHelper = require("tests.test_helper")
local TestBattleMouse = {}

local function installStubs(opts)
    opts = opts or {}
    local saved = {
        CC = rawget(_G, "CC"),
        JY = rawget(_G, "JY"),
        WAR = rawget(_G, "WAR"),
        GAME_MMAP = rawget(_G, "GAME_MMAP"),
        GAME_SMAP = rawget(_G, "GAME_SMAP"),
        GAME_WMAP = rawget(_G, "GAME_WMAP"),
        VK_SPACE = rawget(_G, "VK_SPACE"),
        VK_ESCAPE = rawget(_G, "VK_ESCAPE"),
        GetWarMap = rawget(_G, "GetWarMap"),
        EngineAPI = rawget(_G, "EngineAPI"),
    }
    rawset(_G, "CC", {
        XScale = 18, YScale = 9, Width = 1024, Height = 768,
        WarWidth = 64, WarHeight = 64,
    })
    rawset(_G, "GAME_MMAP", 2)
    rawset(_G, "GAME_SMAP", 4)
    rawset(_G, "GAME_WMAP", 5)
    rawset(_G, "VK_SPACE", 32)
    rawset(_G, "VK_ESCAPE", 27)
    rawset(_G, "JY", { Status = 5 })   -- 战斗中：没有 Base 表
    rawset(_G, "WAR", {
        Person = {}, PersonNum = 1, CurID = 0,
        DrawMode = opts.drawMode or 1,
        MoveCursorX = 10, MoveCursorY = 10,
    })
    rawget(_G, "WAR").Person[0] = {
        ["坐标X"] = 10, ["坐标Y"] = 10, ["我方"] = true,
    }
    rawset(_G, "EngineAPI", {
        time = {
            getTime = function() return os.clock() * 1000 end,
            getTimeSeconds = function() return os.clock() end,
        },
    })
    return saved
end

local function restoreStubs(saved)
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

local function freshBattleMouse()
    package.loaded["framework.battle_mouse"] = nil
    package.loaded["framework.mouse_hover"] = nil
    return require("framework.battle_mouse")
end

-- ============================================================
-- 可移动范围判定
-- ============================================================

function TestBattleMouse.testIsMovable()
    print("\n=== Test: 可移动范围判定 ===")
    local saved = installStubs()

    -- War_CalMoveStep 把可达格写进第 3 层，255 = 不可达
    rawset(_G, "GetWarMap", function(x, y, layer)
        if layer ~= 3 then return 0 end
        if y == 10 and x >= 10 and x <= 12 then return x - 10 end
        if x == 10 and y == 11 then return 1 end
        return 255
    end)

    local BM = freshBattleMouse()
    TestHelper.assertTrue(BM.isMovable(11, 10), "(11,10) 可达")
    TestHelper.assertTrue(BM.isMovable(10, 10), "起点可达（第 0 步）")
    TestHelper.assertFalse(BM.isMovable(20, 20), "(20,20) 不可达")
    restoreStubs(saved)
end

-- ============================================================
-- 相机（战斗相机 = 当前行动者坐标）
-- ============================================================

function TestBattleMouse.testCameraIsActorPosition()
    print("\n=== Test: 战斗相机 = 当前行动者坐标 ===")
    local saved = installStubs()
    rawset(_G, "WAR", { Person = {}, PersonNum = 1, CurID = 0 })
    rawget(_G, "WAR").Person[0] = { ["坐标X"] = 25, ["坐标Y"] = 30 }

    package.loaded["framework.mouse_hover"] = nil
    local H = require("framework.mouse_hover")

    local cx, cy = H.camera("WMAP")
    TestHelper.assertEquals(25, cx, "相机 x = 坐标X")
    TestHelper.assertEquals(30, cy, "相机 y = 坐标Y")
    restoreStubs(saved)
end

function TestBattleMouse.testCameraWorksWithoutJYBase()
    print("\n=== Test: 战斗状态下没有 JY.Base 也能取相机 ===")
    local saved = installStubs()
    -- installStubs 里 JY 没有 Base 字段（模拟真实战斗状态）
    TestHelper.assertEquals(nil, rawget(_G, "JY").Base,
        "确认测试环境无 Base")

    package.loaded["framework.mouse_hover"] = nil
    local H = require("framework.mouse_hover")

    local cx, cy = H.camera("WMAP")
    TestHelper.assertEquals(10, cx, "仍能返回正确相机（不受 Base 缺失影响）")
    restoreStubs(saved)
end

-- ============================================================
-- 悬停 / 点击
-- ============================================================

function TestBattleMouse.testHoverMovesCursor()
    print("\n=== Test: 悬停可移动格 → 挪光标 ===")
    local saved = installStubs()
    rawset(_G, "GetWarMap", function(x, y, layer)
        if layer ~= 3 then return 0 end
        if y == 10 and x >= 10 and x <= 12 then return x - 10 end
        return 255
    end)

    local BM = freshBattleMouse()
    local H = require("framework.mouse_hover")

    local sx, sy = H.tileToScreen(11, 10, 10, 10)
    local moved = BM.hoverTo(sx, sy)

    TestHelper.assertTrue(moved, "光标移动了")
    TestHelper.assertEquals(11, rawget(_G, "WAR").MoveCursorX, "光标 x=11")
    TestHelper.assertEquals(10, rawget(_G, "WAR").MoveCursorY, "光标 y=10")
    restoreStubs(saved)
end

function TestBattleMouse.testHoverRejectsUnreachable()
    print("\n=== Test: 悬停不可达格 → 光标不动 ===")
    local saved = installStubs()
    rawset(_G, "GetWarMap", function(x, y, layer)
        if layer ~= 3 then return 0 end
        if y == 10 and x >= 10 and x <= 12 then return x - 10 end
        return 255
    end)

    local BM = freshBattleMouse()
    local H = require("framework.mouse_hover")

    local sx, sy = H.tileToScreen(20, 20, 10, 10)
    local moved = BM.hoverTo(sx, sy)

    TestHelper.assertFalse(moved, "不可达 → 不挪")
    TestHelper.assertEquals(10, rawget(_G, "WAR").MoveCursorX, "光标未变")
    restoreStubs(saved)
end

function TestBattleMouse.testHoverSameTileNoop()
    print("\n=== Test: 悬停已选中格 → 不重复 ===")
    local saved = installStubs()
    rawset(_G, "GetWarMap", function() return 0 end)

    local BM = freshBattleMouse()
    local H = require("framework.mouse_hover")

    local sx, sy = H.tileToScreen(10, 10, 10, 10)   -- 就是当前光标位置
    TestHelper.assertFalse(BM.hoverTo(sx, sy), "同格 → 不重绘")
    restoreStubs(saved)
end

function TestBattleMouse.testClickConfirmInjectsKey()
    print("\n=== Test: 点击可移动格 → 挪光标 + 注入确认键 ===")
    local saved = installStubs()
    rawset(_G, "GetWarMap", function(x, y, layer)
        if layer ~= 3 then return 0 end
        if y == 10 and x >= 10 and x <= 12 then return x - 10 end
        return 255
    end)

    local IM = require("framework.input_manager")
    IM.getInstance():init()
    IM.clearMouseQueue()

    local BM = freshBattleMouse()
    local H = require("framework.mouse_hover")

    local sx, sy = H.tileToScreen(12, 10, 10, 10)
    local handled = BM.clickAt(sx, sy)

    TestHelper.assertTrue(handled, "处理了点击")
    TestHelper.assertEquals(12, rawget(_G, "WAR").MoveCursorX, "光标移到 12")
    TestHelper.assertEquals(32, IM.getInstance():_peekKeyInternal(),
        "注入了 VK_SPACE 供 War_MoveCoroutine 确认")
    IM.getInstance():clearCurrentKey()
    restoreStubs(saved)
end

function TestBattleMouse.testClickUnreachableNoKey()
    print("\n=== Test: 点击不可达格 → 不注入键（等价键盘走不过去）===")
    local saved = installStubs()
    rawset(_G, "GetWarMap", function(x, y, layer)
        if layer ~= 3 then return 0 end
        if y == 10 and x >= 10 and x <= 12 then return x - 10 end
        return 255
    end)

    local IM = require("framework.input_manager")
    IM.getInstance():init()

    local BM = freshBattleMouse()
    local H = require("framework.mouse_hover")

    local sx, sy = H.tileToScreen(20, 20, 10, 10)
    BM.clickAt(sx, sy)

    TestHelper.assertEquals(-1, IM.getInstance():_peekKeyInternal(),
        "不可达格不注入确认键")
    TestHelper.assertEquals(10, rawget(_G, "WAR").MoveCursorX, "光标未变")
    restoreStubs(saved)
end

function TestBattleMouse.testCancelInjectsEscape()
    print("\n=== Test: 取消注入 ESC ===")
    local saved = installStubs()

    local IM = require("framework.input_manager")
    IM.getInstance():init()

    local BM = freshBattleMouse()
    TestHelper.assertTrue(BM.cancel(), "处理了取消")
    TestHelper.assertEquals(27, IM.getInstance():_peekKeyInternal(),
        "注入 VK_ESCAPE")
    IM.getInstance():clearCurrentKey()
    restoreStubs(saved)
end

function TestBattleMouse.testNotActiveOutsideBattle()
    print("\n=== Test: 非战斗状态不处理 ===")
    local saved = installStubs()
    rawset(_G, "JY", { Status = 2 })   -- MMAP

    local BM = freshBattleMouse()
    TestHelper.assertFalse(BM.canOperate(), "地图状态 → 战斗鼠标不工作")
    TestHelper.assertFalse(BM.clickAt(500, 400), "不处理点击")
    restoreStubs(saved)
end

function TestBattleMouse.testNotActiveWithoutDrawMode()
    print("\n=== Test: 没有光标选择时不处理 ===")
    local saved = installStubs()
    rawget(_G, "WAR").DrawMode = nil

    local BM = freshBattleMouse()
    TestHelper.assertFalse(BM.canOperate(), "DrawMode=nil → 不工作")
    restoreStubs(saved)
end

-- ============================================================
-- 光标双份状态同步（用户实测：悬停有效果、点击无效）
--
-- War_MoveCoroutine 用局部 x,y 做判断，而鼠标只能改 WAR.MoveCursorX/Y。
-- 若不在 WaitKey 返回后立刻读回，点击会用 click 前的 x,y 判断
-- → `x == x0` → 「没有移动」→ 点了没反应。
-- ============================================================

function TestBattleMouse.testMoveCoroutineReadsGlobalCursorAfterWait()
    print("\n=== Test: War_MoveCoroutine 等键后读回全局光标 ===")
    local saved = installStubs()

    -- 必须显式给出可移动范围：
    --   * 单跑时 GetWarMap 可能是 nil → isMovable 恒 false → clickAt 不注入键
    --   * 混跑时 GetWarMap 可能是别的用例残留的桩，范围完全不对
    -- 两种情况下这个用例都测不到真正的路径。
    rawset(_G, "GetWarMap", function(x, y, layer)
        if layer ~= 3 then return 0 end
        if y == 10 and x >= 10 and x <= 13 then return x - 10 end
        return 255
    end)

    local IM = require("framework.input_manager")
    local SC = require("framework.coroutine_scheduler")
    local sched = SC.getInstance()

    -- 全套件混跑时，前面模块可能留下：
    --   * 残留协程（也在等键 → 会抢走 clickAt 注入的键）
    --   * 残留键事件（dispatcher 会把注入键当成已有事件直接消费）
    -- sched:clear() 只清协程表；键队列必须单独清。
    sched:clear()
    IM.getInstance():init()
    IM.getInstance():clearCurrentKey()

    -- 复刻打过补丁的循环结构
    local confirmed = nil
    local co = sched:create(function()
        local x0, y0 = 10, 10
        local x, y = x0, y0
        while true do
            WAR.MoveCursorX = x
            WAR.MoveCursorY = y
            local key = require("framework.input_async").WaitKeyCoroutine()
            -- 补丁位置：等键返回后立刻读回
            if WAR.MoveCursorX and WAR.MoveCursorY
                and (WAR.MoveCursorX ~= x or WAR.MoveCursorY ~= y) then
                x, y = WAR.MoveCursorX, WAR.MoveCursorY
            end
            if key == VK_SPACE or key == VK_RETURN then
                if x == x0 and y == y0 then return end
                confirmed = { x, y }
                return
            end
        end
    end, "war_move")
    sched:start(co)

    local BM = require("framework.battle_mouse")
    local H = require("framework.mouse_hover")
    local sx, sy = H.tileToScreen(12, 10, 10, 10)

    BM.clickAt(sx, sy)
    sched:update(0.016)

    TestHelper.assertNotNil(confirmed, "点击必须真的移动（不是「未移动」取消）")
    TestHelper.assertEquals(12, confirmed[1], "移动到 x=12")
    restoreStubs(saved)
end

function TestBattleMouse.testMoveLoopSyncsBeforeWorkingCopy()
    print("\n=== Test: 同步位置必须在赋全局光标之前 ===")
    -- 源码级断言：sync 必须出现在 `WAR.MoveCursorX = x` 之后、判断之前。
    -- 放在循环顶部（赋全局之前）会失效 —— 协程从 yield 点恢复后
    -- 不会重新执行循环顶部，本轮判断仍用旧的 x,y。
    local f = io.open("script/battle/battle_flow_coroutines.lua", "r")
    if not f then
        TestHelper.assertTrue(false, "无法打开 battle_flow_coroutines.lua")
        return
    end
    local src = f:read("*a")
    f:close()

    -- 找到 War_MoveCoroutine 里的 WaitKey 行
    local moveStart = src:find("War_MoveCoroutine = function")
    TestHelper.assertNotNil(moveStart, "找到 War_MoveCoroutine")
    local body = src:sub(moveStart, moveStart + 6000)

    -- Task 5 批 7 迁移后是 WaitActionCoroutine（语义动作版，同样先于光标同步）
    local waitPos = body:find("InputAsync.WaitActionCoroutine()")
        or body:find("InputAsync.WaitKeyCoroutine()")
    local syncPos = body:find("x, y = WAR.MoveCursorX, WAR.MoveCursorY")
    TestHelper.assertNotNil(waitPos, "找到 WaitAction/Key 调用")
    TestHelper.assertNotNil(syncPos, "找到光标同步代码")

    TestHelper.assertTrue(syncPos > waitPos,
        "光标同步必须在 WaitKey **之后**（否则本轮判断仍用旧值）")
end

function TestBattleMouse.runAll()
    print("\n" .. string.rep("=", 60))
    print("战斗鼠标测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestBattleMouse.testIsMovable()

    TestBattleMouse.testCameraIsActorPosition()
    TestBattleMouse.testCameraWorksWithoutJYBase()

    TestBattleMouse.testHoverMovesCursor()
    TestBattleMouse.testHoverRejectsUnreachable()
    TestBattleMouse.testHoverSameTileNoop()

    TestBattleMouse.testClickConfirmInjectsKey()
    TestBattleMouse.testClickUnreachableNoKey()
    TestBattleMouse.testCancelInjectsEscape()

    TestBattleMouse.testNotActiveOutsideBattle()
    TestBattleMouse.testNotActiveWithoutDrawMode()

    TestBattleMouse.testMoveCoroutineReadsGlobalCursorAfterWait()
    TestBattleMouse.testMoveLoopSyncsBeforeWorkingCopy()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_battle_mouse.lua$") then
    TestBattleMouse.runAll()
end

return TestBattleMouse
