-- test_format_spec.lua -- 格式字段级覆盖测试
--
-- 对应 allmods-slice0c-format-spec 的 REQ-FMT-1..7

local TestHelper = require("tests.test_helper")

package.path = "./?.lua;" .. package.path
local FS = require("tools.format_spec")

local T = {}

local REF = "../reference/allmods"

-- 缓存全量结果（6773 项，避免重复遍历）
local _all = nil
local function all()
    if not _all then
        local res, total, bad = FS.verifyEverything()
        _all = { results = res, total = total, bad = bad }
    end
    return _all
end

-- ============================================================
-- REQ-FMT-1: 字段表完整覆盖，无缺口
-- ============================================================

function T.testHdgrpCoverage()
    print("\n=== Test: hdgrp 覆盖完整 ===")
    local idx = REF .. "/kys-pascal/resource/hdgrp.idx"
    local grp = REF .. "/kys-pascal/resource/hdgrp.grp"
    TestHelper.assertEquals(460, FS.fileSize(idx), "hdgrp.idx = 460")
    TestHelper.assertEquals(249276, FS.fileSize(grp), "hdgrp.grp = 249276")
    local r = FS.verifyPair(idx, grp)
    TestHelper.assertTrue(r.ok, "覆盖 ok")
    TestHelper.assertEquals(0, #r.gaps, "无缺口")
    TestHelper.assertEquals(0, #r.overlaps, "无重叠")
    TestHelper.assertEquals(249276, r.covered, "覆盖到文件末尾")
    TestHelper.assertEquals(115, r.idx_count, "115 项 offset")
    TestHelper.assertEquals(0, r.idx_tail, "idx 无残余字节")
end

function T.testAllModsHdgrpCoverage()
    print("\n=== Test: 20 MOD 的 hdgrp 均覆盖完整 ===")
    local n, bad = 0, 0
    local p = io.popen("ls -d " .. REF .. "/kys-*")
    for m in p:lines() do
        n = n + 1
        local r = FS.verifyPair(m .. "/resource/hdgrp.idx", m .. "/resource/hdgrp.grp")
        if not r.ok then
            bad = bad + 1
            print("  FAIL " .. m:match("([^/]+)$"))
        end
    end
    p:close()
    TestHelper.assertEquals(20, n, "20 个 MOD")
    TestHelper.assertEquals(0, bad, "20/20 覆盖完整")
end

function T.testGridCoverage()
    print("\n=== Test: earth.002 定长网格覆盖 ===")
    local path = REF .. "/kys-pascal/resource/earth.002"
    TestHelper.assertEquals(460800, FS.fileSize(path), "大小 460800")
    local r = FS.verifyGrid(path, 2)
    TestHelper.assertTrue(r.ok, "覆盖 ok")
    TestHelper.assertEquals(230400, r.cells, "230400 个 uint16 单元")
    TestHelper.assertEquals(0, #r.gaps, "无缺口")
    -- 460800 = MWidth(480) × MHeight(480) × 2
    TestHelper.assertEquals(480 * 480, r.cells, "480×480")
end

function T.testIdxTailIsZero()
    print("\n=== Test: 主要格式 tail == 0 ===")
    local cases = {
        { "hdgrp", "resource/hdgrp.idx", "resource/hdgrp.grp" },
        { "eft", "resource/eft.idx", "resource/eft.grp" },
        { "warfld", "resource/warfld.idx", "resource/warfld.grp" },
        { "cloud", "resource/cloud.idx", "resource/cloud.grp" },
        { "title", "resource/title.idx", "resource/title.grp" },
        { "talk", "resource/talk.idx", "resource/talk.grp" },
        { "kdef", "resource/kdef.idx", "resource/kdef.grp" },
    }
    for _, c in ipairs(cases) do
        local r = FS.verifyPair(REF .. "/kys-pascal/" .. c[2],
                                REF .. "/kys-pascal/" .. c[3])
        TestHelper.assertTrue(r.ok, c[1] .. " ok")
        TestHelper.assertEquals(0, r.idx_tail, c[1] .. " idx_tail=0")
    end
end

-- ============================================================
-- REQ-FMT-2: 缺口必须被报告（4 个负例）
-- ============================================================

function T.testGapDetected()
    print("\n=== Test: 中段缺口被检测 ===")
    local iv = { { start = 0, stop = 100 }, { start = 200, stop = 300 } }
    local r = FS.verifyIntervals(iv, 300)
    TestHelper.assertTrue(not r.ok, "不 ok")
    TestHelper.assertEquals(1, #r.gaps, "1 个缺口")
    TestHelper.assertEquals(100, r.gaps[1].start, "缺口起 100")
    TestHelper.assertEquals(200, r.gaps[1]["end"], "缺口止 200")
end

function T.testOverlapDetected()
    print("\n=== Test: 重叠被检测 ===")
    local iv = { { start = 0, stop = 150 }, { start = 100, stop = 300 } }
    local r = FS.verifyIntervals(iv, 300)
    TestHelper.assertTrue(not r.ok, "不 ok")
    TestHelper.assertEquals(1, #r.overlaps, "1 处重叠")
    TestHelper.assertEquals(100, r.overlaps[1].start, "重叠起 100")
    TestHelper.assertEquals(150, r.overlaps[1]["end"], "重叠止 150")
end

function T.testStartGapDetected()
    print("\n=== Test: 起始缺口被检测 ===")
    local iv = { { start = 10, stop = 300 } }
    local r = FS.verifyIntervals(iv, 300)
    TestHelper.assertTrue(not r.ok, "不 ok")
    TestHelper.assertEquals(1, #r.gaps, "1 个缺口")
    TestHelper.assertEquals(0, r.gaps[1].start, "缺口起 0")
    TestHelper.assertEquals(10, r.gaps[1]["end"], "缺口止 10")
end

function T.testTailGapDetected()
    print("\n=== Test: 尾部缺口被检测 ===")
    local iv = { { start = 0, stop = 295 } }
    local r = FS.verifyIntervals(iv, 300)
    TestHelper.assertTrue(not r.ok, "不 ok")
    TestHelper.assertEquals(1, #r.gaps, "1 个缺口")
    TestHelper.assertEquals(295, r.gaps[1].start, "缺口起 295")
    TestHelper.assertEquals(300, r.gaps[1]["end"], "缺口止 300")
end

function T.testPerfectCoverageOk()
    print("\n=== Test: 完整覆盖 ok ===")
    local iv = { { start = 0, stop = 100 }, { start = 100, stop = 300 } }
    local r = FS.verifyIntervals(iv, 300)
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(0, #r.gaps, "无缺口")
    TestHelper.assertEquals(0, #r.overlaps, "无重叠")
end

-- ============================================================
-- REQ-FMT-3: 变长记录族
-- ============================================================

function T.testRleRecordsExpanded()
    print("\n=== Test: RLE 记录由 offset 表展开 ===")
    local r = FS.verifyPair(REF .. "/kys-pascal/resource/hdgrp.idx",
                            REF .. "/kys-pascal/resource/hdgrp.grp")
    TestHelper.assertEquals(115, r.idx_count, "115 个区间")
    TestHelper.assertEquals(249276, r.covered, "Σ == grpsize")
end

function T.testTalkCoverage()
    print("\n=== Test: talk 文本格式 ===")
    local idx = REF .. "/kys-pascal/resource/talk.idx"
    local grp = REF .. "/kys-pascal/resource/talk.grp"
    TestHelper.assertEquals(11908, FS.fileSize(idx), "talk.idx = 11908")
    TestHelper.assertEquals(186513, FS.fileSize(grp), "talk.grp = 186513")
    local r = FS.verifyPair(idx, grp)
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(2977, r.idx_count, "2977 项")
    TestHelper.assertEquals(0, r.idx_tail, "tail=0")
end

function T.testKdefCoverage()
    print("\n=== Test: kdef 指令流格式 ===")
    local idx = REF .. "/kys-pascal/resource/kdef.idx"
    local grp = REF .. "/kys-pascal/resource/kdef.grp"
    TestHelper.assertEquals(4072, FS.fileSize(idx), "kdef.idx = 4072")
    TestHelper.assertEquals(121214, FS.fileSize(grp), "kdef.grp = 121214")
    local r = FS.verifyPair(idx, grp)
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(1018, r.idx_count, "1018 项")
    TestHelper.assertEquals(0, r.idx_tail, "tail=0")
end

function T.testBareIdxCoverage()
    print("\n=== Test: 无 .idx 后缀的 offset 表（sdx/smp）===")
    local idx = REF .. "/kys-pascal/resource/sdx"
    local grp = REF .. "/kys-pascal/resource/smp"
    TestHelper.assertEquals(17472, FS.fileSize(idx), "sdx = 17472")
    TestHelper.assertEquals(4349778, FS.fileSize(grp), "smp = 4349778")
    local r = FS.verifyPair(idx, grp)
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(4368, r.idx_count, "4368 项")
    TestHelper.assertEquals(0, r.idx_tail, "tail=0")
    -- wdx/wmp
    local r2 = FS.verifyPair(REF .. "/kys-pascal/resource/wdx",
                             REF .. "/kys-pascal/resource/wmp")
    TestHelper.assertTrue(r2.ok, "wmap ok")
    TestHelper.assertEquals(3701, r2.idx_count, "3701 项")
end

-- ============================================================
-- REQ-FMT-4: 多段 offset 表被识别
-- ============================================================

function T.testMmapTwoSegments()
    print("\n=== Test: mmap 两段 offset 表 ===")
    local idx = REF .. "/kys-pascal/resource/mmap.idx"
    TestHelper.assertEquals(34924, FS.fileSize(idx), "mmap.idx = 34924")
    local d = FS.readFile(idx)
    local n = #d / 4
    TestHelper.assertEquals(8731, n, "8731 项")
    TestHelper.assertEquals((3731 + 5000) * 4, 34924, "3731 + 5000 段")
end

function T.testMmapCoverage()
    print("\n=== Test: mmap 覆盖完整 ===")
    local r = FS.verifyPair(REF .. "/kys-pascal/resource/mmap.idx",
                            REF .. "/kys-pascal/resource/mmap.grp",
                            { segments = { { offset = 0, count = 3731 } } })
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(0, #r.gaps, "无缺口")
    -- idx_count 为整个 idx 的项数；段数由 readOffsets 限定
    TestHelper.assertEquals(8731, r.idx_count, "idx 共 8731 项")
    local offs = FS.readOffsets(FS.readFile(REF .. "/kys-pascal/resource/mmap.idx"),
                                { { offset = 0, count = 3731 } })
    TestHelper.assertEquals(3731, #offs, "seg1 段 3731 项")
end

function T.testMmapSeg1CoversGrp()
    print("\n=== Test: mmap seg1 恰好覆盖 grp ===")
    local idx = REF .. "/kys-pascal/resource/mmap.idx"
    local grp = REF .. "/kys-pascal/resource/mmap.grp"
    local offs = FS.readOffsets(FS.readFile(idx), { { offset = 0, count = 3731 } })
    local grpsize = FS.fileSize(grp)
    TestHelper.assertEquals(grpsize, offs[#offs], "seg1 末项 == grpsize（tail=0）")
    -- seg1 必须单调递增
    local mono = true
    for i = 2, #offs do if offs[i] < offs[i - 1] then mono = false break end end
    TestHelper.assertTrue(mono, "seg1 单调递增")
end

-- ============================================================
-- REQ-FMT-5: 字段元数据
-- ============================================================

function T.testConsumerSymbolsResolve()
    print("\n=== Test: consumer 指向真实符号 ===")
    -- 每项: { 标注名, 文件, 必须出现的源码片段, 是否要求是导出符号 }
    -- 最后一项 kdef 是构建期 local 函数，不要求导出（consumer 标注已显式声明 build-time/local）
    local symbols = {
        { "lib_love.PicLoadFile", "engine-love2d/lib_love.lua", "function PicLoadFile", true },
        { "jymain.ReadTalk",      "script/jymain.lua",          "ReadTalk",              true },
        { "lib_love.LoadSMap",    "engine-love2d/lib_love.lua", "function LoadSMap",     true },
        { "lib_love.LoadWarMap",  "engine-love2d/lib_love.lua", "function LoadWarMap",   true },
        { "jymain.LoadRecord",    "script/jymain.lua",          "LoadRecord",            true },
        { "jymain.WarLoad",       "script/jymain.lua",          "WarLoad",               true },
        { "lib_love.LoadMMap_Sub","engine-love2d/lib_love.lua", "function LoadMMap_Sub", true },
        { "mod_build.extractKdef","tools/mod_build.lua",        "local function extractKdef", false },
    }
    for _, s in ipairs(symbols) do
        local d = FS.readFile(s[2])
        TestHelper.assertNotNil(d, s[2] .. " 可读")
        TestHelper.assertTrue(d:find(s[3], 1, true) ~= nil,
            s[1] .. " -> " .. s[3])
        -- 鉴别力：要求导出的 consumer，源码里的定义不能是 local function
        if s[4] then
            local shortName = s[1]:match("%.(.+)$") or s[1]
            local localDecl = "local function " .. shortName
            TestHelper.assertNil(d:find(localDecl, 1, true),
                s[1] .. " 不得是 local 函数（consumer 标注为可调用导出符号）")
        end
    end
end

function T.testFormatsHaveConsumer()
    print("\n=== Test: 每个格式声明 consumer ===")
    for _, f in ipairs(FS.FORMATS) do
        TestHelper.assertNotNil(f.consumer, f.name .. " 有 consumer")
        TestHelper.assertTrue(#f.consumer > 0, f.name .. " consumer 非空")
    end
    for _, f in ipairs(FS.SIMPLE_FORMATS) do
        TestHelper.assertNotNil(f.consumer, f.name .. " 有 consumer")
    end
end

-- ============================================================
-- REQ-FMT-6: 20 MOD 全覆盖
-- ============================================================

function T.testVerifyAllNoGaps()
    print("\n=== Test: 全量验证无缺口 ===")
    local a = all()
    TestHelper.assertEquals(0, a.bad, "gaps=0")
    TestHelper.assertTrue(a.total > 6000, "checked > 6000（" .. a.total .. "）")
end

function T.testFormatFamiliesPresent()
    print("\n=== Test: 覆盖的格式族齐全 ===")
    local a = all()
    local fams = {}
    for _, r in ipairs(a.results) do fams[r.family or "?"] = true end
    local expect = { "idx_grp_rle", "wav_pcm", "png_image", "bin_table" }
    for _, f in ipairs(expect) do
        TestHelper.assertTrue(fams[f], "含格式族 " .. f)
    end
    local n = 0
    for _ in pairs(fams) do n = n + 1 end
    TestHelper.assertTrue(n >= 4, "格式族数 >= 4（" .. n .. "）")
end

function T.testAllFormatsCheckedForAllMods()
    print("\n=== Test: 每个格式对每个 MOD 都被检查 ===")
    local a = all()
    local byMod = {}
    for _, r in ipairs(a.results) do byMod[r.mod] = (byMod[r.mod] or 0) + 1 end
    local n = 0
    for _, c in pairs(byMod) do
        n = n + 1
        TestHelper.assertTrue(c > 100, "MOD 检查项 > 100")
    end
    TestHelper.assertEquals(20, n, "20 个 MOD")
end

-- ============================================================
-- 关键数据事实（防回归）
-- ============================================================

function T.testWarStaRecordCountsVary()
    print("\n=== Test: war.sta 记录数随 MOD 变化 ===")
    local counts = {}
    local p = io.popen("ls -d " .. REF .. "/kys-*")
    for m in p:lines() do
        local path = m .. "/resource/war.sta"
        if FS.fileSize(path) then
            local r = FS.verifyFixedRecords(path, 186)
            TestHelper.assertTrue(r.ok, m:match("([^/]+)$") .. " war.sta 覆盖 ok")
            counts[r.records] = true
        end
    end
    p:close()
    local n = 0
    for _ in pairs(counts) do n = n + 1 end
    TestHelper.assertTrue(n > 1, "记录数非固定（" .. n .. " 种）")
    -- pascal 恰好 140
    local rp = FS.verifyFixedRecords(REF .. "/kys-pascal/resource/war.sta", 186)
    TestHelper.assertEquals(140, rp.records, "pascal war.sta = 140 × 186")
end

function T.testEmptyWavsHandled()
    print("\n=== Test: 空 wav 被显式归类 ===")
    local r = FS.verifyWav(REF .. "/kys-RiverLake/sound/e71.wav")
    TestHelper.assertTrue(r.ok, "空 wav ok")
    TestHelper.assertTrue(r.empty, "标记 empty")
    TestHelper.assertEquals(0, r.filesize, "0 字节")
end

function T.testWavWithTrailingMetadata()
    print("\n=== Test: data 之后的元数据块被覆盖 ===")
    -- BookCalamity e167.wav 在 data 之后有 LIST/INFO/ICMT
    local r = FS.verifyWav(REF .. "/kys-BookCalamity/sound/e167.wav")
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(0, #r.gaps, "无缺口（含尾部元数据）")
    TestHelper.assertTrue(r.chunks > 2, "chunk 数 > 2（" .. r.chunks .. "）")
end

function T.testOrphanFightIdxIsDeadFile()
    print("\n=== Test: 孤儿 fight idx 归类为死文件 ===")
    local results, orphans = FS.verifyFightDir(REF .. "/kys-dream")
    local found = false
    for _, r in ipairs(results) do
        if r.orphan_idx and r.name == "fight23" then found = true end
    end
    TestHelper.assertTrue(found, "dream/fight23.idx 无配对 grp")
    -- BookCalamity
    local r2 = FS.verifyFightDir(REF .. "/kys-BookCalamity")
    local found2 = false
    for _, r in ipairs(r2) do
        if r.orphan_idx and r.name == "fight915" then found2 = true end
    end
    TestHelper.assertTrue(found2, "BookCalamity/fight915.idx 无配对 grp")
    -- awaken 有孤儿 grp（无配对 idx）
    local r3, orphans3 = FS.verifyFightDir(REF .. "/kys-awaken")
    local found3 = false
    for _, g in ipairs(orphans3) do
        if g:find("fight099_02", 1, true) then found3 = true end
    end
    TestHelper.assertTrue(found3, "awaken/fight099_02.grp 无配对 idx")
end

function T.testRangerBothLayouts()
    print("\n=== Test: ranger 两种布局都被覆盖 ===")
    -- MOD 布局（pascal）
    local rm = FS.verifyRanger(REF .. "/kys-pascal/save/ranger.idx",
                               REF .. "/kys-pascal/save/ranger.grp")
    TestHelper.assertTrue(rm.ok, "MOD ranger 覆盖 ok")
    TestHelper.assertEquals(182, rm.segments[1].delta / rm.segments[1].mod_count,
        "MOD Person rec=182")
    TestHelper.assertEquals(190, rm.segments[2].delta / rm.segments[2].mod_count,
        "MOD Thing rec=190")
    -- 原版布局
    local rv = FS.verifyRanger("data/ranger.idx", "data/ranger.grp")
    TestHelper.assertTrue(rv.ok, "原版 ranger 覆盖 ok")
    TestHelper.assertEquals(202, rv.segments[1].delta / rv.segments[1].vanilla_count,
        "原版 Person rec=202")
    TestHelper.assertEquals(260, rv.segments[2].delta / rv.segments[2].vanilla_count,
        "原版 Thing rec=260")
end

function T.testRangerIdxIsSixOffsets()
    print("\n=== Test: ranger.idx = 6 × uint32 ===")
    local d = FS.readFile(REF .. "/kys-pascal/save/ranger.idx")
    TestHelper.assertEquals(24, #d, "24 字节")
    local offs = {}
    for i = 0, 5 do offs[#offs + 1] = FS.u32(d, i * 4) end
    local mono = true
    for i = 2, #offs do if offs[i] < offs[i - 1] then mono = false end end
    TestHelper.assertTrue(mono, "6 个 offset 单调递增")
    TestHelper.assertEquals(836, offs[1], "头部 836 字节")
end

function T.testPaletteCoverage()
    print("\n=== Test: mmap.col 调色板 ===")
    local r = FS.verifyPalette(REF .. "/kys-pascal/resource/mmap.col")
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(768, r.filesize, "768 字节")
    TestHelper.assertEquals(256, r.colors, "256 色 × RGB")
end

function T.testKysmodIniCoverage()
    print("\n=== Test: kysmod.ini 按行覆盖 ===")
    local r = FS.verifyText(REF .. "/kys-pascal/kysmod.ini")
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(0, #r.gaps, "无缺口")
    TestHelper.assertTrue(r.lines > 10, "行数 > 10（" .. r.lines .. "）")
end

function T.testPngAllCovered()
    print("\n=== Test: PNG 全部覆盖 ===")
    local a = all()
    local n, bad = 0, 0
    for _, r in ipairs(a.results) do
        if r.format == "png" then
            n = n + 1
            if not r.ok then bad = bad + 1 end
        end
    end
    TestHelper.assertTrue(n > 1000, "PNG 数 > 1000（" .. n .. "）")
    TestHelper.assertEquals(0, bad, "全部覆盖")
end

function T.testSoundAllCovered()
    print("\n=== Test: sound 全部覆盖 ===")
    local a = all()
    local n, bad, empty = 0, 0, 0
    for _, r in ipairs(a.results) do
        if r.format == "sound" then
            n = n + 1
            if r.empty then empty = empty + 1 end
            if not r.ok then bad = bad + 1 end
        end
    end
    TestHelper.assertTrue(n > 1900, "wav 数 > 1900（" .. n .. "）")
    TestHelper.assertEquals(0, bad, "全部覆盖")
    TestHelper.assertEquals(28, empty, "28 个空 wav（RiverLake）")
end

function T.testFightAllCovered()
    print("\n=== Test: fight 全部覆盖 ===")
    local a = all()
    local n, bad, dead = 0, 0, 0
    for _, r in ipairs(a.results) do
        if r.format == "fight" then
            n = n + 1
            if r.dead_file then dead = dead + 1 end
            if not r.ok then bad = bad + 1 end
        end
    end
    TestHelper.assertTrue(n > 3000, "fight 项 > 3000（" .. n .. "）")
    TestHelper.assertEquals(0, bad, "全部覆盖")
    TestHelper.assertEquals(3, dead,
        "3 个孤儿（dream/fight23.idx, BookCalamity/fight915.idx, awaken/fight099_02.grp）")
end

function T.testListBinCovered()
    print("\n=== Test: list/*.bin 覆盖（记录级 uint16）===")
    -- effect.bin = 128 字节 ⇒ 64 条 uint16 记录（REQ-LBIN-3）
    local r = FS.verifyBinTable(REF .. "/kys-pascal/list/effect.bin")
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(128, r.filesize, "128 字节")
    TestHelper.assertEquals(2, r.unit, "记录单位 = 2 字节（uint16）")
    TestHelper.assertEquals(64, r.records, "64 条 uint16 记录")
    TestHelper.assertEquals(0, r.tail, "无尾部残留")
    -- levelup.bin = 202 → 101 条记录，无尾巴（202 是偶数）
    local r2 = FS.verifyBinTable(REF .. "/kys-pascal/list/levelup.bin")
    TestHelper.assertTrue(r2.ok, "ok")
    TestHelper.assertEquals(101, r2.records, "101 条 uint16 记录")
    TestHelper.assertEquals(0, r2.tail, "202 字节 = 101×2，无尾巴")
end

-- REQ-LBIN-3：记录级语义的鉴别力对照（偶数/奇数/零字节）
function T.testBinTableEvenBytes()
    print("\n=== Test: .bin 偶数字节 ⇒ 完整记录 ===")
    local p = os.tmpname()
    local f = assert(io.open(p, "wb"))
    f:write(string.char(1, 2, 3, 4, 5, 6))   -- 3 × uint16
    f:close()
    local r = FS.verifyBinTable(p)
    TestHelper.assertTrue(r.ok, "ok")
    TestHelper.assertEquals(3, r.records, "6 字节 = 3 条记录")
    TestHelper.assertEquals(0, r.tail, "无尾部")
    os.remove(p)
end

function T.testBinTableOddBytes()
    print("\n=== Test: .bin 奇数字节 ⇒ 显式 gap（不得静默吞）===")
    local p = os.tmpname()
    local f = assert(io.open(p, "wb"))
    f:write(string.char(1, 2, 3))            -- 1 条 + 1 字节尾巴
    f:close()
    local r = FS.verifyBinTable(p)
    TestHelper.assertTrue(not r.ok, "奇数字节必须失败")
    TestHelper.assertEquals(1, r.records, "3 字节 = 1 条完整记录")
    TestHelper.assertEquals(1, r.tail, "1 字节尾巴显式归类")
    os.remove(p)
end

function T.testBinTableZeroBytes()
    print("\n=== Test: .bin 零字节 ⇒ 失败（0 条记录 ≠ 全覆盖）===")
    local p = os.tmpname()
    local f = assert(io.open(p, "wb"))
    f:close()
    local r = FS.verifyBinTable(p)
    TestHelper.assertTrue(not r.ok, "空文件必须失败")
    TestHelper.assertEquals(0, r.records, "0 条记录")
    TestHelper.assertNotNil(r.error, "必须给出 error 说明")
    os.remove(p)
end

-- ============================================================
-- REQ-FMT-7: 零回归
-- ============================================================

function T.testVerifyIntervalsEmpty()
    print("\n=== Test: 空区间集 ===")
    local r = FS.verifyIntervals({}, 100)
    TestHelper.assertTrue(not r.ok, "空集不 ok")
    TestHelper.assertEquals(1, #r.gaps, "整个文件是缺口")
end

function T.testVerifyIntervalsZeroSize()
    print("\n=== Test: 零字节文件 ===")
    local r = FS.verifyIntervals({}, 0)
    TestHelper.assertTrue(r.ok, "0 字节文件 trivially ok")
    TestHelper.assertEquals(0, #r.gaps, "无缺口")
end

-- ============================================================
-- runner
-- ============================================================


-- ============================================================
-- Slice 0c format-spec 补全：save_grid / save_slot（REQ-FMT-1）
-- 背景：初稿 FORMATS 只注册 ranger，遗漏 allsin/alldef 与 rN/sN/dN，
--       导致 save/ 451 个源文件中 411 个从未做字段级覆盖验证。
-- ============================================================

function T.testSaveGridRegistered()
    print("\n=== Test: save_grid 族已注册为定长网格（allsin/alldef）===")
    -- 重要：allsin/alldef **不是** offset 表族，而是定长 uint16 网格。
    -- 引擎证据：lib_love.lua:898-904 s_size=SX*SY*6*Num, d_size=DNum1*DNum2*Num，
    --           Byte.LoadToTable16 一次性定长直读，**不读 .idx**。
    -- 因此它们必须在 SIMPLE_FORMATS（kind=grid_save），不在 FORMATS。
    local inFormats = {}
    for _, f in ipairs(FS.FORMATS) do inFormats[f.name] = f end
    TestHelper.assertNil(inFormats["allsin"],
        "allsin 不得注册在 FORMATS（offset 表族，语义错误）")
    TestHelper.assertNil(inFormats["alldef"],
        "alldef 不得注册在 FORMATS（offset 表族，语义错误）")

    local inSimple = {}
    for _, f in ipairs(FS.SIMPLE_FORMATS) do inSimple[f.name] = f end
    TestHelper.assertNotNil(inSimple["allsin"], "allsin 已注册在 SIMPLE_FORMATS")
    TestHelper.assertNotNil(inSimple["alldef"], "alldef 已注册在 SIMPLE_FORMATS")
    TestHelper.assertEquals("grid_save", inSimple["allsin"].kind, "allsin kind")
    TestHelper.assertEquals("grid_save", inSimple["alldef"].kind, "alldef kind")
    TestHelper.assertEquals("lib_love.LoadSMap", inSimple["allsin"].consumer,
        "allsin consumer 是 LoadSMap（非 LoadRecord）")
    TestHelper.assertTrue(inSimple["allsin"].optional, "allsin 标记 optional")
end

function T.testSaveGridGeometry()
    print("\n=== Test: save_grid 网格几何守恒（真数据）===")
    -- pascal 是权威基准：allsin=64*64*6*100*2=4915200, alldef=200*11*100*2=440000
    local modDir = FS.MODS_SRC .. "/kys-pascal"
    local s = FS.verifySaveGrid(modDir .. "/save/allsin.grp", { x = 64, y = 64, levels = 6 })
    local d = FS.verifySaveGrid(modDir .. "/save/alldef.grp", { dnum = 200, dnum2 = 11 })
    TestHelper.assertTrue(s.ok, "pascal allsin 定长网格守恒")
    TestHelper.assertTrue(d.ok, "pascal alldef 定长网格守恒")
    TestHelper.assertEquals(100, s.scenes, "allsin 反推 100 场景")
    TestHelper.assertEquals(100, d.scenes, "alldef 反推 100 场景")
    TestHelper.assertEquals(0, s.tail, "allsin 无 tail")
    TestHelper.assertEquals(0, d.tail, "alldef 无 tail")
    -- 两独立公式互证（24576 vs 2200 单元/场景）
    TestHelper.assertEquals(s.scenes, d.scenes, "allsin/alldef 场景数交叉一致")
end

function T.testSaveGridRejectsWrongGeometry()
    print("\n=== Test: 错误网格公式必须被拒（负向对照）===")
    local modDir = FS.MODS_SRC .. "/kys-pascal"
    -- 用错的维度因子验真文件：必须 FAIL
    local bad1 = FS.verifySaveGrid(modDir .. "/save/allsin.grp", { x = 88, y = 88, levels = 6 })
    local bad2 = FS.verifySaveGrid(modDir .. "/save/alldef.grp", { dnum = 201, dnum2 = 11 })
    TestHelper.assertFalse(bad1.ok, "88x88x6 验 64x64x6 文件必须 FAIL")
    TestHelper.assertFalse(bad2.ok, "201*11 验 200*11 文件必须 FAIL")
    TestHelper.assertTrue((bad1.tail or 0) > 0, "bad1 报出 tail=" .. tostring(bad1.tail))
    TestHelper.assertTrue((bad2.tail or 0) > 0, "bad2 报出 tail=" .. tostring(bad2.tail))
end

function T.testSaveSlotRegistered()
    print("\n=== Test: save_slot 族已注册（rN/sN/dN 共 9 槽）===")
    local names = {}
    for _, f in ipairs(FS.FORMATS) do names[f.name] = f end
    for _, pfx in ipairs({ "save_r", "save_s", "save_d" }) do
        for i = 1, 3 do
            local n = pfx .. tostring(i)
            TestHelper.assertNotNil(names[n], n .. " 已注册")
            TestHelper.assertEquals("save_slot", names[n].family, n .. " 族")
        end
    end
end

function T.testSaveFamilyCoverageNoGaps()
    print("\n=== Test: save 族验证无缺口 ===")
    local a = all()
    local checked, bad = 0, 0
    for _, r in ipairs(a.results) do
        if r.format == "allsin" or r.format == "alldef" or (r.format or ""):match("^save_") then
            checked = checked + 1
            if not r.ok then bad = bad + 1 end
        end
    end
    TestHelper.assertTrue(checked > 40, "save 族检查项 > 40（" .. checked .. "）")
    TestHelper.assertEquals(0, bad, "save 族 gaps=0")
end

function T.testHeavenSwordOrphanSaveIdx()
    print("\n=== Test: HeavenSword r1.idx 无配对 grp 归为 ORPHAN_IDX ===")
    -- MOD 打包残留：r1.idx 与 ranger.idx 字节相同，真数据在 ranger.grp / r11.grp
    local a = all()
    local hit
    for _, r in ipairs(a.results) do
        if r.mod == "HeavenSword" and r.format == "save_r1" then hit = r break end
    end
    TestHelper.assertNotNil(hit, "找到 HeavenSword save_r1 记录")
    TestHelper.assertTrue(hit.ok, "不算缺口")
    TestHelper.assertEquals("ORPHAN_IDX", hit.category, "归为 ORPHAN_IDX")
    TestHelper.assertTrue(hit.dead_file, "标记 dead_file")
end

function T.testSaveFamilyCountIncreased()
    print("\n=== Test: 补全后 checked 增量 ===")
    local a = all()
    -- 补全前 6773；save_slot 9 槽共产生记录；allsin/alldef 各 20 = 40
    TestHelper.assertTrue(a.total >= 6826, "checked >= 6826（" .. a.total .. "）")
    TestHelper.assertEquals(0, a.bad, "gaps=0")
end

function T.runAll()
    print("\n" .. string.rep("=", 60))
    print("格式字段级覆盖测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    -- REQ-FMT-1
    T.testHdgrpCoverage()
    T.testAllModsHdgrpCoverage()
    T.testGridCoverage()
    T.testIdxTailIsZero()
    -- REQ-FMT-2
    T.testGapDetected()
    T.testOverlapDetected()
    T.testStartGapDetected()
    T.testTailGapDetected()
    T.testPerfectCoverageOk()
    -- REQ-FMT-3
    T.testRleRecordsExpanded()
    T.testTalkCoverage()
    T.testKdefCoverage()
    T.testBareIdxCoverage()
    -- REQ-FMT-4
    T.testMmapTwoSegments()
    T.testMmapCoverage()
    T.testMmapSeg1CoversGrp()
    -- REQ-FMT-5
    T.testConsumerSymbolsResolve()
    T.testFormatsHaveConsumer()
    -- REQ-FMT-6
    T.testVerifyAllNoGaps()
    T.testFormatFamiliesPresent()
    T.testAllFormatsCheckedForAllMods()
    -- 关键数据事实
    T.testWarStaRecordCountsVary()
    T.testEmptyWavsHandled()
    T.testWavWithTrailingMetadata()
    T.testOrphanFightIdxIsDeadFile()
    T.testRangerBothLayouts()
    T.testRangerIdxIsSixOffsets()
    T.testPaletteCoverage()
    T.testKysmodIniCoverage()
    T.testPngAllCovered()
    T.testSoundAllCovered()
    T.testFightAllCovered()
    T.testListBinCovered()
    T.testBinTableEvenBytes()
    T.testBinTableOddBytes()
    T.testBinTableZeroBytes()
    -- REQ-FMT-7
    T.testVerifyIntervalsEmpty()
    T.testVerifyIntervalsZeroSize()
    -- Slice 0c format-spec 补全：save 族
    T.testSaveGridRegistered()
    T.testSaveGridGeometry()
    T.testSaveGridRejectsWrongGeometry()
    T.testSaveSlotRegistered()
    T.testSaveFamilyCoverageNoGaps()
    T.testHeavenSwordOrphanSaveIdx()
    T.testSaveFamilyCountIncreased()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return T
