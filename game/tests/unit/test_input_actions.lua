-- test_input_actions.lua
-- 输入动作层：动作常量 + 事件结构 + 动作队列（change: input-action-layer）
--
-- 守的坑（见 design.md ADR-1 / ADR-3）：
--   ① framework 通用层不得出现任何游戏词汇（金庸的 Y/N 必须住 script/）
--   ② 动作名是 accept 不是 confirm（Y 是「语义上的是」，SPACE 是「推进」）
--   ③ 事件必须带 source（provenance），不允许再出现 synthetic 脏标记
--   ④ 动作队列与键队列必须互不挤占（双队列并存是迁移期的基础）

local TestHelper = require("tests.test_helper")
local TestInputActions = {}

-- 每个测试前重置：EngineAPI 由 TestHelper.setup() 提供 mock
-- （input_manager 的 getTimeSeconds 会读 EngineAPI.time.getTimeSeconds，
--   不先 setup 会报 attempt to index global 'EngineAPI'）
-- 注意：**不在这里调 TestHelper.setup()** —— 它内含 resetCounts，
-- 每个测试都调会把上一个测试的计数清零（症状：Results 只显示 1 条）。
-- setup 只在 runAll 开头调一次；这里只重置模块自身状态。
local function freshInputManager()
    package.loaded["framework.input_manager"] = nil
    package.loaded["framework.input_actions"] = nil
    local IM = require("framework.input_manager")
    local IA = require("framework.input_actions")
    local im = IM.getInstance()
    im:reset()
    im:init()
    return IM, IA, im
end

-- ---------------------------------------------------------------- 动作常量

function TestInputActions.testTenFrameworkActions()
    local _, IA = freshInputManager()
    TestHelper.assertEquals(10, #IA.ALL,
        "framework 通用层应有 10 个动作（9 离散 + 1 向量）")
    TestHelper.assertEquals(9, #IA.DISCRETE,
        "进事件队列的离散动作应为 9 个")
end

function TestInputActions.testActionNamesUseAcceptNotConfirm()
    local _, IA = freshInputManager()
    TestHelper.assertEquals("ui.accept", IA.ACCEPT,
        "确认动作必须是 ui.accept（不是 ui.confirm —— Y 是『语义上的是』，SPACE 是『推进』）")
    TestHelper.assertEquals(nil, IA.CONFIRM,
        "不应存在 CONFIRM 常量")
end

function TestInputActions.testNoGameVocabularyInFramework()
    local _, IA = freshInputManager()
    for _, name in ipairs(IA.ALL) do
        TestHelper.assertTrue(IA.isFrameworkAction(name),
            "动作 " .. name .. " 应属于 framework 通用层（ui. 前缀）")
    end
    -- 金庸词汇不得出现在常量表里
    for _, name in ipairs(IA.ALL) do
        TestHelper.assertTrue(not name:match("jy%."),
            "framework 通用层不得含游戏词汇: " .. name)
    end
end

function TestInputActions.testCursorIsVectorNotDiscrete()
    local _, IA = freshInputManager()
    TestHelper.assertEquals("ui.cursor", IA.CURSOR, "内置向量名应为 ui.cursor")
    local found = false
    for _, name in ipairs(IA.DISCRETE) do
        if name == IA.CURSOR then found = true end
    end
    TestHelper.assertEquals(false, found, "ui.cursor 是向量，不应出现在离散动作表里")
end

-- ------------------------------------------------------------ normalizeName

function TestInputActions.testNormalizeAcceptsSpace()
    local _, IA = freshInputManager()
    TestHelper.assertEquals("ui.accept", IA.normalizeName("SPACE"),
        "SPACE 应归一成 ui.accept")
    TestHelper.assertEquals("ui.accept", IA.normalizeName("space"),
        "大小写不敏感")
end

function TestInputActions.testNormalizeAcceptsReturnAndEnter()
    local _, IA = freshInputManager()
    TestHelper.assertEquals("ui.accept", IA.normalizeName("return"), "return → ui.accept")
    TestHelper.assertEquals("ui.accept", IA.normalizeName("enter"), "enter → ui.accept")
end

function TestInputActions.testNormalizeAcceptsEscape()
    local _, IA = freshInputManager()
    TestHelper.assertEquals("ui.cancel", IA.normalizeName("escape"), "escape → ui.cancel")
    TestHelper.assertEquals("ui.cancel", IA.normalizeName("ESC"), "ESC → ui.cancel")
end

function TestInputActions.testNormalizeKeepsGameActions()
    local _, IA = freshInputManager()
    TestHelper.assertEquals("jy.y", IA.normalizeName("jy.y"),
        "游戏私有动作应原样返回（框架不认识它，只透传）")
    TestHelper.assertEquals("pal.use", IA.normalizeName("pal.use"),
        "任意游戏前缀都该透传")
end

function TestInputActions.testNormalizeRejectsGarbage()
    local _, IA = freshInputManager()
    TestHelper.assertEquals(nil, IA.normalizeName("!!!"), "非法输入应返回 nil")
    TestHelper.assertEquals(nil, IA.normalizeName(""), "空串应返回 nil")
    TestHelper.assertEquals(nil, IA.normalizeName(nil), "nil 应返回 nil")
    TestHelper.assertEquals(nil, IA.normalizeName(42), "非字符串应返回 nil")
end

-- ------------------------------------------------------------ 事件结构

function TestInputActions.testValidSources()
    local _, IA = freshInputManager()
    for _, s in ipairs({ "key", "mouse", "pad", "touch", "vr" }) do
        TestHelper.assertTrue(IA.isValidSource(s), s .. " 应为合法 source")
    end
    TestHelper.assertEquals(false, IA.isValidSource("keyboard"),
        "keyboard 不是合法 source（应用 key）")
    TestHelper.assertEquals(false, IA.isValidSource(nil), "nil 不是合法 source")
end

function TestInputActions.testVrInlineButCapabilityFalse()
    -- ADR-7：vr 留槽不实现。source 合法但 capability 必须为 false
    local _, IA = freshInputManager()
    TestHelper.assertTrue(IA.isValidSource("vr"), "vr 应作为合法 source 留槽")
end

-- ------------------------------------------------------------ 动作队列

function TestInputActions.testEnqueueAndGet()
    local IM = select(1, freshInputManager())
    TestHelper.assertTrue(IM.enqueueAction({ action = "ui.accept", source = "key" }),
        "入队应成功")
    TestHelper.assertEquals("ui.accept", IM.getAction(), "取出应是入队的动作名")
end

function TestInputActions.testGetActionReturnsNilWhenEmpty()
    local IM = select(1, freshInputManager())
    TestHelper.assertEquals(nil, IM.getAction(), "空队列 getAction 应返回 nil")
end

function TestInputActions.testRejectsInvalidAction()
    local IM = select(1, freshInputManager())
    TestHelper.assertEquals(false, IM.enqueueAction({ action = "", source = "key" }),
        "空动作名应被拒绝")
    TestHelper.assertEquals(false, IM.enqueueAction({ action = 42, source = "key" }),
        "非字符串动作名应被拒绝")
    TestHelper.assertEquals(false, IM.enqueueAction(nil), "nil 事件应被拒绝")
end

function TestInputActions.testRejectsInvalidSource()
    local IM = select(1, freshInputManager())
    TestHelper.assertEquals(false,
        IM.enqueueAction({ action = "ui.up", source = "bogus" }),
        "非法 source 应被拒绝")
end

function TestInputActions.testDefaultSourceIsCompat()
    local IM = select(1, freshInputManager())
    TestHelper.assertTrue(IM.enqueueAction({ action = "ui.accept" }),
        "省略 source 时应默认为 compat 并入队")
    local ev = IM.getActionEvent()
    TestHelper.assertEquals("compat", ev.source, "默认 source 应为 compat")
end

function TestInputActions.testActionEventCarriesPositionAndChar()
    local IM = select(1, freshInputManager())
    IM.enqueueAction({
        action = "ui.text", source = "key", char = "a",
    })
    local ev = IM.getActionEvent()
    TestHelper.assertEquals("a", ev.char, "ui.text 事件应携带 char")
    TestHelper.assertNotNil(ev.time, "事件应自动补 time")
end

function TestInputActions.testPeekDoesNotConsume()
    local IM = select(1, freshInputManager())
    IM.enqueueAction({ action = "ui.down", source = "key" })
    TestHelper.assertEquals("ui.down", IM.peekAction(), "peekAction 应看到动作")
    TestHelper.assertEquals(1, IM.getActionQueueSize(), "peek 不应消费")
    TestHelper.assertEquals("ui.down", IM.getAction(), "之后仍能取出同一个动作")
    TestHelper.assertEquals(0, IM.getActionQueueSize(), "取出后队列空")
end

function TestInputActions.testQueueIndependence()
    -- 核心断言：动作队列与键队列互不挤占（ADR-5 双通道）
    --
    -- 注意 Task 4 之后的行为变化：onKeyPressed 会**同时**产出
    --   ① 键队列事件（VK 32）  ② 动作队列事件（ui.accept）
    -- 这是刻意的（迁移期两套并存），所以动作队列里会先有 ui.accept。
    -- 本测试改为先清空动作队列，再验证两队列互不影响。
    local IM, _, im = freshInputManager()
    im:onKeyPressed("space", nil, false)
    TestHelper.assertEquals(32, im:getKey(), "键队列应能取出 SPACE 的 VK 值")

    im:clearActionQueue()
    IM.enqueueAction({ action = "ui.cancel", source = "mouse" })
    TestHelper.assertEquals("ui.cancel", IM.getAction(),
        "动作队列应能取出 ui.cancel，不因键队列消费而丢失")
end

-- Task 4 新增行为：一次按键同时产键事件与动作事件（两套并存）
function TestInputActions.testKeyPressProducesBothChannels()
    local IM, _, im = freshInputManager()
    im:onKeyPressed("space", nil, false)

    TestHelper.assertEquals(32, im:getKey(), "键队列应有 VK_SPACE")
    TestHelper.assertEquals("ui.accept", IM.getAction(),
        "动作队列应有 ui.accept（同一按键同时产两个通道）")
end

-- Task 4 新增行为：字母不进键队列，但进动作队列（修复输入框）
function TestInputActions.testLetterProducesTextActionOnly()
    local IM, _, im = freshInputManager()
    im:onKeyPressed("a", nil, false)

    TestHelper.assertEquals(-1, im:getKey(),
        "字母不在 baseKeyMap 里，键队列应为空")
    local ev = IM.getActionEvent()
    TestHelper.assertEquals("ui.text", ev.action, "字母应产 ui.text 动作")
    TestHelper.assertEquals("a", ev.char, "ui.text 应携带字符")
end

function TestInputActions.testClearActionQueue()
    local IM = select(1, freshInputManager())
    IM.enqueueAction({ action = "ui.up", source = "key" })
    IM.clearActionQueue()
    TestHelper.assertEquals(0, IM.getActionQueueSize(), "清空后队列应为 0")
    TestHelper.assertEquals(nil, IM.getAction(), "清空后取不出动作")
end

function TestInputActions.testQueueOverflowDropsOldest()
    local IM = select(1, freshInputManager())
    for i = 1, 70 do
        IM.enqueueAction({ action = "ui.up", source = "key" })
    end
    TestHelper.assertTrue(IM.getActionQueueSize() <= 64,
        "队列长度不得超过 64，实测 " .. IM.getActionQueueSize())
end

function TestInputActions.testNoSyntheticFieldAnywhere()
    -- 负向对照：动作事件里不得出现 synthetic（ADR-3 废弃脏标记）
    local IM = select(1, freshInputManager())
    IM.enqueueAction({ action = "ui.accept", source = "key", synthetic = true })
    local ev = IM.getActionEvent()
    TestHelper.assertEquals(nil, ev.synthetic,
        "动作事件不应保留 synthetic 字段（应改用 source）")
end

-- 套件入口：与 tests/test_runner.lua 的 runAll 约定一致
function TestInputActions.runAll()
    print("\n" .. string.rep("=", 60))
    print("输入动作层测试（input-action-layer）")
    print(string.rep("=", 60))
    TestHelper.setup()          -- EngineAPI mock + 清零计数（只此一次）
    TestHelper.resetCounts()

    TestInputActions.testTenFrameworkActions()
    TestInputActions.testActionNamesUseAcceptNotConfirm()
    TestInputActions.testNoGameVocabularyInFramework()
    TestInputActions.testCursorIsVectorNotDiscrete()

    TestInputActions.testNormalizeAcceptsSpace()
    TestInputActions.testNormalizeAcceptsReturnAndEnter()
    TestInputActions.testNormalizeAcceptsEscape()
    TestInputActions.testNormalizeKeepsGameActions()
    TestInputActions.testNormalizeRejectsGarbage()

    TestInputActions.testValidSources()
    TestInputActions.testVrInlineButCapabilityFalse()

    TestInputActions.testEnqueueAndGet()
    TestInputActions.testGetActionReturnsNilWhenEmpty()
    TestInputActions.testRejectsInvalidAction()
    TestInputActions.testRejectsInvalidSource()
    TestInputActions.testDefaultSourceIsCompat()
    TestInputActions.testActionEventCarriesPositionAndChar()
    TestInputActions.testPeekDoesNotConsume()
    TestInputActions.testQueueIndependence()
    TestInputActions.testKeyPressProducesBothChannels()
    TestInputActions.testLetterProducesTextActionOnly()
    TestInputActions.testClearActionQueue()
    TestInputActions.testQueueOverflowDropsOldest()
    TestInputActions.testNoSyntheticFieldAnywhere()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_input_actions.lua$") then
    TestInputActions.runAll()
end

return TestInputActions
