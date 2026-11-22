-- test_engine_io_portability.lua
-- framework 主路径零 stdlib IO/时间（change: framework-io-portability）
--
-- 守的坑：
--   framework 里曾有 4 处**无条件**直接调 Lua 标准库：
--     ① framework/mod_ini.lua:23          io.open(path, "rb")
--     ② framework/jymain_adapter.lua:183  math.randomseed(os.time())
--     ③ framework/game_states.lua:1006    os.date("%Y-%m-%d %H:%M")
--     ④ framework/lib_log.lua:22          os.date("%H:%M:%S")
--
--   `io.*` / `os.*` 在 Godot/Unreal 上不存在（GDScript 只有 FileAccess /
--   Time，Unreal 只有 FFileHelper / FDateTime）。这些调用点都在**主路径**
--   （MOD ini 加载、启动、死亡界面、每次日志），换引擎必然崩。
--
--   本文件断言的不是「代码里没出现 os.date 字样」（兜底分支刻意保留），
--   而是语义要求：**EngineAPI 可用时，stdlib 一次都不许被调到**。
--   实现方式是把 io.open / os.date / os.time 换成计数桩，再走真实调用链。

local TestHelper = require("tests.test_helper")
local TestPortability = {}

-- ============================================================
-- stdlib 计数桩
-- ============================================================

--- 把 stdlib 换成计数桩（返回 restore 函数与计数表）
--
-- 计数表字段：ioOpen / osDate / osTime。
-- 桩本身**委托**原函数：这样若被测代码走了兜底分支，行为仍正确，
-- 只有计数会暴露「不该走兜底却走了」。
local function spyStdlib()
    local counts = { ioOpen = 0, osDate = 0, osTime = 0 }
    local saved = {
        ioOpen = io.open, osDate = os.date, osTime = os.time,
    }
    io.open = function(...)
        counts.ioOpen = counts.ioOpen + 1
        return saved.ioOpen(...)
    end
    os.date = function(...)
        counts.osDate = counts.osDate + 1
        return saved.osDate(...)
    end
    os.time = function(...)
        counts.osTime = counts.osTime + 1
        return saved.osTime(...)
    end
    local function restore()
        io.open = saved.ioOpen
        os.date = saved.osDate
        os.time = saved.osTime
    end
    return counts, restore
end

--- 临时替换 EngineAPI（保存/恢复）
local function withEngineAPI(fake, fn)
    local saved = rawget(_G, "EngineAPI")
    rawset(_G, "EngineAPI", fake)
    local ok, err = pcall(fn)
    rawset(_G, "EngineAPI", saved)
    if not ok then error(err, 0) end
end

--- 读源码（测试在 game/ 下跑，按两种相对路径找）
local function readSource(rel)
    for _, p in ipairs({ rel, "../game/" .. rel }) do
        local f = io.open(p, "r")
        if f then
            local s = f:read("*a")
            f:close()
            return s
        end
    end
    return nil
end

--- 去掉注释（判源码级断言时必须去注释：注释里写 os.date 是说明文字）
local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

-- ============================================================
-- ① mod_ini.readFile：EngineAPI.file.read 优先
-- ============================================================

function TestPortability.testModIniPrefersEngineAPI()
    print("\n=== Test: ModIni.readFile 优先 EngineAPI.file.read（不碰 io.open）===")
    local ModIni = require("framework.mod_ini")

    local asked = nil
    withEngineAPI({
        file = {
            read = function(path)
                asked = path
                return "[system]\nWALK_speed = 28\n"
            end,
        },
    }, function()
        local counts, restore = spyStdlib()
        local text, err = ModIni.readFile("mods/kys-pascal/kysmod.ini")
        restore()

        TestHelper.assertEquals(nil, err, "有契约时不应返回错误")
        TestHelper.assertNotNil(text, "有契约时应返回内容")
        TestHelper.assertEquals("mods/kys-pascal/kysmod.ini", asked,
            "应把路径原样交给 EngineAPI.file.read")
        TestHelper.assertEquals(0, counts.ioOpen,
            "EngineAPI 可用时 readFile 不得调 io.open（换引擎后它不存在）")
    end)
end

function TestPortability.testModIniFallsBackToStdlib()
    print("\n=== Test: ModIni.readFile 无契约时回落 io.open（纯 Lua 测试环境）===")
    local ModIni = require("framework.mod_ini")
    local Fs = require("framework.fs_compat")

    -- 临时文件（内容可断言），用完删除
    local tmp = Fs.tempPath("test_engine_io_portability_ini.tmp")
    local out = io.open(tmp, "wb")
    TestHelper.assertNotNil(out, "应能创建临时文件")
    out:write("[system]\nWALK_speed = 28\n")
    out:close()

    withEngineAPI(nil, function()
        local text, err = ModIni.readFile(tmp)
        TestHelper.assertEquals(nil, err, "无契约时应能读（io 兜底）")
        TestHelper.assertNotNil(text and text:find("WALK_speed", 1, true),
            "兜底读取的内容应正确")

        -- 不存在的路径仍返回 nil + 错误信息（与改造前一致）
        local t2, e2 = ModIni.readFile(tmp .. ".does-not-exist")
        TestHelper.assertEquals(nil, t2, "缺失文件应返回 nil")
        TestHelper.assertNotNil(e2, "缺失文件应返回错误信息")
    end)
    os.remove(tmp)
end

-- ============================================================
-- ② 随机种子：EngineAPI.time.getTimeSeconds 优先
-- ============================================================

function TestPortability.testClockRandomSeedUsesEngineTime()
    print("\n=== Test: Clock.randomSeed 优先 EngineAPI.time（不碰 os.time）===")
    local Clock = require("framework.clock")

    withEngineAPI({
        time = { getTimeSeconds = function() return 12.345 end },
    }, function()
        -- 固定时间源 → 确定性种子（毫秒取整：12.345 → 12345）
        TestHelper.assertEquals(12345, Clock.randomSeed(),
            "有契约时种子 = floor(getTimeSeconds × 1000)（确定性、可断言）")

        local counts, restore = spyStdlib()
        local seed = Clock.randomSeed()
        restore()
        TestHelper.assertEquals(12345, seed, "再次取值仍确定")
        TestHelper.assertEquals(0, counts.osTime,
            "EngineAPI 可用时 randomSeed 不得调 os.time")
    end)
end

function TestPortability.testClockRandomSeedFallsBack()
    print("\n=== Test: Clock.randomSeed 无契约时回落 os.time ===")
    local Clock = require("framework.clock")

    withEngineAPI(nil, function()
        local counts, restore = spyStdlib()
        local seed = Clock.randomSeed()
        restore()
        TestHelper.assertEquals(1, counts.osTime,
            "无契约时应恰好调一次 os.time（与改造前逐字一致）")
        TestHelper.assertNotNil(seed, "兜底应返回种子")
    end)
end

function TestPortability.testStartupRandomseedGoesThroughClock()
    print("\n=== Test: jymain_adapter 启动不再无条件 os.time ===")
    local src = readSource("framework/jymain_adapter.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain_adapter.lua")
    local code = stripComments(src)

    TestHelper.assertNotNil(code:find("math.randomseed(Clock.randomSeed())", 1, true),
        "启动随机种子必须走 Clock.randomSeed()（契约优先）")
    TestHelper.assertNil(code:find("math.randomseed(os.time())", 1, true),
        "代码行不得再有 math.randomseed(os.time())（os.time 换引擎不存在）")
end

-- ============================================================
-- ③④ 墙上时间：framework/clock.lua 收敛，game_states / lib_log 走它
-- ============================================================

function TestPortability.testClockFormatNowPrefersContract()
    print("\n=== Test: Clock.formatNow 优先 EngineAPI.time.formatNow（不碰 os.date）===")
    local Clock = require("framework.clock")

    local gotFmt = nil
    withEngineAPI({
        time = {
            formatNow = function(fmt)
                gotFmt = fmt
                return "2026-11-22 15:00"
            end,
        },
    }, function()
        local counts, restore = spyStdlib()
        local s = Clock.formatNow("%Y-%m-%d %H:%M")
        restore()

        TestHelper.assertEquals("2026-11-22 15:00", s, "应原样采用契约结果")
        TestHelper.assertEquals("%Y-%m-%d %H:%M", gotFmt, "格式串应透传给契约")
        TestHelper.assertEquals(0, counts.osDate,
            "EngineAPI 可用时 formatNow 不得调 os.date")
    end)
end

function TestPortability.testClockFormatNowFallsBack()
    print("\n=== Test: Clock.formatNow 无契约时回落 os.date ===")
    local Clock = require("framework.clock")

    withEngineAPI(nil, function()
        local counts, restore = spyStdlib()
        local s = Clock.formatNow("%Y")
        restore()
        TestHelper.assertEquals(1, counts.osDate, "无契约时应恰好调一次 os.date")
        TestHelper.assertEquals(4, #s, "兜底结果应是 4 位年份")
    end)
end

function TestPortability.testClockFormatNowNeverThrows()
    print("\n=== Test: 契约异常/返回空时降级为 \"\"（不崩）===")
    local Clock = require("framework.clock")

    -- 契约抛错
    withEngineAPI({
        time = { formatNow = function() error("boom") end },
    }, function()
        local ok, s = pcall(Clock.formatNow)
        TestHelper.assertTrue(ok, "契约抛错不得冒泡（日志路径不能崩）")
        TestHelper.assertEquals("string", type(s), "仍应返回字符串")
    end)

    -- 契约返回非字符串 → 走 os.date 兜底，仍拿得到字符串
    withEngineAPI({ time = { formatNow = function() return nil end } }, function()
        local s = Clock.formatNow("%Y")
        TestHelper.assertEquals(4, #s, "契约返回 nil 时应回落 os.date")
    end)

    -- 契约与 os.date 都不可用 → ""（由调用方决定怎么降级）
    withEngineAPI({ time = { formatNow = function() return "" end } }, function()
        local savedDate = os.date
        os.date = function() error("no date") end
        local s = Clock.formatNow("%Y")
        os.date = savedDate
        TestHelper.assertEquals("", s, "全部手段失效时返回空串")
    end)
end

function TestPortability.testGameStatesTimestampUsesClock()
    print("\n=== Test: GAME_DEAD 时间戳走 Clock（代码行零 os.date）===")
    local src = readSource("framework/game_states.lua")
    TestHelper.assertNotNil(src, "应能读到 game_states.lua")
    local code = stripComments(src)

    TestHelper.assertNotNil(code:find('Clock.formatNow("%Y-%m-%d %H:%M")', 1, true),
        "死亡时间戳必须走 Clock.formatNow（契约优先）")
    TestHelper.assertNil(code:find("os%.date", 1),
        "game_states 代码行不得再有 os.date（换引擎不存在）")
end

function TestPortability.testLibLogTimestampUsesClock()
    print("\n=== Test: 日志时间戳走 Clock，且 EngineAPI 可用时不碰 os.date ===")
    local src = readSource("framework/lib_log.lua")
    TestHelper.assertNotNil(src, "应能读到 lib_log.lua")
    local code = stripComments(src)
    TestHelper.assertNil(code:find("os%.date", 1),
        "lib_log 代码行不得再有 os.date（每次日志都会走这条路）")

    package.loaded["framework.lib_log"] = nil
    local okLog, _ = pcall(require, "framework.lib_log")
    TestHelper.assertTrue(okLog, "lib_log 应能加载")

    -- 通过 io.write 抓 stdout 分支（logfile=nil）
    local printed = {}
    local savedWrite = io.write
    io.write = function(s)
        printed[#printed + 1] = s
        return true
    end
    local counts, restore = spyStdlib()
    withEngineAPI({
        time = { formatNow = function() return "07:08:09" end },
    }, function()
        -- lib_log 把 Log 定义为**全局**函数；用 rawget 读，
        -- 避免严格 _G（mod_boot 装过）把读取判成未声明全局。
        local LogFn = rawget(_G, "Log")
        TestHelper.assertEquals("function", type(LogFn), "lib_log 应导出全局 Log")
        LogFn(nil, false, "hello %s", "world")
    end)
    restore()
    io.write = savedWrite

    local out = table.concat(printed)
    TestHelper.assertNotNil(out:find("07:08:09", 1, true),
        "日志行首应采用契约给出的时间戳，实际输出: " .. out:sub(1, 60))
    TestHelper.assertNotNil(out:find("hello world", 1, true), "日志正文应完整")
    TestHelper.assertEquals(0, counts.osDate,
        "EngineAPI 可用时日志不得调 os.date")
    package.loaded["framework.lib_log"] = nil
end

function TestPortability.testLibLogDegradesToDash()
    print("\n=== Test: 无时间戳来源时日志降级为 \"-\"（不崩）===")
    package.loaded["framework.lib_log"] = nil
    require("framework.lib_log")

    local printed = {}
    local savedWrite = io.write
    io.write = function(s)
        printed[#printed + 1] = s
        return true
    end
    withEngineAPI({ time = { formatNow = function() return "" end } }, function()
        local savedDate = os.date
        os.date = function() error("no date") end
        local LogFn = rawget(_G, "Log")
        LogFn(nil, false, "no-timestamp")
        os.date = savedDate
    end)
    io.write = savedWrite

    local out = table.concat(printed)
    TestHelper.assertNotNil(out:find("^-", 1), "应以 \"-\" 开头，实际: " .. out:sub(1, 20))
    TestHelper.assertNotNil(out:find("no-timestamp", 1, true), "正文仍应写出")
    package.loaded["framework.lib_log"] = nil
end

-- ============================================================
-- 契约完整性：time.formatNow 在 4 引擎都必须显式实现
-- ============================================================

function TestPortability.testFormatNowImplementedInAllEngines()
    print("\n=== Test: 4 引擎都实现 time.formatNow ===")
    local sources = {
        { "LOVE", "engine-love2d/engine_love2d.lua" },
        { "MUD",  "engine-mud/engine_mud.lua" },
        { "Web",  "engine-web/engine_web.lua" },
        { "Test", "tests/engine_test.lua" },
    }
    for _, e in ipairs(sources) do
        local src = readSource(e[2])
        TestHelper.assertNotNil(src, e[1] .. " 源码应可读: " .. e[2])
        local code = stripComments(src)
        local found = code:find("time%.formatNow", 1)
        TestHelper.assertNotNil(found, e[1] .. " 必须显式实现 time.formatNow（缺了会靠空桩，换引擎才发现）")
    end

    -- 契约文件本身必须有声明（否则引擎实现了也没人知道）
    local apiSrc = readSource("engine-love2d/engine_api.lua")
    TestHelper.assertNotNil(apiSrc, "应能读到 engine_api.lua")
    TestHelper.assertNotNil(apiSrc:find("M.time.formatNow", 1, true),
        "engine_api.lua 必须声明 time.formatNow")
end

function TestPortability.testFormatNowBehaviorAcrossEngines()
    print("\n=== Test: MUD/Web/Test 的 formatNow 返回非空本地时间串 ===")
    -- MUD 引擎加载时会写 _G.EngineAPI（它就是那个模块），必须保存/恢复，
    -- 否则后续模块会拿到 MUD 引擎当 mock（历史上踩过同类污染）。
    local savedEA = rawget(_G, "EngineAPI")
    for _, modName in ipairs({ "engine-mud/engine_mud", "engine-web/engine_web" }) do
        local ok, mod = pcall(require, modName)
        TestHelper.assertTrue(ok, modName .. " 应能加载: " .. tostring(mod))
        if ok and mod and mod.time and mod.time.formatNow then
            local s = mod.time.formatNow("%Y")
            TestHelper.assertTrue(type(s) == "string" and #s > 0,
                modName .. " 的 formatNow 应返回非空串，实测 " .. tostring(s))
        end
    end
    rawset(_G, "EngineAPI", savedEA)

    -- Test 引擎：可注入固定串（确定性断言的基础）
    package.loaded["tests.engine_test"] = nil
    local ET = require("tests.engine_test")
    ET.time.setNow("2026-11-22 15:00")
    TestHelper.assertEquals("2026-11-22 15:00", ET.time.formatNow("%Y-%m-%d %H:%M"),
        "Test 引擎支持 setNow 注入固定时间串")
    ET.time.setNow(nil)
    TestHelper.assertTrue(#ET.time.formatNow("%Y") == 4,
        "setNow(nil) 后恢复真实 os.date 行为")
end

-- ============================================================
-- ⑨ mod_data.readActiveFile：EngineAPI.file.read 优先
--    （port-engine-boot 复审计补漏的第 1 处）
-- ============================================================

function TestPortability.testModDataReadActivePrefersEngineAPI()
    print("\n=== Test: ModData.readActiveFile 优先 EngineAPI.file.read ===")
    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")

    local counts, restore = spyStdlib()
    withEngineAPI({
        file = {
            read = function(path) return "mingdong" end,
            exists = function() return true end,
        },
    }, function()
        local c = ModData.readActiveFile()
        TestHelper.assertEquals("mingdong", c, "应取到契约返回的内容")
        TestHelper.assertEquals(0, counts.ioOpen,
            "EngineAPI.file.read 可用时不得调 io.open（实测 " .. counts.ioOpen .. " 次）")
    end)
    restore()
    package.loaded["framework.mod_data"] = nil
end

function TestPortability.testModDataReadActiveFallsBack()
    print("\n=== Test: ModData.readActiveFile 无契约时回退 io.open ===")
    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")

    local counts, restore = spyStdlib()
    withEngineAPI(nil, function()
        -- 文件不存在 → 返回 nil；关键是它**试过** io.open（兜底分支活着）
        local c = ModData.readActiveFile()
        TestHelper.assertEquals(nil, c, "文件不存在应返回 nil")
        TestHelper.assertEquals(1, counts.ioOpen,
            "无契约时必须走 io.open 兜底（实测 " .. counts.ioOpen .. " 次）")
    end)
    restore()
    package.loaded["framework.mod_data"] = nil
end

-- ============================================================
-- ⑩ mod_data.WarRecordCount：EngineAPI.file.getSize 优先
--    （第 2 处）
-- ============================================================

function TestPortability.testWarRecordCountPrefersEngineAPI()
    print("\n=== Test: ModData.WarRecordCount 优先 EngineAPI.file.getSize ===")
    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")

    local counts, restore = spyStdlib()
    withEngineAPI({
        file = { getSize = function(path) return 1024 end },
    }, function()
        local n = ModData.WarRecordCount("data/war.sta", 128)
        TestHelper.assertEquals(8, n, "1024 / 128 应为 8")
        TestHelper.assertEquals(0, counts.ioOpen,
            "EngineAPI.file.getSize 可用时不得调 io.open（实测 " .. counts.ioOpen .. " 次）")
    end)
    restore()
    package.loaded["framework.mod_data"] = nil
end

function TestPortability.testWarRecordCountFallsBack()
    print("\n=== Test: ModData.WarRecordCount 无契约时回退 io.open ===")
    package.loaded["framework.mod_data"] = nil
    local ModData = require("framework.mod_data")

    local counts, restore = spyStdlib()
    withEngineAPI(nil, function()
        local n = ModData.WarRecordCount("data/nonexistent.bin", 128)
        TestHelper.assertEquals(nil, n, "文件不存在应返回 nil")
        TestHelper.assertEquals(1, counts.ioOpen,
            "无契约时必须走 io.open 兜底（实测 " .. counts.ioOpen .. " 次）")
    end)
    restore()
    package.loaded["framework.mod_data"] = nil
end

function TestPortability.runAll()
    print("\n" .. string.rep("=", 60))
    print("framework 主路径零 stdlib IO/时间（framework-io-portability）")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestPortability.testModIniPrefersEngineAPI()
    TestPortability.testModIniFallsBackToStdlib()
    TestPortability.testClockRandomSeedUsesEngineTime()
    TestPortability.testClockRandomSeedFallsBack()
    TestPortability.testStartupRandomseedGoesThroughClock()
    TestPortability.testClockFormatNowPrefersContract()
    TestPortability.testClockFormatNowFallsBack()
    TestPortability.testClockFormatNowNeverThrows()
    TestPortability.testModDataReadActivePrefersEngineAPI()
    TestPortability.testModDataReadActiveFallsBack()
    TestPortability.testWarRecordCountPrefersEngineAPI()
    TestPortability.testWarRecordCountFallsBack()
    TestPortability.testGameStatesTimestampUsesClock()
    TestPortability.testLibLogTimestampUsesClock()
    TestPortability.testLibLogDegradesToDash()
    TestPortability.testFormatNowImplementedInAllEngines()
    TestPortability.testFormatNowBehaviorAcrossEngines()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_engine_io_portability.lua$") then
    TestPortability.runAll()
end

return TestPortability
