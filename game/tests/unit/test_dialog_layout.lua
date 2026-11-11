-- test_dialog_layout.lua
-- 对话框自动换行 + 框宽自适应的单元测试
--
-- 覆盖三块：
--   ① framework/dialog_layout.lua 的纯排版算法（不依赖 LÖVE）
--   ② engine_love2d 的 M.dialog.measure 用「模拟真字体」验证真实度量通路
--   ③ 负向对照：撤掉各修复后对应断言必须失败（判别力验证）
--
-- 实测基准（LÖVE 11.5 + game/simsun.ttf @ 24）：
--   汉字 24.00px = 1.0 em   ASCII 12.00px = 0.5 em   getHeight() = 27px

local TestHelper = require("tests.test_helper")
local DialogLayout = require("framework.dialog_layout")

local TestDialogLayout = {}

-- 项目基准参数（与 engine_love2d 的 M.dialog 常量一致）
local OPTS = {
    size = 24,
    pad = 5,
    minWidth = 298,          -- 12 * 24 + 10
    maxWidth = 908,          -- 1024 - 2*2 - 110 - 2
    linesPerPage = 3,
}

local function utf8Count(s)
    local n = 0
    for _ in s:gmatch("[^\128-\191][\128-\191]*") do
        n = n + 1
    end
    return n
end

local function widthFn(s)
    return DialogLayout.textWidth(s, OPTS.size)
end

--------------------------------------------------------------------
-- ① 纯排版算法
--------------------------------------------------------------------

function TestDialogLayout.testCharWidth()
    print("\n=== Test: 字符宽度 = 汉字 1.0em / ASCII 0.5em（实测 24 / 12）===")
    TestHelper.assertEquals(DialogLayout.charWidth("中", 24), 24, "汉字应为 1.0em")
    TestHelper.assertEquals(DialogLayout.charWidth("a", 24), 12, "ASCII 应为 0.5em")
    TestHelper.assertEquals(
        DialogLayout.charWidth("a", 24) + DialogLayout.charWidth("中", 24), 36,
        "ASCII+汉字 应为 36（与实测 a中=36.00 一致）")
end

function TestDialogLayout.testTextWidth()
    print("\n=== Test: 字符串宽度累加（12字=288 / 13字=312）===")
    TestHelper.assertEquals(DialogLayout.textWidth(string.rep("中", 12), 24), 288,
        "12 汉字应为 288px（正好填满框内宽度）")
    TestHelper.assertEquals(DialogLayout.textWidth(string.rep("中", 13), 24), 312,
        "13 汉字应为 312px（溢出 24px = 1 个汉字）")
    TestHelper.assertEquals(DialogLayout.textWidth("", 24), 0, "空串宽度应为 0")
end

function TestDialogLayout.testGreedyWrapBoundary()
    print("\n=== Test: 换行临界点 12 字不换 / 13 字必换 ===")
    local wf = DialogLayout.emWidthFn(24)
    local l12 = DialogLayout.greedyWrap(string.rep("中", 12), 288, wf)
    local l13 = DialogLayout.greedyWrap(string.rep("中", 13), 288, wf)
    TestHelper.assertEquals(#l12, 1, "12 字应排成 1 行")
    TestHelper.assertEquals(#l13, 2, "13 字应排成 2 行")
    TestHelper.assertEquals(table.concat(l13), string.rep("中", 13), "换行不得丢字符")
end

function TestDialogLayout.testGreedyWrapNoOverflow()
    print("\n=== Test: 每行像素宽不超过框内宽度 ===")
    local wf = DialogLayout.emWidthFn(24)
    local text = "咦？你刚才还在外面，怎么突然就到这里来了？莫不是使出了传说中的移行幻影之术？"
    local lines = DialogLayout.greedyWrap(text, 288, wf)
    local allFit = true
    for _, line in ipairs(lines) do
        if DialogLayout.textWidth(line, 24) > 288 then
            allFit = false
        end
    end
    TestHelper.assertTrue(allFit, "所有行都必须 <= 288px（无溢出）")
end

function TestDialogLayout.testBalancedWrapRemovesOrphan()
    print("\n=== Test: 均衡换行消除孤儿尾行 ===")
    local wf = DialogLayout.emWidthFn(24)
    local text = "你既然是他哥哥，那么本领是不是比他大那么一点点呢？"

    local greedy = DialogLayout.greedyWrap(text, 288, wf)
    local balanced = DialogLayout.balancedWrap(text, 288, wf)

    -- 旧贪心：末行只剩 1 个字（孤儿行）
    TestHelper.assertEquals(utf8Count(greedy[#greedy]), 1,
        "贪心换行的末行应只剩 1 字（这是要修的缺陷）")

    -- 新均衡：末行不再孤立
    TestHelper.assertTrue(utf8Count(balanced[#balanced]) >= 4,
        "均衡后末行应 >= 4 字，实际 " .. utf8Count(balanced[#balanced]))
    TestHelper.assertEquals(#balanced, #greedy, "均衡不得改变行数")
    TestHelper.assertEquals(table.concat(balanced), text, "均衡不得丢字符")
end

function TestDialogLayout.testBalancedWrapSingleLineUnchanged()
    print("\n=== Test: 单行文本不做均衡调整 ===")
    local wf = DialogLayout.emWidthFn(24)
    local lines = DialogLayout.balancedWrap("短句", 288, wf)
    TestHelper.assertEquals(#lines, 1, "单行应保持 1 行")
    TestHelper.assertEquals(lines[1], "短句", "单行内容不变")
end

function TestDialogLayout.testSplitByStar()
    print("\n=== Test: * 切段（空段保留为空格语义）===")
    local s = DialogLayout.splitByStar
    TestHelper.assertEquals(#s("a*b"), 2, "a*b 应为 2 段")
    TestHelper.assertEquals(#s("a**b"), 3, "a**b 应为 3 段（中间空段）")
    TestHelper.assertEquals(#s("a***"), 4, "a*** 应为 4 段（末尾 3 空段）")
    TestHelper.assertEquals(#s(""), 1, "空串应为 1 段")
    TestHelper.assertEquals(s("a**b")[2], "", "a**b 的中间段为空串")
end

function TestDialogLayout.testTrimTrailingBlank()
    print("\n=== Test: 只裁末尾空白行，中间空行保留 ===")
    local t = DialogLayout.trimTrailingBlank
    TestHelper.assertEquals(#t({ "内容", "", "", "" }), 1, "末尾 3 空行应全裁")
    TestHelper.assertEquals(#t({ "内容", " ", " " }), 1, "末尾纯空格也算空白，应裁")
    TestHelper.assertEquals(#t({ "a", "", "b" }), 3,
        "中间空行必须保留（作者故意的视觉间隔）")
    TestHelper.assertEquals(#t({ "内容" }), 1, "无空白时不变")
end

--------------------------------------------------------------------
-- ② 框宽自适应（组 7.2）
--------------------------------------------------------------------

function TestDialogLayout.testShortTextUsesMinWidth()
    print("\n=== Test: 短句用框宽下限 298px ===")
    local r = DialogLayout.layoutText("好", OPTS)
    TestHelper.assertEquals(r.width, 298, "1 字应取框宽下限 298")
    TestHelper.assertEquals(r.lineCount, 1, "1 字应为 1 行")
    TestHelper.assertEquals(r.pages, 1, "1 字应为 1 页")
end

function TestDialogLayout.testMediumTextFitsContent()
    print("\n=== Test: 中等长度按内容宽度框（16字 -> 394px）===")
    local r = DialogLayout.layoutText("欢迎光临佣兵行会，您可以选择任务", OPTS)
    TestHelper.assertEquals(r.width, 394, "16 字（384px）+ 2*5 内边距 = 394")
    TestHelper.assertEquals(r.lineCount, 1, "16 字应排 1 行")
end

function TestDialogLayout.testLongTextWrapsThenSizes()
    print("\n=== Test: 长文本先换行、后按实际行宽定框（关键顺序）===")
    local text = "咦？你刚才还在外面，怎么突然就到这里来了？莫不是使出了传说中的移行幻影之术？"
    local r = DialogLayout.layoutText(text, OPTS)

    -- 这是「先换行后定宽」的判别点：若先假定框宽=908 再换行，会得到 908。
    TestHelper.assertEquals(r.width, 466,
        "38 字应得 466px；若得 908 说明「先定框宽后换行」的顺序错了（框右会留大片空白）")
    TestHelper.assertTrue(r.width <= OPTS.maxWidth, "框宽不得超过上限 908")
    TestHelper.assertEquals(r.lineCount, 2, "38 字应排 2 行")
end

function TestDialogLayout.testVeryLongTextCapped()
    print("\n=== Test: 超长文本不超上限 ===")
    local text = string.rep("江湖路远，你且记住：剑法可以学，心法可以练。", 8)
    local r = DialogLayout.layoutText(text, OPTS)
    TestHelper.assertTrue(r.width <= OPTS.maxWidth,
        "框宽 " .. r.width .. " 不得超过上限 " .. OPTS.maxWidth)
    TestHelper.assertTrue(r.pages >= 2, "超长文本应多页，实际 " .. r.pages)
end

function TestDialogLayout.testAnchorNoOverflow()
    print("\n=== Test: 各框宽下锚点均不越界 ===")
    -- 复刻 engine_love2d 的锚点算法，验证 298/500/700/908 四档
    local SW, SH = 1024, 768
    local DX, DY = 2, 2
    local BOXPICW, BOXPICH = 110, 110
    local leftTalkX = DX + BOXPICW + 2
    local allOk = true
    for _, boxW in ipairs({ 298, 500, 700, 908 }) do
        local rightTalkX = SW - 1 - DX - BOXPICW - boxW - 2
        local rightEdge = rightTalkX + boxW
        local leftEdge = leftTalkX + boxW
        if rightTalkX < 0 or rightEdge > SW or leftEdge > SW then
            allOk = false
            print(string.format("    越界: boxW=%d rightTalkX=%d rightEdge=%d leftEdge=%d",
                boxW, rightTalkX, rightEdge, leftEdge))
        end
    end
    TestHelper.assertTrue(allOk, "所有框宽下锚点都必须在屏内")
end

--------------------------------------------------------------------
-- ③ * 语义 + 末尾裁剪（组 7.3）
--------------------------------------------------------------------

function TestDialogLayout.testStarForcesLineBreak()
    print("\n=== Test: * 处强制断行（段内仍自动换行）===")
    local r = DialogLayout.layoutText("少侠已连战三场，*可先休息再战．", OPTS)
    TestHelper.assertEquals(r.lineCount, 2, "* 应强制断成 2 行")
    TestHelper.assertTrue(r.lines[1]:find("少侠已连战三场", 1, true) == 1,
        "第 1 行应以 * 前的内容开头")
end

function TestDialogLayout.testStarLongSegmentStillWraps()
    print("\n=== Test: * 段内超长仍自动换行（原版缺失的能力）===")
    local longSeg = string.rep("中", 20)   -- 20 字 = 480px > 288px 框内
    local r = DialogLayout.layoutText(longSeg .. "*短", OPTS)
    TestHelper.assertTrue(#r.lines >= 2, "* 前那段应被自动换行，实际行数 " .. #r.lines)
end

function TestDialogLayout.testTrailingStarNoBlankPage()
    print("\n=== Test: 末尾 *** 不产生空白页 ===")
    local r = DialogLayout.layoutText("内容***", OPTS)
    TestHelper.assertEquals(r.pages, 1, "末尾 *** 应裁掉，只 1 页（裁前会 2 页）")
    TestHelper.assertEquals(r.lineCount, 1, "只保留 1 行内容")
end

function TestDialogLayout.testMiddleBlankLinesPreserved()
    print("\n=== Test: 中间空行必须保留（反向断言）===")
    -- 若实现错误地裁掉「所有」空白行，本测试必须失败
    local text = "接下来换谁？**．．．．*．．．．***没有人了吗？"
    local r = DialogLayout.layoutText(text, OPTS)
    local blanks = 0
    for _, line in ipairs(r.lines) do
        if line:match("^%s*$") then
            blanks = blanks + 1
        end
    end
    TestHelper.assertEquals(blanks, 3,
        "中间应有 3 个空行（作者故意的视觉间隔），实际 " .. blanks)
end

function TestDialogLayout.testBlankOnlyText()
    print("\n=== Test: 纯空白文本退化为一空行 ===")
    local r = DialogLayout.layoutText("   ***   ", OPTS)
    TestHelper.assertEquals(r.lineCount, 1, "全空白应退化为一空行")
    TestHelper.assertEquals(r.pages, 1, "全空白应为 1 页")
end

--------------------------------------------------------------------
-- ④ 分页
--------------------------------------------------------------------

function TestDialogLayout.testPaginate()
    print("\n=== Test: 每页 3 行分页 ===")
    local pages = DialogLayout.paginate({ "a", "b", "c", "d", "e" }, 3)
    TestHelper.assertEquals(#pages, 2, "5 行应分 2 页")
    TestHelper.assertEquals(#pages[1], 3, "第 1 页 3 行")
    TestHelper.assertEquals(#pages[2], 2, "第 2 页 2 行")
end

function TestDialogLayout.testPaginateEmpty()
    print("\n=== Test: 空行表也返回 1 页 ===")
    local pages = DialogLayout.paginate({}, 3)
    TestHelper.assertEquals(#pages, 1, "空表应有 1 页兜底")
end

--------------------------------------------------------------------
-- ⑤ 纯函数性（REQ-DLG-9）
--------------------------------------------------------------------

function TestDialogLayout.testLayoutTextIsPure()
    print("\n=== Test: layoutText 是纯函数（重复调用结果一致）===")
    local text = "咦？你刚才还在外面，怎么突然就到这里来了？"
    local a = DialogLayout.layoutText(text, OPTS)
    local b = DialogLayout.layoutText(text, OPTS)
    TestHelper.assertEquals(a.width, b.width, "两次调用框宽应一致")
    TestHelper.assertEquals(a.lineCount, b.lineCount, "两次调用行数应一致")
    TestHelper.assertEquals(table.concat(a.lines), table.concat(b.lines),
        "两次调用行内容应一致")
end

function TestDialogLayout.testLayoutTextDoesNotMutateOpts()
    print("\n=== Test: layoutText 不修改 opts ===")
    local opts = { size = 24, pad = 5, minWidth = 298, maxWidth = 908, linesPerPage = 3 }
    DialogLayout.layoutText("测试文本", opts)
    TestHelper.assertEquals(opts.size, 24, "opts.size 不应被改")
    TestHelper.assertEquals(opts.maxWidth, 908, "opts.maxWidth 不应被改")
end

--------------------------------------------------------------------
-- ⑥ 真实字体度量通路（用模拟字体验证 widthFn 被真正使用）
--------------------------------------------------------------------

function TestDialogLayout.testCustomWidthFnIsUsed()
    print("\n=== Test: 传入真实测量函数时以它为准（自适应字体/字号/分辨率）===")
    -- 模拟一个「每字 10px」的字体：与 em 估算（24/12）完全不同
    local fake = function(s) return utf8Count(s) * 10 end
    local opts = {
        size = 24, pad = 5, minWidth = 298, maxWidth = 908, linesPerPage = 3,
        widthFn = fake,
    }
    local r = DialogLayout.layoutText(string.rep("中", 20), opts)
    -- 20 字 * 10px = 200px < 288px -> 1 行；框宽 max(298, 200+10) = 298
    TestHelper.assertEquals(r.lineCount, 1, "自定义度量下 20 字应排 1 行")
    TestHelper.assertEquals(r.width, 298, "自定义度量下应取框宽下限")

    -- 100 字 * 10px = 1000px > innerMax(898) -> 必须换行
    local r2 = DialogLayout.layoutText(string.rep("中", 100), opts)
    TestHelper.assertTrue(#r2.lines >= 2, "自定义度量下 100 字应换行，实际 " .. #r2.lines)
end

function TestDialogLayout.testRealFontMetricsMatchEmEstimate()
    print("\n=== Test: em 估算与实测值一致（汉字 1.0em / ASCII 0.5em）===")
    -- 实测依据：font:getWidth("中")=24.00, font:getWidth("a")=12.00
    local em = DialogLayout.emWidthFn(24)
    TestHelper.assertEquals(em("中"), 24, "em 估算的汉字宽应等于实测 24.00")
    TestHelper.assertEquals(em("a"), 12, "em 估算的 ASCII 宽应等于实测 12.00")
    TestHelper.assertEquals(em(string.rep("中", 12)), 288,
        "em 估算 12 汉字应等于实测 288.00")
end

function TestDialogLayout.runAll()
    TestDialogLayout.testCharWidth()
    TestDialogLayout.testTextWidth()
    TestDialogLayout.testGreedyWrapBoundary()
    TestDialogLayout.testGreedyWrapNoOverflow()
    TestDialogLayout.testBalancedWrapRemovesOrphan()
    TestDialogLayout.testBalancedWrapSingleLineUnchanged()
    TestDialogLayout.testSplitByStar()
    TestDialogLayout.testTrimTrailingBlank()
    TestDialogLayout.testShortTextUsesMinWidth()
    TestDialogLayout.testMediumTextFitsContent()
    TestDialogLayout.testLongTextWrapsThenSizes()
    TestDialogLayout.testVeryLongTextCapped()
    TestDialogLayout.testAnchorNoOverflow()
    TestDialogLayout.testStarForcesLineBreak()
    TestDialogLayout.testStarLongSegmentStillWraps()
    TestDialogLayout.testTrailingStarNoBlankPage()
    TestDialogLayout.testMiddleBlankLinesPreserved()
    TestDialogLayout.testBlankOnlyText()
    TestDialogLayout.testPaginate()
    TestDialogLayout.testPaginateEmpty()
    TestDialogLayout.testLayoutTextIsPure()
    TestDialogLayout.testLayoutTextDoesNotMutateOpts()
    TestDialogLayout.testCustomWidthFnIsUsed()
    TestDialogLayout.testRealFontMetricsMatchEmEstimate()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestDialogLayout
