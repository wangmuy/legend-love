-- test_settings_store.lua
-- framework/settings_store.lua 的单元测试
--
-- 覆盖：INI 解析 / 序列化 / 往返幂等 / 回读校验 / 无写能力降级
--
-- store 只依赖 EngineAPI.file，测试用内存桩（不需要真实文件）。

local TestHelper = require("tests.test_helper")
local TestSettingsStore = {}

local Store = require("framework.settings_store")

local function withFakeEngineFile(files)
    local saved = rawget(_G, "EngineAPI")
    -- 必须用 rawset：jymain_adapter 会给 _G 装严格 ____newindex 元表，
    -- 之后的 `_G.X = ...` 会抛 "attempt read write to undeclared variable"。
    -- 全量测试里 jymain_adapter 已被前面的模块加载过。
    rawset(_G, "EngineAPI", {
        file = {
            read = function(path)
                return files[path]
            end,
            write = function(path, content)
                files[path] = content
                return true
            end,
        },
    })
    return saved
end

local function restoreEngineAPI(saved)
    rawset(_G, "EngineAPI", saved)
end

-- ============================================================
-- 解析
-- ============================================================

function TestSettingsStore.testParseBasic()
    local r = Store.parse("; 注释\n[audio]\nmusic=64\nsfx=90\n")
    TestHelper.assertEquals("64", r.sections.audio.music, "解析出 music")
    TestHelper.assertEquals("90", r.sections.audio.sfx, "解析出 sfx")
    TestHelper.assertEquals("audio", r.order[1], "记录段落顺序")
end

function TestSettingsStore.testParseBomCrlfAndTrailingComment()
    local text = "\239\187\191[audio]\r\nmusic=50 ; 行尾注释\r\n"
    local r = Store.parse(text)
    TestHelper.assertEquals("50", r.sections.audio.music,
        "BOM + CRLF + 行尾注释都能处理")
end

function TestSettingsStore.testParseHashComment()
    local r = Store.parse("# 整行注释\n[audio]\nmusic=30\n")
    TestHelper.assertEquals("30", r.sections.audio.music, "# 也是注释")
end

function TestSettingsStore.testParseEmptyAndNil()
    TestHelper.assertEquals(0, #Store.parse("").order, "空文本返回空结构")
    TestHelper.assertEquals(0, #Store.parse(nil).order, "nil 返回空结构，不抛错")
end

function TestSettingsStore.testParseLowercasesKeys()
    local r = Store.parse("[AUDIO]\nMUSIC=40\n")
    TestHelper.assertEquals("40", r.sections.audio.music,
        "段名与键名都转小写")
end

-- ============================================================
-- 序列化
-- ============================================================

function TestSettingsStore.testSerializeRoundTrip()
    local sections = {
        audio = { music = 64, sfx = 90 },
        meta = { version = 1 },
        _order = { "meta", "audio" },
    }
    local text = Store.serialize(sections)
    local back = Store.parse(text)
    TestHelper.assertEquals("64", back.sections.audio.music, "往返保留 music")
    TestHelper.assertEquals("90", back.sections.audio.sfx, "往返保留 sfx")
    TestHelper.assertEquals("1", back.sections.meta.version, "往返保留 version")
end

function TestSettingsStore.testSerializeIdempotent()
    local sections = {
        audio = { music = 64 },
        meta = { version = 1 },
        _order = { "meta", "audio" },
    }
    local once = Store.serialize(sections)
    local twice = Store.serialize(Store.parse(once).sections)
    TestHelper.assertEquals(once, twice,
        "parse → serialize 幂等（顺序稳定，便于回读校验与 diff）")
end

function TestSettingsStore.testSerializeOrderPreserved()
    local sections = { meta = { version = 1 }, audio = { music = 64 },
                       _order = { "meta", "audio" } }
    local text = Store.serialize(sections)
    local metaPos = text:find("%[meta%]")
    local audioPos = text:find("%[audio%]")
    TestHelper.assertTrue(metaPos < audioPos, "_order 指定的顺序被保留")
end

function TestSettingsStore.testSerializeBoolean()
    local sections = { video = { fullscreen = true }, _order = { "video" } }
    local text = Store.serialize(sections)
    TestHelper.assertTrue(text:find("fullscreen=1") ~= nil,
        "布尔值序列化成 1/0（INI 惯例）")
end

-- ============================================================
-- 读写 + 回读校验
-- ============================================================

function TestSettingsStore.testReadWriteRoundTrip()
    local files = {}
    local saved = withFakeEngineFile(files)
    local ok, err = Store.write("settings.ini", {
        audio = { music = 30 }, _order = { "audio" },
    })
    TestHelper.assertTrue(ok, "写入成功: " .. tostring(err))

    local sections = Store.read("settings.ini")
    TestHelper.assertNotNil(sections, "读回成功")
    TestHelper.assertEquals("30", sections.audio.music, "读回内容一致")
    restoreEngineAPI(saved)
end

function TestSettingsStore.testReadMissingReturnsNil()
    local saved = withFakeEngineFile({})
    local sections, err = Store.read("no-such.ini")
    TestHelper.assertEquals(nil, sections, "文件不存在返回 nil")
    TestHelper.assertNotNil(err, "给出原因")
    restoreEngineAPI(saved)
end

function TestSettingsStore.testWriteRejectedReportsFailure()
    local saved = rawget(_G, "EngineAPI")
    -- 模拟 web 引擎：write 是空函数
    rawset(_G, "EngineAPI", {
        file = {
            read = function() return nil end,
            write = function() return nil end,
        },
    })
    local ok, err = Store.write("settings.ini", { audio = { music = 30 } })
    TestHelper.assertFalse(ok, "写入被拒时返回 false")
    TestHelper.assertNotNil(err, "给出失败原因")
    restoreEngineAPI(saved)
end

function TestSettingsStore.testWriteVerifyMismatchDetected()
    local saved = rawget(_G, "EngineAPI")
    -- 模拟「返回 true 但没真写」的实现
    rawset(_G, "EngineAPI", {
        file = {
            read = function() return "被改过的内容" end,
            write = function() return true end,
        },
    })
    local ok, err = Store.write("settings.ini", { audio = { music = 30 } })
    TestHelper.assertFalse(ok, "回读内容不一致时判定失败")
    TestHelper.assertEquals("verify-mismatch", err, "失败原因明确")
    restoreEngineAPI(saved)
end

function TestSettingsStore.testNoEngineFileApi()
    local saved = rawget(_G, "EngineAPI")
    rawset(_G, "EngineAPI", nil)
    local sections, err = Store.read("x.ini")
    TestHelper.assertEquals(nil, sections, "无引擎文件接口时读返回 nil")
    TestHelper.assertEquals("no-engine-file-api", err, "原因明确")
    local ok = Store.write("x.ini", {})
    TestHelper.assertFalse(ok, "无引擎文件接口时写返回 false")
    restoreEngineAPI(saved)
end

function TestSettingsStore.runAll()
    print("\n" .. string.rep("=", 60))
    print("SettingsStore INI 持久化测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestSettingsStore.testParseBasic()
    TestSettingsStore.testParseBomCrlfAndTrailingComment()
    TestSettingsStore.testParseHashComment()
    TestSettingsStore.testParseEmptyAndNil()
    TestSettingsStore.testParseLowercasesKeys()

    TestSettingsStore.testSerializeRoundTrip()
    TestSettingsStore.testSerializeIdempotent()
    TestSettingsStore.testSerializeOrderPreserved()
    TestSettingsStore.testSerializeBoolean()

    TestSettingsStore.testReadWriteRoundTrip()
    TestSettingsStore.testReadMissingReturnsNil()
    TestSettingsStore.testWriteRejectedReportsFailure()
    TestSettingsStore.testWriteVerifyMismatchDetected()
    TestSettingsStore.testNoEngineFileApi()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_settings_store.lua$") then
    TestSettingsStore.runAll()
end

return TestSettingsStore
