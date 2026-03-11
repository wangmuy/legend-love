-- game_states.lua
-- 游戏状态处理器定义
-- 将原有的Game_MMap和Game_SMap拆分为update和draw

local GameStates = {}

-- 导入必要的模块
local EventBridge = require("event_bridge")

-- 游戏状态处理器表
local handlers = {}

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
    end
    return nil
end

-- GAME_MMAP 状态处理器
handlers["GAME_MMAP"] = {
    -- 状态进入时调用
    enter = function()
        lib.Debug("Enter GAME_MMAP state")
        -- 初始化主地图(如果不是从其他状态切换过来)
        if JY.oldMMapX == -1 then
            Init_MMap()
        end
    end,
    
    -- 状态退出时调用
    exit = function()
        lib.Debug("Exit GAME_MMAP state")
    end,
    
    -- 每帧更新逻辑
    update = function(dt)
        -- 原有的Game_MMap逻辑(除去渲染部分)
        local direct = -1
        local keypress = lib.GetKey()
        
        if keypress ~= -1 then
            JY.MyTick = 0
            if keypress == VK_ESCAPE then
                MMenu()
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
            CleanMemory()
            lib.UnloadMMap()
            lib.PicInit()
            lib.ShowSlow(50, 1)
            
            JY.Status = getStateId("GAME_SMAP")
            JY.MMAPMusic = -1
            
            JY.MyPic = GetMyPic()
            JY.Base["人X1"] = JY.Scene[JY.SubScene]["入口X"]
            JY.Base["人Y1"] = JY.Scene[JY.SubScene]["入口Y"]
            
            Init_SMap(1)
        end
    end,
    
    -- 每帧渲染
    draw = function()
        local pic = GetMyPic()
        
        if CONFIG.FastShowScreen == 1 then
            if JY.oldMMapX == JY.Base["人X"] and JY.oldMMapY == JY.Base["人Y"] then
                if JY.oldMMapPic >= 0 and JY.oldMMapPic ~= pic then
                    local rr = ClipRect(Cal_PicClip(0, 0, JY.oldMMapPic, 0, 0, 0, pic, 0))
                    if rr ~= nil then
                        lib.SetClip(rr.x1, rr.y1, rr.x2, rr.y2)
                        lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)
                    end
                end
            else
                lib.SetClip(0, 0, CC.ScreenW, CC.ScreenH)
                lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)
            end
        else
            lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)
        end
        
        if CC.ShowXY == 1 then
            DrawString(10, CC.ScreenH - 20, string.format("%d %d", JY.Base["人X"], JY.Base["人Y"]), C_GOLD, 16)
        end
        
        ShowScreen(CONFIG.FastShowScreen)
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
    end,
    
    exit = function()
        lib.Debug("Exit GAME_SMAP state")
    end,
    
    update = function(dt)
        -- 处理路过事件
        local d_pass = GetS(JY.SubScene, JY.Base["人X1"], JY.Base["人Y1"], 3)
        if d_pass >= 0 then
            if d_pass ~= JY.OldDPass then
                EventExecute(d_pass, 3)
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
            
            if JY.MMAPMusic < 0 then
                JY.MMAPMusic = JY.Scene[JY.SubScene]["出门音乐"]
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
        
        if keypress ~= -1 then
            JY.MyTick = 0
            if keypress == VK_ESCAPE then
                MMenu()
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
                if JY.Base["人方向"] >= 0 then
                    local d_num = GetS(JY.SubScene, JY.Base["人X1"] + CC.DirectX[JY.Base["人方向"] + 1], JY.Base["人Y1"] + CC.DirectY[JY.Base["人方向"] + 1], 3)
                    if d_num >= 0 then
                        EventExecute(d_num, 1)
                        JY.oldSMapX = -1
                        JY.oldSMapY = -1
                        JY.D_Valid = nil
                    end
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
        
        JY.MyPic = GetMyPic()
        DtoSMap()
        
        if SceneCanPass(x, y) == true then
            JY.Base["人X1"] = x
            JY.Base["人Y1"] = y
        end
        
        JY.Base["人X1"] = limitX(JY.Base["人X1"], 1, CC.SWidth - 2)
        JY.Base["人Y1"] = limitX(JY.Base["人Y1"], 1, CC.SHeight - 2)
    end,
    
    draw = function()
        DrawSMap(CONFIG.FastShowScreen)
        
        if CC.ShowXY == 1 then
            DrawString(10, CC.ScreenH - 20, string.format("%s %d %d", JY.Scene[JY.SubScene]["名称"], JY.Base["人X1"], JY.Base["人Y1"]), C_GOLD, 16)
        end
        
        ShowScreen(CONFIG.FastShowScreen)
        lib.SetClip(0, 0, 0, 0)
    end
}

-- GAME_FIRSTMMAP 状态处理器(首次进入主地图)
handlers["GAME_FIRSTMMAP"] = {
    enter = function()
        lib.Debug("Enter GAME_FIRSTMMAP state")
        CleanMemory()
        lib.ShowSlow(50, 1)
        JY.MmapMusic = 16
        JY.Status = getStateId("GAME_MMAP")
        
        Init_MMap()
        
        lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], GetMyPic())
        lib.ShowSlow(50, 0)
    end,
    
    exit = function()
        lib.Debug("Exit GAME_FIRSTMMAP state")
    end,
    
    update = function(dt)
        -- 首次进入后直接切换到GAME_MMAP
        EventBridge.getInstance():switchState(getStateId("GAME_MMAP"))
    end,
    
    draw = function()
        -- 渲染已在enter中完成
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
