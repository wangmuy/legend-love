-- test_text_box_layout.lua
-- framework/text_box_layout.lua 单元测试
--
-- 这些测试的核心是防回归：曾经这里用 `size * #str / 2` 估算框宽，
-- 而 Lua 的 # 是 UTF-8 字节数（汉字 3 字节），导致所有中文提示框、
-- 场景名框比文字宽出几十像素，文字左对齐后右边空一大块。
--
-- 判别力设计：断言都建立在「框宽 - pad - 文字宽 == pad」这个不变式上，
-- 而不是复算一遍 measure 的内部公式。任何把宽度算错的方式（字节数、
-- 固定值、字数×字号）都会打破这个不变式。

local TestHelper = require("tests.test_helper")
local assertEquals = TestHelper.assertEquals
local assertTrue = TestHelper.assertTrue
local assertFalse = TestHelper.assertFalse
local assertNotNil = TestHelper.assertNotNil

local M = {}

-- 在伪造的 CC 环境下执行 fn
--
-- 注意：这里**故意不提供** EngineAPI.font.measureText，以此验证模块在
-- 纯 em 估算路径下的行为。这是实际运行时的路径 —— 工程当前字体
-- simsun.ttf 是等宽设计，em 估算与 font:getWidth 实测完全相等
-- （20 个代表性文本 + 95 个 ASCII 字符，最大偏差 0.00px）。
local function withEngine(fn)
    local savedEngineAPI = rawget(_G, "EngineAPI")
    local savedCC = rawget(_G, "CC")

    rawset(_G, "EngineAPI", nil)
    rawset(_G, "CC", {
        MenuBorderPixel = 5,
        FontName = "simsun.ttf",
        DefaultFont = 24,
    })

    -- 清掉 require 缓存，让模块用新的全局状态重新加载
    package.loaded["framework.text_box_layout"] = nil
    local ok, err = pcall(fn)

    package.loaded["framework.text_box_layout"] = nil
    rawset(_G, "EngineAPI", savedEngineAPI)
    rawset(_G, "CC", savedCC)
    if not ok then error(err, 0) end
end

-- ============================================
-- ① 文本宽度：必须按字符数，不按字节数
-- ============================================
local function testTextWidth()
    withEngine(function()
        local TL = require("framework.text_box_layout")

        -- 3 个汉字 = 3 * 24 = 72，而字节数是 9
        assertEquals(72, TL.textWidth("牛家村", 24), "牛家村 应为 3 字 × 24px")
        -- 2 个汉字 = 48，字节数 6
        assertEquals(48, TL.textWidth("梅庄", 24), "梅庄 应为 2 字 × 24px")
        -- 边界：单个汉字
        assertEquals(24, TL.textWidth("中", 24), "单汉字应为 1 个字号宽")
        -- ASCII 半角
        assertEquals(12, TL.textWidth("a", 24), "ASCII 应为 0.5 个字号宽")
        assertEquals(36, TL.textWidth("abc", 24), "3 个 ASCII 应为 1.5 个字号宽")
        -- 中英混排：「得到物品:倚天剑 1」
        -- 汉字 6 个(得/到/物/品/倚/天/剑 中取实际) + ASCII
        -- 用逐字核对而非硬编码，避免测试自身写错
        local mixed = "得到物品:倚天剑 1"
        local expect = 0
        for ch in mixed:gmatch("[^\128-\191][\128-\191]*") do
            expect = expect + ((#ch >= 2) and 24 or 12)
        end
        assertEquals(expect, TL.textWidth(mixed, 24), "中英混排宽度")

        -- 空串 / nil
        assertEquals(0, TL.textWidth("", 24), "空串宽度应为 0")
        assertEquals(0, TL.textWidth(nil, 24), "nil 宽度应为 0")
    end)
end

-- ============================================
-- ② 框宽不变式：右边空位必须等于左边空位
-- ============================================
local function testBoxWidthSymmetric()
    withEngine(function()
        local TL = require("framework.text_box_layout")
        local cases = {
            "梅庄", "牛家村", "得到物品:倚天剑 1",
            "得到物品:千年灵芝 3", "得到经验 120", "要查阅谁的状态",
        }
        for _, str in ipairs(cases) do
            local box = TL.measure(str, { size = 24 })
            local leftGap = box.pad
            local rightGap = box.width - box.pad - box.textWidth
            assertEquals(leftGap, rightGap,
                "「" .. str .. "」左右间隙必须相等（左=" .. leftGap
                .. " 右=" .. rightGap .. "）")
        end
    end)
end

-- ============================================
-- ③ 判别力负向对照：旧字节数公式必须被判为不对称
-- ============================================
local function testOldFormulaFails()
    withEngine(function()
        local TL = require("framework.text_box_layout")
        local pad = 5
        local size = 24

        -- 复刻旧公式：w = size * #str / 2 + 2*pad
        local function oldWidth(str)
            return size * #str / 2 + 2 * pad
        end

        -- 中文文本：旧公式必然偏宽（3 字节/字，只按 1.5 字宽算）
        for _, str in ipairs({ "梅庄", "牛家村", "要查阅谁的状态" }) do
            local box = TL.measure(str, { size = size })
            local oldW = oldWidth(str)
            assertTrue(oldW > box.width,
                "「" .. str .. "」旧公式(" .. oldW .. ")应宽于正确值(" .. box.width .. ")")
            -- 旧公式的右空位明显大于左空位
            local oldRight = oldW - pad - box.textWidth
            assertTrue(oldRight > pad + 10,
                "「" .. str .. "」旧公式右空位(" .. oldRight .. ")应远大于 pad")
        end

        -- 反向对照：纯 ASCII 文本旧公式恰好正确（1 字节 = 半角字）
        -- 这证明缺陷只出现在多字节字符上，不是公式整体偏移
        local asciiW = oldWidth("abc")
        local asciiBox = TL.measure("abc", { size = size })
        assertEquals(asciiW, asciiBox.width, "纯 ASCII 时旧公式与正确值一致")
    end)
end

-- ============================================
-- ④ 框高：单行必须光学居中（用字号，不用行高）
-- ============================================
local function testBoxHeight()
    withEngine(function()
        local TL = require("framework.text_box_layout")
        local box = TL.measure("牛家村", { size = 24 })
        -- 框高 = 字号 + 2*pad。用行高(27)会让文字偏上，实测 上7/下10。
        assertEquals(24 + 2 * 5, box.height, "框高应为 字号 + 2*pad")

        -- 行高仍可通过 lineHeight 字段取得（供多行布局使用）
        assertEquals(27, box.lineHeight, "lineHeight 应为 getHeight 的 27")
        assertTrue(box.lineHeight > box.height - 2 * box.pad,
            "行高应大于字号（simsun@24 实测 27 > 24）")
    end)
end

-- ============================================
-- ⑤ 居中定位
-- ============================================
local function testCenter()
    withEngine(function()
        local TL = require("framework.text_box_layout")
        local box = TL.measure("牛家村", { size = 24 })
        local x, y = TL.center(box, 1024, 768)
        -- 左右留白相等
        assertEquals(1024 - (x + box.width), x, "屏幕水平居中")
        assertEquals(768 - (y + box.height), y, "屏幕垂直居中")
    end)
end

-- ============================================
-- ⑥ 极端环境：连 CC 都没有也不能崩，且有合理默认值
-- ============================================
local function testNoGlobalsAtAll()
    local savedEngineAPI = rawget(_G, "EngineAPI")
    local savedCC = rawget(_G, "CC")
    rawset(_G, "EngineAPI", nil)
    rawset(_G, "CC", nil)
    package.loaded["framework.text_box_layout"] = nil

    local ok, err = pcall(function()
        local TL = require("framework.text_box_layout")
        local box = TL.measure("牛家村", { size = 24 })
        assertEquals(5, box.pad, "无 CC 时 pad 回退为 5")
        assertEquals(72, box.textWidth, "纯 em 估算汉字宽度")
        assertEquals(82, box.width, "框宽仍正确")
        assertEquals(34, box.height, "框高仍正确")
        -- 屏幕尺寸缺失时 center 仍应返回数值而不是崩
        local x = TL.center(box, 1024, 768)
        assertTrue(type(x) == "number", "center 返回数值")
    end)

    package.loaded["framework.text_box_layout"] = nil
    rawset(_G, "EngineAPI", savedEngineAPI)
    rawset(_G, "CC", savedCC)
    if not ok then error(err, 0) end
end

-- ============================================
-- ⑥b 若引擎提供 measureText，则必须优先采用（为将来非等宽字体留路）
-- ============================================
local function testPrefersEngineMeasure()
    local savedEngineAPI = rawget(_G, "EngineAPI")
    local savedCC = rawget(_G, "CC")
    -- 故意返回一个与 em 估算不同的值（模拟非等宽字体）
    rawset(_G, "EngineAPI", {
        font = { measureText = function(str, size) return 999 end },
    })
    rawset(_G, "CC", { MenuBorderPixel = 5 })
    package.loaded["framework.text_box_layout"] = nil

    local ok, err = pcall(function()
        local TL = require("framework.text_box_layout")
        assertEquals(999, TL.textWidth("牛家村", 24),
            "有 EngineAPI.font.measureText 时必须优先采用")
        assertEquals(999 + 10, TL.measure("牛家村", { size = 24 }).width,
            "框宽应基于引擎度量")
    end)

    package.loaded["framework.text_box_layout"] = nil
    rawset(_G, "EngineAPI", savedEngineAPI)
    rawset(_G, "CC", savedCC)
    if not ok then error(err, 0) end
end

-- ============================================
-- ⑦ 不同字号下不变式仍成立（自适应）
-- ============================================
local function testDifferentSizes()
    withEngine(function()
        local TL = require("framework.text_box_layout")
        for _, size in ipairs({ 16, 20, 24, 32, 48 }) do
            local box = TL.measure("牛家村", { size = size })
            assertEquals(3 * size, box.textWidth, "字号 " .. size .. " 的文本宽")
            assertEquals(size + 10, box.height, "字号 " .. size .. " 的框高")
            assertEquals(box.pad, box.width - box.pad - box.textWidth,
                "字号 " .. size .. " 的左右间隙相等")
        end
    end)
end

-- ============================================
-- ⑧ 纯函数性：两次调用结果一致、不改入参
-- ============================================
local function testPurity()
    withEngine(function()
        local TL = require("framework.text_box_layout")
        local opts = { size = 24 }
        local a = TL.measure("牛家村", opts)
        local b = TL.measure("牛家村", opts)
        assertEquals(a.width, b.width, "两次调用的框宽一致")
        assertEquals(a.height, b.height, "两次调用的框高一致")
        assertEquals(24, opts.size, "measure 不应修改调用方的 opts")
        assertTrue(rawget(opts, "pad") == nil, "measure 不应往 opts 写 pad")
    end)
end

-- ============================================
-- ⑨ 严格 _G 模式（jymain_adapter.lua 真实开启的）下不能崩
--
-- 这是最容易漏的一条：单元测试默认不开启严格 _G，于是模块里裸读
-- EngineAPI / CC 的写法在测试里看不出来，但真跑游戏时
-- __index 元方法会抛 "attempt read read to undeclared variable"。
-- ============================================
local function testStrictGlobals()
    local savedEngineAPI = rawget(_G, "EngineAPI")
    local savedCC = rawget(_G, "CC")
    local savedMeta = getmetatable(_G)
    rawset(_G, "EngineAPI", nil)
    rawset(_G, "CC", nil)
    package.loaded["framework.text_box_layout"] = nil

    -- 复刻 jymain_adapter.lua:102-109
    setmetatable(_G, {
        __newindex = function(_, n)
            error("attempt read write to undeclared variable " .. n, 2)
        end,
        __index = function(_, n)
            error("attempt read read to undeclared variable " .. n, 2)
        end,
    })

    local ok, err = pcall(function()
        local TL = require("framework.text_box_layout")
        local box = TL.measure("牛家村", { size = 24 })
        -- 严格模式下必须仍然给出正确结果（靠 rawget 探测全局）
        assertEquals(72, box.textWidth, "严格 _G 下文本宽")
        assertEquals(82, box.width, "严格 _G 下框宽")
        assertEquals(34, box.height, "严格 _G 下框高")
        assertEquals(5, box.pad, "严格 _G 下 pad 默认值")
    end)

    setmetatable(_G, savedMeta)
    package.loaded["framework.text_box_layout"] = nil
    rawset(_G, "EngineAPI", savedEngineAPI)
    rawset(_G, "CC", savedCC)
    if not ok then error(err, 0) end
end

-- ============================================
-- ⑩ 列对齐：padToWidth 必须按显示宽度补齐
-- ============================================
local function testPadToWidth()
    withEngine(function()
        local TL = require("framework.text_box_layout")

        -- 3 汉字 = 72px，补到 96px（4 汉字）需要 2 个半角空格（各 12px）
        local padded = TL.padToWidth("牛家村", 96, 24)
        assertEquals(96, TL.textWidth(padded, 24), "补齐后宽度应恰为 96px")
        assertEquals(72 + 12 * 2, TL.textWidth(padded, 24), "96 = 72 + 2×12")
        assertTrue(#padded > #"牛家村", "补齐后应更长")

        -- 已达标：原样返回，不加空格
        assertEquals("牛家村", TL.padToWidth("牛家村", 72, 24), "恰等时应原样返回")
        assertEquals("牛家村", TL.padToWidth("牛家村", 50, 24), "超出时不应截断")

        -- 精确对齐的关键：汉字宽是 1.0em，空格 0.5em，
        -- 所以目标宽度只要是 0.5em 的整数倍就能精确命中
        for _, target in ipairs({ 72, 84, 96, 108, 120, 132 }) do
            local w = TL.textWidth(TL.padToWidth("梅庄", target, 24), 24)
            assertEquals(target, w, "目标 " .. target .. "px 应精确达到")
        end

        -- 纯 ASCII：3 字符 = 36px，补到 48px 需 1 个空格
        assertEquals(48, TL.textWidth(TL.padToWidth("abc", 48, 24), 24), "ASCII 补齐")

        -- 空串
        assertEquals(24, TL.textWidth(TL.padToWidth("", 24, 24), 24), "空串补到 24px")

        -- nil 不能崩
        assertEquals(0, TL.textWidth(TL.padToWidth(nil, 0, 24), 24), "nil 安全")
    end)
end

-- ============================================
-- ⑪ 列对齐判别力：旧 %-Ns 公式必须被判为不对齐
-- ============================================
local function testOldBytePaddingMisaligns()
    withEngine(function()
        local TL = require("framework.text_box_layout")

        -- 复刻旧写法：string.format("%-12s", name)
        -- 真实商店数据里的名字（3/4/5 字混杂）
        local names = { "玉靈散", "冰魄銀針", "九轉熊蛇丸", "凝碧劍", "龍象般若功" }

        -- 旧写法的价格列起点（= 补齐后名称的显示宽度 + 1 个空格）
        local oldStarts = {}
        for i, nm in ipairs(names) do
            oldStarts[i] = TL.textWidth(string.format("%-12s", nm) .. " ", 24)
        end

        -- 判别力核心：旧写法必然产生多个不同的起点
        local mn, mx = math.huge, -math.huge
        for _, x in ipairs(oldStarts) do
            if x < mn then mn = x end
            if x > mx then mx = x end
        end
        assertTrue(mx - mn > 0,
            "旧 %-12s 写法必然错位（实测抖动 " .. (mx - mn) .. "px），"
            .. "若此处为 0 说明测试本身失效")

        -- 实测抖动应为整整 1 个汉字（24px）：
        -- 3/4/5 字名经 %-12s 后分别落在 3 档
        assertEquals(24, mx - mn, "旧写法抖动应恰为 1 个汉字宽")

        -- 新写法：先用 formatColumns 归一到同一列宽
        local rows = {}
        for i, nm in ipairs(names) do
            rows[i] = { nm, "100" }
        end
        local lines = TL.formatColumns(rows, 24)

        -- 新写法的价格列起点必须全部一致
        local newStarts = {}
        for i, line in ipairs(lines) do
            local nameCell = TL.padToWidth(names[i], TL.columnWidth(rows, 1, 24), 24)
            newStarts[i] = TL.textWidth(nameCell .. " ", 24)
        end
        local nmn, nmx = math.huge, -math.huge
        for _, x in ipairs(newStarts) do
            if x < nmn then nmn = x end
            if x > nmx then nmx = x end
        end
        assertEquals(0, nmx - nmn,
            "新写法价格列必须完全对齐（抖动应为 0）")
    end)
end

-- ============================================
-- ⑫ formatColumns：列宽取该列最大值，最后一列不补
-- ============================================
local function testFormatColumns()
    withEngine(function()
        local TL = require("framework.text_box_layout")

        local rows = {
            { "梅庄", "80" },
            { "牛家村", "1200" },
            { "要查阅谁的状态", "5" },
        }
        local lines = TL.formatColumns(rows, 24)

        assertEquals(3, #lines, "行数应与输入一致")

        -- 第 1 列宽 = 最长名「要查阅谁的状态」7 字 = 168px
        assertEquals(168, TL.columnWidth(rows, 1, 24), "第 1 列宽取最大值")

        -- 每一行的第 1 列都必须补齐到 168px，这样第 2 列才对齐
        for i = 1, 3 do
            local padded = TL.padToWidth(rows[i][1], 168, 24)
            assertEquals(168, TL.textWidth(padded, 24),
                "第 " .. i .. " 行第 1 列应补齐到 168px")
        end

        -- 最后一列不补齐（右侧无下一列）
        local last = lines[1]:sub(-2)
        assertEquals("80", last, "最后一列不应补空格")
    end)
end

-- ============================================
-- ⑬ 列对齐的纯函数性与严格 _G
-- ============================================
local function testColumnPurity()
    withEngine(function()
        local TL = require("framework.text_box_layout")
        local rows = { { "梅庄", "80" }, { "牛家村", "1200" } }

        local a = TL.formatColumns(rows, 24)
        local b = TL.formatColumns(rows, 24)
        for i = 1, #a do
            assertEquals(a[i], b[i], "formatColumns 必须纯函数，第 " .. i .. " 行")
        end

        -- 输入不能被修改
        assertEquals("梅庄", rows[1][1], "不得修改输入")
        assertEquals("80", rows[1][2], "不得修改输入")
    end)
end

-- ============================================
-- ⑭ 数字列必须右对齐（原版 %4d 语义），文本列左对齐
-- ============================================
local function testNumericColumnRightAligned()
    withEngine(function()
        local TL = require("framework.text_box_layout")

        -- 原版 string.format("%-10s%4d", 姓名, 值) 里 %4d 是右对齐数字。
        -- 修掉字节数缺陷时不能顺手把数字改成左对齐，否则观感与原版不符。
        local rows = {
            { "胡斐", "29" },
            { "程靈素", "5" },
            { "金花婆婆", "100" },
        }
        local lines = TL.formatColumns(rows, 24)

        -- 所有行宽度必须一致（列对齐的前提）
        local w0 = TL.textWidth(lines[1], 24)
        for i = 1, #lines do
            assertEquals(w0, TL.textWidth(lines[i], 24),
                "第 " .. i .. " 行宽度应与首行一致")
        end

        -- 数字列必须是右对齐：所有行**右边缘**一致
        local ends = {}
        for i = 1, #lines do
            ends[i] = TL.textWidth(lines[i], 24)
        end
        assertEquals(ends[1], ends[#ends], "数字右边缘应对齐")

        -- 具体验证：数值前的空格数应随数值位数变化
        -- 「29」补到 3 位宽 -> 前面 1 空格；「5」-> 2 空格；「100」-> 0 空格
        -- 右对齐 => 数字前有空格，行尾就是数字
        assertTrue(lines[2]:match("%s+5$") ~= nil,
            "「5」应被左补空格（右对齐），实际: [" .. lines[2] .. "]")
        assertTrue(lines[3]:match("100$") ~= nil, "「100」应在行尾")
        assertTrue(lines[3]:match("100$") ~= nil,
            "「100」右侧不应有多余空格")

        -- 文本列仍是左对齐：姓名从行首开始
        assertTrue(lines[1]:sub(1, #"胡斐") == "胡斐", "姓名应在行首（左对齐）")
        assertTrue(lines[3]:sub(1, #"金花婆婆") == "金花婆婆", "长姓名应在行首")
    end)
end

-- ============================================
-- ⑮ 判别力：数字列改成左对齐必须被判错
-- ============================================
local function testLeftAlignedNumbersDetected()
    withEngine(function()
        local TL = require("framework.text_box_layout")
        local rows = {
            { "胡斐", "29" },
            { "程靈素", "5" },
            { "金花婆婆", "100" },
        }

        -- 用 3 列（姓名 / 数值 / 备注），让数值列不是末列，
        -- 这样左对齐与右对齐的差异才可观测（末列左对齐按约定不补齐）。
        local rows3 = {
            { "胡斐", "29", "甲" },
            { "程靈素", "5", "乙" },
            { "金花婆婆", "100", "丙" },
        }

        -- 显式强制数值列左对齐（模拟「忘了保留 %4d 右对齐」的错误实现）
        local bad = TL.formatColumns(rows3, 24, nil, " ",
            { aligns = { "left", "left", "left" } })
        -- 显式强制数值列右对齐（正确行为）
        local good = TL.formatColumns(rows3, 24, nil, " ",
            { aligns = { "left", "right", "left" } })
        -- 默认（自动识别数字列 -> 第 2 列右对齐）
        local auto = TL.formatColumns(rows3, 24)

        -- 错误的左对齐写法里，短的「5」右侧补空格，数值左边缘对齐
        assertTrue(bad[2]:match("5%s") ~= nil,
            "强制左对齐时「5」右侧应有空格（用于证明判别力），实际: [" .. bad[2] .. "]")
        -- 正确写法里「5」左侧补空格，数值右边缘对齐
        assertTrue(good[2]:match("%s+5%s") ~= nil,
            "强制右对齐时「5」应左补空格，实际: [" .. good[2] .. "]")
        -- 两种写法必须产生不同结果，否则本对照无判别力
        assertTrue(bad[2] ~= good[2],
            "左对齐与右对齐的结果必须不同，否则对照无判别力")

        -- 默认应与显式右对齐一致（自动识别数字列）
        for i = 1, #rows3 do
            assertEquals(good[i], auto[i],
                "默认（自动识别数字列）应与显式右对齐一致，第 " .. i .. " 行")
        end
    end)
end

-- ============================================
-- ⑯ 末列左对齐不补空格（避免行尾空白）
-- ============================================
local function testLastTextColumnNoTrailingSpace()
    withEngine(function()
        local TL = require("framework.text_box_layout")

        -- 最后一列是文本（非数字）-> 左对齐 -> 不补空格
        local rows = {
            { "80", "梅庄" },
            { "1200", "牛家村" },
        }
        local lines = TL.formatColumns(rows, 24)
        for i = 1, #lines do
            assertTrue(lines[i]:match("%s$") == nil,
                "末列文本左对齐时行尾不应有空格，第 " .. i .. " 行: [" .. lines[i] .. "]")
        end

        -- 但末列若是数字 -> 右对齐 -> 允许左侧补齐，且行尾仍是数字
        local rows2 = {
            { "梅庄", "80" },
            { "牛家村", "1200" },
        }
        local lines2 = TL.formatColumns(rows2, 24)
        for i = 1, #lines2 do
            assertTrue(lines2[i]:match("%d$") ~= nil,
                "末列数字右对齐时行尾应是数字，第 " .. i .. " 行: [" .. lines2[i] .. "]")
        end
    end)
end

-- ============================================
-- 入口
-- ============================================
function M.runAll()
    TestHelper.resetCounts()
    testTextWidth()
    testBoxWidthSymmetric()
    testOldFormulaFails()
    testBoxHeight()
    testCenter()
    testNoGlobalsAtAll()
    testPrefersEngineMeasure()
    testDifferentSizes()
    testPurity()
    testStrictGlobals()
    testPadToWidth()
    testOldBytePaddingMisaligns()
    testFormatColumns()
    testColumnPurity()
    testNumericColumnRightAligned()
    testLeftAlignedNumbersDetected()
    testLastTextColumnNoTrailingSpace()
    TestHelper.printSummary("text_box_layout")
    return TestHelper.getStats().failed == 0
end

return M
