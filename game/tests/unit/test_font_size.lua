-- test_font_size.lua
-- 锁定「DrawStr 的 size 参数真正生效」这一移植缺陷的修复。
--
-- 原版 charset.c:68 GetFont 的缓存键是 (字号, 字体名)：
--     if((Font[i].size ==size) && (Font[i].name) && (strcmp(filename,Font[i].name)==0))
-- LÖVE 移植版曾把 newFont 的字号硬编码成 20、且只按文件名缓存
-- （fontTbl[fontname]），导致 DrawStr 收下 size 却完全不用：
-- 游戏里 CC.DefaultFont=16/24 的场合一律画成 20px。

local TestHelper = require("tests.test_helper")
local TestFontSize = {}

-- 复用项目现成的 mod_boot_harness 搭建最小 LÖVE 环境（它已提供
-- love.filesystem 的 load/read 等，lib_love 模块加载期会用到），
-- 然后把 graphics.newFont / setFont 换成可观测的探针。
local harnessReady = false
local function bootLoveGraphics()
    if not harnessReady then
        require("tests.mod_boot_harness").setup()
        harnessReady = true
    end

    local created = {}      -- { {name=..., size=...}, ... }
    local current = nil

    love.graphics.newFont = function(a, b)
        -- 两种签名：newFont(size) 或 newFont(filename, size)
        local name, size
        if type(a) == "number" then
            size, name = a, nil
        else
            name, size = a, b
        end
        created[#created + 1] = { name = name, size = size }
        return { size = size, name = name }
    end
    love.graphics.setFont = function(f) current = f end
    love.graphics.print = function() end
    love.graphics.setColor = function() end
    love.graphics.getColor = function() return 1, 1, 1, 1 end

    return created, function() return current end
end

-- 前序测试（test_mod_boot → jymain_adapter.init）会不可逆地给 _G 装上
-- 严格元表（__index/__newindex 一律 error）。重新 require lib_love 会执行
-- 它的模块头（setfenv / _ENV 惯例代码），在严格元表下必然炸。
-- 这里临时摘掉元表完成加载，随后原样恢复——只影响加载瞬间。
local function loadLibLove()
    local mt = getmetatable(_G)
    setmetatable(_G, nil)
    package.loaded["engine-love2d.lib_love"] = nil
    local ok, lib = pcall(require, "engine-love2d.lib_love")
    setmetatable(_G, mt)
    if not ok then
        TestHelper.assertTrue(false, "加载 lib_love 失败: " .. tostring(lib))
        return nil
    end
    return lib
end

function TestFontSize.testDrawStrHonorsSize()
    print("\n=== Test: DrawStr 把 size 传给 newFont（不再硬编码 20）===")
    local created, getCurrent = bootLoveGraphics()

    -- 独立加载一份 lib_love，避免与其它测试共享 fontTbl 缓存
    local lib = loadLibLove()
    if not lib then return end
    _G.C_WHITE = _G.C_WHITE or 0xFFFFFF

    lib.DrawStr(0, 0, "测试", 0xFFFFFF, 16, "simsun.ttf")
    TestHelper.assertEquals(#created, 1, "应创建 1 个字体")
    TestHelper.assertEquals(created[1].size, 16, "newFont 应收到 size=16")

    lib.DrawStr(0, 0, "测试", 0xFFFFFF, 24, "simsun.ttf")
    TestHelper.assertEquals(#created, 2, "不同字号应创建第二个字体（缓存键含字号）")
    TestHelper.assertEquals(created[2].size, 24, "第二个字体应为 24")
end

function TestFontSize.testSameSizeReusesFont()
    print("\n=== Test: 同字体同字号复用缓存对象 ===")
    local created = bootLoveGraphics()
    local lib = loadLibLove()
    if not lib then return end

    lib.DrawStr(0, 0, "a", 0xFFFFFF, 16, "simsun.ttf")
    lib.DrawStr(10, 0, "b", 0xFFFFFF, 16, "simsun.ttf")
    TestHelper.assertEquals(#created, 1, "同字体同字号不应重复创建")
end

function TestFontSize.testSetFontReceivesMatchingSize()
    print("\n=== Test: setFont 收到与 size 一致的字体 ===")
    local _, getCurrent = bootLoveGraphics()
    local lib = loadLibLove()
    if not lib then return end

    lib.DrawStr(0, 0, "x", 0xFFFFFF, 24, "simsun.ttf")
    local f = getCurrent()
    TestHelper.assertNotNil(f, "应已 setFont")
    if f then
        TestHelper.assertEquals(f.size, 24, "setFont 的字体字号应为 24")
    end
end

function TestFontSize.testNilSizeDefaultsTo20()
    print("\n=== Test: size 缺省时回落到原版 DefaultFont 字号 20 ===")
    local created = bootLoveGraphics()
    local lib = loadLibLove()
    if not lib then return end

    lib.DrawStr(0, 0, "x", 0xFFFFFF, nil, "simsun.ttf")
    TestHelper.assertEquals(#created, 1, "应创建 1 个字体")
    TestHelper.assertEquals(created[1].size, 20, "缺省字号应为 20")
end

function TestFontSize.testNilFontnameUsesBuiltinBySize()
    print("\n=== Test: 无字体名时内置字体也按字号区分 ===")
    local created = bootLoveGraphics()
    local lib = loadLibLove()
    if not lib then return end

    lib.DrawStr(0, 0, "x", 0xFFFFFF, 16, nil)
    lib.DrawStr(0, 0, "x", 0xFFFFFF, 24, nil)
    TestHelper.assertEquals(#created, 2, "不同字号应创建两个内置字体")
    TestHelper.assertEquals(created[1].size, 16, "第一个为 16")
    TestHelper.assertEquals(created[2].size, 24, "第二个为 24")
end

function TestFontSize.testEngineApiPassesFontnameThrough()
    print("\n=== Test: EngineAPI.render.text 透传 fontname（原版 luafun.c 六参数）===")
    local f = io.open("engine-love2d/engine_love2d.lua", "r")
    if not f then TestHelper.assertTrue(false, "无法打开 engine_love2d.lua"); return end
    local src = f:read("*a"); f:close()

    -- 捕获「形参列表 + 函数体」，不能只匹配到第一个 ')'（那只是形参表）
    local params, body = src:match("EngineAPI%.render%.text%s*=%s*function%(([^)]*)%)(.-)\nend")
    TestHelper.assertNotNil(params, "应能找到 EngineAPI.render.text 定义")
    if params and body then
        TestHelper.assertNotNil(params:match("fontname"), "形参应包含 fontname")
        TestHelper.assertNotNil(body:match("lib%.DrawStr%([^)]*fontname"),
            "应把 fontname 透传给 lib.DrawStr")
    end
end

function TestFontSize.testNoHardcoded20Left()
    print("\n=== Test: lib_love 里不再有硬编码 newFont(...,20) ===")
    local f = io.open("engine-love2d/lib_love.lua", "r")
    if not f then TestHelper.assertTrue(false, "无法打开 lib_love.lua"); return end
    local src = f:read("*a"); f:close()

    -- 允许 DEFAULT_FONT_SIZE = 20 这个具名常量，但不允许调用点写死 20
    local hardcoded = src:match("newFont%(%s*[^,%)]+%s*,%s*20%s*%)")
        or src:match("newFont%(%s*20%s*%)")
    TestHelper.assertNil(hardcoded,
        "newFont 调用不应硬编码 20（应使用传入的 size）")
end

function TestFontSize.runAll()
    -- 整套测试临时摘掉严格 _G 元表：
    --   * 前序测试（test_mod_boot → jymain_adapter.init）会不可逆地装上它
    --   * 本套件需要重新 require lib_love + 经 mod_boot_harness 建 LÖVE 环境
    --   * 二者都会碰到未声明全局（setfenv/bit32/love 等）
    -- 结束时原样恢复，不影响后续套件。
    local savedMt = getmetatable(_G)
    setmetatable(_G, nil)

    TestFontSize.testDrawStrHonorsSize()
    TestFontSize.testSameSizeReusesFont()
    TestFontSize.testSetFontReceivesMatchingSize()
    TestFontSize.testNilSizeDefaultsTo20()
    TestFontSize.testNilFontnameUsesBuiltinBySize()
    TestFontSize.testEngineApiPassesFontnameThrough()
    TestFontSize.testNoHardcoded20Left()

    setmetatable(_G, savedMt)

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestFontSize
