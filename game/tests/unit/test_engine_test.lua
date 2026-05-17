-- test_engine_test.lua
-- 测试引擎单元测试

local TestHelper = require("tests.test_helper")

local TestEngineTest = {}

local function setup()
    TestHelper.setup()
end

function TestEngineTest.testRenderNoOps()
    setup()
    print("\n=== Test: Engine test render no-ops ===")
    
    local EngineAPI = require("engine_test")
    EngineAPI._clearLog()
    EngineAPI._logEnabled = true
    
    EngineAPI.render.text(100, 100, "test", {1,1,1}, 20)
    EngineAPI.render.fillRect(0, 0, 100, 100, {1,0,0})
    EngineAPI.render.present()
    
    TestHelper.assertEquals(3, #EngineAPI._callLog, "Should have 3 log entries")
    TestHelper.assertEquals("render.text", EngineAPI._callLog[1].func, "First call should be render.text")
    TestHelper.assertEquals("render.fillRect", EngineAPI._callLog[2].func, "Second call should be render.fillRect")
    TestHelper.assertEquals("render.present", EngineAPI._callLog[3].func, "Third call should be render.present")
    
    EngineAPI._logEnabled = false
end

function TestEngineTest.testInputKeyQueue()
    setup()
    print("\n=== Test: Engine test input key queue ===")
    
    local EngineAPI = require("engine_test")
    EngineAPI._setKeyQueue({27, 32, 13})
    
    local key1 = EngineAPI.input.waitForKey()
    TestHelper.assertEquals(27, key1, "First key should be ESC (27)")
    
    local key2 = EngineAPI.input.waitForKey()
    TestHelper.assertEquals(32, key2, "Second key should be SPACE (32)")
    
    local key3 = EngineAPI.input.waitForKey()
    TestHelper.assertEquals(13, key3, "Third key should be RETURN (13)")
    
    -- 空队列返回 -1
    local key4 = EngineAPI.input.waitForKey()
    TestHelper.assertEquals(-1, key4, "Empty queue should return -1")
end

function TestEngineTest.testTimeNoWait()
    setup()
    print("\n=== Test: Engine test time no-wait ===")
    
    local EngineAPI = require("engine_test")
    
    local start = EngineAPI.time.getTime()
    EngineAPI.time.sleep(1000)  -- 应该立即返回
    local elapsed = EngineAPI.time.getTime() - start
    
    TestHelper.assertEquals(true, elapsed < 100, "sleep(1000) should return immediately (elapsed < 100ms)")
end

function TestEngineTest.testFileOperations()
    setup()
    print("\n=== Test: Engine test file operations ===")
    
    local EngineAPI = require("engine_test")
    
    -- 测试文件存在
    local exists = EngineAPI.file.exists("script/jyconst.lua")
    TestHelper.assertEquals(true, exists, "script/jyconst.lua should exist")
    
    -- 测试文件不存在
    local notExists = EngineAPI.file.exists("nonexistent_file.lua")
    TestHelper.assertEquals(false, notExists, "nonexistent file should not exist")
end

function TestEngineTest.testColorModule()
    setup()
    print("\n=== Test: Engine test color module ===")
    
    local EngineAPI = require("engine_test")
    
    local packed = EngineAPI.color.pack(236, 236, 236)
    local r, g, b = EngineAPI.color.unpack(packed)
    
    TestHelper.assertEquals(236 * 65536 + 236 * 256 + 236, packed, "pack should match expected value")
    TestHelper.assertEquals(true, math.abs(r - 0.925) < 0.01, "unpack r should be ~0.925")
    TestHelper.assertEquals(true, math.abs(g - 0.925) < 0.01, "unpack g should be ~0.925")
    TestHelper.assertEquals(true, math.abs(b - 0.925) < 0.01, "unpack b should be ~0.925")
end

function TestEngineTest.testCoroutineModule()
    setup()
    print("\n=== Test: Engine test coroutine module ===")
    
    local EngineAPI = require("engine_test")
    
    -- 在协程中测试
    local co = coroutine.create(function()
        local running = EngineAPI.coroutine.isRunning()
        TestHelper.assertEquals(true, running, "isRunning should be true inside coroutine")
    end)
    coroutine.resume(co)
end

function TestEngineTest.runAll()
    print("\n========================================")
    print("Engine Test Engine Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    TestEngineTest.testRenderNoOps()
    TestEngineTest.testInputKeyQueue()
    TestEngineTest.testTimeNoWait()
    TestEngineTest.testFileOperations()
    TestEngineTest.testColorModule()
    TestEngineTest.testCoroutineModule()
    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_engine_test.lua$") then
    TestEngineTest.runAll()
end

return TestEngineTest