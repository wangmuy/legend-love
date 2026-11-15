-- test_settings.lua
-- framework/settings.lua 的单元测试
--
-- 覆盖：三层优先级 / schema 校验 / 钳制 / 变更通知 / 枚举 / 持久化委派
--
-- 本模块是纯逻辑（零 IO、零引擎依赖），所以测试不需要 mock 引擎。

local TestHelper = require("tests.test_helper")
local TestSettings = {}

local function freshSettings()
    -- 每个测试用干净的 Settings 实例：reset 会丢弃 schema/值/监听器/store
    local Settings = require("framework.settings")
    Settings.reset()
    return Settings
end

-- ============================================================
-- REQ-SET-1 三层优先级
-- ============================================================

function TestSettings.testDefaultLayer()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    TestHelper.assertEquals(64, S.get("audio.music"),
        "无其他层时返回 default")
end

function TestSettings.testModOverridesDefault()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.setMod("audio.music", 22)
    TestHelper.assertEquals(22, S.get("audio.music"),
        "mod 层覆盖 default（REQ-VOL-3：MOD 音量原样生效）")
end

function TestSettings.testUserOverridesMod()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.setMod("audio.music", 22)
    S.set("audio.music", 100)
    TestHelper.assertEquals(100, S.get("audio.music"),
        "user 层覆盖 mod 层")
end

function TestSettings.testLayerIsolation()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.setMod("audio.music", 22)
    S.set("audio.music", 100)
    TestHelper.assertEquals(64, S.getLayer("audio.music", "default"),
        "default 层不受影响")
    TestHelper.assertEquals(22, S.getLayer("audio.music", "mod"),
        "mod 层不受影响")
    TestHelper.assertEquals(100, S.getLayer("audio.music", "user"),
        "user 层是设置值")
end

-- ============================================================
-- REQ-SET-2 schema 校验
-- ============================================================

function TestSettings.testClampUpper()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.set("audio.music", 999)
    TestHelper.assertEquals(128, S.get("audio.music"), "超上界钳制到 128")
end

function TestSettings.testClampLower()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.set("audio.music", -5)
    TestHelper.assertEquals(0, S.get("audio.music"), "低于下界钳制到 0")
end

function TestSettings.testInvalidStringFallsBack()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.setMod("audio.music", "abc")
    TestHelper.assertEquals(64, S.get("audio.music"),
        "非法字符串跳过该层，回落到 default，不抛错")
end

function TestSettings.testStringToInt()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.setMod("audio.music", "22")     -- INI 读出来是字符串
    TestHelper.assertEquals(22, S.get("audio.music"),
        "字符串按 schema 转成整数")
end

function TestSettings.testKeysEnumerated()
    local S = freshSettings()
    S.define("audio.music", { default = 64 })
    S.define("audio.sfx", { default = 90 })
    local keys = S.keys()
    TestHelper.assertEquals(2, #keys, "keys 枚列出全部已声明的键")
    TestHelper.assertEquals("audio.music", keys[1], "keys 按字典序排序")
    TestHelper.assertEquals("audio.sfx", keys[2], "keys 按字典序排序")
end

function TestSettings.testSpecReadable()
    local S = freshSettings()
    S.define("audio.music", {
        default = 64, type = "int", min = 0, max = 128, label = "音乐音量",
    })
    local spec = S.spec("audio.music")
    TestHelper.assertNotNil(spec, "spec 可读")
    TestHelper.assertEquals(64, spec.default, "spec.default")
    TestHelper.assertEquals(0, spec.min, "spec.min")
    TestHelper.assertEquals(128, spec.max, "spec.max")
    TestHelper.assertEquals("音乐音量", spec.label, "spec.label")
end

function TestSettings.testUndefinedKeyReturnsNil()
    local S = freshSettings()
    TestHelper.assertEquals(nil, S.get("no.such.key"),
        "未声明的键返回 nil 而不是抛错")
end

-- ============================================================
-- REQ-SET-4 变更通知
-- ============================================================

function TestSettings.testOnChangeFiresOnce()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    local count, lastValue = 0, nil
    S.onChange("audio.music", function(v) count = count + 1; lastValue = v end)
    S.set("audio.music", 70)
    TestHelper.assertEquals(1, count, "值变化触发恰好 1 次")
    TestHelper.assertEquals(70, lastValue, "回调收到新值")
end

function TestSettings.testOnChangeNotFiredWhenUnchanged()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    local count = 0
    S.onChange("audio.music", function() count = count + 1 end)
    S.set("audio.music", 70)
    S.set("audio.music", 70)
    TestHelper.assertEquals(1, count, "值未变时不重复触发")
end

function TestSettings.testOnChangeIsolated()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    local secondCalled = 0
    S.onChange("audio.music", function() error("第一个监听器抛错") end)
    S.onChange("audio.music", function() secondCalled = secondCalled + 1 end)
    S.set("audio.music", 80)
    TestHelper.assertEquals(1, secondCalled,
        "一个监听器抛错不影响其他监听器（pcall 隔离）")
end

function TestSettings.testMultiListenersAllCalled()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    local a, b = 0, 0
    S.onChange("audio.music", function() a = a + 1 end)
    S.onChange("audio.music", function() b = b + 1 end)
    S.set("audio.music", 80)
    TestHelper.assertEquals(1, a, "监听器 A 被调用")
    TestHelper.assertEquals(1, b, "监听器 B 被调用")
end

-- ============================================================
-- REQ-SET-3 持久化（store 由 settings_store 提供，这里用内存桩）
-- ============================================================

local function memoryStore()
    local files = {}
    local Store = require("framework.settings_store")
    return {
        files = files,
        read = function(path)
            if not files[path] then return nil end
            return Store.parse(files[path]).sections
        end,
        write = function(path, sections)
            files[path] = Store.serialize(sections)
            return true
        end,
    }
end

function TestSettings.testSaveAndLoadRoundTrip()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    local store = memoryStore()
    S.setStore(store, "settings.ini")

    S.set("audio.music", 30)
    local ok = S.save()
    TestHelper.assertTrue(ok, "save 成功")
    TestHelper.assertNotNil(store.files["settings.ini"], "文件已写出")
    TestHelper.assertTrue(store.files["settings.ini"]:find("music=30") ~= nil,
        "文件含 music=30")
    TestHelper.assertTrue(store.files["settings.ini"]:find("version=1") ~= nil,
        "文件含 [meta] version=1")

    -- 新建实例并加载
    S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.setStore(store, "settings.ini")
    S.load()
    TestHelper.assertEquals(30, S.get("audio.music"), "跨会话保留（30）")
end

function TestSettings.testSaveWithoutStoreDoesNotThrow()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.set("audio.music", 30)
    local ok = S.save()
    TestHelper.assertFalse(ok, "无 store 时 save 返回 false")
    TestHelper.assertEquals(30, S.get("audio.music"),
        "无 store 时内存值保留（会话内有效）")
end

function TestSettings.testSaveRejectedDoesNotThrow()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    -- 模拟 web 引擎：file.write 是空函数
    S.setStore({
        read = function() return nil end,
        write = function() return nil end,
    }, "settings.ini")
    S.set("audio.music", 30)
    local ok = S.save()
    TestHelper.assertFalse(ok, "写入被拒时返回 false")
    TestHelper.assertEquals(30, S.get("audio.music"),
        "写入被拒后内存值保留，不抛错")
end

function TestSettings.testLoadFiresOnChange()
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    local store = memoryStore()
    S.setStore(store, "settings.ini")
    S.set("audio.music", 100)
    S.save()

    -- 新实例：先注册监听器，再 load
    S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    S.setStore(store, "settings.ini")
    local pushed = nil
    S.onChange("audio.music", function(v) pushed = v end)
    S.load()
    TestHelper.assertEquals(100, pushed,
        "load 触发 onChange（否则引擎拿到的是默认值）")
end

-- ============================================================
-- REQ-MS1-4 平台层（第四层：user > mod > platform > default）
-- ============================================================

local function defineMouseWithPlatforms(S, platform)
    S.setPlatform(platform)
    S.define("input.mouse", {
        default = false,
        type    = "bool",
        label   = "鼠标操作",
        platformDefaults = {
            Windows = true, Linux = true, macOS = true,
            Android = false, iOS = false,
        },
    })
end

function TestSettings.testPlatformWindowsDefaultTrue()
    local S = freshSettings()
    defineMouseWithPlatforms(S, "Windows")
    TestHelper.assertTrue(S.get("input.mouse"),
        "Windows 平台上鼠标开关默认 true")
end

function TestSettings.testPlatformAndroidDefaultFalse()
    local S = freshSettings()
    defineMouseWithPlatforms(S, "Android")
    TestHelper.assertFalse(S.get("input.mouse"),
        "Android 平台上鼠标开关默认 false")
end

function TestSettings.testPlatformUnknownFallsToDefault()
    local S = freshSettings()
    defineMouseWithPlatforms(S, "unknown")
    TestHelper.assertFalse(S.get("input.mouse"),
        "未列出的平台落到 default")
end

function TestSettings.testPlatformWebFallsToDefault()
    local S = freshSettings()
    defineMouseWithPlatforms(S, "web")
    TestHelper.assertFalse(S.get("input.mouse"),
        "web 未在 platformDefaults 中，落到 default")
end

function TestSettings.testUserOverridesPlatform()
    local S = freshSettings()
    defineMouseWithPlatforms(S, "Android")
    S.set("input.mouse", true)
    TestHelper.assertTrue(S.get("input.mouse"),
        "user 层覆盖平台默认值（Android 上玩家手动开启）")
end

function TestSettings.testModOverridesPlatform()
    local S = freshSettings()
    defineMouseWithPlatforms(S, "Android")
    S.setMod("input.mouse", true)
    TestHelper.assertTrue(S.get("input.mouse"),
        "mod 层优先于平台层")
end

function TestSettings.testPlatformNotPersisted()
    -- 平台层是"默认值"，不是"用户选择"，不应写入 settings.ini
    local S = freshSettings()
    local store = memoryStore()
    S.setStore(store, "settings.ini")
    defineMouseWithPlatforms(S, "Windows")

    S.save()
    local text = store.files["settings.ini"]
    TestHelper.assertNotNil(text, "文件已写")
    TestHelper.assertTrue(text:find("mouse=", 1, true) == nil,
        "用户未设置时，settings.ini 不含 mouse 键（平台默认不落盘）")
end

function TestSettings.testGetPlatform()
    local S = freshSettings()
    S.setPlatform("Linux")
    TestHelper.assertEquals("Linux", S.getPlatform(), "getPlatform 返回注入值")
    S.setPlatform(nil)
    TestHelper.assertEquals("unknown", S.getPlatform(), "nil 视为 unknown")
end

function TestSettings.testSpecExposesPlatformDefaults()
    local S = freshSettings()
    defineMouseWithPlatforms(S, "Windows")
    local spec = S.spec("input.mouse")
    TestHelper.assertNotNil(spec.platformDefaults, "spec 暴露 platformDefaults")
    TestHelper.assertTrue(spec.platformDefaults.Windows, "Windows 值为 true")
    TestHelper.assertFalse(spec.platformDefaults.Android, "Android 值为 false")
end

function TestSettings.testNoPlatformInjectedActsLikeBefore()
    -- 完全不 setPlatform：行为应与引入该层之前一致（用 default）
    local S = freshSettings()
    S.define("audio.music", { default = 64, type = "int", min = 0, max = 128 })
    TestHelper.assertEquals(64, S.get("audio.music"),
        "未注入平台且无 platformDefaults 时行为不变")
end

function TestSettings.runAll()
    print("\n" .. string.rep("=", 60))
    print("Settings 设置核心测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestSettings.testDefaultLayer()
    TestSettings.testModOverridesDefault()
    TestSettings.testUserOverridesMod()
    TestSettings.testLayerIsolation()

    TestSettings.testClampUpper()
    TestSettings.testClampLower()
    TestSettings.testInvalidStringFallsBack()
    TestSettings.testStringToInt()
    TestSettings.testKeysEnumerated()
    TestSettings.testSpecReadable()
    TestSettings.testUndefinedKeyReturnsNil()

    TestSettings.testOnChangeFiresOnce()
    TestSettings.testOnChangeNotFiredWhenUnchanged()
    TestSettings.testOnChangeIsolated()
    TestSettings.testMultiListenersAllCalled()

    TestSettings.testSaveAndLoadRoundTrip()
    TestSettings.testSaveWithoutStoreDoesNotThrow()
    TestSettings.testSaveRejectedDoesNotThrow()
    TestSettings.testLoadFiresOnChange()

    TestSettings.testPlatformWindowsDefaultTrue()
    TestSettings.testPlatformAndroidDefaultFalse()
    TestSettings.testPlatformUnknownFallsToDefault()
    TestSettings.testPlatformWebFallsToDefault()
    TestSettings.testUserOverridesPlatform()
    TestSettings.testModOverridesPlatform()
    TestSettings.testPlatformNotPersisted()
    TestSettings.testGetPlatform()
    TestSettings.testSpecExposesPlatformDefaults()
    TestSettings.testNoPlatformInjectedActsLikeBefore()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_settings.lua$") then
    TestSettings.runAll()
end

return TestSettings
