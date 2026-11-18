-- test_virtual_pad.lua
-- 虚拟手柄逻辑层测试（change: input-action-layer）
--
-- 守的坑（ADR-9）：
--   ① 逻辑层不得直接调用 love.*（绘制必须经 EngineAPI）
--   ② 布局必须用锚点+边距，不得硬编码屏幕坐标
--   ③ 一个手指只归属一个按钮（拖动不得串键）
--   ④ 平台默认值：Android/iOS 开，桌面关

local TestHelper = require("tests.test_helper")
local TestVirtualPad = {}

local function fresh()
    package.loaded["framework.virtual_pad"] = nil
    package.loaded["framework.input_actions"] = nil
    local VP = require("framework.virtual_pad")
    VP.init()
    return VP
end

-- ------------------------------------------------------------ 布局与锚点

function TestVirtualPad.testLayoutUsesAnchorNotAbsoluteCoords()
    local VP = fresh()
    for _, b in ipairs(VP.getLayout()) do
        TestHelper.assertNotNil(b.anchor, "按钮 " .. tostring(b.id) .. " 必须有 anchor")
        TestHelper.assertTrue(type(b.ox) == "number", "按钮必须有 ox")
        TestHelper.assertTrue(type(b.oy) == "number", "按钮必须有 oy")
        TestHelper.assertTrue(type(b.r) == "number", "按钮必须有半径 r")
    end
end

function TestVirtualPad.testButtonCenterBottomLeft()
    local VP = fresh()
    local b = { anchor = "bottom-left", ox = 100, oy = -150, r = 50 }
    local x, y = VP.buttonCenter(b, 1024, 768)
    TestHelper.assertEquals(100, x, "bottom-left 的 x 应等于 ox")
    TestHelper.assertEquals(618, y, "bottom-left 的 y 应为 768 - 150")
end

function TestVirtualPad.testButtonCenterBottomRight()
    local VP = fresh()
    local b = { anchor = "bottom-right", ox = -100, oy = -150, r = 50 }
    local x, y = VP.buttonCenter(b, 1024, 768)
    TestHelper.assertEquals(924, x, "bottom-right 的 x 应为 1024 - 100")
    TestHelper.assertEquals(618, y, "bottom-right 的 y 应为 768 - 150")
end

function TestVirtualPad.testButtonCenterTopRight()
    local VP = fresh()
    local b = { anchor = "top-right", ox = -80, oy = 80, r = 44 }
    local x, y = VP.buttonCenter(b, 1024, 768)
    TestHelper.assertEquals(944, x, "top-right 的 x 应为 1024 - 80")
    TestHelper.assertEquals(80, y, "top-right 的 y 应等于 oy")
end

function TestVirtualPad.testLayoutAdaptsToResolution()
    -- 同一份布局在不同分辨率下位置不同（证明不是硬编码）
    local VP = fresh()
    local b = { anchor = "bottom-right", ox = -100, oy = -150, r = 50 }
    local x1 = VP.buttonCenter(b, 1024, 768)
    local x2 = VP.buttonCenter(b, 2048, 1536)
    TestHelper.assertTrue(x1 ~= x2,
        "同一布局在 1024 与 2048 宽下 x 应不同（" .. x1 .. " vs " .. x2 .. "）")
end

-- ------------------------------------------------------------ 命中测试

function TestVirtualPad.testHitTestInsideButton()
    local VP = fresh()
    local layout = {
        { id = "up", action = "ui.up", anchor = "bottom-left",
          ox = 150, oy = -260, r = 56 },
    }
    VP.setLayout(layout)
    -- 圆心在 (150, 768-260=508)
    local hit = VP.hitTest(150, 508, 1024, 768)
    TestHelper.assertNotNil(hit, "点在圆心应命中")
    TestHelper.assertEquals("up", hit.id, "命中的应是 up 按钮")
end

function TestVirtualPad.testHitTestOutsideButton()
    local VP = fresh()
    VP.setLayout({ { id = "up", action = "ui.up", anchor = "bottom-left",
                     ox = 150, oy = -260, r = 56 } })
    local hit = VP.hitTest(150, 300, 1024, 768)
    TestHelper.assertEquals(nil, hit, "点在远处不应命中")
end

function TestVirtualPad.testHitTestUsesRadiusNotRect()
    -- 圆形命中：距圆心 r 之内命中，超过则不命中（即使在对角方向）
    local VP = fresh()
    VP.setLayout({ { id = "up", action = "ui.up", anchor = "bottom-left",
                     ox = 100, oy = 0, r = 50 } })
    local hit = VP.hitTest(100 + 60, 100, 1024, 768)  -- 距离 60 > r 50
    TestHelper.assertEquals(nil, hit, "距离超过半径不应命中（圆而非矩形）")
end

-- ------------------------------------------------------------ 触摸 → 动作

function TestVirtualPad.testTouchProducesAction()
    local VP = fresh()
    VP.setEnabled(true)
    VP.setLayout({ { id = "accept", action = "ui.accept", anchor = "bottom-right",
                     ox = -110, oy = -230, r = 64 } })
    local cx, cy = VP.buttonCenter(VP.getLayout()[1], 1024, 768)

    local fired = {}
    VP.update({ { id = 1, x = cx, y = cy } }, 1024, 768, 0,
        function(action, touchId) fired[#fired + 1] = action end)

    TestHelper.assertEquals(1, #fired, "按下应产 1 个动作事件")
    TestHelper.assertEquals("ui.accept", fired[1], "应产出 ui.accept")
end

function TestVirtualPad.testDisabledProducesNothing()
    local VP = fresh()
    VP.setEnabled(false)
    VP.setLayout({ { id = "accept", action = "ui.accept", anchor = "bottom-right",
                     ox = -110, oy = -230, r = 64 } })
    local fired = {}
    VP.update({ { id = 1, x = 100, y = 100 } }, 1024, 768, 0,
        function(a) fired[#fired + 1] = a end)
    TestHelper.assertEquals(0, #fired, "关闭状态不应产出任何事件")
end

function TestVirtualPad.testTouchOutsideAnyButtonProducesNothing()
    local VP = fresh()
    VP.setEnabled(true)
    VP.setLayout({ { id = "accept", action = "ui.accept", anchor = "bottom-right",
                     ox = -110, oy = -230, r = 64 } })
    local fired = {}
    VP.update({ { id = 1, x = 10, y = 10 } }, 1024, 768, 0,
        function(a) fired[#fired + 1] = a end)
    TestHelper.assertEquals(0, #fired, "点在空白处不应产出事件（应穿透给游戏）")
end

function TestVirtualPad.testDragDoesNotSwitchButton()
    -- 核心断言：一个手指只归属一个按钮（ADR-9）
    local VP = fresh()
    VP.setEnabled(true)
    VP.setLayout({
        { id = "up",    action = "ui.up",    anchor = "bottom-left", ox = 100, oy = -100, r = 50 },
        { id = "right", action = "ui.right", anchor = "bottom-left", ox = 250, oy = -100, r = 50 },
    })
    local fired = {}
    local emit = function(a) fired[#fired + 1] = a end

    -- 帧1：按在 UP
    VP.update({ { id = 1, x = 100, y = 768 - 100 } }, 1024, 768, 0, emit)
    TestHelper.assertEquals("ui.up", fired[1], "第一次按下应是 ui.up")

    -- 帧2：同一手指滑到 RIGHT 的位置
    VP.update({ { id = 1, x = 250, y = 768 - 100 } }, 1024, 768, 0.1, emit)
    -- 不应产出 ui.right（手指已归属 up）
    TestHelper.assertEquals(1, #fired, "拖动不得切换按钮（实测事件数 " .. #fired .. "）")
end

function TestVirtualPad.testEdgeOnlyFiresOnce()
    -- 只有「未按下 → 按下」产事件；持续按住不重复产
    local VP = fresh()
    VP.setEnabled(true)
    VP.setLayout({ { id = "accept", action = "ui.accept", anchor = "bottom-right",
                     ox = -110, oy = -230, r = 64 } })
    local cx, cy = VP.buttonCenter(VP.getLayout()[1], 1024, 768)
    local fired = {}
    local emit = function(a) fired[#fired + 1] = a end

    VP.update({ { id = 1, x = cx, y = cy } }, 1024, 768, 0, emit)
    VP.update({ { id = 1, x = cx, y = cy } }, 1024, 768, 0.1, emit)
    VP.update({ { id = 1, x = cx, y = cy } }, 1024, 768, 0.2, emit)

    TestHelper.assertEquals(1, #fired, "持续按住只应产 1 个边沿事件")
end

function TestVirtualPad.testReleaseThenPressFiresAgain()
    local VP = fresh()
    VP.setEnabled(true)
    VP.setLayout({ { id = "accept", action = "ui.accept", anchor = "bottom-right",
                     ox = -110, oy = -230, r = 64 } })
    local cx, cy = VP.buttonCenter(VP.getLayout()[1], 1024, 768)
    local fired = {}
    local emit = function(a) fired[#fired + 1] = a end

    VP.update({ { id = 1, x = cx, y = cy } }, 1024, 768, 0, emit)   -- 按下
    VP.update({}, 1024, 768, 0.1, emit)                            -- 松开
    VP.update({ { id = 1, x = cx, y = cy } }, 1024, 768, 0.2, emit) -- 再按

    TestHelper.assertEquals(2, #fired, "松开后再按应产第 2 个事件")
end

function TestVirtualPad.testMultiTouchTwoButtons()
    local VP = fresh()
    VP.setEnabled(true)
    VP.setLayout({
        { id = "up",     action = "ui.up",     anchor = "bottom-left", ox = 100, oy = -100, r = 50 },
        { id = "accept", action = "ui.accept", anchor = "bottom-right", ox = -100, oy = -100, r = 50 },
    })
    local cx1, cy1 = VP.buttonCenter(VP.getLayout()[1], 1024, 768)
    local cx2, cy2 = VP.buttonCenter(VP.getLayout()[2], 1024, 768)
    local fired = {}
    local emit = function(a) fired[#fired + 1] = a end

    VP.update({ { id = 1, x = cx1, y = cy1 }, { id = 2, x = cx2, y = cy2 } },
        1024, 768, 0, emit)
    TestHelper.assertEquals(2, #fired, "两个手指按两个按钮应产 2 个事件")
end

-- ------------------------------------------------------------ 平台默认值

function TestVirtualPad.testPlatformDefaultsAndroidOn()
    local VP = fresh()
    TestHelper.assertEquals(true, VP.PLATFORM_DEFAULTS.Android,
        "Android 默认应开（无物理键盘）")
end

function TestVirtualPad.testPlatformDefaultsDesktopOff()
    local VP = fresh()
    TestHelper.assertEquals(false, VP.PLATFORM_DEFAULTS.Windows,
        "Windows 默认应关（有键鼠）")
    TestHelper.assertEquals(false, VP.PLATFORM_DEFAULTS.Linux, "Linux 默认应关")
    TestHelper.assertEquals(false, VP.PLATFORM_DEFAULTS.macOS, "macOS 默认应关")
end

-- ------------------------------------------------------------ 解耦断言

function TestVirtualPad.testNoDirectLoveCalls()
    -- 负向对照：逻辑层不得直接调 love.*（绘制必须经 EngineAPI）
    local f = io.open("framework/virtual_pad.lua", "rb")
    if not f then
        f = io.open("game/framework/virtual_pad.lua", "rb")
    end
    TestHelper.assertNotNil(f, "应能找到 virtual_pad.lua")
    local content = f:read("*a")
    f:close()

    -- 只统计"实际调用"，排除注释里的说明
    local calls = 0
    for line in content:gmatch("[^\r\n]+") do
        -- 去掉行首注释后检查
        local code = line:gsub("^%s*%-%-.*$", "")
        if code:match("love%.") and not code:match("%-%-") then
            calls = calls + 1
        end
    end
    TestHelper.assertEquals(0, calls,
        "virtual_pad.lua 不得直接调用 love.*（实测 " .. calls .. " 处）")
end

function TestVirtualPad.testDrawUsesEngineAPI()
    local VP = fresh()
    VP.setEnabled(true)

    local draws = 0
    local savedEA = _G.EngineAPI
    _G.EngineAPI = {
        render = {
            fillRect = function() draws = draws + 1 end,
        },
    }
    VP.draw(1024, 768)
    _G.EngineAPI = savedEA

    TestHelper.assertTrue(draws > 0, "draw 应经 EngineAPI.render.fillRect 绘制")
end

function TestVirtualPad.testDrawNoopWhenDisabled()
    local VP = fresh()
    VP.setEnabled(false)
    local draws = 0
    local savedEA = _G.EngineAPI
    _G.EngineAPI = { render = { fillRect = function() draws = draws + 1 end } }
    local ret = VP.draw(1024, 768)
    _G.EngineAPI = savedEA
    TestHelper.assertEquals(false, ret, "关闭时 draw 应返回 false")
    TestHelper.assertEquals(0, draws, "关闭时不应绘制")
end

-- 套件入口
function TestVirtualPad.runAll()
    print("\n" .. string.rep("=", 60))
    print("虚拟手柄测试（input-action-layer）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestVirtualPad.testLayoutUsesAnchorNotAbsoluteCoords()
    TestVirtualPad.testButtonCenterBottomLeft()
    TestVirtualPad.testButtonCenterBottomRight()
    TestVirtualPad.testButtonCenterTopRight()
    TestVirtualPad.testLayoutAdaptsToResolution()

    TestVirtualPad.testHitTestInsideButton()
    TestVirtualPad.testHitTestOutsideButton()
    TestVirtualPad.testHitTestUsesRadiusNotRect()

    TestVirtualPad.testTouchProducesAction()
    TestVirtualPad.testDisabledProducesNothing()
    TestVirtualPad.testTouchOutsideAnyButtonProducesNothing()
    TestVirtualPad.testDragDoesNotSwitchButton()
    TestVirtualPad.testEdgeOnlyFiresOnce()
    TestVirtualPad.testReleaseThenPressFiresAgain()
    TestVirtualPad.testMultiTouchTwoButtons()

    TestVirtualPad.testPlatformDefaultsAndroidOn()
    TestVirtualPad.testPlatformDefaultsDesktopOff()

    TestVirtualPad.testNoDirectLoveCalls()
    TestVirtualPad.testDrawUsesEngineAPI()
    TestVirtualPad.testDrawNoopWhenDisabled()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_virtual_pad.lua$") then
    TestVirtualPad.runAll()
end

return TestVirtualPad
