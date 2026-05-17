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

    local calls = {}
    _G.love = {
        filesystem = {
            load = function(path)
                table.insert(calls, path)
                if path == "game/script/oldevent/oldevent_691.lua" then
                    return function() return true end
                end
                return nil, "not found"
            end
        }
    }

    local oldLoadfile = _G.loadfile
    _G.loadfile = function() return nil, "native disabled in test" end

    local ScriptLoader = require("framework.script_loader")
    local chunk = ScriptLoader.load("script/oldevent/oldevent_691.lua")

    _G.loadfile = oldLoadfile

    TestHelper.assertNotNil(chunk, "Chunk should be loaded from fallback game/ path")
    TestHelper.assertEquals("script/oldevent/oldevent_691.lua", calls[1], "Should try original path first")
    TestHelper.assertEquals("game/script/oldevent/oldevent_691.lua", calls[2], "Should try game/ prefixed path second")
end

function TestScriptLoader.runAll()
    print("\n========================================")
    print("Script Loader Unit Tests")
    print("========================================")

    TestHelper.resetCounts()
    TestScriptLoader.testFallbackToGamePrefixedPath()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_script_loader.lua$") then
    TestScriptLoader.runAll()
end

return TestScriptLoader
