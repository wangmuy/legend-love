-- test_state_machine.lua
-- 状态机模块单元测试

local TestHelper = require("tests.test_helper")
local StateMachine = require("state_machine")

local TestStateMachine = {}

-- 测试前重置
local function setup()
    TestHelper.setup()
    StateMachine.getInstance():reset()
end

-- 测试1: 状态注册
function TestStateMachine.testRegister()
    setup()
    print("\n=== Test: State Registration ===")
    
    local sm = StateMachine.getInstance()
    
    -- 注册测试状态
    sm:register("TEST_STATE", {
        update = function() end,
        draw = function() end,
        enter = function() end,
        exit = function() end
    })
    
    TestHelper.assertEquals(true, sm:isRegistered("TEST_STATE"), "State should be registered")
    TestHelper.assertEquals(false, sm:isRegistered("NON_EXISTENT"), "Non-existent state should not be registered")
    
    local states = sm:getRegisteredStates()
    TestHelper.assertEquals(1, #states, "Should have 1 registered state")
end

-- 测试2: 状态切换
function TestStateMachine.testStateSwitch()
    setup()
    print("\n=== Test: State Switching ===")
    
    local sm = StateMachine.getInstance()
    local enterCalled = false
    local exitCalled = false
    
    -- 注册状态A
    sm:register("STATE_A", {
        enter = function() enterCalled = true end,
        exit = function() exitCalled = true end,
        update = function() end,
        draw = function() end
    })
    
    -- 注册状态B
    sm:register("STATE_B", {
        enter = function() end,
        exit = function() end,
        update = function() end,
        draw = function() end
    })
    
    -- 切换到状态A
    sm:switchTo("STATE_A")
    TestHelper.assertEquals("STATE_A", sm:getCurrentState(), "Current state should be STATE_A")
    TestHelper.assertEquals(true, enterCalled, "Enter callback should be called")
    
    -- 切换到状态B
    enterCalled = false
    sm:switchTo("STATE_B")
    TestHelper.assertEquals("STATE_B", sm:getCurrentState(), "Current state should be STATE_B")
    TestHelper.assertEquals(true, exitCalled, "Exit callback of previous state should be called")
    TestHelper.assertEquals("STATE_A", sm:getPreviousState(), "Previous state should be STATE_A")
end

-- 测试3: update和draw调用
function TestStateMachine.testUpdateDraw()
    setup()
    print("\n=== Test: Update and Draw ===")
    
    local sm = StateMachine.getInstance()
    local updateCalled = false
    local drawCalled = false
    local updateDt = nil
    
    sm:register("TEST_STATE", {
        update = function(dt) 
            updateCalled = true
            updateDt = dt
        end,
        draw = function() 
            drawCalled = true
        end,
        enter = function() end,
        exit = function() end
    })
    
    sm:switchTo("TEST_STATE")
    
    -- 调用update
    sm:update(0.016)
    TestHelper.assertEquals(true, updateCalled, "Update should be called")
    TestHelper.assertEquals(0.016, updateDt, "Update should receive correct dt")
    
    -- 调用draw
    sm:draw()
    TestHelper.assertEquals(true, drawCalled, "Draw should be called")
end

-- 测试4: 未注册状态切换
function TestStateMachine.testUnregisteredState()
    setup()
    print("\n=== Test: Unregistered State ===")
    
    local sm = StateMachine.getInstance()
    local errorCaught = false
    
    -- 尝试切换到未注册的状态
    local status, err = pcall(function()
        sm:switchTo("UNREGISTERED")
    end)
    
    TestHelper.assertEquals(false, status, "Should throw error for unregistered state")
end

-- 测试5: 多状态管理
function TestStateMachine.testMultipleStates()
    setup()
    print("\n=== Test: Multiple States ===")
    
    local sm = StateMachine.getInstance()
    
    -- 注册多个状态
    for i = 1, 5 do
        sm:register("STATE_" .. i, {
            update = function() end,
            draw = function() end,
            enter = function() end,
            exit = function() end
        })
    end
    
    local states = sm:getRegisteredStates()
    TestHelper.assertEquals(5, #states, "Should have 5 registered states")
    
    -- 验证所有状态都已注册
    for i = 1, 5 do
        TestHelper.assertEquals(true, sm:isRegistered("STATE_" .. i), "STATE_" .. i .. " should be registered")
    end
end

-- 运行所有测试
function TestStateMachine.runAll()
    print("\n========================================")
    print("State Machine Unit Tests")
    print("========================================")
    
    testCount = 0
    passCount = 0
    failCount = 0
    
    TestStateMachine.testRegister()
    TestStateMachine.testStateSwitch()
    TestStateMachine.testUpdateDraw()
    TestStateMachine.testUnregisteredState()
    TestStateMachine.testMultipleStates()
    
    return TestHelper.printSummary()
end

-- 如果直接运行此文件
if arg and arg[0]:match("test_state_machine.lua$") then
    TestStateMachine.runAll()
end

return TestStateMachine
