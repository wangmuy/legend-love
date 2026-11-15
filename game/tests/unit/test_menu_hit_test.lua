-- test_menu_hit_test.lua
-- 菜单鼠标命中测试（REQ-MS2-2）
--
-- 全部是纯几何计算，不需要渲染、不需要状态机实例。
-- 关键断言：numShow 滚动（start > 1）时的行偏移必须用 (i - start)。

local TestHelper = require("tests.test_helper")
local TestMenuHitTest = {}

local function installStubs()
    local saved = {
        CC = rawget(_G, "CC"),
        lib = rawget(_G, "lib"),
        DrawString = rawget(_G, "DrawString"),
        Cls = rawget(_G, "Cls"),
        DrawBox = rawget(_G, "DrawBox"),
        C_WHITE = rawget(_G, "C_WHITE"),
    }
    rawset(_G, "CC", { MenuBorderPixel = 5, RowPixel = 4 })
    rawset(_G, "lib", { Debug = function() end, GetKey = function() return -1 end })
    rawset(_G, "DrawString", function() end)
    rawset(_G, "Cls", function() end)
    rawset(_G, "DrawBox", function() end)
    rawset(_G, "C_WHITE", 0xFFFFFF)
    return saved
end

local function restoreStubs(saved)
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

-- 造一个竖向菜单：
--   x1=100 y1=50  size=24  RowPixel=4  MenuBorderPixel=5
--   行高 = 28；第 i 项起始 y = 50 + 5 + (i - start) * 28
local function makeMenu(opts)
    opts = opts or {}
    local start = opts.start or 1
    local num = opts.num or 4
    local total = opts.total or num
    local itemW = opts.w or 200
    local rh = 28
    -- newMenu 必须有：hitItem 要读每项的 desc 判断占几行
    -- （普通项 1 行、值项 3 行，见 hitItem 的注释）
    local newMenu = {}
    for i = 1, total do
        local desc = nil
        if opts.valueRowsAt and opts.valueRowsAt == i then
            desc = { kind = "number", step = 1, min = 0, max = 128 }
        end
        newMenu[i] = { "item" .. i, desc, 1, i }
    end

    return {
        x1 = 100, y1 = 50,
        w = itemW,
        h = (opts.h) or (rh * num + 5),
        start = start,
        num = num,
        newNumItem = total,
        newMenu = newMenu,
        size = 24,
        isHorizontal = opts.isHorizontal or false,
    }
end

-- ============================================================
-- hitMenu
-- ============================================================

function TestMenuHitTest.testHitMenuInside()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu()

    TestHelper.assertTrue(MSM.hitMenu(m, 100, 50), "左上角在内")
    TestHelper.assertTrue(MSM.hitMenu(m, 300, 160), "右下角在内")
    TestHelper.assertTrue(MSM.hitMenu(m, 200, 100), "中心在内")
    restoreStubs(saved)
end

function TestMenuHitTest.testHitMenuOutside()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu()

    TestHelper.assertFalse(MSM.hitMenu(m, 99, 50), "左边界外")
    TestHelper.assertFalse(MSM.hitMenu(m, 100, 49), "上边界外")
    TestHelper.assertFalse(MSM.hitMenu(m, 301, 100), "右边界外")
    TestHelper.assertFalse(MSM.hitMenu(m, 200, 200), "下边界外")
    TestHelper.assertFalse(MSM.hitMenu(nil, 100, 100), "nil 菜单返回 false")
    restoreStubs(saved)
end

-- ============================================================
-- hitItem：竖向
-- ============================================================

function TestMenuHitTest.testHitItemVertical()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu()

    -- 第 1 项：[55, 83)；第 2 项：[83, 111) …
    TestHelper.assertEquals(1, MSM.hitItem(m, 150, 60), "第 1 行")
    TestHelper.assertEquals(2, MSM.hitItem(m, 150, 90), "第 2 行")
    TestHelper.assertEquals(3, MSM.hitItem(m, 150, 118), "第 3 行")
    TestHelper.assertEquals(4, MSM.hitItem(m, 150, 146), "第 4 行")
    restoreStubs(saved)
end

function TestMenuHitTest.testHitItemOutsideReturnsNil()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu()
    TestHelper.assertEquals(nil, MSM.hitItem(m, 50, 60), "菜单外返回 nil")
    restoreStubs(saved)
end

function TestMenuHitTest.testHitItemBlankAreaReturnsNil()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    -- 只有 2 项但菜单高度按 4 项算 → 下半部是空白区
    local m = makeMenu({ num = 2, total = 2, h = 28 * 4 + 5 })
    TestHelper.assertEquals(nil, MSM.hitItem(m, 150, 160),
        "矩形内但超出项数 → nil（空白区）")
    restoreStubs(saved)
end

-- ============================================================
-- hitItem：numShow 滚动偏移（最关键）
-- ============================================================

function TestMenuHitTest.testHitItemWithScrollOffset()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")

    -- numShow=3、共 10 项、已滚到 start=5
    -- 屏幕第 1 行显示的是 newMenu[5]，不是 newMenu[1]
    local m = makeMenu({ start = 5, num = 3, total = 10 })

    TestHelper.assertEquals(5, MSM.hitItem(m, 150, 60),
        "屏幕第 1 行 → newMenu[5]（start 偏移生效）")
    TestHelper.assertEquals(6, MSM.hitItem(m, 150, 90),
        "屏幕第 2 行 → newMenu[6]")
    TestHelper.assertEquals(7, MSM.hitItem(m, 150, 118),
        "屏幕第 3 行 → newMenu[7]")
    restoreStubs(saved)
end

function TestMenuHitTest.testScrollOffsetNegativeControl()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu({ start = 5, num = 3, total = 10 })

    -- 断言「如果错用 (i - 1)，会算出 1/2/3 而不是 5/6/7」
    local wrongFirst = MSM.hitItem(m, 150, 60)
    TestHelper.assertTrue(wrongFirst ~= 1,
        "不得退化为 (i-1) 偏移（否则第 1 行会算成第 1 项）")
    restoreStubs(saved)
end

-- ============================================================
-- hitItem：横向
-- ============================================================

function TestMenuHitTest.testHitItemHorizontal()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    -- 横向：3 项，宽 300 → 每项 100
    local m = makeMenu({ num = 3, total = 3, w = 300, isHorizontal = true })

    TestHelper.assertEquals(1, MSM.hitItem(m, 120, 60), "第 1 列")
    TestHelper.assertEquals(2, MSM.hitItem(m, 220, 60), "第 2 列")
    TestHelper.assertEquals(3, MSM.hitItem(m, 320, 60), "第 3 列")
    restoreStubs(saved)
end

-- ============================================================
-- hitValueLine：值项三行
-- ============================================================

function TestMenuHitTest.testHitValueLine()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu({ num = 1, total = 1, h = 28 * 3 + 5 })

    -- 值项占 3 行：▲ [55,83) / 值 [83,111) / ▼ [111,139)
    TestHelper.assertEquals(1, MSM.hitValueLine(m, 1, 150, 60), "第 1 行 = ▲")
    TestHelper.assertEquals(2, MSM.hitValueLine(m, 1, 150, 90), "第 2 行 = 值")
    TestHelper.assertEquals(3, MSM.hitValueLine(m, 1, 150, 118), "第 3 行 = ▼")
    restoreStubs(saved)
end

function TestMenuHitTest.testHitValueLineOutOfRange()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu({ num = 1, total = 1, h = 28 * 3 + 5 })
    TestHelper.assertEquals(nil, MSM.hitValueLine(m, 1, 150, 200),
        "超出三行范围 → nil")
    restoreStubs(saved)
end

-- ============================================================
-- 共用公式一致性（draw 与 hitItem 必须同一套行高）
-- ============================================================

function TestMenuHitTest.testRowYMatchesDrawFormula()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu({ start = 3, num = 4, total = 10 })

    -- rowY(menu, i) = y1 + pad + (i - start) * (size + RowPixel)
    for i = 3, 6 do
        local expected = 50 + 5 + (i - 3) * (24 + 4)
        TestHelper.assertEquals(expected, MSM._rowY(m, i),
            "rowY(" .. i .. ") 与 draw 公式一致")
    end
    restoreStubs(saved)
end

-- ============================================================
-- 多行值项与普通项混排（实测踩到的缺陷）
-- ============================================================

function TestMenuHitTest.testValueItemOccupiesThreeRows()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")

    -- 第 1 项是普通项（1 行），第 2 项是值项（3 行），第 3 项普通项（1 行）
    -- 布局（y1=50, pad=5, rh=28）：
    --   项1 [55, 83)
    --   项2 [83, 167)    ← 3 行
    --   项3 [167, 195)
    local m = makeMenu({ num = 3, total = 3, h = 28 * 5 + 5, valueRowsAt = 2 })

    TestHelper.assertEquals(1, MSM.hitItem(m, 150, 60), "项 1（1 行）")
    TestHelper.assertEquals(2, MSM.hitItem(m, 150, 90), "项 2 第 1 行（▲）")
    TestHelper.assertEquals(2, MSM.hitItem(m, 150, 118), "项 2 第 2 行（值）")
    TestHelper.assertEquals(2, MSM.hitItem(m, 150, 146), "项 2 第 3 行（▼）")
    TestHelper.assertEquals(3, MSM.hitItem(m, 150, 174), "项 3（值项之后）")
    restoreStubs(saved)
end

function TestMenuHitTest.testValueItemLineMapping()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu({ num = 3, total = 3, h = 28 * 5 + 5, valueRowsAt = 2 })

    TestHelper.assertEquals(1, MSM.hitValueLine(m, 2, 150, 90), "▲ 行 = 1")
    TestHelper.assertEquals(2, MSM.hitValueLine(m, 2, 150, 118), "值行 = 2")
    TestHelper.assertEquals(3, MSM.hitValueLine(m, 2, 150, 146), "▼ 行 = 3")
    restoreStubs(saved)
end

function TestMenuHitTest.testValueItemNotFirstItemNegativeControl()
    -- 负向对照：若 hitItem 一律按每项 1 行算，值项的第 3 行会落到项 3 上
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local m = makeMenu({ num = 3, total = 3, h = 28 * 5 + 5, valueRowsAt = 2 })

    local hit = MSM.hitItem(m, 150, 146)   -- 值项 ▼ 行
    TestHelper.assertEquals(2, hit,
        "值项 ▼ 行必须命中项 2，不能因按 1 行算而落到项 3")
    restoreStubs(saved)
end

function TestMenuHitTest.runAll()
    print("\n" .. string.rep("=", 60))
    print("菜单鼠标命中测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestMenuHitTest.testHitMenuInside()
    TestMenuHitTest.testHitMenuOutside()

    TestMenuHitTest.testHitItemVertical()
    TestMenuHitTest.testHitItemOutsideReturnsNil()
    TestMenuHitTest.testHitItemBlankAreaReturnsNil()

    TestMenuHitTest.testHitItemWithScrollOffset()
    TestMenuHitTest.testScrollOffsetNegativeControl()

    TestMenuHitTest.testHitItemHorizontal()
    TestMenuHitTest.testHitValueLine()
    TestMenuHitTest.testHitValueLineOutOfRange()

    TestMenuHitTest.testValueItemOccupiesThreeRows()
    TestMenuHitTest.testValueItemLineMapping()
    TestMenuHitTest.testValueItemNotFirstItemNegativeControl()
    TestMenuHitTest.testRowYMatchesDrawFormula()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_menu_hit_test.lua$") then
    TestMenuHitTest.runAll()
end

return TestMenuHitTest
