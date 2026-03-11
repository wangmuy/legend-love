-- state_machine.lua
-- 游戏状态机管理模块
-- 用于管理游戏状态(GAME_MMAP, GAME_SMAP等)的注册、切换和生命周期

local StateMachine = {}
StateMachine.__index = StateMachine

-- 存储所有注册的状态处理器
local states = {}
local currentState = nil
local previousState = nil

-- 状态机实例
local instance = nil

-- 获取状态机单例
function StateMachine.getInstance()
    if not instance then
        instance = setmetatable({}, StateMachine)
    end
    return instance
end

-- 注册一个状态及其处理器
-- @param stateId: 状态ID (如 GAME_MMAP)
-- @param handlers: 包含update, draw, enter, exit函数的对象
function StateMachine:register(stateId, handlers)
    states[stateId] = {
        update = handlers.update or function() end,
        draw = handlers.draw or function() end,
        enter = handlers.enter or function() end,
        exit = handlers.exit or function() end
    }
end

-- 切换到指定状态
-- @param stateId: 目标状态ID
function StateMachine:switchTo(stateId)
    if not states[stateId] then
        error("State not registered: " .. tostring(stateId))
        return
    end
    
    -- 退出当前状态
    if currentState and states[currentState] then
        states[currentState].exit()
    end
    
    -- 记录状态历史
    previousState = currentState
    currentState = stateId
    
    -- 进入新状态
    states[currentState].enter()
end

-- 更新当前状态
-- @param dt: delta time (秒)
function StateMachine:update(dt)
    if currentState and states[currentState] then
        states[currentState].update(dt)
    end
end

-- 渲染当前状态
function StateMachine:draw()
    if currentState and states[currentState] then
        states[currentState].draw()
    end
end

-- 获取当前状态ID
function StateMachine:getCurrentState()
    return currentState
end

-- 获取上一个状态ID
function StateMachine:getPreviousState()
    return previousState
end

-- 检查状态是否已注册
function StateMachine:isRegistered(stateId)
    return states[stateId] ~= nil
end

-- 获取所有已注册的状态列表
function StateMachine:getRegisteredStates()
    local list = {}
    for stateId, _ in pairs(states) do
        table.insert(list, stateId)
    end
    return list
end

-- 重置状态机(用于测试)
function StateMachine:reset()
    states = {}
    currentState = nil
    previousState = nil
    instance = nil
end

return StateMachine
