-- test_input_manager.lua
-- 输入管理器模块单元测试

local TestHelper = require("tests.test_helper")
local InputManager = require("input_manager")

local TestInputManager = {}

-- 定义按键常量（用于测试）
local VK_ESCAPE = 27
local VK_SPACE = 32
local VK_RETURN = 13
local VK_UP = 1073741906
local VK_DOWN = 1073741905
local VK_LEFT = 1073741904
local VK_RIGHT = 1073741903

-- 测试前重置
local function setup()
    TestHelper.setup()
    InputManager.getInstance():reset()
    InputManager.getInstance():init()
end

-- 测试1: 初始化
function TestInputManager.testInit()
    setup()
    print("\n=== Test: Initialization ===")
    
    local im = InputManager.getInstance()
    
    TestHelper.assertEquals(-1, im:getKey(), "Initial key should be -1")
    TestHelper.assertEquals(false, im:isKeyDown(VK_ESCAPE), "Initial key state should be false")
    TestHelper.assertEquals(false, im:isKeyRepeatEnabled(), "Key repeat should be disabled by default")
end

-- 测试2: 按键按下事件
function TestInputManager.testKeyPressed()
    setup()
    print("\n=== Test: Key Pressed Event ===")
    
    local im = InputManager.getInstance()
    
    -- 模拟按下escape键
    im:onKeyPressed("escape", nil, false)
    
    TestHelper.assertEquals(true, im:isKeyDown(VK_ESCAPE), "Escape should be down after press")
    TestHelper.assertEquals(VK_ESCAPE, im:getKey(), "getKey should return VK_ESCAPE")
    
    -- 再次调用getKey应该返回-1(已重置)
    TestHelper.assertEquals(-1, im:getKey(), "getKey should return -1 after read")
end

-- 测试3: 按键释放事件
function TestInputManager.testKeyReleased()
    setup()
    print("\n=== Test: Key Released Event ===")
    
    local im = InputManager.getInstance()
    
    -- 按下然后释放
    im:onKeyPressed("space", nil, false)
    TestHelper.assertEquals(true, im:isKeyDown(VK_SPACE), "Space should be down")
    
    im:onKeyReleased("space", nil)
    TestHelper.assertEquals(false, im:isKeyDown(VK_SPACE), "Space should be up after release")
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
    TestHelper.assertEquals(2, #events, "Should have 2 events in queue")
    
    TestHelper.assertEquals("pressed", events[1].type, "First event should be pressed")
    TestHelper.assertEquals(1073741906, events[1].key, "First event key should be VK_UP")
    
    TestHelper.assertEquals("pressed", events[2].type, "Second event should be pressed")
    TestHelper.assertEquals(1073741905, events[2].key, "Second event key should be VK_DOWN")
    
    -- 队列应该已清空
    local events2 = im:pollEvents()
    TestHelper.assertEquals(0, #events2, "Queue should be empty after poll")
end

-- 测试5: 按键重复
function TestInputManager.testKeyRepeat()
    setup()
    print("\n=== Test: Key Repeat ===")
    
    local im = InputManager.getInstance()
    
    TestHelper.assertEquals(false, im:isKeyRepeatEnabled(), "Key repeat should be disabled initially")
    
    im:setKeyRepeat(true)
    TestHelper.assertEquals(true, im:isKeyRepeatEnabled(), "Key repeat should be enabled")
    
    im:setKeyRepeat(false)
    TestHelper.assertEquals(false, im:isKeyRepeatEnabled(), "Key repeat should be disabled")
end

-- 测试6: 按键映射
function TestInputManager.testKeyMapping()
    setup()
    print("\n=== Test: Key Mapping ===")
    
    local im = InputManager.getInstance()
    local keyMap = im:getKeyMap()
    
    -- 验证默认映射（使用实际数值）
    TestHelper.assertEquals(27, keyMap["escape"], "escape should map to 27")
    TestHelper.assertEquals(32, keyMap[" "], "space should map to 32")
    TestHelper.assertEquals(32, keyMap["space"], "space should map to 32")
    TestHelper.assertEquals(13, keyMap["return"], "return should map to 13")
    TestHelper.assertEquals(1073741906, keyMap["up"], "up should map to 1073741906")
    TestHelper.assertEquals(1073741905, keyMap["down"], "down should map to 1073741905")
    TestHelper.assertEquals(1073741904, keyMap["left"], "left should map to 1073741904")
    TestHelper.assertEquals(1073741903, keyMap["right"], "right should map to 1073741903")
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
    TestHelper.assertEquals(100, im:getKey(), "Custom key 'a' should map to 100")
    
    im:onKeyPressed("b", nil, false)
    TestHelper.assertEquals(101, im:getKey(), "Custom key 'b' should map to 101")
end

-- 测试8: 清空状态
function TestInputManager.testClear()
    setup()
    print("\n=== Test: Clear ===")
    
    local im = InputManager.getInstance()
    
    -- 添加一些事件和状态
    im:onKeyPressed("escape", nil, false)
    im:onKeyPressed("space", nil, false)
    
    TestHelper.assertEquals(true, im:isKeyDown(VK_ESCAPE), "Escape should be down")
    
    -- 清空
    im:clear()
    
    TestHelper.assertEquals(-1, im:getKey(), "Key should be -1 after clear")
    TestHelper.assertEquals(false, im:isKeyDown(VK_ESCAPE), "Key state should be false after clear")
    
    local events = im:pollEvents()
    TestHelper.assertEquals(0, #events, "Event queue should be empty after clear")
end

-- 测试9: disableInput 阻止普通 getKey/peekKey
function TestInputManager.testDisableInput()
    setup()
    print("\n=== Test: Disable Input ===")
    
    local im = InputManager.getInstance()
    
    -- 添加按键事件
    im:onKeyPressed("escape", nil, false)
    
    -- 正常情况下应该能获取
    TestHelper.assertEquals(VK_ESCAPE, im:peekKey(), "peekKey should return VK_ESCAPE normally")
    
    -- 启用 disableInput
    InputManager.disableInput = true
    
    -- 现在 peekKey 和 getKey 应该返回 -1
    TestHelper.assertEquals(-1, im:peekKey(), "peekKey should return -1 when disabled")
    TestHelper.assertEquals(-1, im:getKey(), "getKey should return -1 when disabled")
    
    -- 恢复
    InputManager.disableInput = false
end

-- 测试10: 内部方法绕过 disableInput
function TestInputManager.testInternalMethodsBypassDisableInput()
    setup()
    print("\n=== Test: Internal Methods Bypass DisableInput ===")
    
    local im = InputManager.getInstance()
    
    -- 添加按键事件
    im:onKeyPressed("left", nil, false)
    im:onKeyPressed("right", nil, false)
    
    -- 启用 disableInput
    InputManager.disableInput = true
    
    -- 普通方法应该返回 -1
    TestHelper.assertEquals(-1, im:peekKey(), "peekKey should return -1 when disabled")
    
    -- 内部方法应该能正常工作
    TestHelper.assertEquals(VK_LEFT, im:_peekKeyInternal(), "_peekKeyInternal should bypass disableInput")
    TestHelper.assertEquals(VK_LEFT, im:_getKeyInternal(), "_getKeyInternal should bypass disableInput")
    
    -- 消费了第一个按键，应该能获取第二个
    TestHelper.assertEquals(VK_RIGHT, im:_peekKeyInternal(), "_peekKeyInternal should see next key")
    
    -- 恢复
    InputManager.disableInput = false
end

-- 运行所有测试
function TestInputManager.runAll()
    print("\n========================================")
    print("Input Manager Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    
    TestInputManager.testInit()
    TestInputManager.testKeyPressed()
    TestInputManager.testKeyReleased()
    TestInputManager.testEventQueue()
    TestInputManager.testKeyRepeat()
    TestInputManager.testKeyMapping()
    TestInputManager.testCustomKeyMapping()
    TestInputManager.testClear()
    TestInputManager.testDisableInput()
    TestInputManager.testInternalMethodsBypassDisableInput()
    
    return TestHelper.printSummary()
end

-- 如果直接运行此文件
if arg and arg[0]:match("test_input_manager.lua$") then
    TestInputManager.runAll()
end

return TestInputManager
