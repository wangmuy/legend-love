-- test_input_bindings.lua
-- 绑定表 + 向量机制 + 迟滞（change: input-action-layer）
--
-- 守的坑：
--   ① framework 不得内置 move/aim（ADR-4）——游戏要自己 defineVector
--   ② 迟滞：摇杆在阈值附近抖动不得反复产生事件（ADR-6）
--   ③ 任意可打印字符都要能落到 ui.text（修复输入框打不出字）
--   ④ 模拟量派生重复独立于 keyRepeatEnabled

local TestHelper = require("tests.test_helper")
local TestInputBindings = {}

-- 注意：不在这里调 TestHelper.setup()（它含 resetCounts，会清零计数）
local function fresh()
    package.loaded["framework.input_bindings"] = nil
    package.loaded["framework.input_actions"] = nil
    package.loaded["script.input_actions"] = nil
    local IB = require("framework.input_bindings")
    local IA = require("framework.input_actions")
    return IB, IA
end

-- ------------------------------------------------------------ 默认绑定表

function TestInputBindings.testSpaceBindsToAccept()
    local IB, IA = fresh()
    TestHelper.assertEquals("ui.accept", IB.resolve("key", "space"),
        "空格应绑到 ui.accept")
    TestHelper.assertEquals("ui.accept", IB.resolve("key", "return"),
        "回车应绑到 ui.accept")
end

function TestInputBindings.testEscapeBindsToCancel()
    local IB = fresh()
    TestHelper.assertEquals("ui.cancel", IB.resolve("key", "escape"),
        "ESC 应绑到 ui.cancel")
end

function TestInputBindings.testArrowKeysBindToNavigation()
    local IB = fresh()
    TestHelper.assertEquals("ui.up", IB.resolve("key", "up"), "up → ui.up")
    TestHelper.assertEquals("ui.down", IB.resolve("key", "down"), "down → ui.down")
    TestHelper.assertEquals("ui.left", IB.resolve("key", "left"), "left → ui.left")
    TestHelper.assertEquals("ui.right", IB.resolve("key", "right"), "right → ui.right")
end

function TestInputBindings.testMouseButtonsBind()
    local IB = fresh()
    TestHelper.assertEquals("ui.accept", IB.resolve("mouse", 1), "左键 → ui.accept")
    TestHelper.assertEquals("ui.cancel", IB.resolve("mouse", 2), "右键 → ui.cancel")
end

function TestInputBindings.testPadButtonsBind()
    local IB = fresh()
    TestHelper.assertEquals("ui.accept", IB.resolve("pad", "a"), "手柄 A → ui.accept")
    TestHelper.assertEquals("ui.cancel", IB.resolve("pad", "b"), "手柄 B → ui.cancel")
    TestHelper.assertEquals("ui.menu", IB.resolve("pad", "start"), "手柄 start → ui.menu")
end

function TestInputBindings.testUnboundKeyReturnsNil()
    local IB = fresh()
    TestHelper.assertEquals(nil, IB.resolve("key", "f12"), "未绑定的键应返回 nil")
end

-- ------------------------------------------------------------ 文本输入（REQ-IAL-3b）

function TestInputBindings.testPrintableCharBecomesText()
    local IB, IA = fresh()
    local action, char = IB.resolveKey("a")
    TestHelper.assertEquals("ui.text", action, "字母 a 应降级为 ui.text")
    TestHelper.assertEquals("a", char, "ui.text 应携带字符 a")
end

function TestInputBindings.testAllLettersProduceText()
    local IB = fresh()
    for c = string.byte("a"), string.byte("z") do
        local ch = string.char(c)
        local action, got = IB.resolveKey(ch)
        TestHelper.assertEquals("ui.text", action, ch .. " 应产生 ui.text")
        TestHelper.assertEquals(ch, got, "携带的字符应为 " .. ch)
    end
end

function TestInputBindings.testNonPrintableKeyNoText()
    local IB = fresh()
    -- f12 是功能键（名字长度 > 1，不是单字符）→ 不产 ui.text
    local action = IB.resolveKey("f12")
    TestHelper.assertEquals(nil, action, "功能键不应产生 ui.text")
end

function TestInputBindings.testBackspaceHasExplicitBinding()
    local IB = fresh()
    local action = IB.resolveKey("backspace")
    TestHelper.assertEquals("ui.backspace", action,
        "退格必须有显式绑定（历史缺陷：VK_BACKSPACE 未定义导致静默失效）")
end

-- ------------------------------------------------------------ 向量机制（ADR-4）

function TestInputBindings.testCursorVectorIsBuiltIn()
    local IB = fresh()
    local v = IB.getVector("ui.cursor")
    TestHelper.assertNotNil(v, "内置向量 ui.cursor 应可用")
    TestHelper.assertTrue(type(v.x) == "number", "应返回 x")
    TestHelper.assertTrue(type(v.y) == "number", "应返回 y")
    TestHelper.assertTrue(type(v.magnitude) == "number", "应返回 magnitude")
    TestHelper.assertTrue(type(v.angle) == "number", "应返回 angle")
end

function TestInputBindings.testGameCanDefineOwnVector()
    local IB = fresh()
    TestHelper.assertTrue(IB.defineVector("move", { x = { "leftx" }, y = { "lefty" } }),
        "游戏应能自己声明 move 向量")
    TestHelper.assertNotNil(IB.getVector("move"), "声明后应可读取")
end

function TestInputBindings.testUndeclaredVectorReturnsNil()
    local IB = fresh()
    TestHelper.assertEquals(nil, IB.getVector("aim"),
        "未声明的向量应返回 nil（框架不内置 aim）")
end

function TestInputBindings.testSingleAxisVector()
    local IB = fresh()
    TestHelper.assertTrue(IB.defineVector("steer", { x = { "leftx" } }),
        "单轴向量（y 省略）应可声明")
    local v = IB.getVector("steer")
    TestHelper.assertEquals(0, v.y, "单轴向量的 y 应恒为 0")
end

function TestInputBindings.testFrameworkDoesNotShipMoveOrAim()
    local IB = fresh()
    local ids = IB.listVectors()
    for _, id in ipairs(ids) do
        TestHelper.assertTrue(id ~= "move",
            "框架不得内置 move（那是 Hades 玩法惯例，ADR-4）")
        TestHelper.assertTrue(id ~= "aim",
            "框架不得内置 aim（那是 Hades 玩法惯例，ADR-4）")
    end
end

function TestInputBindings.testVectorReadsEngineAxis()
    -- 注入假 EngineAPI，验证向量真的从 getAxis 取数
    local IB = fresh()
    local saved = _G.EngineAPI
    _G.EngineAPI = {
        time = { getTimeSeconds = function() return 0 end },
        input = {
            getAxis = function(name)
                if name == "leftx" then return 0.8 end
                if name == "lefty" then return 0.6 end
                return 0
            end,
        },
    }
    local v = IB.getVector("ui.cursor")
    _G.EngineAPI = saved
    TestHelper.assertTrue(math.abs(v.x - 0.8) < 0.001, "x 应读到 leftx=0.8，实测 " .. v.x)
    TestHelper.assertTrue(math.abs(v.y - 0.6) < 0.001, "y 应读到 lefty=0.6，实测 " .. v.y)
    TestHelper.assertTrue(math.abs(v.magnitude - 1.0) < 0.001,
        "magnitude 应为 sqrt(0.8²+0.6²)=1.0，实测 " .. v.magnitude)
end

-- ------------------------------------------------------------ 迟滞（ADR-6）

function TestInputBindings.testHysteresisBlocksJitter()
    local IB = fresh()
    -- 摇杆在 0.30 附近抖：未按下态下 0.30 < 0.35 按下阈值 → 不产生事件
    local pressed, fire = IB.axisToDiscrete(0.30, false)
    TestHelper.assertEquals(false, pressed, "0.30 未过按下阈值 0.35")
    TestHelper.assertEquals(false, fire, "不应产生边沿")
end

function TestInputBindings.testHysteresisFiresAboveThreshold()
    local IB = fresh()
    local pressed, fire = IB.axisToDiscrete(0.40, false)
    TestHelper.assertEquals(true, pressed, "0.40 应过按下阈值")
    TestHelper.assertEquals(true, fire, "应产生一次边沿")
end

function TestInputBindings.testHysteresisHoldsBetweenThresholds()
    local IB = fresh()
    -- 已在按下态，回落到 0.30（> 释放阈值 0.25）→ 仍按下，不产生新事件
    local pressed, fire = IB.axisToDiscrete(0.30, true)
    TestHelper.assertEquals(true, pressed, "0.30 > 释放阈值 0.25，应保持按下")
    TestHelper.assertEquals(false, fire, "不应重复产生边沿")
end

function TestInputBindings.testHysteresisReleasesBelowReleaseThreshold()
    local IB = fresh()
    local pressed, fire = IB.axisToDiscrete(0.20, true)
    TestHelper.assertEquals(false, pressed, "0.20 < 释放阈值 0.25，应释放")
    TestHelper.assertEquals(false, fire, "释放不产生边沿")
end

function TestInputBindings.testHysteresisJitterTenFramesNoEvents()
    -- 核心断言：在 0.28..0.32 之间抖 10 帧，应产生 0 个事件
    local IB = fresh()
    local wasPressed = false
    local fired = 0
    for i = 1, 10 do
        local v = 0.28 + (i % 2) * 0.04   -- 0.28 / 0.32 交替
        local p, f = IB.axisToDiscrete(v, wasPressed)
        wasPressed = p
        if f then fired = fired + 1 end
    end
    TestHelper.assertEquals(0, fired, "死区内抖动不得产生任何事件，实测 " .. fired)
end

-- ---------------------------------------------------- 模拟量派生的独立重复

function TestInputBindings.testRepeatNotImmediate()
    local IB = fresh()
    local n = IB.tickRepeat("leftx", true, 1.0)
    TestHelper.assertEquals(0, n, "首次进入按下态不应立刻重复")
end

function TestInputBindings.testRepeatAfterDelay()
    local IB = fresh()
    IB.tickRepeat("leftx", true, 1.0)          -- 建立计时器
    IB.tickRepeat("leftx", true, 1.2)          -- 0.2s，未到 0.3s 延迟
    local n = IB.tickRepeat("leftx", true, 1.35)  -- 0.35s，过了延迟
    TestHelper.assertEquals(1, n, "过了 0.3s 延迟后应产生 1 次重复")
end

function TestInputBindings.testRepeatResetsWhenReleased()
    local IB = fresh()
    IB.tickRepeat("leftx", true, 1.0)
    IB.tickRepeat("leftx", false, 1.5)         -- 松开
    local n = IB.tickRepeat("leftx", true, 2.0)  -- 重新按下
    TestHelper.assertEquals(0, n, "重新按下应重新计时，不立刻重复")
end

function TestInputBindings.testRepeatIndependentOfKeyRepeat()
    -- ADR-6：模拟量重复独立于 keyRepeatEnabled（键盘手感不变）
    local IB = fresh()
    local IM = require("framework.input_manager")
    local im = IM.getInstance()
    im:init()
    TestHelper.assertEquals(false, im:isKeyRepeatEnabled(),
        "键盘重复默认关闭（摇杆重复不应打开它）")
end

-- ------------------------------------------------------------ 绑定 API

function TestInputBindings.testBindAndUnbind()
    local IB = fresh()
    TestHelper.assertTrue(IB.bindAction("key", "q", "ui.cancel"), "应能自定义绑定")
    TestHelper.assertEquals("ui.cancel", IB.resolve("key", "q"), "自定义绑定应生效")
    TestHelper.assertTrue(IB.unbind("key", "q"), "应能解绑")
    TestHelper.assertEquals(nil, IB.resolve("key", "q"), "解绑后应返回 nil")
end

function TestInputBindings.testResetRestoresDefaults()
    local IB = fresh()
    IB.bindAction("key", "space", "ui.up")     -- 改坏默认绑定
    IB.resetBindings()
    TestHelper.assertEquals("ui.accept", IB.resolve("key", "space"),
        "resetBindings 应恢复默认")
end

function TestInputBindings.testGameLayerRegistersJyActions()
    local IB = fresh()
    package.loaded["script.input_actions"] = nil
    local Game = require("script.input_actions")
    Game.register()
    TestHelper.assertEquals("jy.y", IB.resolve("key", "y"), "y 键应绑到 jy.y")
    TestHelper.assertEquals("jy.n", IB.resolve("key", "n"), "n 键应绑到 jy.n")
end

function TestInputBindings.testFrameworkBindingsHaveNoGameVocabulary()
    local IB = fresh()
    local b = IB.getDefaultBindings()
    for source, mapping in pairs(b) do
        for _, action in pairs(mapping) do
            TestHelper.assertTrue(not action:match("^jy%."),
                "默认绑定表不得含游戏动作: " .. tostring(action))
        end
    end
end

-- 套件入口
function TestInputBindings.runAll()
    print("\n" .. string.rep("=", 60))
    print("输入绑定与向量测试（input-action-layer）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestInputBindings.testSpaceBindsToAccept()
    TestInputBindings.testEscapeBindsToCancel()
    TestInputBindings.testArrowKeysBindToNavigation()
    TestInputBindings.testMouseButtonsBind()
    TestInputBindings.testPadButtonsBind()
    TestInputBindings.testUnboundKeyReturnsNil()

    TestInputBindings.testPrintableCharBecomesText()
    TestInputBindings.testAllLettersProduceText()
    TestInputBindings.testNonPrintableKeyNoText()
    TestInputBindings.testBackspaceHasExplicitBinding()

    TestInputBindings.testCursorVectorIsBuiltIn()
    TestInputBindings.testGameCanDefineOwnVector()
    TestInputBindings.testUndeclaredVectorReturnsNil()
    TestInputBindings.testSingleAxisVector()
    TestInputBindings.testFrameworkDoesNotShipMoveOrAim()
    TestInputBindings.testVectorReadsEngineAxis()

    TestInputBindings.testHysteresisBlocksJitter()
    TestInputBindings.testHysteresisFiresAboveThreshold()
    TestInputBindings.testHysteresisHoldsBetweenThresholds()
    TestInputBindings.testHysteresisReleasesBelowReleaseThreshold()
    TestInputBindings.testHysteresisJitterTenFramesNoEvents()

    TestInputBindings.testRepeatNotImmediate()
    TestInputBindings.testRepeatAfterDelay()
    TestInputBindings.testRepeatResetsWhenReleased()
    TestInputBindings.testRepeatIndependentOfKeyRepeat()

    TestInputBindings.testBindAndUnbind()
    TestInputBindings.testResetRestoresDefaults()
    TestInputBindings.testGameLayerRegistersJyActions()
    TestInputBindings.testFrameworkBindingsHaveNoGameVocabulary()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_input_bindings.lua$") then
    TestInputBindings.runAll()
end

return TestInputBindings
