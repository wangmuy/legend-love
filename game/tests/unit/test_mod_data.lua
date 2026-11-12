-- test_mod_data.lua
-- ModData 单元测试（allmods-data-fallback，Contract B）

local TestHelper = require("tests.test_helper")
local TestModData = {}

local function freshModData()
    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")
    return ModData
end

-- ============================================================
-- REQ-DATA-1: Resolve 回退链
-- ============================================================

function TestModData.testResolveNoActiveReturnsOriginal()
    print("\n=== Test: Resolve no active MOD returns original path ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    TestHelper.assertEquals("data/mmap.grp", ModData.Resolve("data/mmap.grp"),
        "no active: data/ path unchanged")
    TestHelper.assertEquals("data/hdgrp.idx", ModData.Resolve("data/hdgrp.idx"),
        "no active: another path unchanged")
end

function TestModData.testResolveModHit()
    print("\n=== Test: Resolve hits MOD dir when file exists ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function(path) return path == "mods/mingdong/data/mmap.grp" end
    TestHelper.assertEquals("mods/mingdong/data/mmap.grp", ModData.Resolve("data/mmap.grp"),
        "MOD hit: resolves to mods/<mod>/data/")
end

function TestModData.testResolveModMissFallsBack()
    print("\n=== Test: Resolve falls back to data/ when MOD file missing ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function() return false end
    TestHelper.assertEquals("data/smap.grp", ModData.Resolve("data/smap.grp"),
        "MOD miss: falls back to data/")
end

function TestModData.testResolveAcceptsBareFilename()
    print("\n=== Test: Resolve accepts bare filename ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function(path) return path == "mods/mingdong/data/mmap.grp" end
    TestHelper.assertEquals("mods/mingdong/data/mmap.grp", ModData.Resolve("mmap.grp"),
        "bare filename: MOD hit")
    ModData.exists = function() return false end
    TestHelper.assertEquals("data/mmap.grp", ModData.Resolve("mmap.grp"),
        "bare filename: fallback gets data/ prefix")
end

-- ============================================================
-- REQ-DATA-2: ScriptFile 回退链
-- ============================================================

function TestModData.testScriptFileNoActive()
    print("\n=== Test: ScriptFile no active MOD ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    TestHelper.assertEquals("script/oldevent/oldevent_5.lua",
        ModData.ScriptFile("script/oldevent/oldevent_5.lua"),
        "no active: unchanged")
end

function TestModData.testScriptFileModHit()
    print("\n=== Test: ScriptFile MOD hit ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function(path)
        return path == "mods/mingdong/script/oldevent/oldevent_5.lua"
    end
    TestHelper.assertEquals("mods/mingdong/script/oldevent/oldevent_5.lua",
        ModData.ScriptFile("script/oldevent/oldevent_5.lua"),
        "MOD hit: script/ resolved under mods/")
end

function TestModData.testScriptFileFallback()
    print("\n=== Test: ScriptFile fallback ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function() return false end
    TestHelper.assertEquals("script/oldevent/oldevent_5.lua",
        ModData.ScriptFile("script/oldevent/oldevent_5.lua"),
        "MOD miss: unchanged script/ path")
end

-- ============================================================
-- REQ-DATA-3: FightFiles 动态枚举
-- ============================================================

function TestModData.testFightFilesUsesModWhenPresent()
    print("\n=== Test: FightFiles enumerates MOD fight files ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.listDir = function(dir, pattern)
        if dir == "mods/mingdong/data/" then
            return { "fight010.grp", "fight002.grp", "fight000.grp" }
        end
        return {}
    end
    local files = ModData.FightFiles()
    TestHelper.assertEquals(3, #files, "MOD fight count")
    TestHelper.assertEquals("fight000.grp", files[1], "sorted[1]")
    TestHelper.assertEquals("fight002.grp", files[2], "sorted[2]")
    TestHelper.assertEquals("fight010.grp", files[3], "sorted[3]")
end

function TestModData.testFightFilesFallsBackToData()
    print("\n=== Test: FightFiles falls back to data/ ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.listDir = function(dir, pattern)
        if dir == "data/" then return { "fight000.grp", "fight001.grp" } end
        return {}
    end
    local files = ModData.FightFiles()
    TestHelper.assertEquals(2, #files, "fallback fight count")
    TestHelper.assertEquals("fight000.grp", files[1], "fallback sorted[1]")
end

function TestModData.testFightFilesNoActiveUsesData()
    print("\n=== Test: FightFiles no active uses data/ ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    local seenDir
    ModData.listDir = function(dir, pattern) seenDir = dir; return { "fight000.grp" } end
    ModData.FightFiles()
    TestHelper.assertEquals("data/", seenDir, "no active: enumerates data/")
end

-- ============================================================
-- REQ-DATA-4: 零回归 / ini 接入
-- ============================================================

function TestModData.testRewriteConstantsNoActiveIsNoop()
    print("\n=== Test: RewriteConstants no active is no-op ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    local CC = { PaletteFile = "data/mmap.col", MMAPPicFile = { "data/mmap.idx", "data/mmap.grp" } }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/" })
    TestHelper.assertEquals("data/mmap.col", CC.PaletteFile, "single path unchanged")
    TestHelper.assertEquals("data/mmap.idx", CC.MMAPPicFile[1], "table[1] unchanged")
    TestHelper.assertEquals("data/mmap.grp", CC.MMAPPicFile[2], "table[2] unchanged")
end

function TestModData.testRewriteConstantsRedirectsOnHit()
    print("\n=== Test: RewriteConstants redirects to MOD on hit ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function(path) return path == "mods/mingdong/data/mmap.grp" end
    local CC = { MMAPPicFile = { "data/mmap.idx", "data/mmap.grp" } }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/" })
    TestHelper.assertEquals("data/mmap.idx", CC.MMAPPicFile[1], "miss: unchanged")
    TestHelper.assertEquals("mods/mingdong/data/mmap.grp", CC.MMAPPicFile[2], "hit: redirected")
end

function TestModData.testRewriteConstantsCloudPicFile()
    print("\n=== Test: RewriteConstants redirects CloudPicFile per-entry ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    -- 只有 grp 存在于 MOD 中，idx 走回退（逐项判断，与 MMAPPicFile 语义一致）
    ModData.exists = function(path) return path == "mods/mingdong/data/cloud.grp" end
    local CC = { CloudPicFile = { "data/cloud.idx", "data/cloud.grp" } }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/" })
    TestHelper.assertEquals("data/cloud.idx", CC.CloudPicFile[1], "cloud idx miss: unchanged")
    TestHelper.assertEquals("mods/mingdong/data/cloud.grp", CC.CloudPicFile[2],
        "cloud grp hit: redirected")
end

function TestModData.testRewriteConstantsFightPicFormat()
    print("\n=== Test: RewriteConstants redirects FightPicFile format string ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    local CC = { FightPicFile = { "data/fight%03d.idx", "data/fight%03d.grp" } }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/" })
    TestHelper.assertEquals("mods/mingdong/data/fight%03d.idx", CC.FightPicFile[1],
        "FightPicFile idx format redirected to mods/")
    TestHelper.assertEquals("mods/mingdong/data/fight%03d.grp", CC.FightPicFile[2],
        "FightPicFile grp format redirected to mods/")
end

function TestModData.testRewriteConstantsScriptPath()
    print("\n=== Test: RewriteConstants redirects script/ paths ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function(path) return path == "mods/mingdong/script/oldtalk.idx" end
    local CC = { TalkIdxFile = "script/oldtalk.idx", TalkGrpFile = "script/oldtalk.grp" }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/" })
    TestHelper.assertEquals("mods/mingdong/script/oldtalk.idx", CC.TalkIdxFile, "script hit")
    TestHelper.assertEquals("script/oldtalk.grp", CC.TalkGrpFile, "script miss unchanged")
end

-- ============================================================
-- REQ-SOUND-2 / REQ-SOUND-3: 音频常量 MOD 前缀回退
-- ============================================================

function TestModData.testRewriteAudioNoActiveIsNoop()
    print("\n=== Test: RewriteConstants audio no active MOD is noop ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    local CC = {
        MIDIFile = "sound/game%02d.ogg",
        ATKFile = "sound/atk%02d.wav",
        EFile = "sound/e%02d.wav",
    }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/", SoundPath = "sound/" })
    TestHelper.assertEquals("sound/atk%02d.wav", CC.ATKFile, "no active: ATKFile unchanged")
    TestHelper.assertEquals("sound/e%02d.wav", CC.EFile, "no active: EFile unchanged")
    TestHelper.assertEquals("sound/game%02d.ogg", CC.MIDIFile, "no active: MIDIFile unchanged")
end

function TestModData.testRewriteAudioModHit()
    print("\n=== Test: RewriteConstants audio redirects to MOD when files present ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.dirExists = function(path) return path == "mods/mingdong/sound/" end
    ModData.listDir = function(dir, pattern)
        if dir ~= "mods/mingdong/sound/" then return {} end
        if pattern == "^atk%d+%.wav$" then return { "atk00.wav", "atk01.wav" } end
        if pattern == "^e%d+%.wav$" then return { "e00.wav", "e100.wav" } end
        return {}   -- 无 game*.ogg
    end
    local CC = {
        MIDIFile = "sound/game%02d.ogg",
        ATKFile = "sound/atk%02d.wav",
        EFile = "sound/e%02d.wav",
    }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/", SoundPath = "sound/" })
    TestHelper.assertEquals("mods/mingdong/sound/atk%02d.wav", CC.ATKFile, "ATKFile -> MOD")
    TestHelper.assertEquals("mods/mingdong/sound/e%02d.wav", CC.EFile, "EFile -> MOD")
    TestHelper.assertEquals("sound/game%02d.ogg", CC.MIDIFile,
        "MIDIFile unchanged (no game*.ogg in MOD)")
    TestHelper.assertEquals("mods/mingdong/sound/e100.wav",
        string.format(CC.EFile, 100), "3-digit e number formats correctly")
end

function TestModData.testRewriteAudioNoSoundDirFallsBack()
    print("\n=== Test: RewriteConstants audio falls back when MOD has no sound/ ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.dirExists = function() return false end
    local CC = { ATKFile = "sound/atk%02d.wav", EFile = "sound/e%02d.wav" }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/", SoundPath = "sound/" })
    TestHelper.assertEquals("sound/atk%02d.wav", CC.ATKFile, "no sound/: ATKFile falls back")
    TestHelper.assertEquals("sound/e%02d.wav", CC.EFile, "no sound/: EFile falls back")
end

-- ============================================================
-- REQ-ALIAS-5: 资源别名后的运行时地图数据
-- ============================================================

function TestModData.testRewriteConstantsSmapAliasTarget()
    print("\n=== Test: RewriteConstants resolves smap/wmap to MOD (alias target) ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function(path)
        return path == "mods/mingdong/data/smap.idx"
            or path == "mods/mingdong/data/smap.grp"
            or path == "mods/mingdong/data/wmap.idx"
            or path == "mods/mingdong/data/wmap.grp"
    end
    local CC = {
        SMAPPicFile = { "data/smap.idx", "data/smap.grp" },
        WMAPPicFile = { "data/wmap.idx", "data/wmap.grp" },
    }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/" })
    TestHelper.assertEquals("mods/mingdong/data/smap.idx", CC.SMAPPicFile[1], "smap.idx -> MOD")
    TestHelper.assertEquals("mods/mingdong/data/smap.grp", CC.SMAPPicFile[2], "smap.grp -> MOD")
    TestHelper.assertEquals("mods/mingdong/data/wmap.idx", CC.WMAPPicFile[1], "wmap.idx -> MOD")
    TestHelper.assertEquals("mods/mingdong/data/wmap.grp", CC.WMAPPicFile[2], "wmap.grp -> MOD")
end

function TestModData.testDirExistsFunction()
    print("\n=== Test: ModData.dirExists ===")
    local ModData = freshModData()
    TestHelper.assertTrue(ModData.dirExists("tests"), "tests/ dir exists")
    TestHelper.assertTrue(not ModData.dirExists("no/such/dir/xyz"), "nonexistent dir false")
end

function TestModData.testSetActiveNormalizesSlug()
    print("\n=== Test: SetActive normalizes slug ===")
    local ModData = freshModData()
    ModData.SetActive("kys-mingdong")
    TestHelper.assertEquals("mingdong", ModData.Active(), "kys- prefix stripped")
    ModData.SetActive("  mingdong\n")
    TestHelper.assertEquals("mingdong", ModData.Active(), "whitespace trimmed")
    ModData.SetActive("")
    TestHelper.assertNil(ModData.Active(), "empty slug -> nil")
end

function TestModData.testActiveReadsFile()
    print("\n=== Test: Active reads active_mod.txt ===")
    local ModData = freshModData()
    ModData.readActiveFile = function() return "mingdong\n" end
    TestHelper.assertEquals("mingdong", ModData.Active(), "slug read from file")
end

-- 回归：旧实现用 gsub("\n","") 把所有行拼接，带注释的文件会被解析成
-- 一个 2000+ 字符的乱串并静默失效（active_mod.sample.txt 直接复制不可用）。
function TestModData.testActiveSkipsCommentAndBlankLines()
    print("\n=== Test: Active 跳过注释行与空行 ===")
    local cases = {
        { "单行",            "mingdong\n",                    "mingdong" },
        { "kys- 前缀",       "kys-mingdong\n",                "mingdong" },
        { "前置空行",        "\n\n  mingdong  \n",          "mingdong" },
        { "CRLF",            "mingdong\r\n",                 "mingdong" },
        { "前有注释",        "# 说明\n# 更多\nmingdong\n",  "mingdong" },
        { "多行取第一",      "mingdong\nawaken\n",           "mingdong" },
        { "注释后跟多行",    "# x\nDragon\nawaken\n",        "Dragon" },
    }
    for _, c in ipairs(cases) do
        local ModData = freshModData()
        local content = c[2]
        ModData.readActiveFile = function() return content end
        TestHelper.assertEquals(c[3], ModData.Active(), c[1])
    end
end

function TestModData.testActiveAllCommentsMeansVanilla()
    print("\n=== Test: 全注释/空文件 = 未激活 ===")
    local cases = {
        { "全注释",   "# 说明\n# 更多\n" },
        { "空文件",   "" },
        { "仅空白",   "   \n\n  \n" },
    }
    for _, c in ipairs(cases) do
        local ModData = freshModData()
        local content = c[2]
        ModData.readActiveFile = function() return content end
        TestHelper.assertNil(ModData.Active(), c[1] .. " -> nil（原版）")
    end
end

-- sample 文件本身必须可直接复制生效，否则说明与实现不符。
function TestModData.testActiveModSampleFileWorks()
    print("\n=== Test: active_mod.sample.txt 可直接复制生效 ===")
    local ModData = freshModData()
    local f = io.open("active_mod.sample.txt", "rb")
    TestHelper.assertNotNil(f, "sample 文件存在")
    if not f then return end
    local content = f:read("*a")
    f:close()
    ModData.readActiveFile = function() return content end
    local slug = ModData.Active()
    TestHelper.assertNotNil(slug, "sample 复制后应能激活某个 MOD")
    -- 必须是一个真实存在的 MOD slug，而非被拼成的大字符串
    TestHelper.assertTrue(#slug < 40,
        "解析结果应是短 slug 而非拼接乱串（实际长度 " .. tostring(#slug) .. "）")
    TestHelper.assertTrue(ModData.dirExists("mods/" .. slug) or slug == "mingdong",
        "解析出的 slug 应指向真实 MOD 目录")
end

function TestModData.testWarRecordCount()
    print("\n=== Test: WarRecordCount ===")
    local ModData = freshModData()
    -- 不存在的文件返回 nil
    TestHelper.assertNil(ModData.WarRecordCount("no/such/file.sta", 186),
        "missing file -> nil")
    -- 用真实存在的文件验证 floor(size/recordSize)
    local f = io.open("tests/unit/test_mod_data.lua", "rb")
    local size = f:seek("end"); f:close()
    TestHelper.assertEquals(math.floor(size / 100),
        ModData.WarRecordCount("tests/unit/test_mod_data.lua", 100),
        "record count = floor(size/recordSize)")
end

-- ============================================================
-- REQ-DATA-5: 存档目录隔离（MOD 之间不共享/不读取彼此存档）
-- ============================================================

function TestModData.testSaveDirNoActive()
    print("\n=== Test: SaveDir no active MOD -> save/ ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    TestHelper.assertEquals("save/", ModData.SaveDir(), "vanilla SaveDir")
end

function TestModData.testSaveDirModActive()
    print("\n=== Test: SaveDir MOD active -> mods/<slug>/save/ ===")
    local ModData = freshModData()
    ModData.SetActive("kys-mingdong")
    TestHelper.assertEquals("mods/mingdong/save/", ModData.SaveDir(), "MOD SaveDir")
end

function TestModData.testRewriteSaveSlotsNoActive()
    print("\n=== Test: save slots unchanged when no MOD (zero regression) ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    local CC = {
        R_IDXFilename = { [0] = "data/ranger.idx", "save/r1.idx", "save/r2.idx", "save/r3.idx" },
        R_GRPFilename = { [0] = "data/ranger.grp", "save/r1.grp", "save/r2.grp", "save/r3.grp" },
        S_Filename    = { [0] = "data/allsin.grp",  "save/s1.grp", "save/s2.grp", "save/s3.grp" },
        D_Filename    = { [0] = "data/alldef.grp",  "save/d1.grp", "save/d2.grp", "save/d3.grp" },
    }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/" })
    TestHelper.assertEquals("data/ranger.idx", CC.R_IDXFilename[0], "slot 0 base unchanged")
    TestHelper.assertEquals("save/r1.idx", CC.R_IDXFilename[1], "slot 1 unchanged")
    TestHelper.assertEquals("save/d3.grp", CC.D_Filename[3], "slot 3 unchanged")
end

function TestModData.testRewriteSaveSlotsModActive()
    print("\n=== Test: save slots redirected to MOD save dir ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function(path) return path == "mods/mingdong/data/ranger.idx" end
    local CC = {
        R_IDXFilename = { [0] = "data/ranger.idx", "save/r1.idx", "save/r2.idx", "save/r3.idx" },
        R_GRPFilename = { [0] = "data/ranger.grp", "save/r1.grp", "save/r2.grp", "save/r3.grp" },
        S_Filename    = { [0] = "data/allsin.grp",  "save/s1.grp", "save/s2.grp", "save/s3.grp" },
        D_Filename    = { [0] = "data/alldef.grp",  "save/d1.grp", "save/d2.grp", "save/d3.grp" },
    }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/" })
    -- slot 0 是 data/ 模板，走回退链（存在则重定向）
    TestHelper.assertEquals("mods/mingdong/data/ranger.idx", CC.R_IDXFilename[0],
        "slot 0 base template redirected (hit)")
    -- slot 1..3 是 save/ 存档槽，重定向到 MOD 专属存档目录
    TestHelper.assertEquals("mods/mingdong/save/r1.idx", CC.R_IDXFilename[1], "slot 1 idx")
    TestHelper.assertEquals("mods/mingdong/save/r2.idx", CC.R_IDXFilename[2], "slot 2 idx")
    TestHelper.assertEquals("mods/mingdong/save/r3.idx", CC.R_IDXFilename[3], "slot 3 idx")
    TestHelper.assertEquals("mods/mingdong/save/r1.grp", CC.R_GRPFilename[1], "slot 1 grp")
    TestHelper.assertEquals("mods/mingdong/save/s2.grp", CC.S_Filename[2], "slot 2 s")
    TestHelper.assertEquals("mods/mingdong/save/d3.grp", CC.D_Filename[3], "slot 3 d")
end

function TestModData.testSeedSaveSlotNoActive()
    print("\n=== Test: SeedSaveSlot seeds from template (vanilla) ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    local existsSet = { ["data/ranger.idx"] = true }
    local written = {}
    ModData.exists = function(p) return existsSet[p] == true end
    ModData.readFileRaw = function(p) return p == "data/ranger.idx" and "IDXDATA" or nil end
    ModData.writeFileRaw = function(p, d) written[p] = d; return true end
    local target = ModData.SeedSaveSlot(1)
    TestHelper.assertEquals("save/r1.idx", target, "seeded target path")
    TestHelper.assertEquals("IDXDATA", written["save/r1.idx"], "seeded content")
end

function TestModData.testSeedSaveSlotPrefersModRanger()
    print("\n=== Test: SeedSaveSlot prefers MOD ranger.idx over vanilla rN.idx ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    -- 两个候选都存在，且内容不同；必须选 MOD ranger.idx
    local existsSet = { ["mods/mingdong/data/ranger.idx"] = true, ["data/r1.idx"] = true }
    local written = {}
    ModData.exists = function(p) return existsSet[p] == true end
    ModData.readFileRaw = function(p)
        if p == "mods/mingdong/data/ranger.idx" then return "MOD_RANGER_IDX" end
        if p == "data/r1.idx" then return "VANILLA_R1_IDX" end
        return nil
    end
    ModData.writeFileRaw = function(p, d) written[p] = d; return true end
    local target = ModData.SeedSaveSlot(1)
    TestHelper.assertEquals("mods/mingdong/save/r1.idx", target, "MOD save target")
    TestHelper.assertEquals("MOD_RANGER_IDX", written["mods/mingdong/save/r1.idx"],
        "seeded from MOD ranger.idx (NOT vanilla r1.idx)")
end

function TestModData.testSeedSaveSlotSkipsExisting()
    print("\n=== Test: SeedSaveSlot is a no-op when target exists ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.exists = function(p) return p == "mods/mingdong/save/r1.idx" end
    ModData.writeFileRaw = function() error("should not write") end
    TestHelper.assertNil(ModData.SeedSaveSlot(1), "no-op when target exists")
end

function TestModData.testSeedSaveSlotIgnoresIdZero()
    print("\n=== Test: SeedSaveSlot ignores slot 0 ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    TestHelper.assertNil(ModData.SeedSaveSlot(0), "slot 0 not seeded")
    TestHelper.assertNil(ModData.SeedSaveSlot(-1), "negative id not seeded")
end

-- 合成键：用于构建期未转换（纯 ASCII）的字符串字段。
-- 这类字段的缓冲区里存的是原文而非 hint，写入 UTF-8 会被定长字段截断，
-- 因此改用 "!<seg>.<prefix>.<byteOffset>" 作为覆盖表键。
function TestModData.testSyntheticKeyFormat()
    print("\n=== Test: SyntheticKey 格式（ASCII 安全）===")
    local ModData = freshModData()
    -- 字段名用 MOD_STRINGS 的中文键（与 IdentifyStringField 的返回值一致）
    TestHelper.assertEquals("!Person.P.0", ModData.SyntheticKey("Person", "姓名", 0),
        "Person.姓名 @0")
    TestHelper.assertEquals("!Person.N.364", ModData.SyntheticKey("Person", "外号", 364),
        "Person.外号 @364")
    TestHelper.assertEquals("!Thing.T2.190", ModData.SyntheticKey("Thing", "名称2", 190),
        "Thing.名称2 @190")
    TestHelper.assertEquals("!Thing.TD.0", ModData.SyntheticKey("Thing", "物品说明", 0),
        "Thing.物品说明 @0")
    TestHelper.assertEquals("!Scene.S.52", ModData.SyntheticKey("Scene", "名称", 52),
        "Scene.名称 @52")
    TestHelper.assertEquals("!Wugong.W.136", ModData.SyntheticKey("Wugong", "名称", 136),
        "Wugong.名称 @136")
    -- 键必须全为 ASCII（旧实现用中文字段名，导致覆盖表解析正则失配）
    local k = ModData.SyntheticKey("Person", "姓名", 0)
    TestHelper.assertTrue(k:match("^[\128-\255]") == nil, "key has no non-ASCII leading byte")
    -- 逐字节判定纯 ASCII：不能用 [\0-\127] 这样的字符类 —— Lua 5.1 的
    -- pattern 按 C 字符串处理，模式里的 NUL 会截断，直接报 "missing ']'"。
    local pureAscii = true
    for i = 1, #k do
        if k:byte(i) > 127 then pureAscii = false break end
    end
    TestHelper.assertTrue(pureAscii, "key is pure ASCII")
    -- 未知字段返回 nil
    TestHelper.assertNil(ModData.SyntheticKey("Person", "不存在", 0), "unknown field -> nil")
    TestHelper.assertNil(ModData.SyntheticKey(nil, "姓名", 0), "nil seg -> nil")
end

-- Big5 表必须包含 CP950 扩展码位（f9xx 段 + a3e1）。
-- 回归：早期表由 plain big5 生成，缺少 42 个 CP950 码位，
-- 导致 ranger.grp 中「恒山」等字被解码为 U+FFFD（全 20 MOD 共 87 个字段）。
function TestModData.testBig5TableCoversCp950Extensions()
    print("\n=== Test: Big5 表覆盖 CP950 扩展码位 ===")
    local tbl = dofile("tools/mod_big5_trad.lua")
    -- 关键回归点：f9da = 恒（恒山掌門），曾缺失
    TestHelper.assertEquals("恒", tbl[0xf9da], "0xf9da -> 恒")
    TestHelper.assertEquals("嵩", tbl[0xb743], "0xb743 -> 嵩")
    TestHelper.assertEquals("€", tbl[0xa3e1], "0xa3e1 -> €")
    -- 整段 f9xx 扩展必须存在
    TestHelper.assertNotNil(tbl[0xf9d6], "0xf9d6 present")
    TestHelper.assertNotNil(tbl[0xf9fc], "0xf9fc present")
    -- 表规模下界（13710 基础 + 42 扩展）
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    TestHelper.assertTrue(n >= 13752, "table has >= 13752 entries, got " .. n)
end

-- 端到端：恒山掌門 的原始字节必须解码为正确 UTF-8（而非 U+FFFD）。
function TestModData.testDecodeBig5Cp950Extension()
    print("\n=== Test: DecodeBig5 解码 CP950 扩展字符 ===")
    local ok, enc = pcall(require, "tools.mod_encoding")
    if not ok then
        TestHelper.assertTrue(true, "mod_encoding not loadable in this env (skip)")
        return
    end
    -- f9da a473 b478 aaf9 = 恒山掌門
    local raw = string.char(0xf9, 0xda, 0xa4, 0x73, 0xb4, 0x78, 0xaa, 0xf9)
    local got = enc.DecodeBig5(raw)
    TestHelper.assertEquals("恒山掌門", got, "恒山掌門 decodes exactly")
    TestHelper.assertTrue(got:find("\239\191\189", 1, true) == nil, "no U+FFFD in result")
end

-- IdentifyStringField：由结构表偏移反查段名与字段名
function TestModData.testIdentifyStringField()
    print("\n=== Test: IdentifyStringField 反查 ===")
    local ModData = freshModData()
    local seg, field = ModData.IdentifyStringField(8)
    TestHelper.assertEquals("Person", seg, "offset 8 -> Person")
    TestHelper.assertEquals("姓名", field, "offset 8 -> 姓名")
    local s2, f2 = ModData.IdentifyStringField(18)
    TestHelper.assertEquals("Person", s2, "offset 18 -> Person")
    TestHelper.assertEquals("外号", f2, "offset 18 -> 外号")
    local s3, f3 = ModData.IdentifyStringField(42)
    TestHelper.assertEquals("Thing", s3, "offset 42 -> Thing")
    TestHelper.assertEquals("物品说明", f3, "offset 42 -> 物品说明")
    -- 非字符串字段偏移
    TestHelper.assertNil(ModData.IdentifyStringField(1000), "unknown offset -> nil")
    TestHelper.assertNil(ModData.IdentifyStringField(nil), "nil offset -> nil")
end

-- SaveOverrides 解析：必须能读回合成键（含中文值）
function TestModData.testSaveOverridesParsesSyntheticKeys()
    print("\n=== Test: SaveOverrides 解析合成键 ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.EnsureSaveDir()
    local dir = ModData.SaveDir()
    local path = dir .. "r9.ovr"
    -- 混合真实 hint 与合成键，值含 UTF-8 中文
    local body = "P0000=胡斐\n!Person.P.182=自检改名\nTD0007=活性飲料"
    ModData.writeFileRaw(path, body)
    local ovr = ModData.SaveOverrides(9)
    TestHelper.assertEquals("胡斐", ovr["P0000"], "真实 hint 键")
    TestHelper.assertEquals("自检改名", ovr["!Person.P.182"], "合成键")
    TestHelper.assertEquals("活性飲料", ovr["TD0007"], "Thing 说明 hint 键")
    os.remove(path)
end

-- ============================================================
-- REQ-MIDI-2: MOD 自带 MIDI 音乐重定向
-- ============================================================

function TestModData.testRewriteAudioMidiRedirect()
    print("\n=== Test: MIDIFile redirects to modules music dir when .mid present ===")
    local ModData = freshModData()
    ModData.SetActive("mingdong")
    ModData.dirExists = function(path) return path == "mods/mingdong/music/" end
    ModData.listDir = function(dir, pattern)
        if dir ~= "mods/mingdong/music/" then return {} end
        if pattern == "^game%d+%.mid$" then return { "game02.mid", "game27.mid" } end
        return {}
    end
    local CC = {
        MIDIFile = "sound/game%02d.ogg",
        ATKFile = "sound/atk%02d.wav",
        EFile = "sound/e%02d.wav",
    }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/", SoundPath = "sound/" })
    -- 扩展名必须被去掉，交给 lib.PlayMIDI 按 .ogg/.mid/.mp3 探测
    TestHelper.assertEquals("mods/mingdong/music/game%02d", CC.MIDIFile,
        "MIDIFile -> MOD music dir, .ogg suffix stripped")
    TestHelper.assertEquals("mods/mingdong/music/game27",
        string.format(CC.MIDIFile, 27), "id 26 formats to game27")
    TestHelper.assertEquals("mods/mingdong/music/game82",
        string.format(CC.MIDIFile, 82), "id 81 formats to game82 (min-width, not game082)")
    -- 音效常量不受影响（该 MOD 无 sound/ 匹配文件）
    TestHelper.assertEquals("sound/atk%02d.wav", CC.ATKFile, "ATKFile not touched")
end

function TestModData.testRewriteAudioMidiNoMidNoRedirect()
    print("\n=== Test: MIDIFile untouched when MOD ships no .mid ===")
    local ModData = freshModData()
    ModData.SetActive("pascal")
    ModData.dirExists = function(path) return path == "mods/pascal/music/" end
    ModData.listDir = function() return {} end   -- 目录存在但无 game*.mid
    local CC = { MIDIFile = "sound/game%02d.ogg",
                 ATKFile = "sound/atk%02d.wav", EFile = "sound/e%02d.wav" }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/", SoundPath = "sound/" })
    TestHelper.assertEquals("sound/game%02d.ogg", CC.MIDIFile,
        "negative control: no .mid => no redirect")
end

function TestModData.testRewriteAudioMidiNoActiveIsNoop()
    print("\n=== Test: no active MOD => MIDIFile byte-identical (vanilla zero-regression) ===")
    local ModData = freshModData()
    ModData.SetActive(nil)
    ModData.dirExists = function() return true end
    ModData.listDir = function() return { "game02.mid" } end   -- 即使有文件也不该动
    local CC = { MIDIFile = "sound/game%02d.ogg",
                 ATKFile = "sound/atk%02d.wav", EFile = "sound/e%02d.wav" }
    ModData.RewriteConstants(CC, { DataPath = "data/", ScriptPath = "script/", SoundPath = "sound/" })
    TestHelper.assertEquals("sound/game%02d.ogg", CC.MIDIFile,
        "vanilla: MIDIFile unchanged")
    TestHelper.assertEquals("sound/atk%02d.wav", CC.ATKFile, "vanilla: ATKFile unchanged")
    TestHelper.assertEquals("sound/e%02d.wav", CC.EFile, "vanilla: EFile unchanged")
end


-- ============================================================
-- 音乐扩展名探测顺序：.ogg -> .mp3 -> .mid
--
-- 顺序本身是行为契约：MOD 的 music/ 目录可能同时存在标源 .mid 和
-- 预渲染 .ogg（用真实 SoundFont 渲染）。LÖVE 自带 libmodplug 忽略
-- SoundFont，会把 .mid 渲染成高频能量高约 2.1 倍的刺耳音色，所以
-- 预渲染 .ogg 必须优先；.mid 排最后，仅作为尚未渲染时的兜底。
-- ============================================================

local function readLoveSource()
    local f = io.open("engine-love2d/lib_love.lua", "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

function TestModData.testMusicExtProbeOrderIsOggMp3Mid()
    print("\n=== Test: MUSIC_EXTS 顺序为 .ogg,.mp3,.mid ===")
    local src = readLoveSource()
    TestHelper.assertNotNil(src, "lib_love.lua 可读")
    -- 精确提取 MUSIC_EXTS 表字面量，避免宽松匹配
    local order = src:match("MUSIC_EXTS%s*=%s*{%s*([^}]+)}")
    TestHelper.assertNotNil(order, "MUSIC_EXTS 定义存在")
    local exts = {}
    for e in order:gmatch('"([^"]+)"') do exts[#exts + 1] = e end
    TestHelper.assertEquals(3, #exts, "MUSIC_EXTS 恰好 3 个扩展名")
    TestHelper.assertEquals(".ogg", exts[1], "第 1 优先：.ogg（预渲染）")
    TestHelper.assertEquals(".mp3", exts[2], "第 2 优先：.mp3")
    TestHelper.assertEquals(".mid", exts[3], "第 3 优先（最后）：.mid 兜底")
end

function TestModData.testMusicExtProbeOrderMidNotFirst()
    print("\n=== Test: .mid 不得排在第一位（负向守门） ===")
    local src = readLoveSource()
    local order = src:match("MUSIC_EXTS%s*=%s*{%s*([^}]+)}")
    TestHelper.assertNotNil(order, "MUSIC_EXTS 定义存在")
    local first = order:match('"([^"]+)"')
    TestHelper.assertTrue(first ~= ".mid",
        "第一个探测的扩展名不能是 .mid（否则预渲染 ogg 失效）")
end

function TestModData.testMusicExtProbeOrderHasNoDuplicates()
    print("\n=== Test: MUSIC_EXTS 无重复且无空项 ===")
    local src = readLoveSource()
    local order = src:match("MUSIC_EXTS%s*=%s*{%s*([^}]+)}")
    local seen, n = {}, 0
    for e in order:gmatch('"([^"]+)"') do
        TestHelper.assertTrue(e:sub(1, 1) == ".", "扩展名以点开头: " .. e)
        TestHelper.assertNil(seen[e], "扩展名不重复: " .. e)
        seen[e] = true; n = n + 1
    end
    TestHelper.assertEquals(3, n, "共 3 项")
end

function TestModData.runAll()
    print("\n" .. string.rep("=", 60))
    print("ModData 单元测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestModData.testResolveNoActiveReturnsOriginal()
    TestModData.testResolveModHit()
    TestModData.testResolveModMissFallsBack()
    TestModData.testResolveAcceptsBareFilename()
    TestModData.testScriptFileNoActive()
    TestModData.testScriptFileModHit()
    TestModData.testScriptFileFallback()
    TestModData.testFightFilesUsesModWhenPresent()
    TestModData.testFightFilesFallsBackToData()
    TestModData.testFightFilesNoActiveUsesData()
    TestModData.testRewriteConstantsNoActiveIsNoop()
    TestModData.testRewriteConstantsRedirectsOnHit()
    TestModData.testRewriteConstantsCloudPicFile()
    TestModData.testRewriteConstantsFightPicFormat()
    TestModData.testRewriteConstantsScriptPath()
    TestModData.testRewriteAudioNoActiveIsNoop()
    TestModData.testRewriteAudioModHit()
    TestModData.testRewriteAudioNoSoundDirFallsBack()
    TestModData.testRewriteAudioMidiRedirect()
    TestModData.testRewriteAudioMidiNoMidNoRedirect()
    TestModData.testRewriteAudioMidiNoActiveIsNoop()
    TestModData.testRewriteConstantsSmapAliasTarget()
    TestModData.testDirExistsFunction()
    TestModData.testSetActiveNormalizesSlug()
    TestModData.testActiveReadsFile()
    TestModData.testActiveSkipsCommentAndBlankLines()
    TestModData.testActiveAllCommentsMeansVanilla()
    TestModData.testActiveModSampleFileWorks()
    TestModData.testWarRecordCount()
    TestModData.testSaveDirNoActive()
    TestModData.testSaveDirModActive()
    TestModData.testRewriteSaveSlotsNoActive()
    TestModData.testRewriteSaveSlotsModActive()
    TestModData.testSeedSaveSlotNoActive()
    TestModData.testSeedSaveSlotPrefersModRanger()
    TestModData.testSeedSaveSlotSkipsExisting()
    TestModData.testSeedSaveSlotIgnoresIdZero()
    TestModData.testSyntheticKeyFormat()
    TestModData.testIdentifyStringField()
    TestModData.testSaveOverridesParsesSyntheticKeys()
    TestModData.testBig5TableCoversCp950Extensions()
    TestModData.testDecodeBig5Cp950Extension()
    TestModData.testMusicExtProbeOrderIsOggMp3Mid()
    TestModData.testMusicExtProbeOrderMidNotFirst()
    TestModData.testMusicExtProbeOrderHasNoDuplicates()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestModData
