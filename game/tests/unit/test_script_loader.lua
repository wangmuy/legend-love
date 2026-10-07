-- test_script_loader.lua
-- ScriptLoader 单元测试

local TestHelper = require("tests.test_helper")
local TestScriptLoader = {}

local function setup()
    TestHelper.setup()
    TestHelper.mockGlobals()
    package.loaded["script_loader"] = nil
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
end

function TestScriptLoader.runAll()
    print("\n========================================")
    print("Script Loader Unit Tests")
    print("========================================")

    TestHelper.resetCounts()
    TestScriptLoader.testEngineAPIPath()
    TestScriptLoader.testFallbackToGamePrefixedPath()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_script_loader.lua$") then
    TestScriptLoader.runAll()
end

return TestScriptLoader