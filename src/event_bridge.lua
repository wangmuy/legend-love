-- event_bridge.lua
-- 事件桥接模块
-- 连接新旧架构，提供向后兼容的API

local EventBridge = {}
EventBridge.__index = EventBridge

-- 依赖模块
local StateMachine = require("state_machine")
local InputManager = require("input_manager")

-- 调试输出函数(如果lib未加载则使用print)
local function debugLog(msg)
    if lib and lib.Debug then
        lib.Debug(msg)
    else
        print(msg)
    end
end

-- 游戏状态常量 (从jyconst.lua导入)
-- 这里先声明，实际值会在初始化时从CC表获取
local GAME_STATES = {
    GAME_START = 0,
    GAME_MMAP = 1,
    GAME_SMAP = 2,
    GAME_WMAP = 3,
    GAME_FIRSTMMAP = 4,
    GAME_END = 5,
}

-- 状态处理器注册表
local stateHandlers = {}

-- 单例
local instance = nil

-- 获取单例
function EventBridge.getInstance()
    if not instance then
        instance = setmetatable({}, EventBridge)
    end
    return instance
end

-- 初始化桥接器
function EventBridge:init()
    -- 从全局CC表获取游戏状态常量
    if CC then
        GAME_STATES.GAME_START = GAME_START or 0
        GAME_STATES.GAME_MMAP = GAME_MMAP or 1
        GAME_STATES.GAME_SMAP = GAME_SMAP or 2
        GAME_STATES.GAME_WMAP = GAME_WMAP or 3
        GAME_STATES.GAME_FIRSTMMAP = GAME_FIRSTMMAP or 4
        GAME_STATES.GAME_END = GAME_END or 5
    end
    
    -- 初始化输入管理器
    InputManager.getInstance():init()
    
    -- 注册Love2D事件回调
    self:registerLoveCallbacks()
end

-- 注册Love2D事件回调
function EventBridge:registerLoveCallbacks()
    -- 保存原始的keypressed回调(如果有)
    local originalKeyPressed = love.keypressed
    local originalKeyReleased = love.keyreleased
    
    -- 使用全局的Debug函数(如果可用)
    local function log(msg)
        if _G.Debug then
            Debug(msg)
        elseif _G.lib and _G.lib.Debug then
            lib.Debug(msg)
        end
    end
    
    log("Registering Love2D key callbacks")
    
    -- 重写keypressed
    love.keypressed = function(key, scancode, isrepeat)
        log("Key pressed: " .. tostring(key))
        InputManager.getInstance():onKeyPressed(key, scancode, isrepeat)
        if originalKeyPressed then
            originalKeyPressed(key, scancode, isrepeat)
        end
    end
    
    -- 重写keyreleased
    love.keyreleased = function(key, scancode)
        log("Key released: " .. tostring(key))
        InputManager.getInstance():onKeyReleased(key, scancode)
        if originalKeyReleased then
            originalKeyReleased(key, scancode)
        end
    end
    
    log("Love2D key callbacks registered")
end

-- 注册游戏状态处理器
function EventBridge:registerState(stateId, handlers)
    local sm = StateMachine.getInstance()
    sm:register(stateId, handlers)
    stateHandlers[stateId] = handlers
end

-- 切换到指定状态
function EventBridge:switchState(stateId)
    local sm = StateMachine.getInstance()
    sm:switchTo(stateId)
    
    -- 同步JY.Status
    if JY then
        JY.Status = stateId
    end
end

-- 获取当前状态
function EventBridge:getCurrentState()
    local sm = StateMachine.getInstance()
    return sm:getCurrentState()
end

-- 更新 (在love.update中调用)
function EventBridge:update(dt)
    -- 重置按键消费状态(每帧开始时)
    InputManager.getInstance():resetKeyConsumed()
    
    -- 处理输入事件
    InputManager.getInstance():processEvents()
    
    -- 更新当前状态
    StateMachine.getInstance():update(dt)
end

-- 渲染 (在love.draw中调用)
function EventBridge:draw()
    StateMachine.getInstance():draw()
end

-- 获取输入管理器实例
function EventBridge:getInputManager()
    return InputManager.getInstance()
end

-- 获取状态机实例
function EventBridge:getStateMachine()
    return StateMachine.getInstance()
end

-- 向后兼容的GetKey函数
function EventBridge:getKey()
    return InputManager.getInstance():getKey()
end

-- 向后兼容的EnableKeyRepeat函数
function EventBridge:enableKeyRepeat(delay, interval)
    -- 原API使用delay和interval，新API只使用enabled
    -- 如果delay > 0则启用重复
    InputManager.getInstance():setKeyRepeat(delay > 0)
end

-- 检查按键是否按下
function EventBridge:isKeyDown(key)
    return InputManager.getInstance():isKeyDown(key)
end

-- 获取游戏状态常量
function EventBridge:getGameStates()
    return GAME_STATES
end

-- 重置桥接器 (用于测试)
function EventBridge:reset()
    StateMachine.getInstance():reset()
    InputManager.getInstance():reset()
    stateHandlers = {}
    instance = nil
end

-- 获取已注册的状态处理器
function EventBridge:getStateHandlers()
    return stateHandlers
end

return EventBridge
