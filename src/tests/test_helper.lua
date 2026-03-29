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
        Wugong = {},
    }
    return _G.JY
end

function TestHelper.mockWAR()
    _G.WAR = {
        PersonNum = 0,
        Person = {},
        CurID = 0,
        AutoFight = 0,
        Effect = 0,
        DrawMode = nil,
        MoveCursorX = nil,
        MoveCursorY = nil,
        ShowHead = 1,
        Data = {},
        EffectXY = {},
    }
    return _G.WAR
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
    TestHelper.mockWAR()
    TestHelper.mockLib()
    TestHelper.mockWarFunctions()
end

function TestHelper.mockWarFunctions()
    local warMapData = {}
    for i = 0, 19 do
        warMapData[i] = {}
        for j = 0, 19 do
            warMapData[i][j] = {}
            for k = 0, 5 do
                warMapData[i][j][k] = 255
            end
        end
    end
    
    _G.GetWarMap = function(x, y, layer)
        if x < 0 or x >= 20 or y < 0 or y >= 20 then
            return 255
        end
        return warMapData[x][y][layer] or 255
    end
    
    _G.SetWarMap = function(x, y, layer, value)
        if x >= 0 and x < 20 and y >= 0 and y < 20 then
            warMapData[x][y][layer] = value
        end
    end
    
    _G.CleanWarMap = function(layer, value)
        for i = 0, 19 do
            for j = 0, 19 do
                warMapData[i][j][layer] = value
            end
        end
    end
    
    _G.WarCalPersonPic = function(id)
        return 0
    end
    
    _G.WarSetPerson = function()
    end
    
    _G.WarDrawMap = function(flag)
    end
    
    _G.War_isEnd = function()
        return 0
    end
    
    _G.War_CalMoveStep = function(id, steps, mode)
        local result = {}
        for i = 0, steps do
            result[i] = { num = 0, x = {}, y = {} }
        end
        return result
    end
    
    _G.War_GetMinNeiLi = function(pid)
        return 0
    end
    
    _G.War_WugongHurtLife = function(enemy, wugong, level)
        return 10
    end
    
    _G.War_WugongHurtNeili = function(enemy, wugong, level)
        return 5
    end
    
    _G.War_AutoCalMaxEnemyMap = function(wugong, level)
    end
    
    _G.War_AutoCalMaxEnemy = function(x, y, wugong, level)
        return 0, nil, nil
    end
    
    _G.War_GetCanFightEnemyXY = function(scope)
        return nil, nil
    end
    
    _G.War_AutoSelectEnemy = function()
        return 0
    end
    
    _G.War_FightSelectType0 = function(wugong, level, x, y)
        return true
    end
    
    _G.War_FightSelectType1 = function(wugong, level, x, y)
    end
    
    _G.War_FightSelectType2 = function(wugong, level)
    end
    
    _G.War_FightSelectType3 = function(wugong, level, x, y)
        return true
    end
    
    _G.War_PersonLostLife = function()
    end
    
    _G.War_EndPersonData = function(isExp, warStatus)
    end
    
    _G.WarLoad = function(warid)
    end
    
    _G.WarSelectTeam = function()
    end
    
    _G.WarSelectEnemy = function()
    end
    
    _G.WarLoadMap = function(mapid)
    end
    
    _G.WarPersonSort = function()
    end
    
    _G.CleanMemory = function()
    end
    
    _G.PlayMIDI = function(music)
    end
    
    _G.PlayWavAtk = function(sound)
    end
    
    _G.AddPersonAttrib = function(pid, attr, value)
        if _G.JY and _G.JY.Person and _G.JY.Person[pid] then
            _G.JY.Person[pid][attr] = (_G.JY.Person[pid][attr] or 0) + value
        end
    end
    
    _G.Rnd = function(n)
        return 0
    end
    
    _G.War_ThingMenu = function()
    end
    
    _G.War_WaitMenu = function()
    end
    
    _G.War_StatusMenu = function()
    end
    
    _G.War_RestMenu = function()
    end
    
    _G.War_AutoMenu = function()
        _G.WAR.AutoFight = 1
    end
    
    _G.GAME_WMAP = 3
    _G.VK_SPACE = 32
    _G.VK_RETURN = 13
    _G.VK_ESCAPE = 27
    _G.VK_UP = 1073741906
    _G.VK_DOWN = 1073741905
    _G.VK_LEFT = 1073741904
    _G.VK_RIGHT = 1073741903
    _G.C_ORANGE = {255, 165, 0}
    _G.C_WHITE = {255, 255, 255}
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
        "input_async",
        "war_async",
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
    person["姓名"] = overrides["姓名"] or "测试人物"
    person["体力"] = overrides["体力"] or 100
    person["内力"] = overrides["内力"] or 100
    person["经验值"] = overrides["经验值"] or 0
    person["等级"] = overrides["等级"] or 1
    person["受伤程度"] = overrides["受伤程度"] or 0
    person["用毒能力"] = overrides["用毒能力"] or 0
    person["解毒能力"] = overrides["解毒能力"] or 0
    person["医疗能力"] = overrides["医疗能力"] or 0
    person["轻功"] = overrides["轻功"] or 50
    person["头像代号"] = overrides["头像代号"] or 1
    person["武功1"] = overrides["武功1"] or 1
    person["武功等级1"] = overrides["武功等级1"] or 100
    person["左右互搏"] = overrides["左右互搏"] or 0
    for k, v in pairs(overrides) do
        person[k] = v
    end
    return person
end

function TestHelper.createTestWarPerson(overrides)
    overrides = overrides or {}
    local warPerson = {
        ["人物编号"] = overrides["人物编号"] or 0,
        ["坐标X"] = overrides["坐标X"] or 5,
        ["坐标Y"] = overrides["坐标Y"] or 5,
        ["移动步数"] = overrides["移动步数"] or 3,
        ["贴图"] = overrides["贴图"] or 0,
        ["贴图类型"] = overrides["贴图类型"] or 0,
        ["人方向"] = overrides["人方向"] or 0,
        ["我方"] = overrides["我方"] or true,
        ["死亡"] = overrides["死亡"] or false,
        ["轻功"] = overrides["轻功"] or 50,
        ["点数"] = overrides["点数"] or 0,
        ["经验"] = overrides["经验"] or 0,
    }
    for k, v in pairs(overrides) do
        warPerson[k] = v
    end
    return warPerson
end

function TestHelper.createTestWugong(overrides)
    overrides = overrides or {}
    local wugong = {
        ID = overrides.ID or 1,
    }
    wugong["名称"] = overrides["名称"] or "测试武功"
    wugong["攻击范围"] = overrides["攻击范围"] or 0
    wugong["移动范围1"] = overrides["移动范围1"] or 3
    wugong["杀伤范围1"] = overrides["杀伤范围1"] or 1
    wugong["消耗内力点数"] = overrides["消耗内力点数"] or 10
    wugong["伤害类型"] = overrides["伤害类型"] or 0
    wugong["武功类型"] = overrides["武功类型"] or 0
    wugong["武功动画&音效"] = overrides["武功动画&音效"] or 0
    wugong["出招音效"] = overrides["出招音效"] or ""
    for k, v in pairs(overrides) do
        wugong[k] = v
    end
    return wugong
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
    _G.love = nil
    _G.CC = nil
    _G.JY = nil
    _G.WAR = nil
    _G.lib = nil
    _G.GetWarMap = nil
    _G.SetWarMap = nil
    _G.CleanWarMap = nil
    _G.WarCalPersonPic = nil
    _G.WarSetPerson = nil
    _G.WarDrawMap = nil
    _G.War_isEnd = nil
    _G.War_CalMoveStep = nil
    _G.War_GetMinNeiLi = nil
    _G.War_WugongHurtLife = nil
    _G.War_WugongHurtNeili = nil
    _G.War_AutoCalMaxEnemyMap = nil
    _G.War_AutoCalMaxEnemy = nil
    _G.War_GetCanFightEnemyXY = nil
    _G.War_AutoSelectEnemy = nil
    _G.War_FightSelectType0 = nil
    _G.War_FightSelectType1 = nil
    _G.War_FightSelectType2 = nil
    _G.War_FightSelectType3 = nil
    _G.War_PersonLostLife = nil
    _G.War_EndPersonData = nil
    _G.WarLoad = nil
    _G.WarSelectTeam = nil
    _G.WarSelectEnemy = nil
    _G.WarLoadMap = nil
    _G.WarPersonSort = nil
    _G.CleanMemory = nil
    _G.PlayMIDI = nil
    _G.PlayWavAtk = nil
    _G.AddPersonAttrib = nil
    _G.Rnd = nil
    _G.War_ThingMenu = nil
    _G.War_WaitMenu = nil
    _G.War_StatusMenu = nil
    _G.War_RestMenu = nil
    _G.War_AutoMenu = nil
    _G.GAME_WMAP = nil
    _G.VK_SPACE = nil
    _G.VK_RETURN = nil
    _G.VK_ESCAPE = nil
    _G.VK_UP = nil
    _G.VK_DOWN = nil
    _G.VK_LEFT = nil
    _G.VK_RIGHT = nil
    _G.C_ORANGE = nil
    _G.C_WHITE = nil
end

return TestHelper
