-- coroutine_scheduler.lua
-- 协程调度器模块
-- 管理所有协程的创建、调度和销毁

local CoroutineScheduler = {}
CoroutineScheduler.__index = CoroutineScheduler

-- 协程列表
local coroutines = {}
local currentCoroutine = nil
local coroutineIdCounter = 0

-- 单例实例
local instance = nil

-- 获取单例
function CoroutineScheduler.getInstance()
    if not instance then
        instance = setmetatable({}, CoroutineScheduler)
    end
    return instance
end

-- 初始化调度器
function CoroutineScheduler:init()
    coroutines = {}
    currentCoroutine = nil
    coroutineIdCounter = 0
end

-- 创建新协程
-- @param fn: 协程执行的函数
-- @param name: 协程名称（可选，用于调试）
-- @return: 协程ID
function CoroutineScheduler:create(fn, name)
    coroutineIdCounter = coroutineIdCounter + 1
    local id = coroutineIdCounter
    
    local co = coroutine.create(fn)
    coroutines[id] = {
        co = co,
        name = name or "coroutine_" .. id,
        status = "suspended",
        waitingFor = nil,  -- 等待的条件（如按键、时间等）
        result = nil,      -- 协程返回值
        error = nil        -- 错误信息
    }
    
    return id
end

-- 启动协程
-- @param id: 协程ID
-- @param ...: 传递给协程的参数
-- @return: 成功返回true，失败返回false和错误信息
function CoroutineScheduler:start(id, ...)
    local info = coroutines[id]
    if not info then
        return false, "Coroutine not found: " .. tostring(id)
    end
    
    if info.status ~= "suspended" then
        return false, "Coroutine is not suspended: " .. info.status
    end
    
    currentCoroutine = id
    local success, result = coroutine.resume(info.co, ...)
    currentCoroutine = nil
    
    if not success then
        info.status = "error"
        info.error = result
        return false, result
    end
    
    local actualStatus = coroutine.status(info.co)
    if lib and lib.Debug then
        lib.Debug("CoroutineScheduler.start: info.status before=" .. tostring(info.status) .. ", coroutine.status=" .. tostring(actualStatus) .. ", result=" .. tostring(result))
    end
    info.status = actualStatus
    if info.status == "dead" then
        info.result = result
        coroutines[id] = nil  -- 清理已完成的协程
        if lib and lib.Debug then
            lib.Debug("CoroutineScheduler.start: coroutine " .. tostring(id) .. " cleaned up")
        end
    end
    
    return true, result
end

-- 恢复协程
-- @param id: 协程ID
-- @param ...: 传递给协程的参数
-- @return: 成功返回true，失败返回false和错误信息
function CoroutineScheduler:resume(id, ...)
    return self:start(id, ...)
end

-- 挂起当前协程
-- @param waitingFor: 等待的条件描述（可选）
-- @return: 挂起时返回的值
function CoroutineScheduler:yield(waitingFor)
    if not currentCoroutine then
        error("Cannot yield from outside a coroutine")
    end
    
    if lib and lib.Debug then
        lib.Debug("CoroutineScheduler.yield: currentCoroutine=" .. tostring(currentCoroutine) .. ", waitingFor=" .. tostring(waitingFor))
    end
    
    local info = coroutines[currentCoroutine]
    if info then
        info.status = "suspended"
        info.waitingFor = waitingFor
    end
    
    return coroutine.yield(waitingFor)
end

-- 等待按键
-- @return: 按下的按键值
function CoroutineScheduler:waitForKey()
    return self:yield("key")
end

-- 等待时间
-- @param seconds: 等待的秒数
function CoroutineScheduler:waitForTime(seconds)
    local startTime = love.timer.getTime()
    while love.timer.getTime() - startTime < seconds do
        self:yield("time")
    end
end

-- 等待条件
-- @param conditionFn: 条件函数，返回true时结束等待
function CoroutineScheduler:waitForCondition(conditionFn)
    while not conditionFn() do
        self:yield("condition")
    end
end

-- 更新所有协程
-- @param dt: delta time
function CoroutineScheduler:update(dt)
    if lib and lib.Debug then
        lib.Debug("CoroutineScheduler.update called, coroutines count=" .. tostring(#coroutines))
    end
    
    local activeCoroutines = {}
    local keyWaitingCoroutines = {}
    
    -- 收集所有需要更新的协程
    for id, info in pairs(coroutines) do
        if info.status == "suspended" then
            if info.waitingFor == "key" then
                -- 等待按键的协程单独处理
                table.insert(keyWaitingCoroutines, id)
            else
                table.insert(activeCoroutines, id)
            end
        end
    end
    
    if lib and lib.Debug then
        lib.Debug("CoroutineScheduler.update: active coroutines=" .. tostring(#activeCoroutines) .. ", key waiting=" .. tostring(#keyWaitingCoroutines))
    end
    
    -- 检查是否有按键按下
    local keyPressed = false
    local pressedKey = -1
    if #keyWaitingCoroutines > 0 then
        pressedKey = lib.GetKey()
        if pressedKey ~= -1 then
            keyPressed = true
            if lib and lib.Debug then
                lib.Debug("CoroutineScheduler.update: key pressed=" .. tostring(pressedKey))
            end
        end
    end
    
    -- 恢复等待按键的协程（如果有按键按下）
    if keyPressed then
        for _, id in ipairs(keyWaitingCoroutines) do
            local info = coroutines[id]
            if info and info.status == "suspended" and info.waitingFor == "key" then
                if lib and lib.Debug then
                    lib.Debug("CoroutineScheduler.update: resuming key-waiting coroutine id=" .. tostring(id) .. " with key=" .. tostring(pressedKey))
                end
                self:resume(id, pressedKey)  -- 传递按键值给协程
            end
        end
    end
    
    -- 恢复其他挂起的协程
    for _, id in ipairs(activeCoroutines) do
        local info = coroutines[id]
        if info and info.status == "suspended" then
            if lib and lib.Debug then
                lib.Debug("CoroutineScheduler.update: resuming coroutine id=" .. tostring(id))
            end
            self:resume(id)
        end
    end
end

-- 获取协程状态
-- @param id: 协程ID
-- @return: 状态字符串
function CoroutineScheduler:getStatus(id)
    local info = coroutines[id]
    if not info then
        return "not_found"
    end
    return info.status
end

-- 获取当前运行的协程ID
-- @return: 当前协程ID或nil
function CoroutineScheduler:getCurrentCoroutine()
    return currentCoroutine
end

-- 获取协程信息
-- @param id: 协程ID
-- @return: 协程信息表
function CoroutineScheduler:getInfo(id)
    return coroutines[id]
end

-- 获取所有协程列表
-- @return: 协程ID列表
function CoroutineScheduler:getAllCoroutines()
    local list = {}
    for id, _ in pairs(coroutines) do
        table.insert(list, id)
    end
    return list
end

-- 终止协程
-- @param id: 协程ID
function CoroutineScheduler:kill(id)
    coroutines[id] = nil
end

-- 清理所有协程
function CoroutineScheduler:clear()
    coroutines = {}
    currentCoroutine = nil
end

-- 重置调度器
function CoroutineScheduler:reset()
    self:clear()
    coroutineIdCounter = 0
    instance = nil
end

-- 包装函数为协程
-- @param fn: 要包装的函数
-- @return: 返回一个可以启动协程的函数
function CoroutineScheduler:wrap(fn)
    return function(...)
        local id = self:create(fn)
        return self:start(id, ...)
    end
end

return CoroutineScheduler
