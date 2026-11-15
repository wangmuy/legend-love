-- test_auto_move.lua
-- 自动移动状态机与三种中断语义的测试（REQ-MS3-3 / REQ-MS3-4 / REQ-MS3-5）

local TestHelper = require("tests.test_helper")
local TestAutoMove = {}

local function installGlobals(opts)
    opts = opts or {}
    local saved = { JY = rawget(_G, "JY"), EngineAPI = rawget(_G, "EngineAPI") }
    rawset(_G, "JY", {})
    rawset(_G, "EngineAPI", {
        time = { getTime = function() return opts.nowMs or (os.clock() * 1000) end },
    })
    return saved
end

local function restoreGlobals(saved)
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

local function freshAutoMove()
    package.loaded["framework.auto_move"] = nil
    return require("framework.auto_move")
end

local function makePath(coords)
    local p = {}
    for _, c in ipairs(coords) do p[#p + 1] = { x = c[1], y = c[2] } end
    return p
end

-- ============================================================
-- 基础状态
-- ============================================================

function TestAutoMove.testStartRequiresTwoPoints()
    print("\n=== Test: 路径至少 2 点才启动 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    TestHelper.assertFalse(A.start(makePath({ {1,1} }), "MMAP"),
        "只有起点 → 不启动")
    TestHelper.assertTrue(A.start(makePath({ {1,1}, {1,2} }), "MMAP"),
        "2 个点 → 启动")
    restoreGlobals(saved)
end

function TestAutoMove.testStartSkipsFirstPoint()
    print("\n=== Test: 默认跳过起点 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {5,5}, {5,4}, {5,3} }), "MMAP")
    local nextPt = A.peek()
    TestHelper.assertEquals(4, nextPt.y, "第一个要走的点是 (5,4)，不是起点 (5,5)")
    TestHelper.assertEquals(2, A.remaining(), "剩余 2 步")
    restoreGlobals(saved)
end

function TestAutoMove.testAdvanceAndFinish()
    print("\n=== Test: 推进路径直到走完 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1}, {0,2} }), "MMAP")
    TestHelper.assertTrue(A.isActive(), "启动后在移动")

    A.advance()
    TestHelper.assertTrue(A.isActive(), "走一步后仍在移动")

    local hasMore = A.advance()
    TestHelper.assertFalse(hasMore, "走完最后一步")
    TestHelper.assertFalse(A.isActive(), "状态已清除")
    restoreGlobals(saved)
end

function TestAutoMove.testRemaining()
    print("\n=== Test: remaining 计数 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1}, {0,2}, {0,3} }), "MMAP")
    TestHelper.assertEquals(3, A.remaining(), "4 点路径（跳过起点）剩 3 步")
    A.advance()
    TestHelper.assertEquals(2, A.remaining(), "走一步后剩 2")
    restoreGlobals(saved)
end

-- ============================================================
-- REQ-MS3-5 中断：按键
-- ============================================================

function TestAutoMove.testInterruptByKey()
    print("\n=== Test: 按键中断 + 设置 drain ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1}, {0,2} }), "MMAP")
    A.interruptByKey(1073741906)      -- VK_UP

    TestHelper.assertFalse(A.isActive(), "自动移动已停止")
    TestHelper.assertTrue(A.isDraining(), "进入 drain 状态")

    local JY = rawget(_G, "JY")
    TestHelper.assertEquals(1073741906, JY.InputDrain.key, "记录了被中断的键")
    restoreGlobals(saved)
end

function TestAutoMove.testShouldDrainKeyOnlyAffectsInterruptKey()
    print("\n=== Test: drain 只吃被中断的那个键 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "MMAP")
    A.interruptByKey(1073741906)      -- 上

    TestHelper.assertTrue(A.shouldDrainKey(1073741906), "上键被吃掉")
    TestHelper.assertFalse(A.shouldDrainKey(1073741905),
        "下键不被吃（玩家可以按别的方向）")
    restoreGlobals(saved)
end

function TestAutoMove.testKeyReleasedClearsDrain()
    print("\n=== Test: 松开按键解除 drain ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "MMAP")
    A.interruptByKey(1073741906)
    A.onKeyReleased(1073741906)

    TestHelper.assertFalse(A.isDraining(), "松开后 drain 解除")
    restoreGlobals(saved)
end

function TestAutoMove.testDrainTimeoutProtection()
    print("\n=== Test: drain 超时保护（窗口失焦场景）===")
    local nowMs = 1000
    local saved = installGlobals({ nowMs = nowMs })
    local A = freshAutoMove()

    -- EngineAPI.time.getTime 固定返回 1000
    A.start(makePath({ {0,0}, {0,1} }), "MMAP")
    A.interruptByKey(1073741906)
    TestHelper.assertTrue(A.isDraining(), "刚开始在 drain")

    -- 手动把 startMs 往前推 3 秒（超过 2000ms 超时）
    local JY = rawget(_G, "JY")
    JY.InputDrain.startMs = nowMs - 3000

    TestHelper.assertFalse(A.isDraining(), "超时后自动解除（不会永久卡住）")
    restoreGlobals(saved)
end

-- ============================================================
-- REQ-MS3-5 中断：事件与场景
-- ============================================================

function TestAutoMove.testInterruptByEvent()
    print("\n=== Test: 事件中断（不设 drain）===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1}, {0,2} }), "SMAP")
    A.interruptByEvent()

    TestHelper.assertFalse(A.isActive(), "自动移动已停止")
    TestHelper.assertFalse(A.isDraining(), "事件中断不设 drain（事件要消费按键）")

    local JY = rawget(_G, "JY")
    TestHelper.assertEquals(nil, JY.AutoMove, "路径已清空（不恢复）")
    restoreGlobals(saved)
end

function TestAutoMove.testInterruptBySceneChange()
    print("\n=== Test: 场景切换中断 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "MMAP")
    A.interruptByKey(1073741906)
    A.interruptBySceneChange()

    TestHelper.assertFalse(A.isActive(), "移动停止")
    TestHelper.assertFalse(A.isDraining(), "drain 也清空（场景已换）")
    restoreGlobals(saved)
end

function TestAutoMove.testReset()
    print("\n=== Test: reset 清空全部 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "MMAP")
    A.interruptByKey(999)
    A.reset()

    local JY = rawget(_G, "JY")
    TestHelper.assertEquals(nil, JY.AutoMove, "AutoMove 清空")
    TestHelper.assertEquals(nil, JY.InputDrain, "InputDrain 清空")
    restoreGlobals(saved)
end

-- ============================================================
-- REQ-MS3-4 不在 update 中寻路
-- ============================================================

function TestAutoMove.testPeekIsO1()
    print("\n=== Test: peek/advance 是 O(1)（不在 update 里寻路）===")
    local saved = installGlobals()
    local A = freshAutoMove()

    -- 构造 1000 点的长路径
    local coords = {}
    for i = 0, 1000 do coords[#coords + 1] = { i, 0 } end
    A.start(makePath(coords), "MMAP")

    local t0 = os.clock()
    for _ = 1, 1000 do
        A.peek()
        A.advance()
    end
    local elapsed = (os.clock() - t0) * 1000

    TestHelper.assertTrue(elapsed < 50,
        string.format("1000 次 peek+advance < 50ms（实际 %.2f ms）—— O(1)", elapsed))
    restoreGlobals(saved)
end

-- ============================================================
-- canPlayerAct 统一守卫（本次修复的核心）
--
-- 用户实测报告：对话期间点击地图，主角照样移动。
-- 根因：handleMapClick 只查了「鼠标开关 + 状态」，一层冻结条件都没查。
-- ============================================================

local function setupGuard(opts)
    opts = opts or {}
    local saved = {
        JY = rawget(_G, "JY"),
        GAME_MMAP = rawget(_G, "GAME_MMAP"),
        GAME_SMAP = rawget(_G, "GAME_SMAP"),
    }
    rawset(_G, "GAME_MMAP", 2)
    rawset(_G, "GAME_SMAP", 4)
    rawset(_G, "JY", {
        Status = opts.status or 2,
        CurrentD = opts.currentD,
        AnimationState = { active = opts.animActive == true },
    })

    -- MenuAsync
    package.loaded["framework.menu_async"] = nil
    local MA = require("framework.menu_async")
    MA.hasActiveMenu = function() return opts.menuActive == true end

    -- InputManager
    local IM = require("framework.input_manager")
    IM.disableInput = opts.inputBlocked == true

    -- TalkAsync
    package.loaded["framework.talk_async"] = nil
    local TA = require("framework.talk_async")
    TA.getCurrentTalk = function()
        if opts.talkActive then return { text = "x" } end
        return nil
    end

    package.loaded["framework.auto_move"] = nil
    return require("framework.auto_move"), saved
end

local function restoreGuard(saved)
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

function TestAutoMove.testCanPlayerActWhenAllClear()
    print("\n=== Test: 全部条件正常时允许行动 ===")
    local A, saved = setupGuard({})
    TestHelper.assertTrue(A.canPlayerAct(), "无任何冻结条件 → 允许")
    restoreGuard(saved)
end

function TestAutoMove.testCanPlayerActBlockedByDialogue()
    print("\n=== Test: 对话显示中禁止行动（本次修复的 bug）===")
    local A, saved = setupGuard({ talkActive = true })
    TestHelper.assertFalse(A.canPlayerAct(),
        "TalkAsync 有活动对话 → 禁止（这正是用户报告的对话中能走路的根因）")
    restoreGuard(saved)
end

function TestAutoMove.testCanPlayerActBlockedByCurrentD()
    print("\n=== Test: 事件执行中禁止行动 ===")
    local A, saved = setupGuard({ currentD = 5 })
    TestHelper.assertFalse(A.canPlayerAct(), "CurrentD >= 0 → 禁止")
    restoreGuard(saved)
end

function TestAutoMove.testCanPlayerActBlockedByAnimation()
    print("\n=== Test: 动画播放中禁止行动 ===")
    local A, saved = setupGuard({ animActive = true })
    TestHelper.assertFalse(A.canPlayerAct(), "AnimationState.active → 禁止")
    restoreGuard(saved)
end

function TestAutoMove.testCanPlayerActBlockedByMenu()
    print("\n=== Test: 有菜单时禁止行动 ===")
    local A, saved = setupGuard({ menuActive = true })
    TestHelper.assertFalse(A.canPlayerAct(), "有活动菜单 → 禁止")
    restoreGuard(saved)
end

function TestAutoMove.testCanPlayerActBlockedByDisableInput()
    print("\n=== Test: disableInput 时禁止行动 ===")
    local A, saved = setupGuard({ inputBlocked = true })
    TestHelper.assertFalse(A.canPlayerAct(), "disableInput → 禁止")
    restoreGuard(saved)
end

function TestAutoMove.testCanPlayerActBlockedByWrongState()
    print("\n=== Test: 非地图状态禁止行动（含战斗）===")
    local A, saved = setupGuard({ status = 5 })   -- 5 = GAME_WMAP
    TestHelper.assertFalse(A.canPlayerAct(),
        "战斗中 → 禁止（战斗不在 MMAP/SMAP 分支内，天然排除）")
    restoreGuard(saved)
end

function TestAutoMove.testCanPlayerActSmoke()
    print("\n=== Test: 小场景也允许行动 ===")
    local A, saved = setupGuard({ status = 4 })   -- 4 = GAME_SMAP
    TestHelper.assertTrue(A.canPlayerAct(), "小场景正常时允许")
    restoreGuard(saved)
end

-- ============================================================
-- 步进节流（用户实测：点一下人「一下子跑很远」）
-- ============================================================

function TestAutoMove.testStepIntervalDefault()
    print("\n=== Test: 默认步进间隔 50ms ===")
    local saved = installGlobals()
    local A = freshAutoMove()
    TestHelper.assertEquals(50, A.STEP_INTERVAL_MS,
        "50ms/格 = 20 格/秒，与原版 CC.Frame=50 一致")
    restoreGlobals(saved)
end

function TestAutoMove.testFirstStepImmediate()
    print("\n=== Test: 第一步立即走（点击后马上有反馈）===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "MMAP")
    TestHelper.assertTrue(A.readyToStep(),
        "刚启动就能走第一步（不必等 50ms）")
    restoreGlobals(saved)
end

function TestAutoMove.testSecondStepThrottled()
    print("\n=== Test: 第二步需等 50ms ===")
    local nowMs = 10000
    local saved = installGlobals({ nowMs = nowMs })
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1}, {0,2} }), "MMAP")
    A.markStep()
    TestHelper.assertFalse(A.readyToStep(), "刚走完一步，未到间隔 → 不能再走")

    -- 把 lastStepMs 往前推 60ms（超过 50ms 间隔）
    local JY = rawget(_G, "JY")
    JY.AutoMove.lastStepMs = nowMs - 60
    TestHelper.assertTrue(A.readyToStep(), "过了 60ms → 可以走")
    restoreGlobals(saved)
end

function TestAutoMove.testPacingIsMinimumIntervalNotPerFrame()
    print("\n=== Test: 节流是「最小间隔」而非「每帧」 ===")
    local nowMs = 5000
    local saved = installGlobals({ nowMs = nowMs })
    local A = freshAutoMove()

    -- 1000 点路径
    local coords = {}
    for i = 0, 1000 do coords[#coords + 1] = { i, 0 } end
    A.start(makePath(coords), "MMAP")
    A.markStep()

    -- 时间不推进 → 一次都走不了（不是每帧走一格）
    local stepped = 0
    for _ = 1, 60 do
        if A.readyToStep() then stepped = stepped + 1; A.markStep() end
    end
    TestHelper.assertEquals(0, stepped,
        "同一时刻连续 60 次检查 → 0 次可走（证明不是每帧走一格）")
    restoreGlobals(saved)
end

-- ============================================================
-- 自动移动的方向与贴图（用户实测：小场景朝向不跟着变）
--
-- 根因：SMAP 的绘制链用全局 JY.MyPic，不像 MMAP 那样每帧 GetMyPic() 重算。
-- 键盘路径在 update 末尾会刷新 MyPic，但自动移动提前 return，跳过了它。
-- ============================================================

local function setupMoveEnv(mapKind)
    local saved = {
        JY = rawget(_G, "JY"), CC = rawget(_G, "CC"),
        lib = rawget(_G, "lib"), EngineAPI = rawget(_G, "EngineAPI"),
        GAME_MMAP = rawget(_G, "GAME_MMAP"), GAME_SMAP = rawget(_G, "GAME_SMAP"),
        GetMyPic = rawget(_G, "GetMyPic"),
        AddMyCurrentPic = rawget(_G, "AddMyCurrentPic"),
        DtoSMap = rawget(_G, "DtoSMap"),
        SceneCanPass = rawget(_G, "SceneCanPass"),
        CanEnterScene = rawget(_G, "CanEnterScene"),
        TalkAsync = nil,
    }
    rawset(_G, "GAME_MMAP", 2)
    rawset(_G, "GAME_SMAP", 4)
    rawset(_G, "CC", {
        XScale = 18, YScale = 9, Width = 1024, Height = 768,
        MWidth = 480, MHeight = 480, SWidth = 64, SHeight = 64,
        SceneXMin = 12, SceneYMin = 12, SceneXMax = 45, SceneYMax = 45,
        MyStartPic = 2494, BoatStartPic = 3000,
    })
    rawset(_G, "lib", {
        Debug = function() end,
        GetKey = function() return -1 end,
        GetMMap = function() return 0 end,
    })
    rawset(_G, "JY", {
        Status = (mapKind == "MMAP") and 2 or 4,
        SubScene = 1, SubSceneX = 0, SubSceneY = 0,
        MyCurrentPic = 0, MyPic = 2494, MyTick = 0, MyTick2 = 0,
        AnimationState = { active = false, currentFrame = 0 },
        Base = { ["人X1"] = 19, ["人Y1"] = 20, ["人X"] = 100, ["人Y"] = 100,
                 ["人方向"] = 0, ["乘船"] = 0 },
    })
    rawset(_G, "GetMyPic", function()
        local J = rawget(_G, "JY")
        if J.MyCurrentPic > 6 then J.MyCurrentPic = 1 end
        return 2494 + J.Base["人方向"] * 7 + J.MyCurrentPic
    end)
    rawset(_G, "AddMyCurrentPic", function()
        local J = rawget(_G, "JY")
        J.MyCurrentPic = J.MyCurrentPic + 1
    end)
    rawset(_G, "DtoSMap", function() end)
    rawset(_G, "SceneCanPass", function() return true end)
    rawset(_G, "CanEnterScene", function() return -1 end)

    package.loaded["framework.auto_move"] = nil
    package.loaded["framework.game_states"] = nil
    return require("framework.auto_move"), require("framework.game_states"), saved
end

local function restoreMoveEnv(saved)
    for k, v in pairs(saved) do
        if k ~= "TalkAsync" then rawset(_G, k, v) end
    end
end

function TestAutoMove.testSMAPUpdatesDirection()
    print("\n=== Test: SMAP 自动移动更新朝向与贴图 ===")
    local A, GS, saved = setupMoveEnv("SMAP")

    A.start({ {x=19,y=20}, {x=20,y=20}, {x=21,y=20} }, "SMAP")
    local JY = rawget(_G, "JY")
    JY.Base["人方向"] = 0     -- 初始朝下
    JY.MyPic = 2494

    GS._stepAutoMoveSMAP()

    TestHelper.assertEquals(20, JY.Base["人X1"], "向右走了一格")
    TestHelper.assertEquals(1, JY.Base["人方向"], "朝向变成右(1)")
    TestHelper.assertTrue(JY.MyPic >= 2501 and JY.MyPic <= 2507,
        "贴图切到「右」方向帧区间 [2501,2507]，实际 " .. JY.MyPic)
    restoreMoveEnv(saved)
end

function TestAutoMove.testSMAPSpriteNotStale()
    print("\n=== Test: SMAP 负向对照 —— 贴图不得停留在旧朝向 ===")
    local A, GS, saved = setupMoveEnv("SMAP")

    A.start({ {x=19,y=20}, {x=20,y=20} }, "SMAP")
    local JY = rawget(_G, "JY")
    JY.Base["人方向"] = 0
    JY.MyPic = 2494          -- 朝下帧区间 [2494,2500]

    GS._stepAutoMoveSMAP()

    TestHelper.assertTrue(JY.MyPic ~= 2494,
        "贴图必须变化（修复前一直停在 2494，表现为人朝右滑走但贴图朝下）")
    restoreMoveEnv(saved)
end

function TestAutoMove.testMMAPUpdatesDirection()
    print("\n=== Test: MMAP 自动移动更新朝向 ===")
    local A, GS, saved = setupMoveEnv("MMAP")

    A.start({ {x=100,y=100}, {x=100,y=99} }, "MMAP")
    local JY = rawget(_G, "JY")
    JY.Base["人方向"] = 3     -- 初始朝下
    JY.MyTick = 15

    GS._stepAutoMoveMMap()

    TestHelper.assertEquals(99, JY.Base["人Y"], "向上走了一格")
    TestHelper.assertEquals(0, JY.Base["人方向"], "朝向变成上(0)")
    TestHelper.assertEquals(0, JY.MyTick,
        "MyTick 被重置（否则每 20 帧会闪一次站立姿势）")
    restoreMoveEnv(saved)
end

-- ============================================================
-- onArrive 暂存（REQ-MS3-6）
--
-- advance() 走完最后一步会清空 JY.AutoMove；若 onArrive 挂在状态上，
-- 调用方紧接着 takeOnArrive() 时读到的就是 nil
-- → 表现「走到门口却进不去」。必须在清空前搬到模块级。
-- ============================================================

function TestAutoMove.testOnArriveSurvivesPathCompletion()
    print("\n=== Test: 路径走完后仍能取到 onArrive ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1}, {0,2} }), "MMAP",
        { onArrive = { kind = "interact", tx = 0, ty = 3 } })

    A.advance()                 -- 还有剩余
    local more = A.advance()    -- 走完
    TestHelper.assertFalse(more, "路径已走完")
    TestHelper.assertFalse(A.isActive(), "状态已清空")

    local act = A.takeOnArrive()
    TestHelper.assertNotNil(act, "走完后仍能取到 onArrive（关键）")
    TestHelper.assertEquals("interact", act.kind, "kind 正确")
    TestHelper.assertEquals(3, act.ty, "目标坐标正确")
    restoreGlobals(saved)
end

function TestAutoMove.testOnArriveOnlyOnce()
    print("\n=== Test: onArrive 只执行一次 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "MMAP",
        { onArrive = { kind = "interact", tx = 1, ty = 1 } })
    A.advance()

    TestHelper.assertNotNil(A.takeOnArrive(), "第一次取到")
    TestHelper.assertEquals(nil, A.takeOnArrive(), "第二次为 nil（不会重复触发）")
    restoreGlobals(saved)
end

function TestAutoMove.testOnArriveClearedByReset()
    print("\n=== Test: reset 清空待执行的 onArrive ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "MMAP",
        { onArrive = { kind = "interact", tx = 1, ty = 1 } })
    A.advance()
    A.reset()

    TestHelper.assertEquals(nil, A.takeOnArrive(),
        "reset 后不能再触发（场景已换）")
    restoreGlobals(saved)
end

-- ============================================================
-- 场景名提示期间禁止行动（用户实测：出场景后名字不消失，
-- 且之后点击都没反应）
-- ============================================================

function TestAutoMove.testCanPlayerActBlockedBySceneName()
    print("\n=== Test: 场景名提示显示中禁止行动 ===")
    local saved = installGlobals()
    rawset(_G, "GAME_MMAP", 2)
    rawset(_G, "GAME_SMAP", 4)
    rawset(_G, "JY", { Status = 4,
                       AnimationState = { active = false } })

    package.loaded["framework.menu_async"] = nil
    require("framework.menu_async").hasActiveMenu = function() return false end
    require("framework.input_manager").disableInput = false

    package.loaded["framework.scene_name_async"] = nil
    local SNA = require("framework.scene_name_async")
    SNA.isActive = function() return true end

    package.loaded["framework.auto_move"] = nil
    local A = require("framework.auto_move")

    TestHelper.assertFalse(A.canPlayerAct(),
        "场景名提示显示中 → 禁止（不能靠 disableInput，它每帧被覆盖）")
    restoreGlobals(saved)
end

function TestAutoMove.testSceneNameCheckIsIndependentOfDisableInput()
    print("\n=== Test: 判定不依赖 disableInput（它会被每帧覆盖）===")
    local saved = installGlobals()
    rawset(_G, "GAME_MMAP", 2)
    rawset(_G, "GAME_SMAP", 4)
    rawset(_G, "JY", { Status = 4, AnimationState = { active = false } })

    package.loaded["framework.menu_async"] = nil
    require("framework.menu_async").hasActiveMenu = function() return false end
    -- 关键：disableInput 为 false（模拟被 GAME_SMAP.update 每帧重置后的状态）
    require("framework.input_manager").disableInput = false

    package.loaded["framework.scene_name_async"] = nil
    local SNA = require("framework.scene_name_async")
    SNA.isActive = function() return true end

    package.loaded["framework.auto_move"] = nil
    local A = require("framework.auto_move")

    TestHelper.assertFalse(A.canPlayerAct(),
        "即使 disableInput=false，场景名仍在显示 → 仍应禁止")
    restoreGlobals(saved)
end

-- ============================================================
-- 模态 UI 期间禁止行动（用户实测：物品/状态页显示时还能点地图）
--
-- 根因：GAME_SMAP.update 每帧把 disableInput 重算成
-- 「动画是否在播」，覆盖掉 item_async / person_status 设的 true。
-- 所以不能只靠 disableInput，要逐个体问「你是不是开着」。
-- ============================================================

local function setupModalEnv()
    local saved = {
        JY = rawget(_G, "JY"),
        GAME_MMAP = rawget(_G, "GAME_MMAP"),
        GAME_SMAP = rawget(_G, "GAME_SMAP"),
    }
    rawset(_G, "GAME_MMAP", 2)
    rawset(_G, "GAME_SMAP", 4)
    rawset(_G, "JY", { Status = 4, AnimationState = { active = false } })

    package.loaded["framework.menu_async"] = nil
    require("framework.menu_async").hasActiveMenu = function() return false end
    -- 关键：disableInput = false（模拟被每帧重置后）
    require("framework.input_manager").disableInput = false
    package.loaded["framework.scene_name_async"] = nil
    require("framework.scene_name_async").isActive = function() return false end

    package.loaded["framework.auto_move"] = nil
    return require("framework.auto_move"), saved
end

local function restoreModalEnv(saved)
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

function TestAutoMove.testBlockedByItemMenu()
    print("\n=== Test: 物品清单显示中禁止行动 ===")
    local A, saved = setupModalEnv()

    local ItemAsync = require("framework.item_async")
    ItemAsync.isActive = function() return true end

    TestHelper.assertFalse(A.canPlayerAct(),
        "物品清单开着 → 禁止（即使 disableInput 被重置成 false）")
    ItemAsync.isActive = nil
    restoreModalEnv(saved)
end

function TestAutoMove.testBlockedByPersonStatus()
    print("\n=== Test: 人物状态页显示中禁止行动 ===")
    local A, saved = setupModalEnv()

    local PersonStatusAsync = require("framework.person_status_async")
    PersonStatusAsync.isActive = function() return true end

    TestHelper.assertFalse(A.canPlayerAct(),
        "状态页开着 → 禁止（即使 disableInput 被重置成 false）")
    PersonStatusAsync.isActive = nil
    restoreModalEnv(saved)
end

function TestAutoMove.testNormalWhenNoModal()
    print("\n=== Test: 没有模态 UI 时允许行动 ===")
    local A, saved = setupModalEnv()

    local ItemAsync = require("framework.item_async")
    local PersonStatusAsync = require("framework.person_status_async")
    ItemAsync.isActive = function() return false end
    PersonStatusAsync.isActive = function() return false end

    TestHelper.assertTrue(A.canPlayerAct(), "无模态 UI → 允许")
    ItemAsync.isActive = nil
    PersonStatusAsync.isActive = nil
    restoreModalEnv(saved)
end

-- ============================================================
-- REQ-MS3-7 路过事件失效时不该中断自动移动
--
-- 用户实测：河洛客栈从一侧点到另一侧，走到门口就停住，
-- 因为门槛事件是一次性的（后续 no-op），但代码无条件中断了路径。
-- ============================================================

function TestAutoMove.testEventWouldRunStatic()
    print("\n=== Test: 静态判据（tile 上还有没有事件号）===")
    local saved = {
        JY = rawget(_G, "JY"),
        GetD = rawget(_G, "GetD"),
        EngineAPI = rawget(_G, "EngineAPI"),
    }
    rawset(_G, "EngineAPI", {
        time = { getTime = function() return os.clock() * 1000 end },
    })
    package.loaded["framework.auto_move"] = nil
    local A = require("framework.auto_move")

    rawset(_G, "JY", { SceneNewEventFunction = {} })
    rawset(_G, "GetD", function(scene, d, i)
        if i == 4 then return 5 end
        return 0
    end)
    TestHelper.assertTrue(A.eventWouldRun(1, 3), "有事件号 → true")

    rawset(_G, "GetD", function() return 0 end)
    TestHelper.assertFalse(A.eventWouldRun(1, 3), "事件号=0（已清空）→ false")

    -- 新式事件：静态判断不了，保守 true
    rawset(_G, "JY", { SceneNewEventFunction = { [1] = function() end } })
    TestHelper.assertTrue(A.eventWouldRun(1, 3),
        "新式事件 → 保守返回 true（宁可中断，不可穿透剧情）")

    for k, v in pairs(saved) do rawset(_G, k, v) end
end

function TestAutoMove.testWatchedEventInterruptsWhenRunning()
    print("\n=== Test: 真事件（CurrentD 跨帧保持）→ 中断 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1}, {0,2} }), "SMAP")
    rawget(_G, "JY").CurrentD = 5     -- 事件在跑（yield 了）
    A.watchEvent(1, 3)

    TestHelper.assertTrue(A.checkWatchedEvent(), "确认事件在跑 → 中断")
    TestHelper.assertFalse(A.isActive(), "路径已清空")
    restoreGlobals(saved)
end

function TestAutoMove.testWatchedEventContinuesWhenNoop()
    print("\n=== Test: no-op 事件（同帧跑完）→ 继续走 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1}, {0,2} }), "SMAP")
    rawget(_G, "JY").CurrentD = -1    -- no-op：同帧跑完，CurrentD 已回 -1
    A.watchEvent(1, 3)

    TestHelper.assertFalse(A.checkWatchedEvent(), "no-op → 不中断")
    TestHelper.assertTrue(A.isActive(), "路径仍在，继续走完")
    restoreGlobals(saved)
end

function TestAutoMove.testWatchedEventOnlyOnce()
    print("\n=== Test: 待判定只生效一次 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "SMAP")
    rawget(_G, "JY").CurrentD = 5
    A.watchEvent(1, 3)

    A.checkWatchedEvent()
    -- 第二次调用：pending 已被消费，不应再判定
    TestHelper.assertFalse(A.checkWatchedEvent(), "已消费 → 不再判定")
    restoreGlobals(saved)
end

function TestAutoMove.testWatchClearedByReset()
    print("\n=== Test: reset 清空待判定 ===")
    local saved = installGlobals()
    local A = freshAutoMove()

    A.start(makePath({ {0,0}, {0,1} }), "SMAP")
    A.watchEvent(1, 3)
    A.reset()

    TestHelper.assertFalse(A.checkWatchedEvent(),
        "reset 后不再判定（场景已换）")
    restoreGlobals(saved)
end

function TestAutoMove.runAll()
    print("\n" .. string.rep("=", 60))
    print("自动移动状态机测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestAutoMove.testStartRequiresTwoPoints()
    TestAutoMove.testStartSkipsFirstPoint()
    TestAutoMove.testAdvanceAndFinish()
    TestAutoMove.testRemaining()

    TestAutoMove.testInterruptByKey()
    TestAutoMove.testShouldDrainKeyOnlyAffectsInterruptKey()
    TestAutoMove.testKeyReleasedClearsDrain()
    TestAutoMove.testDrainTimeoutProtection()

    TestAutoMove.testInterruptByEvent()
    TestAutoMove.testInterruptBySceneChange()
    TestAutoMove.testReset()

    TestAutoMove.testPeekIsO1()

    TestAutoMove.testCanPlayerActWhenAllClear()
    TestAutoMove.testCanPlayerActBlockedByDialogue()
    TestAutoMove.testCanPlayerActBlockedByCurrentD()
    TestAutoMove.testCanPlayerActBlockedByAnimation()
    TestAutoMove.testCanPlayerActBlockedByMenu()
    TestAutoMove.testCanPlayerActBlockedByDisableInput()
    TestAutoMove.testCanPlayerActBlockedByWrongState()
    TestAutoMove.testCanPlayerActSmoke()

    TestAutoMove.testStepIntervalDefault()
    TestAutoMove.testFirstStepImmediate()
    TestAutoMove.testSecondStepThrottled()
    TestAutoMove.testPacingIsMinimumIntervalNotPerFrame()

    TestAutoMove.testSMAPUpdatesDirection()
    TestAutoMove.testSMAPSpriteNotStale()
    TestAutoMove.testMMAPUpdatesDirection()

    TestAutoMove.testOnArriveSurvivesPathCompletion()
    TestAutoMove.testOnArriveOnlyOnce()
    TestAutoMove.testOnArriveClearedByReset()

    TestAutoMove.testCanPlayerActBlockedBySceneName()
    TestAutoMove.testSceneNameCheckIsIndependentOfDisableInput()

    TestAutoMove.testBlockedByItemMenu()
    TestAutoMove.testBlockedByPersonStatus()
    TestAutoMove.testNormalWhenNoModal()

    TestAutoMove.testEventWouldRunStatic()
    TestAutoMove.testWatchedEventInterruptsWhenRunning()
    TestAutoMove.testWatchedEventContinuesWhenNoop()
    TestAutoMove.testWatchedEventOnlyOnce()
    TestAutoMove.testWatchClearedByReset()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_auto_move.lua$") then
    TestAutoMove.runAll()
end

return TestAutoMove

