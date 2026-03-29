-- game_states.lua
-- 游戏状态处理器定义
-- 将原有的Game_MMap和Game_SMap拆分为update和draw

local GameStates = {}

-- 导入必要的模块
local EventBridge = require("event_bridge")
local EventExecutor = require("event_executor")
local JyMainAsync = require("jymain_async")
local CoroutineScheduler = require("coroutine_scheduler")
local MenuAsync = require("menu_async")

-- 游戏状态处理器表
local handlers = {}

-- 启动菜单协程的辅助函数
local function startMenuCoroutine()
    local scheduler = CoroutineScheduler.getInstance()
    local co = scheduler:create(function()
        lib.Debug("MMenuCoroutine: starting")
        JyMainAsync.MMenuCoroutine()
        lib.Debug("MMenuCoroutine: ended, calling MenuAsync.clear()")
        -- 菜单关闭后清理状态
        MenuAsync.clear()
        local InputManager = require("input_manager")
        lib.Debug("MMenuCoroutine: MenuAsync.clear() done, disableInput=" .. tostring(InputManager.disableInput))
    end, "main_menu")
    scheduler:start(co)
end

-- 获取状态ID的辅助函数
-- 在模块加载时，常量可能还未定义，所以使用函数延迟获取
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
    elseif stateName == "GAME_FIRSTSMAP" then
        return GAME_FIRSTSMAP or 3
    elseif stateName == "GAME_DEAD" then
        return GAME_DEAD or 6
    end
    return nil
end

-- GAME_MMAP 状态处理器
handlers["GAME_MMAP"] = {
    -- 状态进入时调用
    enter = function()
        lib.Debug("Enter GAME_MMAP state")
        -- 初始化主地图
        -- 注意：需要加载地图数据，否则会导致黑屏
        Init_MMap()
    end,
    
    -- 状态退出时调用
    exit = function()
        lib.Debug("Exit GAME_MMAP state")
        -- 清理大地图资源
        CleanMemory()
        lib.UnloadMMap()
        lib.PicInit()
        lib.ShowSlow(50, 1)
    end,
    
    -- 每帧更新逻辑
    update = function(dt)
        -- 如果有活动菜单，不处理游戏输入
        if MenuAsync.hasActiveMenu() then
            return
        end
        
        -- 原有的Game_MMap逻辑(除去渲染部分)
        local direct = -1
        local keypress = lib.GetKey()
        
        if keypress ~= -1 then
            JY.MyTick = 0
            if keypress == VK_ESCAPE then
                startMenuCoroutine()
                if JY.Status == getStateId("GAME_FIRSTMMAP") then
                    return
                end
                JY.oldMMapX = -1
                JY.oldMMapY = -1
            elseif keypress == VK_UP then
                direct = 0
            elseif keypress == VK_DOWN then
                direct = 3
            elseif keypress == VK_LEFT then
                direct = 2
            elseif keypress == VK_RIGHT then
                direct = 1
            end
        end
        
        local x, y
        if direct ~= -1 then
            AddMyCurrentPic()
            x = JY.Base["人X"] + CC.DirectX[direct + 1]
            y = JY.Base["人Y"] + CC.DirectY[direct + 1]
            JY.Base["人方向"] = direct
        else
            x = JY.Base["人X"]
            y = JY.Base["人Y"]
        end
        
        JY.SubScene = CanEnterScene(x, y)
        
        if lib.GetMMap(x, y, 3) == 0 and lib.GetMMap(x, y, 4) == 0 then
            JY.Base["人X"] = x
            JY.Base["人Y"] = y
        end
        
        JY.Base["人X"] = limitX(JY.Base["人X"], 10, CC.MWidth - 10)
        JY.Base["人Y"] = limitX(JY.Base["人Y"], 10, CC.MHeight - 10)
        
        if CC.MMapBoat[lib.GetMMap(JY.Base["人X"], JY.Base["人Y"], 0)] == 1 then
            JY.Base["乘船"] = 1
        else
            JY.Base["乘船"] = 0
        end
        
        -- 检查是否进入子场景
        if JY.SubScene >= 0 then
            lib.Debug("Entering subscene: " .. tostring(JY.SubScene))
            
            -- 先切换状态，让exit处理资源清理
            local newState = getStateId("GAME_SMAP")
            lib.Debug("Setting JY.Status to GAME_SMAP: " .. tostring(newState))
            JY.Status = newState
            JY.MmapMusic = -1
            
            JY.MyPic = GetMyPic()
            JY.Base["人X1"] = JY.Scene[JY.SubScene]["入口X"]
            JY.Base["人Y1"] = JY.Scene[JY.SubScene]["入口Y"]
            
            lib.Debug("Subscene transition completed")
        end
    end,
    
    -- 每帧渲染
    draw = function()
        local pic = GetMyPic()
        
        -- 在 Love2D 中，每一帧都需要重新绘制整个屏幕
        -- 原来的 FastShowScreen 优化在 SDL 中有效，但在 Love2D 中会导致黑屏
        -- 因此简化绘制逻辑，始终全屏重绘
        lib.SetClip(0, 0, CC.ScreenW, CC.ScreenH)
        lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)
        
        if CC.ShowXY == 1 then
            DrawString(10, CC.ScreenH - 20, string.format("%d %d", JY.Base["人X"], JY.Base["人Y"]), C_GOLD, 16)
        end
        
        -- 在 Love2D 中，love.draw() 结束时会自动调用 present()
        -- 不需要手动调用 ShowScreen，否则可能导致抖动
        -- ShowScreen(CONFIG.FastShowScreen)
        lib.SetClip(0, 0, 0, 0)
        
        JY.oldMMapX = JY.Base["人X"]
        JY.oldMMapY = JY.Base["人Y"]
        JY.oldMMapPic = pic
    end
}

-- GAME_SMAP 状态处理器
handlers["GAME_SMAP"] = {
    enter = function()
        lib.Debug("Enter GAME_SMAP state")
        -- 在enter中调用Init_SMap，确保状态已经切换
        Init_SMap(0)
    end,
    
    exit = function()
        lib.Debug("Exit GAME_SMAP state")
    end,
    
    update = function(dt)
        -- 如果有活动菜单，不处理游戏输入
        if MenuAsync.hasActiveMenu() then
            return
        end
        
        -- 检查是否正在播放动画，如果是则禁用输入
        local InputManager = require("input_manager")
        if JY.AnimationState.active then
            InputManager.disableInput = true
        else
            InputManager.disableInput = false
        end
        
        -- 处理动画（事件驱动架构）
        if JY.AnimationState.active then
            local anim = JY.AnimationState
            local now = lib.GetTime()
            local elapsed = now - anim.startTime
            local frameIndex = math.floor(elapsed / anim.frameDuration)
            local i = anim.startFrame + frameIndex * 2
            
            if i > anim.endFrame then
                -- 动画结束
                anim.active = false
                anim.currentFrame = 0  -- 重置为初始状态
            else
                -- 设置当前帧贴图
                if anim.id == -1 then
                    JY.MyPic = i / 2
                else
                    SetD(JY.SubScene, anim.id, 5, i)
                    SetD(JY.SubScene, anim.id, 6, i)
                    SetD(JY.SubScene, anim.id, 7, i)
                end
                DtoSMap()
            end
        end
        
        -- 处理路过事件
        local d_pass = GetS(JY.SubScene, JY.Base["人X1"], JY.Base["人Y1"], 3)
        if d_pass >= 0 then
            if d_pass ~= JY.OldDPass then
                EventExecuteSync(d_pass, 3)
                JY.OldDPass = d_pass
                JY.oldSMapX = -1
                JY.oldSMapY = -1
                JY.D_Valid = nil
            end
        else
            JY.OldDPass = -1
        end
        
        -- 检查是否退出到主地图
        local isout = 0
        if (JY.Scene[JY.SubScene]["出口X1"] == JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y1"] == JY.Base["人Y1"]) or
           (JY.Scene[JY.SubScene]["出口X2"] == JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y2"] == JY.Base["人Y1"]) or
           (JY.Scene[JY.SubScene]["出口X3"] == JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y3"] == JY.Base["人Y1"]) then
            isout = 1
        end
        
        if isout == 1 then
            JY.Status = getStateId("GAME_MMAP")
            lib.PicInit()
            CleanMemory()
            lib.ShowSlow(50, 1)
            
            if JY.MmapMusic < 0 then
                JY.MmapMusic = JY.Scene[JY.SubScene]["出门音乐"]
            end
            
            Init_MMap()
            
            JY.SubScene = -1
            JY.oldSMapX = -1
            JY.oldSMapY = -1
            
            lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], GetMyPic())
            lib.ShowSlow(50, 0)
            lib.GetKey()
            return
        end
        
        -- 检查场景跳转
        if JY.Scene[JY.SubScene]["跳转场景"] >= 0 then
            if JY.Base["人X1"] == JY.Scene[JY.SubScene]["跳转口X1"] and JY.Base["人Y1"] == JY.Scene[JY.SubScene]["跳转口Y1"] then
                JY.SubScene = JY.Scene[JY.SubScene]["跳转场景"]
                lib.ShowSlow(50, 1)
                
                if JY.Scene[JY.SubScene]["外景入口X1"] == 0 and JY.Scene[JY.SubScene]["外景入口Y1"] == 0 then
                    JY.Base["人X1"] = JY.Scene[JY.SubScene]["入口X"]
                    JY.Base["人Y1"] = JY.Scene[JY.SubScene]["入口Y"]
                else
                    JY.Base["人X1"] = JY.Scene[JY.SubScene]["跳转口X2"]
                    JY.Base["人Y1"] = JY.Scene[JY.SubScene]["跳转口Y2"]
                end
                
                Init_SMap(1)
                return
            end
        end
        
        -- 处理输入
        local x, y
        local keypress = lib.GetKey()
        local direct = -1
        
        -- 检查是否正在显示人物状态或物品选择，如果是则跳过按键处理
        -- 注意：现在统一通过 InputManager.disableInput 实现
        local InputManager = require("input_manager")
        if InputManager.disableInput then
            keypress = -1  -- 忽略按键
        end
        
        if keypress ~= -1 then
            JY.MyTick = 0
            if keypress == VK_ESCAPE then
                startMenuCoroutine()
                JY.oldSMapX = -1
                JY.oldSMapY = -1
            elseif keypress == VK_UP then
                direct = 0
            elseif keypress == VK_DOWN then
                direct = 3
            elseif keypress == VK_LEFT then
                direct = 2
            elseif keypress == VK_RIGHT then
                direct = 1
            elseif keypress == VK_SPACE or keypress == VK_RETURN then
                lib.Debug("GAME_SMAP.update: SPACE/RETURN pressed")
                if JY.Base["人方向"] >= 0 then
                    local targetX = JY.Base["人X1"] + CC.DirectX[JY.Base["人方向"] + 1]
                    local targetY = JY.Base["人Y1"] + CC.DirectY[JY.Base["人方向"] + 1]
                    local d_num = GetS(JY.SubScene, targetX, targetY, 3)
                    lib.Debug(string.format("GAME_SMAP.update: checking target (%d,%d), d_num=%d", targetX, targetY, d_num))
                    if d_num >= 0 then
                        lib.Debug(string.format("GAME_SMAP.update: executing event d_num=%d", d_num))
                        EventExecuteSync(d_num, 1)
                        JY.oldSMapX = -1
                        JY.oldSMapY = -1
                        JY.D_Valid = nil
                    else
                        lib.Debug("GAME_SMAP.update: no event at target position")
                    end
                else
                    lib.Debug("GAME_SMAP.update: no direction set")
                end
            end
        end
        
        if JY.Status ~= getStateId("GAME_SMAP") then
            return
        end
        
        if direct ~= -1 then
            AddMyCurrentPic()
            x = JY.Base["人X1"] + CC.DirectX[direct + 1]
            y = JY.Base["人Y1"] + CC.DirectY[direct + 1]
            JY.Base["人方向"] = direct
        else
            x = JY.Base["人X1"]
            y = JY.Base["人Y1"]
        end
        
        -- 更新主角贴图（根据方向和走路帧）
        -- 只有在动画播放期间才跳过更新
        if not JY.AnimationState.active then
            JY.MyPic = GetMyPic()
        end
        DtoSMap()
        
        if SceneCanPass(x, y) == true then
            JY.Base["人X1"] = x
            JY.Base["人Y1"] = y
        end
        
        JY.Base["人X1"] = limitX(JY.Base["人X1"], 1, CC.SWidth - 2)
        JY.Base["人Y1"] = limitX(JY.Base["人Y1"], 1, CC.SHeight - 2)
    end,
    
    draw = function()
        -- 在 Love2D 中，每一帧都需要重新绘制
        -- 禁用 FastShowScreen 优化以避免黑屏
        DrawSMap(0)
        
        if CC.ShowXY == 1 then
            DrawString(10, CC.ScreenH - 20, string.format("%s %d %d", JY.Scene[JY.SubScene]["名称"], JY.Base["人X1"], JY.Base["人Y1"]), C_GOLD, 16)
        end
        
        -- 在 Love2D 中，love.draw() 结束时会自动调用 present()
        -- ShowScreen(0)
        lib.SetClip(0, 0, 0, 0)
    end
}

-- GAME_START 状态处理器(开始菜单)
handlers["GAME_START"] = {
    enter = function()
        lib.Debug("Enter GAME_START state")
    end,
    
    exit = function()
        lib.Debug("Exit GAME_START state")
    end,
    
    update = function(dt)
        -- 开始菜单的更新逻辑在jymain_adapter中处理
    end,
    
    draw = function()
        -- 绘制开始界面背景
        if CC.FirstFile then
            lib.LoadPicture(CC.FirstFile, -1, -1)
        end
    end
}

-- GAME_FIRSTMMAP 状态处理器(首次进入主地图)
handlers["GAME_FIRSTMMAP"] = {
    enter = function()
        lib.Debug("Enter GAME_FIRSTMMAP state")
        CleanMemory()
        lib.ShowSlow(50, 1)
        JY.MmapMusic = 16
        
        Init_MMap()
        
        lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], GetMyPic())
        lib.ShowSlow(50, 0)
    end,
    
    exit = function()
        lib.Debug("Exit GAME_FIRSTMMAP state")
    end,
    
    update = function(dt)
        -- 首次进入后立即切换到主地图状态
        local newState = getStateId("GAME_MMAP")
        lib.Debug("GAME_FIRSTMMAP update: setting JY.Status=" .. tostring(newState))
        JY.Status = newState
    end,
    
    draw = function()
        -- 绘制主地图
        local pic = GetMyPic()
        lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)
        -- 在 Love2D 中，love.draw() 结束时会自动调用 present()
        -- ShowScreen(0)
    end
}

-- GAME_WMAP 状态处理器(战斗)
handlers["GAME_WMAP"] = {
    enter = function()
        lib.Debug("Enter GAME_WMAP state (battle)")
    end,
    
    exit = function()
        lib.Debug("Exit GAME_WMAP state (battle)")
        -- 清理战斗资源
        if WAR then
            WAR.Person = {}
            WAR.Data = {}
        end
    end,
    
    update = function(dt)
        -- 战斗逻辑在 WarMain 协程中处理
        -- 这里不需要额外处理
    end,
    
    draw = function()
        if JY.Status == GAME_WMAP and WAR and WAR.Person and WAR.CurID and WAR.Person[WAR.CurID] then
            lib.Debug(string.format("GAME_WMAP draw: DrawMode=%s, MoveCursorX=%s, MoveCursorY=%s", 
                tostring(WAR.DrawMode), tostring(WAR.MoveCursorX), tostring(WAR.MoveCursorY)))
            if WAR.DrawMode and WAR.MoveCursorX and WAR.MoveCursorY then
                if WAR.DrawMode == 1 then
                    WarDrawMap(1, WAR.MoveCursorX, WAR.MoveCursorY)
                elseif WAR.DrawMode == 2 then
                    WarDrawMap(2, WAR.MoveCursorX, WAR.MoveCursorY)
                elseif WAR.DrawMode == 3 then
                    WarDrawMap(1, WAR.MoveCursorX, WAR.MoveCursorY)
                else
                    WarDrawMap(0)
                end
            elseif WAR.DrawMode == 4 and WAR.AnimPic then
                WarDrawMap(4, WAR.AnimPic, WAR.AnimType or 0, WAR.AnimEffect or -1)
            elseif WAR.DrawMode == 2 then
                WarDrawMap(2)
            else
                WarDrawMap(0)
            end
        end
    end
}

-- GAME_END 状态处理器(游戏结束)
handlers["GAME_END"] = {
    enter = function()
        lib.Debug("Enter GAME_END state")
        -- 退出游戏
        love.event.quit()
    end,
    
    exit = function()
        lib.Debug("Exit GAME_END state")
    end,
    
    update = function(dt)
        -- 游戏结束状态不需要更新
    end,
    
    draw = function()
        -- 游戏结束状态不需要绘制
    end
}

-- 注册所有状态到状态机
function GameStates.registerAll()
    local eb = EventBridge.getInstance()
    
    -- 使用字符串键注册，然后在注册时转换为实际的状态ID
    for stateName, handler in pairs(handlers) do
        local stateId = getStateId(stateName)
        if stateId then
            eb:registerState(stateId, handler)
        end
    end
end

-- 获取处理器(用于测试)
function GameStates.getHandler(stateName)
    return handlers[stateName]
end

-- 获取状态ID
function GameStates.getStateId(stateName)
    return getStateId(stateName)
end

return GameStates
