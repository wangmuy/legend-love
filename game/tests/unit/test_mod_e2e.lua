-- test_mod_e2e.lua
-- 名动天下（kys-mingdong）无头端到端验证（allmods-mingdong-activate，Contract D）
--
-- 用 tests/engine_test.lua 的 EngineAPI 无头实现驱动启动链路的关键环节：
--   SetGlobalConst → ModData.RewriteConstants → ModIni.Apply → 路径回退 → 脚本/对话/战斗加载
-- 不依赖显示器；不写入 game/active_mod.txt（用 ModData.SetActive 模拟激活）。

local TestHelper = require("tests.test_helper")
local TestModE2E = {}

-- 保存真实 loadfile（其它测试可能替换全局 loadfile 且未恢复）
local realLoadfile = loadfile
local function restoreLoadfile()
    if _G.loadfile ~= realLoadfile then _G.loadfile = realLoadfile end
end

-- 重新加载 mod_data（清除缓存），并模拟激活
local function freshModData(slug)
    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")
    if slug ~= nil then ModData.SetActive(slug) end
    return ModData
end

-- 模拟 SetGlobalConst 的 CC.* 路径常量（与 jyconst.lua 一致的最小集）
local function fakeCC()
    return {
        ScreenW = 1024, ScreenH = 768,
        MMAPPicFile = { "data/mmap.idx", "data/mmap.grp" },
        SMAPPicFile = { "data/smap.idx", "data/smap.grp" },
        WMAPPicFile = { "data/wmap.idx", "data/wmap.grp" },
        HeadPicFile = { "data/hdgrp.idx", "data/hdgrp.grp" },
        ThingPicFile = { "data/thing.idx", "data/thing.grp" },
        EffectFile = { "data/eft.idx", "data/eft.grp" },
        WarMapFile = { "data/warfld.idx", "data/warfld.grp" },
        FightPicFile = { "data/fight%03d.idx", "data/fight%03d.grp" },
        PaletteFile = "data/mmap.col",
        WarFile = "data/war.sta",
        TalkIdxFile = "script/oldtalk.idx",
        TalkGrpFile = "script/oldtalk.grp",
        MyThingNum = 200, MaxHP = 999, MaxMP = 999,
    }
end

-- ============================================================
-- REQ-MD-1: 激活后 CC.* 路径重定向 + ini 覆盖
-- ============================================================

function TestModE2E.testActivateRewritesPathsAndIni()
    print("\n=== Test: activate mingdong rewrites CC paths + ini override ===")
    local ModData = freshModData("mingdong")
    -- ModIni.Apply 写入全局 CONFIG/CC（与真实运行时一致）
    _G.CC = fakeCC()
    _G.CONFIG = { DataPath = "data/", ScriptPath = "script/", Width = 1024, Height = 768 }
    local CC, CONFIG = _G.CC, _G.CONFIG

    -- 启动链路：先重定向路径，再应用 ini
    ModData.RewriteConstants(CC, CONFIG)
    local parsed = ModData.LoadIni()
    TestHelper.assertNotNil(parsed, "kysmod.ini parsed")

    -- 路径重定向：mingdong 有的文件命中 mods/mingdong/data/
    TestHelper.assertEquals("mods/mingdong/data/mmap.grp", CC.MMAPPicFile[2], "mmap -> MOD")
    TestHelper.assertEquals("mods/mingdong/data/hdgrp.grp", CC.HeadPicFile[2], "hdgrp -> MOD")
    TestHelper.assertEquals("mods/mingdong/data/eft.grp", CC.EffectFile[2], "eft -> MOD")
    TestHelper.assertEquals("mods/mingdong/data/warfld.grp", CC.WarMapFile[2], "warfld -> MOD")
    -- 别名转换后：smap/wmap 由构建期把 sdx/smp/wdx/wmp 改名而来，
    -- 故 mingdong 产物中已有 smap.*/wmap.*，应命中 MOD（allmods-slice0b-smap-rename）
    TestHelper.assertEquals("mods/mingdong/data/smap.grp", CC.SMAPPicFile[2], "smap -> MOD (alias)")
    TestHelper.assertEquals("mods/mingdong/data/wmap.grp", CC.WMAPPicFile[2], "wmap -> MOD (alias)")
    -- 回退：mingdong 没有的文件保持原版路径
    TestHelper.assertEquals("data/thing.grp", CC.ThingPicFile[2], "thing -> fallback data/")
    -- FightPicFile 格式串前缀重定向
    TestHelper.assertEquals("mods/mingdong/data/fight%03d.grp", CC.FightPicFile[2],
        "fight format -> MOD")

    -- ini 覆盖
    -- 分辨率不映射：窗口尺寸始终来自 config.lua（1024x768），
    -- 避免 MOD 的 RESOLUTIONX/Y 缩小窗口（详见 allmods-ini-parser/reports/resolution-mapping.md）
    TestHelper.assertEquals(1024, CONFIG.Width, "CONFIG.Width 不被 MOD ini 覆盖")
    TestHelper.assertEquals(768, CONFIG.Height, "CONFIG.Height 不被 MOD ini 覆盖")
    TestHelper.assertEquals(1024, CC.ScreenW, "CC.ScreenW 不被 MOD ini 覆盖")
    TestHelper.assertEquals(768, CC.ScreenH, "CC.ScreenH 不被 MOD ini 覆盖")
    TestHelper.assertEquals(330, CC.MyThingNum, "CC.MyThingNum=330")
    TestHelper.assertEquals(9999, CC.MaxHP, "CC.MaxHP=9999")
end

-- ============================================================
-- REQ-MD-2: 事件脚本回退链
-- ============================================================

function TestModE2E.testEventScriptFallback()
    print("\n=== Test: event script loads from MOD via ScriptLoader ===")
    local ModData = freshModData("mingdong")
    -- ScriptLoader 经 ModData.ScriptFile 解析
    local resolved = ModData.ScriptFile("script/oldevent/oldevent_0.lua")
    TestHelper.assertEquals("mods/mingdong/script/oldevent/oldevent_0.lua", resolved,
        "oldevent_0.lua resolves to MOD script dir")

    -- 实际加载（无头 EngineAPI）
    package.loaded["tests.engine_test"] = nil
    local EngineAPI = require("tests.engine_test")
    _G.EngineAPI = EngineAPI
    package.loaded["framework.script_loader"] = nil
    local ScriptLoader = require("framework.script_loader")
    local chunk, err = ScriptLoader.load("script/oldevent/oldevent_0.lua")
    TestHelper.assertNotNil(chunk, "chunk loaded from MOD (" .. tostring(err) .. ")")
end

-- ============================================================
-- REQ-MD-3: 对话表加载，内容为 mingdong 数据
-- ============================================================

function TestModE2E.testTalkTableContent()
    print("\n=== Test: mingdong old_talk.lua content ===")
    -- 其它测试可能临时替换 _G.loadfile；用真实 loadfile 读取
    local realLoadfile = loadfile
    if _G.loadfile ~= realLoadfile then _G.loadfile = realLoadfile end
    local ModData = freshModData("mingdong")
    local talkPath = ModData.ScriptFile("script/old_talk.lua")
    TestHelper.assertEquals("mods/mingdong/script/old_talk.lua", talkPath, "talk path -> MOD")

    local chunk = loadfile(talkPath)
    TestHelper.assertNotNil(chunk, "old_talk.lua loadable")
    _G.oldtalk = nil
    chunk()
    TestHelper.assertNotNil(_G.oldtalk, "oldtalk global defined")
    TestHelper.assertNotNil(_G.oldtalk[1], "oldtalk[1] exists")
    -- mingdong 首条对话（从 MOD talk.grp 解码，简体中文）
    TestHelper.assertEquals("小兄弟，你好啊。", _G.oldtalk[1],
        "oldtalk[1] is mingdong's first line")
end

-- 运行时对话路径：ReadTalk 读 script/oldtalk.grp + oldtalk.idx
function TestModE2E.testRuntimeTalkGrpIdx()
    print("\n=== Test: mingdong runtime talk (oldtalk.grp + oldtalk.idx) ===")
    local ModData = freshModData("mingdong")
    -- CC.TalkGrpFile/TalkIdxFile 重定向到 MOD
    local CC = fakeCC()
    local CONFIG = { DataPath = "data/", ScriptPath = "script/" }
    ModData.RewriteConstants(CC, CONFIG)
    TestHelper.assertEquals("mods/mingdong/script/oldtalk.grp", CC.TalkGrpFile,
        "TalkGrpFile -> MOD")
    TestHelper.assertEquals("mods/mingdong/script/oldtalk.idx", CC.TalkIdxFile,
        "TalkIdxFile -> MOD")

    -- 模拟 GenTalkIdx/ReadTalk 的读取语义
    local f = io.open(CC.TalkGrpFile, "rb")
    local grp = f:read("*a"); f:close()
    local g = io.open(CC.TalkIdxFile, "rb")
    local idx = g:read("*a"); g:close()
    TestHelper.assertEquals(5183, #idx / 4, "idx has 5183 entries")

    -- 运行时对话路径：ReadTalk 读 script/oldtalk.grp + oldtalk.idx
    -- 语义（见 script/jymain.lua GenTalkIdx/ReadTalk）：
    --   idx[k] = 第 k 条（0-based）读取结束后的偏移，即第 k+1 条的起始
    --   ReadTalk(0): [0, idx[0])；ReadTalk(k): [idx[k-1], idx[k])
    --   条目在 grp 中以 CRLF 结尾，读取时去掉 CRLF。
    local function u32(s, off)
        local b1, b2, b3, b4 = s:byte(off + 1, off + 4)
        return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end
    local function readTalk(id)
        local id1 = (id == 0) and 0 or u32(idx, (id - 1) * 4)
        local id2 = u32(idx, id * 4)
        local raw = grp:sub(id1 + 1, id2)
        return (raw:gsub("\r?\n$", ""))
    end
    TestHelper.assertEquals("小兄弟，你好啊。", readTalk(0), "ReadTalk(0)")
    TestHelper.assertEquals("请问你是胡斐胡大哥吗？", readTalk(1), "ReadTalk(1)")
    TestHelper.assertEquals("正是在下．", readTalk(2), "ReadTalk(2)")
end

-- ============================================================
-- REQ-MD-4: 战斗文件动态枚举 + 越界校验
-- ============================================================

function TestModE2E.testFightFilesDynamic()
    print("\n=== Test: mingdong fight files dynamic enumeration ===")
    local ModData = freshModData("mingdong")
    local files = ModData.FightFiles()
    TestHelper.assertEquals(267, #files, "mingdong has 267 fight files")
    TestHelper.assertEquals("fight000.grp", files[1], "first fight file")
    TestHelper.assertEquals("fight321.grp", files[#files], "last fight file")

    -- war.sta 记录数
    local warFile = ModData.Resolve("data/war.sta")
    TestHelper.assertEquals("mods/mingdong/data/war.sta", warFile, "war.sta -> MOD")
    local records = ModData.WarRecordCount(warFile, 186)
    TestHelper.assertEquals(309, records, "mingdong war.sta has 309 records")
end

-- ============================================================
-- 零回归：未激活时路径不变
-- ============================================================

function TestModE2E.testNoActiveNoRegression()
    print("\n=== Test: no active MOD -> paths unchanged ===")
    local ModData = freshModData(nil)
    local CC = fakeCC()
    local CONFIG = { DataPath = "data/", ScriptPath = "script/" }    ModData.RewriteConstants(CC, CONFIG)
    TestHelper.assertEquals("data/mmap.grp", CC.MMAPPicFile[2], "mmap unchanged")
    TestHelper.assertEquals("data/smap.grp", CC.SMAPPicFile[2], "smap unchanged")
    TestHelper.assertEquals("data/fight%03d.grp", CC.FightPicFile[2], "fight format unchanged")
    TestHelper.assertEquals("script/oldtalk.grp", CC.TalkGrpFile, "talk unchanged")
end

function TestModE2E.runAll()
    print("\n" .. string.rep("=", 60))
    print("名动天下 无头端到端验证")
    print(string.rep("=", 60))
    restoreLoadfile()
    TestHelper.resetCounts()

    TestModE2E.testActivateRewritesPathsAndIni()
    TestModE2E.testEventScriptFallback()
    TestModE2E.testTalkTableContent()
    TestModE2E.testRuntimeTalkGrpIdx()
    TestModE2E.testFightFilesDynamic()
    TestModE2E.testNoActiveNoRegression()

    TestHelper.printSummary()
    return TestHelper.getStats().allPassed
end

return TestModE2E
