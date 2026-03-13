-- state_machine.lua
-- 游戏状态机管理模块
-- 用于管理游戏状态(GAME_MMAP, GAME_SMAP等)的注册、切换和生命周期
-- 支持子状态和数据传递

local StateMachine = {}
StateMachine.__index = StateMachine

-- 存储所有注册的状态处理器
local states = {}
local currentState = nil
local previousState = nil

-- 子状态栈
local subStateStack = {}

-- 状态数据存储
local stateData = {}

-- 状态机实例
local instance = nil

-- 获取状态机单例
function StateMachine.getInstance()
    if not instance then
        instance = setmetatable({}, StateMachine)
        instance:init()
    end
    return instance
end

-- 初始化状态机
function StateMachine:init()
    states = {}
    currentState = nil
    previousState = nil
    subStateStack = {}
    stateData = {}
end

-- 注册一个状态及其处理器
-- @param stateId: 状态ID (如 GAME_MMAP)
-- @param handlers: 包含update, draw, enter, exit函数的对象
function StateMachine:register(stateId, handlers)
    states[stateId] = {
        update = handlers.update or function(dt) end,
        draw = handlers.draw or function() end,
        enter = handlers.enter or function(prevState, data) end,
        exit = handlers.exit or function(nextState) end,
        -- 可选：子状态处理器
        subStates = handlers.subStates or {},
        -- 状态上下文数据
        context = {}
    }
end

-- 切换到指定状态
-- @param stateId: 目标状态ID
-- @param data: 传递给新状态的参数（可选）
-- @return: 是否切换成功
function StateMachine:switchTo(stateId, data)
    if not states[stateId] then
        error("State not registered: " .. tostring(stateId))
        return false
    end
    
    -- 退出当前状态
    if currentState and states[currentState] then
        states[currentState].exit(stateId)
        -- 保存当前状态数据
        stateData[currentState] = states[currentState].context
    end
    
    -- 记录状态历史
    previousState = currentState
    currentState = stateId
    
    -- 恢复或初始化状态数据
    if stateData[stateId] then
        states[stateId].context = stateData[stateId]
    else
        states[stateId].context = {}
    end
    
    -- 清空子状态栈
    subStateStack = {}
    
    -- 进入新状态
    states[currentState].enter(previousState, data)
    
    return true
end

-- 进入子状态
-- @param subStateId: 子状态ID
-- @param data: 传递给子状态的参数（可选）
function StateMachine:pushSubState(subStateId, data)
    if not currentState then
        error("No current state to push sub-state to")
        return false
    end
    
    local currentHandler = states[currentState]
    if not currentHandler.subStates[subStateId] then
        error("Sub-state not registered: " .. tostring(subStateId))
        return false
    end
    
    -- 暂停当前状态（如果有子状态）
    local currentSubState = subStateStack[#subStateStack]
    if currentSubState then
        local handler = currentHandler.subStates[currentSubState.id]
        if handler and handler.pause then
            handler.pause()
        end
    end
    
    -- 推入子状态栈
    table.insert(subStateStack, {
        id = subStateId,
        data = data,
        context = {}
    })
    
    -- 进入子状态
    local subHandler = currentHandler.subStates[subStateId]
    if subHandler and subHandler.enter then
        subHandler.enter(data)
    end
    
    return true
end

-- 退出子状态
-- @param result: 返回给父状态的结果（可选）
function StateMachine:popSubState(result)
    if #subStateStack == 0 then
        return false
    end
    
    local currentHandler = states[currentState]
    local subStateInfo = table.remove(subStateStack)
    
    -- 退出子状态
    local subHandler = currentHandler.subStates[subStateInfo.id]
    if subHandler and subHandler.exit then
        subHandler.exit(result)
    end
    
    -- 恢复上一个子状态
    local prevSubState = subStateStack[#subStateStack]
    if prevSubState then
        local prevHandler = currentHandler.subStates[prevSubState.id]
        if prevHandler and prevHandler.resume then
            prevHandler.resume()
        end
    end
    
    return true, subStateInfo
end

-- 获取当前子状态
-- @return: 当前子状态ID或nil
function StateMachine:getCurrentSubState()
    if #subStateStack == 0 then
        return nil
    end
    return subStateStack[#subStateStack].id
end

-- 更新当前状态
-- @param dt: delta time (秒)
function StateMachine:update(dt)
    -- 更新当前状态的子状态（如果有）
    if currentState and #subStateStack > 0 then
        local currentSubState = subStateStack[#subStateStack]
        local subHandler = states[currentState].subStates[currentSubState.id]
        if subHandler and subHandler.update then
            subHandler.update(dt, currentSubState.context)
        end
        return
    end
    
    -- 更新当前状态
    if currentState and states[currentState] then
        states[currentState].update(dt, states[currentState].context)
    end
end

-- 渲染当前状态
function StateMachine:draw()
    -- 先渲染当前状态
    if currentState and states[currentState] then
        states[currentState].draw(states[currentState].context)
        
        -- 再渲染子状态（如果有）
        if #subStateStack > 0 then
            local currentSubState = subStateStack[#subStateStack]
            local subHandler = states[currentState].subStates[currentSubState.id]
            if subHandler and subHandler.draw then
                subHandler.draw(currentSubState.context)
            end
        end
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

-- 获取状态上下文数据
-- @param stateId: 状态ID（可选，默认为当前状态）
-- @return: 状态上下文表
function StateMachine:getContext(stateId)
    stateId = stateId or currentState
    if stateId and states[stateId] then
        return states[stateId].context
    end
    return nil
end

-- 设置状态上下文数据
-- @param key: 数据键
-- @param value: 数据值
-- @param stateId: 状态ID（可选，默认为当前状态）
function StateMachine:setContext(key, value, stateId)
    stateId = stateId or currentState
    if stateId and states[stateId] then
        states[stateId].context[key] = value
    end
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
    subStateStack = {}
    stateData = {}
    instance = nil
end

return StateMachine
