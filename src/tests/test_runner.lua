-- test_runner.lua
-- 测试运行器 - 运行所有单元测试

local TestHelper = require("tests.test_helper")
local TestStateMachine = require("tests.unit.test_state_machine")
local TestInputManager = require("tests.unit.test_input_manager")
local TestEventBridge = require("tests.unit.test_event_bridge")

local TestRunner = {}

-- 运行所有测试
function TestRunner.runAll()
    print("\n" .. string.rep("=", 60))
    print("金庸群侠传 Love2D 重构 - 单元测试套件")
    print(string.rep("=", 60))
    
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
    
    -- 最终结果
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
    
    if moduleName == "state_machine" then
        return TestStateMachine.runAll()
    elseif moduleName == "input_manager" then
        return TestInputManager.runAll()
    elseif moduleName == "event_bridge" then
        return TestEventBridge.runAll()
    else
        print("未知测试模块: " .. tostring(moduleName))
        print("可用模块: state_machine, input_manager, event_bridge")
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
