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
        require("framework.luabit")
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
    TestHelper.mockEngineAPI()
end

function TestHelper.mockEngineAPI()
    -- love 风格的 open mode（"r"/"w"/"a"/"c"）转成 io.open 能接受的形式。
    -- lib_file.toLoveOpenMode 把含 "+" 的模式（如 "r+b"）映射为 "c"，
    -- 但 io.open 不认 "c"，必须先转回 "r+b"/"w+b"。
    local function toIOOpenMode(mode)
        mode = mode or "r"
        if mode == "c" then return "r+b" end
        return mode
    end

    _G.EngineAPI = {
        time = {
            getTime = function() return love and love.timer and love.timer.getTime and love.timer.getTime() * 1000 or 0 end,
            getTimeSeconds = function() return love and love.timer and love.timer.getTime and love.timer.getTime() or 0 end,
            sleep = function() end,
        },
        file = {
            -- 真实文件访问：lib_file 已迁移到 EngineAPI.file，mock 必须委托到 io.*
            -- 否则所有读文件路径返回 nil（历史遗留：本 mock 曾返回恒 false/nil）
            exists = function(p)
                local f = io.open(p, "r")
                if f then f:close() return true end
                return false
            end,
            getSize = function(p)
                local f = io.open(p, "rb")
                if f then local s = f:seek("end") f:close() return s end
                return -1
            end,
            open = function(p, mode) return io.open(p, toIOOpenMode(mode)) end,
            openFile = function(p, mode) return io.open(p, toIOOpenMode(mode)) end,
            read = function(p)
                local f = io.open(p, "rb")
                if not f then return nil end
                local d = f:read("*a")
                f:close()
                return d
            end,
            write = function(p, d)
                local f = io.open(p, "wb")
                if not f then return false end
                f:write(d)
                f:close()
                return true
            end,
            lines = function(p)
                local f = io.open(p, "r")
                if not f then return function() return nil end end
                return function()
                    local l = f:read("*line")
                    if not l then f:close() end
                    return l
                end
            end,
            createDirectory = function() end,
            remove = function(p) return os.remove(p) end,
        },
        debug = { log = function() end },
        coroutine = {
            isRunning = function() return false end,
            yieldPoint = function() end,
            waitFor = function() return false end,
        },
        app = { quit = function() end },
        script = { load = function() return nil end },
    }
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
    
    _G.War_Direct = function(x1, y1, x2, y2)
        local x = x2 - x1
        local y = y2 - y1
        if math.abs(y) > math.abs(x) then
            if y > 0 then return 3 else return 0 end
        else
            if x > 0 then return 1 else return 2 end
        end
    end
    
    _G.War_PoisonHurt = function(pid, targetId)
        return 10
    end
    
    _G.ExecDecPoison = function(pid, targetId)
        return 20
    end
    
    _G.ExecDoctor = function(pid, targetId)
        return 30
    end
    
    _G.War_AnqiHurt = function(pid, targetId, thingid)
        return 15
    end
    
    _G.instruct_32 = function(thingid, count)
    end
    
    _G.WarSetPerson = function()
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
    _G.War_Direct = nil
    _G.War_PoisonHurt = nil
    _G.ExecDecPoison = nil
    _G.ExecDoctor = nil
    _G.War_AnqiHurt = nil
    _G.instruct_32 = nil
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

-- ---------------------------------------------------------------------------
-- 自愈：产物 save/ 与源 save/ 逐字节对齐（MOD 存档槽自愈）
-- ---------------------------------------------------------------------------
-- 背景：存档 round-trip 测试（mod_boot round-trip、mod_check_one SAVE 自检）
-- 先删槽文件再写引擎存档。若进程中途被杀（provider 断连、超时 kill 等），
-- 产物 save/ 会停在「引擎存档」状态：r1.grp 内容不符、s1.grp/d1.grp 缺失、
-- r1.idx/r1.ovr 播种残留。这会污染下一次全量运行：mod_resources 的字节比对
-- 与 mod_audit 的「必需但未进产物」矛盾检查会报出假失败，且失败面随每次
-- 中断位置漂移（同一套件多次运行结果不一致的根因）。
-- 源包 save/ 是唯一规范态：构建从源→产物逐字节复制，测试结束也应恢复源态。
-- 本函数在套件入口（runAll/runModule）与 mod_check_one 入口各做一次归一化，
-- 让每次运行从干净基线开始；它不掩盖运行内缺陷——套件开始后的所有检查
-- 仍是纯断言（运行内任何模块再次破坏 save/ 仍会被后续检查捕获）。
--
-- 返回修复的文件数（0 = 无需修复）。
function TestHelper.healModSave(slug)
    -- 只对已存在的产物目录自愈（产物目录由构建创建）。防止 reference 下
    -- 临时出现的非规范目录（如并行实验的 kys-s-* 暂存）被误自愈成幻影
    -- mods/<slug>/ 或误报缺失。
    local function dirExists(d)
        local p = io.popen('test -d "' .. d .. '" && echo y', "r")
        if not p then return false end
        local ok = p:read() == "y\n"
        p:close()
        return ok
    end
    if not dirExists("mods/" .. slug) then return 0 end
    local function listDir1(d)
        local out, p = {}, io.popen('ls -1 "' .. d .. '" 2>/dev/null', "r")
        if not p then return out end
        for line in p:lines() do out[#out + 1] = line end
        p:close()
        return out
    end
    local function readAll(p)
        local f = io.open(p, "rb")
        if not f then return nil end
        local d = f:read("*a"); f:close()
        return d
    end
    local srcDir = "../reference/allmods/kys-" .. slug .. "/save/"
    local dstDir = "mods/" .. slug .. "/save/"
    local srcFiles = listDir1(srcDir)
    if #srcFiles == 0 then return 0 end
    os.execute('mkdir -p "' .. dstDir .. '"')
    local healed = 0
    local srcSet = {}
    for _, n in ipairs(srcFiles) do
        srcSet[n] = true
        local sd = readAll(srcDir .. n)
        if sd == nil then goto cont end
        local dd = readAll(dstDir .. n)
        if dd ~= sd then
            local out = io.open(dstDir .. n, "wb")
            if out then out:write(sd); out:close(); healed = healed + 1 end
        end
        ::cont::
    end
    for _, n in ipairs(listDir1(dstDir)) do
        if not srcSet[n] then
            os.remove(dstDir .. n)
            healed = healed + 1
        end
    end
    return healed
end

-- 全部 20 个 MOD 产物 save/ 自愈（套件入口调用）
function TestHelper.healAllModSaves()
    local total, p = 0, io.popen("ls -1d ../reference/allmods/kys-* 2>/dev/null", "r")
    if p then
        for d in p:lines() do
            local slug = d:match("kys-(.+)")
            if slug then total = total + TestHelper.healModSave(slug) end
        end
        p:close()
    end
    if total > 0 then
        print("[heal] 修复 " .. total .. " 个存档槽文件（上次运行中断残留）")
    end
    return total
end

return TestHelper
