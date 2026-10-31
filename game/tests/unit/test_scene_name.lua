-- test_scene_name.lua
-- 场景名提示（原版 Init_SMap(1) 的 DrawStrBox + WaitKey）单元测试
--
-- 原版是一段阻塞流程：DrawStrBox → ShowScreen → WaitKey → Cls → ShowScreen。
-- LÖVE 版改为事件驱动的状态机子状态：
--   GAME_SMAP.update → GameStates.pushSceneNamePrompt()
--     → StateMachine:pushSubState("SCENE_NAME", {name=...})
--     → 子状态 update 消费一次按键后 popSubState
--     → 子状态 draw 在父状态 DrawSMap 之后画出名称
--
-- 本套件刻意不使用 LoadRecord：只测这一小段逻辑，手工构造最小 JY，
-- 从而对套件运行顺序完全免疫（test_mod_boot 会不可逆地污染全局 JY）。

local TestHelper = require("tests.test_helper")

local TestSceneName = {}

-- ============================================================
-- 无头环境引导
-- ============================================================

local booted = false
local GameStates, EventBridge, StateMachine

local function bootHeadless()
    if booted then return end
    booted = true

    require("tests.mod_boot_harness").setup()
    _G.EngineAPI = require("tests.engine_test")
    require("framework.config")
    _G.Byte = require("framework.lib_Byte")
    require("engine-love2d.lib_love")
    _G.lib = require("engine-love2d.engine_love2d")
    lib.init()

    EventBridge = require("framework.event_bridge")
    EventBridge.getInstance():init()

    require(CONFIG.ScriptPath .. "jymain")

    -- 手工构造最小 JY：不调用 SetGlobal()，因为
    --   * GAME_INIT 常量未定义，严格 _G 下会报错
    --   * mod_boot 会替换全局环境，SetGlobal 在其后不可靠
    JY = {
        Scene = {
            [1] = { ["名称"] = "河洛客棧" },
            [2] = { ["名称"] = "   " },      -- 纯空白
            [3] = { ["名称"] = "" },         -- 空串
            [4] = {},                        -- 无名称字段
        },
        SubScene = 1,
        Base = { ["人X1"] = 1, ["人Y1"] = 1 },
        Status = 4,          -- GAME_SMAP
    }
    _G.JY = JY

    GameStates = require("framework.game_states")
    StateMachine = require("framework.state_machine")
end

local function IM()
    return require("framework.input_manager").getInstance()
end

-- 注册状态机里用于测试的最小状态（SCENE_NAME 只挂在 GAME_SMAP 下）
local function setupStateMachine()
    local sm = StateMachine.getInstance()
    sm:init()
    -- 直接注册 GAME_SMAP 的真实处理器，取其 subStates
    local handler = GameStates.getHandler("GAME_SMAP")
    sm:register(4, {
        enter = function() end,
        exit = function() end,
        -- 父状态 update/draw 用探针替换，避免真正跑场景行走逻辑
        update = function() end,
        draw = function() end,
        subStates = handler.subStates,
    })
    sm:switchTo(4)
    return sm
end

-- ============================================================
-- 1. 数据获取：GetSceneName
-- ============================================================

function TestSceneName.testGetSceneNameReturnsName()
    print("\n=== Test: GetSceneName 返回当前场景名称 ===")
    bootHeadless()
    JY.SubScene = 1
    TestHelper.assertEquals(GetSceneName(), "河洛客棧", "应返回场景 1 的名称")
end

function TestSceneName.testGetSceneNameNilForBlank()
    print("\n=== Test: 空串/纯空白/无名称字段都视为无名称 ===")
    bootHeadless()
    JY.SubScene = 2
    TestHelper.assertNil(GetSceneName(), "纯空白应视为无名称")
    JY.SubScene = 3
    TestHelper.assertNil(GetSceneName(), "空串应视为无名称")
    JY.SubScene = 4
    TestHelper.assertNil(GetSceneName(), "缺少名称字段应视为无名称")
end

function TestSceneName.testGetSceneNameNilForMissingScene()
    print("\n=== Test: 越界场景号不崩溃，返回 nil ===")
    bootHeadless()
    JY.SubScene = 999
    TestHelper.assertNil(GetSceneName(), "不存在的场景应返回 nil 而不是报错")
end

-- ============================================================
-- 2. 绘制原语：DrawSceneName
-- ============================================================

function TestSceneName.testDrawSceneNameGeometry()
    print("\n=== Test: DrawSceneName 几何与原版一致（x=-1 居中, y=10）===")
    bootHeadless()
    JY.SubScene = 1

    local calls = {}
    local orig = _G.DrawStrBox
    _G.DrawStrBox = function(x, y, str, color, font)
        calls[#calls + 1] = { x = x, y = y, str = str, color = color, font = font }
    end
    local ok, err = pcall(DrawSceneName)
    _G.DrawStrBox = orig

    TestHelper.assertTrue(ok, "DrawSceneName 不应报错: " .. tostring(err))
    TestHelper.assertEquals(#calls, 1, "应调用一次 DrawStrBox")
    TestHelper.assertEquals(calls[1].x, -1, "x 应为 -1（水平居中）")
    TestHelper.assertEquals(calls[1].y, 10, "y 应为 10")
    TestHelper.assertEquals(calls[1].str, "河洛客棧", "应绘制场景名称")
    TestHelper.assertEquals(calls[1].color, C_WHITE, "颜色应为 C_WHITE")
    TestHelper.assertEquals(calls[1].font, CC.DefaultFont, "字体应为 CC.DefaultFont")
end

function TestSceneName.testDrawSceneNameSkipsBlank()
    print("\n=== Test: 无名称时不画空框 ===")
    bootHeadless()
    JY.SubScene = 2   -- 纯空白

    local count = 0
    local orig = _G.DrawStrBox
    _G.DrawStrBox = function() count = count + 1 end
    pcall(DrawSceneName)
    _G.DrawStrBox = orig

    TestHelper.assertEquals(count, 0, "无名称时不应调用 DrawStrBox")
end

function TestSceneName.testDrawSceneNameAcceptsExplicitName()
    print("\n=== Test: DrawSceneName 可直接传入名称（子状态从 context 取）===")
    bootHeadless()
    JY.SubScene = 999   -- 当前场景无名称

    local got = nil
    local orig = _G.DrawStrBox
    _G.DrawStrBox = function(x, y, str) got = str end
    pcall(DrawSceneName, "显式名称")
    _G.DrawStrBox = orig

    TestHelper.assertEquals(got, "显式名称", "应绘制传入的名称而非当前场景")
end

-- ============================================================
-- 3. 子状态注册与切换
-- ============================================================

function TestSceneName.testSubStateRegistered()
    print("\n=== Test: GAME_SMAP 注册了 SCENE_NAME 子状态 ===")
    bootHeadless()
    local handler = GameStates.getHandler("GAME_SMAP")
    TestHelper.assertNotNil(handler.subStates, "GAME_SMAP 应有 subStates")
    TestHelper.assertNotNil(handler.subStates.SCENE_NAME, "应注册 SCENE_NAME 子状态")
    local sub = handler.subStates.SCENE_NAME
    TestHelper.assertTrue(type(sub.enter) == "function", "子状态应有 enter")
    TestHelper.assertTrue(type(sub.update) == "function", "子状态应有 update")
    TestHelper.assertTrue(type(sub.draw) == "function", "子状态应有 draw")
end

function TestSceneName.testPushSceneNamePromptPushesSubState()
    print("\n=== Test: pushSceneNamePrompt 压入子状态并携带名称 ===")
    bootHeadless()
    JY.SubScene = 1
    local sm = setupStateMachine()
    IM():clear()

    local ok = GameStates.pushSceneNamePrompt()
    TestHelper.assertTrue(ok, "pushSceneNamePrompt 应返回 true")
    TestHelper.assertEquals(sm:getCurrentSubState(), "SCENE_NAME", "当前子状态应为 SCENE_NAME")

    local ctx = sm:getCurrentSubStateContext()
    TestHelper.assertNotNil(ctx, "子状态 context 应可读取")
    TestHelper.assertEquals(ctx.data.name, "河洛客棧", "子状态应携带场景名称")
end

function TestSceneName.testPushSceneNamePromptSkipsBlankName()
    print("\n=== Test: 无名称时不压入子状态 ===")
    bootHeadless()
    JY.SubScene = 2
    local sm = setupStateMachine()
    IM():clear()

    local ok = GameStates.pushSceneNamePrompt()
    TestHelper.assertFalse(ok, "无名称时应返回 false")
    TestHelper.assertNil(sm:getCurrentSubState(), "不应压入子状态")
end

-- ============================================================
-- 4. 子状态 draw：在父状态之后
-- ============================================================

function TestSceneName.testSubStateDrawAfterParentDraw()
    print("\n=== Test: StateMachine.draw 先父状态后子状态 ===")
    bootHeadless()
    JY.SubScene = 1
    local sm = setupStateMachine()

    -- 给子状态打点（用真实 draw，但拦 DrawStrBox）
    local order = {}
    local handler = GameStates.getHandler("GAME_SMAP")
    local realDraw = handler.subStates.SCENE_NAME.draw

    -- 重新注册，父 draw 与子 draw 都记录顺序
    sm:register(4, {
        enter = function() end,
        exit = function() end,
        update = function() end,
        draw = function() order[#order + 1] = "parent" end,
        subStates = {
            SCENE_NAME = {
                enter = handler.subStates.SCENE_NAME.enter,
                update = handler.subStates.SCENE_NAME.update,
                draw = function(ctx)
                    order[#order + 1] = "child"
                    realDraw(ctx)
                end,
            },
        },
    })
    sm:switchTo(4)

    IM():clear()
    GameStates.pushSceneNamePrompt()

    local orig = _G.DrawStrBox
    _G.DrawStrBox = function() end
    sm:draw()
    _G.DrawStrBox = orig

    TestHelper.assertEquals(#order, 2, "应分别绘制父状态与子状态各一次")
    TestHelper.assertEquals(order[1], "parent", "父状态（DrawSMap）应先画")
    TestHelper.assertEquals(order[2], "child", "子状态（场景名）应后画，才不会被覆盖")
end

-- ============================================================
-- 5. 子状态 update：父状态被抑制 + 任意键取消
-- ============================================================

function TestSceneName.testParentUpdateSuppressedDuringPrompt()
    print("\n=== Test: 提示期间父状态 update 被抑制（不会走路）===")
    bootHeadless()
    JY.SubScene = 1

    local parentUpdated = 0
    local handler = GameStates.getHandler("GAME_SMAP")
    local sm = StateMachine.getInstance()
    sm:init()
    sm:register(4, {
        enter = function() end,
        exit = function() end,
        update = function() parentUpdated = parentUpdated + 1 end,
        draw = function() end,
        subStates = handler.subStates,
    })
    sm:switchTo(4)

    IM():clear()
    GameStates.pushSceneNamePrompt()

    -- 无按键：子状态 update 跑，父状态 update 被跳过
    sm:update(0.016)
    TestHelper.assertEquals(parentUpdated, 0, "提示期间父状态 update 不应被调用")

    -- 消费按键后子状态弹出，父状态恢复
    IM():onKeyPressed("space", nil, false)
    sm:update(0.016)
    TestHelper.assertNil(sm:getCurrentSubState(), "按任意键后子状态应弹出")

    sm:update(0.016)
    TestHelper.assertEquals(parentUpdated, 1, "提示关闭后父状态 update 应恢复")
end

function TestSceneName.testAnyKeyDismisses()
    print("\n=== Test: 任意键取消提示 ===")
    bootHeadless()
    JY.SubScene = 1
    local sm = setupStateMachine()
    IM():clear()
    GameStates.pushSceneNamePrompt()
    TestHelper.assertEquals(sm:getCurrentSubState(), "SCENE_NAME", "初始应在提示中")

    IM():onKeyPressed("space", nil, false)
    sm:update(0.016)
    TestHelper.assertNil(sm:getCurrentSubState(), "按空格应关闭提示")
end

function TestSceneName.testNoKeyKeepsPrompt()
    print("\n=== Test: 无按键时提示保持 ===")
    bootHeadless()
    JY.SubScene = 1
    local sm = setupStateMachine()
    IM():clear()
    GameStates.pushSceneNamePrompt()

    for _ = 1, 10 do sm:update(0.016) end
    TestHelper.assertEquals(sm:getCurrentSubState(), "SCENE_NAME", "无按键时提示应一直保持")
end

function TestSceneName.testKeyConsumedOnce()
    print("\n=== Test: 按键只被消费一次（不会连带触发走路）===")
    bootHeadless()
    JY.SubScene = 1
    local sm = setupStateMachine()
    IM():clear()
    GameStates.pushSceneNamePrompt()

    IM():onKeyPressed("space", nil, false)
    sm:update(0.016)   -- 子状态消费该按键并弹出
    TestHelper.assertNil(sm:getCurrentSubState(), "按键后子状态应弹出")

    -- 按键已被子状态消费，队列里不应再有残留
    local leftover = IM():_peekKeyInternal()
    TestHelper.assertEquals(leftover, -1, "按键应已被消费，不残留给父状态")
end

function TestSceneName.testParentDrawStillRunsDuringPrompt()
    print("\n=== Test: 提示期间父状态仍每帧重绘（地图不能黑屏）===")
    bootHeadless()
    JY.SubScene = 1
    local parentDrew = 0
    local handler = GameStates.getHandler("GAME_SMAP")
    local sm = StateMachine.getInstance()
    sm:init()
    sm:register(4, {
        enter = function() end,
        exit = function() end,
        update = function() end,
        draw = function() parentDrew = parentDrew + 1 end,
        subStates = handler.subStates,
    })
    sm:switchTo(4)
    IM():clear()
    GameStates.pushSceneNamePrompt()

    local orig = _G.DrawStrBox
    _G.DrawStrBox = function() end
    sm:draw(); sm:draw()
    _G.DrawStrBox = orig

    TestHelper.assertEquals(parentDrew, 2, "父状态每帧都应重绘")
end

-- ============================================================
-- 6. 协程路径：等键不阻塞主线程（非协程）/ 挂起协程（协程内）
-- ============================================================

function TestSceneName.testNonCoroutineDoesNotBlock()
    print("\n=== Test: 非协程路径不阻塞主线程 ===")
    bootHeadless()
    JY.SubScene = 1
    setupStateMachine()
    IM():clear()

    -- 非协程内调用应立即返回（若实现里误用 waitForKey 会在此卡死）
    local ok = GameStates.pushSceneNamePrompt()
    TestHelper.assertTrue(ok, "非协程调用应立即返回 true")
    TestHelper.assertFalse(EngineAPI.coroutine.isRunning(), "主线程 isRunning 应为 false")
end

function TestSceneName.testCoroutinePathWaitsForKey()
    print("\n=== Test: 协程路径压入子状态并调用 waitForKey ===")
    bootHeadless()
    JY.SubScene = 1
    local sm = setupStateMachine()
    IM():clear()

    -- 测试环境里 EngineAPI.input.waitForKey 立即返回，无法观测真正的挂起；
    -- 这里改为验证「协程内走的是 waitForKey 分支，而非靠父状态轮询」。
    local waited = 0
    local origWait = EngineAPI.input.waitForKey
    EngineAPI.input.waitForKey = function()
        waited = waited + 1
        return 32
    end

    local co = coroutine.create(function()
        GameStates.pushSceneNamePrompt()
    end)
    local ok, err = coroutine.resume(co)
    EngineAPI.input.waitForKey = origWait

    TestHelper.assertTrue(ok, "协程不应报错: " .. tostring(err))
    TestHelper.assertEquals(waited, 1, "协程路径应调用一次 waitForKey（而不是靠轮询）")
    TestHelper.assertEquals(sm:getCurrentSubState(), "SCENE_NAME", "协程路径也应压入子状态")
end

function TestSceneName.testNonCoroutineDoesNotCallWaitForKey()
    print("\n=== Test: 非协程路径不调用 waitForKey（不阻塞）===")
    bootHeadless()
    JY.SubScene = 1
    setupStateMachine()
    IM():clear()

    local waited = 0
    local origWait = EngineAPI.input.waitForKey
    EngineAPI.input.waitForKey = function() waited = waited + 1; return 32 end
    local ok = GameStates.pushSceneNamePrompt()
    EngineAPI.input.waitForKey = origWait

    TestHelper.assertTrue(ok, "应压入子状态成功")
    TestHelper.assertEquals(waited, 0, "非协程路径不应调用阻塞的 waitForKey")
end

-- ============================================================
-- 7. 源码级不变量
-- ============================================================

function TestSceneName.testNoBlockingPollingRemains()
    print("\n=== Test: 源码中不再有标志轮询实现残留 ===")
    local f = io.open("script/jymain.lua", "r")
    if not f then
        TestHelper.assertTrue(false, "无法打开 script/jymain.lua")
        return
    end
    local src = f:read("*a")
    f:close()

    -- 注意：不能只匹配 "SceneNameShow"，否则会命中允许存在的
    -- SetSceneNameShowHook 钩子名。这里要求带 JY. 前缀。
    TestHelper.assertNil(src:match("JY%.SceneNameShow"), "不应再有 JY.SceneNameShow 标志轮询")
    TestHelper.assertNil(src:match("JY%.SceneNameWaiter"), "不应再有 JY.SceneNameWaiter 双读保护")
    TestHelper.assertNil(src:match("ClearSceneNameOnKey"), "不应再有 ClearSceneNameOnKey 轮询函数")
    TestHelper.assertNotNil(src:match("SetSceneNameShowHook"), "应保留注入钩子 SetSceneNameShowHook")
end

function TestSceneName.testStateDrawDoesNotDrawSceneNameDirectly()
    print("\n=== Test: 父状态 draw 不再直接画场景名（只由子状态画）===")
    local f = io.open("framework/game_states.lua", "r")
    if not f then
        TestHelper.assertTrue(false, "无法打开 framework/game_states.lua")
        return
    end
    local src = f:read("*a")
    f:close()

    -- 先定位到 GAME_SMAP 处理器，避免匹配到前面 GAME_MMAP 的 draw
    local smapStart = src:find('handlers%["GAME_SMAP"%]')
    TestHelper.assertNotNil(smapStart, "应能找到 handlers[\"GAME_SMAP\"]")
    local smapSrc = smapStart and src:sub(smapStart) or src

    -- 取出 GAME_SMAP 处理器中「父状态 draw」的函数体：
    -- 从 "    draw = function()" 开始（subStates 内部的是 "draw = function(context)"，
    -- 缩进更深），到下一个同缩进的 "    end" 结束。
    local body = smapSrc:match("\n    draw = function%(%)%s*\n(.-)\n    end%s*[},]")
    TestHelper.assertNotNil(body, "应能定位 GAME_SMAP 的父状态 draw 函数体")
    if body then
        TestHelper.assertNil(body:match("DrawSceneName"),
            "父状态 draw 内不应出现 DrawSceneName —— 否则会被同函数末尾/下一帧的 DrawSMap 覆盖")
        TestHelper.assertNotNil(body:match("DrawSMap%(0%)"), "父状态 draw 仍应调用 DrawSMap(0)")
    end

    -- 子状态的 draw 必须画场景名
    local subDraw = smapSrc:match("\n            draw = function%(context%)%s*\n(.-)\n            end,")
    TestHelper.assertNotNil(subDraw, "应能定位 SCENE_NAME 子状态的 draw 函数体")
    if subDraw then
        TestHelper.assertNotNil(subDraw:match("DrawSceneName"),
            "SCENE_NAME 子状态的 draw 必须调用 DrawSceneName")
    end
end

function TestSceneName.testIsRunningDistinguishesMainThread()
    print("\n=== Test: isRunning 能区分主线程与协程 ===")
    bootHeadless()
    TestHelper.assertFalse(EngineAPI.coroutine.isRunning(),
        "主线程 isRunning=false（LuaJIT 主线程 running() 非 nil，需用 ismain 排除）")

    local inside = nil
    local co = coroutine.create(function() inside = EngineAPI.coroutine.isRunning() end)
    coroutine.resume(co)
    TestHelper.assertTrue(inside, "协程内 isRunning=true")
end

-- ============================================================
-- 8. GAME_INIT 常量已定义（SetGlobal 的依赖）
-- ============================================================

function TestSceneName.testGameInitConstantDefined()
    print("\n=== Test: GAME_INIT 常量已定义（SetGlobal 依赖它）===")
    bootHeadless()
    -- SetGlobal() 里 JY.Status=GAME_INIT；此前该常量从未定义，
    -- 一旦在严格 _G 元表安装之后调用 SetGlobal 就会报
    -- "attempt read read to undeclared variable GAME_INIT"。
    -- 它必须存在于常量全局表中，且不能与已有状态值冲突。
    TestHelper.assertNotNil(rawget(_G, "GAME_INIT"), "GAME_INIT 应在 _G 中定义")
    if rawget(_G, "GAME_INIT") ~= nil then
        TestHelper.assertTrue(type(GAME_INIT) == "number", "GAME_INIT 应为数字")
        TestHelper.assertFalse(GAME_INIT == GAME_START, "GAME_INIT 不应与 GAME_START 重复")
        TestHelper.assertFalse(GAME_INIT == GAME_MMAP, "GAME_INIT 不应与 GAME_MMAP 重复")
        TestHelper.assertFalse(GAME_INIT == GAME_SMAP, "GAME_INIT 不应与 GAME_SMAP 重复")
    end
end

function TestSceneName.testSetGlobalInitializesStatus()
    print("\n=== Test: SetGlobal() 后 JY.Status == GAME_INIT（而不是 nil）===")
    bootHeadless()
    -- 缺陷原状：GAME_INIT 未定义 → 非严格模式下读到 nil →
    -- JY.Status = nil，初始化状态静默丢失（任何依赖
    -- "尚未进入任何画面" 的判断都会失效）。
    local ok, err = pcall(SetGlobal)
    TestHelper.assertTrue(ok, "SetGlobal() 应成功: " .. tostring(err))
    TestHelper.assertNotNil(JY.Status, "SetGlobal 后 JY.Status 不应为 nil")
    TestHelper.assertEquals(JY.Status, GAME_INIT, "SetGlobal 后 JY.Status 应为 GAME_INIT")
end

function TestSceneName.testSetGlobalLeavesNoStrayGlobals()
    print("\n=== Test: SetGlobal() 不往 _G 泄漏裸变量 ===")
    bootHeadless()
    -- 缺陷原状：JY_D_Valld_Num=0 是裸全局赋值（漏写 JY. 前缀），
    -- 在非严格模式下会静默创建全局变量。正确位置是 JY 表内。
    rawset(_G, "JY_D_Valld_Num", nil)
    local ok, err = pcall(SetGlobal)
    TestHelper.assertTrue(ok, "SetGlobal() 应成功: " .. tostring(err))
    TestHelper.assertNil(rawget(_G, "JY_D_Valld_Num"),
        "不应向 _G 泄漏 JY_D_Valld_Num（应挂在 JY 表内）")
end

-- ============================================================
-- 清理与入口
-- ============================================================

local function cleanup()
    local sm = StateMachine.getInstance()
    while sm:getCurrentSubState() do
        sm:popSubState(nil)
    end
    IM():clear()
    os.remove("active_mod.txt")
end

function TestSceneName.runAll()
    bootHeadless()

    TestSceneName.testGetSceneNameReturnsName()
    TestSceneName.testGetSceneNameNilForBlank()
    TestSceneName.testGetSceneNameNilForMissingScene()

    TestSceneName.testDrawSceneNameGeometry()
    TestSceneName.testDrawSceneNameSkipsBlank()
    TestSceneName.testDrawSceneNameAcceptsExplicitName()

    TestSceneName.testSubStateRegistered()
    TestSceneName.testPushSceneNamePromptPushesSubState()
    TestSceneName.testPushSceneNamePromptSkipsBlankName()

    TestSceneName.testSubStateDrawAfterParentDraw()
    TestSceneName.testParentDrawStillRunsDuringPrompt()

    TestSceneName.testParentUpdateSuppressedDuringPrompt()
    TestSceneName.testAnyKeyDismisses()
    TestSceneName.testNoKeyKeepsPrompt()
    TestSceneName.testKeyConsumedOnce()

    TestSceneName.testNonCoroutineDoesNotBlock()
    TestSceneName.testCoroutinePathWaitsForKey()
    TestSceneName.testNonCoroutineDoesNotCallWaitForKey()

    TestSceneName.testNoBlockingPollingRemains()
    TestSceneName.testStateDrawDoesNotDrawSceneNameDirectly()
    TestSceneName.testIsRunningDistinguishesMainThread()

    TestSceneName.testGameInitConstantDefined()
    TestSceneName.testSetGlobalInitializesStatus()
    TestSceneName.testSetGlobalLeavesNoStrayGlobals()

    cleanup()
    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestSceneName
