-- test_input_action_migration.lua
-- input-action-layer Task 5 迁移的基础设施回归测试
--
-- 守的坑（迁移前实测确认的三个硬阻塞）：
--   A. getKey() 跳过 source≠"key"（ADR-3 修的河洛客栈 bug），
--      而 getAction() 不看 source → 直接迁移会让 bug 回归
--   B. 按键重复只进键队列，动作队列没有 repeat → 菜单长按连翻失效
--   C. _peekKeyInternal 无动作版 → 对话/场景名等待迁移后无法"偷看"

local TestHelper = require("tests.test_helper")
local T = {}

local function freshIM()
    -- 必须确保 EngineAPI 可用（input_manager 的 getTimeSeconds 会调它）
    TestHelper.setup()
    package.loaded["framework.input_manager"] = nil
    local IM = require("framework.input_manager")
    IM.clearActionQueue()
    return IM, IM.getInstance()
end

-- ---------------------------------------------------------------- A

function T.testActionKeyOnlyFiltersSource()
    print("\n=== Test: getActionKeyOnly 只收 source=key（镜像 getKey）===")
    local IM, inst = freshIM()

    IM.enqueueAction({ action = "ui.up", source = "key" })
    IM.enqueueAction({ action = "ui.accept", source = "mouse" })
    IM.enqueueAction({ action = "ui.down", source = "key" })

    TestHelper.assertEquals("ui.up", inst.getActionKeyOnly(),
        "第一个键盘动作")
    TestHelper.assertEquals("ui.down", inst.getActionKeyOnly(),
        "跳过 mouse 后取到第二个键盘动作（FIFO 顺序不乱）")
    TestHelper.assertEquals("ui.accept", IM.getAction(),
        "mouse 动作仍留在队列里给别的消费方")
    TestHelper.assertEquals(nil, inst.getActionKeyOnly(), "队列空返回 nil")
end

function T.testActionKeyOnlyRespectsDisableInput()
    print("\n=== Test: disableInput 时 getActionKeyOnly 返回 nil ===")
    local IM, inst = freshIM()
    IM.enqueueAction({ action = "ui.up", source = "key" })
    IM.disableInput = true
    TestHelper.assertEquals(nil, inst.getActionKeyOnly(),
        "disableInput=true 时不得消费（与 getKey 一致）")
    IM.disableInput = false
    TestHelper.assertEquals("ui.up", inst.getActionKeyOnly(),
        "恢复后事件仍在（没被丢弃）")
end

function T.testActionKeyOnlyDoesNotDropPadEvents()
    print("\n=== Test: pad/touch/vr 动作不被键盘读取吞掉 ===")
    local IM, inst = freshIM()
    IM.enqueueAction({ action = "ui.up", source = "pad" })
    IM.enqueueAction({ action = "ui.accept", source = "touch" })
    TestHelper.assertEquals(nil, inst.getActionKeyOnly(), "键盘读取看不到手柄/触摸")
    TestHelper.assertEquals("ui.up", IM.getAction(), "手柄动作仍在")
    TestHelper.assertEquals("ui.accept", IM.getAction(), "触摸动作仍在")
end

-- ---------------------------------------------------------------- B

function T.testKeyRepeatAlsoFeedsActionQueue()
    print("\n=== Test: 按键重复同时进动作队列（菜单长按连翻）===")
    local IM, inst = freshIM()
    package.loaded["framework.input_bindings"] = nil
    local IB = require("framework.input_bindings")
    if IB.reset then IB.reset() end

    -- 反查映射必须能把 SDL keycode 转回动作
    TestHelper.assertEquals("ui.up", IB.actionForKeyCode(1073741906),
        "1073741906（SDLK_UP）→ ui.up")
    TestHelper.assertEquals("ui.cancel", IB.actionForKeyCode(27),
        "27（VK_ESCAPE）→ ui.cancel")
    TestHelper.assertEquals("ui.accept", IB.actionForKeyCode(32), "32 → ui.accept")
    TestHelper.assertEquals(nil, IB.actionForKeyCode(999999),
        "未绑定的码返回 nil（不抛错）")
    TestHelper.assertEquals(nil, IB.actionForKeyCode("x"), "非数字返回 nil")
end

-- ---------------------------------------------------------------- C

function T.testPeekActionInternalMirrorsPeekKey()
    print("\n=== Test: _peekActionInternal 不过滤 source、不消费 ===")
    local IM, inst = freshIM()
    IM.enqueueAction({ action = "ui.accept", source = "mouse" })

    TestHelper.assertEquals("ui.accept", inst:_peekActionInternal(),
        "mouse 动作也能偷看到（对话推进依赖这条）")
    TestHelper.assertEquals("ui.accept", inst:_peekActionInternal(),
        "偷看不消费（两次结果相同）")
    TestHelper.assertEquals("ui.accept", IM.getAction(), "消费后才消失")
    TestHelper.assertEquals(nil, inst:_peekActionInternal(), "空队列返回 nil")
end

function T.testPeekActionInternalBypassesDisableInput()
    print("\n=== Test: _peekActionInternal 绕过 disableInput ===")
    local IM, inst = freshIM()
    IM.enqueueAction({ action = "ui.accept", source = "key" })
    IM.disableInput = true
    TestHelper.assertEquals("ui.accept", inst:_peekActionInternal(),
        "disableInput 不影响偷看（对话本身就在 disableInput 下等）")
    IM.disableInput = false
end

-- ---------------------------------------------------------------- 负向对照

function T.testNegativeControlSourceFilterMatters()
    print("\n=== Test: 负向对照 —— 不做 source 过滤会让鼠标动作被当键盘 ===")
    local IM, inst = freshIM()
    IM.enqueueAction({ action = "ui.accept", source = "mouse" })

    -- 这是"直接用 getAction"的行为（迁移时必须避免）
    local unfiltered = IM.getAction()
    TestHelper.assertEquals("ui.accept", unfiltered,
        "getAction 不看 source → 把鼠标动作交给地图循环（河洛客栈 bug）")

    -- 正确做法
    IM.enqueueAction({ action = "ui.accept", source = "mouse" })
    TestHelper.assertEquals(nil, inst.getActionKeyOnly(),
        "getActionKeyOnly 正确拒绝 mouse 来源")
end

-- ---------------------------------------------------------------- 端到端

function T.testRealKeypressProducesActionWithKeyCode()
    print("\n=== Test: 真实键盘事件 → 动作 + keyCode（端到端）===")
    TestHelper.setup()
    package.loaded["framework.input_manager"] = nil
    local IM = require("framework.input_manager")
    local inst = IM.getInstance()
    local IA = require("framework.input_actions")

    local t = 0
    local savedGetTime = EngineAPI.time.getTimeSeconds
    EngineAPI.time.getTimeSeconds = function() return t end

    local function press(keyName)
        IM.clearActionQueue()
        inst:onKeyPressed(keyName, nil, false)
        return inst.getActionEventKeyOnly()
    end

    local ev = press("up")
    TestHelper.assertEquals(IA.UP, ev and ev.action, "上键 → ui.up")
    TestHelper.assertEquals(1073741906, ev and ev.keyCode,
        "keyCode 必须是 SDL keycode（AutoMove drain 依赖它区分具体键）")

    ev = press("space")
    TestHelper.assertEquals(IA.ACCEPT, ev and ev.action, "空格 → ui.accept")
    TestHelper.assertEquals(32, ev and ev.keyCode, "空格 keyCode=32")

    ev = press("escape")
    TestHelper.assertEquals(IA.CANCEL, ev and ev.action, "ESC → ui.cancel")

    EngineAPI.time.getTimeSeconds = savedGetTime
end

function T.testLongPressProducesRepeatActions()
    print("\n=== Test: 长按产生 repeat 动作（菜单连翻）===")
    TestHelper.setup()
    package.loaded["framework.input_manager"] = nil
    local IM = require("framework.input_manager")
    local inst = IM.getInstance()
    local IA = require("framework.input_actions")

    local t = 0
    local savedGetTime = EngineAPI.time.getTimeSeconds
    EngineAPI.time.getTimeSeconds = function() return t end

    inst:setKeyRepeat(true)
    inst:setKeyRepeatParams(0.3, 0.04)

    IM.clearActionQueue()
    inst:onKeyPressed("up", nil, false)
    IM.clearActionQueue()     -- 清掉 pressed，只看 repeat

    t = 1.0                   -- 超过 delay
    inst:update(1.0)

    TestHelper.assertTrue(IM.getActionQueueSize() >= 1,
        "长按后动作队列应有 repeat 事件（实测 " .. IM.getActionQueueSize() .. "）")
    local ev = inst.getActionEventKeyOnly()
    TestHelper.assertEquals(IA.UP, ev and ev.action, "repeat 的动作名是 ui.up")
    TestHelper.assertEquals(1073741906, ev and ev.keyCode,
        "repeat 也带 keyCode（drain 机制需要）")

    inst:onKeyReleased("up", nil)
    inst:setKeyRepeat(false)
    EngineAPI.time.getTimeSeconds = savedGetTime
end

-- ---------------------------------------------------------------- 菜单快捷选择

function T.testMenuShortcutIsDeclaredByMenuNotFramework()
    print("\n=== Test: 菜单快捷选择由描述符声明（framework 零 jy.*）===")
    local src
    for _, p in ipairs({ "framework/menu_state_machine.lua",
                         "../game/framework/menu_state_machine.lua" }) do
        local f = io.open(p, "r")
        if f then src = f:read("*a"); f:close(); break end
    end
    TestHelper.assertNotNil(src, "应能读到 menu_state_machine.lua")

    -- 去掉注释再检查（注释里说明 jy.y 是允许的）
    local code = src:gsub("%-%-%[%[.-%]%]%]", ""):gsub("%-%-[^\n]*", "")
    TestHelper.assertNil(code:find('"jy%.y"'),
        'framework 不得硬编码 "jy.y"（那是游戏私有动作，会让框架绑死本游戏）')
    TestHelper.assertNil(code:find('"jy%.n"'),
        'framework 不得硬编码 "jy.n"')
    TestHelper.assertNotNil(code:find("menu%.shortcut"),
        "应改为读菜单描述符的 shortcut 字段")
end

function T.runAll()
    print("\n" .. string.rep("=", 60))
    print("输入动作迁移基础设施（input-action-layer Task 5 前置）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    T.testActionKeyOnlyFiltersSource()
    T.testActionKeyOnlyRespectsDisableInput()
    T.testActionKeyOnlyDoesNotDropPadEvents()
    T.testKeyRepeatAlsoFeedsActionQueue()
    T.testPeekActionInternalMirrorsPeekKey()
    T.testPeekActionInternalBypassesDisableInput()
    T.testNegativeControlSourceFilterMatters()
    T.testRealKeypressProducesActionWithKeyCode()
    T.testLongPressProducesRepeatActions()
    T.testMenuShortcutIsDeclaredByMenuNotFramework()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_input_action_migration.lua$") then
    T.runAll()
end

return T
