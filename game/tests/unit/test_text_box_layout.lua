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
    TestHelper.printSummary("text_box_layout")
    return TestHelper.getStats().failed == 0
end

return M
