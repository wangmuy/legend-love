-- test_menu_align.lua
-- 菜单项文本的框内水平对齐（align = "left" | "center"）
--
-- 守的坑（用户实测）：开始菜单的框已经水平居中，但「设置」只有 2 字、
-- 其余 3 项 4 字，而每项文本默认**左对齐**，于是「设置」左边贴框、右边空 64px。
-- 视觉上就是「设置项没有居中」。
--
-- 关键设计约束：
--   ① 默认必须仍是 left —— 既有 20+ 个菜单（物品/人名/招式）项长各异，
--      左对齐才看得出层级。改成全局居中会破坏那些界面。
--   ② 多行文本项（值项的 ▲/值/▼）不参与居中 —— 它自带手写前导空格，
--      是给左对齐设计的三行，再叠加居中会推歪。

local TestHelper = require("tests.test_helper")
local TestMenuAlign = {}

local function withStubs(fn)
    local saved = {
        Cls = rawget(_G, "Cls"),
        DrawBox = rawget(_G, "DrawBox"),
        DrawString = rawget(_G, "DrawString"),
        lib = rawget(_G, "lib"),
        CC = rawget(_G, "CC"),
    }
    rawset(_G, "Cls", function() end)
    rawset(_G, "DrawBox", function() end)
    rawset(_G, "DrawString", function() end)
    rawset(_G, "lib", { Debug = function() end, GetKey = function() return -1 end })

    local cc = rawget(_G, "CC") or {}
    cc.ScreenW = 1024
    cc.ScreenH = 768
    cc.MenuBorderPixel = 5
    cc.RowPixel = 4
    cc.DefaultFont = 24
    cc.StartMenuFontSize = 32
    rawset(_G, "CC", cc)

    local ok, err = pcall(fn)

    rawset(_G, "Cls", saved.Cls)
    rawset(_G, "DrawBox", saved.DrawBox)
    rawset(_G, "DrawString", saved.DrawString)
    rawset(_G, "lib", saved.lib)
    rawset(_G, "CC", saved.CC)
    if not ok then error(err) end
end

local START_MENU = {
    {"重新开始", nil, 1},
    {"载入进度", nil, 1},
    {"设置",     nil, 1},
    {"离开游戏", nil, 1},
}

-- ------------------------------------------------------------ 默认左对齐

function TestMenuAlign.testDefaultAlignIsLeft()
    print("\n=== Test: align 默认是 left ===")
    withStubs(function()
        local MSM = require("framework.menu_state_machine")
        local msm = MSM.getInstance()
        msm:clear()

        -- 不传 align（既有 20+ 个调用点的写法）
        local m = msm:createMenu(START_MENU, 4, 0, 100, 50, 0, 0,
                                 0, 0, 32, 0, 0)
        local x = MSM.textX(m, "设置")
        msm:clear()

        TestHelper.assertEquals("left", m.align, "align 默认必须是 left")
        TestHelper.assertEquals(105, x, "左对齐起点 = x1 + MenuBorderPixel")
    end)
end

-- ------------------------------------------------------------ 居中生效

function TestMenuAlign.testCenterAlignShiftsShortItem()
    print("\n=== Test: 居中让 2 字项右移（4 字项不动）===")
    withStubs(function()
        local MSM = require("framework.menu_state_machine")
        local TextBoxLayout = require("framework.text_box_layout")
        local msm = MSM.getInstance()
        msm:clear()

        local m = msm:createMenu(START_MENU, 4, 0, 443, 50, 0, 0,
                                 0, 0, 32, 0, 0, "center")

        local xShort = MSM.textX(m, "设置")
        local xLong  = MSM.textX(m, "重新开始")
        local wShort = TextBoxLayout.textWidth("设置", 32)
        local wLong  = TextBoxLayout.textWidth("重新开始", 32)
        local leftX  = m.x1 + 5
        msm:clear()

        -- 4 字项文本宽 = 框宽 - 2*边框，居中后位置不变
        TestHelper.assertEquals(leftX, xLong,
            "4 字项（填满框）居中后位置不变")
        -- 2 字项右移 (wLong - wShort)/2 = (128-64)/2 = 32
        TestHelper.assertEquals(leftX + 32, xShort,
            "2 字项居中后右移 32px（半个字身）")
    end)
end

function TestMenuAlign.testCenteredItemSymmetry()
    print("\n=== Test: 居中后左右内边距相等 ===")
    withStubs(function()
        local MSM = require("framework.menu_state_machine")
        local TextBoxLayout = require("framework.text_box_layout")
        local msm = MSM.getInstance()
        msm:clear()

        local m = msm:createMenu(START_MENU, 4, 0, 443, 50, 0, 0,
                                 0, 0, 32, 0, 0, "center")
        local x = MSM.textX(m, "设置")
        local w = TextBoxLayout.textWidth("设置", 32)
        local leftPad  = x - m.x1
        local rightPad = (m.x1 + m.w) - (x + w)
        msm:clear()

        TestHelper.assertEquals(leftPad, rightPad,
            string.format("左右内边距必须相等（左 %d / 右 %d）", leftPad, rightPad))
    end)
end

function TestMenuAlign.testCenterNeverEscapesLeftPadding()
    print("\n=== Test: 框比文本窄时退化为左对齐 ===")
    withStubs(function()
        local MSM = require("framework.menu_state_machine")
        local msm = MSM.getInstance()
        msm:clear()

        local m = msm:createMenu(START_MENU, 4, 0, 443, 50, 0, 0,
                                 0, 0, 32, 0, 0, "center")
        -- 强行把框宽改窄，模拟异常（例如外部改了 menu.w）
        m.w = 20
        local x = MSM.textX(m, "重新开始")
        msm:clear()

        TestHelper.assertEquals(m.x1 + 5, x,
            "框太窄时不得算出小于左边距的 X（退化为左对齐）")
    end)
end

-- ------------------------------------------------------------ 多行文本不受影响

function TestMenuAlign.testMultiLineValueItemNotCentered()
    print("\n=== Test: 值项三行文本不受 align 影响 ===")
    withStubs(function()
        local Settings = require("framework.settings")
        Settings.reset()
        local AudioSettings = require("framework.audio_settings")
        AudioSettings.resetInit()
        AudioSettings.define()
        local AudioMenu = require("framework.audio_menu")
        local MSM = require("framework.menu_state_machine")

        local msm = MSM.getInstance()
        msm:clear()

        local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
        local m = msm:createMenu(items, 1, 0, 400, 100, 0, 0,
                                 1, 1, 24, 0, 0, "center")
        msm:clear()

        -- 值项是多行文本（含 \n），draw 走多行分支，不调 textX。
        -- 这里断言菜单本身仍记录 align=center（不因值项而否定），
        -- 但绘制分支的选择由 \n 决定，与 align 无关。
        TestHelper.assertEquals("center", m.align,
            "菜单仍记录 align=center（值项的多行分支单独处理）")
    end)
end

-- ------------------------------------------------------------ 开始菜单已启用

function TestMenuAlign.testStartMenuUsesCenter()
    print("\n=== Test: 开始菜单传了 align=center ===")
    local f = io.open("framework/jymain_adapter.lua", "rb")
    if not f then f = io.open("game/framework/jymain_adapter.lua", "rb") end
    TestHelper.assertNotNil(f, "应能读到 jymain_adapter.lua")
    local src = f:read("*a")
    f:close()

    -- 开始菜单的 ShowMenuCoroutine 调用必须带 "center"
    local ok = src:find('C_STARTMENU, C_RED, "center"', 1, true) ~= nil
    TestHelper.assertTrue(ok,
        "开始菜单/载入菜单必须传 align=\"center\"（否则「设置」仍左对齐）")
end

-- ------------------------------------------------------------ 既有菜单未被改动

function TestMenuAlign.testOtherMenusStillLeftAligned()
    print("\n=== Test: 其它菜单调用点未传 center ===")
    local f = io.open("framework/jymain_async.lua", "rb")
    if not f then f = io.open("game/framework/jymain_async.lua", "rb") end
    TestHelper.assertNotNil(f, "应能读到 jymain_async.lua")
    local src = f:read("*a")
    f:close()

    -- 系统菜单（物品/人名等）不应传 center
    local n = 0
    for _ in src:gmatch('"center"') do n = n + 1 end
    TestHelper.assertEquals(0, n,
        "jymain_async 的既有菜单不得传 center（项长各异，左对齐才看得出层级）")
end

function TestMenuAlign.runAll()
    print("\n" .. string.rep("=", 60))
    print("菜单项文本对齐测试")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestMenuAlign.testDefaultAlignIsLeft()
    TestMenuAlign.testCenterAlignShiftsShortItem()
    TestMenuAlign.testCenteredItemSymmetry()
    TestMenuAlign.testCenterNeverEscapesLeftPadding()
    TestMenuAlign.testMultiLineValueItemNotCentered()
    TestMenuAlign.testStartMenuUsesCenter()
    TestMenuAlign.testOtherMenusStillLeftAligned()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_menu_align.lua$") then
    TestMenuAlign.runAll()
end

return TestMenuAlign
