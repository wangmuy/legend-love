-- person_status_async.lua
-- 异步人物状态显示模块
-- 提供非阻塞版本的人物状态显示功能

local PersonStatusAsync = {}

-- 导入必要的模块
local CoroutineScheduler = require("coroutine_scheduler")

-- 当前显示的状态数据
local currentStatus = nil

-- 异步显示人物状态
-- teamid: 队伍位置（1-6）
-- 返回: 无（直接显示，ESC退出）
function PersonStatusAsync.ShowStatusCoroutine(teamid)
    if lib and lib.Debug then
        lib.Debug("PersonStatusAsync.ShowStatusCoroutine: started with teamid=" .. tostring(teamid))
    end
    
    -- 设置标志，阻止游戏主循环处理按键
    local InputManager = require("input_manager")
    InputManager.disableInput = true
    
    local page = 1
    local pagenum = 2
    local teamnum = GetTeamNum()
    local scheduler = CoroutineScheduler.getInstance()
    local InputAsync = require("input_async")
    
    if lib and lib.Debug then
        lib.Debug("PersonStatusAsync.ShowStatusCoroutine: modules loaded")
    end
    
    while true do
        local id = JY.Base["队伍" .. teamid]
        if lib and lib.Debug then
            lib.Debug("PersonStatusAsync.ShowStatusCoroutine: teamid=" .. tostring(teamid) .. ", id=" .. tostring(id))
        end
        
        if id >= 0 then
            -- 设置当前显示的状态数据
            currentStatus = {
                personId = id,
                page = page,
                teamid = teamid
            }
            if lib and lib.Debug then
                lib.Debug("PersonStatusAsync.ShowStatusCoroutine: set currentStatus, personId=" .. tostring(id))
            end
        end
        
        -- 异步等待按键
        if lib and lib.Debug then
            lib.Debug("PersonStatusAsync.ShowStatusCoroutine: waiting for key")
        end
        local keypress = InputAsync.WaitKeyCoroutine()
        if lib and lib.Debug then
            lib.Debug("PersonStatusAsync.ShowStatusCoroutine: key pressed=" .. tostring(keypress))
        end
        
        -- 清除状态显示
        currentStatus = nil
        
        if keypress == VK_ESCAPE then
            if lib and lib.Debug then
                lib.Debug("PersonStatusAsync.ShowStatusCoroutine: ESC pressed, exiting")
            end
            -- 清除标志，恢复游戏主循环按键处理
            local InputManager = require("input_manager")
            InputManager.disableInput = false
            break
        elseif keypress == VK_UP then
            teamid = teamid - 1
        elseif keypress == VK_DOWN then
            teamid = teamid + 1
        elseif keypress == VK_LEFT then
            page = page - 1
        elseif keypress == VK_RIGHT then
            page = page + 1
        end
        
        teamid = limitX(teamid, 1, teamnum)
        page = limitX(page, 1, pagenum)
        
        -- 小延迟防止按键过快
        scheduler:waitForTime(0.1)
    end
    
    if lib and lib.Debug then
        lib.Debug("PersonStatusAsync.ShowStatusCoroutine: ended")
    end
end

-- 绘制人物状态（在draw函数中调用）
function PersonStatusAsync.draw()
    if not currentStatus then
        return
    end
    
    if lib and lib.Debug then
        lib.Debug("PersonStatusAsync.draw: drawing status for personId=" .. tostring(currentStatus.personId))
    end
    
    local id = currentStatus.personId
    local page = currentStatus.page
    
    if id >= 0 then
        -- 调用原有的状态绘制函数
        ShowPersonStatus_sub(id, page)
    end
end

-- 模块导出
return PersonStatusAsync
