-- test_event_bridge.lua
-- 事件桥接模块单元测试

local EventBridge = require("event_bridge")

local TestEventBridge = {}

-- 测试计数
local testCount = 0
local passCount = 0
local failCount = 0

-- 断言函数
local function assertEquals(expected, actual, message)
    testCount = testCount + 1
    if expected == actual then
        passCount = passCount + 1
        print(string.format("[PASS] %s", message or "Test"))
        return true
    else
        failCount = failCount + 1
        print(string.format("[FAIL] %s: expected %s, got %s", 
            message or "Test", tostring(expected), tostring(actual)))
        return false
    end
end

-- 测试前重置
local function setup()
    if EventBridge then
        EventBridge.getInstance():reset()
    end
end

-- 测试1: 单例模式
function TestEventBridge.testSingleton()
    setup()
    print("\n=== Test: Singleton Pattern ===")
    
    local eb1 = EventBridge.getInstance()
    local eb2 = EventBridge.getInstance()
    
    assertEquals(true, eb1 == eb2, "Should return same instance")
end

-- 测试2: 状态注册
function TestEventBridge.testStateRegistration()
    setup()
    print("\n=== Test: State Registration ===")
    
    local eb = EventBridge.getInstance()
    eb:init()
    
    local enterCalled = false
    local exitCalled = false
    local updateCalled = false
    local drawCalled = false
    
    -- 注册测试状态
    eb:registerState("TEST_STATE", {
        enter = function() enterCalled = true end,
        exit = function() exitCalled = true end,
        update = function() updateCalled = true end,
        draw = function() drawCalled = true end
    })
    
    local handlers = eb:getStateHandlers()
    assertEquals(true, handlers["TEST_STATE"] ~= nil, "State should be registered")
    
    -- 切换状态触发enter
    eb:switchState("TEST_STATE")
    assertEquals(true, enterCalled, "Enter should be called")
    assertEquals("TEST_STATE", eb:getCurrentState(), "Current state should be TEST_STATE")
end

-- 测试3: 状态切换
function TestEventBridge.testStateSwitch()
    setup()
    print("\n=== Test: State Switching ===")
    
    local eb = EventBridge.getInstance()
    eb:init()
    
    local stateAExit = false
    local stateBEnter = false
    
    eb:registerState("STATE_A", {
        enter = function() end,
        exit = function() stateAExit = true end,
        update = function() end,
        draw = function() end
    })
    
    eb:registerState("STATE_B", {
        enter = function() stateBEnter = true end,
        exit = function() end,
        update = function() end,
        draw = function() end
    })
    
    eb:switchState("STATE_A")
    eb:switchState("STATE_B")
    
    assertEquals(true, stateAExit, "Previous state exit should be called")
    assertEquals(true, stateBEnter, "New state enter should be called")
    assertEquals("STATE_B", eb:getCurrentState(), "Current state should be STATE_B")
end

-- 测试4: 输入管理器集成
function TestEventBridge.testInputManager()
    setup()
    print("\n=== Test: Input Manager Integration ===")
    
    local eb = EventBridge.getInstance()
    eb:init()
    
    local im = eb:getInputManager()
    assertEquals(true, im ~= nil, "Should have input manager")
    
    -- 测试getKey API
    local key = eb:getKey()
    assertEquals(-1, key, "Initial key should be -1")
    
    -- 测试EnableKeyRepeat API
    eb:enableKeyRepeat(500, 100)
    assertEquals(true, im:isKeyRepeatEnabled(), "Key repeat should be enabled")
    
    eb:enableKeyRepeat(0, 0)
    assertEquals(false, im:isKeyRepeatEnabled(), "Key repeat should be disabled")
end

-- 测试5: 状态机集成
function TestEventBridge.testStateMachine()
    setup()
    print("\n=== Test: State Machine Integration ===")
    
    local eb = EventBridge.getInstance()
    eb:init()
    
    local sm = eb:getStateMachine()
    assertEquals(true, sm ~= nil, "Should have state machine")
    
    -- 注册并切换状态
    eb:registerState("SM_TEST", {
        enter = function() end,
        exit = function() end,
        update = function() end,
        draw = function() end
    })
    
    eb:switchState("SM_TEST")
    assertEquals("SM_TEST", sm:getCurrentState(), "State machine should have correct state")
end

-- 测试6: 向后兼容API
function TestEventBridge.testBackwardCompatibility()
    setup()
    print("\n=== Test: Backward Compatibility ===")
    
    local eb = EventBridge.getInstance()
    eb:init()
    
    -- 测试isKeyDown
    local im = eb:getInputManager()
    im:onKeyPressed("escape", nil, false)
    
    assertEquals(true, eb:isKeyDown(VK_ESCAPE), "isKeyDown should work")
end

-- 测试7: update和draw调用
function TestEventBridge.testUpdateDraw()
    setup()
    print("\n=== Test: Update and Draw ===")
    
    local eb = EventBridge.getInstance()
    eb:init()
    
    local updateCalled = false
    local drawCalled = false
    
    eb:registerState("UPDATE_DRAW_TEST", {
        enter = function() end,
        exit = function() end,
        update = function(dt) updateCalled = true end,
        draw = function() drawCalled = true end
    })
    
    eb:switchState("UPDATE_DRAW_TEST")
    
    -- 调用update
    eb:update(0.016)
    assertEquals(true, updateCalled, "Update should be called")
    
    -- 调用draw
    eb:draw()
    assertEquals(true, drawCalled, "Draw should be called")
end

-- 测试8: 重置功能
function TestEventBridge.testReset()
    setup()
    print("\n=== Test: Reset ===")
    
    local eb = EventBridge.getInstance()
    eb:init()
    
    eb:registerState("RESET_TEST", {
        enter = function() end,
        exit = function() end,
        update = function() end,
        draw = function() end
    })
    
    eb:switchState("RESET_TEST")
    assertEquals("RESET_TEST", eb:getCurrentState(), "Should have state")
    
    -- 重置
    eb:reset()
    
    -- 获取新实例
    local eb2 = EventBridge.getInstance()
    assertEquals(true, eb ~= eb2, "Should be new instance after reset")
end

-- 运行所有测试
function TestEventBridge.runAll()
    print("\n========================================")
    print("Event Bridge Unit Tests")
    print("========================================")
    
    testCount = 0
    passCount = 0
    failCount = 0
    
    TestEventBridge.testSingleton()
    TestEventBridge.testStateRegistration()
    TestEventBridge.testStateSwitch()
    TestEventBridge.testInputManager()
    TestEventBridge.testStateMachine()
    TestEventBridge.testBackwardCompatibility()
    TestEventBridge.testUpdateDraw()
    TestEventBridge.testReset()
    
    print("\n========================================")
    print(string.format("Results: %d tests, %d passed, %d failed", 
        testCount, passCount, failCount))
    print("========================================")
    
    return failCount == 0
end

-- 如果直接运行此文件
if arg and arg[0]:match("test_event_bridge.lua$") then
    TestEventBridge.runAll()
end

return TestEventBridge
