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
    TestNewEvent.testWarMainFallsBackOutsideCoroutine()
    TestNewEvent.testWeiDabaoUsesWarMain()
    TestNewEvent.testNoBareFrameworkRequire()
    TestNewEvent.testNewEventPathConfigured()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestNewEvent
