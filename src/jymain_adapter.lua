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

-- 开始新游戏
function JYMainAdapter.startNewGame(menux)
    local scheduler = CoroutineScheduler.getInstance()
    
    Cls()
    DrawString(menux, CC.StartMenuY, "请稍候...", C_RED, CC.StartMenuFontSize)
    ShowScreen()
    
    NewGame()
    
    JY.SubScene = CC.NewGameSceneID
    JY.Scene[JY.SubScene]["名称"] = JY.Person[0]["姓名"] .. "居"
    JY.Base["人X1"] = CC.NewGameSceneX
    JY.Base["人Y1"] = CC.NewGameSceneY
    JY.MyPic = CC.NewPersonPic
    
    lib.ShowSlow(50, 1)
    
    JY.Status = getStateId("GAME_SMAP")
    JY.MMAPMusic = -1
    
    CleanMemory()
    
    Init_SMap(0)
    
    if CC.NewGameEvent > 0 then
        oldCallEvent(CC.NewGameEvent)
    end
    
    lib.LoadPicture("", 0, 0)
    
    -- 切换到场景状态
    EventBridge.getInstance():switchState(getStateId("GAME_SMAP"))
end

-- 载入游戏
function JYMainAdapter.loadGame()
    local scheduler = CoroutineScheduler.getInstance()
    
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
    
    JY.Status = getStateId("GAME_FIRSTMMAP")
    
    lib.LoadPicture("", 0, 0)
    
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
