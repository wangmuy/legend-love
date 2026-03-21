-- jymain_adapter.lua
-- JY_Main适配器，连接新旧架构
-- 完全事件驱动版本

local JYMainAdapter = {}

-- 导入模块
local EventBridge = require("event_bridge")
local GameStates = require("game_states")
local MenuAsync = require("menu_async")
local CoroutineScheduler = require("coroutine_scheduler")
local InputAsync = require("input_async")
local EventExecutor = require("event_executor")

-- 游戏初始化标志
local isInitialized = false
local initCoroutine = nil

-- 获取状态ID的辅助函数
local function getStateId(stateName)
    if stateName == "GAME_MMAP" then
        return GAME_MMAP or 2
    elseif stateName == "GAME_SMAP" then
        return GAME_SMAP or 4
    elseif stateName == "GAME_FIRSTMMAP" then
        return GAME_FIRSTMMAP or 1
    elseif stateName == "GAME_START" then
        return GAME_START or 0
    elseif stateName == "GAME_WMAP" then
        return GAME_WMAP or 5
    elseif stateName == "GAME_END" then
        return GAME_END or 7
    end
    return nil
end

-- 初始化游戏（事件驱动版本）
function JYMainAdapter.init()
    if isInitialized then
        return
    end
    
    -- 使用协程执行初始化流程
    local scheduler = CoroutineScheduler.getInstance()
    initCoroutine = scheduler:create(function()
        JYMainAdapter.initCoroutine()
    end, "init")
    
    scheduler:start(initCoroutine)
end

-- 初始化协程
function JYMainAdapter.initCoroutine()
    lib.Debug("JYMainAdapter.initCoroutine started")
    
    -- 导入其他模块
    IncludeFile()
    lib.Debug("IncludeFile done")
    
    SetGlobalConst()
    lib.Debug("SetGlobalConst done")
    
    SetGlobal()
    lib.Debug("SetGlobal done")
    
    GenTalkIdx()
    lib.Debug("GenTalkIdx done")
    
    SetModify()
    lib.Debug("SetModify done")
    
    -- 禁止访问全程变量
    setmetatable(_G, {
        __newindex = function(_, n)
            error("attempt read write to undeclared variable " .. n, 2)
        end,
        __index = function(_, n)
            error("attempt read read to undeclared variable " .. n, 2)
        end,
    })
    
    lib.Debug("JY_Main start.")
    
    math.randomseed(os.time())
    
    lib.EnableKeyRepeat(CONFIG.KeyRepeatDelay, CONFIG.KeyRepeatInterval)
    
    JY.Status = getStateId("GAME_START")
    
    lib.PicInit(CC.PaletteFile)
    
    -- 注册游戏状态
    GameStates.registerAll()
    
    -- 切换到开始菜单状态
    EventBridge.getInstance():switchState(getStateId("GAME_START"))
    
    -- 显示开始菜单（使用协程版本的菜单）
    JYMainAdapter.showStartMenuCoroutine()
    
    isInitialized = true
    lib.Debug("JYMainAdapter.initCoroutine completed")
end

-- 显示开始菜单（协程版本）
function JYMainAdapter.showStartMenuCoroutine()
    local scheduler = CoroutineScheduler.getInstance()
    
    lib.PlayMPEG(CONFIG.DataPath .. "start.mpg", VK_ESCAPE)
    
    Cls()
    
    PlayMIDI(16)
    lib.ShowSlow(50, 0)
    
    local menu = {
        {"重新开始", nil, 1},
        {"载入进度", nil, 1},
        {"离开游戏", nil, 1}
    }
    local menux = (CC.ScreenW - 4 * CC.StartMenuFontSize - 2 * CC.MenuBorderPixel) / 2
    
    local menuReturn = MenuAsync.ShowMenuCoroutine(menu, 3, 0, menux, CC.StartMenuY, 0, 0, 0, 0, CC.StartMenuFontSize, C_STARTMENU, C_RED)
    
    if menuReturn == 1 then
        JYMainAdapter.startNewGame(menux)
    elseif menuReturn == 2 then
        JYMainAdapter.loadGame()
    elseif menuReturn == 3 then
        JY.Status = getStateId("GAME_END")
        love.event.quit()
    end
end

-- 属性随机范围定义（用于判断是否为当前随机最大值）
local ATTRIBUTE_RANGES = {
    ["内力最大值"] = {min = 21, max = 40},  -- Rnd(20) + 21 (21-40)
    ["攻击力"] = {min = 21, max = 30},      -- Rnd(10) + 21 (21-30)
    ["防御力"] = {min = 21, max = 30},      -- Rnd(10) + 21 (21-30)
    ["轻功"] = {min = 21, max = 30},        -- Rnd(10) + 21 (21-30)
    ["医疗能力"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["用毒能力"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["解毒能力"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["拳掌功夫"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["御剑能力"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["耍刀技巧"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["暗器技巧"] = {min = 21, max = 30},    -- Rnd(10) + 21 (21-30)
    ["生命增长"] = {min = 3, max = 7},      -- Rnd(5) + 3 (3-7)
    ["生命最大值"] = {min = 38, max = 50},  -- 生命增长(3-7) * 3 + 29 = 38-50
    ["资质"] = {
        tiers = {
            {min = 30, max = 64},   -- 30-64 (20%概率: Rnd(35)+30)
            {min = 60, max = 79},   -- 60-79 (60%概率: Rnd(20)+60)
            {min = 75, max = 94}    -- 75-94 (20%概率: Rnd(20)+75)
        }
    }
}

-- 获取属性的当前随机范围最大值
local function getAttributeMaxRandomValue(attrKey, value)
    local range = ATTRIBUTE_RANGES[attrKey]
    if not range then
        return nil
    end
    
    -- 资质特殊处理，根据当前值判断属于哪个档次
    if attrKey == "资质" then
        for _, tier in ipairs(range.tiers) do
            if value >= tier.min and value <= tier.max then
                return tier.max
            end
        end
        return 94  -- 默认最大值
    end
    
    return range.max
end

-- 生成随机属性
local function generateRandomAttributes()
    JY.Person[0]["内力性质"] = Rnd(2)
    JY.Person[0]["内力最大值"] = Rnd(20) + 21
    JY.Person[0]["攻击力"] = Rnd(10) + 21
    JY.Person[0]["防御力"] = Rnd(10) + 21
    JY.Person[0]["轻功"] = Rnd(10) + 21
    JY.Person[0]["医疗能力"] = Rnd(10) + 21
    JY.Person[0]["用毒能力"] = Rnd(10) + 21
    JY.Person[0]["解毒能力"] = Rnd(10) + 21
    JY.Person[0]["抗毒能力"] = Rnd(10) + 21
    JY.Person[0]["拳掌功夫"] = Rnd(10) + 21
    JY.Person[0]["御剑能力"] = Rnd(10) + 21
    JY.Person[0]["耍刀技巧"] = Rnd(10) + 21
    JY.Person[0]["特殊兵器"] = Rnd(10) + 21
    JY.Person[0]["暗器技巧"] = Rnd(10) + 21
    JY.Person[0]["生命增长"] = Rnd(5) + 3
    JY.Person[0]["生命最大值"] = JY.Person[0]["生命增长"] * 3 + 29
    
    local rate = Rnd(10)
    if rate < 2 then
        JY.Person[0]["资质"] = Rnd(35) + 30
    elseif rate <= 7 then
        JY.Person[0]["资质"] = Rnd(20) + 60
    else
        JY.Person[0]["资质"] = Rnd(20) + 75
    end
    
    JY.Person[0]["生命"] = JY.Person[0]["生命最大值"]
    JY.Person[0]["内力"] = JY.Person[0]["内力最大值"]
end

-- 显示属性选择界面
local function showAttributeSelection()
    local fontsize = CC.NewGameFontSize
    local h = fontsize + CC.RowPixel
    local w = fontsize * 4
    local x1 = (CC.ScreenW - w * 4) / 2
    local y1 = CC.NewGameY
    
    -- 绘制属性
    -- str1: 显示名称, str2: 属性键, str3: 用于判断最大值的键, i: 列索引, y: Y坐标
    local function DrawAttrib(str1, str2, str3, i, y)
        DrawString(x1 + i * w, y, str1, C_RED, fontsize)
        
        -- 判断是否为当前随机范围的最大值，最大值用黄色显示
        local value = JY.Person[0][str2]
        local maxRandomValue = getAttributeMaxRandomValue(str3, value)
        local valueColor = C_WHITE
        
        if maxRandomValue and value >= maxRandomValue then
            valueColor = C_GOLD  -- 黄色显示当前随机范围的最大值
        end
        DrawString(x1 + i * w + fontsize * 2, y, string.format("%3d ", value), valueColor, fontsize)
    end
    
    DrawString(x1, y1, "这样的属性满意吗(Y/N)?", C_GOLD, fontsize)
    
    local i = 0
    y1 = y1 + h
    DrawAttrib("内力", "内力", "内力最大值", i, y1); i = i + 1
    DrawAttrib("攻击", "攻击力", "攻击力", i, y1); i = i + 1
    DrawAttrib("轻功", "轻功", "轻功", i, y1); i = i + 1
    DrawAttrib("防御", "防御力", "防御力", i, y1)
    
    i = 0
    y1 = y1 + h
    DrawAttrib("生命", "生命", "生命最大值", i, y1); i = i + 1
    DrawAttrib("医疗", "医疗能力", "医疗能力", i, y1); i = i + 1
    DrawAttrib("用毒", "用毒能力", "用毒能力", i, y1); i = i + 1
    DrawAttrib("解毒", "解毒能力", "解毒能力", i, y1)
    
    i = 0
    y1 = y1 + h
    DrawAttrib("拳掌", "拳掌功夫", "拳掌功夫", i, y1); i = i + 1
    DrawAttrib("御剑", "御剑能力", "御剑能力", i, y1); i = i + 1
    DrawAttrib("耍刀", "耍刀技巧", "耍刀技巧", i, y1); i = i + 1
    DrawAttrib("暗器", "暗器技巧", "暗器技巧", i, y1)
end

-- 创建属性选择绘制回调
local function createAttributeDrawCallback()
    return function()
        showAttributeSelection()
    end
end

-- 开始新游戏（异步版本）
function JYMainAdapter.startNewGame(menux)
    Cls()
    DrawString(menux, CC.StartMenuY, "请稍候...", C_RED, CC.StartMenuFontSize)
    ShowScreen()
    
    -- 载入新游戏数据
    LoadRecord(0)
    JY.Person[0]["姓名"] = CC.NewPersonName
    
    -- 属性选择循环（异步版本）
    local satisfied = false
    while not satisfied do
        -- 生成随机属性
        generateRandomAttributes()
        
        -- 清屏并设置绘制回调
        Cls()
        EventBridge.setGlobalDrawCallback(createAttributeDrawCallback())
        
        -- 异步菜单询问是否满意
        local menu = {
            {"是 ", nil, 1},
            {"否 ", nil, 2},
        }
        local fontsize = CC.NewGameFontSize
        local x1 = (CC.ScreenW - fontsize * 4 * 4) / 2
        local ok = MenuAsync.ShowMenu2Coroutine(menu, 2, 0, x1 + 11 * fontsize, CC.NewGameY - CC.MenuBorderPixel, 0, 0, 0, 1, fontsize, C_RED, C_WHITE)
        
        -- 清除绘制回调
        EventBridge.clearGlobalDrawCallback()
        
        if ok == 1 then
            -- 选择"是"，确认属性
            satisfied = true
        elseif ok == 0 then
            -- 按ESC键，返回到开始菜单
            lib.Debug("startNewGame: ESC pressed, returning to start menu")
            -- 切换回开始菜单状态
            EventBridge.getInstance():switchState(getStateId("GAME_START"))
            -- 重新显示开始菜单
            JYMainAdapter.showStartMenuCoroutine()
            return
        end
        -- ok == 2 时（选择"否"），继续循环重新随机属性
    end
    
    -- 继续新游戏初始化
    JY.SubScene = CC.NewGameSceneID
    JY.Scene[JY.SubScene]["名称"] = JY.Person[0]["姓名"] .. "居"
    JY.Base["人X1"] = CC.NewGameSceneX
    JY.Base["人Y1"] = CC.NewGameSceneY
    JY.MyPic = CC.NewPersonPic
    
    lib.ShowSlow(50, 1)
    
    JY.MmapMusic = -1
    
    CleanMemory()
    
    Init_SMap(0)
    
    if CC.NewGameEvent > 0 then
        -- 在协程中执行新游戏事件
        local AsyncGlobals = require("async_globals")
        AsyncGlobals.install()
        local success, err = pcall(function()
            oldCallEvent(CC.NewGameEvent)
        end)
        AsyncGlobals.uninstall()
        
        if not success then
            lib.Debug("startNewGame event error: " .. tostring(err))
        end
    end
    
    -- 切换到场景状态
    EventBridge.getInstance():switchState(getStateId("GAME_SMAP"))
end

-- 载入游戏
function JYMainAdapter.loadGame()
    Cls()
    local loadMenu = {
        {"进度一", nil, 1},
        {"进度二", nil, 1},
        {"进度三", nil, 1}
    }
    
    local menux2 = (CC.ScreenW - 3 * CC.StartMenuFontSize - 2 * CC.MenuBorderPixel) / 2
    
    local r = MenuAsync.ShowMenuCoroutine(loadMenu, 3, 0, menux2, CC.StartMenuY, 0, 0, 0, 0, CC.StartMenuFontSize, C_STARTMENU, C_RED)
    
    Cls()
    DrawString(menux2, CC.StartMenuY, "请稍候...", C_RED, CC.StartMenuFontSize)
    ShowScreen()
    
    LoadRecord(r)
    
    Cls()
    ShowScreen()
    
    -- 切换到首次主地图状态
    EventBridge.getInstance():switchState(getStateId("GAME_FIRSTMMAP"))
end

-- 更新函数（每帧调用）
function JYMainAdapter.update(dt)
    if not isInitialized then
        return
    end
    
    -- 更新节拍计数器
    JY.MyTick = JY.MyTick + 1
    JY.MyTick2 = JY.MyTick2 + 1
    
    if JY.MyTick == 20 then
        JY.MyCurrentPic = 0
        JY.MyTick = 0
    end
    
    if JY.MyTick2 == 1000 then
        JY.MyTick2 = 0
    end
    
    collectgarbage("step", 0)
end

-- 渲染函数（每帧调用）
function JYMainAdapter.draw()
    -- 渲染由状态机的draw处理
end

-- 重置适配器
function JYMainAdapter.reset()
    isInitialized = false
    initCoroutine = nil
end

return JYMainAdapter
