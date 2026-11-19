-- test_virtual_pad_wiring.lua
-- 虚拟手柄**端到端接线测试**（change: port-contract-completeness Task 8）
--
-- 守的坑（真实缺陷，见 design.md REQ-VP-1 / REQ-VP-2）：
--   input-action-layer（commit 33b89bc）引入的虚拟手柄接线断了：
--     pollVirtualPad 依赖 EngineAPI.render.getWidth/getHeight，
--     而那两个函数**契约与实现里都没有** → 函数永远 return false
--   → 虚拟手柄在真机上永远不会激活，而它 57 条逻辑测试全绿。
--
-- 本测试跑**真实调用链**：
--   注入触摸点 → JYMainAdapter.pollVirtualPad() → 动作队列 → 取动作
-- 而不是只测 VirtualPad.update 的纯逻辑。

local TestHelper = require("tests.test_helper")
local TestVirtualPadWiring = {}

local function withStubbedEngine(fn)
    local saved = {
        EngineAPI = rawget(_G, "EngineAPI"),
        love = rawget(_G, "love"),
        CC = rawget(_G, "CC"),
        lib = rawget(_G, "lib"),
    }
    local ET = require("tests.engine_test")
    rawset(_G, "EngineAPI", ET)
    rawset(_G, "lib", ET)

    local cc = rawget(_G, "CC") or {}
    cc.ScreenW = 1024
    cc.ScreenH = 768
    rawset(_G, "CC", cc)

    local ok, err = pcall(fn)

    rawset(_G, "EngineAPI", saved.EngineAPI)
    rawset(_G, "love", saved.love)
    rawset(_G, "CC", saved.CC)
    rawset(_G, "lib", saved.lib)
    if not ok then error(err) end
end

local function setupPad(opts)
    opts = opts or {}
    local VP = require("framework.virtual_pad")
    package.loaded["framework.virtual_pad"] = nil
    VP = require("framework.virtual_pad")
    VP.init()
    VP.setEnabled(opts.enabled ~= false)
    local ET = _G.EngineAPI
    ET.render._width = opts.width or 1024
    ET.render._height = opts.height or 768
    ET.input._capabilities = {
        pointer = true, touch = true, gamepad = false, vr = false,
    }
    ET.input._touches = opts.touches or {}
    local IM = require("framework.input_manager")
    IM.getInstance():init()
    return VP
end

-- ------------------------------------------------------------ 契约存在性

function TestVirtualPadWiring.testRenderSizeContractsExist()
    print("\n=== Test: render.getWidth/getHeight 契约存在 ===")
    local ET = require("tests.engine_test")
    TestHelper.assertNotNil(ET.render.getWidth,
        "render.getWidth 必须存在（否则虚拟手柄永远不激活）")
    TestHelper.assertNotNil(ET.render.getHeight, "render.getHeight 必须存在")

    local w = ET.render.getWidth()
    local h = ET.render.getHeight()
    TestHelper.assertTrue(type(w) == "number" and w > 0,
        "getWidth 必须返回正数，实测 " .. tostring(w))
    TestHelper.assertTrue(type(h) == "number" and h > 0,
        "getHeight 必须返回正数，实测 " .. tostring(h))
end

-- ------------------------------------------------------------ 端到端激活

function TestVirtualPadWiring.testPollActivatesOnTouch()
    print("\n=== Test: 注入触摸点 → pollVirtualPad 真实激活 ===")
    withStubbedEngine(function()
        local VP = setupPad()
        local ET = _G.EngineAPI

        -- 算 accept 按钮圆心
        local accept
        for _, b in ipairs(VP.getLayout()) do
            if b.id == "accept" then accept = b end
        end
        TestHelper.assertNotNil(accept, "默认布局必须有 accept 按钮")
        local cx, cy = VP.buttonCenter(accept, ET.render.getWidth(), ET.render.getHeight())

        ET.input._touches = { { id = 1, x = cx, y = cy } }

        local JYMainAdapter = require("framework.jymain_adapter")
        local handled = JYMainAdapter.pollVirtualPad()

        TestHelper.assertEquals(true, handled,
            "注入 accept 圆心的触摸后 pollVirtualPad 必须返回 true（接线通了）")

        local IM = require("framework.input_manager")
        local ev = IM.getActionEvent()
        TestHelper.assertNotNil(ev, "动作队列必须有事件")
        TestHelper.assertEquals("ui.accept", ev.action, "动作应为 ui.accept")
        TestHelper.assertEquals("touch", ev.source, "来源应为 touch")
        TestHelper.assertEquals(1, ev.index, "index 应为触摸点 id")
    end)
end

function TestVirtualPadWiring.testPollDisabledProducesNothing()
    print("\n=== Test: 设置关闭时不激活 ===")
    withStubbedEngine(function()
        local VP = setupPad({ enabled = false })
        local ET = _G.EngineAPI
        local accept
        for _, b in ipairs(VP.getLayout()) do
            if b.id == "accept" then accept = b end
        end
        local cx, cy = VP.buttonCenter(accept, ET.render.getWidth(), ET.render.getHeight())
        ET.input._touches = { { id = 1, x = cx, y = cy } }

        local JYMainAdapter = require("framework.jymain_adapter")
        local handled = JYMainAdapter.pollVirtualPad()
        TestHelper.assertEquals(false, handled, "关闭状态不激活")

        local IM = require("framework.input_manager")
        TestHelper.assertEquals(nil, IM.getActionEvent(), "关闭状态不产动作")
    end)
end

function TestVirtualPadWiring.testPollNoTouchCapability()
    print("\n=== Test: 引擎无触摸能力时不激活 ===")
    withStubbedEngine(function()
        local VP = setupPad()
        local ET = _G.EngineAPI
        ET.input._capabilities = {
            pointer = true, touch = false, gamepad = false, vr = false,
        }
        ET.input._touches = { { id = 1, x = 100, y = 100 } }

        local JYMainAdapter = require("framework.jymain_adapter")
        TestHelper.assertEquals(false, JYMainAdapter.pollVirtualPad(),
            "无 touch 能力时（MUD/Web）必须不激活")
    end)
end

function TestVirtualPadWiring.testPollUsesContractSizeNotCC()
    print("\n=== Test: 用契约尺寸而非 CC 常量 ===")
    withStubbedEngine(function()
        -- 模拟窗口被 resize 到 800x600，但 CC 仍是 1024x768
        local VP = setupPad({ width = 800, height = 600 })
        local ET = _G.EngineAPI
        TestHelper.assertEquals(1024, _G.CC.ScreenW, "CC 常量仍是 1024（不被改）")

        local accept
        for _, b in ipairs(VP.getLayout()) do
            if b.id == "accept" then accept = b end
        end
        -- 按 800x600 算圆心
        local cx, cy = VP.buttonCenter(accept, 800, 600)
        ET.input._touches = { { id = 1, x = cx, y = cy } }

        local JYMainAdapter = require("framework.jymain_adapter")
        TestHelper.assertEquals(true, JYMainAdapter.pollVirtualPad(),
            "按 800x600 的圆心点击必须命中（证明用的是契约尺寸，不是 CC 1024x768）")
    end)
end

function TestVirtualPadWiring.testTouchOutsideProducesNoAction()
    print("\n=== Test: 空白区不产动作 ===")
    withStubbedEngine(function()
        local VP = setupPad({ touches = { { id = 1, x = 10, y = 10 } } })
        local JYMainAdapter = require("framework.jymain_adapter")
        JYMainAdapter.pollVirtualPad()

        local IM = require("framework.input_manager")
        TestHelper.assertEquals(nil, IM.getActionEvent(), "远离按钮的触摸不产动作")
    end)
end

-- ------------------------------------------------------------ 负向对照

function TestVirtualPadWiring.testMissingSizeWouldBreakWiring()
    print("\n=== Test: 缺少 getWidth 会导致接线断开（负向对照）===")
    withStubbedEngine(function()
        local VP = setupPad()
        local ET = _G.EngineAPI

        -- 临时摘掉 getWidth，模拟修复前的状态
        local savedW, savedH = ET.render.getWidth, ET.render.getHeight
        ET.render.getWidth = nil
        ET.render.getHeight = nil

        local accept
        for _, b in ipairs(VP.getLayout()) do
            if b.id == "accept" then accept = b end
        end
        ET.input._touches = { { id = 1, x = 900, y = 500 } }

        local JYMainAdapter = require("framework.jymain_adapter")
        local handled = JYMainAdapter.pollVirtualPad()

        TestHelper.assertEquals(false, handled,
            "缺少 getWidth 时 pollVirtualPad 必须返回 false（这正是修复前的现象）")

        ET.render.getWidth = savedW
        ET.render.getHeight = savedH
    end)
end

function TestVirtualPadWiring.runAll()
    print("\n" .. string.rep("=", 60))
    print("虚拟手柄接线端到端测试（REQ-VP-1 / REQ-VP-2）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestVirtualPadWiring.testRenderSizeContractsExist()
    TestVirtualPadWiring.testPollActivatesOnTouch()
    TestVirtualPadWiring.testPollDisabledProducesNothing()
    TestVirtualPadWiring.testPollNoTouchCapability()
    TestVirtualPadWiring.testPollUsesContractSizeNotCC()
    TestVirtualPadWiring.testTouchOutsideProducesNoAction()
    TestVirtualPadWiring.testMissingSizeWouldBreakWiring()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_virtual_pad_wiring.lua$") then
    TestVirtualPadWiring.runAll()
end

return TestVirtualPadWiring
