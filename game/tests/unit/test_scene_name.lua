-- test_scene_name.lua
-- 场景名提示（原版 Init_SMap(1) 的 DrawStrBox + WaitKey）单元测试
--
-- 原版是一段阻塞流程：DrawStrBox → ShowScreen → WaitKey → Cls → ShowScreen。
-- LÖVE 版按 person_status_async.lua 的既有样板改造成事件驱动：
--   Init_SMap(1) → jymain 的 ShowSceneName() → 全局 ShowSceneNameAsyncImpl
--     → SceneNameAsync.Show() 起协程并置 currentName + disableInput
--     → 协程 WaitKeyCoroutine() 挂起，按键事件到来时由 CoroutineScheduler 唤醒
--     → 绘制由 EventBridge:draw() 里的 SceneNameAsync.draw() 每帧完成
--       （排在 StateMachine:draw() 的 DrawSMap 全屏重绘之后）
--
-- 本套件刻意不使用 LoadRecord：只测这一小段逻辑，手工构造最小 JY，
-- 从而对套件运行顺序完全免疫（test_mod_boot 会不可逆地污染全局 JY）。

local TestHelper = require("tests.test_helper")

local TestSceneName = {}

-- ============================================================
-- 无头环境引导
-- ============================================================

local booted = false
local GameStates, EventBridge, StateMachine, SceneNameAsync

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

    GameStates.registerAll()

    -- 注入场景名实现（正常由 AsyncGlobals.install() 或 GAME_SMAP.enter 兜底完成）。
    -- 不注入时 jymain 的 ShowSceneName() 会静默跳过——正是真机
    -- 「什么都没有」的隐患形状，测试必须覆盖到。
    -- 严格 _G 元表可能已被前序测试（jymain_adapter）安装，
    -- 因此这里必须用 rawset 写全局，不能用裸赋值。
    rawset(_G, "SceneNameAsync_", require("framework.scene_name_async"))
    SceneNameAsync = rawget(_G, "SceneNameAsync_")
    rawset(_G, "ShowSceneNameAsyncImpl", SceneNameAsync.Show)
    TestHelper.assertNotNil(rawget(_G, "ShowSceneNameAsyncImpl"),
        "应注入 ShowSceneNameAsyncImpl")
end

local function IM()
    return require("framework.input_manager").getInstance()
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

-- ============================================================
-- 2. SceneNameAsync：事件驱动显示（协程等键 + draw 每帧渲染）
-- ============================================================

function TestSceneName.testShowSkipsBlankName()
    print("\n=== Test: 空名称不起协程、不置状态 ===")
    SceneNameAsync.clear()
    TestHelper.assertEquals(SceneNameAsync.Show(nil), false, "nil 名称应返回 false")
    TestHelper.assertEquals(SceneNameAsync.Show("  "), false, "纯空白名称应返回 false")
    TestHelper.assertEquals(SceneNameAsync.isActive(), false, "不应处于显示中")
end

function TestSceneName.testShowSetsActiveAndName()
    print("\n=== Test: Show 后进入显示态并带名称 ===")
    SceneNameAsync.clear()
    local ok = SceneNameAsync.Show("河洛客棧")
    TestHelper.assertTrue(ok, "Show 应返回 true")
    TestHelper.assertTrue(SceneNameAsync.isActive(), "应处于显示中")
    SceneNameAsync.clear()
    TestHelper.assertEquals(SceneNameAsync.isActive(), false, "clear 后应退出显示态")
end

function TestSceneName.testDrawRendersBoxAndText()
    print("\n=== Test: draw 画出白框与文字（几何与原版一致）===")
    SceneNameAsync.clear()
    SceneNameAsync.Show("河洛客棧")

    local boxes, strs = {}, {}
    local origBox, origStr = _G.DrawBox, _G.DrawString
    _G.DrawBox = function(x1, y1, x2, y2, c)
        boxes[#boxes + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
        if origBox then return origBox(x1, y1, x2, y2, c) end
    end
    _G.DrawString = function(x, y, str, c, size)
        strs[#strs + 1] = { x = x, y = y, str = str, size = size }
        if origStr then return origStr(x, y, str, c, size) end
    end
    SceneNameAsync.draw()
    _G.DrawBox, _G.DrawString = origBox, origStr

    TestHelper.assertEquals(#boxes, 1, "应画一个框")
    TestHelper.assertEquals(#strs, 1, "应画一段文字")
    if #boxes == 1 then
        TestHelper.assertEquals(boxes[1].y1, 10, "框顶 y 应为 10（原版位置）")
        TestHelper.assertTrue(boxes[1].y2 - boxes[1].y1 >= CC.DefaultFont - 1,
            "框高应容纳 CC.DefaultFont")
    end
    if #strs == 1 then
        TestHelper.assertEquals(strs[1].str, "河洛客棧", "文字内容应为场景名")
    end
    SceneNameAsync.clear()
end

function TestSceneName.testDrawNoopWhenInactive()
    print("\n=== Test: 未显示时 draw 不画任何东西 ===")
    SceneNameAsync.clear()
    local n = 0
    local origBox = _G.DrawBox
    _G.DrawBox = function(...) n = n + 1; if origBox then return origBox(...) end end
    SceneNameAsync.draw()
    _G.DrawBox = origBox
    TestHelper.assertEquals(n, 0, "未显示时不应画框")
end

function TestSceneName.testShowDisablesInput()
    print("\n=== Test: 显示期间 disableInput=true（挡住 GAME_SMAP 行走）===")
    SceneNameAsync.clear()
    local IM = require("framework.input_manager").getInstance()
    TestHelper.assertEquals(IM.disableInput, false, "前置：disableInput 应为 false")
    SceneNameAsync.Show("河洛客棧")
    TestHelper.assertEquals(IM.disableInput, true,
        "提示期间必须 disableInput，否则同一按键既关提示又走路")
    SceneNameAsync.clear()
    TestHelper.assertEquals(IM.disableInput, false, "clear 后应恢复输入")
end

function TestSceneName.testKeyDismissesAndRestoresInput()
    print("\n=== Test: 按键事件唤醒协程 → 提示消失 + 恢复输入 ===")
    SceneNameAsync.clear()
    local im = require("framework.input_manager").getInstance()
    im:clear()

    SceneNameAsync.Show("河洛客棧")
    TestHelper.assertTrue(SceneNameAsync.isActive(), "应显示中")

    -- 注入按键 + 只驱动协程调度器。
    -- 不调 EventBridge:update()——它会同步 JY.Status 触发状态切换，
    -- 进而跑真实 Init_SMap（需要完整存档/贴图数据，本套件刻意不装载）。
    im:onKeyPressed("space", nil, false)
    require("framework.coroutine_scheduler").getInstance():update(0)

    TestHelper.assertEquals(SceneNameAsync.isActive(), false,
        "按键后提示应消失（协程被唤醒并走完）")
    TestHelper.assertEquals(im.disableInput, false, "按键后应恢复输入")
end

function TestSceneName.testNoKeyKeepsPrompt()
    print("\n=== Test: 无按键时提示持续存在（不会自己消失）===")
    SceneNameAsync.clear()
    local im = require("framework.input_manager").getInstance()
    im:clear()
    SceneNameAsync.Show("河洛客棧")
    for _ = 1, 10 do
        require("framework.coroutine_scheduler").getInstance():update(0)
    end
    TestHelper.assertTrue(SceneNameAsync.isActive(), "无按键时应持续显示")
    SceneNameAsync.clear()
end

function TestSceneName.testDrawIsCalledFromEventBridge()
    print("\n=== Test: EventBridge:draw 里调用 SceneNameAsync.draw ===")
    local f = io.open("framework/event_bridge.lua", "r")
    if not f then TestHelper.assertTrue(false, "无法打开 event_bridge.lua"); return end
    local src = f:read("*a"); f:close()

    -- 只匹配「行首非注释」的真实调用，避免把 -- SceneNameAsync.draw() 当成调用
    local callPat = "\n%s*SceneNameAsync%.draw%(%)"
    TestHelper.assertNotNil(src:match(callPat),
        "EventBridge:draw 应真正调用 SceneNameAsync.draw()（未被注释）")

    -- 必须排在 StateMachine:draw() 之后（否则被 DrawSMap 全屏重绘覆盖）
    local iSm = src:find("\n%s*StateMachine%.getInstance%(%)%:draw%(%)")
    local iSn = src:find(callPat)
    TestHelper.assertNotNil(iSm, "应能找到 StateMachine:draw()")
    if iSm and iSn then
        TestHelper.assertTrue(iSn > iSm,
            "SceneNameAsync.draw 必须在 StateMachine:draw（含 DrawSMap）之后")
    end
end

function TestSceneName.testSceneNameModuleUsesCoroutineWait()
    print("\n=== Test: 用协程等键，不在 update 里轮询 ===")
    local f = io.open("framework/scene_name_async.lua", "r")
    if not f then TestHelper.assertTrue(false, "无法打开 scene_name_async.lua"); return end
    local src = f:read("*a"); f:close()

    TestHelper.assertNotNil(src:match("WaitKeyCoroutine"), "应用 InputAsync.WaitKeyCoroutine 挂起等键")
    TestHelper.assertNotNil(src:match("disableInput%s*=%s*true"), "应置 disableInput 屏蔽行走")
    -- 不得出现自己轮询 GetKey 的循环
    TestHelper.assertNil(src:match("while%s+true%s+do"),
        "不应有手工轮询循环（应交给 CoroutineScheduler 唤醒）")
end

function TestSceneName.testNoGlobalHookRemains()
    print("\n=== Test: 旧全局钩子 SetSceneNameShowHook 已彻底移除 ===")
    local f = io.open("script/jymain.lua", "r")
    if not f then TestHelper.assertTrue(false, "无法打开 jymain.lua"); return end
    local src = f:read("*a"); f:close()
    TestHelper.assertNil(src:match("SetSceneNameShowHook"),
        "不应再有 SetSceneNameShowHook 全局钩子")
    TestHelper.assertNil(src:match("JY%.SceneNameShow"), "不应再回到标志轮询")
end

function TestSceneName.testGameStatesHasNoSubStateLeftover()
    print("\n=== Test: game_states 不再有 SCENE_NAME 子状态 ===")
    local f = io.open("framework/game_states.lua", "r")
    if not f then TestHelper.assertTrue(false, "无法打开 game_states.lua"); return end
    local src = f:read("*a"); f:close()
    TestHelper.assertNil(src:match("SCENE_NAME"), "不应残留 SCENE_NAME 子状态")
    TestHelper.assertNil(src:match("pushSceneNamePrompt"), "不应残留 pushSceneNamePrompt")
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
-- 8. 真实入口：主地图进小场景必须带 showname=1
-- ============================================================

function TestSceneName.testMmapSubscenePassesShowname()
    print("\n=== Test: 主地图进小场景时 switchState 传 showname=1 ===")
    local f = io.open("framework/game_states.lua", "r")
    if not f then
        TestHelper.assertTrue(false, "无法打开 framework/game_states.lua")
        return
    end
    local src = f:read("*a")
    f:close()

    -- 缺陷形状：GAME_MMAP.update 里只写 JY.Status = newState 就完事，
    -- 不走 switchState(..., {showname=1})，于是 GAME_SMAP.enter 拿到 nil
    -- 只跑 Init_SMap(0)，进客栈等小场景永远不显示场景名。
    local mmapStart = src:find('handlers%["GAME_MMAP"%]')
    TestHelper.assertNotNil(mmapStart, "应能找到 handlers[\"GAME_MMAP\"]")
    local smapStart = src:find('handlers%["GAME_SMAP"%]')
    TestHelper.assertNotNil(smapStart, "应能找到 handlers[\"GAME_SMAP\"]")
    if not (mmapStart and smapStart) then return end

    local mmapSrc = src:sub(mmapStart, smapStart - 1)
    TestHelper.assertNotNil(mmapSrc:match("switchState%(%s*newState%s*,%s*{%s*showname%s*=%s*1%s*}%)"),
        "GAME_MMAP 进子场景必须 switchState(newState, { showname = 1 })")
end

function TestSceneName.testSmapEnterHonorsShowname()
    print("\n=== Test: GAME_SMAP.enter 把 data.showname 传给 Init_SMap ===")
    local f = io.open("framework/game_states.lua", "r")
    if not f then
        TestHelper.assertTrue(false, "无法打开 framework/game_states.lua")
        return
    end
    local src = f:read("*a")
    f:close()

    local body = src:match('handlers%["GAME_SMAP"%]%s*=%s*{%s*enter%s*=%s*function%(prevState,%s*data%)%s*(.-)%s*end,')
    TestHelper.assertNotNil(body, "GAME_SMAP.enter 应接收 (prevState, data)")
    if body then
        TestHelper.assertNotNil(body:match("data%.showname"), "enter 应读取 data.showname")
        TestHelper.assertNotNil(body:match("Init_SMap%(showname%)"),
            "enter 应调用 Init_SMap(showname) 而不是写死 0")
    end
end

-- 用 Init_SMap 桩跑真实 GAME_SMAP.enter：
-- 真实 Init_SMap(1) 需要完整的存档/贴图/音乐数据，本套件刻意不装载，
-- 因此把 Init_SMap 换成只记录 showname 的桩，专测「调用参数是否正确」。
local function enterWithShowname(showname)
    bootHeadless()
    SceneNameAsync.clear()
    JY.SubScene = 1

    local seen = {}
    local origInitSMap = _G.Init_SMap
    _G.Init_SMap = function(v)
        seen[#seen + 1] = v
        -- 真实 Init_SMap 末尾的 showname==1 分支就是调 ShowSceneName()
        if v == 1 then ShowSceneName() end
    end

    local sm = StateMachine.getInstance()
    sm:init()
    local handler = GameStates.getHandler("GAME_SMAP")
    sm:register(4, {
        enter = handler.enter,
        exit = function() end,
        update = function() end,
        draw = function() end,
    })
    sm:register(2, { enter = function() end, exit = function() end,
                     update = function() end, draw = function() end })
    require("framework.input_manager").getInstance():clear()

    sm:switchTo(2)
    local ok, err
    if showname == nil then
        ok, err = pcall(function() sm:switchTo(4) end)
    else
        ok, err = pcall(function() sm:switchTo(4, { showname = showname }) end)
    end

    _G.Init_SMap = origInitSMap
    return ok, err, seen
end

function TestSceneName.testEnterWithShownameShowsPrompt()
    print("\n=== Test: switchTo(GAME_SMAP,{showname=1}) → Init_SMap(1) → 提示激活 ===")
    local ok, err, seen = enterWithShowname(1)
    TestHelper.assertTrue(ok, "switchTo(GAME_SMAP, {showname=1}) 不应报错: " .. tostring(err))
    TestHelper.assertEquals(#seen, 1, "应调用一次 Init_SMap")
    TestHelper.assertEquals(seen[1], 1, "应把 showname=1 传给 Init_SMap")
    TestHelper.assertTrue(SceneNameAsync.isActive(),
        "带 showname=1 进 GAME_SMAP 应激活场景名提示")
    SceneNameAsync.clear()
end

function TestSceneName.testEnterWithoutShownameShowsNoPrompt()
    print("\n=== Test: 不带 showname 进 GAME_SMAP → Init_SMap(0)，不提示 ===")
    local ok, err, seen = enterWithShowname(nil)
    TestHelper.assertTrue(ok, "无 data 切状态不应报错: " .. tostring(err))
    TestHelper.assertEquals(#seen, 1, "仍应调用一次 Init_SMap")
    TestHelper.assertEquals(seen[1], 0, "无 showname 时应传 0（原版 Init_SMap(0) 不显示）")
    TestHelper.assertEquals(SceneNameAsync.isActive(), false,
        "无 showname 时不应提示场景名")
end

function TestSceneName.testEnterWithShownameZeroShowsNoPrompt()
    print("\n=== Test: showname=0 显式传入也不提示 ===")
    local ok, err, seen = enterWithShowname(0)
    TestHelper.assertTrue(ok, "showname=0 不应报错: " .. tostring(err))
    TestHelper.assertEquals(seen[1], 0, "应传 0")
    TestHelper.assertEquals(SceneNameAsync.isActive(), false, "showname=0 不提示")
end

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

    TestSceneName.testShowSkipsBlankName()
    TestSceneName.testShowSetsActiveAndName()
    TestSceneName.testDrawRendersBoxAndText()
    TestSceneName.testDrawNoopWhenInactive()
    TestSceneName.testShowDisablesInput()
    TestSceneName.testKeyDismissesAndRestoresInput()
    TestSceneName.testNoKeyKeepsPrompt()
    TestSceneName.testDrawIsCalledFromEventBridge()
    TestSceneName.testSceneNameModuleUsesCoroutineWait()
    TestSceneName.testNoGlobalHookRemains()
    TestSceneName.testGameStatesHasNoSubStateLeftover()
    TestSceneName.testIsRunningDistinguishesMainThread()

    TestSceneName.testMmapSubscenePassesShowname()
    TestSceneName.testSmapEnterHonorsShowname()
    TestSceneName.testEnterWithShownameShowsPrompt()
    TestSceneName.testEnterWithoutShownameShowsNoPrompt()
    TestSceneName.testEnterWithShownameZeroShowsNoPrompt()

    TestSceneName.testGameInitConstantDefined()
    TestSceneName.testSetGlobalInitializesStatus()
    TestSceneName.testSetGlobalLeavesNoStrayGlobals()

    cleanup()
    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestSceneName
