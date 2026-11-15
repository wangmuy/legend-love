-- test_audio_settings.lua
-- framework/audio_settings.lua + framework/audio_menu.lua 的单元测试
--
-- 覆盖：
--   REQ-VOL-1 音乐/音效独立音量
--   REQ-VOL-2 引擎接线（监听器真的调到引擎）
--   REQ-MENU-1 值项描述符（待定值 / 确认提交 / 钳制 / 显示原始值）
--   REQ-MENU-2 onCursorChange（不用于音量）
--
-- 用假 EngineAPI.audio 记录调用，验证「框架真的调到了引擎」。

local TestHelper = require("tests.test_helper")
local TestAudioSettings = {}

-- 假的 EngineAPI.audio：记录每次调用
local calls = {}
local audioState = {}

local function installFakeAudio()
    local saved = rawget(_G, "EngineAPI")
    calls = {}
    audioState = { music = nil, sfx = nil }
    rawset(_G, "EngineAPI", {
        audio = {
            setMusicVolume = function(v)
                calls[#calls + 1] = { kind = "music", value = v }
                audioState.music = v
            end,
            getMusicVolume = function() return audioState.music end,
            setSFXVolume = function(v)
                calls[#calls + 1] = { kind = "sfx", value = v }
                audioState.sfx = v
            end,
            getSFXVolume = function() return audioState.sfx end,
        },
    })
    return saved
end

local function freshAudio()
    local Settings = require("framework.settings")
    local AudioSettings = require("framework.audio_settings")
    Settings.reset()
    AudioSettings.resetInit()
    AudioSettings.define()
    return Settings, AudioSettings
end

-- ============================================================
-- REQ-VOL-1 独立音量
-- ============================================================

function TestAudioSettings.testDefaults()
    freshAudio()
    local S = require("framework.settings")
    TestHelper.assertEquals(64, S.get("audio.music"),
        "音乐默认 64/128（约 50%）")
    TestHelper.assertEquals(90, S.get("audio.sfx"),
        "音效默认 90/128（约 70%）")
end

function TestAudioSettings.testMusicAndSFXIndependent()
    local saved = installFakeAudio()
    local S, A = freshAudio()
    A.init()

    calls = {}
    A.setMusic(30)
    TestHelper.assertEquals(1, #calls, "只调音乐一次")
    TestHelper.assertEquals("music", calls[1].kind, "调的是音乐")
    TestHelper.assertEquals(30, calls[1].value, "值是 30")

    calls = {}
    A.setSFX(100)
    TestHelper.assertEquals(1, #calls, "只调音效一次")
    TestHelper.assertEquals("sfx", calls[1].kind, "调的是音效")
    TestHelper.assertEquals(100, calls[1].value, "值是 100")

    TestHelper.assertEquals(30, A.getMusic(), "音乐值不被音效影响")
    TestHelper.assertEquals(100, A.getSFX(), "音效值不被音乐影响")

    rawset(_G, "EngineAPI", saved)
end

-- ============================================================
-- REQ-VOL-2 引擎接线
-- ============================================================

function TestAudioSettings.testInitPushesCurrentValues()
    local saved = installFakeAudio()
    local S, A = freshAudio()
    calls = {}
    A.init()
    TestHelper.assertTrue(#calls >= 2,
        "init 时把当前值推给引擎（否则引擎停在旧值）")
    TestHelper.assertEquals(64, audioState.music, "推送的音乐值 = 默认 64")
    TestHelper.assertEquals(90, audioState.sfx, "推送的音效值 = 默认 90")
    rawset(_G, "EngineAPI", saved)
end

function TestAudioSettings.testInitIsIdempotent()
    local saved = installFakeAudio()
    local S, A = freshAudio()
    A.init()
    A.init()
    A.init()
    TestHelper.assertEquals(1, S.listenerCount("audio.music"),
        "重复 init 不重复注册监听器")

    calls = {}
    A.setMusic(40)
    TestHelper.assertEquals(1, #calls,
        "重复 init 后一次 set 仍只调引擎一次（不会推 3 次）")
    rawset(_G, "EngineAPI", saved)
end

function TestAudioSettings.testNoEngineDoesNotThrow()
    local saved = rawget(_G, "EngineAPI")
    rawset(_G, "EngineAPI", nil)
    local S, A = freshAudio()
    local ok = pcall(A.init)
    TestHelper.assertTrue(ok, "无引擎时 init 不抛错（降级为不可调）")
    rawset(_G, "EngineAPI", saved)
end

function TestAudioSettings.testLinearGainContract()
    -- REQ-VOL-2 的增益是线性 value/128，不是平方。
    -- 这里在引擎契约层面验证量程：值原样传到引擎，由引擎按 /128 映射。
    local saved = installFakeAudio()
    local S, A = freshAudio()
    A.init()

    calls = {}
    A.setMusic(64)
    TestHelper.assertEquals(64, calls[1].value,
        "0-128 原样传给引擎（引擎侧按 value/128 线性映射，不是平方）")

    calls = {}
    A.setMusic(32)
    TestHelper.assertEquals(32, calls[1].value, "半量程值 32 原样传递")

    rawset(_G, "EngineAPI", saved)
end

-- ============================================================
-- REQ-MENU-1 值项描述符
-- ============================================================

function TestAudioSettings.testValueMenuStructure()
    freshAudio()
    local AudioMenu = require("framework.audio_menu")
    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")

    TestHelper.assertEquals(1, #items, "值调节界面只有 1 项（上下键无导航歧义）")
    TestHelper.assertEquals("number", items[1][2].kind, "描述符 kind=number")
    TestHelper.assertEquals("audio.music", items[1][2].key, "描述符指向设置键")
    TestHelper.assertEquals(1, items[1][2].step, "step=1")
    TestHelper.assertEquals(0, items[1][2].min, "min=0")
    TestHelper.assertEquals(128, items[1][2].max, "max=128")
end

function TestAudioSettings.testValueMenuReturnsNewTableEachTime()
    freshAudio()
    local AudioMenu = require("framework.audio_menu")
    local a = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    local b = AudioMenu.buildValueMenu("audio.music", "音乐音量")

    TestHelper.assertTrue(a ~= b, "两次构建的外层表不同")
    TestHelper.assertTrue(a[1] ~= b[1], "两次构建的菜单项不同")
    TestHelper.assertTrue(a[1][2] ~= b[1][2],
        "两次构建的描述符不同（否则 pending 会残留）")
end

function TestAudioSettings.testFormatShowsRawValueNotPercent()
    freshAudio()
    local AudioMenu = require("framework.audio_menu")
    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    local format = items[1][2].format

    local text = format(64)
    TestHelper.assertTrue(text:find("64/128", 1, true) ~= nil,
        "显示原始值 64/128（不换算成 50%）")
    TestHelper.assertTrue(text:find("50%", 1, true) == nil,
        "不含百分比")
end

function TestAudioSettings.testFormatIsThreeLines()
    freshAudio()
    local AudioMenu = require("framework.audio_menu")
    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    local text = items[1][2].format(64)

    local _, count = text:gsub("\n", "")
    TestHelper.assertEquals(2, count, "三行文本（2 个换行）")
    TestHelper.assertTrue(text:find("▲", 1, true) ~= nil, "含上箭头 ▲")
    TestHelper.assertTrue(text:find("▼", 1, true) ~= nil, "含下箭头 ▼")
end

function TestAudioSettings.testEveryStepChangesDisplay()
    -- 0→128 每次 +1，显示值必须每次都不同（无跳字）。
    -- 这是「显示原始值而非百分比」的核心依据。
    freshAudio()
    local AudioMenu = require("framework.audio_menu")
    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    local format = items[1][2].format

    local seen = {}
    local duplicates = 0
    for v = 0, 128 do
        local text = format(v)
        if seen[text] then
            duplicates = duplicates + 1
        end
        seen[text] = true
    end
    TestHelper.assertEquals(0, duplicates,
        "129 个值产生 129 种不同显示，不存在「按了没变化」")

    -- 对照：若换算成百分比，129 个值只有 101 种显示（28 次跳字）
    local pctSeen = {}
    for v = 0, 128 do
        local pct = math.floor(v * 100 / 128 + 0.5)
        pctSeen[pct] = true
    end
    local pctCount = 0
    for _ in pairs(pctSeen) do pctCount = pctCount + 1 end
    TestHelper.assertTrue(pctCount < 129,
        "百分比方案确实会跳字（只有 " .. pctCount .. " 种显示）")
end

function TestAudioSettings.testEntriesOpenSubMenu()
    freshAudio()
    local AudioMenu = require("framework.audio_menu")
    local opened = {}
    local entries = AudioMenu.buildVolumeEntries(function(key, label)
        opened[#opened + 1] = key
    end)

    TestHelper.assertEquals(2, #entries, "第 1 层有 2 项（音乐/音效）")
    TestHelper.assertEquals("音乐音量", entries[1][1], "第 1 项标签")
    TestHelper.assertEquals("音效音量", entries[2][1], "第 2 项标签")

    -- 回调应返回 1（关闭本层，打开子界面）
    local r = entries[1][2](entries, 1)
    TestHelper.assertEquals(1, r, "回调返回 1，关闭本层")
    TestHelper.assertEquals("audio.music", opened[1], "回调收到音乐键")
end

-- ============================================================
-- REQ-MENU-2 onCursorChange 不用于音量
-- ============================================================

function TestAudioSettings.testValueMenuHasNoCursorHook()
    freshAudio()
    local AudioMenu = require("framework.audio_menu")
    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    -- 值项菜单只有 1 项，没有 onCursorChange 的挂载点；
    -- 这条断言锁住「音量变更不走 onCursorChange」的约束。
    local hasHook = false
    for i = 1, #items do
        if type(items[i]) == "table" and items[i].onCursorChange then
            hasHook = true
        end
    end
    TestHelper.assertFalse(hasHook,
        "音量菜单不注册 onCursorChange（只走确认键，见 ADR-AS-008）")
end

function TestAudioSettings.runAll()
    print("\n" .. string.rep("=", 60))
    print("AudioSettings / AudioMenu 测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestAudioSettings.testDefaults()
    TestAudioSettings.testMusicAndSFXIndependent()

    TestAudioSettings.testInitPushesCurrentValues()
    TestAudioSettings.testInitIsIdempotent()
    TestAudioSettings.testNoEngineDoesNotThrow()
    TestAudioSettings.testLinearGainContract()

    TestAudioSettings.testValueMenuStructure()
    TestAudioSettings.testValueMenuReturnsNewTableEachTime()
    TestAudioSettings.testFormatShowsRawValueNotPercent()
    TestAudioSettings.testFormatIsThreeLines()
    TestAudioSettings.testEveryStepChangesDisplay()
    TestAudioSettings.testEntriesOpenSubMenu()

    TestAudioSettings.testValueMenuHasNoCursorHook()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_audio_settings.lua$") then
    TestAudioSettings.runAll()
end

return TestAudioSettings
