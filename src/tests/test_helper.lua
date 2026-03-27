-- test_helper.lua
-- 测试辅助工具集
-- 提供 Mock、Spy、Stub 和断言函数

local TestHelper = {}

-- ============================================
-- 断言函数
-- ============================================

-- 测试计数
TestHelper.testCount = 0
TestHelper.passCount = 0
TestHelper.failCount = 0

-- 重置测试计数
function TestHelper.resetCounts()
    TestHelper.testCount = 0
    TestHelper.passCount = 0
    TestHelper.failCount = 0
end

-- 相等断言
function TestHelper.assertEquals(expected, actual, message)
    TestHelper.testCount = TestHelper.testCount + 1
    if expected == actual then
        TestHelper.passCount = TestHelper.passCount + 1
        print(string.format("[PASS] %s", message or "Test"))
        return true
    else
        TestHelper.failCount = TestHelper.failCount + 1
        print(string.format("[FAIL] %s: expected %s, got %s", 
            message or "Test", tostring(expected), tostring(actual)))
        return false
    end
end

-- 真值断言
function TestHelper.assertTrue(value, message)
    return TestHelper.assertEquals(true, value ~= nil and value ~= false, message)
end

-- 假值断言
function TestHelper.assertFalse(value, message)
    return TestHelper.assertEquals(false, value ~= nil and value ~= false, message)
end

-- 非 nil 断言
function TestHelper.assertNotNil(value, message)
    return TestHelper.assertEquals(true, value ~= nil, message)
end

-- nil 断言
function TestHelper.assertNil(value, message)
    return TestHelper.assertEquals(true, value == nil, message)
end

-- 获取测试结果统计
function TestHelper.getStats()
    return {
        total = TestHelper.testCount,
        passed = TestHelper.passCount,
        failed = TestHelper.failCount,
        allPassed = TestHelper.failCount == 0
    }
end

-- 打印测试结果摘要
function TestHelper.printSummary()
    print("\n========================================")
    print(string.format("Results: %d tests, %d passed, %d failed", 
        TestHelper.testCount, TestHelper.passCount, TestHelper.failCount))
    print("========================================")
    return TestHelper.failCount == 0
end

-- ============================================
-- Love2D API Mock
-- ============================================

-- Mock love.timer
function TestHelper.mockLoveTimer()
    local mockTime = 0
    return {
        getTime = function()
            return mockTime
        end,
        getDelta = function()
            return 0.016  -- 约60fps
        end,
        step = function()
            mockTime = mockTime + 0.016
        end,
        setTime = function(t)
            mockTime = t
        end
    }
end

-- Mock love.graphics
function TestHelper.mockLoveGraphics()
    local drawCalls = {}
    return {
        draw = function(...)
            table.insert(drawCalls, {...})
        end,
        print = function(...)
            table.insert(drawCalls, {"print", ...})
        end,
        rectangle = function(...)
            table.insert(drawCalls, {"rectangle", ...})
        end,
        getDrawCalls = function()
            return drawCalls
        end,
        clearDrawCalls = function()
            drawCalls = {}
        end,
        setColor = function() end,
        setFont = function() end,
        getFont = function() return {} end
    }
end

-- Mock love.keyboard
function TestHelper.mockLoveKeyboard()
    local keyStates = {}
    return {
        isDown = function(key)
            return keyStates[key] or false
        end,
        setKeyDown = function(key, down)
            keyStates[key] = down
        end,
        reset = function()
            keyStates = {}
        end
    }
end

-- Mock love.data
function TestHelper.mockLoveData()
    -- 确保 bit32 可用（标准 Lua 5.1 需要加载 luabit）
    if not bit32 then
        require("luabit")
        bit32 = bit
        bit32.rshift = bit.brshift
    end
    
    local ByteData = {}
    ByteData.__index = ByteData
    
    function ByteData.new(size)
        local self = setmetatable({}, ByteData)
        self._size = size
        self._data = {}
        for i = 0, size - 1 do
            self._data[i] = 0
        end
        return self
    end
    
    function ByteData:setByte(offset, value)
        self._data[offset] = value
    end
    
    function ByteData:getByte(offset)
        return self._data[offset] or 0
    end
    
    function ByteData:getString()
        local chars = {}
        for i = 0, self._size - 1 do
            chars[i + 1] = string.char(self._data[i] or 0)
        end
        return table.concat(chars)
    end
    
    return {
        newByteData = function(size)
            return ByteData.new(size)
        end
    }
end

-- 完整 Love2D Mock
function TestHelper.mockLove()
    local mock = {
        timer = TestHelper.mockLoveTimer(),
        graphics = TestHelper.mockLoveGraphics(),
        keyboard = TestHelper.mockLoveKeyboard(),
        data = TestHelper.mockLoveData()
    }
    _G.love = mock
    return mock
end

-- ============================================
-- 游戏数据 Mock
-- ============================================

-- Mock CC 配置
function TestHelper.mockCC()
    _G.CC = {
        ScreenW = 1024,
        ScreenH = 768,
        DefaultFont = 16,
        MenuBorderPixel = 2,
        RowPixel = 4,
        XScale = 18,
        YScale = 9,
    }
    return _G.CC
end

-- Mock JY 数据
function TestHelper.mockJY()
    _G.JY = {
        Status = 0,
        SubScene = 0,
        CurrentD = 0,
        Person = {},
        Thing = {},
        Scene = {},
    }
    return _G.JY
end

-- Mock lib 模块
function TestHelper.mockLib()
    _G.lib = {
        Debug = function() end,
        GetKey = function() return -1 end,
        Delay = function() end,
        Cls = function() end,
    }
    return _G.lib
end

-- Mock 所有全局依赖
function TestHelper.mockGlobals()
    TestHelper.mockLove()
    TestHelper.mockCC()
    TestHelper.mockJY()
    TestHelper.mockLib()
end

-- ============================================
-- 模块重置工具
-- ============================================

-- 重置单个模块
function TestHelper.resetModule(moduleName)
    package.loaded[moduleName] = nil
end

-- 重置所有测试相关模块
function TestHelper.resetAllModules()
    local modulesToReset = {
        "state_machine",
        "input_manager",
        "coroutine_scheduler",
        "event_bridge",
        "menu_state_machine",
        "menu_async",
        "async_dialog",
        "async_message_box",
    }
    for _, name in ipairs(modulesToReset) do
        package.loaded[name] = nil
    end
end

-- 重置单例实例
function TestHelper.resetSingleton(module)
    if module and module.reset then
        module:reset()
    end
end

-- ============================================
-- Spy 和 Stub 工具
-- ============================================

-- 创建 Stub
function TestHelper.stub(object, methodName, returnValue)
    local original = object[methodName]
    local calls = {}
    
    object[methodName] = function(...)
        table.insert(calls, {...})
        return returnValue
    end
    
    return {
        restore = function()
            object[methodName] = original
        end,
        getCalls = function()
            return calls
        end,
        wasCalled = function()
            return #calls > 0
        end,
        callCount = function()
            return #calls
        end
    }
end

-- 创建 Spy
function TestHelper.spy(object, methodName)
    local original = object[methodName]
    local calls = {}
    
    object[methodName] = function(...)
        table.insert(calls, {...})
        return original(...)
    end
    
    return {
        restore = function()
            object[methodName] = original
        end,
        getCalls = function()
            return calls
        end,
        wasCalled = function()
            return #calls > 0
        end,
        wasCalledWith = function(...)
            local expectedArgs = {...}
            for _, call in ipairs(calls) do
                local match = true
                for i, arg in ipairs(expectedArgs) do
                    if call[i] ~= arg then
                        match = false
                        break
                    end
                end
                if match then
                    return true
                end
            end
            return false
        end,
        callCount = function()
            return #calls
        end
    }
end

-- ============================================
-- 测试数据工厂
-- ============================================

-- 创建测试人物数据
function TestHelper.createTestPerson(overrides)
    overrides = overrides or {}
    local person = {
        ID = overrides.ID or 1,
        name = overrides.name or "TestPerson",
        life = overrides.life or 100,
        power = overrides.power or 100,
        stamina = overrides.stamina or 100,
        exp = overrides.exp or 0,
        level = overrides.level or 1,
    }
    for k, v in pairs(overrides) do
        person[k] = v
    end
    return person
end

-- 创建测试物品数据
function TestHelper.createTestThing(overrides)
    overrides = overrides or {}
    local thing = {
        ID = overrides.ID or 1,
        name = overrides.name or "TestItem",
        type = overrides.type or 0,
        count = overrides.count or 1,
    }
    for k, v in pairs(overrides) do
        thing[k] = v
    end
    return thing
end

-- 创建测试菜单数据
function TestHelper.createTestMenu(items)
    items = items or {
        {"选项1", nil, 1},
        {"选项2", nil, 1},
        {"选项3", nil, 1},
    }
    return {
        items = items,
        numItem = #items,
        numShow = #items,
    }
end

-- ============================================
-- 测试生命周期
-- ============================================

-- 测试前的标准初始化
function TestHelper.setup()
    TestHelper.resetCounts()
    TestHelper.mockGlobals()
    TestHelper.resetAllModules()
end

-- 测试后的清理
function TestHelper.teardown()
    -- 清理全局 Mock
    _G.love = nil
    _G.CC = nil
    _G.JY = nil
    _G.lib = nil
end

return TestHelper
