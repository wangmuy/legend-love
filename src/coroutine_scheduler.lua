-- coroutine_scheduler.lua
-- 协程调度器模块
-- 管理所有协程的创建、调度和销毁

local CoroutineScheduler = {}
CoroutineScheduler.__index = CoroutineScheduler

-- 导入依赖模块
local InputManager = require("input_manager")

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
function CoroutineScheduler:init(deps)
    deps = deps or {}
    coroutines = {}
    currentCoroutine = nil
    coroutineIdCounter = 0
    -- 注入时间源，默认为 love.timer.getTime
    self.timeSource = deps.timeSource or (love and love.timer and love.timer.getTime)
end

-- 内部调试方法，便于测试时 mock
function CoroutineScheduler:_debug(msg)
    if lib and lib.Debug then
        lib.Debug(msg)
    end
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
    
    self:_debug("CoroutineScheduler.create: created coroutine id=" .. tostring(id) .. ", name=" .. tostring(name or "coroutine_" .. id))
    
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
    
    local previousCoroutine = currentCoroutine
    currentCoroutine = id
    local success, result = coroutine.resume(info.co, ...)
    currentCoroutine = previousCoroutine
    
    if not success then
        info.status = "error"
        info.error = result
        self:_debug("CoroutineScheduler.start: ERROR in coroutine " .. tostring(id) .. ": " .. tostring(result))
        -- 清理出错的协程，防止阻塞后续事件
        coroutines[id] = nil
        return false, result
    end
    
    local actualStatus = coroutine.status(info.co)
    self:_debug("CoroutineScheduler.start: info.status before=" .. tostring(info.status) .. ", coroutine.status=" .. tostring(actualStatus) .. ", result=" .. tostring(result))
    -- 修复：如果 coroutine.status 返回 "running"，将其视为 "suspended"
    -- 因为协程已经调用了 yield，只是 coroutine.status 返回了错误的状态
    if actualStatus == "running" then
        info.status = "suspended"
    else
        info.status = actualStatus
    end
    if info.status == "dead" then
        info.result = result
        info.status = "completed"
        self:_debug("CoroutineScheduler.start: coroutine " .. tostring(id) .. " completed with result=" .. tostring(result))
        -- 不立即清理，让调用者可以获取结果
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
    
    self:_debug("CoroutineScheduler.yield: currentCoroutine=" .. tostring(currentCoroutine) .. ", waitingFor=" .. tostring(waitingFor))
    
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

-- 等待时间（事件驱动版本）
-- @param seconds: 等待的秒数
-- 注意：这个版本只yield一次，让出时间给love.draw，然后由外部控制是否继续等待
function CoroutineScheduler:waitForTime(seconds)
    -- 记录开始时间
    local startTime = self.timeSource and self.timeSource() or 0
    
    -- yield一次，让love.draw有机会执行
    self:yield("time")
    
    -- 检查是否已经过了足够的时间
    -- 如果没有，继续yield（但这样会导致阻塞）
    -- 在事件驱动架构中，应该由调用方控制帧率
    -- 这里我们只yield一次，假设调用方会在合适的时间再次调用
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
    self:_debug("CoroutineScheduler.update called, coroutines count=" .. tostring(#coroutines))
    
    local activeCoroutines = {}
    local keyWaitingCoroutines = {}
    
    -- 收集所有需要更新的协程
    for id, info in pairs(coroutines) do
        self:_debug("CoroutineScheduler.update: checking coroutine id=" .. tostring(id) .. ", status=" .. tostring(info.status) .. ", waitingFor=" .. tostring(info.waitingFor) .. ", name=" .. tostring(info.name))
        if info.status == "suspended" then
            if info.waitingFor == "key" then
                -- 等待按键的协程单独处理
                table.insert(keyWaitingCoroutines, id)
            else
                table.insert(activeCoroutines, id)
            end
        end
    end
    
    self:_debug("CoroutineScheduler.update: active coroutines=" .. tostring(#activeCoroutines) .. ", key waiting=" .. tostring(#keyWaitingCoroutines))
    
    -- 检查是否有按键按下
    local keyPressed = false
    local pressedKey = -1
    if #keyWaitingCoroutines > 0 then
        -- 使用内部方法绕过 disableInput 标志
        local im = InputManager.getInstance()
        pressedKey = im:_peekKeyInternal()
        if pressedKey ~= -1 then
            im:_getKeyInternal()
            keyPressed = true
            self:_debug("CoroutineScheduler.update: key pressed=" .. tostring(pressedKey))
        end
        self:_debug("CoroutineScheduler.update: checking key, pressedKey=" .. tostring(pressedKey) .. ", keyWaitingCoroutines=" .. tostring(#keyWaitingCoroutines))
    end
    
    -- 恢复等待按键的协程（如果有按键按下）
    if keyPressed then
        for _, id in ipairs(keyWaitingCoroutines) do
            local info = coroutines[id]
            if info and info.status == "suspended" and info.waitingFor == "key" then
                self:_debug("CoroutineScheduler.update: resuming key-waiting coroutine id=" .. tostring(id) .. " with key=" .. tostring(pressedKey))
                self:resume(id, pressedKey)  -- 传递按键值给协程
            end
        end
    end
    
    -- 恢复其他挂起的协程
    for _, id in ipairs(activeCoroutines) do
        local info = coroutines[id]
        if info and info.status == "suspended" then
            self:_debug("CoroutineScheduler.update: resuming coroutine id=" .. tostring(id))
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

-- 检查协程是否活跃
-- @param id: 协程ID
-- @return: true 如果协程正在运行或挂起
function CoroutineScheduler:isActive(id)
    local info = coroutines[id]
    return info ~= nil and (info.status == "suspended" or info.status == "running")
end

-- 获取协程的结果
-- @param id: 协程ID
-- @return: 协程的结果，如果协程未完成或不存在则返回nil
function CoroutineScheduler:getResult(id)
    local info = coroutines[id]
    if not info then
        return nil
    end
    return info.result
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
