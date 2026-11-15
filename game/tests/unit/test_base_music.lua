-- test_base_music.lua
-- 原版 BGM 音质修复的回归测试（change: base-music-quality）
--
-- 守的坑：game/sound/gameNN.ogg 曾是「MIDI → opus → ogg」两次有损转码的产物，
-- 25 首里 15 首真峰值 > 0 dBFS、整轨响度跨度 18.2 dB、尾部多 3~5 s 静音。
-- 修法是 tools/render-base-music.sh 从 MIDI 母带重渲染。
--
-- 注意：**MIDI 母带不入 git**（用户要求，避免仓库膨胀）。母带的来源与 md5 记录在
-- tools/base-music-manifest.tsv，渲染脚本按清单从 reference/allmods/ 或 git 历史
-- 现取。所以本套件断言的是「清单健全 + OGG 与清单里记录的母带时长匹配」，
-- 而不是「game/sound 下有 .mid 文件」。
--
-- 本套件只用纯 Lua（不依赖 ffmpeg），因此四版本 Lua 下都能跑：
--   * tools/midiinfo.lua 用 tempo map 算 MIDI 时长
--   * 这里自带一个极简 Ogg Vorbis 页解析器算 OGG 时长
-- 两者比值必须落在 [0.90, 1.15]——旧转码产物有 4 首越界，能真正抓住回退。

local TestHelper = require("tests.test_helper")
local TestBaseMusic = {}

-- tools/ 在仓库根目录（与 tests/ 同级的上一级），而测试进程的 cwd 是 game/。
-- 依次尝试候选路径，避免把「从哪个目录跑」写死进测试。
local function repoPath(rel)
    local cands = { rel, "../" .. rel, "../../" .. rel }
    for _, c in ipairs(cands) do
        local f = io.open(c, "rb")
        if f then f:close() return c end
    end
    return nil
end

local function loadMidiInfo()
    if TestBaseMusic._midiinfo then return TestBaseMusic._midiinfo end
    local path = repoPath("tools/midiinfo.lua")
    if not path then return nil, "找不到 tools/midiinfo.lua" end
    local mod = dofile(path)
    TestBaseMusic._midiinfo = mod
    return mod
end

-- cwd=game/ 时（test_runner 的常规跑法）sound/ 就是 game/sound；
-- 从仓库根跑工具时是 game/sound/。用 repoPath 探测，避免依赖 cwd。
-- 注意：探测锚点用 .ogg 而不是 .mid —— 母带不入 git，.mid 通常不在盘上。
local function soundDir()
    if repoPath("sound/game01.ogg") == "sound/game01.ogg" then return "sound/" end
    return "game/sound/"
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local function fileExists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

-- 大端 u32
local function beU32(s, i)
    local a, b, c, d = s:byte(i, i + 3)
    if not a then return nil end
    return ((a * 256 + b) * 256 + c) * 256 + d
end

-- 小端 u32（Ogg 的 granule 与采样率都是小端）
local function leU32(s, i)
    local a, b, c, d = s:byte(i, i + 3)
    if not a then return nil end
    return ((d * 256 + c) * 256 + b) * 256 + a
end

-- 小端 u64（granule position）
local function leU64(s, i)
    local b1, b2, b3, b4, b5, b6, b7, b8 = s:byte(i, i + 7)
    if not b1 then return nil end
    -- 高 32 位在实际曲目里恒为 0；把它带上但仍用 double（< 2^53 精确）
    local lo = ((b4 * 256 + b3) * 256 + b2) * 256 + b1
    local hi = ((b8 * 256 + b7) * 256 + b6) * 256 + b5
    return hi * 4294967296 + lo
end

-- 极简 Ogg 页扫描：取 identification header 的采样率 + 最后一个 granule。
-- 返回 sr, duration（秒），失败返回 nil, err
local function oggInfo(path)
    local s = readFile(path)
    if not s then return nil, "无法读取 " .. path end
    local pos = 1
    local sr = nil
    local lastGranule = 0
    while true do
        local p = s:find("OggS", pos, true)
        if not p then break end
        -- 页头：capture(4) version(1) type(1) granule(8) serial(4) seq(4) crc(4) nseg(1)
        if p + 26 > #s then break end
        local granule = leU64(s, p + 6)
        local nseg = s:byte(p + 26)
        if not nseg then break end
        local headerLen = 27 + nseg
        local body = p + headerLen
        -- 首个包是 vorbis 识别头：\x01vorbis
        if sr == nil and s:sub(body, body) == "\1" and s:sub(body + 1, body + 6) == "vorbis" then
            sr = leU32(s, body + 12)      -- 采样率在包内偏移 12
        end
        if granule and granule > lastGranule then lastGranule = granule end
        -- 下一个页 = 当前页 + 头长 + Σ segment 长度
        local total = 0
        for k = 0, nseg - 1 do
            total = total + (s:byte(p + 27 + k) or 0)
        end
        pos = body + total
    end
    if not sr or sr == 0 then return nil, "找不到 vorbis 识别头" end
    return sr, lastGranule / sr
end

-- 目录隔离：母带不再入库，曲线救国——把归零的 .mid 从盘上移走
local function listMasters()
    local out = {}
    for i = 1, 25 do
        out[#out + 1] = string.format("game%02d", i)
    end
    return out
end

-- 解析 tools/base-music-manifest.tsv -> { {stem=, md5=, src=, dur=}, ... }
local function parseManifest()
    local path = repoPath("tools/base-music-manifest.tsv")
    if not path then return nil, "找不到 tools/base-music-manifest.tsv" end
    local s = readFile(path)
    if not s then return nil, "无法读取清单" end
    local rows = {}
    for line in s:gmatch("[^\r\n]+") do
        if line:sub(1, 1) ~= "#" and line:match("%S") then
            local stem, md5, src, dur = line:match("^(%S+)	(%S+)	(%S*)	(%S+)")
            if stem then
                rows[#rows + 1] = {
                    stem = stem, md5 = md5, src = src,
                    dur = tonumber(dur) or 0,
                }
            end
        end
    end
    return rows
end

function TestBaseMusic.testManifestIsComplete()
    local rows, err = parseManifest()
    TestHelper.assertNotNil(rows, "应能解析母带清单" .. (err and ("（" .. tostring(err) .. "）") or ""))
    TestHelper.assertEquals(25, #rows, "清单应有 25 行，实测 " .. tostring(#rows))
    local seen = {}
    for _, r in ipairs(rows) do
        seen[r.stem] = true
        TestHelper.assertTrue(#r.md5 == 32, r.stem .. " 的 md5 应为 32 位十六进制")
        TestHelper.assertTrue(r.dur > 20 and r.dur < 130,
            string.format("%s 的 MIDI 时长 %s 应在 20~130 s 之间", r.stem, tostring(r.dur)))
    end
    local missing = {}
    for _, stem in ipairs(listMasters()) do
        if not seen[stem] then missing[#missing + 1] = stem end
    end
    TestHelper.assertEquals(0, #missing,
        "清单应覆盖全部 25 首" .. (#missing > 0 and ("；缺: " .. table.concat(missing, ",")) or ""))
end

-- 母带不入 git，但清单指向的来源在本地应可解析（找不到则跳过，不算失败）
local function firstAvailableMaster()
    local rows = parseManifest()
    if not rows then return nil end
    for _, r in ipairs(rows) do
        if r.src and r.src ~= "-" then
            local p = repoPath(r.src)
            if p then return p, r end
        end
    end
    return nil
end

function TestBaseMusic.testMidiInfoParsesRealMaster()
    local MidiInfo = loadMidiInfo()
    TestHelper.assertNotNil(MidiInfo, "tools/midiinfo.lua 应能加载")
    TestHelper.assertNotNil(MidiInfo.parse, "midiinfo 应导出 parse")

    local path, row = firstAvailableMaster()
    if not path then
        print("  [skip] 本地没有 reference/allmods，跳过 MIDI 解析验证")
        return
    end
    local info, err = MidiInfo.parse(path)
    TestHelper.assertNotNil(info, "应能解析 " .. path .. (err and ("（" .. tostring(err) .. "）") or ""))
    TestHelper.assertTrue(info.format == 0 or info.format == 1,
        "format 应为 0 或 1，实测 " .. tostring(info.format))
    TestHelper.assertTrue(info.division > 0, "division 应为正数")
    TestHelper.assertTrue(info.notes > 0, "应有 note-on 事件")
    TestHelper.assertTrue(math.abs(info.duration - row.dur) < 0.5,
        string.format("%s 解析时长 %.2f 应与清单 %.2f 一致（±0.5s）", row.stem, info.duration, row.dur))
end

function TestBaseMusic.testMidiInfoHandlesMultiTrack()
    local MidiInfo = loadMidiInfo()
    local rows = parseManifest()
    local target
    for _, r in ipairs(rows or {}) do
        if r.src == "-" then target = r break end
    end
    if not target then
        print("  [skip] 清单里没有 git 历史来源的曲目")
        return
    end
    local mid
    if target.src and target.src ~= "-" then
        mid = repoPath(target.src)
    else
        mid = repoPath(soundDir() .. target.stem .. ".mid")
    end
    if not mid then
        print("  [skip] " .. target.stem .. " 母带不在本地（母带入 git 属预期），跳过多轨验证")
        return
    end
    local info, err = MidiInfo.parse(mid)
    TestHelper.assertNotNil(info, "应能解析 " .. mid .. (err and ("（" .. tostring(err) .. "）") or ""))
    TestHelper.assertEquals(1, info.format, target.stem .. " 应为 format 1")
    TestHelper.assertTrue(info.tracks > 1, target.stem .. " 应多轨，实测 " .. tostring(info.tracks))
end

function TestBaseMusic.testMidiInfoRejectsNonMidi()
    local MidiInfo = loadMidiInfo()
    local info, err = MidiInfo.parse(soundDir() .. "game01.ogg")
    TestHelper.assertEquals(nil, info, "把 OGG 当 MIDI 解析应返回 nil")
    TestHelper.assertNotNil(err, "应返回错误说明")
end

function TestBaseMusic.testMidiInfoRejectsMissingFile()
    local MidiInfo = loadMidiInfo()
    local info, err = MidiInfo.parse(soundDir() .. "does_not_exist.mid")
    TestHelper.assertEquals(nil, info, "不存在的文件应返回 nil")
    TestHelper.assertNotNil(err, "应返回错误说明")
end

-- 母带**不入 git**：game/sound 下不该有 .mid（这是用户的明确要求）
function TestBaseMusic.testNoMasterInGitDir()
    local leftover = {}
    for _, stem in ipairs(listMasters()) do
        if fileExists(soundDir() .. stem .. ".mid") then
            leftover[#leftover + 1] = stem
        end
    end
    TestHelper.assertEquals(0, #leftover,
        "game/sound 不应保留 MIDI 母带（母带由 render-base-music.sh 按清单现取）" ..
        (#leftover > 0 and ("；残留: " .. table.concat(leftover, ", ")) or ""))
end

-- 核心断言：OGG 时长必须贴近清单记录的母带时长。
-- 旧转码产物比值 1.034..1.212（game08 达 1.212）；重渲染后 0.993..1.077。
function TestBaseMusic.testOggDurationMatchesMaster()
    local rows = parseManifest()
    TestHelper.assertNotNil(rows, "应能解析母带清单")
    local ratioMin, ratioMax = 0.90, 1.15
    local bad = {}
    local checked = 0
    for _, r in ipairs(rows) do
        local ogg = soundDir() .. r.stem .. ".ogg"
        if fileExists(ogg) then
            local sr, oggDur = oggInfo(ogg)
            if not sr then
                bad[#bad + 1] = r.stem .. "(OGG 解析失败)"
            elseif r.dur > 0 then
                checked = checked + 1
                local ratio = oggDur / r.dur
                if ratio < ratioMin or ratio > ratioMax then
                    bad[#bad + 1] = string.format("%s(ratio=%.3f ogg=%.1fs midi=%.1fs)",
                        r.stem, ratio, oggDur, r.dur)
                end
            end
        end
    end
    TestHelper.assertEquals(25, checked, "应检查 25 首，实测 " .. checked)
    TestHelper.assertEquals(0, #bad,
        "25 首 OGG 时长都应贴近母带时长（比值 ∈ [0.90,1.15]）" ..
        (#bad > 0 and ("；越界: " .. table.concat(bad, "; ")) or ""))
end

-- 负向对照：把阈值收得比实测还严，断言必须失败——证明上面的检查真的有鉴别力。
function TestBaseMusic.testDurationCheckHasTeeth()
    local rows = parseManifest()
    local r = rows and rows[1]
    TestHelper.assertNotNil(r, "清单第一行应可读")
    local sr, oggDur = oggInfo(soundDir() .. r.stem .. ".ogg")
    TestHelper.assertNotNil(sr, r.stem .. ".ogg 应能解析")
    local ratio = oggDur / r.dur
    TestHelper.assertTrue(ratio > 1.005 or ratio < 0.99,
        string.format("阈值收紧到 [0.99,1.005] 后 %s(ratio=%.4f) 判为越界——时长检查确有鉴别力",
            r.stem, ratio))
end

-- 音质/体积取舍：32 kHz q4（不是 48 kHz）——见 render-base-music.sh 头注释
function TestBaseMusic.testOggIsVorbisStereo32k()
    local sr, dur = oggInfo(soundDir() .. "game01.ogg")
    TestHelper.assertEquals(32000, sr,
        "重渲染产物应为 32 kHz（原版音色库样本只有 22.05 kHz，48 kHz 纯属浪费体积）")
    TestHelper.assertTrue(dur > 45 and dur < 60,
        "game01.ogg 时长应在 45~60 s，实测 " .. tostring(dur))
end

function TestBaseMusic.testRenderScriptKeepsKeyParams()
    local s = readFile(repoPath("tools/render-base-music.sh") or "tools/render-base-music.sh")
    TestHelper.assertNotNil(s, "tools/render-base-music.sh 应存在")
    TestHelper.assertNotNil(s:find("silenceremove", 1, true),
        "脚本必须保留 silenceremove（否则带回 3~5 s 尾静音）")
    TestHelper.assertNotNil(s:find("loudnorm", 1, true),
        "脚本必须保留 loudnorm（否则带回 18 dB 响度差）")
    TestHelper.assertNotNil(s:find("mid.sf2", 1, true),
        "脚本默认音色库应是原版 mid.sf2")
    TestHelper.assertNotNil(s:find("libvorbis", 1, true),
        "脚本应以 libvorbis 编码")
    TestHelper.assertNotNil(s:find("SAMPLE_RATE=", 1, true),
        "脚本必须显式声明 SAMPLE_RATE")
    TestHelper.assertNotNil(s:find("ensure_master", 1, true),
        "脚本必须能按清单自动恢复母带（母带不入 git）")
end

-- 运行时零改动：探测顺序必须仍是 .ogg 优先
function TestBaseMusic.testMusicProbeOrderUnchanged()
    local s = readFile(repoPath("game/engine-love2d/lib_love.lua") or "game/engine-love2d/lib_love.lua")
    TestHelper.assertNotNil(s, "lib_love.lua 应存在")
    local line = s:match("MUSIC_EXTS%s*=%s*{([^}]*)}")
    TestHelper.assertNotNil(line, "应能找到 MUSIC_EXTS 定义")
    local e1 = line:match('"(%.%w+)"')
    TestHelper.assertEquals(".ogg", e1, "第一个探测扩展名必须是 .ogg")
    local ext2 = line:match('"(%.%w+)"', line:find('"(%.%w+)"') + 1)
    TestHelper.assertNotNil(ext2, "应有第二个扩展名")
    TestHelper.assertEquals(".mp3", ext2, "第二个探测扩展名必须是 .mp3")
end

function TestBaseMusic.testGateScriptExists()
    local s = readFile(repoPath("game/tests/gate_base_music.sh") or "game/tests/gate_base_music.sh")
    TestHelper.assertNotNil(s, "game/tests/gate_base_music.sh 应存在")
    TestHelper.assertNotNil(s:find("ebur128", 1, true), "门禁应用 ebur128 测真峰值")
end

-- 套件入口：与 tests/test_runner.lua 的 runAll 约定一致
function TestBaseMusic.runAll()
    print("\n" .. string.rep("=", 60))
    print("原版 BGM 音质测试（base-music-quality）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestBaseMusic.testManifestIsComplete()

    TestBaseMusic.testMidiInfoParsesRealMaster()
    TestBaseMusic.testMidiInfoHandlesMultiTrack()
    TestBaseMusic.testMidiInfoRejectsNonMidi()
    TestBaseMusic.testMidiInfoRejectsMissingFile()

    TestBaseMusic.testNoMasterInGitDir()
    TestBaseMusic.testOggDurationMatchesMaster()
    TestBaseMusic.testDurationCheckHasTeeth()
    TestBaseMusic.testOggIsVorbisStereo32k()

    TestBaseMusic.testRenderScriptKeepsKeyParams()
    TestBaseMusic.testMusicProbeOrderUnchanged()
    TestBaseMusic.testGateScriptExists()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_base_music.lua$") then
    TestBaseMusic.runAll()
end

return TestBaseMusic
