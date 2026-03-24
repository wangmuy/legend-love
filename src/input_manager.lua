-- input_manager.lua
-- 输入管理模块
-- 提供事件驱动的输入处理，替代阻塞式GetKey
-- 纯事件驱动架构：按键事件进入队列，getKey从队列消费

local InputManager = {}
InputManager.__index = InputManager

-- 事件队列（环形缓冲区）
local eventQueue = {}
local queueHead = 1
local queueTail = 1
local maxQueueSize = 64

-- 按键状态（用于判断是否按住）
local keyStates = {}

-- 输入禁用标志
InputManager.disableInput = false

-- 按键重复配置
local keyRepeatEnabled = false
local keyRepeatDelay = 0.3   -- 首次重复延迟（秒）
local keyRepeatInterval = 0.04  -- 重复间隔（秒）
local keyRepeatTimers = {}

-- 按键映射表
local baseKeyMap = {
    ["escape"] = 27,
    [" "] = 32,
    ["space"] = 32,
    ["return"] = 13,
    ["up"] = 1073741906,
    ["down"] = 1073741905,
    ["left"] = 1073741904,
    ["right"] = 1073741903,
}

local function initKeyMap()
    local km = {}
    for k, v in pairs(baseKeyMap) do
        km[k] = v
    end
    if VK_Y then km["y"] = VK_Y end
    if VK_N then km["n"] = VK_N end
    return km
end

local instance = nil

function InputManager.getInstance()
    if not instance then
        instance = setmetatable({}, InputManager)
    end
    return instance
end

function InputManager:init()
    eventQueue = {}
    queueHead = 1
    queueTail = 1
    keyStates = {}
    keyRepeatTimers = {}
end

-- 添加事件到队列
local function enqueueEvent(event)
    local info = debug.getinfo(2, "nSl")
    lib.Debug(string.format("enqueueEvent: key=%d, queueHead=%d, queueTail=%d, caller=%s:%d", 
        event.key, queueHead, queueTail, tostring(info.short_src), info.currentline))
    local nextTail = queueTail + 1
    if nextTail > maxQueueSize then
        nextTail = 1
    end
    
    if nextTail == queueHead then
        queueHead = queueHead + 1
        if queueHead > maxQueueSize then
            queueHead = 1
        end
    end
    
    eventQueue[queueTail] = event
    queueTail = nextTail
    lib.Debug(string.format("enqueueEvent: done, new queueTail=%d", queueTail))
end

-- 从队列取出事件
local function dequeueEvent()
    if queueHead == queueTail then
        return nil
    end
    
    local event = eventQueue[queueHead]
    eventQueue[queueHead] = nil
    local oldHead = queueHead
    queueHead = queueHead + 1
    if queueHead > maxQueueSize then
        queueHead = 1
    end
    
    lib.Debug(string.format("dequeueEvent: key=%d, oldHead=%d, new queueHead=%d, queueTail=%d", event.key, oldHead, queueHead, queueTail))
    return event
end

-- 查看队列头部事件但不移除
local function peekEvent()
    if queueHead == queueTail then
        return nil
    end
    return eventQueue[queueHead]
end

-- 处理love.keypressed事件
function InputManager:onKeyPressed(key, scancode, isrepeat)
    local km = initKeyMap()
    local gameKey = km[key]
    
    if not gameKey then
        return
    end
    
    -- 忽略 love.keyboard 的 repeat 事件，使用自己的定时器
    if isrepeat then
        return
    end
    
    lib.Debug(string.format("InputManager:onKeyPressed: key=%s, gameKey=%d", key, gameKey))
    
    -- 添加按键按下事件到队列
    enqueueEvent({
        type = "pressed",
        key = gameKey,
        time = love.timer.getTime()
    })
    
    -- 更新按键状态
    keyStates[gameKey] = true
    
    -- 初始化重复计时器
    if keyRepeatEnabled then
        keyRepeatTimers[gameKey] = {
            pressedTime = love.timer.getTime(),
            lastRepeatTime = love.timer.getTime(),
            repeatCount = 0
        }
    end
end

-- 处理love.keyreleased事件
function InputManager:onKeyReleased(key, scancode)
    local km = initKeyMap()
    local gameKey = km[key]
    
    if not gameKey then
        return
    end
    
    -- 不在队列中添加释放事件，因为游戏不需要处理释放事件
    -- 只有按下和重复事件才需要处理
    
    -- 更新按键状态
    keyStates[gameKey] = false
    keyRepeatTimers[gameKey] = nil
end

-- 更新按键重复
function InputManager:update(dt)
    if not keyRepeatEnabled then
        return
    end
    
    local currentTime = love.timer.getTime()
    
    for gameKey, timer in pairs(keyRepeatTimers) do
        if keyStates[gameKey] then
            local elapsed = currentTime - timer.pressedTime
            local timeSinceLastRepeat = currentTime - timer.lastRepeatTime
            
            local shouldRepeat = false
            if timer.repeatCount == 0 then
                shouldRepeat = elapsed >= keyRepeatDelay
            else
                shouldRepeat = timeSinceLastRepeat >= keyRepeatInterval
            end
            
            if shouldRepeat then
                lib.Debug(string.format("InputManager:update: generating repeat event for key=%d", gameKey))
                -- 添加重复事件到队列
                enqueueEvent({
                    type = "repeat",
                    key = gameKey,
                    time = currentTime
                })
                
                timer.repeatCount = timer.repeatCount + 1
                timer.lastRepeatTime = currentTime
            end
        end
    end
end

-- 获取当前按键（消费队列中的事件）
function InputManager:getKey()
    if InputManager.disableInput then
        return -1
    end
    
    -- 从队列中获取事件
    local event = dequeueEvent()
    if event then
        lib.Debug(string.format("InputManager:getKey: returning key=%d", event.key))
        return event.key
    end
    
    return -1
end

-- 查看队列中的下一个按键但不消费
function InputManager:peekKey()
    if InputManager.disableInput then
        return -1
    end
    
    local event = peekEvent()
    if event then
        return event.key
    end
    
    return -1
end

-- 清除当前按键状态和队列
function InputManager:clearCurrentKey()
    eventQueue = {}
    queueHead = 1
    queueTail = 1
    keyStates = {}
    keyRepeatTimers = {}
end

-- 查询按键是否被按住
function InputManager:isKeyDown(gameKey)
    return keyStates[gameKey] == true
end

-- 处理所有待处理的事件（兼容接口）
function InputManager:processEvents()
    -- 在事件驱动架构中，事件已经在队列中
    -- 此方法不需要做任何事情
end

-- 设置按键重复
function InputManager:setKeyRepeat(enabled)
    lib.Debug(string.format("InputManager:setKeyRepeat: enabled=%s", tostring(enabled)))
    keyRepeatEnabled = enabled
    -- 不使用 love.keyboard 的重复，使用我们自己的定时器机制
end

-- 设置按键重复参数（毫秒）
function InputManager:setKeyRepeatParams(delay, interval)
    keyRepeatDelay = delay or 0.3
    keyRepeatInterval = interval or 0.04
end

-- 清空所有状态
function InputManager:clear()
    eventQueue = {}
    queueHead = 1
    queueTail = 1
    keyStates = {}
    keyRepeatTimers = {}
end

-- 重置
function InputManager:reset()
    self:clear()
    instance = nil
end

function InputManager:getQueueSize()
    if queueTail >= queueHead then
        return queueTail - queueHead
    else
        return maxQueueSize - queueHead + queueTail
    end
end

return InputManager