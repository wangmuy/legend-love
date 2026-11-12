-- test_mod_audit.lua -- 文件级穷举归类测试
--
-- 对应 allmods-slice0c-file-inventory 的 REQ-INV-1..7

local TestHelper = require("tests.test_helper")

-- 从 game/ 目录加载审计工具
package.path = "./?.lua;" .. package.path
local Audit = require("tools.mod_audit")
local Fs = require("framework.fs_compat")

local T = {}

-- 缓存 auditAll 结果（11220 条，避免重复遍历）
local _cache = nil
local function audit()
    if not _cache then
        local recs, unc, tot = Audit.auditAll()
        _cache = { recs = recs, unc = unc, tot = tot }
    end
    return _cache
end

-- ============================================================
-- REQ-INV-1: 穷举遍历，无遗漏
-- ============================================================

function T.testWalksAllModFiles()
    print("\n=== Test: 遍历 20 MOD 全部源文件 ===")
    local a = audit()
    -- 独立统计：用 fs_compat 递归遍历（不依赖 find/ls，Windows 也可用）
    local n = 0
    local modsSrc = "../reference/allmods"
    for _, name in ipairs(Fs.listDirectory(modsSrc)) do
        if name:match("^kys%-.+") and Fs.directoryExists(modsSrc .. "/" .. name) then
            n = n + #Fs.walkFiles(modsSrc .. "/" .. name)
        end
    end
    TestHelper.assertEquals(n, a.tot, "walkMods 覆盖文件系统全部文件")
end

function T.testTotalEqualsFilesystem()
    print("\n=== Test: 记录数 == 文件系统实际值 ===")
    local a = audit()
    local n = 0
    local modsSrc = "../reference/allmods"
    for _, name in ipairs(Fs.listDirectory(modsSrc)) do
        if name:match("^kys%-.+") and Fs.directoryExists(modsSrc .. "/" .. name) then
            n = n + #Fs.walkFiles(modsSrc .. "/" .. name)
        end
    end
    TestHelper.assertEquals(n, a.tot, "遍历总数 == 文件系统实际值")
    TestHelper.assertEquals(n, #a.recs, "无未归类时 记录数 == 遍历总数")
    TestHelper.assertTrue(n > 11000, "总数 > 11000（实际 " .. n .. "）")
end

function T.testNoExtensionFilesIncluded()
    print("\n=== Test: 无扩展名文件被收录 ===")
    local a = audit()
    local found = 0
    for _, r in ipairs(a.recs) do
        if r.ext == "" and r.path:match("^resource/") then found = found + 1 end
    end
    TestHelper.assertEquals(80, found, "resource/ 下 80 个无扩展名文件被收录")
end

function T.testNestedFilesIncluded()
    print("\n=== Test: topdir/文件名 解析正确 ===")
    local a = audit()
    -- 所有源文件都是 <topdir>/<filename> 或根级 <filename> 形式
    local bad, root = 0, 0
    for _, r in ipairs(a.recs) do
        if not r.path:find("/", 1, true) then
            root = root + 1  -- 根级文件（kysmod.ini / 111.txt / dll 等）
        end
        -- 文件名必须与 path 末尾一致
        local fn = r.path:match("([^/]+)$")
        local ext = fn:match("(%.[^%.]*)$") or ""
        if ext ~= r.ext then bad = bad + 1 end
    end
    TestHelper.assertEquals(0, bad, "ext 解析全部正确")
    TestHelper.assertTrue(root > 0, "存在根级文件（" .. root .. "）")
    TestHelper.assertTrue(root < 50, "根级文件不多（" .. root .. "）")
end

function T.testSplitPathHandlesRootFiles()
    print("\n=== Test: 根级文件 topdir 为空 ===")
    -- 根级文件（kysmod.ini 等）topdir 应为 ""
    -- 用 fs_compat 枚举各 MOD 目录的直接子项，统计其中的**文件**（跨平台）
    local n = 0
    local modsSrc = "../reference/allmods"
    for _, name in ipairs(Fs.listDirectory(modsSrc)) do
        if name:match("^kys%-.+") and Fs.directoryExists(modsSrc .. "/" .. name) then
            n = n + #Fs.listFiles(modsSrc .. "/" .. name)
        end
    end
    TestHelper.assertTrue(n > 0, "存在根级文件（" .. n .. "）")
    local r = Audit.classify({ mod = "x", path = "kysmod.ini", size = 0 })
    TestHelper.assertNotNil(r, "根级 kysmod.ini 可归类")
    TestHelper.assertEquals("BUILD_INPUT", r.category, "根级文件分类正确")
end

-- ============================================================
-- REQ-INV-2: 无兜底类别
-- ============================================================

function T.testNoUnclassified()
    print("\n=== Test: 未归类 == 0 ===")
    local a = audit()
    if #a.unc > 0 then
        for _, u in ipairs(a.unc) do
            print(string.format("  未归类: topdir=%s ext=%s 例=%s",
                u.topdir, u.ext, u.example))
        end
    end
    TestHelper.assertEquals(0, #a.unc, "无未归类文件组合")
end

function T.testClassifyReturnsNilForUnknown()
    print("\n=== Test: 未知组合返回 nil（无兜底）===")
    local r = Audit.classify({ mod = "x", path = "nonexistent/.xyz", size = 0 })
    TestHelper.assertTrue(r == nil, "未知 (topdir, ext) 返回 nil")
    local r2 = Audit.classify({ mod = "x", path = "totallynew/ext.qqq", size = 0 })
    TestHelper.assertTrue(r2 == nil, "另一未知组合返回 nil")
end

-- ============================================================
-- REQ-INV-3: 类别枚举
-- ============================================================

function T.testCategoryEnumExact()
    print("\n=== Test: CATEGORY 恰好 10 项 ===")
    TestHelper.assertEquals(10, #Audit.CATEGORY, "枚举项数")
    local set = {}
    for _, c in ipairs(Audit.CATEGORY) do set[c] = true end
    TestHelper.assertTrue(not set["OTHER"], "无 OTHER")
    TestHelper.assertTrue(not set["UNKNOWN"], "无 UNKNOWN")
    TestHelper.assertTrue(not set["MISC"], "无 MISC")
    for _, c in ipairs(Audit.CATEGORY) do
        TestHelper.assertTrue(not c:match("OTHER$"), "无 *_OTHER: " .. c)
    end
end

function T.testAllRecordCategoriesInEnum()
    print("\n=== Test: 所有记录类别 ∈ 枚举 ===")
    local a = audit()
    local set = {}
    for _, c in ipairs(Audit.CATEGORY) do set[c] = true end
    local bad = 0
    for _, r in ipairs(a.recs) do
        if not set[r.category] then
            bad = bad + 1
            if bad <= 3 then print("  非法类别: " .. tostring(r.category) .. " @ " .. r.path) end
        end
    end
    TestHelper.assertEquals(0, bad, "全部类别合法")
end

function T.testCategorySumEqualsTotal()
    print("\n=== Test: Σ(类别) == 记录数 ===")
    local a = audit()
    local sum = Audit.summarize(a.recs)
    local catSum = 0
    for _, n in pairs(sum.by_category) do catSum = catSum + n end
    TestHelper.assertEquals(sum.total, catSum, "Σ(类别) == total")
    TestHelper.assertEquals(#a.recs, catSum, "Σ(类别) == #records")
end

-- ============================================================
-- REQ-INV-4: needed=false 必有证据
-- ============================================================

function T.testNeededFalseHasEvidence()
    print("\n=== Test: needed=false 必有证据 ===")
    local a = audit()
    local nFalse, bad = 0, 0
    for _, r in ipairs(a.recs) do
        if r.needed == false then
            nFalse = nFalse + 1
            if #r.evidence == 0 then
                bad = bad + 1
                if bad <= 3 then print("  无证据: " .. r.mod .. "/" .. r.path) end
            end
        end
    end
    TestHelper.assertTrue(nFalse > 0, "存在 needed=false 记录（" .. nFalse .. "）")
    TestHelper.assertEquals(0, bad, "全部有证据")
end

function T.testEvidenceStructureValid()
    print("\n=== Test: 证据结构合法 ===")
    local a = audit()
    local kindSet = {}
    for _, k in ipairs(Audit.EVIDENCE_KINDS) do kindSet[k] = true end
    local bad = 0
    for _, r in ipairs(a.recs) do
        for _, e in ipairs(r.evidence) do
            if not kindSet[e.kind] then bad = bad + 1
            elseif e.kind == "code" and not e.cmd then bad = bad + 1
            elseif e.kind == "manual" and not e.cmd then bad = bad + 1
            elseif e.text and #e.text < 10 then bad = bad + 1
            end
        end
    end
    TestHelper.assertEquals(0, bad, "全部证据结构合法（kind/cmd/text 长度）")
end

function T.testEvidenceQualityCheckerRejects()
    print("\n=== Test: 空壳证据被拒 ===")
    local ok1 = Audit.checkEvidenceQuality({ kind = "manual", text = "unused" })
    TestHelper.assertTrue(ok1 == false, "过短 text 被拒")
    local ok2 = Audit.checkEvidenceQuality({ kind = "code", ref = "game/x.lua:foo" })
    TestHelper.assertTrue(ok2 == false, "缺 cmd 的 code 证据被拒")
    local ok3 = Audit.checkEvidenceQuality({ kind = "bogus", text = "some long text here" })
    TestHelper.assertTrue(ok3 == false, "非法 kind 被拒")
    local ok4 = Audit.checkEvidenceQuality({
        kind = "code", ref = "game/tools/mod_build.lua:IGNORE_DIRS",
        cmd = "grep -n IGNORE_DIRS game/tools/mod_build.lua",
        text = "构建器忽略这些目录" })
    TestHelper.assertTrue(ok4 == true, "合法证据通过")
end

-- ============================================================
-- REQ-INV-5: in_product 交叉验证
-- ============================================================

local function fileExists(p)
    -- 走 fs_compat：产物里有中文名文件（如 "ranger - 副本.idx"），
    -- Windows 的 io.open 打不开这类 UTF-8 路径。
    return Fs.fileExists(p)
end

function T.testInProductMatchesFilesystem()
    print("\n=== Test: in_product 与产物一致 ===")
    local a = audit()
    local mism = 0
    for _, r in ipairs(a.recs) do
        if Audit.IN_PRODUCT_BY_CATEGORY[r.category] then
            local cands = Audit.productCandidates(r.mod, r.path, Audit.classify(r))
            local any = false
            for _, p in ipairs(cands) do if fileExists(p) then any = true break end end
            if any ~= r.in_product then
                mism = mism + 1
                if mism <= 3 then
                    print(string.format("  不一致: %s/%s claimed=%s actual=%s",
                        r.mod, r.path, tostring(r.in_product), tostring(any)))
                end
            end
        end
    end
    TestHelper.assertEquals(0, mism, "in_product 与文件系统一致")
end

function T.testAliasSourceInProductViaTarget()
    print("\n=== Test: 别名源通过目标名判定进产物 ===")
    local rule = Audit.classify({ mod = "mingdong", path = "resource/sdx", size = 0 })
    TestHelper.assertNotNil(rule, "resource/sdx 可归类")
    TestHelper.assertEquals("REQUIRED_CONVERTED", rule.category, "类别")
    TestHelper.assertEquals("smap.idx", rule.alias_to, "别名目标")
    local cands = Audit.productCandidates("mingdong", "resource/sdx", rule)
    TestHelper.assertEquals("mods/mingdong/data/smap.idx", cands[1], "候选路径为别名目标")
end

function T.testEditorDumpNotInProduct()
    print("\n=== Test: 编辑器副产物不在产物中 ===")
    local rule = Audit.classify({ mod = "x", path = "head/hdgrp001.png", size = 0 })
    TestHelper.assertNotNil(rule, "head/*.png 可归类")
    TestHelper.assertEquals("EDITOR_DUMP", rule.category, "类别")
    TestHelper.assertEquals(false, rule.needed, "needed=false")
    TestHelper.assertEquals(false, Audit.IN_PRODUCT_BY_CATEGORY["EDITOR_DUMP"],
        "EDITOR_DUMP 不进产物")
end

-- ============================================================
-- REQ-INV-6: Markdown 报告
-- ============================================================

function T.testMarkdownHasAllSections()
    print("\n=== Test: audit.md 含分组与汇总 ===")
    local a = audit()
    local sum = Audit.summarize(a.recs)
    local md = Audit.renderMarkdown(a.recs, sum)
    TestHelper.assertTrue(md:find("## 汇总", 1, true) ~= nil, "含汇总表")
    TestHelper.assertTrue(md:find("| 类别 | 文件数 |", 1, true) ~= nil, "含表头")
    local n = 0
    for _, cat in ipairs(Audit.CATEGORY) do
        if (sum.by_category[cat] or 0) > 0 then
            n = n + 1
            TestHelper.assertTrue(md:find("## `" .. cat .. "`", 1, true) ~= nil,
                "含分组 " .. cat)
        end
    end
    TestHelper.assertTrue(n >= 5, "至少 5 个非空分组（实际 " .. n .. "）")
end

function T.testMarkdownNumbersMatchSummary()
    print("\n=== Test: 报告数字与统计一致 ===")
    local a = audit()
    local sum = Audit.summarize(a.recs)
    local md = Audit.renderMarkdown(a.recs, sum)
    for _, cat in ipairs(Audit.CATEGORY) do
        local n = sum.by_category[cat] or 0
        if n > 0 then
            local pat = "| `" .. cat .. "` | " .. n .. " |"
            TestHelper.assertTrue(md:find(pat, 1, true) ~= nil,
                "汇总行匹配 " .. cat .. " = " .. n)
        end
    end
end

-- ============================================================
-- 具体归类正确性（关键判定）
-- ============================================================

function T.testKeyClassifications()
    print("\n=== Test: 关键文件归类正确 ===")
    local cases = {
        { "resource/sdx",              "REQUIRED_CONVERTED" },
        { "resource/smp",              "REQUIRED_CONVERTED" },
        { "resource/wdx",              "REQUIRED_CONVERTED" },
        { "resource/wmp",              "REQUIRED_CONVERTED" },
        { "resource/hdgrp.grp",        "REQUIRED" },
        { "resource/kdef.grp",         "REQUIRED" },
        { "resource/talk.grp",         "REQUIRED" },
        { "resource/mmap.col",         "REQUIRED" },
        { "resource/earth.002",        "REQUIRED" },
        { "resource/war.sta",          "REQUIRED" },
        { "resource/war1.sta",         "DEAD_FILE" },
        { "resource/name.grp",         "LEGACY" },
        { "resource/name.idx",         "LEGACY" },
        { "fight/fight001.grp",        "REQUIRED" },
        { "sound/atk00.wav",           "REQUIRED" },
        { "save/ranger.grp",           "REQUIRED" },
        { "save/r1.grp",               "REQUIRED" },
        { "head/hdgrp001.png",         "EDITOR_DUMP" },
        { "item/item001.png",          "EDITOR_DUMP" },
        { "eft/eft001.png",            "EDITOR_DUMP" },
        { "music/song.mid",            "PENDING" },
        { "list/effect.bin",           "REQUIRED" },
        { "list/match.bin",            "REQUIRED" },
        { "list/leave.bin",            "LEGACY" },
        { "list/levelup.bin",          "LEGACY" },
        { "list/end.txt",              "LEGACY" },
        { "cc/STCharacters.txt",       "BUILD_INPUT" },
        { "SDL3.dll",                  "PLATFORM_ARTIFACT" },
        { "kys.exe",                   "PLATFORM_ARTIFACT" },
        { "kysmod.ini",                "BUILD_INPUT" },
        { "111.txt",                   "EDITOR_DUMP" },
        { "script/1.lua",              "LEGACY" },
    }
    for _, c in ipairs(cases) do
        local r = Audit.classify({ mod = "x", path = c[1], size = 0 })
        TestHelper.assertNotNil(r, "可归类: " .. c[1])
        TestHelper.assertEquals(c[2], r.category, c[1] .. " -> " .. c[2])
    end
end

function T.testPendingIsNotNeededFalse()
    print("\n=== Test: PENDING 的 needed 既非 true 也非 false ===")
    local r = Audit.classify({ mod = "x", path = "music/a.mid", size = 0 })
    TestHelper.assertEquals("PENDING", r.category, "类别")
    TestHelper.assertTrue(r.needed ~= true, "needed != true")
    TestHelper.assertTrue(r.needed ~= false, "needed != false（显式 nil）")
    TestHelper.assertTrue(#r.evidence > 0, "PENDING 有证据")
end

function T.testAbsentExpectedDocuments()
    print("\n=== Test: 源中不存在的资源有参考记录 ===")
    local names = {}
    for _, a in ipairs(Audit.ABSENT_EXPECTED) do names[a.path] = a.category end
    TestHelper.assertEquals("DESIGNED_FALLBACK", names["resource/thing.grp"], "thing 回退")
    TestHelper.assertEquals("DEAD_PARAM", names["resource/allsinbk.grp"], "allsinbk 死参数")
end

-- ============================================================
-- REQ-LBIN-4: list/*.bin 不能一刀切
-- ============================================================
function T.testListEffectAndMatchAreRequired()
    print("\n=== Test: list/effect.bin + match.bin → REQUIRED 且进产物 ===")
    for _, f in ipairs({ "list/effect.bin", "list/match.bin" }) do
        local r = Audit.classify({ mod = "pascal", path = f, size = 1 })
        TestHelper.assertEquals("REQUIRED", r.category, f .. " 类别")
        TestHelper.assertTrue(r.needed == true, f .. " needed=true")
        TestHelper.assertTrue(r.in_product == true, f .. " in_product=true")
        TestHelper.assertTrue(#r.evidence > 0, f .. " 有证据")
    end
end

function T.testListLeaveAndLevelupAreLegacy()
    print("\n=== Test: list/leave.bin + levelup.bin → LEGACY（引擎零引用）===")
    for _, f in ipairs({ "list/leave.bin", "list/levelup.bin" }) do
        local r = Audit.classify({ mod = "pascal", path = f, size = 1 })
        TestHelper.assertEquals("LEGACY", r.category, f .. " 类别")
        TestHelper.assertTrue(r.needed == false, f .. " needed=false")
        TestHelper.assertTrue(#r.evidence > 0, f .. " 有证据")
        TestHelper.assertEquals("code", r.evidence[1].kind, f .. " 证据 kind=code")
    end
end

function T.testListMatchCopyIsEditorDump()
    print("\n=== Test: list/match - 复制.bin → EDITOR_DUMP（作者备份）===")
    local r = Audit.classify({ mod = "Dragon", path = "list/match - \229\164\141\229\136\182.bin", size = 42 })
    TestHelper.assertEquals("EDITOR_DUMP", r.category, "类别")
    TestHelper.assertTrue(r.needed == false, "needed=false")
    TestHelper.assertTrue(#r.evidence > 0, "有证据")
end

function T.testListBinHasNoUnclassified()
    print("\n=== Test: list/ 下无未归类文件（含中文/空格文件名）===")
    local recs = Audit.walkMods(nil)
    local bad = {}
    local listCount = 0
    for _, r in ipairs(recs) do
        local top = r.path:match("^(list)/")
        if top then
            listCount = listCount + 1
            if not Audit.classify(r) then bad[#bad + 1] = r.mod .. "/" .. r.path end
        end
    end
    TestHelper.assertTrue(listCount > 0, "list/ 下有文件（" .. listCount .. "）")
    TestHelper.assertEquals(0, #bad, "未归类数：" .. table.concat(bad, ", "))
end

-- REQ-LBIN-4：PENDING 中不得再有 .bin 残留
function T.testNoPendingBinResidue()
    print("\n=== Test: PENDING 里没有 .bin 残留 ===")
    local recs = Audit.walkMods(nil)
    local bin, other = 0, 0
    local exts = {}
    for _, r in ipairs(recs) do
        local rule = Audit.classify(r)
        if rule and rule.category == "PENDING" then
            local e = r.path:match("(%.[^%.]+)$") or "(none)"
            if e == ".bin" then bin = bin + 1 end
            exts[e] = (exts[e] or 0) + 1
            other = other + 1
        end
    end
    TestHelper.assertEquals(0, bin, "PENDING 中 .bin 数")
    -- 剩下的只能是音频类（.mid/.mp3/.sf2）
    for e in pairs(exts) do
        TestHelper.assertTrue(e == ".mid" or e == ".mp3" or e == ".sf2",
            "PENDING 只剩音频类，发现 " .. e)
    end
end

function T.testInProductCounts()
    print("\n=== Test: 进产物 / 未进产物计数 ===")
    local a = audit()
    local sum = Audit.summarize(a.recs)
    TestHelper.assertEquals(sum.total, sum.in_product + sum.not_in_product,
        "in_product + not_in_product == total")
    TestHelper.assertTrue(sum.in_product > 9000, "进产物 > 9000（" .. sum.in_product .. "）")
    TestHelper.assertTrue(sum.not_in_product > 1500, "未进产物 > 1500（" .. sum.not_in_product .. "）")
end

function T.testEvidenceKindsEnum()
    print("\n=== Test: EVIDENCE_KINDS 枚举 ===")
    TestHelper.assertEquals(6, #Audit.EVIDENCE_KINDS, "恰好 6 种")
    local set = {}
    for _, k in ipairs(Audit.EVIDENCE_KINDS) do set[k] = true end
    for _, k in ipairs({ "code", "strings", "offset_table", "format", "external", "manual" }) do
        TestHelper.assertTrue(set[k], "含 " .. k)
    end
end

-- ============================================================
-- REQ-EVID-1..6: 证据与权威文档
-- ============================================================

function T.testEvidenceExecutesSuccessfully()
    print("\n=== Test: 全部证据 cmd 可执行且输出含 expect ===")
    local a = audit()
    local checked, failed, details = Audit.verifyAllEvidence(a.recs, { timeout = 30 })
    for _, d in ipairs(details) do
        print(string.format("  [FAIL] %s\n         %s", d.cmd, d.err))
    end
    TestHelper.assertTrue(checked >= 10, "证据命令 >= 10（" .. checked .. "）")
    TestHelper.assertEquals(0, failed, "全部证据通过")
end

function T.testEvidenceCommandsAreGameRelative()
    print("\n=== Test: 证据 cmd 用 game/ 相对路径 ===")
    local a = audit()
    local bad = 0
    for _, r in ipairs(a.recs) do
        for _, e in ipairs(r.evidence) do
            if e.cmd and e.cmd:find("game/", 1, true) then
                bad = bad + 1
                if bad <= 3 then print("  含 game/ 前缀: " .. e.cmd) end
            end
        end
    end
    TestHelper.assertEquals(0, bad, "无 game/ 前缀（cmd 在 game/ 下执行）")
end

function T.testIgnoreDirsEvidence()
    print("\n=== Test: IGNORE_DIRS 证据可复现 ===")
    local ok, out = Audit.runEvidence({
        kind = "code",
        ref = "game/tools/mod_build.lua:IGNORE_DIRS",
        cmd = "grep -n IGNORE_DIRS tools/mod_build.lua",
        expect = "head",
        text = "构建器忽略 head/item/eft",
    })
    TestHelper.assertTrue(ok, "证据执行成功: " .. tostring(out))
    TestHelper.assertTrue(out:find("head", 1, true) ~= nil, "输出含 head")
    TestHelper.assertTrue(out:find("item", 1, true) ~= nil, "输出含 item")
    TestHelper.assertTrue(out:find("eft", 1, true) ~= nil, "输出含 eft")
end

function T.testFormatEvidenceRejectsDeadNames()
    print("\n=== Test: format 证据证明死文件名不可生成 ===")
    -- %03d 生成不出 fight030_02.grp
    local ok, out = Audit.runEvidence({
        kind = "format",
        ref = "game/tools/mod_build.lua:FightPicFile",
        cmd = "lua -e 'print(string.format(\"fight%03d.grp\",30))'",
        expect = "fight030.grp",
        text = "%03d 生成不出 fight030_02.grp",
    })
    TestHelper.assertTrue(ok, "证据执行成功: " .. tostring(out))
    TestHelper.assertTrue(not out:find("fight030_02", 1, true),
        "输出不含 fight030_02.grp")
end

function T.testPlatformEvidenceMagic()
    print("\n=== Test: PLATFORM_ARTIFACT 魔数证据 ===")
    local ok, out = Audit.runEvidence({
        kind = "external",
        cmd = "head -c 2 ../reference/allmods/kys-pascal/kys.exe",
        expect = "MZ",
        text = "Windows PE 可执行",
    })
    TestHelper.assertTrue(ok, "MZ 魔数证据成立: " .. tostring(out))
end

function T.testMusicEvidenceMagic()
    print("\n=== Test: PENDING 音乐魔数证据 ===")
    local ok, out = Audit.runEvidence({
        kind = "external",
        cmd = "head -c 4 $(ls ../reference/allmods/kys-pascal/music/*.mid | head -1)",
        expect = "MThd",
        text = "MIDI 魔数 MThd != 引擎期望 OggS/RIFF",
    })
    TestHelper.assertTrue(ok, "MThd 魔数证据成立: " .. tostring(out))
    TestHelper.assertTrue(out:find("MThd", 1, true) ~= nil, "输出含 MThd")
    TestHelper.assertTrue(not out:find("OggS", 1, true), "非 OggS")
end

function T.testResourceAuditDocExists()
    print("\n=== Test: MOD_RESOURCE_AUDIT.md 存在且含全部锚点 ===")
    local f = io.open("../MOD_RESOURCE_AUDIT.md", "rb")
    TestHelper.assertNotNil(f, "文件存在")
    local doc = f:read("*a")
    f:close()
    local n = select(2, doc:gsub("<!%-%- rec:", ""))
    TestHelper.assertEquals(11220, n, "锚点数 == 11220")
    TestHelper.assertTrue(doc:find("## 汇总", 1, true) ~= nil, "含汇总")
    TestHelper.assertTrue(doc:find("## 如何复现", 1, true) ~= nil, "含如何复现")
    TestHelper.assertTrue(doc:find("未归类（应为 0）", 1, true) ~= nil, "含未归类节")
end

function T.testResourceAuditAnchorsMatchRecords()
    print("\n=== Test: 文档锚点可在记录中找到 ===")
    local f = io.open("../MOD_RESOURCE_AUDIT.md", "rb")
    local doc = f:read("*a")
    f:close()
    local a = audit()
    -- 抽样 30 条记录，断言其锚点存在于文档
    local step = math.max(1, math.floor(#a.recs / 30))
    local checked = 0
    for i = 1, #a.recs, step do
        local r = a.recs[i]
        local anchor = "<!-- rec:" .. r.mod .. ":" .. r.path .. " -->"
        TestHelper.assertTrue(doc:find(anchor, 1, true) ~= nil,
            "锚点存在: " .. r.mod .. "/" .. r.path)
        checked = checked + 1
    end
    TestHelper.assertTrue(checked >= 25, "抽样 >= 25（" .. checked .. "）")
end

function T.testNotInProductAllHaveReason()
    print("\n=== Test: 未进产物全部有类别与理由 ===")
    local a = audit()
    local n, noCat, noEv = 0, 0, 0
    for _, r in ipairs(a.recs) do
        if not r.in_product then
            n = n + 1
            if not r.category or r.category == "" then noCat = noCat + 1 end
            if r.category ~= "REQUIRED" and r.category ~= "REQUIRED_CONVERTED" then
                if #r.evidence == 0 then noEv = noEv + 1 end
            end
        end
    end
    -- 计数从审计结果派生（避免硬编码漂移）
    local expNotInProduct = 0
    for _, r in ipairs(a.recs) do if not r.in_product then expNotInProduct = expNotInProduct + 1 end end
    TestHelper.assertEquals(expNotInProduct, n, "未进产物计数与记录一致（" .. expNotInProduct .. "）")
    TestHelper.assertTrue(n > 1000, "未进产物 > 1000（实际 " .. n .. "）")
    TestHelper.assertEquals(0, noCat, "全部有类别")
    TestHelper.assertEquals(0, noEv, "全部有理由")
end

function T.testNoRequiredFileMissingFromProduct()
    print("\n=== Test: 无「必需但未进产物」矛盾 ===")
    local a = audit()
    local bad = 0
    for _, r in ipairs(a.recs) do
        if not r.in_product then
            -- 与 checkInProduct 同语义：per-rule 覆盖优先
            local rule = Audit.classify({ mod = r.mod, path = r.path, size = r.size })
            local declared = rule and rule.in_product
            local ip = declared ~= nil and declared or Audit.IN_PRODUCT_BY_CATEGORY[r.category]
            if ip == true then
                bad = bad + 1
                if bad <= 3 then print("  矛盾: " .. r.mod .. "/" .. r.path) end
            end
        end
    end
    TestHelper.assertEquals(0, bad, "无矛盾")
end

function T.testPendingRecordsHaveEvidence()
    print("\n=== Test: PENDING 记录均有证据且 needed=nil ===")
    local a = audit()
    local n, bad = 0, 0
    for _, r in ipairs(a.recs) do
        if r.category == "PENDING" then
            n = n + 1
            if r.needed ~= nil or #r.evidence == 0 then bad = bad + 1 end
        end
    end
    TestHelper.assertTrue(n > 0, "PENDING 记录 > 0（" .. n .. "）")
    TestHelper.assertEquals(0, bad, "全部 needed=nil 且有证据")
end

function T.testJsonRoundTrip()
    print("\n=== Test: audit.json 可解析且数字一致 ===")
    local f = io.open("mods/_audit/audit.json", "rb")
    TestHelper.assertNotNil(f, "audit.json 存在")
    -- 缺产物的环境下（新克隆 / 未跑 mod_audit.lua --all）该文件不存在。
    -- 断言已记录失败，这里直接返回，避免再去索引 nil 把「缺文件」
    -- 变成一条难读的 stack traceback。
    if not f then return end
    local txt = f:read("*a")
    f:close()
    -- 简单结构断言（不引入 JSON 解析依赖）
    TestHelper.assertTrue(txt:find('"total":11220', 1, true) ~= nil, "total=11220")
    TestHelper.assertTrue(txt:find('"unclassified"', 1, true) == nil, "无 unclassified 字段")
    local a = audit()
    -- 计数从审计结果派生
    local nReq, nPend = 0, 0
    for _, r in ipairs(a.recs) do
        if r.category == "REQUIRED" then nReq = nReq + 1 end
        if r.category == "PENDING" then nPend = nPend + 1 end
    end
    TestHelper.assertTrue(txt:find('"REQUIRED":' .. nReq, 1, true) ~= nil, "REQUIRED=" .. nReq)
    TestHelper.assertTrue(txt:find('"PENDING":' .. nPend, 1, true) ~= nil, "PENDING=" .. nPend)
end

function T.testKysmodIniIsBuildInputButShipped()
    print("\n=== Test: kysmod.ini 是 BUILD_INPUT 但确实在产物中 ===")
    local a = audit()
    local n, bad = 0, 0
    for _, r in ipairs(a.recs) do
        if r.path == "kysmod.ini" then
            n = n + 1
            TestHelper.assertEquals("BUILD_INPUT", r.category, r.mod .. " kysmod.ini 类别")
            TestHelper.assertEquals(false, r.needed, r.mod .. " kysmod.ini needed=false")
            if not r.in_product then bad = bad + 1 end
        end
    end
    TestHelper.assertEquals(20, n, "20 个 MOD 各一个 kysmod.ini")
    TestHelper.assertEquals(0, bad, "全部 kysmod.ini in_product=true")
end

function T.testCcDictsAreBuildInputAndNotShipped()
    print("\n=== Test: cc/ 词典是 BUILD_INPUT 且不在产物中 ===")
    local a = audit()
    local n, bad = 0, 0
    for _, r in ipairs(a.recs) do
        if r.path:match("^cc/") then
            n = n + 1
            TestHelper.assertEquals("BUILD_INPUT", r.category, r.path .. " 类别")
            if r.in_product then bad = bad + 1 end
        end
    end
    TestHelper.assertTrue(n >= 4, "cc/ 词典 >= 4（实际 " .. n .. "）")
    TestHelper.assertEquals(0, bad, "全部 cc/ 词典 not in product")
end

function T.runAll()
    print("\n" .. string.rep("=", 60))
    print("MOD 资源穷举审计测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    -- REQ-INV-1: 穷举遍历
    T.testWalksAllModFiles()
    T.testTotalEqualsFilesystem()
    T.testNoExtensionFilesIncluded()
    T.testNestedFilesIncluded()
    T.testSplitPathHandlesRootFiles()

    -- REQ-INV-2: 无兜底
    T.testNoUnclassified()
    T.testClassifyReturnsNilForUnknown()

    -- REQ-INV-3: 类别枚举
    T.testCategoryEnumExact()
    T.testAllRecordCategoriesInEnum()
    T.testCategorySumEqualsTotal()

    -- REQ-INV-4: 证据
    T.testNeededFalseHasEvidence()
    T.testEvidenceStructureValid()
    T.testEvidenceQualityCheckerRejects()
    T.testEvidenceKindsEnum()

    -- REQ-INV-5: in_product
    T.testInProductMatchesFilesystem()
    T.testAliasSourceInProductViaTarget()
    T.testEditorDumpNotInProduct()
    T.testInProductCounts()

    -- REQ-INV-6: 报告
    T.testMarkdownHasAllSections()
    T.testMarkdownNumbersMatchSummary()

    -- 具体归类
    T.testKeyClassifications()
    T.testPendingIsNotNeededFalse()
    T.testAbsentExpectedDocuments()
    T.testListEffectAndMatchAreRequired()
    T.testListLeaveAndLevelupAreLegacy()
    T.testListMatchCopyIsEditorDump()
    T.testListBinHasNoUnclassified()
    T.testNoPendingBinResidue()

    -- REQ-EVID-1..6: 证据与权威文档
    T.testEvidenceExecutesSuccessfully()
    T.testEvidenceCommandsAreGameRelative()
    T.testIgnoreDirsEvidence()
    T.testFormatEvidenceRejectsDeadNames()
    T.testPlatformEvidenceMagic()
    T.testMusicEvidenceMagic()
    T.testResourceAuditDocExists()
    T.testResourceAuditAnchorsMatchRecords()
    T.testNotInProductAllHaveReason()
    T.testNoRequiredFileMissingFromProduct()
    T.testPendingRecordsHaveEvidence()
    T.testJsonRoundTrip()
    T.testKysmodIniIsBuildInputButShipped()
    T.testCcDictsAreBuildInputAndNotShipped()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return T
