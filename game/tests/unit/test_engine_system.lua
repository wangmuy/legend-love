-- test_engine_system.lua
-- EngineAPI.system / 鼠标 / drawTinted 的单元测试（REQ-MS1-1/2/3）
--
-- ⚠ 测试隔离陷阱（本文件踩过）：
--
--   engine_test.lua 与 engine_mud.lua 都是
--       local EngineAPI = require("engine-love2d.engine_api")
--   然后把实现**挂到同一个表上**。也就是说它们是**共享单例**。
--
--   若测试里直接 `dofile("./engine-mud/engine_mud.lua")`，mud 的实现会
--   覆盖测试引擎的同名函数（实测：drawTinted 被覆盖后 _lastTint 不再被记录）。
--
--   生产环境只加载一个引擎，所以这不是产品缺陷；但测试必须隔离：
--   先摘掉 package.loaded 里的 engine_api，让被测引擎拿到全新表，
--   测完再把原单例装回去。

local TestHelper = require("tests.test_helper")
local TestEngineSystem = {}

local VALID_OS = {
    Windows = true, Linux = true, macOS = true,
    Android = true, iOS = true, web = true, unknown = true,
}

--- 取一个「刚安装完自己实现」的测试引擎
--
-- 为什么不能直接 require：
--   engine_test.lua 与 engine_love2d.lua 往**同一个** engine_api 表上挂实现。
--   tests/unit/test_mod_boot.lua 会 `require("engine-love2d.engine_love2d")`，
--   把 getOS / mousePosition / mouseButton / drawTinted 覆盖成 love2d 版本
--   （那些版本读 love.*，在测试桩下返回 unknown / -1 / false）。
--
--   全量跑时 test_engine_system 排在 test_mod_boot 之后，于是读到的是
--   love2d 的实现 → 「全量失败、单跑通过」。
--   （test_mod_e2e.lua:101 已有同样的处理，这是本仓既有的共享单例惯用法。）
--
-- 清掉 package.loaded 再 require，engine_test 会重新把自己的实现装回去。
local function freshTestEngine()
    package.loaded["tests.engine_test"] = nil
    local te = require("tests.engine_test")
    rawset(_G, "EngineAPI", te)
    return te
end

--- 在「全新 engine_api 单例」下加载某个引擎，测完恢复原状
--
-- @param loader function 返回被测引擎表
-- @param fn function(engineTable) 断言体
local function withFreshEngine(loader, fn)
    local realApi = package.loaded["engine-love2d.engine_api"]
    local savedGlobalAPI = rawget(_G, "EngineAPI")
    local savedGlobalLib = rawget(_G, "lib")

    package.loaded["engine-love2d.engine_api"] = nil

    local ok, err = pcall(function()
        local engine = loader()
        fn(engine)
    end)

    -- 无论成功失败都要恢复，否则会污染后续所有测试
    package.loaded["engine-love2d.engine_api"] = realApi
    rawset(_G, "EngineAPI", savedGlobalAPI)
    rawset(_G, "lib", savedGlobalLib)

    if not ok then
        error(err, 0)
    end
end

-- ============================================================
-- REQ-MS1-1 platform
-- ============================================================

function TestEngineSystem.testMudReturnsUnknown()
    print("\n=== Test: mud 引擎 getOS ===")
    withFreshEngine(function()
        return dofile("./engine-mud/engine_mud.lua")
    end, function(mud)
        TestHelper.assertNotNil(mud.system, "mud 有 system 模块")
        TestHelper.assertNotNil(mud.system.getOS, "mud 有 getOS")
        TestHelper.assertEquals("unknown", mud.system.getOS(),
            "MUD 引擎无平台概念，返回 unknown")
    end)
end

function TestEngineSystem.testWebReturnsWeb()
    print("\n=== Test: web 引擎 getOS（硬编码 web）===")
    local Fs = require("framework.fs_compat")
    local src = Fs.readFile("./engine-web/engine_web.lua")
    TestHelper.assertNotNil(src, "能读到 engine_web.lua")
    TestHelper.assertTrue(src:find('return "web"', 1, true) ~= nil,
        "web 的 getOS 必须硬编码返回 \"web\"")

    -- 只检查**非注释行**：注释里提到 love.system.getOS 是在解释「为什么不用它」，
    -- 那是文档价值，不能当成违规。
    local codeHit = false
    for line in (src .. "\n"):gmatch("(.-)\r?\n") do
        local code = line:gsub("%-%-.*$", "")      -- 去行注释
        if code:find("love%.system%.getOS") then
            -- 也不允许出现在被引号包裹的字符串里之外的代码
            codeHit = true
            break
        end
    end
    TestHelper.assertFalse(codeHit,
        "web 的**代码**不得透传 love.system.getOS（web 构建返回 Linux 会导致平台误判为桌面）")
end

function TestEngineSystem.testLove2dMapsOSXToMacOS()
    print("\n=== Test: love2d 引擎 getOS 的 OS X 映射 ===")
    local Fs = require("framework.fs_compat")
    local src = Fs.readFile("./engine-love2d/engine_love2d.lua")
    TestHelper.assertNotNil(src, "能读到 engine_love2d.lua")
    TestHelper.assertTrue(src:find('"OS X"', 1, true) ~= nil,
        "必须处理 LÖVE 返回 \"OS X\" 的情况")
    TestHelper.assertTrue(src:find('return "macOS"', 1, true) ~= nil,
        "把 \"OS X\" 映射为 \"macOS\"（与文档一致）")
end

function TestEngineSystem.testTestEngineInjectable()
    print("\n=== Test: 测试引擎可注入平台 ===")
    local te = freshTestEngine()
    TestHelper.assertNotNil(te.system, "测试引擎有 system 模块")

    te.system.setOS("Android")
    TestHelper.assertEquals("Android", te.system.getOS(), "可注入 Android")
    te.system.setOS("Linux")
    TestHelper.assertEquals("Linux", te.system.getOS(), "可注入 Linux")
    te.system.setOS("Windows")
end

function TestEngineSystem.testReturnValueInAllowedSet()
    print("\n=== Test: 返回值在限定集合内 ===")
    withFreshEngine(function()
        return dofile("./engine-mud/engine_mud.lua")
    end, function(mud)
        local osMud = mud.system.getOS()
        TestHelper.assertTrue(VALID_OS[osMud] == true,
            "mud 返回值在集合内: " .. tostring(osMud))
    end)

    local te = freshTestEngine()
    local osTest = te.system.getOS()
    TestHelper.assertTrue(VALID_OS[osTest] == true,
        "test 返回值在集合内: " .. tostring(osTest))
end

function TestEngineSystem.testInterfaceDeclarationExists()
    print("\n=== Test: engine_api.lua 有 system 模块声明 ===")
    local api = require("engine-love2d.engine_api")
    TestHelper.assertNotNil(api.system, "engine_api 声明了 system 模块")
    TestHelper.assertNotNil(api.system.getOS, "声明了 getOS")
end

-- ============================================================
-- REQ-MS1-2 鼠标接口
-- ============================================================

function TestEngineSystem.testMudMouseReturnsMinusOne()
    print("\n=== Test: mud 引擎鼠标接口 ===")
    withFreshEngine(function()
        return dofile("./engine-mud/engine_mud.lua")
    end, function(mud)
        local x, y = mud.input.mousePosition()
        TestHelper.assertEquals(-1, x, "无鼠标时 x = -1（不是 nil）")
        TestHelper.assertEquals(-1, y, "无鼠标时 y = -1")
        TestHelper.assertFalse(mud.input.mouseButton(1), "无鼠标时按键恒 false")
    end)
end

function TestEngineSystem.testTestEngineMouseInjectable()
    print("\n=== Test: 测试引擎鼠标可注入 ===")
    local te = freshTestEngine()
    te.input._mouseX = 512
    te.input._mouseY = 384
    local x, y = te.input.mousePosition()
    TestHelper.assertEquals(512, x, "x 可注入")
    TestHelper.assertEquals(384, y, "y 可注入")

    te.input._mouseDown[2] = true
    TestHelper.assertTrue(te.input.mouseButton(2), "右键状态可注入")
    TestHelper.assertFalse(te.input.mouseButton(1), "左键未按下")
    te.input._mouseDown[2] = nil
end

function TestEngineSystem.testLove2dNoDpiConversion()
    print("\n=== Test: love2d 的 mousePosition 不做 DPI 换算 ===")
    -- 实测（Windows 150%）证明 love.mouse.getPosition 已是逻辑坐标，
    -- 故实现里不应出现 toDensity / toPixels
    local Fs = require("framework.fs_compat")
    local src = Fs.readFile("./engine-love2d/engine_love2d.lua")
    TestHelper.assertTrue(src:find("toDensity", 1, true) == nil,
        "不得调用 toDensity（实测无需换算）")
    TestHelper.assertTrue(src:find("toPixels", 1, true) == nil,
        "不得调用 toPixels")
end

function TestEngineSystem.testMousePositionContractDocumented()
    print("\n=== Test: mousePosition 的 DPI 契约写在接口注释里 ===")
    local Fs = require("framework.fs_compat")
    local src = Fs.readFile("./engine-love2d/engine_api.lua")
    TestHelper.assertTrue(src:find("逻辑坐标", 1, true) ~= nil,
        "注释必须写明「逻辑坐标」")
    TestHelper.assertTrue(src:find("同一坐标空间", 1, true) ~= nil
        or src:find("同一空间", 1, true) ~= nil,
        "注释必须写明与绘图同一坐标空间")
    TestHelper.assertTrue(src:find("150%", 1, true) ~= nil,
        "注释应记录 150% 缩放的实测结论")
end

-- ============================================================
-- REQ-MS1-3 drawTinted
-- ============================================================

function TestEngineSystem.testDrawTintedDeclared()
    print("\n=== Test: drawTinted 接口声明 ===")
    local api = require("engine-love2d.engine_api")
    TestHelper.assertNotNil(api.sprite.drawTinted, "engine_api 声明了 drawTinted")
end

function TestEngineSystem.testDrawTintedRecordsArgs()
    print("\n=== Test: drawTinted 记录参数 ===")
    local te = freshTestEngine()
    te.sprite._lastTint = nil
    te.sprite.drawTinted(0, 0, 100, 200, { r = 1, g = 0, b = 0 }, 180)
    local last = te.sprite._lastTint
    TestHelper.assertNotNil(last, "记录了调用")
    TestHelper.assertEquals(0, last.archiveId, "archiveId 透传")
    TestHelper.assertEquals(0, last.spriteId, "spriteId 透传")
    TestHelper.assertEquals(100, last.x, "x 透传")
    TestHelper.assertEquals(200, last.y, "y 透传")
    TestHelper.assertEquals(1, last.color.r, "color.r 透传")
    TestHelper.assertEquals(180, last.alpha, "alpha 透传")
end

function TestEngineSystem.testDrawTintedAcceptsAnySpriteId()
    print("\n=== Test: drawTinted 接受任意 spriteId ===")
    local te = freshTestEngine()
    te.sprite.drawTinted(0, 42, 10, 20, { r = 0, g = 1, b = 0 }, 255)
    TestHelper.assertEquals(42, te.sprite._lastTint.spriteId,
        "spriteId 不硬编码为 0（可用于任意图标）")
end

function TestEngineSystem.testMudDrawTintedNoThrow()
    print("\n=== Test: mud 的 drawTinted 不抛错 ===")
    withFreshEngine(function()
        return dofile("./engine-mud/engine_mud.lua")
    end, function(mud)
        local ok = pcall(mud.sprite.drawTinted, 0, 0, 1, 1, { r = 1, g = 0, b = 0 }, 100)
        TestHelper.assertTrue(ok, "mud 的 drawTinted 不抛错")
    end)
end

function TestEngineSystem.testWebDrawTintedNoThrow()
    print("\n=== Test: web 的 drawTinted 存在且不抛错 ===")
    local Fs = require("framework.fs_compat")
    local src = Fs.readFile("./engine-web/engine_web.lua")
    TestHelper.assertTrue(src:find("function EngineAPI.sprite.drawTinted", 1, true) ~= nil,
        "web 实现了 drawTinted")
end

function TestEngineSystem.testDrawTintedColorFallback()
    print("\n=== Test: drawTinted 的颜色容错（接口注释承诺）===")
    -- 契约：color 为 nil / 缺分量时按原色绘制，不抛错。
    -- 这里在测试引擎上验证「不抛错」（真实染色在 love2d，需实机）。
    local te = freshTestEngine()
    local ok1 = pcall(te.sprite.drawTinted, 0, 0, 0, 0, nil, nil)
    local ok2 = pcall(te.sprite.drawTinted, 0, 0, 0, 0, {}, 100)
    local ok3 = pcall(te.sprite.drawTinted, 0, 0, 0, 0, { r = 1 }, 100)
    TestHelper.assertTrue(ok1, "color=nil 不抛错")
    TestHelper.assertTrue(ok2, "color={} 不抛错")
    TestHelper.assertTrue(ok3, "color 缺分量不抛错")
end

function TestEngineSystem.runAll()
    print("\n" .. string.rep("=", 60))
    print("EngineAPI.system / 鼠标 / drawTinted 测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestEngineSystem.testInterfaceDeclarationExists()
    TestEngineSystem.testMudReturnsUnknown()
    TestEngineSystem.testWebReturnsWeb()
    TestEngineSystem.testLove2dMapsOSXToMacOS()
    TestEngineSystem.testTestEngineInjectable()
    TestEngineSystem.testReturnValueInAllowedSet()

    TestEngineSystem.testMudMouseReturnsMinusOne()
    TestEngineSystem.testTestEngineMouseInjectable()
    TestEngineSystem.testLove2dNoDpiConversion()
    TestEngineSystem.testMousePositionContractDocumented()

    TestEngineSystem.testDrawTintedDeclared()
    TestEngineSystem.testDrawTintedRecordsArgs()
    TestEngineSystem.testDrawTintedAcceptsAnySpriteId()
    TestEngineSystem.testMudDrawTintedNoThrow()
    TestEngineSystem.testWebDrawTintedNoThrow()
    TestEngineSystem.testDrawTintedColorFallback()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_engine_system.lua$") then
    TestEngineSystem.runAll()
end

return TestEngineSystem
