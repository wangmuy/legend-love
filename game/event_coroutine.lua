-- event_coroutine.lua
-- 事件脚本协程执行器
-- 包装原有的阻塞式事件脚本为协程执行

local EventCoroutine = {}

-- 导入协程调度器
local CoroutineScheduler = require("coroutine_scheduler")

-- 当前执行的事件协程ID
local currentEventId = nil

-- 事件执行状态
local eventState = {
    idle = true,
    running = false,
    paused = false,
}

-- 包装instruct函数为协程版本
-- 将阻塞式的instruct调用改为yield/resume模式
function EventCoroutine.wrapInstructs()
    -- 保存原始函数
    local originalInstructs = {}
    
    -- 需要包装的instruct函数列表
    local instructsToWrap = {
        "instruct_0",   -- 清屏
        "instruct_1",   -- 对话
        "instruct_2",   -- 选择
        "instruct_3",   -- 修改事件
        "instruct_4",   -- 战斗
        "instruct_5",   -- 显示贴图
        "instruct_6",   -- 等待按键
        "instruct_7",   -- 显示数字
        "instruct_8",   -- 显示物品
        "instruct_9",   -- 显示人物
        "instruct_10",  -- 加入队员
        "instruct_11",  -- 是否住宿
        "instruct_12",  -- 住宿
        "instruct_13",  -- 场景变亮
        "instruct_14",  -- 场景变黑
        "instruct_15",  -- game over
        "instruct_16",  -- 队伍中是否有某人
        "instruct_17",  -- 修改场景图形
        "instruct_18",  -- 是否有某种物品
        "instruct_19",  -- 改变主角位置
    }
    
    -- 包装每个instruct函数
    for _, name in ipairs(instructsToWrap) do
        if _G[name] then
            originalInstructs[name] = _G[name]
            
            _G[name] = function(...)
                -- 调用原始函数
                local result = originalInstructs[name](...)
                
                -- 如果当前在协程中，yield让出控制权
                local scheduler = CoroutineScheduler.getInstance()
                if scheduler:getCurrentCoroutine() then
                    scheduler:yield("instruct_" .. name)
                end
                
                return result
            end
        end
    end
    
    return originalInstructs
end

-- 恢复原始instruct函数
function EventCoroutine.unwrapInstructs(originalInstructs)
    for name, fn in pairs(originalInstructs) do
        _G[name] = fn
    end
end

-- 执行事件脚本（协程版本）
-- @param eventFn: 事件函数（如oldevent_1）
-- @param callback: 事件完成后的回调
function EventCoroutine.execute(eventFn, callback)
    local scheduler = CoroutineScheduler.getInstance()
    
    -- 包装instruct函数
    local originalInstructs = EventCoroutine.wrapInstructs()
    
    -- 创建事件协程
    local eventId = scheduler:create(function()
        -- 设置事件状态
        eventState.idle = false
        eventState.running = true
        
        -- 执行事件函数
        local success, result = pcall(eventFn)
        
        -- 恢复原始函数
        EventCoroutine.unwrapInstructs(originalInstructs)
        
        -- 更新状态
        eventState.running = false
        eventState.idle = true
        currentEventId = nil
        
        -- 调用回调
        if callback then
            callback(success, result)
        end
        
        if not success then
            lib.Debug("Event execution error: " .. tostring(result))
        end
    end, "event_" .. tostring(eventFn))
    
    currentEventId = eventId
    
    -- 启动协程
    scheduler:start(eventId)
    
    return eventId
end

-- 暂停当前事件
function EventCoroutine.pause()
    eventState.paused = true
end

-- 恢复当前事件
function EventCoroutine.resume()
    eventState.paused = false
end

-- 停止当前事件
function EventCoroutine.stop()
    if currentEventId then
        local scheduler = CoroutineScheduler.getInstance()
        scheduler:kill(currentEventId)
        currentEventId = nil
        eventState.running = false
        eventState.idle = true
    end
end

-- 获取事件状态
function EventCoroutine.getState()
    return eventState
end

-- 检查是否有事件在运行
function EventCoroutine.isRunning()
    return eventState.running
end

-- 获取当前事件ID
function EventCoroutine.getCurrentEventId()
    return currentEventId
end

-- 等待事件完成（在协程中使用）
function EventCoroutine.waitForEvent(eventId)
    local scheduler = CoroutineScheduler.getInstance()
    
    while scheduler:getStatus(eventId) ~= "not_found" do
        scheduler:yield("wait_event")
    end
end

-- 创建异步版本的事件执行函数
-- 将阻塞式事件函数转换为返回协程的函数
function EventCoroutine.createAsync(eventFn)
    return function(callback)
        return EventCoroutine.execute(eventFn, callback)
    end
end

return EventCoroutine
