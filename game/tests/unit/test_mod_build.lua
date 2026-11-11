-- test_mod_build.lua
-- mod_build.lua 构建期行为单元测试
--   allmods-slice0b-smap-rename（Contract A: 资源别名映射）
--   allmods-slice0b-sound-fallback（Contract B: sound/ 复制）
--
-- 用临时目录伪造 MOD 树做隔离测试；另加对真实 20 MOD 源数据的轻量断言。

local TestHelper = require("tests.test_helper")
local Fs = require("framework.fs_compat")
local TestModBuild = {}

-- 载入 mod_build.lua（dofile 不触发 CLI，因为 ... 在 dofile 下为 nil）
local function freshBuild()
    local BUILD = dofile("tools/mod_build.lua")
    return BUILD
end

-- 用 shell 命令读文件字节
local function readBytes(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local function writeBytes(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

local function dirExists(path)
    return Fs.directoryExists(path)
end

-- 在临时目录下搭一个伪 MOD 树，返回 modDir 路径。
-- spec = { resource = { {name, content}, ... }, sound = {...}, fight = {...} }
local function makeFakeMod(spec)
    local root = "tests/tmp_mod_" .. tostring(math.random(100000, 999999))
    Fs.removeTree(root)
    Fs.makeDirectory(root)
    for dir, files in pairs(spec) do
        Fs.makeDirectory(root .. "/" .. dir)
        for _, item in ipairs(files) do
            writeBytes(root .. "/" .. dir .. "/" .. item[1], item[2])
        end
    end
    -- kysmod.ini 必需（Build 会尝试读取，缺失不致命但补齐更真实）
    if not spec.kysmod then
        writeBytes(root .. "/kysmod.ini", "[system]\n")
    end
    return root
end

local function cleanup(root)
    if root then Fs.removeTree(root) end
end

-- 直接调用内部 collectDataFiles/flattenResources 不可行（它们是 local），
-- 因此改为验证 BUILD 暴露的行为：用真实 MOD 构建到一个临时 outRoot 不可行
-- （Build 固定输出到 game/mods/<slug>）。折中：断言「真实产物」与「源码常量」。

-- ============================================================
-- REQ-ALIAS-1 / REQ-ALIAS-2: 别名映射（源码级断言）
-- ============================================================

function TestModBuild.testAliasMapInSource()
    print("\n=== Test: ALIAS_MAP 定义正确（sdx/smp/wdx/wmp → smap/wmap）===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(src ~= nil, "mod_build.lua 可读")
    -- 逐条断言映射
    TestHelper.assertTrue(src:find('["sdx"] = "smap.idx"', 1, true) ~= nil,
        "sdx → smap.idx")
    TestHelper.assertTrue(src:find('["smp"] = "smap.grp"', 1, true) ~= nil,
        "smp → smap.grp")
    TestHelper.assertTrue(src:find('["wdx"] = "wmap.idx"', 1, true) ~= nil,
        "wdx → wmap.idx")
    TestHelper.assertTrue(src:find('["wmp"] = "wmap.grp"', 1, true) ~= nil,
        "wmp → wmap.grp")
end

function TestModBuild.testAliasSourceCitedInComment()
    print("\n=== Test: 别名表附权威来源注释（UPedit.ini）===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(src:find("UPedit.ini", 1, true) ~= nil,
        "注释引用 UPedit.ini")
    TestHelper.assertTrue(src:find("SMAPIDX", 1, true) ~= nil,
        "注释引用 SMAPIDX 映射键")
end

function TestModBuild.testAliasOnlyAppliedToDataKind()
    print("\n=== Test: 别名仅作用于 kind==data（resource/ 来源）===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(
        src:find('if f.kind == "data" and ALIAS_MAP[destRel] then', 1, true) ~= nil,
        "别名应用条件含 kind==\"data\" 守卫")
end

-- ============================================================
-- REQ-ALIAS-3: 冲突显式失败
-- ============================================================

function TestModBuild.testConflictDetectionInSource()
    print("\n=== Test: 冲突检测（重复目标名报错）===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(src:find("aliased and written[dest]", 1, true) ~= nil,
        "仅对别名目标做冲突检测")
    TestHelper.assertTrue(src:find("alias conflict", 1, true) ~= nil,
        "含冲突错误信息")
end

-- ============================================================
-- REQ-ALIAS-4: diff 改名对识别
-- ============================================================

function TestModBuild.testDiffHasAliasSection()
    print("\n=== Test: buildDiff 含「资源别名转换」小节 ===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(src:find("## 资源别名转换", 1, true) ~= nil,
        "含别名转换小节标题")
    TestHelper.assertTrue(src:find("aliasedTargets", 1, true) ~= nil,
        "过滤基准独有中的别名目标名")
    TestHelper.assertTrue(src:find("aliasedSources", 1, true) ~= nil,
        "过滤 MOD 独有中的别名源名")
end

-- ============================================================
-- REQ-SOUND-1: sound/ 复制
-- ============================================================

function TestModBuild.testSoundWalkInSource()
    print("\n=== Test: collectDataFiles 含 sound/ walk ===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(src:find('walk(modDir .. "/sound", "", "sound")', 1, true) ~= nil,
        "walk sound/ with kind=\"sound\"")
end

function TestModBuild.testSoundRoutingInSource()
    print("\n=== Test: sound/ 路由到 outSound（不拍平进 data/）===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(src:find('elseif f.kind == "sound" then base = outSound', 1, true) ~= nil,
        "kind==sound 路由到 outSound")
    TestHelper.assertTrue(src:find("local outSound = outRoot", 1, true) ~= nil,
        "outSound = outRoot .. \"/sound\"")
end

-- ============================================================
-- REQ-CLASSIFY-3: IGNORE_DIRS 覆盖编辑器目录
-- ============================================================

function TestModBuild.testIgnoreDirsCoversEditorDirs()
    print("\n=== Test: IGNORE_DIRS 含 head/item/eft ===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(
        src:find("local IGNORE_DIRS = { head = true, item = true, eft = true }", 1, true) ~= nil,
        "IGNORE_DIRS = { head, item, eft }")
end

-- ============================================================
-- 真实产物断言（若 mods/mingdong 已构建）
-- ============================================================

function TestModBuild.testMingdongArtifactsIfBuilt()
    print("\n=== Test: mingdong 真实产物（若已构建）===")
    local dataDir = "mods/mingdong/data"
    if not dirExists(dataDir) then
        print("  [SKIP] mods/mingdong/data 不存在（未构建）")
        TestHelper.assertTrue(true, "skip: not built")
        return
    end
    TestHelper.assertTrue(readBytes(dataDir .. "/smap.idx") ~= nil, "smap.idx 存在")
    TestHelper.assertTrue(readBytes(dataDir .. "/smap.grp") ~= nil, "smap.grp 存在")
    TestHelper.assertTrue(readBytes(dataDir .. "/wmap.idx") ~= nil, "wmap.idx 存在")
    TestHelper.assertTrue(readBytes(dataDir .. "/wmap.grp") ~= nil, "wmap.grp 存在")
    TestHelper.assertTrue(readBytes(dataDir .. "/sdx") == nil, "无 sdx 残留")
    TestHelper.assertTrue(readBytes(dataDir .. "/smp") == nil, "无 smp 残留")
    TestHelper.assertTrue(readBytes(dataDir .. "/wdx") == nil, "无 wdx 残留")
    TestHelper.assertTrue(readBytes(dataDir .. "/wmp") == nil, "无 wmp 残留")
    TestHelper.assertTrue(dirExists("mods/mingdong/sound"), "sound/ 目录存在")

    -- 内容一致性：smap.grp 与源 smp 逐字节相同
    local srcSmp = readBytes("../reference/allmods/kys-mingdong/resource/smp")
    local outSmp = readBytes(dataDir .. "/smap.grp")
    TestHelper.assertTrue(srcSmp ~= nil and outSmp ~= nil and srcSmp == outSmp,
        "smap.grp 与源 smp 逐字节相同（只改名不改内容）")

    -- diff.md 别名小节
    local diff = readBytes("mods/mingdong/diff.md")
    TestHelper.assertTrue(diff ~= nil and diff:find("## 资源别名转换", 1, true) ~= nil,
        "diff.md 含资源别名转换小节")
    if diff then
        local fileSection = diff:match("## 文件差异.-## hdgrp")
        if fileSection then
            TestHelper.assertTrue(fileSection:find("smap.idx", 1, true) == nil,
                "smap.idx 不在文件差异中误报")
            TestHelper.assertTrue(fileSection:find("sdx", 1, true) == nil,
                "sdx 不在文件差异中误报")
        end
    end
end

-- ============================================================
-- REQ-MIDI-4: MOD music/ 搬运（.mid + .mp3，排除 .sf2）
-- ============================================================

function TestModBuild.testMusicWalkInSource()
    print("\n=== Test: music/ 搬运已在源码接线 ===")
    local src = readBytes("tools/mod_build.lua")
    TestHelper.assertTrue(src:find("local function flattenMusic(", 1, true) ~= nil,
        "flattenMusic 存在")
    TestHelper.assertTrue(src:find('flattenMusic(modDir, outMusic)', 1, true) ~= nil,
        "flattenMusic 被调用")
    TestHelper.assertTrue(src:find('local outMusic = outRoot', 1, true) ~= nil,
        'outMusic = outRoot .. "/music"')
end

function TestModBuild.testMusicPatternHasNoLuaAlternation()
    print("\n=== Test: 音乐文件名正则不使用 Lua 不支持的 | 选择符 ===")
    local src = readBytes("tools/mod_build.lua")
    -- Lua pattern 没有 alternation 操作符，'|' 是字面字符。
    -- 早期实现写成 "^(%d+)%.(mid|mp3)$" 会静默匹配 0 个文件。
    TestHelper.assertTrue(src:find('%.(mid|mp3)', 1, true) == nil,
        "negative control: 源码不得出现 Lua 不支持的 (mid|mp3) 写法")
    TestHelper.assertTrue(src:find('ext == "mid" or ext == "mp3"', 1, true) ~= nil,
        "改用扩展名白名单比较")
end

function TestModBuild.testMusicPatternMatchesRealNames()
    print("\n=== Test: 音乐正则对真实文件名可用 ===")
    local function matchName(name)
        local id, ext = name:match("^(%d+)%.([%a%d]+)$")
        if id and (ext == "mid" or ext == "mp3") then return tonumber(id), ext end
        return nil
    end
    local id, ext = matchName("26.mid")
    TestHelper.assertEquals(26, id, "26.mid id")
    TestHelper.assertEquals("mid", ext, "26.mid ext")
    local id2, ext2 = matchName("37.mp3")
    TestHelper.assertEquals(37, id2, "37.mp3 id")
    TestHelper.assertEquals("mp3", ext2, "37.mp3 ext")
    -- 负向对照：非音频扩展名必须不匹配
    TestHelper.assertEquals(nil, (matchName("mid.sf2")), "negative: .sf2 不匹配")
    TestHelper.assertEquals(nil, (matchName("readme.txt")), "negative: .txt 不匹配")
    TestHelper.assertEquals(nil, (matchName("game27.mid")), "negative: 已有 game 前缀不匹配")
end

function TestModBuild.testMusicRenumberingFormula()
    print("\n=== Test: 重命名公式 game<id+1> ===")
    local function destFor(id, ext) return string.format("game%02d.%s", tonumber(id) + 1, ext) end
    TestHelper.assertEquals("game01.mid", destFor("0", "mid"), "0.mid -> game01.mid")
    TestHelper.assertEquals("game27.mid", destFor("26", "mid"), "26.mid -> game27.mid")
    TestHelper.assertEquals("game82.mid", destFor("81", "mid"), "81.mid -> game82.mid (min-width)")
    TestHelper.assertEquals("game25.mp3", destFor("24", "mp3"), "24.mp3 -> game25.mp3")
    TestHelper.assertEquals("game38.mp3", destFor("37", "mp3"), "37.mp3 -> game38.mp3")
end

function TestModBuild.testMusicArtifactsIfBuilt()
    print("\n=== Test: 真实产物含 .mid 与 .mp3，排除 .sf2 ===")
    -- 统计 mods/*/music/ 下匹配的文件总数（跨平台，不依赖 ls/wc）
    local function count(pattern)
        local n = 0
        for _, slug in ipairs(Fs.listDirectory("mods")) do
            local d = "mods/" .. slug .. "/music"
            if slug:sub(1, 1) ~= "_" and Fs.directoryExists(d) then
                n = n + #Fs.listFiles(d, pattern)
            end
        end
        return n
    end
    local mid = count("^game%d+%.mid$")
    if mid == 0 then
        print("  [SKIP] mods/ 未构建，跳过产物断言")
        return
    end
    TestHelper.assertEquals(578, mid, "产物 .mid = 源 578（零丢失）")
    TestHelper.assertEquals(2, count("^game%d+%.mp3$"), "产物 .mp3 = 源 2")
    TestHelper.assertEquals(0, count("%.sf2$"), "negative: .sf2 不搬运（BUILD_INPUT）")

    -- 字节级：产物必须与源逐字节相同（直接比对内容，不依赖 md5sum）
    local pairsToCheck = {
        { "../reference/allmods/kys-dream/music/24.mp3", "mods/dream/music/game25.mp3" },
        { "../reference/allmods/kys-pineapple/music/37.mp3", "mods/pineapple/music/game38.mp3" },
    }
    for _, pr in ipairs(pairsToCheck) do
        local a, b = Fs.readFile(pr[1]), Fs.readFile(pr[2])
        TestHelper.assertTrue(a ~= nil and a == b,
            string.format("%s 与 %s 字节一致", pr[1], pr[2]))
    end
end

function TestModBuild.runAll()
    print("\n" .. string.rep("=", 60))
    print("mod_build 单元测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestModBuild.testAliasMapInSource()
    TestModBuild.testAliasSourceCitedInComment()
    TestModBuild.testAliasOnlyAppliedToDataKind()
    TestModBuild.testConflictDetectionInSource()
    TestModBuild.testDiffHasAliasSection()
    TestModBuild.testSoundWalkInSource()
    TestModBuild.testSoundRoutingInSource()
    TestModBuild.testMusicWalkInSource()
    TestModBuild.testMusicPatternHasNoLuaAlternation()
    TestModBuild.testMusicPatternMatchesRealNames()
    TestModBuild.testMusicRenumberingFormula()
    TestModBuild.testMusicArtifactsIfBuilt()
    TestModBuild.testIgnoreDirsCoversEditorDirs()
    TestModBuild.testMingdongArtifactsIfBuilt()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestModBuild
