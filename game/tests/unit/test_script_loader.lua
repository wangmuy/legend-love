-- test_script_loader.lua
-- ScriptLoader 单元测试

local TestHelper = require("tests.test_helper")
local TestScriptLoader = {}

-- 保存真实 loadfile：本套件会替换全局 loadfile 来观察探测顺序，
-- 必须在每个用例后还原。早期版本没有还原，导致后续套件（test_new_event）
-- 的所有文件加载都走这个 mock 并返回 "not found" —— 全量跑时被
-- test_mod_boot 里偶然的 restoreLoadfile() 掩盖，单跑 MOD 组被跳过时才暴露。
local realLoadfile = _G.loadfile
local function restoreLoadfile()
    _G.loadfile = realLoadfile
end

local function setup()
    TestHelper.setup()
    TestHelper.mockGlobals()
    package.loaded["script_loader"] = nil
    restoreLoadfile()
end

local function teardown()
    restoreLoadfile()
    _G.EngineAPI = nil
end

function TestScriptLoader.testFallbackToGamePrefixedPath()
    setup()
    print("\n=== Test: ScriptLoader Fallback Path ===")

    local loadfileCalls = {}
    _G.EngineAPI = nil
    _G.loadfile = function(path)
        table.insert(loadfileCalls, path)
        if path == "script/oldevent/oldevent_691.lua" then
            return nil, "not found"
        end
        if path == "game/script/oldevent/oldevent_691.lua" then
            return function() return true end
        end
        return nil, "not found"
    end

    local ScriptLoader = require("framework.script_loader")
    local chunk = ScriptLoader.load("script/oldevent/oldevent_691.lua")

    TestHelper.assertNotNil(chunk, "Chunk should be loaded from fallback game/ path")
    TestHelper.assertEquals("script/oldevent/oldevent_691.lua", loadfileCalls[1], "Should try original path first")
    TestHelper.assertEquals("game/script/oldevent/oldevent_691.lua", loadfileCalls[2], "Should try game/ prefixed path second")
    teardown()
end

function TestScriptLoader.testEngineAPIPath()
    setup()
    print("\n=== Test: ScriptLoader EngineAPI Path ===")

    local engineCalled = false
    _G.EngineAPI = {
        script = {
            load = function(path)
                engineCalled = true
                TestHelper.assertEquals("script/oldevent/oldevent_691.lua", path, "EngineAPI path should match")
                return function() return true end
            end
        }
    }

    local ScriptLoader = require("framework.script_loader")
    local chunk = ScriptLoader.load("script/oldevent/oldevent_691.lua")

    TestHelper.assertEquals(true, engineCalled, "EngineAPI.script.load should be called")
    TestHelper.assertNotNil(chunk, "Chunk should be loaded via EngineAPI")
    teardown()
end

function TestScriptLoader.testLeavesLoadfileIntact()
    setup()
    print("\n=== Test: 不残留 loadfile mock（跨套件隔离）===")
    -- 先跑一次会替换 loadfile 的用例，再断言全局已还原
    TestScriptLoader.testFallbackToGamePrefixedPath()
    TestHelper.assertTrue(_G.loadfile == realLoadfile,
        "用例结束后 _G.loadfile 必须还原（否则后续套件加载脚本全失败）")
    teardown()
end

function TestScriptLoader.runAll()
    print("\n========================================")
    print("Script Loader Unit Tests")
    print("========================================")

    TestHelper.resetCounts()
    TestScriptLoader.testEngineAPIPath()
    TestScriptLoader.testFallbackToGamePrefixedPath()
    TestScriptLoader.testLeavesLoadfileIntact()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_script_loader.lua$") then
    TestScriptLoader.runAll()
end

return TestScriptLoader