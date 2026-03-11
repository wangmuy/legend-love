-- test_input_manager.lua
-- 输入管理器模块单元测试

local InputManager = require("input_manager")

local TestInputManager = {}

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
    InputManager.getInstance():reset()
    InputManager.getInstance():init()
end

-- 测试1: 初始化
function TestInputManager.testInit()
    setup()
    print("\n=== Test: Initialization ===")
    
    local im = InputManager.getInstance()
    
    assertEquals(-1, im:getKey(), "Initial key should be -1")
    assertEquals(false, im:isKeyDown(VK_ESCAPE), "Initial key state should be false")
    assertEquals(false, im:isKeyRepeatEnabled(), "Key repeat should be disabled by default")
end

-- 测试2: 按键按下事件
function TestInputManager.testKeyPressed()
    setup()
    print("\n=== Test: Key Pressed Event ===")
    
    local im = InputManager.getInstance()
    
    -- 模拟按下escape键
    im:onKeyPressed("escape", nil, false)
    
    assertEquals(true, im:isKeyDown(VK_ESCAPE), "Escape should be down after press")
    assertEquals(VK_ESCAPE, im:getKey(), "getKey should return VK_ESCAPE")
    
    -- 再次调用getKey应该返回-1(已重置)
    assertEquals(-1, im:getKey(), "getKey should return -1 after read")
end

-- 测试3: 按键释放事件
function TestInputManager.testKeyReleased()
    setup()
    print("\n=== Test: Key Released Event ===")
    
    local im = InputManager.getInstance()
    
    -- 按下然后释放
    im:onKeyPressed("space", nil, false)
    assertEquals(true, im:isKeyDown(VK_SPACE), "Space should be down")
    
    im:onKeyReleased("space", nil)
    assertEquals(false, im:isKeyDown(VK_SPACE), "Space should be up after release")
end

-- 测试4: 事件队列
function TestInputManager.testEventQueue()
    setup()
    print("\n=== Test: Event Queue ===")
    
    local im = InputManager.getInstance()
    
    -- 模拟多个按键
    im:onKeyPressed("up", nil, false)
    im:onKeyPressed("down", nil, false)
    im:onKeyReleased("up", nil)
    
    local events = im:pollEvents()
    assertEquals(3, #events, "Should have 3 events in queue")
    
    assertEquals("pressed", events[1].type, "First event should be pressed")
    assertEquals(VK_UP, events[1].key, "First event key should be VK_UP")
    
    assertEquals("pressed", events[2].type, "Second event should be pressed")
    assertEquals(VK_DOWN, events[2].key, "Second event key should be VK_DOWN")
    
    assertEquals("released", events[3].type, "Third event should be released")
    
    -- 队列应该已清空
    local events2 = im:pollEvents()
    assertEquals(0, #events2, "Queue should be empty after poll")
end

-- 测试5: 按键重复
function TestInputManager.testKeyRepeat()
    setup()
    print("\n=== Test: Key Repeat ===")
    
    local im = InputManager.getInstance()
    
    assertEquals(false, im:isKeyRepeatEnabled(), "Key repeat should be disabled initially")
    
    im:setKeyRepeat(true)
    assertEquals(true, im:isKeyRepeatEnabled(), "Key repeat should be enabled")
    
    im:setKeyRepeat(false)
    assertEquals(false, im:isKeyRepeatEnabled(), "Key repeat should be disabled")
end

-- 测试6: 按键映射
function TestInputManager.testKeyMapping()
    setup()
    print("\n=== Test: Key Mapping ===")
    
    local im = InputManager.getInstance()
    local keyMap = im:getKeyMap()
    
    -- 验证默认映射
    assertEquals(VK_ESCAPE, keyMap["escape"], "escape should map to VK_ESCAPE")
    assertEquals(VK_SPACE, keyMap[" "], "space should map to VK_SPACE")
    assertEquals(VK_RETURN, keyMap["return"], "return should map to VK_RETURN")
    assertEquals(VK_UP, keyMap["up"], "up should map to VK_UP")
    assertEquals(VK_DOWN, keyMap["down"], "down should map to VK_DOWN")
    assertEquals(VK_LEFT, keyMap["left"], "left should map to VK_LEFT")
    assertEquals(VK_RIGHT, keyMap["right"], "right should map to VK_RIGHT")
end

-- 测试7: 自定义按键映射
function TestInputManager.testCustomKeyMapping()
    setup()
    print("\n=== Test: Custom Key Mapping ===")
    
    local im = InputManager.getInstance()
    
    -- 注册自定义映射
    im:registerKey("a", 100)
    im:registerKey("b", 101)
    
    im:onKeyPressed("a", nil, false)
    assertEquals(100, im:getKey(), "Custom key 'a' should map to 100")
    
    im:onKeyPressed("b", nil, false)
    assertEquals(101, im:getKey(), "Custom key 'b' should map to 101")
end

-- 测试8: 清空状态
function TestInputManager.testClear()
    setup()
    print("\n=== Test: Clear ===")
    
    local im = InputManager.getInstance()
    
    -- 添加一些事件和状态
    im:onKeyPressed("escape", nil, false)
    im:onKeyPressed("space", nil, false)
    
    assertEquals(true, im:isKeyDown(VK_ESCAPE), "Escape should be down")
    
    -- 清空
    im:clear()
    
    assertEquals(-1, im:getKey(), "Key should be -1 after clear")
    assertEquals(false, im:isKeyDown(VK_ESCAPE), "Key state should be false after clear")
    
    local events = im:pollEvents()
    assertEquals(0, #events, "Event queue should be empty after clear")
end

-- 运行所有测试
function TestInputManager.runAll()
    print("\n========================================")
    print("Input Manager Unit Tests")
    print("========================================")
    
    testCount = 0
    passCount = 0
    failCount = 0
    
    TestInputManager.testInit()
    TestInputManager.testKeyPressed()
    TestInputManager.testKeyReleased()
    TestInputManager.testEventQueue()
    TestInputManager.testKeyRepeat()
    TestInputManager.testKeyMapping()
    TestInputManager.testCustomKeyMapping()
    TestInputManager.testClear()
    
    print("\n========================================")
    print(string.format("Results: %d tests, %d passed, %d failed", 
        testCount, passCount, failCount))
    print("========================================")
    
    return failCount == 0
end

-- 如果直接运行此文件
if arg and arg[0]:match("test_input_manager.lua$") then
    TestInputManager.runAll()
end

return TestInputManager
