-- test_engine_conformance.lua
-- 跨引擎**契约一致性**测试（change: port-contract-completeness Task 10）
--
-- 与 test_engine_api 的区别：
--   test_engine_api        只断言"函数存在"（接口层）
--   本文件                 断言"行为一致"（实现层）
--
-- 守的坑（design.md ADR-PORT-007）：
--   现有 test_engine_api 只 require 引擎然后查函数非 nil。
--   MUD/Web 上根本没有行为验证 —— 换引擎时不会有人告诉你实现对不对。
--
--   本文件用**哨兵值约定**替代 skip：
--     MUD/Web 无图形 → getWidth 返回 1024 而不是 nil（调用方无需判 nil）
--   断言哨兵值本身，而不是跳过测试（skip 会让缺陷隐身）。

local TestHelper = require("tests.test_helper")
local TestEngineConformance = {}

-- 契约声明（从 engine_api.lua 读出，不硬编码 —— 避免漏掉新加的函数）
local function readContract()
    local function readSrc(rel)
        for _, p in ipairs({ rel, "game/" .. rel }) do
            local f = io.open(p, "rb")
            if f then local c = f:read("*a"); f:close(); return c end
        end
        return nil
    end
    local src = readSrc("engine-love2d/engine_api.lua")
    if not src then return nil end
    local out = {}
    local ID = "[%a_][%a%d_]*"
    for mod, fn in src:gmatch("function M%." .. "(" .. ID .. ")%.(" .. ID .. ")") do
        out[#out + 1] = { mod = mod, fn = fn }
    end
    return out
end

-- ------------------------------------------------------------ 完整性

function TestEngineConformance.testAllEnginesImplementAllContracts()
    print("\n=== Test: 3 引擎实现全部契约函数 ===")
    local contract = readContract()
    TestHelper.assertNotNil(contract, "应能读到 engine_api.lua")
    TestHelper.assertTrue(#contract >= 70,
        "契约应有 70+ 个函数，实测 " .. #contract)

    local engines = {
        { name = "MUD",  path = "engine-mud.engine_mud" },
        { name = "Web",  path = "engine-web.engine_web" },
        { name = "Test", path = "tests.engine_test" },
    }
    for _, e in ipairs(engines) do
        local ok, mod = pcall(require, e.path)
        TestHelper.assertTrue(ok, e.name .. " 应能加载: " .. tostring(mod))
        if ok and mod then
            local missing = {}
            for _, d in ipairs(contract) do
                if mod[d.mod] == nil or mod[d.mod][d.fn] == nil then
                    missing[#missing + 1] = d.mod .. "." .. d.fn
                end
            end
            TestHelper.assertEquals(0, #missing,
                e.name .. " 缺 " .. #missing .. " 个契约函数"
                .. (#missing > 0 and (": " .. table.concat(missing, ", ")) or ""))
        end
    end
end

-- ------------------------------------------------------------ 哨兵值约定

function TestEngineConformance.testRenderSizeSentinel()
    print("\n=== Test: 无图形引擎的尺寸哨兵值 ===")
    -- MUD / Web 无真实图形，必须返回哨兵而不是 nil
    for _, e in ipairs({
        { name = "MUD", path = "engine-mud.engine_mud" },
        { name = "Web", path = "engine-web.engine_web" },
    }) do
        local ok, mod = pcall(require, e.path)
        if ok and mod and mod.render then
            local w = mod.render.getWidth()
            local h = mod.render.getHeight()
            TestHelper.assertTrue(type(w) == "number",
                e.name .. ".render.getWidth 必须返回 number（不是 nil）")
            TestHelper.assertTrue(type(h) == "number",
                e.name .. ".render.getHeight 必须返回 number（不是 nil）")
            TestHelper.assertTrue(w > 0, e.name .. " getWidth 必须 > 0，实测 " .. tostring(w))
            TestHelper.assertTrue(h > 0, e.name .. " getHeight 必须 > 0，实测 " .. tostring(h))
        end
    end
end

function TestEngineConformance.testFontMeasureSentinel()
    print("\n=== Test: 无字体引擎的 measureText 返回 nil（触发 fallback）===")
    for _, e in ipairs({
        { name = "MUD", path = "engine-mud.engine_mud" },
        { name = "Web", path = "engine-web.engine_web" },
    }) do
        local ok, mod = pcall(require, e.path)
        if ok and mod and mod.font and mod.font.measureText then
            local w = mod.font.measureText("测试", 24)
            TestHelper.assertEquals(nil, w,
                e.name .. " 无字体度量能力时应返回 nil（让 textBoxLayout 走 em 估算）")
        end
    end
end

function TestEngineConformance.testMeasureTextFallbackBehavior()
    print("\n=== Test: measureText 缺失时 textWidth 退回 em 估算 ===")
    local TextBoxLayout = require("framework.text_box_layout")
    -- 无 EngineAPI.font.measureText → 走 em
    local savedEA = rawget(_G, "EngineAPI")
    rawset(_G, "EngineAPI", {})
    local w = TextBoxLayout.textWidth("梅庄", 24)
    rawset(_G, "EngineAPI", savedEA)
    TestHelper.assertEquals(48, w,
        "无 measureText 时「梅庄」应为 2 汉字 × 24 = 48")
end

function TestEngineConformance.testMeasureTextPreferredWhenAvailable()
    print("\n=== Test: 有 measureText 时优先采用 ===")
    local TextBoxLayout = require("framework.text_box_layout")
    package.loaded["framework.text_box_layout"] = nil
    TextBoxLayout = require("framework.text_box_layout")

    local savedEA = rawget(_G, "EngineAPI")
    rawset(_G, "EngineAPI", {
        font = { measureText = function() return 999 end },
    })
    local w = TextBoxLayout.textWidth("梅庄", 24)
    rawset(_G, "EngineAPI", savedEA)
    package.loaded["framework.text_box_layout"] = nil

    TestHelper.assertEquals(999, w,
        "有 measureText 时必须优先采用（模拟非等宽字体）")
end

-- ------------------------------------------------------------ 纹理创建契约

function TestEngineConformance.testCreateFromRGBAContract()
    print("\n=== Test: createFromRGBA 行为一致性 ===")
    -- Test 引擎可注入，用它验证契约行为
    -- 注意：4 引擎共享同一张 engine_api 表，前面用例 require 过 MUD/Web
    -- 会覆盖实现。这里重新 require 拿回 Test 引擎自己的版本。
    package.loaded["tests.engine_test"] = nil
    local ET = require("tests.engine_test")

    -- 正常路径
    local handle = ET.sprite.createFromRGBA(2, 2, string.rep("x", 2 * 2 * 4), {})
    TestHelper.assertNotNil(handle, "正常参数应返回 handle")
    TestHelper.assertEquals(2, handle.w, "handle.w 应为 2")
    TestHelper.assertEquals(2, handle.h, "handle.h 应为 2")

    -- 数据不足 → 拒绝（不崩）
    TestHelper.assertEquals(nil, ET.sprite.createFromRGBA(2, 2, "short", {}),
        "RGBA 字节不足时必须返回 nil（而不是崩）")

    -- 非法尺寸 → 拒绝
    TestHelper.assertEquals(nil, ET.sprite.createFromRGBA(0, 2, "xxxx", {}),
        "宽为 0 时必须返回 nil")
end

function TestEngineConformance.testCreateFromEncodedContract()
    print("\n=== Test: createFromEncoded 行为一致性 ===")
    -- 注意：4 引擎共享同一张 engine_api 表，前面用例 require 过 MUD/Web
    -- 会覆盖实现。这里重新 require 拿回 Test 引擎自己的版本。
    package.loaded["tests.engine_test"] = nil
    local ET = require("tests.engine_test")
    local handle = ET.sprite.createFromEncoded("png-bytes", "png", {})
    TestHelper.assertNotNil(handle, "正常参数应返回 handle")
    TestHelper.assertEquals(nil, ET.sprite.createFromEncoded("", "png", {}),
        "空字节必须返回 nil")
    TestHelper.assertEquals(nil, ET.sprite.createFromEncoded(nil, "png", {}),
        "nil 必须返回 nil")
end

function TestEngineConformance.testGetMetaContract()
    print("\n=== Test: getMeta 返回五个字段 ===")
    -- 注意：4 引擎共享同一张 engine_api 表，前面用例 require 过 MUD/Web
    -- 会覆盖实现。这里重新 require 拿回 Test 引擎自己的版本。
    package.loaded["tests.engine_test"] = nil
    local ET = require("tests.engine_test")
    local h = ET.sprite.createFromRGBA(10, 20, string.rep("x", 10 * 20 * 4), { xoff = 5, yoff = 20 })
    local meta = ET.sprite.getMeta(h)
    TestHelper.assertNotNil(meta, "getMeta 应返回表")
    TestHelper.assertEquals(10, meta.w, "w")
    TestHelper.assertEquals(20, meta.h, "h")
    TestHelper.assertEquals(5, meta.xoff, "xoff 应原样返回")
    TestHelper.assertEquals(20, meta.yoff, "yoff 应原样返回")
    TestHelper.assertEquals(nil, ET.sprite.getMeta(nil), "nil handle 应返回 nil")
end

-- ------------------------------------------------------------ 地图契约

function TestEngineConformance.testMapGetTileSentinel()
    print("\n=== Test: 无地图引擎的 getTile 哨兵 ===")
    for _, e in ipairs({
        { name = "MUD", path = "engine-mud.engine_mud" },
        { name = "Web", path = "engine-web.engine_web" },
    }) do
        local ok, mod = pcall(require, e.path)
        if ok and mod and mod.map and mod.map.getTile then
            local v = mod.map.getTile(0, 0, 0)
            TestHelper.assertEquals(-1, v,
                e.name .. " 无地图数据时应返回越界哨兵 -1（不是 nil）")
        end
    end
end

-- ------------------------------------------------------------ 音频契约

--- 4 引擎的 playSequence 语义必须一致（port-audio-semantics 的漏洞修复）
--
-- **背景**：`port-audio-semantics` 把 `playSequence` 收窄成「只收 number」，
-- 但当时**只改了 LÖVE** —— MUD/Web/测试桩仍是 `playSequence(filenameOrId)`
-- 无条件 `return true`。而「新引擎作者会抄哪个引擎？」的答案是：多半抄
-- MUD（它是最简参考实现）。于是这个漏洞会直接传染给 Godot/Unreal。
--
-- **为什么必须用源码级断言，不能 require 后调**（实测踩到）：
--   `engine_mud.lua` / `tests/engine_test.lua` / `engine_love2d.lua` 都
--   直接 `local EngineAPI = require("engine-love2d.engine_api")` —— 拿到的是
--   **同一张表**。所以：
--     · `mud.audio == test.audio == engine_api.audio` 全为 true
--     · 后加载的引擎会**覆盖**先加载的（实测：破坏 MUD 后先 require MUD
--       返回 true，但 test_runner 里先 require 了测试桩，于是读到的仍是
--       测试桩的实现 → 断言全 PASS，负向对照抓不到）
--
--   这与 `test_engine_api.lua` 里「不能只靠 engine_api 空桩继承」用源码断言
--   是同一个理由。Web 是唯一例外（它自己 `local EngineAPI = {}`）。
function TestEngineConformance.testPlaySequenceSemanticsAligned()
    print("\n=== Test: playSequence 只收 number（4 引擎源码级）===")
    local files = {
        { name = "LOVE", path = "engine-love2d/engine_love2d.lua" },
        { name = "MUD",  path = "engine-mud/engine_mud.lua" },
        { name = "Web",  path = "engine-web/engine_web.lua" },
        { name = "Test", path = "tests/engine_test.lua" },
    }
    for _, f in ipairs(files) do
        local fh = io.open(f.path, "r")
        if not fh then fh = io.open("../game/" .. f.path, "r") end
        TestHelper.assertNotNil(fh, f.name .. " 源码应可读: " .. f.path)
        if fh then
            local src = fh:read("*a"); fh:close()
            local start = src:find("audio.playSequence", 1, true)
            TestHelper.assertNotNil(start, f.name .. " 应有 audio.playSequence")
            if start then
                local body = src:sub(start, (src:find("\nend", start) or (start + 800)))
                TestHelper.assertNotNil(body:find('type(id) ~= "number"', 1, true),
                    f.name .. ".playSequence 必须有 number 类型守卫")
                TestHelper.assertNotNil(body:find("id < 0", 1, true),
                    f.name .. ".playSequence 必须拒绝负数 id")
                TestHelper.assertNil(body:find("filenameOrId", 1, true),
                    f.name .. ".playSequence 不得再有 filenameOrId（旧语义）")
                -- 「不得 return true」只对有/无音频能力区分：
                --   LÖVE  真播 → true 是正确结果
                --   Test  桩记录调用 → true（代表「调用被接受」）
                --   MUD/Web 明确无音频 → 必须 false，否则「无能力」与
                --           「参数错」无法区分，调用方无法决定是否重试
                if f.name == "MUD" or f.name == "Web" then
                    TestHelper.assertNil(body:find("return true", 1, true),
                        f.name .. ".playSequence 无音频能力时不得返回 true")
                end
            end
        end
    end
end

function TestEngineConformance.testAudioPlayVideoContract()
    print("\n=== Test: playVideo 在所有引擎返回 boolean ===")
    for _, e in ipairs({
        { name = "MUD", path = "engine-mud.engine_mud" },
        { name = "Web", path = "engine-web.engine_web" },
        { name = "Test", path = "tests.engine_test" },
    }) do
        local ok, mod = pcall(require, e.path)
        if ok and mod and mod.audio and mod.audio.playVideo then
            local r = mod.audio.playVideo("x.mpg", 27)
            TestHelper.assertTrue(type(r) == "boolean",
                e.name .. ".audio.playVideo 必须返回 boolean（不是 nil）")
        end
    end
end

-- ------------------------------------------------------------ 门禁反例

function TestEngineConformance.testMissingImplWouldBeDetected()
    print("\n=== Test: 缺一个实现会被检出（负向对照）===")
    local contract = readContract()
    -- 注意：4 引擎共享同一张 engine_api 表，前面用例 require 过 MUD/Web
    -- 会覆盖实现。这里重新 require 拿回 Test 引擎自己的版本。
    package.loaded["tests.engine_test"] = nil
    local ET = require("tests.engine_test")
    -- 临时摘掉一个实现
    local saved = ET.render.getWidth
    ET.render.getWidth = nil
    local missing = 0
    for _, d in ipairs(contract) do
        if ET[d.mod] == nil or ET[d.mod][d.fn] == nil then missing = missing + 1 end
    end
    ET.render.getWidth = saved
    TestHelper.assertTrue(missing >= 1,
        "摘掉一个实现后完整性检查必须发现缺口（实测 " .. missing .. "）")
end

function TestEngineConformance.runAll()
    print("\n" .. string.rep("=", 60))
    print("引擎契约一致性测试（ADR-PORT-007）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestEngineConformance.testAllEnginesImplementAllContracts()
    TestEngineConformance.testRenderSizeSentinel()
    TestEngineConformance.testFontMeasureSentinel()
    TestEngineConformance.testMeasureTextFallbackBehavior()
    TestEngineConformance.testMeasureTextPreferredWhenAvailable()
    TestEngineConformance.testCreateFromRGBAContract()
    TestEngineConformance.testCreateFromEncodedContract()
    TestEngineConformance.testGetMetaContract()
    TestEngineConformance.testMapGetTileSentinel()
    TestEngineConformance.testPlaySequenceSemanticsAligned()
    TestEngineConformance.testAudioPlayVideoContract()
    TestEngineConformance.testMissingImplWouldBeDetected()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_engine_conformance.lua$") then
    TestEngineConformance.runAll()
end

return TestEngineConformance
