-- test_runner.lua
-- 测试运行器 - 运行所有单元测试

local TestHelper = require("tests.test_helper")

local TestModE2E = require("tests.unit.test_mod_e2e")

-- **所有测试模块放进一个表**：
-- 原因：Lua 5.1 的函数最多 60 个 upvalue，而 runAll 要引用 60+ 个
-- 模块局部变量 → 编译期直接报 "more than 60 upvalues"。
-- 收进一张表后 runAll 只捕获 1 个 upvalue（T）。
local T = {
    state_machine = require("tests.unit.test_state_machine"),
    input_manager = require("tests.unit.test_input_manager"),
    event_bridge = require("tests.unit.test_event_bridge"),
    coroutine_scheduler = require("tests.unit.test_coroutine_scheduler"),
    byte_io = require("tests.unit.test_byte_io"),
    script_loader = require("tests.unit.test_script_loader"),
    item_async = require("tests.unit.test_item_async"),
    war_async = require("tests.unit.test_war_async"),
    engine_api = require("tests.unit.test_engine_api"),
    engine_test = require("tests.unit.test_engine_test"),
    mod_ini = require("tests.unit.test_mod_ini"),
    mod_data = require("tests.unit.test_mod_data"),
    mod_encoding = require("tests.unit.test_mod_encoding"),
    mod_build = require("tests.unit.test_mod_build"),
    mod_resources = require("tests.unit.test_mod_resources"),
    mod_audit = require("tests.unit.test_mod_audit"),
    format_spec = require("tests.unit.test_format_spec"),
    mod_boot = require("tests.unit.test_mod_boot"),
    scene_name = require("tests.unit.test_scene_name"),
    font_size = require("tests.unit.test_font_size"),
    new_event = require("tests.unit.test_new_event"),
    dialog_layout = require("tests.unit.test_dialog_layout"),
    text_box_layout = require("tests.unit.test_text_box_layout"),
    mmap_depth = require("tests.unit.test_mmap_depth"),
    cloud = require("tests.unit.test_cloud"),
    version_compat = require("tests.unit.test_version_compat"),
    settings = require("tests.unit.test_settings"),
    settings_store = require("tests.unit.test_settings_store"),
    audio_settings = require("tests.unit.test_audio_settings"),
    menu_value_item = require("tests.unit.test_menu_value_item"),
    start_menu_layout = require("tests.unit.test_start_menu_layout"),
    engine_system = require("tests.unit.test_engine_system"),
    mouse_input = require("tests.unit.test_mouse_input"),
    menu_hit_test = require("tests.unit.test_menu_hit_test"),
    mouse_menu = require("tests.unit.test_mouse_menu"),
    pathfind = require("tests.unit.test_pathfind"),
    mouse_hover = require("tests.unit.test_mouse_hover"),
    auto_move = require("tests.unit.test_auto_move"),
    interact = require("tests.unit.test_interact"),
    item_status_mouse = require("tests.unit.test_item_status_mouse"),
    battle_mouse = require("tests.unit.test_battle_mouse"),
    base_music = require("tests.unit.test_base_music"),
    input_actions = require("tests.unit.test_input_actions"),
    input_bindings = require("tests.unit.test_input_bindings"),
    virtual_pad = require("tests.unit.test_virtual_pad"),
    volume_menu_esc = require("tests.unit.test_volume_menu_esc"),
    menu_align = require("tests.unit.test_menu_align"),
    sprite_decoder = require("tests.unit.test_sprite_decoder"),
    virtual_pad_wiring = require("tests.unit.test_virtual_pad_wiring"),
    engine_conformance = require("tests.unit.test_engine_conformance"),
    sprite_anim = require("tests.unit.test_sprite_anim"),
    battle_rules = require("tests.unit.test_battle_rules"),
    battle_wiring = require("tests.unit.test_battle_wiring"),
    battle_flow_headless = require("tests.unit.test_battle_flow_headless"),
    war_coroutine_wiring = require("tests.unit.test_war_coroutine_wiring"),
    robustness = require("tests.unit.test_robustness"),
    sprite_atlas_png = require("tests.unit.test_sprite_atlas_png"),
    cal_pic_clip = require("tests.unit.test_cal_pic_clip"),
    battle_robustness = require("tests.unit.test_battle_robustness"),
    wait_for_time = require("tests.unit.test_wait_for_time"),
    wait_frame = require("tests.unit.test_wait_frame"),
    archive_dual_write = require("tests.unit.test_archive_dual_write"),
    map_render = require("tests.unit.test_map_render"),
    map_render_missing = require("tests.unit.test_map_render_missing"),
    audio_semantics = require("tests.unit.test_audio_semantics"),
    engine_io_portability = require("tests.unit.test_engine_io_portability"),
}

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
    local smResult = T.state_machine.runAll()
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
    local imResult = T.input_manager.runAll()
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
    local ebResult = T.event_bridge.runAll()
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
    local csResult = T.coroutine_scheduler.runAll()
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
    local bioResult = T.byte_io.runAll()
    local bioStats = TestHelper.getStats()
    totalStats.total = totalStats.total + bioStats.total
    totalStats.passed = totalStats.passed + bioStats.passed
    totalStats.failed = totalStats.failed + bioStats.failed
    allPassed = allPassed and bioResult

    print("\n" .. string.rep("-", 60))
    print("运行脚本加载器测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local slResult = T.script_loader.runAll()
    local slStats = TestHelper.getStats()
    totalStats.total = totalStats.total + slStats.total
    totalStats.passed = totalStats.passed + slStats.passed
    totalStats.failed = totalStats.failed + slStats.failed
    allPassed = allPassed and slResult
    
    print("\n" .. string.rep("-", 60))
    print("运行物品系统测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local itemResult = T.item_async.runAll()
    local itemStats = TestHelper.getStats()
    totalStats.total = totalStats.total + itemStats.total
    totalStats.passed = totalStats.passed + itemStats.passed
    totalStats.failed = totalStats.failed + itemStats.failed
    allPassed = allPassed and itemResult
    
    print("\n" .. string.rep("-", 60))
    print("运行战斗系统测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local warResult = T.war_async.runAll()
    local warStats = TestHelper.getStats()
    totalStats.total = totalStats.total + warStats.total
    totalStats.passed = totalStats.passed + warStats.passed
    totalStats.failed = totalStats.failed + warStats.failed
    allPassed = allPassed and warResult
    
    print("\n" .. string.rep("-", 60))
    print("运行 EngineAPI 接口测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local eaResult = T.engine_api.runAll()
    local eaStats = TestHelper.getStats()
    totalStats.total = totalStats.total + eaStats.total
    totalStats.passed = totalStats.passed + eaStats.passed
    totalStats.failed = totalStats.failed + eaStats.failed
    allPassed = allPassed and eaResult
    
    print("\n" .. string.rep("-", 60))
    print("运行测试引擎测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local etResult = T.engine_test.runAll()
    local etStats = TestHelper.getStats()
    totalStats.total = totalStats.total + etStats.total
    totalStats.passed = totalStats.passed + etStats.passed
    totalStats.failed = totalStats.failed + etStats.failed
    allPassed = allPassed and etResult

    print("\n" .. string.rep("-", 60))
    print("运行 ModIni 解析器测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local miResult = runModModule("mod_ini", T.mod_ini.runAll)
    local miStats = TestHelper.getStats()
    totalStats.total = totalStats.total + miStats.total
    totalStats.passed = totalStats.passed + miStats.passed
    totalStats.failed = totalStats.failed + miStats.failed
    allPassed = allPassed and miResult
    
    print("\n" .. string.rep("-", 60))
    print("运行 ModData 数据回退测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local mdResult = runModModule("mod_data", T.mod_data.runAll)
    local mdStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mdStats.total
    totalStats.passed = totalStats.passed + mdStats.passed
    totalStats.failed = totalStats.failed + mdStats.failed
    allPassed = allPassed and mdResult
    
    print("\n" .. string.rep("-", 60))
    print("运行 MOD 编码/布局逆向测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local meResult = runModModule("mod_encoding", T.mod_encoding.runAll)
    local meStats = TestHelper.getStats()
    totalStats.total = totalStats.total + meStats.total
    totalStats.passed = totalStats.passed + meStats.passed
    totalStats.failed = totalStats.failed + meStats.failed
    allPassed = allPassed and meResult
    
    print("\n" .. string.rep("-", 60))
    print("运行 mod_build 构建期测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local buildResult = runModModule("mod_build", T.mod_build.runAll)
    local buildStats = TestHelper.getStats()
    totalStats.total = totalStats.total + buildStats.total
    totalStats.passed = totalStats.passed + buildStats.passed
    totalStats.failed = totalStats.failed + buildStats.failed
    allPassed = allPassed and buildResult

    print("\n" .. string.rep("-", 60))
    print("运行 MOD 资源分类测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local resResult = runModModule("mod_resources", T.mod_resources.runAll)
    local resStats = TestHelper.getStats()
    totalStats.total = totalStats.total + resStats.total
    totalStats.passed = totalStats.passed + resStats.passed
    totalStats.failed = totalStats.failed + resStats.failed
    allPassed = allPassed and resResult

    print("\n" .. string.rep("-", 60))
    print("运行 MOD 资源穷举审计测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local auditResult = runModModule("mod_audit", T.mod_audit.runAll)
    local auditStats = TestHelper.getStats()
    totalStats.total = totalStats.total + auditStats.total
    totalStats.passed = totalStats.passed + auditStats.passed
    totalStats.failed = totalStats.failed + auditStats.failed
    allPassed = allPassed and auditResult

    print("\n" .. string.rep("-", 60))
    print("运行格式字段级覆盖测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local fmtResult = runModModule("format_spec", T.format_spec.runAll)
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
    local bootResult = runModModule("mod_boot", T.mod_boot.runAll)
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
    local snResult = T.scene_name.runAll()
    local snStats = TestHelper.getStats()
    totalStats.total = totalStats.total + snStats.total
    totalStats.passed = totalStats.passed + snStats.passed
    totalStats.failed = totalStats.failed + snStats.failed
    allPassed = allPassed and snResult

    print("\n" .. string.rep("-", 60))
    print("运行字体大小测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local fsResult = T.font_size.runAll()
    local fsStats = TestHelper.getStats()
    totalStats.total = totalStats.total + fsStats.total
    totalStats.passed = totalStats.passed + fsStats.passed
    totalStats.failed = totalStats.failed + fsStats.failed
    allPassed = allPassed and fsResult

    print("\n" .. string.rep("-", 60))
    print("运行 newevent 事件分派测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local neResult = T.new_event.runAll()
    local neStats = TestHelper.getStats()
    totalStats.total = totalStats.total + neStats.total
    totalStats.passed = totalStats.passed + neStats.passed
    totalStats.failed = totalStats.failed + neStats.failed
    allPassed = allPassed and neResult

    print("\n" .. string.rep("-", 60))
    print("运行对话框排版测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local dlgResult = T.dialog_layout.runAll()
    local dlgStats = TestHelper.getStats()
    totalStats.total = totalStats.total + dlgStats.total
    totalStats.passed = totalStats.passed + dlgStats.passed
    totalStats.failed = totalStats.failed + dlgStats.failed
    allPassed = allPassed and dlgResult

    print("\n" .. string.rep("-", 60))
    print("运行单行文本框尺寸测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local tboxResult = T.text_box_layout.runAll()
    local tboxStats = TestHelper.getStats()
    totalStats.total = totalStats.total + tboxStats.total
    totalStats.passed = totalStats.passed + tboxStats.passed
    totalStats.failed = totalStats.failed + tboxStats.failed
    allPassed = allPassed and tboxResult

    print("\n" .. string.rep("-", 60))
    print("运行主地图 2.5D 遮挡关系测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local mmResult = T.mmap_depth.runAll()
    local mmStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mmStats.total
    totalStats.passed = totalStats.passed + mmStats.passed
    totalStats.failed = totalStats.failed + mmStats.failed
    allPassed = allPassed and mmResult

    print("\n" .. string.rep("-", 60))
    print("运行主地图飘云测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local clResult = T.cloud.runAll()
    local clStats = TestHelper.getStats()
    totalStats.total = totalStats.total + clStats.total
    totalStats.passed = totalStats.passed + clStats.passed
    totalStats.failed = totalStats.failed + clStats.failed
    allPassed = allPassed and clResult

    print("\n" .. string.rep("-", 60))
    print("运行跨版本兼容性测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local vcResult = T.version_compat.runAll()
    local vcStats = TestHelper.getStats()
    totalStats.total = totalStats.total + vcStats.total
    totalStats.passed = totalStats.passed + vcStats.passed
    totalStats.failed = totalStats.failed + vcStats.failed
    allPassed = allPassed and vcResult

    print("\n" .. string.rep("-", 60))
    print("运行设置系统测试...")
    print(string.rep("-", 60))
    TestHelper.resetCounts()
    local stResult = T.settings.runAll()
    local stStats = TestHelper.getStats()
    totalStats.total = totalStats.total + stStats.total
    totalStats.passed = totalStats.passed + stStats.passed
    totalStats.failed = totalStats.failed + stStats.failed
    allPassed = allPassed and stResult

    TestHelper.resetCounts()
    local ssResult = T.settings_store.runAll()
    local ssStats = TestHelper.getStats()
    totalStats.total = totalStats.total + ssStats.total
    totalStats.passed = totalStats.passed + ssStats.passed
    totalStats.failed = totalStats.failed + ssStats.failed
    allPassed = allPassed and ssResult

    TestHelper.resetCounts()
    local asResult = T.audio_settings.runAll()
    local asStats = TestHelper.getStats()
    totalStats.total = totalStats.total + asStats.total
    totalStats.passed = totalStats.passed + asStats.passed
    totalStats.failed = totalStats.failed + asStats.failed
    allPassed = allPassed and asResult

    TestHelper.resetCounts()
    local mvResult = T.menu_value_item.runAll()
    local mvStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mvStats.total
    totalStats.passed = totalStats.passed + mvStats.passed
    totalStats.failed = totalStats.failed + mvStats.failed
    allPassed = allPassed and mvResult

    TestHelper.resetCounts()
    local smlResult = T.start_menu_layout.runAll()
    local smlStats = TestHelper.getStats()
    totalStats.total = totalStats.total + smlStats.total
    totalStats.passed = totalStats.passed + smlStats.passed
    totalStats.failed = totalStats.failed + smlStats.failed
    allPassed = allPassed and smlResult

    TestHelper.resetCounts()
    local mesResult = T.engine_system.runAll()
    local mesStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mesStats.total
    totalStats.passed = totalStats.passed + mesStats.passed
    totalStats.failed = totalStats.failed + mesStats.failed
    allPassed = allPassed and mesResult

    TestHelper.resetCounts()
    local minResult = T.mouse_input.runAll()
    local minStats = TestHelper.getStats()
    totalStats.total = totalStats.total + minStats.total
    totalStats.passed = totalStats.passed + minStats.passed
    totalStats.failed = totalStats.failed + minStats.failed
    allPassed = allPassed and minResult

    TestHelper.resetCounts()
    local mhtResult = T.menu_hit_test.runAll()
    local mhtStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mhtStats.total
    totalStats.passed = totalStats.passed + mhtStats.passed
    totalStats.failed = totalStats.failed + mhtStats.failed
    allPassed = allPassed and mhtResult

    TestHelper.resetCounts()
    local mmnResult = T.mouse_menu.runAll()
    local mmnStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mmnStats.total
    totalStats.passed = totalStats.passed + mmnStats.passed
    totalStats.failed = totalStats.failed + mmnStats.failed
    allPassed = allPassed and mmnResult

    TestHelper.resetCounts()
    local pfResult = T.pathfind.runAll()
    local pfStats = TestHelper.getStats()
    totalStats.total = totalStats.total + pfStats.total
    totalStats.passed = totalStats.passed + pfStats.passed
    totalStats.failed = totalStats.failed + pfStats.failed
    allPassed = allPassed and pfResult

    TestHelper.resetCounts()
    local mhResult = T.mouse_hover.runAll()
    local mhStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mhStats.total
    totalStats.passed = totalStats.passed + mhStats.passed
    totalStats.failed = totalStats.failed + mhStats.failed
    allPassed = allPassed and mhResult

    TestHelper.resetCounts()
    local amResult = T.auto_move.runAll()
    local amStats = TestHelper.getStats()
    totalStats.total = totalStats.total + amStats.total
    totalStats.passed = totalStats.passed + amStats.passed
    totalStats.failed = totalStats.failed + amStats.failed
    allPassed = allPassed and amResult

    TestHelper.resetCounts()
    local itxResult = T.interact.runAll()
    local itxStats = TestHelper.getStats()
    totalStats.total = totalStats.total + itxStats.total
    totalStats.passed = totalStats.passed + itxStats.passed
    totalStats.failed = totalStats.failed + itxStats.failed
    allPassed = allPassed and itxResult

    TestHelper.resetCounts()
    local ismResult = T.item_status_mouse.runAll()
    local ismStats = TestHelper.getStats()
    totalStats.total = totalStats.total + ismStats.total
    totalStats.passed = totalStats.passed + ismStats.passed
    totalStats.failed = totalStats.failed + ismStats.failed
    allPassed = allPassed and ismResult

    TestHelper.resetCounts()
    local btmResult = T.battle_mouse.runAll()
    local btmStats = TestHelper.getStats()
    totalStats.total = totalStats.total + btmStats.total
    totalStats.passed = totalStats.passed + btmStats.passed
    totalStats.failed = totalStats.failed + btmStats.failed
    allPassed = allPassed and btmResult

    TestHelper.resetCounts()
    local bgmResult = T.base_music.runAll()
    local bgmStats = TestHelper.getStats()
    totalStats.total = totalStats.total + bgmStats.total
    totalStats.passed = totalStats.passed + bgmStats.passed
    totalStats.failed = totalStats.failed + bgmStats.failed
    allPassed = allPassed and bgmResult

    TestHelper.resetCounts()
    local iaResult = T.input_actions.runAll()
    local iaStats = TestHelper.getStats()
    totalStats.total = totalStats.total + iaStats.total
    totalStats.passed = totalStats.passed + iaStats.passed
    totalStats.failed = totalStats.failed + iaStats.failed
    allPassed = allPassed and iaResult

    TestHelper.resetCounts()
    local ibResult = T.input_bindings.runAll()
    local ibStats = TestHelper.getStats()
    totalStats.total = totalStats.total + ibStats.total
    totalStats.passed = totalStats.passed + ibStats.passed
    totalStats.failed = totalStats.failed + ibStats.failed
    allPassed = allPassed and ibResult

    TestHelper.resetCounts()
    local vpResult = T.virtual_pad.runAll()
    local vpStats = TestHelper.getStats()
    totalStats.total = totalStats.total + vpStats.total
    totalStats.passed = totalStats.passed + vpStats.passed
    totalStats.failed = totalStats.failed + vpStats.failed
    allPassed = allPassed and vpResult

    TestHelper.resetCounts()
    local vescResult = T.volume_menu_esc.runAll()
    local vescStats = TestHelper.getStats()
    totalStats.total = totalStats.total + vescStats.total
    totalStats.passed = totalStats.passed + vescStats.passed
    totalStats.failed = totalStats.failed + vescStats.failed
    allPassed = allPassed and vescResult

    TestHelper.resetCounts()
    local maResult = T.menu_align.runAll()
    local maStats = TestHelper.getStats()
    totalStats.total = totalStats.total + maStats.total
    totalStats.passed = totalStats.passed + maStats.passed
    totalStats.failed = totalStats.failed + maStats.failed
    allPassed = allPassed and maResult

    TestHelper.resetCounts()
    local sdResult = T.sprite_decoder.runAll()
    local sdStats = TestHelper.getStats()
    totalStats.total = totalStats.total + sdStats.total
    totalStats.passed = totalStats.passed + sdStats.passed
    totalStats.failed = totalStats.failed + sdStats.failed
    allPassed = allPassed and sdResult

    TestHelper.resetCounts()
    local vpwResult = T.virtual_pad_wiring.runAll()
    local vpwStats = TestHelper.getStats()
    totalStats.total = totalStats.total + vpwStats.total
    totalStats.passed = totalStats.passed + vpwStats.passed
    totalStats.failed = totalStats.failed + vpwStats.failed
    allPassed = allPassed and vpwResult

    TestHelper.resetCounts()
    local ecfResult = T.engine_conformance.runAll()
    local ecfStats = TestHelper.getStats()
    totalStats.total = totalStats.total + ecfStats.total
    totalStats.passed = totalStats.passed + ecfStats.passed
    totalStats.failed = totalStats.failed + ecfStats.failed
    allPassed = allPassed and ecfResult

    TestHelper.resetCounts()
    local sanResult = T.sprite_anim.runAll()
    local sanStats = TestHelper.getStats()
    totalStats.total = totalStats.total + sanStats.total
    totalStats.passed = totalStats.passed + sanStats.passed
    totalStats.failed = totalStats.failed + sanStats.failed
    allPassed = allPassed and sanResult

    TestHelper.resetCounts()
    local brResult = T.battle_rules.runAll()
    local brStats = TestHelper.getStats()
    totalStats.total = totalStats.total + brStats.total
    totalStats.passed = totalStats.passed + brStats.passed
    totalStats.failed = totalStats.failed + brStats.failed
    allPassed = allPassed and brResult

    TestHelper.resetCounts()
    local bwResult = T.battle_wiring.runAll()
    local bwStats = TestHelper.getStats()
    totalStats.total = totalStats.total + bwStats.total
    totalStats.passed = totalStats.passed + bwStats.passed
    totalStats.failed = totalStats.failed + bwStats.failed
    allPassed = allPassed and bwResult

    TestHelper.resetCounts()
    local bhResult = T.battle_flow_headless.runAll()
    local bhStats = TestHelper.getStats()
    totalStats.total = totalStats.total + bhStats.total
    totalStats.passed = totalStats.passed + bhStats.passed
    totalStats.failed = totalStats.failed + bhStats.failed
    allPassed = allPassed and bhResult

    TestHelper.resetCounts()
    local wcwResult = T.war_coroutine_wiring.runAll()
    local wcwStats = TestHelper.getStats()
    totalStats.total = totalStats.total + wcwStats.total
    totalStats.passed = totalStats.passed + wcwStats.passed
    totalStats.failed = totalStats.failed + wcwStats.failed
    allPassed = allPassed and wcwResult

    TestHelper.resetCounts()
    local rbResult = T.robustness.runAll()
    local rbStats = TestHelper.getStats()
    totalStats.total = totalStats.total + rbStats.total
    totalStats.passed = totalStats.passed + rbStats.passed
    totalStats.failed = totalStats.failed + rbStats.failed
    allPassed = allPassed and rbResult

    TestHelper.resetCounts()
    local sapResult = T.sprite_atlas_png.runAll()
    local sapStats = TestHelper.getStats()
    totalStats.total = totalStats.total + sapStats.total
    totalStats.passed = totalStats.passed + sapStats.passed
    totalStats.failed = totalStats.failed + sapStats.failed
    allPassed = allPassed and sapResult

    TestHelper.resetCounts()
    local cpcResult = T.cal_pic_clip.runAll()
    local cpcStats = TestHelper.getStats()
    totalStats.total = totalStats.total + cpcStats.total
    totalStats.passed = totalStats.passed + cpcStats.passed
    totalStats.failed = totalStats.failed + cpcStats.failed
    allPassed = allPassed and cpcResult

    TestHelper.resetCounts()
    local brbResult = T.battle_robustness.runAll()
    local brbStats = TestHelper.getStats()
    totalStats.total = totalStats.total + brbStats.total
    totalStats.passed = totalStats.passed + brbStats.passed
    totalStats.failed = totalStats.failed + brbStats.failed
    allPassed = allPassed and brbResult

    TestHelper.resetCounts()
    local wftResult = T.wait_for_time.runAll()
    local wftStats = TestHelper.getStats()
    totalStats.total = totalStats.total + wftStats.total
    totalStats.passed = totalStats.passed + wftStats.passed
    totalStats.failed = totalStats.failed + wftStats.failed
    allPassed = allPassed and wftResult

    TestHelper.resetCounts()
    local wfResult = T.wait_frame.runAll()
    local wfStats = TestHelper.getStats()
    totalStats.total = totalStats.total + wfStats.total
    totalStats.passed = totalStats.passed + wfStats.passed
    totalStats.failed = totalStats.failed + wfStats.failed
    allPassed = allPassed and wfResult

    TestHelper.resetCounts()
    local adwResult = T.archive_dual_write.runAll()
    local adwStats = TestHelper.getStats()
    totalStats.total = totalStats.total + adwStats.total
    totalStats.passed = totalStats.passed + adwStats.passed
    totalStats.failed = totalStats.failed + adwStats.failed
    allPassed = allPassed and adwResult

    TestHelper.resetCounts()
    local mrnResult = T.map_render.runAll()
    local mrnStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mrnStats.total
    totalStats.passed = totalStats.passed + mrnStats.passed
    totalStats.failed = totalStats.failed + mrnStats.failed
    allPassed = allPassed and mrnResult

    TestHelper.resetCounts()
    local mrmResult = T.map_render_missing.runAll()
    local mrmStats = TestHelper.getStats()
    totalStats.total = totalStats.total + mrmStats.total
    totalStats.passed = totalStats.passed + mrmStats.passed
    totalStats.failed = totalStats.failed + mrmStats.failed
    allPassed = allPassed and mrmResult

    TestHelper.resetCounts()
    local audResult = T.audio_semantics.runAll()
    local audStats = TestHelper.getStats()
    totalStats.total = totalStats.total + audStats.total
    totalStats.passed = totalStats.passed + audStats.passed
    totalStats.failed = totalStats.failed + audStats.failed
    allPassed = allPassed and audResult

    -- framework-io-portability：主路径零 stdlib IO/时间（EngineAPI 优先）
    TestHelper.resetCounts()
    local eipResult = T.engine_io_portability.runAll()
    local eipStats = TestHelper.getStats()
    totalStats.total = totalStats.total + eipStats.total
    totalStats.passed = totalStats.passed + eipStats.passed
    totalStats.failed = totalStats.failed + eipStats.failed
    allPassed = allPassed and eipResult

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
    
    -- **表查分发**（原是 54 个 elseif 链）：
    --
    -- 为什么改：Lua 5.1 的函数最多 60 个 upvalue，而 runAll + 这个分发表
    -- 一起引用 57 个模块 → 加第 58 个测试时就撞 "more than 60 upvalues"。
    -- 收进 T 表后，两处都只捕获 T 这一个 upvalue，新增测试不再触发上限。
    --
    -- 语义不变：T[key] 存在就调它的 runAll()，不存在就落到下面的"未知模块"。
    local fn = T[moduleName]
    if fn and type(fn.runAll) == "function" then
        return fn.runAll()
    else
        print("未知测试模块: " .. tostring(moduleName))
        print("可用模块: state_machine, input_manager, event_bridge, coroutine_scheduler, byte_io, script_loader, item_async, war_async, engine_api, engine_test, mod_ini, mod_data, mod_encoding, mod_build, mod_resources, mod_audit, format_spec, mod_e2e, mod_boot, dialog_layout, text_box_layout, mmap_depth, cloud, version_compat, settings, settings_store, audio_settings, menu_value_item, start_menu_layout, engine_system, mouse_input, menu_hit_test, mouse_menu, pathfind, mouse_hover, auto_move, interact, item_status_mouse, battle_mouse, base_music, input_actions, input_bindings, virtual_pad, volume_menu_esc, menu_align, sprite_decoder, virtual_pad_wiring, engine_conformance, sprite_anim, battle_rules, battle_wiring, battle_flow_headless, war_coroutine_wiring, robustness, sprite_atlas_png, cal_pic_clip, battle_robustness, wait_for_time, wait_frame, archive_dual_write, map_render, map_render_missing, audio_semantics, engine_io_portability")
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
