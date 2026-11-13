-- test_runner.lua
-- 测试运行器 - 运行所有单元测试

local TestHelper = require("tests.test_helper")
local TestStateMachine = require("tests.unit.test_state_machine")
local TestInputManager = require("tests.unit.test_input_manager")
local TestEventBridge = require("tests.unit.test_event_bridge")
local TestCoroutineScheduler = require("tests.unit.test_coroutine_scheduler")
local TestByteIO = require("tests.unit.test_byte_io")
local TestScriptLoader = require("tests.unit.test_script_loader")
local TestItemAsync = require("tests.unit.test_item_async")
local TestWarAsync = require("tests.unit.test_war_async")
local TestEngineAPI = require("tests.unit.test_engine_api")
local TestEngineTest = require("tests.unit.test_engine_test")
local TestModIni = require("tests.unit.test_mod_ini")
local TestModData = require("tests.unit.test_mod_data")
local TestModEncoding = require("tests.unit.test_mod_encoding")
local TestModBuild = require("tests.unit.test_mod_build")
local TestModResources = require("tests.unit.test_mod_resources")
local TestModAudit = require("tests.unit.test_mod_audit")
local TestFormatSpec = require("tests.unit.test_format_spec")
local TestModE2E = require("tests.unit.test_mod_e2e")
local TestModBoot = require("tests.unit.test_mod_boot")
local TestSceneName = require("tests.unit.test_scene_name")
local TestFontSize = require("tests.unit.test_font_size")
local TestNewEvent = require("tests.unit.test_new_event")
local TestDialogLayout = require("tests.unit.test_dialog_layout")
local TestTextBoxLayout = require("tests.unit.test_text_box_layout")
local TestMmapDepth = require("tests.unit.test_mmap_depth")
local TestCloud = require("tests.unit.test_cloud")
local TestVersionCompat = require("tests.unit.test_version_compat")

local TestRunner = {}

-- 运行前检查：MOD 相关测试依赖两个「不随 git 分发」的目录。
-- 缺任何一个就**跳过** MOD 组（其余模块照常跑），并尽早明确告知 ——
-- 否则表现为几十条「参考数据缺失」式失败 + 一处 nil 索引崩溃，很难定位。
local MOD_MODULES = {
    "mod_ini", "mod_data", "mod_encoding", "mod_build", "mod_resources",
    "mod_audit", "format_spec", "mod_e2e", "mod_boot",
}

local modDataReady = nil   -- nil = 未检查

-- 检查（并缓存）MOD 测试数据是否就绪。
-- @return boolean
local function checkPrerequisites()
    if modDataReady ~= nil then return modDataReady end
    local Fs = require("framework.fs_compat")
    local missing = {}
    if not Fs.directoryExists("../reference/allmods") then
        missing[#missing + 1] = {
            path = "../reference/allmods",
            hint = "MOD 源数据（20 个 kys-* 目录），见 MOD_20IN1_GUIDE.md",
        }
    end
    if not Fs.directoryExists("mods") then
        missing[#missing + 1] = {
            path = "mods",
            hint = "MOD 构建产物，先运行: lua tools/mod_build.lua --all",
        }
    end
    if #missing == 0 then
        modDataReady = true
        return true
    end

    print("\n" .. string.rep("!", 60))
    print("缺少 MOD 测试所需目录（git 不分发，需本地准备）：")
    for _, m in ipairs(missing) do
        print(string.format("  ✗ %-24s  %s", m.path, m.hint))
    end
    print("")
    print("以下模块将被跳过：" .. table.concat(MOD_MODULES, " "))
    print("其余模块照常运行。")
    print(string.rep("!", 60) .. "\n")
    modDataReady = false
    return false
end
TestRunner.hasModData = function() return checkPrerequisites() end

-- 该模块名是否属于 MOD 组
local function isModModule(name)
    for _, m in ipairs(MOD_MODULES) do
        if m == name then return true end
    end
    return false
end

-- MOD 数据缺失时跳过某模块，返回「算作通过」的 true
local function skipModModule(name)
    print(string.format("  [SKIP] %s（缺少 reference/allmods 或 mods/）", name))
    return true
end

-- 运行一个 MOD 组模块；数据缺失时跳过。
-- @param name string 模块名（用于提示）
-- @param fn function 该模块的 runAll
local function runModModule(name, fn)
    if not checkPrerequisites() then
        return skipModModule(name)
    end
    return fn()
end

-- 运行所有测试
function TestRunner.runAll()
    print("\n" .. string.rep("=", 60))
    print("金庸群侠传 Love2D 重构 - 单元测试套件")
    print(string.rep("=", 60))

    checkPrerequisites()

    -- 套件入口自愈：各 MOD 产物 save/ 与源 save/ 逐字节对齐
    -- （清理上次运行中断残留，见 TestHelper.healAllModSaves 注释）
    TestHelper.healAllModSaves()
    
    local allPassed = true
    local totalStats = { total = 0, passed = 0, failed = 0 }
    
    -- 运行状态机测试
    print("\n" .. string.rep("-", 60))
    print("运行状态机测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local smResult = TestStateMachine.runAll()
    local smStats = TestHelper.getStats()
    totalStats.total = totalStats.total + smStats.total
    totalStats.passed = totalStats.passed + smStats.passed
    totalStats.failed = totalStats.failed + smStats.failed
    allPassed = allPassed and smResult
    
    -- 运行输入管理器测试
    print("\n" .. string.rep("-", 60))
    print("运行输入管理器测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local imResult = TestInputManager.runAll()
    local imStats = TestHelper.getStats()
    totalStats.total = totalStats.total + imStats.total
    totalStats.passed = totalStats.passed + imStats.passed
    totalStats.failed = totalStats.failed + imStats.failed
    allPassed = allPassed and imResult
    
    -- 运行事件桥接测试
    print("\n" .. string.rep("-", 60))
    print("运行事件桥接测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local ebResult = TestEventBridge.runAll()
    local ebStats = TestHelper.getStats()
    totalStats.total = totalStats.total + ebStats.total
    totalStats.passed = totalStats.passed + ebStats.passed
    totalStats.failed = totalStats.failed + ebStats.failed
    allPassed = allPassed and ebResult
    
    -- 运行协程调度器测试
    print("\n" .. string.rep("-", 60))
    print("运行协程调度器测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local csResult = TestCoroutineScheduler.runAll()
    local csStats = TestHelper.getStats()
    totalStats.total = totalStats.total + csStats.total
    totalStats.passed = totalStats.passed + csStats.passed
    totalStats.failed = totalStats.failed + csStats.failed
    allPassed = allPassed and csResult
    
    -- 运行 Byte I/O 测试
    print("\n" .. string.rep("-", 60))
    print("运行 Byte I/O 测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local bioResult = TestByteIO.runAll()
    local bioStats = TestHelper.getStats()
    totalStats.total = totalStats.total + bioStats.total
    totalStats.passed = totalStats.passed + bioStats.passed
    totalStats.failed = totalStats.failed + bioStats.failed
    allPassed = allPassed and bioResult

    print("\n" .. string.rep("-", 60))
    print("运行脚本加载器测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local slResult = TestScriptLoader.runAll()
    local slStats = TestHelper.getStats()
    totalStats.total = totalStats.total + slStats.total
    totalStats.passed = totalStats.passed + slStats.passed
    totalStats.failed = totalStats.failed + slStats.failed
    allPassed = allPassed and slResult
    
    print("\n" .. string.rep("-", 60))
    print("运行物品系统测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local itemResult = TestItemAsync.runAll()
    local itemStats = TestHelper.getStats()
    totalStats.total = totalStats.total + itemStats.total
    totalStats.passed = totalStats.passed + itemStats.passed
    totalStats.failed = totalStats.failed + itemStats.failed
    allPassed = allPassed and itemResult
    
    print("\n" .. string.rep("-", 60))
    print("运行战斗系统测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local warResult = TestWarAsync.runAll()
    local warStats = TestHelper.getStats()
    totalStats.total = totalStats.total + warStats.total
    totalStats.passed = totalStats.passed + warStats.passed
    totalStats.failed = totalStats.failed + warStats.failed
    allPassed = allPassed and warResult
    
    print("\n" .. string.rep("-", 60))
    print("运行 EngineAPI 接口测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local eaResult = TestEngineAPI.runAll()
    local eaStats = TestHelper.getStats()
    totalStats.total = totalStats.total + eaStats.total
    totalStats.passed = totalStats.passed + eaStats.passed
    totalStats.failed = totalStats.failed + eaStats.failed
    allPassed = allPassed and eaResult
    
    print("\n" .. string.rep("-", 60))
    print("运行测试引擎测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local etResult = TestEngineTest.runAll()
    local etStats = TestHelper.getStats()
    totalStats.total = totalStats.total + etStats.total
    totalStats.passed = totalStats.passed + etStats.passed
    totalStats.failed = totalStats.failed + etStats.failed
    allPassed = allPassed and etResult

    print("\n" .. string.rep("-", 60))
    print("运行 ModIni 解析器测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local miResult = runModModule("mod_ini", TestModIni.runAll)
    local miStats = TestHelper.getStats()
    totalStats.total = totalStats.total + miStats.total
    totalStats.passed = totalStats.passed + miStats.passed
    totalStats.failed = totalStats.failed + miStats.failed
    allPassed = allPassed and miResult
    
    print("\n" .. string.rep("-", 60))
    print("运行 ModData 数据回退测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local mdResult = runModModule("mod_data", TestModData.runAll)
    local mdStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mdStats.total
    totalStats.passed = totalStats.passed + mdStats.passed
    totalStats.failed = totalStats.failed + mdStats.failed
    allPassed = allPassed and mdResult
    
    print("\n" .. string.rep("-", 60))
    print("运行 MOD 编码/布局逆向测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local meResult = runModModule("mod_encoding", TestModEncoding.runAll)
    local meStats = TestHelper.getStats()
    totalStats.total = totalStats.total + meStats.total
    totalStats.passed = totalStats.passed + meStats.passed
    totalStats.failed = totalStats.failed + meStats.failed
    allPassed = allPassed and meResult
    
    print("\n" .. string.rep("-", 60))
    print("运行 mod_build 构建期测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local buildResult = runModModule("mod_build", TestModBuild.runAll)
    local buildStats = TestHelper.getStats()
    totalStats.total = totalStats.total + buildStats.total
    totalStats.passed = totalStats.passed + buildStats.passed
    totalStats.failed = totalStats.failed + buildStats.failed
    allPassed = allPassed and buildResult

    print("\n" .. string.rep("-", 60))
    print("运行 MOD 资源分类测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local resResult = runModModule("mod_resources", TestModResources.runAll)
    local resStats = TestHelper.getStats()
    totalStats.total = totalStats.total + resStats.total
    totalStats.passed = totalStats.passed + resStats.passed
    totalStats.failed = totalStats.failed + resStats.failed
    allPassed = allPassed and resResult

    print("\n" .. string.rep("-", 60))
    print("运行 MOD 资源穷举审计测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local auditResult = runModModule("mod_audit", TestModAudit.runAll)
    local auditStats = TestHelper.getStats()
    totalStats.total = totalStats.total + auditStats.total
    totalStats.passed = totalStats.passed + auditStats.passed
    totalStats.failed = totalStats.failed + auditStats.failed
    allPassed = allPassed and auditResult

    print("\n" .. string.rep("-", 60))
    print("运行格式字段级覆盖测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local fmtResult = runModModule("format_spec", TestFormatSpec.runAll)
    local fmtStats = TestHelper.getStats()
    totalStats.total = totalStats.total + fmtStats.total
    totalStats.passed = totalStats.passed + fmtStats.passed
    totalStats.failed = totalStats.failed + fmtStats.failed
    allPassed = allPassed and fmtResult

    print("\n" .. string.rep("-", 60))
    print("运行名动天下无头端到端验证...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local e2eResult = runModModule("mod_e2e", TestModE2E.runAll)
    local e2eStats = TestHelper.getStats()
    totalStats.total = totalStats.total + e2eStats.total
    totalStats.passed = totalStats.passed + e2eStats.passed
    totalStats.failed = totalStats.failed + e2eStats.failed
    allPassed = allPassed and e2eResult
    
    print("\n" .. string.rep("-", 60))
    print("运行全启动链路无头验证...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local bootResult = runModModule("mod_boot", TestModBoot.runAll)
    local bootStats = TestHelper.getStats()
    totalStats.total = totalStats.total + bootStats.total
    totalStats.passed = totalStats.passed + bootStats.passed
    totalStats.failed = totalStats.failed + bootStats.failed
    allPassed = allPassed and bootResult

    -- 场景名测试放在最后：它会 LoadRecord 并设置全局 JY 状态，
    -- 而 test_mod_boot 要求"必须在最后运行"且不能被前面用例污染。
    print("\n" .. string.rep("-", 60))
    print("运行场景名提示测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local snResult = TestSceneName.runAll()
    local snStats = TestHelper.getStats()
    totalStats.total = totalStats.total + snStats.total
    totalStats.passed = totalStats.passed + snStats.passed
    totalStats.failed = totalStats.failed + snStats.failed
    allPassed = allPassed and snResult

    print("\n" .. string.rep("-", 60))
    print("运行字体大小测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local fsResult = TestFontSize.runAll()
    local fsStats = TestHelper.getStats()
    totalStats.total = totalStats.total + fsStats.total
    totalStats.passed = totalStats.passed + fsStats.passed
    totalStats.failed = totalStats.failed + fsStats.failed
    allPassed = allPassed and fsResult

    print("\n" .. string.rep("-", 60))
    print("运行 newevent 事件分派测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local neResult = TestNewEvent.runAll()
    local neStats = TestHelper.getStats()
    totalStats.total = totalStats.total + neStats.total
    totalStats.passed = totalStats.passed + neStats.passed
    totalStats.failed = totalStats.failed + neStats.failed
    allPassed = allPassed and neResult

    print("\n" .. string.rep("-", 60))
    print("运行对话框排版测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local dlgResult = TestDialogLayout.runAll()
    local dlgStats = TestHelper.getStats()
    totalStats.total = totalStats.total + dlgStats.total
    totalStats.passed = totalStats.passed + dlgStats.passed
    totalStats.failed = totalStats.failed + dlgStats.failed
    allPassed = allPassed and dlgResult

    print("\n" .. string.rep("-", 60))
    print("运行单行文本框尺寸测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local tboxResult = TestTextBoxLayout.runAll()
    local tboxStats = TestHelper.getStats()
    totalStats.total = totalStats.total + tboxStats.total
    totalStats.passed = totalStats.passed + tboxStats.passed
    totalStats.failed = totalStats.failed + tboxStats.failed
    allPassed = allPassed and tboxResult

    print("\n" .. string.rep("-", 60))
    print("运行主地图 2.5D 遮挡关系测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local mmResult = TestMmapDepth.runAll()
    local mmStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mmStats.total
    totalStats.passed = totalStats.passed + mmStats.passed
    totalStats.failed = totalStats.failed + mmStats.failed
    allPassed = allPassed and mmResult

    print("\n" .. string.rep("-", 60))
    print("运行主地图飘云测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local clResult = TestCloud.runAll()
    local clStats = TestHelper.getStats()
    totalStats.total = totalStats.total + clStats.total
    totalStats.passed = totalStats.passed + clStats.passed
    totalStats.failed = totalStats.failed + clStats.failed
    allPassed = allPassed and clResult

    print("\n" .. string.rep("-", 60))
    print("运行跨版本兼容性测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local vcResult = TestVersionCompat.runAll()
    local vcStats = TestHelper.getStats()
    totalStats.total = totalStats.total + vcStats.total
    totalStats.passed = totalStats.passed + vcStats.passed
    totalStats.failed = totalStats.failed + vcStats.failed
    allPassed = allPassed and vcResult

    print("\n" .. string.rep("=", 60))
    print("总体测试结果")
    print(string.rep("=", 60))
    print(string.format("总测试数: %d", totalStats.total))
    print(string.format("通过: %d", totalStats.passed))
    print(string.format("失败: %d", totalStats.failed))
    print(string.rep("=", 60))
    
    if allPassed then
        print("✓ 所有测试通过!")
    else
        print("✗ 部分测试失败")
    end
    print(string.rep("=", 60))
    
    return allPassed
end

-- 运行单个测试模块
function TestRunner.runModule(moduleName)
    TestHelper.resetCounts()
    -- 与全量运行相同的入口自愈（单模块入口同样适用）
    TestHelper.healAllModSaves()
    
    if moduleName == "state_machine" then
        return TestStateMachine.runAll()
    elseif moduleName == "input_manager" then
        return TestInputManager.runAll()
    elseif moduleName == "event_bridge" then
        return TestEventBridge.runAll()
    elseif moduleName == "coroutine_scheduler" then
        return TestCoroutineScheduler.runAll()
    elseif moduleName == "byte_io" then
        return TestByteIO.runAll()
    elseif moduleName == "script_loader" then
        return TestScriptLoader.runAll()
    elseif moduleName == "item_async" then
        return TestItemAsync.runAll()
    elseif moduleName == "war_async" then
        return TestWarAsync.runAll()
    elseif moduleName == "engine_api" then
        return TestEngineAPI.runAll()
    elseif moduleName == "engine_test" then
        return TestEngineTest.runAll()
    elseif moduleName == "mod_ini" then
        return runModModule("mod_ini", TestModIni.runAll)
    elseif moduleName == "mod_data" then
        return runModModule("mod_data", TestModData.runAll)
    elseif moduleName == "mod_encoding" then
        return runModModule("mod_encoding", TestModEncoding.runAll)
    elseif moduleName == "mod_build" then
        return runModModule("mod_build", TestModBuild.runAll)
    elseif moduleName == "mod_resources" then
        return runModModule("mod_resources", TestModResources.runAll)
    elseif moduleName == "mod_audit" then
        return runModModule("mod_audit", TestModAudit.runAll)
    elseif moduleName == "format_spec" then
        return runModModule("format_spec", TestFormatSpec.runAll)
    elseif moduleName == "mod_e2e" then
        return runModModule("mod_e2e", TestModE2E.runAll)
    elseif moduleName == "mod_boot" then
        return runModModule("mod_boot", TestModBoot.runAll)
    elseif moduleName == "text_box_layout" then
        return TestTextBoxLayout.runAll()
    elseif moduleName == "dialog_layout" then
        return TestDialogLayout.runAll()
    elseif moduleName == "mmap_depth" then
        return TestMmapDepth.runAll()
    elseif moduleName == "cloud" then
        return TestCloud.runAll()
    elseif moduleName == "version_compat" then
        return TestVersionCompat.runAll()
    else
        print("未知测试模块: " .. tostring(moduleName))
        print("可用模块: state_machine, input_manager, event_bridge, coroutine_scheduler, byte_io, script_loader, item_async, war_async, engine_api, engine_test, mod_ini, mod_data, mod_encoding, mod_build, mod_resources, mod_audit, format_spec, mod_e2e, mod_boot, dialog_layout, text_box_layout, mmap_depth, cloud, version_compat")
        return false
    end
end

-- 如果直接运行此文件
if arg and arg[0]:match("test_runner.lua$") then
    if arg[1] then
        -- 运行指定模块
        TestRunner.runModule(arg[1])
    else
        -- 运行所有测试
        TestRunner.runAll()
    end
end

return TestRunner
