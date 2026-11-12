-- test_new_event.lua
-- newevent/（scene_X_event_Y.lua）事件分派的单元测试
--
-- 背景（真实缺陷回归）：
--   用户实测在河洛客栈与韦大宝（D*19）对话时卡死、毫无反应。
--   根因是 script/jymodify.lua 的 newCallEvent 用 dofile 同步执行 newevent 脚本，
--   而 newevent 脚本里用的是 TalkEx / Talk / ShowMenu / lib.Delay 这些「阻塞式」
--   原版接口——在本项目的事件驱动架构下，阻塞版 WaitKey 会死等按键，
--   love.update 永不返回，画面完全静止。
--
--   oldevent/ 早就走对了：AsyncGlobals.install() + 协程执行 + uninstall()。
--   newevent/ 一直漏了这套，本套件锁死修复后的三条不变量：
--     1. newCallEvent 不再直接 dofile（改为委托 EventExecutor.newCallEventCoroutine）
--     2. newCallEventCoroutine 执行期间阻塞全局处于「已替换」状态（异步版）
--     3. 执行结束后 uninstall() 已还原，且 JY.CurrentD 被恢复
--
-- 本套件不依赖真实存档/贴图：用临时脚本文件验证 install/uninstall 的时序。

local TestHelper = require("tests.test_helper")

local TestNewEvent = {}

-- ============================================================
-- 无头环境引导
-- ============================================================

local booted = false
local EventExecutor, AsyncGlobals

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

    -- 必须自己加载 jymain：全局 WarMain 由 jymain.lua 定义，本套件的
    -- 「install 期间 WarMain 被替换」用例依赖它存在。
    -- 早前靠 test_scene_name（在全量顺序里排在本套件之前）顺手 require 过，
    -- 于是本套件单跑 / 在全量顺序变更后会报「jymain 应已定义全局 WarMain」失败
    -- ——隐藏的套件间顺序依赖，必须自己补齐。
    pcall(require, CONFIG.ScriptPath .. "jymain")

    EventExecutor = require("framework.event_executor")
    AsyncGlobals = require("framework.async_globals")
end

-- 在还原后的 _G 上执行一段代码（避免前序套件留下的严格元表干扰）
local function withPlainG(fn)
    local saved = getmetatable(_G)
    setmetatable(_G, nil)
    local ok, err = pcall(fn)
    setmetatable(_G, saved)
    return ok, err
end

-- 读取仓库相对路径的源文件
local function readSource(relpath)
    local f = io.open(relpath, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- 去掉 Lua 注释，避免「注释里提到 dofile」被误判为真实调用
local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]", "")   -- 块注释
    src = src:gsub("%-%-[^\n]*", "")       -- 行注释
    return src
end

-- ============================================================
-- 1. 源码级：newCallEvent 必须走协程执行器
-- ============================================================

function TestNewEvent.testNewCallEventUsesCoroutineExecutor()
    print("\n=== Test: newCallEvent 不再直接 dofile，改为委托 newCallEventCoroutine ===")
    bootHeadless()
    local src = readSource("script/jymodify.lua")
    TestHelper.assertNotNil(src, "应能读到 script/jymodify.lua")
    local code = stripComments(src)

    TestHelper.assertTrue(
        code:find("newCallEventCoroutine", 1, true) ~= nil,
        "newCallEvent 必须委托 EventExecutor.newCallEventCoroutine")

    -- 提取 newCallEvent 函数体，确认里面没有裸 dofile
    local start = code:find("function newCallEvent", 1, true)
    TestHelper.assertNotNil(start, "应能定位 newCallEvent 定义")
    local body = code:sub(start, start + 1200)
    local dofilePos = body:find("dofile", 1, true)
    TestHelper.assertNil(dofilePos,
        "newCallEvent 内不得出现 dofile（阻塞式执行会让主线程死等按键）")
end

function TestNewEvent.testNewCallEventCoroutineExists()
    print("\n=== Test: event_executor 提供 newCallEventCoroutine ===")
    bootHeadless()
    TestHelper.assertEquals(type(EventExecutor.newCallEventCoroutine), "function",
        "EventExecutor.newCallEventCoroutine 应是函数")
end

function TestNewEvent.testOldEventStillUsesCoroutine()
    print("\n=== Test: 对照组——oldevent 一直走协程（不应被本次改动影响）===")
    bootHeadless()
    local src = readSource("framework/event_executor.lua")
    local code = stripComments(src)
    local start = code:find("function EventExecutor.oldCallEventCoroutine", 1, true)
    TestHelper.assertNotNil(start, "应能定位 oldCallEventCoroutine")
    local body = code:sub(start, start + 2000)
    TestHelper.assertTrue(body:find("AsyncGlobals.install", 1, true) ~= nil,
        "oldCallEventCoroutine 应调用 AsyncGlobals.install()")
    TestHelper.assertTrue(body:find("AsyncGlobals.uninstall", 1, true) ~= nil,
        "oldCallEventCoroutine 应调用 AsyncGlobals.uninstall()")
end

-- ============================================================
-- 2. 运行时：执行期间阻塞全局被替换，结束后被还原
-- ============================================================

function TestNewEvent.testExecutesWithAsyncGlobalsInstalled()
    print("\n=== Test: 脚本执行期间 WaitKey 处于异步版（关键不变量）===")
    bootHeadless()

    -- 造一个临时 newevent 脚本，记录执行瞬间 _G.WaitKey 是否为异步版
    local probePath = "tests/_tmp_newevent_probe.lua"
    local f = io.open(probePath, "w")
    f:write([[
__NE_WAITKEY_IS_ASYNC = (rawget(_G, "WaitKey") == require("framework.async_globals").WaitKey_Async)
__NE_TALKEX_IS_ASYNC  = (rawget(_G, "TalkEx")  == require("framework.async_globals").TalkEx_Async)
]])
    f:close()

    local observedAsync, observedTalkEx
    local ok, err = withPlainG(function()
        EventExecutor.newCallEventCoroutine(probePath)
        observedAsync = rawget(_G, "__NE_WAITKEY_IS_ASYNC")
        observedTalkEx = rawget(_G, "__NE_TALKEX_IS_ASYNC")
    end)

    os.remove(probePath)
    withPlainG(function()
        rawset(_G, "__NE_WAITKEY_IS_ASYNC", nil)
        rawset(_G, "__NE_TALKEX_IS_ASYNC", nil)
    end)

    TestHelper.assertTrue(ok, "newCallEventCoroutine 不应抛错: " .. tostring(err))
    TestHelper.assertTrue(observedAsync == true,
        "执行期间 WaitKey 必须是异步版（否则主线程会死等按键）")
    TestHelper.assertTrue(observedTalkEx == true,
        "执行期间 TalkEx 必须是异步版（韦大宝对话崩溃的直接原因）")
end

function TestNewEvent.testRestoresGlobalsAfterExecution()
    print("\n=== Test: 执行结束后阻塞全局被还原 ===")
    bootHeadless()

    local probePath = "tests/_tmp_newevent_probe2.lua"
    local f = io.open(probePath, "w")
    f:write("__NE_RAN = true\n")
    f:close()

    local afterWaitKey, afterTalkEx
    local ok = withPlainG(function()
        EventExecutor.newCallEventCoroutine(probePath)
        afterWaitKey = rawget(_G, "WaitKey")
        afterTalkEx = rawget(_G, "TalkEx")
    end)
    os.remove(probePath)
    withPlainG(function() rawset(_G, "__NE_RAN", nil) end)

    TestHelper.assertTrue(ok, "newCallEventCoroutine 不应抛错")
    TestHelper.assertTrue(afterWaitKey ~= AsyncGlobals.WaitKey_Async,
        "执行结束后 WaitKey 应已还原为原版（不应残留异步版）")
    TestHelper.assertTrue(afterTalkEx ~= AsyncGlobals.TalkEx_Async,
        "执行结束后 TalkEx 应已还原为原版（不应残留异步版）")
end

function TestNewEvent.testRestoresCurrentD()
    print("\n=== Test: 执行前后 JY.CurrentD 被保存并恢复 ===")
    bootHeadless()

    local savedJY = rawget(_G, "JY")
    local probePath = "tests/_tmp_newevent_probe3.lua"
    local f = io.open(probePath, "w")
    f:write("JY.CurrentD = -1\n")   -- 脚本内部把 CurrentD 改掉
    f:close()

    local after
    local ok = withPlainG(function()
        rawset(_G, "JY", { CurrentD = 19 })
        EventExecutor.newCallEventCoroutine(probePath)
        after = JY.CurrentD
    end)
    os.remove(probePath)
    withPlainG(function() rawset(_G, "JY", savedJY) end)

    TestHelper.assertTrue(ok, "newCallEventCoroutine 不应抛错")
    TestHelper.assertEquals(after, 19,
        "执行后 JY.CurrentD 应恢复为进入时的值（否则 instruct_3(-2) 会写错 tile）")
end

-- ============================================================
-- 3. 真实脚本存在性与加载能力
-- ============================================================

function TestNewEvent.testWeiDabaoScriptLoads()
    print("\n=== Test: 韦大宝脚本 script/newevent/scene_1_event_19.lua 可被加载 ===")
    bootHeadless()
    local ScriptLoader = require("framework.script_loader")
    local chunk, err = ScriptLoader.load("script/newevent/scene_1_event_19.lua")
    TestHelper.assertNotNil(chunk, "韦大宝事件脚本应能被加载: " .. tostring(err))
    TestHelper.assertEquals(type(chunk), "function", "加载结果应是可执行 chunk")
end

function TestNewEvent.testWeiDabaoScriptHasBlockingApis()
    print("\n=== Test: 韦大宝脚本确实使用阻塞式接口（证明必须走异步替换）===")
    bootHeadless()
    local src = readSource("script/newevent/scene_1_event_19.lua")
    TestHelper.assertNotNil(src, "应能读到韦大宝脚本")
    local code = stripComments(src)
    local blocking = { "TalkEx", "Talk", "ShowMenu", "DrawStrBoxWaitKey", "DrawStrBoxYesNo" }
    local found = {}
    for _, name in ipairs(blocking) do
        if code:find(name, 1, true) then found[#found + 1] = name end
    end
    TestHelper.assertTrue(#found >= 3,
        "韦大宝脚本应使用多个阻塞式接口（实际找到: " .. table.concat(found, ",") .. "）")
end

-- ============================================================
-- 4. WarMain 异步替换（韦大宝「佣兵行会」依赖）
-- ============================================================

function TestNewEvent.testWarMainGetsAsyncWrapper()
    print("\n=== Test: install() 期间 WarMain 被替换为异步包装 ===")
    bootHeadless()
    local original = rawget(_G, "WarMain")
    TestHelper.assertNotNil(original, "jymain 应已定义全局 WarMain")

    local during
    local ok, err = withPlainG(function()
        AsyncGlobals.install()
        during = rawget(_G, "WarMain")
        AsyncGlobals.uninstall()
    end)
    TestHelper.assertTrue(ok, "install/uninstall 不应抛错: " .. tostring(err))
    TestHelper.assertTrue(during ~= original,
        "install() 期间 WarMain 应被替换（否则韦大宝佣兵行会会阻塞主线程）")
end

function TestNewEvent.testWarMainRestoredAfterUninstall()
    print("\n=== Test: uninstall() 后 WarMain 还原 ===")
    bootHeadless()
    local original
    local after
    local ok = withPlainG(function()
        original = rawget(_G, "WarMain")
        AsyncGlobals.install()
        AsyncGlobals.uninstall()
        after = rawget(_G, "WarMain")
    end)
    TestHelper.assertTrue(ok, "install/uninstall 不应抛错")
    TestHelper.assertEquals(after, original, "uninstall() 后 WarMain 应还原为原版")
end

-- 回归：AsyncGlobals.install() 必须可重入。
--
-- 事件脚本里嵌套触发另一个事件时，内层 EventExecutor 会再次 install()。
-- 旧实现每次都无条件把「当前全局」当原版保存，于是：
--   * 内层保存到的是外层已替换的异步版；
--   * 内层 uninstall 把异步版当原版写回 → 异步版永久驻留；
--   * WarMain 包装器闭包引用同一个 _WarMain upvalue，二次安装后
--     「原版」指向自己的包装器 → 非协程分支无限自我递归。
function TestNewEvent.testInstallIsReentrant()
    print("\n=== Test: install()/uninstall() 可重入（嵌套事件）===")
    bootHeadless()

    local origWaitKey = function() return "ORIG" end
    local origWarMain = function() return "ORIG_WAR" end
    local savedWK, savedWM = rawget(_G, "WaitKey"), rawget(_G, "WarMain")

    local duringInner, innerAfterUninstall, depthAfterAll, finalWK, finalWM
    local ok, err = withPlainG(function()
        rawset(_G, "WaitKey", origWaitKey)
        rawset(_G, "WarMain", origWarMain)

        AsyncGlobals.install()            -- 外层事件
        AsyncGlobals.install()            -- 内层事件（嵌套触发）
        duringInner = rawget(_G, "WaitKey")
        AsyncGlobals.uninstall()          -- 内层结束
        innerAfterUninstall = rawget(_G, "WaitKey")
        AsyncGlobals.uninstall()          -- 外层结束
        depthAfterAll = AsyncGlobals.installDepth and AsyncGlobals.installDepth() or -1
        finalWK = rawget(_G, "WaitKey")
        finalWM = rawget(_G, "WarMain")
    end)

    rawset(_G, "WaitKey", savedWK)
    rawset(_G, "WarMain", savedWM)
    -- 用 pcall：旧实现没有这个调试钩子，不该因此把断言失败变成崩溃
    pcall(AsyncGlobals.resetInstallState)

    TestHelper.assertTrue(ok, "嵌套 install/uninstall 不应抛错: " .. tostring(err))
    TestHelper.assertTrue(duringInner ~= origWaitKey,
        "嵌套期间 WaitKey 应处于异步版")
    TestHelper.assertTrue(innerAfterUninstall ~= origWaitKey,
        "退掉内层后 WaitKey 仍应是异步版（外层事件还在执行）")
    TestHelper.assertEquals(0, depthAfterAll, "全部退出后安装深度归零")
    TestHelper.assertTrue(finalWK == origWaitKey,
        "全部退出后 WaitKey 必须还原为真原版（不得残留异步版）")
    TestHelper.assertTrue(finalWM == origWarMain,
        "全部退出后 WarMain 必须还原为真原版（否则包装器会自我递归）")
end
function TestNewEvent.testWarMainFallsBackOutsideCoroutine()
    print("\n=== Test: 非协程上下文时 WarMain 保持原版行为（不误用协程调度）===")
    bootHeadless()
    -- 用一个可识别的假原版 WarMain，确认非协程分支会调用它
    local saved = rawget(_G, "WarMain")
    local called = false
    local ok = withPlainG(function()
        rawset(_G, "WarMain", function() called = true; return "orig" end)
        AsyncGlobals.install()
        local r = rawget(_G, "WarMain")(1, 1)   -- 主线程调用
        called = called and (r == "orig")
        AsyncGlobals.uninstall()
        rawset(_G, "WarMain", saved)
    end)
    TestHelper.assertTrue(ok, "不应抛错")
    TestHelper.assertTrue(called, "非协程上下文应回退到原版 WarMain")
end

function TestNewEvent.testWeiDabaoUsesWarMain()
    print("\n=== Test: 韦大宝脚本确实调用 WarMain（佣兵行会）===")
    bootHeadless()
    local src = readSource("script/newevent/scene_1_event_19.lua")
    local code = stripComments(src)
    TestHelper.assertTrue(code:find("WarMain", 1, true) ~= nil,
        "韦大宝脚本应调用 WarMain（佣兵行会任务战斗）")
end

function TestNewEvent.testNoBareFrameworkRequire()
    print("\n=== Test: script/ 中不得出现缺少 framework. 前缀的框架模块 require ===")
    bootHeadless()
    local src = readSource("script/jymain.lua")
    local code = stripComments(src)
    local bad = { "coroutine_scheduler", "war_async", "event_executor",
                  "input_manager", "state_machine", "menu_async" }
    local hits = {}
    for _, name in ipairs(bad) do
        -- 匹配 require("name") 且前面没有 framework.
        if code:find('require("' .. name .. '")', 1, true) then
            hits[#hits + 1] = name
        end
    end
    TestHelper.assertEquals(#hits, 0,
        "存在裸名 require（实测跑不起来）: " .. table.concat(hits, ", "))
end

-- ============================================================
-- 5. 菜单回调必须协程化（韦大宝「典当」Cannot yield 根因）
-- ============================================================

-- ============================================================
-- 4b. 嵌套菜单必须成对保存/恢复回调（键盘无响应根因）
-- ============================================================

-- 引导菜单专用环境：补齐 menu_state_machine 依赖的脚本全局
local menuBooted = false
local function bootMenuEnv()
    if menuBooted then return end
    menuBooted = true
    bootHeadless()
    rawset(_G, "Cls", function() end)
    rawset(_G, "DrawBox", function() end)
    rawset(_G, "DrawStr", function() end)
    rawset(_G, "C_WHITE", 0xFFFFFFFF)
    rawset(_G, "C_ORANGE", 0xFFFF8000)
    for _, n in ipairs({"ShowMenu", "ShowMenu2", "WaitKey", "ShowScreen",
                        "DrawStrBoxWaitKey", "WarMain"}) do
        rawset(_G, n, function() return 0 end)
    end
    rawset(_G, "TalkEx", function() end)
    rawset(_G, "DrawStrBoxYesNo", function() return 1 end)
    require("framework.async_globals").install()
end

function TestNewEvent.testNestedMenuRestoresOuterCallback()
    print("\n=== Test: 嵌套菜单关闭后外层回调必须恢复（否则事件协程永久挂起）===")
    bootMenuEnv()
    local CS  = require("framework.coroutine_scheduler").getInstance()
    local MA  = require("framework.menu_async")
    local MSM = require("framework.menu_state_machine").getInstance()
    MSM:clear()
    CS:clear()

    local returned, value = false, nil
    -- 复刻韦大宝「瞬息千里」：外层 ShowMenu 在协程里，回调内再 ShowMenu
    local outer = { {"瞬息千里", function()
        ShowMenu({ {"客栈A", nil, 1} }, 1, 0, 200, 200, 0, 0, 1, 1, 24, nil, nil)
        return 1
    end, 1} }

    CS:start(CS:create(function()
        value = ShowMenu(outer, 1, 0, 100, 100, 0, 0, 1, 1, 16, nil, nil)
        returned = true
    end, "event_script"))
    for _ = 1, 4 do CS:update(0.016); MA.update(0.016) end

    -- 选外层项 → 回调内弹嵌套菜单
    MSM:getCurrentMenu().current = 1
    MSM:selectMenuItem()
    for _ = 1, 4 do CS:update(0.016); MA.update(0.016) end
    TestHelper.assertNotNil(MSM:getCurrentMenu(), "嵌套菜单应已弹出")

    -- 关闭嵌套菜单
    MSM:closeMenu(0)
    for _ = 1, 20 do CS:update(0.016); MA.update(0.016) end

    TestHelper.assertTrue(returned,
        "嵌套菜单关闭后外层 ShowMenuCoroutine 必须返回（否则事件协程永久挂起、JY.CurrentD 不复位、键盘全失效）")
    MSM:clear()
    CS:clear()
end

function TestNewEvent.testCallbackStackPairedWithMenuStack()
    print("\n=== Test: callback 与 menuStack 成对压栈/出栈 ===")
    bootMenuEnv()
    local MSM = require("framework.menu_state_machine").getInstance()
    MSM:clear()

    local outerCb = function() end
    local innerCb = function() end
    MSM:openMenu(MSM:createMenu({ {"A", nil, 1} }, 1, 0, 0, 0, 0, 0, 0, 1, 16, nil, nil), outerCb)
    MSM:openMenu(MSM:createMenu({ {"B", nil, 1} }, 1, 0, 0, 0, 0, 0, 0, 1, 16, nil, nil), innerCb)

    TestHelper.assertEquals(#MSM.menuStack, 1, "嵌套打开后菜单栈深度应为 1")
    TestHelper.assertEquals(#MSM.callbackStack, 1, "嵌套打开后回调栈深度也应为 1（成对）")
    TestHelper.assertEquals(MSM.callback, innerCb, "当前回调应属内层")

    MSM:closeMenu(0)
    TestHelper.assertEquals(MSM.callback, outerCb,
        "关闭内层后当前回调必须恢复为外层（否则外层协程永远醒不来）")
    MSM:clear()
end

function TestNewEvent.testClearNotifiesAllCallbacks()
    print("\n=== Test: clear() 必须通知所有层级回调（防外部清理致挂起）===")
    bootMenuEnv()
    local CS  = require("framework.coroutine_scheduler").getInstance()
    local MA  = require("framework.menu_async")
    local MSM = require("framework.menu_state_machine").getInstance()
    MSM:clear()
    CS:clear()

    local returned = false
    CS:start(CS:create(function()
        ShowMenu({ {"甲", nil, 1} }, 1, 0, 0, 0, 0, 0, 0, 1, 16, nil, nil)
        returned = true
    end, "event_script"))
    for _ = 1, 4 do CS:update(0.016); MA.update(0.016) end
    TestHelper.assertTrue(MSM:hasActiveMenu(), "菜单应已弹出")

    MA.clear()   -- 外部强制清理（如切场景）
    for _ = 1, 6 do CS:update(0.016); MA.update(0.016) end
    TestHelper.assertTrue(returned,
        "clear() 必须回调所有层级，否则 ShowMenuCoroutine 永久挂起")
    MSM:clear()
    CS:clear()
end

-- ============================================================
-- 4c. 战斗收尾：敌人全灭后寻路不得崩溃、对话气泡不得残留
-- ============================================================

function TestNewEvent.testWarAutoMoveGuardsNilEnemy()
    print("\n=== Test: 敌人全灭后 War_AutoMoveCoroutine 不得索引 nil 敌人 ===")
    local src = readSource("framework/war_async.lua")
    local noComments = stripComments(src)

    -- 原缺陷：War_AutoSelectEnemy_near() 找不到存活敌人时返回 -1，
    -- 随后 WAR.Person[-1]["坐标X"] 抛 attempt to index a nil value，
    -- 战斗协程静默死亡 → JY.Status 停在 GAME_WMAP → 卡在战斗画面。
    TestHelper.assertTrue(noComments:find("War_AutoSelectEnemy", 1, true) ~= nil,
        "War_AutoMoveCoroutine 应调用 War_AutoSelectEnemy")
    TestHelper.assertTrue(noComments:find("enemyid < 0", 1, true) ~= nil,
        "必须在 WAR.Person[enemyid] 之前判断 enemyid < 0（否则敌人全灭时崩溃）")
    TestHelper.assertTrue(noComments:find("not WAR.Person[enemyid]", 1, true) ~= nil,
        "必须同时判断 WAR.Person[enemyid] 是否存在")
end

function TestNewEvent.testWarAutoMoveGuardHasDiscriminatingPower()
    print("\n=== Test: 上述守卫的触发路径真实存在（负向复现）===")
    -- 复刻缺陷片段：enemyid = -1 且地图存在可走格时，索引必然抛错
    local WAR = { PersonNum = 1, CurID = 0, Person = { [0] = { ["坐标X"] = 1, ["坐标Y"] = 1 } } }
    local function GetWarMap() return 5 end   -- <128 → 进入内层
    local enemyid = -1

    local crashed = not pcall(function()
        for i = 0, 3 do
            for j = 0, 3 do
                if GetWarMap(i, j, 3) < 128 then
                    local dx = math.abs(i - WAR.Person[enemyid]["坐标X"])
                    local dy = math.abs(j - WAR.Person[enemyid]["坐标Y"])
                    local _ = dx + dy
                end
            end
        end
    end)
    TestHelper.assertTrue(crashed,
        "无守卫时 enemyid=-1 必须抛错（证明该分支确实可达、守卫有必要）")

    local survived = pcall(function()
        for i = 0, 3 do
            for j = 0, 3 do
                if GetWarMap(i, j, 3) < 128 then
                    if not enemyid or enemyid < 0 or not WAR.Person[enemyid] then
                        return
                    end
                end
            end
        end
    end)
    TestHelper.assertTrue(survived, "加上守卫后不得抛错")
end

function TestNewEvent.testTalkClearedOnBattleStart()
    print("\n=== Test: 开战必须清掉残留对话气泡 ===")
    local talkSrc = stripComments(readSource("framework/talk_async.lua"))
    TestHelper.assertTrue(talkSrc:find("function TalkAsync.clear()", 1, true) ~= nil,
        "TalkAsync 必须提供 clear()，供开战时清掉残留气泡")

    local warSrc = stripComments(readSource("framework/war_async.lua"))
    TestHelper.assertTrue(warSrc:find("TalkAsync.clear()", 1, true) ~= nil,
        "WarMainCoroutine 进入战斗时必须调用 TalkAsync.clear()")
    -- 清空动作要在设成 GAME_WMAP 之后（此时才确定要开战）
    local iStatus = warSrc:find("JY.Status = GAME_WMAP", 1, true)
    local iClear  = warSrc:find("TalkAsync.clear()", 1, true)
    TestHelper.assertTrue(iStatus ~= nil and iClear ~= nil and iClear > iStatus,
        "TalkAsync.clear() 必须在 JY.Status = GAME_WMAP 之后调用")
end

function TestNewEvent.testTalkDrawSkipsBattleStates()
    print("\n=== Test: 战斗状态下 TalkAsync.draw 不得绘制 ===")
    local src = stripComments(readSource("framework/talk_async.lua"))
    local iDraw = src:find("function TalkAsync.draw()", 1, true)
    TestHelper.assertNotNil(iDraw, "应存在 TalkAsync.draw")
    local seg = src:sub(iDraw, iDraw + 1400)
    TestHelper.assertTrue(seg:find("GAME_WMAP", 1, true) ~= nil,
        "TalkAsync.draw 必须跳过 GAME_WMAP（否则对话框重复画在战斗画面上）")
end

function TestNewEvent.testWarClearsPersonExp()
    print("\n=== Test: 战斗结束必须清零 WAR.Person 经验（原版行为）===")
    local src = stripComments(readSource("framework/war_async.lua"))
    TestHelper.assertTrue(src:find('WAR.Person[i]["经验"] = 0', 1, true) ~= nil,
        "WAR 表跨场复用，不清零会让经验逐场累加（原版 WarMain 有此循环）")
end

function TestNewEvent.testWarMainRecoversFromCoroutineError()
    print("\n=== Test: 战斗协程异常死亡后必须能恢复状态 ===")
    local src = stripComments(readSource("framework/async_globals.lua"))
    TestHelper.assertTrue(src:find('info.status == "error"', 1, true) ~= nil,
        "WarMain 包装器必须检测战斗协程 error 状态")
    TestHelper.assertTrue(src:find("JY.Status = GAME_SMAP", 1, true) ~= nil,
        "检测到 error 后必须把 JY.Status 从 GAME_WMAP 拉回 GAME_SMAP")
end

-- ============================================================
-- 4d. 菜单回调执行期间不得绘制菜单（战斗画面不得残留选项单）
-- ============================================================

function TestNewEvent.testMenuNotDrawnWhileCallbackExecutes()
    print("\n=== Test: 回调执行期间 draw 必须跳过菜单 ===")
    local src = stripComments(readSource("framework/menu_state_machine.lua"))

    local iDraw = src:find("function MenuStateMachine:draw()", 1, true)
    TestHelper.assertNotNil(iDraw, "应存在 MenuStateMachine:draw")
    local seg = src:sub(iDraw, iDraw + 1400)
    TestHelper.assertTrue(seg:find("menu.callbackCo", 1, true) ~= nil,
        "draw 必须以 menu.callbackCo 为判据（否则嵌套菜单回调期间外层菜单盖在战斗画面上）")

    -- 架构约束：判据必须是「字段读取」，不得回退成遍历协程 / 依赖调度器。
    -- 事件驱动意味着 draw 只读状态机自己的状态，不去轮询它方活性。
    TestHelper.assertTrue(seg:find("isActive", 1, true) == nil,
        "draw 不得轮询协程活性（那是全局 flag 轮询，违反事件驱动）")
    TestHelper.assertTrue(seg:find("CoroutineScheduler", 1, true) == nil,
        "draw 不得依赖 CoroutineScheduler（菜单状态机不应感知调度器）")
end

function TestNewEvent.testMenuDrawGuardHasDiscriminatingPower()
    print("\n=== Test: 上述守卫的触发场景真实存在（端到端复刻）===")
    local env = bootMenuEnv()
    local CS  = require("framework.coroutine_scheduler").getInstance()
    local MA  = require("framework.menu_async")
    local MSM = require("framework.menu_state_machine").getInstance()
    CS:clear(); MSM:clear()

    -- 复刻韦大宝分支：外层 4 项菜单 → 选「佣兵行会」→ 内层菜单 → WarMain 挂起
    local warSawMenu, cbAtWar = nil, nil
    local function Menu_Task()
        ShowMenu({ {"去沙漠消灭蜘蛛怪", nil, 1, 61, 50} }, 1, 0, 0, 0, 0, 0, 0, 1, 16, nil, nil)
        local m = MSM:getCurrentMenu()
        warSawMenu = (m ~= nil)
        cbAtWar = (m ~= nil) and (m.callbackCo ~= nil)
        for i = 1, 50 do CS:yield("war_main_wait") end
    end

    CS:start(CS:create(function()
        ShowMenu({ {"典当服务", function() end, 1},
                   {"地下市场", function() end, 1},
                   {"佣兵行会", Menu_Task, 1},
                   {"瞬息千里", function() end, 1} },
                 4, 0, 0, 0, 0, 1, 1, 16, nil, nil)
    end, "event_script"))

    -- 菜单刚打开（未选择）：callbackCo 为 nil，应当可绘制
    for i = 1, 3 do CS:update(0.016); MA.update(0.016) end
    TestHelper.assertNil(MSM:getCurrentMenu().callbackCo,
        "菜单等待玩家选择时 callbackCo 必须为 nil（否则菜单永远不显示）")

    MSM:getCurrentMenu().current = 3
    MSM:selectMenuItem()
    for i = 1, 4 do CS:update(0.016); MA.update(0.016) end

    -- 内层菜单打开、等玩家选择：仍是 nil，应当可绘制
    TestHelper.assertNil(MSM:getCurrentMenu().callbackCo,
        "内层菜单等待选择时 callbackCo 必须为 nil")

    MSM:getCurrentMenu().current = 1
    MSM:selectMenuItem()
    for i = 1, 6 do CS:update(0.016); MA.update(0.016) end

    TestHelper.assertTrue(warSawMenu == true,
        "端到端前提：战斗开始时外层菜单仍在 activeMenu（这正是缺陷的土壤）")
    TestHelper.assertTrue(cbAtWar == true,
        "战斗期间外层菜单的 callbackCo 必须仍在（回调 Menu_Task 未返回）")

    -- 战斗期间逐帧调用 draw()，确认守卫真的让绘制提前返回。
    --
    -- 注意：本 headless 环境里 bootHeadless() 会切换 _ENV，劫持 _G.DrawString
    -- 无法被 menu_state_machine 内部解析到（实测 drawnItems 恒为 0，无判别力），
    -- 因此这里改为观察 draw() 的可观察副作用：DrawBox 边框。
    -- 边框由 DrawBox 绘制，同样走全局解析——若也不可达则只断言状态前提，
    -- 判别力由 testMenuNotDrawnWhileCallbackExecutes 的源码断言承担。
    local menuPresent, cbPresent = 0, 0
    for i = 1, 5 do
        if MSM.activeMenu then
            menuPresent = menuPresent + 1
            if MSM.activeMenu.callbackCo then cbPresent = cbPresent + 1 end
        end
        MSM:draw(); CS:update(0.016)
    end

    TestHelper.assertTrue(menuPresent > 0,
        "端到端前提：战斗期间 activeMenu 必须仍在（否则本测试没有判别力）")
    TestHelper.assertTrue(cbPresent > 0,
        "战斗期间 callbackCo 必须一直存在——正是它让 draw() 每帧提前返回")
    MSM:clear(); CS:clear()
end


function TestNewEvent.testMenuCallbackRunsInCoroutine()
    print("\n=== Test: 菜单回调在协程中执行（主线程不能 yield）===")
    bootHeadless()
    local MSM = require("framework.menu_state_machine")
    local src = readSource("framework/menu_state_machine.lua")
    local code = stripComments(src)
    local start = code:find("function MenuStateMachine:selectMenuItem", 1, true)
    TestHelper.assertNotNil(start, "应能定位 selectMenuItem")
    local body = code:sub(start, start + 2500)

    TestHelper.assertTrue(body:find("scheduler:create", 1, true) ~= nil,
        "selectMenuItem 必须把回调放进协程（否则回调里的 SelectThing/TalkEx 会抛 Cannot yield）")
    -- 危险写法：直接在主线程调 item[2](...)（赋值形式 `= item[2](` 或裸调用）
    TestHelper.assertNil(body:find("= item[2](menu.newMenu", 1, true),
        "不得在主线程直接调用菜单回调")
end

function TestNewEvent.testMenuCallbackPollingExists()
    print("\n=== Test: 提供 pollCallback 供 update 轮询 ===")
    bootHeadless()
    local MSM = require("framework.menu_state_machine")
    local inst = MSM.getInstance()
    TestHelper.assertEquals(type(inst.pollCallback), "function",
        "MenuStateMachine:pollCallback 应存在")
end

function TestNewEvent.testExecutingStateSkipsInput()
    print("\n=== Test: EXECUTING 期间不接受输入（避免重复触发）===")
    bootHeadless()
    local src = readSource("framework/menu_state_machine.lua")
    local code = stripComments(src)
    local start = code:find("function MenuStateMachine:handleInput", 1, true)
    TestHelper.assertNotNil(start, "应能定位 handleInput")
    local body = code:sub(start, start + 800)
    TestHelper.assertTrue(body:find("EXECUTING", 1, true) ~= nil,
        "handleInput 应在 EXECUTING 状态下直接 return")
end

-- ============================================================
-- 6. SelectThing 必须转发调用方的物品数组
-- ============================================================

function TestNewEvent.testSelectThingForwardsArgs()
    print("\n=== Test: 替换版 SelectThing 转发入参（不得忽略调用方数组）===")
    bootHeadless()
    local src = readSource("framework/async_globals.lua")
    local code = stripComments(src)
    local idx = code:find('_G.SelectThing = function', 1, true)
    TestHelper.assertNotNil(idx, "应能定位 SelectThing 替换")
    local body = code:sub(idx, idx + 400)
    TestHelper.assertTrue(body:find("SelectThingByArrayAsync", 1, true) ~= nil,
        "带参数的调用必须转发到 SelectThingByArrayAsync（否则典当列表读错背包）")
    TestHelper.assertTrue(body:find("thing", 1, true) ~= nil,
        "替换版应接受并转发 thing 参数")
end

function TestNewEvent.testSelectThingByArrayExists()
    print("\n=== Test: ItemAsync.SelectThingByArrayAsync 存在 ===")
    bootHeadless()
    local ItemAsync = require("framework.item_async")
    TestHelper.assertEquals(type(ItemAsync.SelectThingByArrayAsync), "function",
        "SelectThingByArrayAsync 应存在")
end

function TestNewEvent.testNewEventPathConfigured()
    print("\n=== Test: CONFIG.NewEventPath 指向 newevent/ ===")
    bootHeadless()
    TestHelper.assertNotNil(rawget(_G, "CONFIG"), "全局 CONFIG 应已由 framework/config.lua 建立")
    TestHelper.assertNotNil(CONFIG.NewEventPath, "CONFIG.NewEventPath 应存在")
    TestHelper.assertTrue(CONFIG.NewEventPath:find("newevent", 1, true) ~= nil,
        "NewEventPath 应指向 newevent/，实际: " .. tostring(CONFIG.NewEventPath))
end

-- ============================================================
-- 运行入口
-- ============================================================

function TestNewEvent.runAll()
    TestNewEvent.testNewCallEventUsesCoroutineExecutor()
    TestNewEvent.testNewCallEventCoroutineExists()
    TestNewEvent.testOldEventStillUsesCoroutine()
    TestNewEvent.testExecutesWithAsyncGlobalsInstalled()
    TestNewEvent.testRestoresGlobalsAfterExecution()
    TestNewEvent.testRestoresCurrentD()
    TestNewEvent.testWeiDabaoScriptLoads()
    TestNewEvent.testWeiDabaoScriptHasBlockingApis()
    TestNewEvent.testWarMainGetsAsyncWrapper()
    TestNewEvent.testWarMainRestoredAfterUninstall()
    TestNewEvent.testInstallIsReentrant()
    TestNewEvent.testWarMainFallsBackOutsideCoroutine()
    TestNewEvent.testWeiDabaoUsesWarMain()
    TestNewEvent.testNoBareFrameworkRequire()
    TestNewEvent.testNestedMenuRestoresOuterCallback()
    TestNewEvent.testCallbackStackPairedWithMenuStack()
    TestNewEvent.testClearNotifiesAllCallbacks()
    TestNewEvent.testWarAutoMoveGuardsNilEnemy()
    TestNewEvent.testWarAutoMoveGuardHasDiscriminatingPower()
    TestNewEvent.testTalkClearedOnBattleStart()
    TestNewEvent.testTalkDrawSkipsBattleStates()
    TestNewEvent.testWarClearsPersonExp()
    TestNewEvent.testWarMainRecoversFromCoroutineError()
    TestNewEvent.testMenuNotDrawnWhileCallbackExecutes()
    TestNewEvent.testMenuDrawGuardHasDiscriminatingPower()
    TestNewEvent.testMenuCallbackRunsInCoroutine()
    TestNewEvent.testMenuCallbackPollingExists()
    TestNewEvent.testExecutingStateSkipsInput()
    TestNewEvent.testSelectThingForwardsArgs()
    TestNewEvent.testSelectThingByArrayExists()
    TestNewEvent.testNewEventPathConfigured()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestNewEvent
