-- input_manager.lua
-- 输入管理模块
-- 提供事件驱动的输入处理，替代阻塞式GetKey
-- 支持输入缓冲和按键重复

local InputManager = {}
InputManager.__index = InputManager

-- 事件队列（环形缓冲区）
local eventQueue = {}
local queueHead = 1
local queueTail = 1
local maxQueueSize = 32

-- 当前按键状态
local currentKey = -1
local keyStates = {}
local keyConsumed = false

-- 按键重复配置
local keyRepeatEnabled = false
local keyRepeatDelay = 0.5  -- 首次重复延迟（秒）
local keyRepeatInterval = 0.1  -- 重复间隔（秒）
local keyRepeatTimers = {}  -- 各按键的重复计时器

-- 按键映射表
local keyMap = {
    ["escape"] = 27,
    [" "] = 32,
    ["return"] = 13,
    ["up"] = 1073741906,
    ["down"] = 1073741905,
    ["left"] = 1073741904,
    ["right"] = 1073741903,
}

-- 单例实例
local instance = nil

-- 获取单例
function InputManager.getInstance()
    if not instance then
        instance = setmetatable({}, InputManager)
    end
    return instance
end

-- 初始化输入管理器
function InputManager:init()
    eventQueue = {}
    queueHead = 1
    queueTail = 1
    currentKey = -1
    keyStates = {}
    keyConsumed = false
    keyRepeatTimers = {}
end

-- 注册按键映射
function InputManager:registerKey(loveKey, gameKey)
    keyMap[loveKey] = gameKey
end

-- 添加事件到队列
local function enqueueEvent(event)
    local nextTail = queueTail + 1
    if nextTail > maxQueueSize then
        nextTail = 1
    end
    
    -- 检查队列是否已满
    if nextTail == queueHead then
        -- 队列满，丢弃最旧的事件
        queueHead = queueHead + 1
        if queueHead > maxQueueSize then
            queueHead = 1
        end
    end
    
    eventQueue[queueTail] = event
    queueTail = nextTail
end

-- 从队列取出事件
local function dequeueEvent()
    if queueHead == queueTail then
        return nil  -- 队列空
    end
    
    local event = eventQueue[queueHead]
    eventQueue[queueHead] = nil
    queueHead = queueHead + 1
    if queueHead > maxQueueSize then
        queueHead = 1
    end
    
    return event
end

-- 处理love.keypressed事件
function InputManager:onKeyPressed(key, scancode, isrepeat)
    local gameKey = keyMap[key]
    if gameKey then
        -- 添加到事件队列
        enqueueEvent({
            type = "pressed",
            key = gameKey,
            isRepeat = isrepeat,
            time = love.timer.getTime()
        })
        
        -- 更新按键状态
        currentKey = gameKey
        keyStates[gameKey] = true
        keyConsumed = false
        
        -- 初始化重复计时器
        if keyRepeatEnabled then
            keyRepeatTimers[gameKey] = {
                pressedTime = love.timer.getTime(),
                lastRepeatTime = love.timer.getTime(),
                repeatCount = 0
            }
        end
    end
end

-- 处理love.keyreleased事件
function InputManager:onKeyReleased(key, scancode)
    local gameKey = keyMap[key]
    if gameKey then
        -- 添加到事件队列
        enqueueEvent({
            type = "released",
            key = gameKey,
            time = love.timer.getTime()
        })
        
        -- 更新按键状态
        keyStates[gameKey] = false
        keyRepeatTimers[gameKey] = nil
        
        -- 如果释放的是当前按键，重置currentKey
        if currentKey == gameKey then
            currentKey = -1
        end
    end
end

-- 更新按键重复
-- @param dt: delta time
function InputManager:update(dt)
    if not keyRepeatEnabled then
        return
    end
    
    local currentTime = love.timer.getTime()
    
    for gameKey, timer in pairs(keyRepeatTimers) do
        if keyStates[gameKey] then
            local elapsed = currentTime - timer.pressedTime
            local timeSinceLastRepeat = currentTime - timer.lastRepeatTime
            
            -- 检查是否应该重复
            local shouldRepeat = false
            if timer.repeatCount == 0 then
                -- 首次重复
                shouldRepeat = elapsed >= keyRepeatDelay
            else
                -- 后续重复
                shouldRepeat = timeSinceLastRepeat >= keyRepeatInterval
            end
            
            if shouldRepeat then
                -- 添加重复事件到队列
                enqueueEvent({
                    type = "repeat",
                    key = gameKey,
                    isRepeat = true,
                    time = currentTime
                })
                
                timer.repeatCount = timer.repeatCount + 1
                timer.lastRepeatTime = currentTime
                
                -- 更新currentKey以允许重复按键被获取
                if currentKey == -1 then
                    currentKey = gameKey
                    keyConsumed = false
                end
            end
        end
    end
end

-- 获取当前按键
function InputManager:getKey()
    if keyConsumed then
        return -1
    end
    local key = currentKey
    if key ~= -1 then
        keyConsumed = true
        -- 不要在这里清空 currentKey，让 keyStates 和 keyReleased 来处理
        -- currentKey = -1
    end
    return key
end

-- 查看当前按键但不消费
function InputManager:peekKey()
    return currentKey
end

-- 重置消费状态
function InputManager:resetKeyConsumed()
    keyConsumed = false
end

-- 查询按键是否被按下
function InputManager:isKeyDown(gameKey)
    return keyStates[gameKey] == true
end

-- 获取并清空事件队列
function InputManager:pollEvents()
    local events = {}
    local event = dequeueEvent()
    while event do
        table.insert(events, event)
        event = dequeueEvent()
    end
    return events
end

-- 处理所有待处理的事件
function InputManager:processEvents()
    return self:pollEvents()
end

-- 设置按键重复
function InputManager:setKeyRepeat(enabled)
    keyRepeatEnabled = enabled
    if love.keyboard then
        love.keyboard.setKeyRepeat(enabled)
    end
end

-- 设置按键重复参数
function InputManager:setKeyRepeatParams(delay, interval)
    keyRepeatDelay = delay or 0.5
    keyRepeatInterval = interval or 0.1
end

-- 是否启用了按键重复
function InputManager:isKeyRepeatEnabled()
    return keyRepeatEnabled
end

-- 清空所有按键状态
function InputManager:clear()
    eventQueue = {}
    queueHead = 1
    queueTail = 1
    currentKey = -1
    keyStates = {}
    keyRepeatTimers = {}
end

-- 重置输入管理器
function InputManager:reset()
    self:clear()
    keyMap = {
        ["escape"] = 27,
        [" "] = 32,
        ["return"] = 13,
        ["up"] = 1073741906,
        ["down"] = 1073741905,
        ["left"] = 1073741904,
        ["right"] = 1073741903,
    }
    instance = nil
end

-- 获取按键映射表
function InputManager:getKeyMap()
    return keyMap
end

-- 获取队列大小
function InputManager:getQueueSize()
    if queueTail >= queueHead then
        return queueTail - queueHead
    else
        return maxQueueSize - queueHead + queueTail
    end
end

return InputManager
