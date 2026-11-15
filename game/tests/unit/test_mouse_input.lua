-- test_mouse_input.lua
-- 鼠标事件队列与鼠标接口的单元测试（REQ-MS1-5）
--
-- 核心断言：鼠标事件与键盘事件**完全隔离** ——
-- 这保护了全仓 20+ 处 lib.GetKey() 调用点不被污染。

local TestHelper = require("tests.test_helper")
local TestMouseInput = {}

-- 保证 EngineAPI 存在（input_manager 的 getTimeSeconds 依赖它）
local function ensureEngineAPI()
    if rawget(_G, "EngineAPI") == nil then
        rawset(_G, "EngineAPI", {
            time = { getTimeSeconds = function() return os.clock() end },
        })
    end
end

local function freshInputManager()
    ensureEngineAPI()
    local IM = require("framework.input_manager")
    local inst = IM.getInstance()
    inst:init()
    IM.clearMouseQueue()
    return IM, inst
end

-- ============================================================
-- REQ-MS1-5 队列隔离
-- ============================================================

function TestMouseInput.testMouseEventDoesNotPolluteGetKey()
    print("\n=== Test: 鼠标事件不污染 getKey ===")
    local IM, inst = freshInputManager()

    IM.enqueueMouseEvent({ type = "pressed", x = 100, y = 200, button = 1 })
    TestHelper.assertEquals(-1, inst:getKey(),
        "只有鼠标事件时 getKey 必须返回 -1（不得把 x 坐标当键码）")

    -- 鼠标事件仍在队列里（getKey 没有消费它）
    local ev = inst:getMouseEvent()
    TestHelper.assertNotNil(ev, "鼠标事件仍在队列中")
    TestHelper.assertEquals(100, ev.x, "内容未被破坏")
end

function TestMouseInput.testKeyEventDoesNotPolluteGetMouseEvent()
    print("\n=== Test: 键盘事件不污染 getMouseEvent ===")
    local IM, inst = freshInputManager()

    inst:onKeyPressed("escape", nil, false)
    local ev = inst:getMouseEvent()
    TestHelper.assertEquals(nil, ev, "只有键盘事件时 getMouseEvent 返回 nil")

    -- 键盘事件仍在（getMouseEvent 没消费它）
    local key = inst:getKey()
    TestHelper.assertEquals(27, key, "键盘事件可正常取出")
end

function TestMouseInput.testMixedEventsIndependent()
    print("\n=== Test: 鼠标与键盘混合时各自独立 ===")
    local IM, inst = freshInputManager()

    inst:onKeyPressed("return", nil, false)
    IM.enqueueMouseEvent({ type = "pressed", x = 5, y = 6, button = 2 })

    TestHelper.assertEquals(13, inst:getKey(), "键盘取出的是 return")
    local ev = inst:getMouseEvent()
    TestHelper.assertNotNil(ev, "鼠标事件也还在")
    TestHelper.assertEquals(2, ev.button, "鼠标按键正确")
end

-- ============================================================
-- 队列行为
-- ============================================================

function TestMouseInput.testOrderPreserved()
    print("\n=== Test: 鼠标事件按顺序消费 ===")
    local IM, inst = freshInputManager()

    IM.enqueueMouseEvent({ type = "pressed", x = 1, y = 1, button = 1 })
    IM.enqueueMouseEvent({ type = "pressed", x = 2, y = 2, button = 1 })
    IM.enqueueMouseEvent({ type = "pressed", x = 3, y = 3, button = 1 })

    TestHelper.assertEquals(1, inst:getMouseEvent().x, "第 1 个 x=1")
    TestHelper.assertEquals(2, inst:getMouseEvent().x, "第 2 个 x=2")
    TestHelper.assertEquals(3, inst:getMouseEvent().x, "第 3 个 x=3")
    TestHelper.assertEquals(nil, inst:getMouseEvent(), "取完后为 nil")
end

function TestMouseInput.testPeekDoesNotConsume()
    print("\n=== Test: peek 不消费 ===")
    local IM = freshInputManager()
    IM.enqueueMouseEvent({ type = "pressed", x = 9, y = 9, button = 1 })

    local p1 = IM.peekMouseEvent()
    local p2 = IM.peekMouseEvent()
    TestHelper.assertEquals(9, p1.x, "peek 第 1 次")
    TestHelper.assertEquals(9, p2.x, "peek 第 2 次仍是同一事件")

    local ev = IM.getMouseEvent()
    TestHelper.assertEquals(9, ev.x, "peek 后仍能取出")
    TestHelper.assertEquals(nil, IM.peekMouseEvent(), "取完后 peek 为 nil")
end

function TestMouseInput.testOverflowDoesNotCrash()
    print("\n=== Test: 队列溢出不崩 ===")
    local IM, inst = freshInputManager()

    local ok = pcall(function()
        for i = 1, 300 do
            IM.enqueueMouseEvent({ type = "pressed", x = i, y = 0, button = 1 })
        end
    end)
    TestHelper.assertTrue(ok, "超过容量上限不抛错（丢最旧的）")
    TestHelper.assertNotNil(inst:getMouseEvent(), "仍能取出事件")
end

function TestMouseInput.testClearQueue()
    print("\n=== Test: 清空队列 ===")
    local IM, inst = freshInputManager()
    IM.enqueueMouseEvent({ type = "pressed", x = 1, y = 1, button = 1 })
    IM.clearMouseQueue()
    TestHelper.assertEquals(nil, inst:getMouseEvent(), "清空后取不到")
end

function TestMouseInput.testTimeAutoFilled()
    print("\n=== Test: time 字段自动填充 ===")
    local IM = freshInputManager()
    IM.enqueueMouseEvent({ type = "pressed", x = 1, y = 1, button = 1 })
    local ev = IM.peekMouseEvent()
    TestHelper.assertNotNil(ev.time, "未提供 time 时自动填充")
end

function TestMouseInput.testInvalidEventRejected()
    print("\n=== Test: 非法事件被拒绝 ===")
    local IM = freshInputManager()
    TestHelper.assertFalse(IM.enqueueMouseEvent(nil), "nil 被拒绝")
    TestHelper.assertFalse(IM.enqueueMouseEvent("string"), "字符串被拒绝")
    TestHelper.assertEquals(nil, IM.getMouseEvent(), "队列仍为空")
end

function TestMouseInput.testInitClearsMouseQueue()
    print("\n=== Test: init 清空鼠标队列 ===")
    local IM, inst = freshInputManager()
    IM.enqueueMouseEvent({ type = "pressed", x = 1, y = 1, button = 1 })
    inst:init()
    TestHelper.assertEquals(nil, inst:getMouseEvent(), "init 后队列为空")
end

-- ============================================================
-- REQ-MS1-2 接口存在性（在测试引擎上）
-- ============================================================

function TestMouseInput.testInputManagerHasMouseAPI()
    print("\n=== Test: InputManager 暴露鼠标 API ===")
    local IM = require("framework.input_manager")
    TestHelper.assertNotNil(IM.enqueueMouseEvent, "有 enqueueMouseEvent")
    TestHelper.assertNotNil(IM.getMouseEvent or IM._dequeueMouseEvent,
        "有取事件的方法")
    TestHelper.assertNotNil(IM.peekMouseEvent, "有 peekMouseEvent")
    TestHelper.assertNotNil(IM.clearMouseQueue, "有 clearMouseQueue")
end

function TestMouseInput.testNoTailRecursionBug()
    print("\n=== Test: 取事件不是尾递归自调用（曾经的死循环）===")
    -- 历史 bug：同时定义 InputManager.getMouseEvent 与 InputManager:getMouseEvent
    -- 会让冒号方法变成对自己的尾调用 → 不增长栈 → 永久卡住（不报错）。
    -- 这里用超时保护的方式验证「调用能正常返回」。
    local IM, inst = freshInputManager()
    IM.enqueueMouseEvent({ type = "pressed", x = 7, y = 8, button = 1 })
    local done = false
    local ok = pcall(function()
        local ev = inst:getMouseEvent()
        done = ev ~= nil and ev.x == 7
    end)
    TestHelper.assertTrue(ok, "调用不抛错")
    TestHelper.assertTrue(done, "调用能正常返回结果（未陷入死循环）")
end

-- ============================================================
-- REQ-MS2-6 键事件注入（对话期间鼠标等价空格/Enter）
-- ============================================================

function TestMouseInput.testEnqueueKeyEventExists()
    print("\n=== Test: enqueueKeyEvent 存在 ===")
    local IM = require("framework.input_manager")
    TestHelper.assertNotNil(IM.enqueueKeyEvent, "有 enqueueKeyEvent")
end

function TestMouseInput.testInjectedKeyVisibleToInternalPeek()
    print("\n=== Test: 注入的键能被对话等待看到 ===")
    local IM, inst = freshInputManager()

    IM.enqueueKeyEvent(32)   -- 空格
    -- 对话等待走的是 _peekKeyInternal（绕过 disableInput）
    local k = inst:_peekKeyInternal()
    TestHelper.assertEquals(32, k,
        "注入的键进的是键队列，_peekKeyInternal 能看到（对话推进依赖这条）")
    inst:clearCurrentKey()
end

function TestMouseInput.testInjectedKeySeenEvenWhenInputDisabled()
    print("\n=== Test: disableInput 期间仍可注入并推进对话 ===")
    local IM, inst = freshInputManager()

    IM.disableInput = true
    IM.enqueueKeyEvent(32)
    local k = inst:_peekKeyInternal()
    TestHelper.assertEquals(32, k,
        "disableInput 不影响 _peekKeyInternal（对话本身就在 disableInput 下等键）")
    IM.disableInput = false
    inst:clearCurrentKey()
end

function TestMouseInput.testInjectedKeyNotConsumedByGetKey()
    print("\n=== Test: injected key NOT consumed by getKey ===")
    -- 修复前这里断言的是「应能取到」
    -- —— 而那个行为正是 bug 成因。
    local IM, inst = freshInputManager()

    IM.enqueueKeyEvent(32)
    local k = inst:getKey()
    TestHelper.assertEquals(-1, k,
        "getKey 不该取到注入键（它只服务于协程等键）")
end

function TestMouseInput.testInjectRejectsNonNumber()
    print("\n=== Test: 注入非数字被拒 ===")
    local IM = require("framework.input_manager")
    TestHelper.assertFalse(IM.enqueueKeyEvent(nil), "nil 被拒")
    TestHelper.assertFalse(IM.enqueueKeyEvent("space"), "字符串被拒")
end

-- ============================================================
-- 注入键不得被主循环读到（用户实测 bug）
--
-- 河洛客栈站在店小二旁，鼠标悬停物品格 → 冒出店小二对话。
-- 根因：悬停注入 VK_SPACE 唤醒物品协程，同一帧 GAME_SMAP.update 的
-- getKey() 也读到这个 SPACE，走进「触发面向 tile 的事件」分支。
-- ============================================================

function TestMouseInput.testSyntheticKeyInvisibleToGetKey()
    print("\n=== Test: 注入键对 getKey 不可见（关键）===")
    local IM, inst = freshInputManager()

    IM.enqueueKeyEvent(32)     -- 模拟鼠标注入的 SPACE
    TestHelper.assertEquals(-1, inst:getKey(),
        "getKey 必须看不到注入键（否则会被当成玩家按了空格 → 触发对话/事件）")

    -- 但协程等键（_peekKeyInternal）必须能看到
    inst:init()
    IM.enqueueKeyEvent(32)
    TestHelper.assertEquals(32, inst:_peekKeyInternal(),
        "协程等键能看到注入键（这是注入的唯一目的）")
    inst:clearCurrentKey()
end

function TestMouseInput.testRealKeyStillVisibleToGetKey()
    print("\n=== Test: 真实按键仍能被 getKey 读到 ===")
    local IM, inst = freshInputManager()

    inst:onKeyPressed("space", nil, false)
    TestHelper.assertEquals(32, inst:getKey(), "真实按键不受影响")
end

function TestMouseInput.testMixedSyntheticAndReal()
    print("\n=== Test: 注入键与真实键混合 ===")
    local IM, inst = freshInputManager()

    IM.enqueueKeyEvent(32)              -- synthetic SPACE
    inst:onKeyPressed("return", nil, false)   -- 真实 RETURN

    TestHelper.assertEquals(13, inst:getKey(),
        "getKey 跳过 synthetic，拿到真实的 RETURN")
end

function TestMouseInput.runAll()
    print("\n" .. string.rep("=", 60))
    print("鼠标事件队列测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestMouseInput.testInputManagerHasMouseAPI()

    TestMouseInput.testMouseEventDoesNotPolluteGetKey()
    TestMouseInput.testKeyEventDoesNotPolluteGetMouseEvent()
    TestMouseInput.testMixedEventsIndependent()

    TestMouseInput.testOrderPreserved()
    TestMouseInput.testPeekDoesNotConsume()
    TestMouseInput.testOverflowDoesNotCrash()
    TestMouseInput.testClearQueue()
    TestMouseInput.testTimeAutoFilled()
    TestMouseInput.testInvalidEventRejected()
    TestMouseInput.testInitClearsMouseQueue()
    TestMouseInput.testNoTailRecursionBug()

    TestMouseInput.testEnqueueKeyEventExists()
    TestMouseInput.testInjectedKeyVisibleToInternalPeek()
    TestMouseInput.testInjectedKeySeenEvenWhenInputDisabled()
    TestMouseInput.testInjectedKeyNotConsumedByGetKey()
    TestMouseInput.testInjectRejectsNonNumber()

    TestMouseInput.testSyntheticKeyInvisibleToGetKey()
    TestMouseInput.testRealKeyStillVisibleToGetKey()
    TestMouseInput.testMixedSyntheticAndReal()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_mouse_input.lua$") then
    TestMouseInput.runAll()
end

return TestMouseInput
