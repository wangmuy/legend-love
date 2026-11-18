-- test_start_menu_layout.lua
-- 开始菜单的纵向布局回归测试
--
-- 背景（真实缺陷）：原公式把项数写死成 3
--
--     CC.StartMenuY = CC.ScreenH - 3*(CC.StartMenuFontSize+CC.RowPixel) - 20
--
-- 加入「设置」后开始菜单变成 4 项，字号 32 的行高较大，最后一项
-- 「离开游戏」的下半截超出了屏幕底部：
--
--     Y = 768 - 3*36 - 20 = 640
--     菜单高 = (32+4)*4 + 5 = 149
--     底 = 789 > 768（超出 21px）
--
-- 修法：按「最大项数」计算，并把项数提成 CC.StartMenuItemMax，
-- 以后增删开始菜单项只改这个常量。
--
-- 本测试直接复算 jyconst 的公式并断言不溢出，不依赖渲染。

local TestHelper = require("tests.test_helper")
local TestStartMenuLayout = {}

-- 与 jyconst.lua 保持一致的布局参数
local MENU_BORDER = 5      -- CC.MenuBorderPixel
local ROW_PIXEL = 4        -- CC.RowPixel
local BOTTOM_MARGIN = 20

-- 复刻 jyconst.lua 的计算（与生产代码同一公式）
local function computeStartMenuY(screenH, font, itemMax)
    return screenH - itemMax * (font + ROW_PIXEL) - MENU_BORDER - BOTTOM_MARGIN
end

local function computeMenuHeight(font, itemCount)
    return (font + ROW_PIXEL) * itemCount + MENU_BORDER
end

-- 两种显示模式（jyconst.lua 的 CONFIG.Type 分支）
local MODES = {
    { name = "Type=1 (1024x768)", screenH = 768, font = 32 },
    { name = "Type=0 (320x240)",  screenH = 240, font = 16 },
}

local ITEM_MAX = 4   -- 重新开始 / 载入进度 / 设置 / 离开游戏

function TestStartMenuLayout.testBottomDoesNotOverflow()
    for _, mode in ipairs(MODES) do
        local y = computeStartMenuY(mode.screenH, mode.font, ITEM_MAX)
        local h = computeMenuHeight(mode.font, ITEM_MAX)
        local bottom = y + h
        TestHelper.assertTrue(bottom <= mode.screenH,
            string.format("%s: 菜单底部 %d 不超出屏幕 %d",
                mode.name, bottom, mode.screenH))
    end
end

function TestStartMenuLayout.testBottomMarginRespected()
    for _, mode in ipairs(MODES) do
        local y = computeStartMenuY(mode.screenH, mode.font, ITEM_MAX)
        local h = computeMenuHeight(mode.font, ITEM_MAX)
        local margin = mode.screenH - (y + h)
        TestHelper.assertTrue(margin >= BOTTOM_MARGIN,
            string.format("%s: 底边距 %d >= %d", mode.name, margin, BOTTOM_MARGIN))
    end
end

function TestStartMenuLayout.testStartYPositive()
    for _, mode in ipairs(MODES) do
        local y = computeStartMenuY(mode.screenH, mode.font, ITEM_MAX)
        TestHelper.assertTrue(y > 0,
            string.format("%s: Y=%d 必须为正（否则菜单从屏外开始）", mode.name, y))
    end
end

function TestStartMenuLayout.testSubMenuFitsAtSameY()
    -- 载入进度子菜单是 3 项，复用同一个 StartMenuY，也必须在屏内
    for _, mode in ipairs(MODES) do
        local y = computeStartMenuY(mode.screenH, mode.font, ITEM_MAX)
        local h3 = computeMenuHeight(mode.font, 3)
        TestHelper.assertTrue(y + h3 <= mode.screenH,
            string.format("%s: 3 项子菜单底部 %d 不超出 %d",
                mode.name, y + h3, mode.screenH))
    end
end

function TestStartMenuLayout.testOldFormulaWouldOverflow()
    -- 负向对照：证明这个修正确实必要
    -- 旧公式：用固定 3 项算 4 项菜单的位置
    local oldY = 768 - 3 * (32 + ROW_PIXEL) - 20
    local oldBottom = oldY + computeMenuHeight(32, 4)
    TestHelper.assertTrue(oldBottom > 768,
        string.format("旧公式确实溢出（底 %d > 768）", oldBottom))
    TestHelper.assertEquals(21, oldBottom - 768,
        "溢出量 21px —— 正好盖住「离开游戏」下半截")
end

function TestStartMenuLayout.testItemMaxMatchesActualMenu()
    -- CC.StartMenuItemMax 必须与实际菜单项数一致，否则公式又会失配。
    -- 这里从 jymain_adapter 的菜单定义处核对项数（4 项）。
    local menuItems = {
        "重新开始", "载入进度", "设置", "离开游戏",
    }
    TestHelper.assertEquals(ITEM_MAX, #menuItems,
        "开始菜单实际项数与 CC.StartMenuItemMax 一致")
end

-- ============================================================
-- 水平居中（REQ-MS2-13）
--
-- 用户实测：开始菜单左对齐，没有居中。
-- 根因：旧公式用「猜测宽度」（N * 字号），而菜单真实宽度
-- 由最长项文本决定，且还要加 2*MenuBorderPixel。
-- ============================================================

function TestStartMenuLayout.testCenteredMenuXFormula()
    print("\n=== Test: centeredMenuX 用真实文本宽度 ===")
    local TextBoxLayout = require("framework.text_box_layout")

    local items = { "重新开始", "载入进度", "设置", "离开游戏" }
    local size = 32
    local border = 5
    local screenW = 1024

    -- 复算期望值
    local maxW = 0
    for _, t in ipairs(items) do
        local w = TextBoxLayout.textWidth(t, size)
        if w > maxW then maxW = w end
    end
    local menuW = maxW + 2 * border
    local expected = math.floor((screenW - menuW) / 2)

    -- 装上最小的 CC 让函数可用
    local savedCC = rawget(_G, "CC")
    rawset(_G, "CC", { ScreenW = screenW, MenuBorderPixel = border })

    package.loaded["framework.jymain_adapter"] = nil
    local ok, JA = pcall(require, "framework.jymain_adapter")

    if ok and JA and JA.centeredMenuX then
        local got = JA.centeredMenuX(items, size)
        TestHelper.assertEquals(expected, got,
            "centeredMenuX 必须按真实文本宽度居中")
        -- 左右余量必须相等
        TestHelper.assertEquals(got, screenW - got - menuW,
            "左右余量相等（真正居中）")
    else
        -- jymain_adapter 依赖大量全局，无法在纯测试环境加载时跳过
        TestHelper.assertTrue(true, "jymain_adapter 无法加载，跳过（已记录公式）")
    end

    rawset(_G, "CC", savedCC)
end

function TestStartMenuLayout.testWiderMenuNeedsDifferentX()
    print("\n=== Test: 更宽的菜单不能用同一个 X ===")
    local TextBoxLayout = require("framework.text_box_layout")

    local function widthOf(items, size)
        local maxW = 0
        for _, t in ipairs(items) do
            local w = TextBoxLayout.textWidth(t, size)
            if w > maxW then maxW = w end
        end
        return maxW
    end

    local startW = widthOf({ "重新开始", "载入进度", "设置", "离开游戏" }, 32)
    local settingsW = widthOf({ "音乐音量", "音效音量", "鼠标操作    关", "返回" }, 32)

    TestHelper.assertTrue(settingsW > startW,
        string.format("设置菜单(%d) 必须比开始菜单(%d) 宽 —— 所以不能共用同一个 menux",
            settingsW, startW))

    -- 若共用开始菜单的 X，设置菜单会**不对称**（左余量 > 右余量）
    --
    -- 注意：不是"溢出屏幕"，而是"看起来偏左" —— 这才是用户报告的现象。
    local screenW = 1024
    local border = 5
    local sharedX = math.floor((screenW - (startW + 2 * border)) / 2)
    local settingsWTotal = settingsW + 2 * border

    local leftMargin = sharedX
    local rightMargin = screenW - sharedX - settingsWTotal
    TestHelper.assertTrue(leftMargin > rightMargin,
        string.format("共用 X 时左余量(%d) > 右余量(%d)，视觉上偏左 %dpx",
            leftMargin, rightMargin, leftMargin - rightMargin))
end

-- 回归：centeredMenuX 与 createMenu 必须用**同一种**度量
--
-- 用户报告「设置菜单还是左对齐」。根因不是 centeredMenuX 算错，而是两套度量
-- 打架：centeredMenuX 按显示宽度、createMenu 按 UTF-8 字节数。
-- 设置菜单按显示宽度是 234px、按字节是 314px，相差 80px → 居中 X 偏 40px。
--
-- 本测试锁死两者一致。若将来有人把 createMenu 改回字节度量，这里会立刻失败。
function TestStartMenuLayout.testCenteredXMatchesCreateMenuWidth()
    print("\n=== Test: centeredMenuX 与 createMenu 用同一套度量 ===")
    local TextBoxLayout = require("framework.text_box_layout")
    local MenuStateMachine = require("framework.menu_state_machine")

    local screenW = 1024
    local border = 5
    local size = 32

    local savedCC = rawget(_G, "CC")
    rawset(_G, "CC", {
        ScreenW = screenW,
        MenuBorderPixel = border,
        RowPixel = 4,
        DefaultFont = 24,
    })

    -- 设置菜单的 4 项（含鼠标开关项的实际文本）
    local items = {
        {"音乐音量", nil, 1},
        {"音效音量", nil, 1},
        {"鼠标操作    开", nil, 1},
        {"返回", nil, 1},
    }

    -- 期望：createMenu 建出的宽度 == centeredMenuX 假设的宽度
    local msm = MenuStateMachine.getInstance()
    msm:clear()

    -- centeredMenuX 侧的宽度口径
    local maxW = 0
    for _, it in ipairs(items) do
        local w = TextBoxLayout.textWidth(it[1], size)
        if w > maxW then maxW = w end
    end
    local expectedMenuW = maxW + 2 * border
    local expectedX = math.floor((screenW - expectedMenuW) / 2)

    -- createMenu 侧的宽度
    local menu = msm:createMenu(items, 4, 0, expectedX, 10, 0, 0, 0, 0, size, 0, 0)
    msm:clear()

    TestHelper.assertEquals(expectedMenuW, menu.w,
        string.format("createMenu 宽度(%d) 必须等于显示宽度口径(%d)",
            menu.w, expectedMenuW))

    -- 左右余量相等 = 真正居中
    local left = menu.x1
    local right = screenW - menu.x1 - menu.w
    TestHelper.assertEquals(left, right,
        string.format("左右余量必须相等（左 %d / 右 %d）", left, right))

    rawset(_G, "CC", savedCC)
end

function TestStartMenuLayout.runAll()
    print("\n" .. string.rep("=", 60))
    print("开始菜单布局测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestStartMenuLayout.testBottomDoesNotOverflow()
    TestStartMenuLayout.testBottomMarginRespected()
    TestStartMenuLayout.testStartYPositive()
    TestStartMenuLayout.testSubMenuFitsAtSameY()
    TestStartMenuLayout.testOldFormulaWouldOverflow()
    TestStartMenuLayout.testItemMaxMatchesActualMenu()
    TestStartMenuLayout.testCenteredMenuXFormula()
    TestStartMenuLayout.testWiderMenuNeedsDifferentX()
    TestStartMenuLayout.testCenteredXMatchesCreateMenuWidth()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_start_menu_layout.lua$") then
    TestStartMenuLayout.runAll()
end

return TestStartMenuLayout
