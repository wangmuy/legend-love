-- test_coroutine_scheduler.lua
-- 协程调度器模块单元测试

local TestHelper = require("tests.test_helper")
local CoroutineScheduler = require("coroutine_scheduler")
local InputManager = require("input_manager")

local TestCoroutineScheduler = {}

local VK_ESCAPE = 27
local VK_LEFT = 1073741904
local VK_RIGHT = 1073741903

local function setup()
    TestHelper.setup()
    CoroutineScheduler.getInstance():reset()
    CoroutineScheduler.getInstance():init({ timeSource = function() return 0 end })
    InputManager.getInstance():reset()
    InputManager.getInstance():init()
end

-- 测试1: 协程创建和启动
function TestCoroutineScheduler.testCreateAndStart()
    setup()
    print("\n=== Test: Create and Start ===")
    
    local scheduler = CoroutineScheduler.getInstance()
    local executed = false
    
    local id = scheduler:create(function()
        executed = true
    end, "test_coroutine")
    
    TestHelper.assertEquals("number", type(id), "Should return coroutine ID")
    
    scheduler:start(id)
    
    TestHelper.assertEquals(true, executed, "Coroutine should have executed")
end

-- 测试2: 协程 yield 和恢复
function TestCoroutineScheduler.testYieldAndResume()
    setup()
    print("\n=== Test: Yield and Resume ===")
    
    local scheduler = CoroutineScheduler.getInstance()
    local step = 0
    
    local id = scheduler:create(function()
        step = 1
        scheduler:yield("test")
        step = 2
    end)
    
    scheduler:start(id)
    TestHelper.assertEquals(1, step, "Step should be 1 after yield")
    
    scheduler:resume(id)
    TestHelper.assertEquals(2, step, "Step should be 2 after resume")
end

-- 测试3: waitForKey 在 disableInput=true 时仍能获取按键
function TestCoroutineScheduler.testWaitForKeyWithDisableInput()
    setup()
    print("\n=== Test: WaitForKey with DisableInput ===")
    
    local scheduler = CoroutineScheduler.getInstance()
    local im = InputManager.getInstance()
    local receivedKey = nil
    
    -- 创建等待按键的协程
    local id = scheduler:create(function()
        receivedKey = scheduler:waitForKey()
    end, "key_waiter")
    
    scheduler:start(id)
    
    -- 验证协程状态
    TestHelper.assertEquals("suspended", scheduler:getStatus(id), "Coroutine should be suspended")
    
    -- 设置 disableInput = true（模拟状态显示界面）
    InputManager.disableInput = true
    
    -- 模拟按键按下
    im:onKeyPressed("left", nil, false)
    
    -- 更新调度器（应该能绕过 disableInput 获取按键）
    scheduler:update(0.016)
    
    -- 验证协程收到了按键
    TestHelper.assertEquals(VK_LEFT, receivedKey, "Coroutine should receive key despite disableInput")
    
    -- 清理
    InputManager.disableInput = false
end

-- 测试4: 多个协程等待按键时，都能收到同一个按键
function TestCoroutineScheduler.testMultipleCoroutinesWaitForKey()
    setup()
    print("\n=== Test: Multiple Coroutines WaitForKey ===")
    
    local scheduler = CoroutineScheduler.getInstance()
    local im = InputManager.getInstance()
    local key1, key2 = nil, nil
    
    local id1 = scheduler:create(function()
        key1 = scheduler:waitForKey()
    end, "waiter1")
    
    local id2 = scheduler:create(function()
        key2 = scheduler:waitForKey()
    end, "waiter2")
    
    scheduler:start(id1)
    scheduler:start(id2)
    
    -- 设置 disableInput
    InputManager.disableInput = true
    
    -- 模拟按键
    im:onKeyPressed("escape", nil, false)
    
    scheduler:update(0.016)
    
    -- 两个协程都应该收到按键
    TestHelper.assertEquals(VK_ESCAPE, key1, "Coroutine 1 should receive key")
    TestHelper.assertEquals(VK_ESCAPE, key2, "Coroutine 2 should receive key")
    
    InputManager.disableInput = false
end

-- 测试5: 状态显示场景模拟
function TestCoroutineScheduler.testPersonStatusScenario()
    setup()
    print("\n=== Test: Person Status Scenario ===")
    
    local scheduler = CoroutineScheduler.getInstance()
    local im = InputManager.getInstance()
    
    local currentPage = 1
    local exited = false
    
    -- 模拟 PersonStatusAsync.ShowStatusCoroutine 的行为
    local id = scheduler:create(function()
        local page = 1
        local pagenum = 2
        
        while true do
            local keypress = scheduler:waitForKey()
            
            if keypress == VK_ESCAPE then
                exited = true
                break
            elseif keypress == VK_LEFT then
                page = page - 1
            elseif keypress == VK_RIGHT then
                page = page + 1
            end
            
            page = math.max(1, math.min(page, pagenum))
            currentPage = page
        end
    end, "status_display")
    
    scheduler:start(id)
    
    -- 设置 disableInput（状态显示时）
    InputManager.disableInput = true
    
    -- 模拟按下右键（翻页）
    im:onKeyPressed("right", nil, false)
    scheduler:update(0.016)
    TestHelper.assertEquals(2, currentPage, "Page should be 2 after right")
    
    -- 模拟再次按下右键（不会超出范围）
    im:onKeyPressed("right", nil, false)
    scheduler:update(0.016)
    TestHelper.assertEquals(2, currentPage, "Page should stay at 2")
    
    -- 模拟按下左键
    im:onKeyPressed("left", nil, false)
    scheduler:update(0.016)
    TestHelper.assertEquals(1, currentPage, "Page should be 1 after left")
    
    -- 模拟按下 ESC 退出
    im:onKeyPressed("escape", nil, false)
    scheduler:update(0.016)
    TestHelper.assertEquals(true, exited, "Should have exited on ESC")
    
    InputManager.disableInput = false
end

-- 运行所有测试
function TestCoroutineScheduler.runAll()
    print("\n========================================")
    print("Coroutine Scheduler Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    
    TestCoroutineScheduler.testCreateAndStart()
    TestCoroutineScheduler.testYieldAndResume()
    TestCoroutineScheduler.testWaitForKeyWithDisableInput()
    TestCoroutineScheduler.testMultipleCoroutinesWaitForKey()
    TestCoroutineScheduler.testPersonStatusScenario()
    
    return TestHelper.printSummary()
end

-- 如果直接运行此文件
if arg and arg[0]:match("test_coroutine_scheduler.lua$") then
    TestCoroutineScheduler.runAll()
end

return TestCoroutineScheduler