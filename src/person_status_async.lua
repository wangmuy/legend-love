-- person_status_async.lua
-- 异步人物状态显示模块
-- 提供非阻塞版本的人物状态显示功能

local PersonStatusAsync = {}

-- 当前显示的状态数据
local currentStatus = nil

-- 异步显示人物状态
-- teamid: 队伍位置（1-6）
-- 返回: 无（直接显示，ESC退出）
function PersonStatusAsync.ShowStatusCoroutine(teamid)
    local page = 1
    local pagenum = 2
    local teamnum = GetTeamNum()
    local scheduler = CoroutineScheduler.getInstance()
    local InputAsync = require("input_async")
    
    while true do
        local id = JY.Base["队伍" .. teamid]
        if id >= 0 then
            -- 设置当前显示的状态数据
            currentStatus = {
                personId = id,
                page = page,
                teamid = teamid
            }
        end
        
        -- 异步等待按键
        local keypress = InputAsync.WaitKeyCoroutine()
        
        -- 清除状态显示
        currentStatus = nil
        
        if keypress == VK_ESCAPE then
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
end

-- 绘制人物状态（在draw函数中调用）
function PersonStatusAsync.draw()
    if not currentStatus then
        return
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
