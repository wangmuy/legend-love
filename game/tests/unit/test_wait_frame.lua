-- test_wait_frame.lua
-- WaitFrame helper 的回归测试（change: port-blocking-delay Task 2）
--
-- 守的坑（实测发现）：
--   script 层的帧率控制模式是
--     t1 = lib.GetTime(); 动作(); t2 = lib.GetTime()
--     lib.Delay(FRAME - (t2 - t1))
--   而 `lib.Delay` = `love.timer.sleep` → **真阻塞主线程**（实测占 101ms）。
--
--   这些 `instruct_*` 实际在**事件协程里**跑，所以可以换成
--   `scheduler:waitForTime` 的协作式等待。
--
-- WaitFrame 的设计：
--   协程里 → scheduler:waitForTime(ms/1000)（非阻塞）
--   非协程 → fallback(ms)（= EngineAPI.time.sleep，阻塞但不崩）
--
-- **port-compat-layer-removal 之后 fallback 不再走全局 `lib.Delay`**：
--   `_G.lib` 已删除，`WaitFrame` 的 fallback 闭包绑定的是
--   `EngineAPI.time.sleep`（且在 `async_globals` 覆盖前取到的原始实现）。
--
-- 为什么需要这个测试：
--   全量测试 3895 条**覆盖不到**「是否真的不阻塞」——因为测试里的 `lib.Delay`
--   是桩，桩当然不阻塞。所以必须直接测调度器的行为。

local TestHelper = require("tests.test_helper")
local TestWaitFrame = {}

-- `lib` 桩被调用的次数（>0 说明 WaitFrame 还在摸已删除的兼容层）
local libDelayCalls = {}

--- 装最小环境：EngineAPI（含 time/sleep 计数）+ lib（仅用于误用检测）
local function installEnv(blockingDelay)
    local saved = {
        EngineAPI = rawget(_G, "EngineAPI"),
        lib = rawget(_G, "lib"),
        WaitFrame = rawget(_G, "WaitFrame"),
    }
    local delayCalls = {}
    for i = #libDelayCalls, 1, -1 do libDelayCalls[i] = nil end

    rawset(_G, "EngineAPI", {
        time = {
            getTime = function() return 0 end,
            getTimeSeconds = function() return 0 end,
            sleep = function(ms)
                delayCalls[#delayCalls + 1] = ms
                if blockingDelay and blockingDelay > 0 then
                    local t0 = os.clock()
                    while os.clock() - t0 < blockingDelay / 1000 do end
                end
            end,
        },
        debug = { log = function() end },
        coroutine = {
            isRunning = function()
                local co, ismain = coroutine.running()
                return co ~= nil and ismain ~= true
            end,
        },
    })
    -- `lib` 只保留一个用于「误用检测」的桩：若 WaitFrame 还会去摸它，
    -- 下面 testWaitFrameNeverTouchesGlobalLib 会失败。
    rawset(_G, "lib", {
        Delay = function(ms)
            libDelayCalls[#libDelayCalls + 1] = ms
        end,
        GetTime = function() return 0 end,
    })
    return saved, delayCalls
end

local function restoreEnv(saved)
    for k, v in pairs(saved) do
        if v == nil then
            rawset(_G, k, nil)
        else
            rawset(_G, k, v)
        end
    end
end

--- 装 WaitFrame（复刻 jymain 里的实现）
local function installWaitFrame()
    package.loaded["framework.coroutine_scheduler"] = nil
    local CS = require("framework.coroutine_scheduler")
    local s = CS.getInstance()
    s:reset()

    rawset(_G, "WaitFrame", function(ms)
        if ms == nil or ms <= 0 then return end
        local sleep = rawget(_G, "EngineAPI").time.sleep
        s:waitFrame(ms, function(m) sleep(m) end)
    end)
    return s
end

-- ------------------------------------------------------------ ① 协程里不阻塞

function TestWaitFrame.testCoroutineDoesNotBlock()
    print("\n=== Test: 协程里 WaitFrame(100) 不阻塞主线程（< 10ms）===")
    local saved, delayCalls = installEnv(0)
    local s = installWaitFrame()

    local fakeNow = 0
    s.timeSource = function() return fakeNow end

    local wallStart = os.clock()
    local doneAt = nil

    local id = s:create(function()
        WaitFrame(100)
        doneAt = "done"
    end, "wf")
    s:start(id)

    -- 立刻返回（只 yield 了），不阻塞
    local elapsed = (os.clock() - wallStart) * 1000
    TestHelper.assertTrue(elapsed < 10,
        "WaitFrame(100) 在协程里应立即返回（实测 " .. string.format("%.1f", elapsed) .. "ms）")
    TestHelper.assertEquals(0, #delayCalls,
        "协程里不应调 time.sleep（实测 " .. #delayCalls .. " 次）")

    -- 推进假时钟直到恢复
    for _ = 1, 20 do
        s:update(1 / 60)
        fakeNow = fakeNow + 1 / 60
        if doneAt then break end
    end
    TestHelper.assertNotNil(doneAt, "协程应最终恢复")
    restoreEnv(saved)
end

-- ------------------------------------------------------------ ② 非协程回退

function TestWaitFrame.testOutsideCoroutineFallsBack()
    print("\n=== Test: 非协程上下文退回 lib.Delay ===")
    local saved, delayCalls = installEnv(0)
    local s = installWaitFrame()

    -- 不在任何协程里调用
    WaitFrame(50)
    TestHelper.assertEquals(1, #delayCalls, "非协程应调 time.sleep 1 次")
    TestHelper.assertEquals(50, delayCalls[1], "应传原始 ms")
    restoreEnv(saved)
end

-- ------------------------------------------------------------ ③ 边界值

function TestWaitFrame.testZeroAndNegativeNoop()
    print("\n=== Test: WaitFrame(0) / 负数 / nil 什么都不做 ===")
    local saved, delayCalls = installEnv(0)
    local s = installWaitFrame()

    WaitFrame(0)
    WaitFrame(-100)
    WaitFrame(nil)
    TestHelper.assertEquals(0, #delayCalls, "0/负数/nil 应完全 no-op")
    restoreEnv(saved)
end

-- ------------------------------------------------------------ ④ 源码检查

function TestWaitFrame.testScriptHasNoRawLibDelay()
    print("\n=== Test: script/ 的帧率控制已全部换成 WaitFrame ===")
    local function readSource(rel)
        for _, p in ipairs({ rel, "../game/" .. rel }) do
            local f = io.open(p, "r")
            if f then
                local s = f:read("*a")
                f:close()
                return s
            end
        end
        return nil
    end

    local files = { "script/jymain.lua",
                    "script/battle/battle_action.lua",
                    "script/battle/battle_ai.lua",
                    "script/battle/battle_flow.lua" }
    local rawDelay = 0
    for _, rel in ipairs(files) do
        local src = readSource(rel)
        if src then
            for line in src:gmatch("[^\r\n]+") do
                local code = line:gsub("^%s*%-%-.*$", "")
                -- 排除 helper 自己的 fallback 行（`function(m) lib.Delay(m) end`）
                if code:find("lib%.Delay") and not code:find("function%(m%) lib%.Delay") then
                    rawDelay = rawDelay + 1
                end
            end
        end
    end
    TestHelper.assertEquals(0, rawDelay,
        "script/ 不应再直接调 lib.Delay（实测 " .. rawDelay .. " 处）")
end

function TestWaitFrame.testWaitFrameIsGlobal()
    print("\n=== Test: WaitFrame 是全局函数（battle/*.lua 也要用）===")
    local src = io.open("script/jymain.lua", "r")
    if not src then src = io.open("../game/script/jymain.lua", "r") end
    TestHelper.assertNotNil(src, "应能读到 jymain.lua")
    local s = src:read("*a")
    src:close()

    TestHelper.assertNotNil(s:find("function WaitFrame(ms)", 1, true),
        "应有全局 function WaitFrame(ms)")
    TestHelper.assertNil(s:find("local function WaitFrame", 1, true),
        "不应是 local（battle/*.lua 是全局函数定义，看不到 local）")
end

-- ------------------------------------------------- ⑤ 不得摸已删除的全局 lib

function TestWaitFrame.testNeverTouchesGlobalLib()
    print("\n=== Test: WaitFrame 不再摸全局 lib.Delay（兼容层已删）===")
    local saved, delayCalls = installEnv(0)
    local s = installWaitFrame()

    WaitFrame(50)
    TestHelper.assertEquals(1, #delayCalls, "非协程应调契约 1 次")
    TestHelper.assertEquals(0, #libDelayCalls,
        "不应调全局 lib.Delay（实测 " .. #libDelayCalls .. " 次）")
    restoreEnv(saved)
end

-- ------------------------------------------------------------ ⑥ 调度器 API

function TestWaitFrame.testSchedulerHasWaitFrameAndIsInCoroutine()
    print("\n=== Test: scheduler 有 isInCoroutine / waitFrame ===")
    local CS = require("framework.coroutine_scheduler")
    local s = CS.getInstance()
    TestHelper.assertNotNil(s.isInCoroutine, "应有 isInCoroutine 方法")
    TestHelper.assertNotNil(s.waitFrame, "应有 waitFrame 方法")

    -- 非协程时 isInCoroutine 应为 false
    s:reset()
    TestHelper.assertEquals(false, s:isInCoroutine() and true or false,
        "非协程时 isInCoroutine 应为 false")
end

function TestWaitFrame.testIsInCoroutineTrueInside()
    print("\n=== Test: 协程里 isInCoroutine 为 true ===")
    local saved = installEnv(0)
    local s = installWaitFrame()

    local inside = nil
    local id = s:create(function()
        inside = s:isInCoroutine()
    end, "ic")
    s:start(id)
    TestHelper.assertEquals(true, inside and true or false,
        "协程里 isInCoroutine 应为 true")
    restoreEnv(saved)
end

-- ------------------------------------------------------------ 套件入口

function TestWaitFrame.runAll()
    print("\n" .. string.rep("=", 60))
    print("WaitFrame 协程感知等待回归（REQ-BD-2 / REQ-BD-3）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestWaitFrame.testCoroutineDoesNotBlock()
    TestWaitFrame.testOutsideCoroutineFallsBack()
    TestWaitFrame.testZeroAndNegativeNoop()
    TestWaitFrame.testNeverTouchesGlobalLib()
    TestWaitFrame.testScriptHasNoRawLibDelay()
    TestWaitFrame.testWaitFrameIsGlobal()
    TestWaitFrame.testSchedulerHasWaitFrameAndIsInCoroutine()
    TestWaitFrame.testIsInCoroutineTrueInside()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_wait_frame.lua$") then
    TestWaitFrame.runAll()
end

return TestWaitFrame
