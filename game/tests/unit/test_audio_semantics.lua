-- test_audio_semantics.lua
-- 音频契约语义的回归测试（change: port-audio-semantics）
--
-- 守的坑（全部有实测依据）：
--   ① `playSequence(id)` 收窄成**只收编号** —— 原来它同时接受字符串，
--      于是 `playMusic(拼好的文件名)` 与 `playSequence(id)` 两条路长期并存，
--      「模板 / 扩展名候选 / sound 回落」这段语义滞留在引擎里没进契约。
--   ② `CC.MIDIFile` 模板**不含扩展名**（原来写死 `.ogg`，而引擎实际按
--      {ogg, mid, mp3} 找候选 —— 模板带扩展名让候选逻辑无从判断边界）。
--   ③ `JY.EnableMusic == 0` 时 `PlayMIDI` 必须**停止**已在播的音乐
--      （原实现只 return → 存档里的开关形同虚设）。
--   ④ `PlayMIDI` 不再拼文件名（原来 `string.format(CC.MIDIFile, id+1)`
--      在 script 层，模板与偏移都是游戏资产约定，应在契约层）。
--   ⑤ `playVideo` 必须如实返回 false（start.mpg 不存在，原实现无条件 true）。

local TestHelper = require("tests.test_helper")
local TestAudioSemantics = {}

local function readSource(rel)
    for _, p in ipairs({ rel, "../game/" .. rel }) do
        local f = io.open(p, "r")
        if f then local s = f:read("*a"); f:close(); return s end
    end
    return nil
end

local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

-- ------------------------------------------------------------ ① 契约文档

function TestAudioSemantics.testContractsDocumented()
    print("\n=== Test: 两个播放契约的职责边界写进 engine_api ===")
    local src = readSource("engine-love2d/engine_api.lua")
    TestHelper.assertNotNil(src, "应能读到 engine_api.lua")

    TestHelper.assertNotNil(src:find("M.app.setMusicTemplate", 1, true),
        "应有 app.setMusicTemplate 契约")
    TestHelper.assertNotNil(src:find("SHALL NOT 含扩展名", 1, true)
        or src:find("SHALL NOT** 含扩展名", 1, true),
        "模板不得含扩展名（契约注释里必须写明）")

    -- playSequence 只收 number
    local seqStart = src:find("M.audio.playSequence", 1, true)
    TestHelper.assertNotNil(seqStart, "应有 audio.playSequence")
    local seqDoc = src:sub(math.max(1, seqStart - 1400), seqStart)
    TestHelper.assertNotNil(seqDoc:find("只收 number", 1, true),
        "playSequence 的注释应写明「只收 number」")

    -- playMusic 只收完整文件名
    local pmStart = src:find("M.audio.playMusic", 1, true)
    TestHelper.assertNotNil(pmStart, "应有 audio.playMusic")
    local pmDoc = src:sub(math.max(1, pmStart - 500), pmStart)
    TestHelper.assertNotNil(pmDoc:find("完整文件名", 1, true),
        "playMusic 的注释应写明「按完整文件名」")
end

-- ------------------------------------------------------------ ② 模板无扩展名

function TestAudioSemantics.testMusicTemplateHasNoExtension()
    print("\n=== Test: CC.MIDIFile 模板不含扩展名 ===")
    local src = readSource("script/jyconst.lua")
    TestHelper.assertNotNil(src, "应能读到 jyconst.lua")
    local code = stripComments(src)

    -- **必须用 plain find**：`%02d` 里的 `%0` 在 Lua 模式里是无效捕获索引
    -- （实测直接抛 "invalid capture index"）。
    for _, pat in ipairs({ "game%02d.ogg", "game%02d.mid", "game%02d.mp3" }) do
        TestHelper.assertNil(code:find(pat, 1, true),
            "CC.MIDIFile 不应带扩展名（实测带 " .. pat .. "）")
    end
    TestHelper.assertNotNil(
        code:find('CC.MIDIFile=CONFIG.SoundPath .. "game%02d"', 1, true),
        "CC.MIDIFile 应为 sound/game%02d（无扩展名）")
end

-- ------------------------------------------------------------ ③ 启动注册模板

function TestAudioSemantics.testTemplateRegisteredAtStartup()
    print("\n=== Test: JYMainAdapter.init 注册音乐模板 ===")
    local src = readSource("framework/jymain_adapter.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain_adapter.lua")
    TestHelper.assertNotNil(src:find("setMusicTemplate(CC.MIDIFile, 1)", 1, true),
        "启动时应 setMusicTemplate(CC.MIDIFile, 1)")
end

-- ------------------------------------------------------------ ④ PlayMIDI 变薄

function TestAudioSemantics.testPlayMIDINoLongerFormatsFilename()
    print("\n=== Test: PlayMIDI 不再拼文件名（交给 playSequence）===")
    local src = readSource("script/jymain.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain.lua")

    local start = src:find("function PlayMIDI(id)", 1, true)
    TestHelper.assertNotNil(start, "应有 function PlayMIDI(id)")
    local bodyEnd = src:find("\nend", start)
    local body = src:sub(start, bodyEnd)

    TestHelper.assertNil(body:find("string.format", 1, true),
        "PlayMIDI 不应再 string.format 文件名（偏移归契约）")
    TestHelper.assertNotNil(body:find("playSequence(id)", 1, true),
        "PlayMIDI 应调 audio.playSequence(id)")
end

-- ------------------------------------------------------------ ⑤ 关音乐要停

function TestAudioSemantics.testEnableMusicZeroStops()
    print("\n=== Test: EnableMusic==0 时 PlayMIDI 调 stopMusic ===")
    local src = readSource("script/jymain.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain.lua")

    local start = src:find("function PlayMIDI(id)", 1, true)
    local bodyEnd = src:find("\nend", start)
    local body = src:sub(start, bodyEnd)
    TestHelper.assertNotNil(body:find("stopMusic", 1, true),
        "EnableMusic==0 分支必须调 audio.stopMusic()（否则已在播的 BGM 不停）")
end

-- ------------------------------------------- ⑥ playVideo 返回值（源码级）

--- **为什么是源码级而不是 require 后调用**：
--   `engine_love2d` 在模块加载期就读 `love.filesystem.load`（加载 jyconst），
--   在测试环境里造完整 love 桩的代价高于收益。而这里的判据本质是
--   「实现里有没有如实返回 false」，源码级断言完全等价且更稳。
function TestAudioSemantics.testPlayVideoReturnsFalseWhenNoCapability()
    print("\n=== Test: playVideo 在无能力/资源缺失时返回 false ===")
    local src = readSource("engine-love2d/engine_love2d.lua")
    TestHelper.assertNotNil(src, "应能读到 engine_love2d.lua")

    local start = src:find("EngineAPI.audio.playVideo = function", 1, true)
    TestHelper.assertNotNil(start, "应有 EngineAPI.audio.playVideo")
    local bodyEnd = src:find("\nend", start)
    local body = src:sub(start, bodyEnd)

    TestHelper.assertNil(body:find("return true", 1, true),
        "playVideo 不得无条件 return true（原实现永远上报「播成功了」）")
    TestHelper.assertNotNil(body:find("return false", 1, true),
        "playVideo 应如实 return false")
    TestHelper.assertNotNil(body:find("getInfo", 1, true),
        "playVideo 应先探测资源是否存在（缺失时静默跳过）")
end

-- --------------------------------- ⑦ playSequence 只收 number（源码级）

function TestAudioSemantics.testPlaySequenceRejectsString()
    print("\n=== Test: playSequence 有 number 类型守卫（收字符串不静默当文件名）===")
    local src = readSource("engine-love2d/engine_love2d.lua")
    TestHelper.assertNotNil(src, "应能读到 engine_love2d.lua")

    local start = src:find("EngineAPI.audio.playSequence = function", 1, true)
    TestHelper.assertNotNil(start, "应有 EngineAPI.audio.playSequence")
    local bodyEnd = src:find("\nend", start)
    local body = src:sub(start, bodyEnd)

    TestHelper.assertNotNil(body:find('type(id) ~= "number"', 1, true),
        "playSequence 必须校验 id 是 number（收字符串应返回 false）")
    TestHelper.assertNil(body:find('type(filenameOrId) == "string"', 1, true),
        "不得再有 filenameOrId 字符串兼容分支（那是语义重叠的根源）")
    TestHelper.assertNotNil(body:find("musicTemplate", 1, true),
        "playSequence 应用注册的模板拼 stem")
    TestHelper.assertNotNil(body:find("musicStartOffset", 1, true),
        "playSequence 应加 startOffset（id → 模板参数的偏移）")
end

-- ------------------------------------------------------------ ⑧ 4 引擎都有契约

function TestAudioSemantics.testAllEnginesHaveSetMusicTemplate()
    print("\n=== Test: 4 引擎都有 app.setMusicTemplate ===")
    local sources = {
        { "LOVE", "engine-love2d/engine_love2d.lua", "EngineAPI.app.setMusicTemplate" },
        { "MUD",  "engine-mud/engine_mud.lua",       "EngineAPI.app.setMusicTemplate" },
        { "Web",  "engine-web/engine_web.lua",       "EngineAPI.app.setMusicTemplate" },
        { "Test", "tests/engine_test.lua",           "EngineAPI.app.setMusicTemplate" },
    }
    for _, e in ipairs(sources) do
        local src = readSource(e[2])
        TestHelper.assertNotNil(src, e[1] .. " 源码应可读")
        TestHelper.assertNotNil(src:find(e[3], 1, true),
            e[1] .. " 应有 " .. e[3])
    end
end

function TestAudioSemantics.runAll()
    print("\n" .. string.rep("=", 60))
    print("音频契约语义（port-audio-semantics）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestAudioSemantics.testContractsDocumented()
    TestAudioSemantics.testMusicTemplateHasNoExtension()
    TestAudioSemantics.testTemplateRegisteredAtStartup()
    TestAudioSemantics.testPlayMIDINoLongerFormatsFilename()
    TestAudioSemantics.testEnableMusicZeroStops()
    TestAudioSemantics.testPlayVideoReturnsFalseWhenNoCapability()
    TestAudioSemantics.testPlaySequenceRejectsString()
    TestAudioSemantics.testAllEnginesHaveSetMusicTemplate()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_audio_semantics.lua$") then
    TestAudioSemantics.runAll()
end

return TestAudioSemantics
