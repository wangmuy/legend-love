-- event_bridge.lua
-- 事件桥接模块
-- 连接新旧架构，提供向后兼容的API
-- 集成协程调度器和异步对话框

local EventBridge = {}
EventBridge.__index = EventBridge

-- 依赖模块
local StateMachine = require("state_machine")
local InputManager = require("input_manager")
local CoroutineScheduler = require("coroutine_scheduler")
local AsyncDialog = require("async_dialog")

-- 游戏状态常量
local GAME_STATES = {
    GAME_START = 0,
    GAME_FIRSTMMAP = 1,
    GAME_MMAP = 2,
    GAME_FIRSTSMAP = 3,
    GAME_SMAP = 4,
    GAME_WMAP = 5,
    GAME_DEAD = 6,
    GAME_END = 7,
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

-- 内部调试方法
function EventBridge:_debug(msg)
    if lib and lib.Debug then
        lib.Debug(msg)
    end
end

-- 初始化桥接器
function EventBridge:init()
    self:_debug("EventBridge:init() called")
    
    -- 从全局CC表获取游戏状态常量
    if CC then
        GAME_STATES.GAME_START = GAME_START or 0
        GAME_STATES.GAME_FIRSTMMAP = GAME_FIRSTMMAP or 1
        GAME_STATES.GAME_MMAP = GAME_MMAP or 2
        GAME_STATES.GAME_FIRSTSMAP = GAME_FIRSTSMAP or 3
        GAME_STATES.GAME_SMAP = GAME_SMAP or 4
        GAME_STATES.GAME_WMAP = GAME_WMAP or 5
        GAME_STATES.GAME_DEAD = GAME_DEAD or 6
        GAME_STATES.GAME_END = GAME_END or 7
    end
    
    -- 初始化各模块
    StateMachine.getInstance():init()
    InputManager.getInstance():init()
    CoroutineScheduler.getInstance():init()
    AsyncDialog.getInstance():init()
    
    -- 启用按键重复，以便按住方向键时持续移动
    InputManager.getInstance():setKeyRepeat(true)
    InputManager.getInstance():setKeyRepeatParams(0.3, 0.1)  -- 首次延迟300ms，后续间隔100ms
    
    -- 注册Love2D事件回调
    self:_debug("EventBridge:init() calling registerLoveCallbacks")
    self:registerLoveCallbacks()
    self:_debug("EventBridge:init() completed")
end

-- 注册Love2D事件回调
function EventBridge:registerLoveCallbacks()
    self:_debug("EventBridge:registerLoveCallbacks() called")
    
    local originalKeyPressed = love.keypressed
    local originalKeyReleased = love.keyreleased
    
    self:_debug(string.format("EventBridge: originalKeyPressed=%s", tostring(originalKeyPressed)))
    
    -- 重写keypressed
    love.keypressed = function(key, scancode, isrepeat)
        self:_debug(string.format("EventBridge: love.keypressed called: key=%s", tostring(key)))
        InputManager.getInstance():onKeyPressed(key, scancode, isrepeat)
        if originalKeyPressed then
            originalKeyPressed(key, scancode, isrepeat)
        end
    end
    
    -- 重写keyreleased
    love.keyreleased = function(key, scancode)
        InputManager.getInstance():onKeyReleased(key, scancode)
        if originalKeyReleased then
            originalKeyReleased(key, scancode)
        end
    end
end

-- 注册游戏状态处理器
function EventBridge:registerState(stateId, handlers)
    local sm = StateMachine.getInstance()
    sm:register(stateId, handlers)
    stateHandlers[stateId] = handlers
end

-- 切换到指定状态
function EventBridge:switchState(stateId, data)
    local sm = StateMachine.getInstance()
    sm:switchTo(stateId, data)
    
    -- 同步JY.Status
    if JY then
        JY.Status = stateId
    end
end

-- 进入子状态
function EventBridge:pushSubState(subStateId, data)
    local sm = StateMachine.getInstance()
    sm:pushSubState(subStateId, data)
end

-- 退出子状态
function EventBridge:popSubState(result)
    local sm = StateMachine.getInstance()
    return sm:popSubState(result)
end

-- 获取当前状态
function EventBridge:getCurrentState()
    local sm = StateMachine.getInstance()
    return sm:getCurrentState()
end

-- 获取当前子状态
function EventBridge:getCurrentSubState()
    local sm = StateMachine.getInstance()
    return sm:getCurrentSubState()
end

-- 更新 (在love.update中调用)
function EventBridge:update(dt)
    -- 更新输入管理器（处理按键重复）
    InputManager.getInstance():update(dt)
    
    -- 更新协程调度器
    CoroutineScheduler.getInstance():update(dt)
    
    -- 更新对话框
    AsyncDialog.getInstance():update(dt)
    self:_debug("EventBridge.update: AsyncDialog.update done")
    
    -- 更新当前状态
    StateMachine.getInstance():update(dt)
    self:_debug("EventBridge.update: StateMachine.update done")
    
    self:_debug("EventBridge.update: end")
end

-- 渲染 (在love.draw中调用)
-- 全局绘制回调（用于特殊场景如属性选择）
local globalDrawCallback = nil

function EventBridge.setGlobalDrawCallback(callback)
    globalDrawCallback = callback
end

function EventBridge.clearGlobalDrawCallback()
    globalDrawCallback = nil
end

function EventBridge:draw()
    self:_debug("EventBridge:draw called")
    
    -- 执行全局绘制回调（如果有）
    if globalDrawCallback then
        globalDrawCallback()
    end
    
    -- 渲染当前状态
    StateMachine.getInstance():draw()
    
    -- 渲染人物状态（在场景之上）
    local PersonStatusAsync = require("person_status_async")
    PersonStatusAsync.draw()
    
    -- 渲染物品选择界面（在场景之上）
    local ItemAsync = require("item_async")
    ItemAsync.draw()
    
    -- 渲染菜单标题（在场景之上）
    local JyMainAsync = require("jymain_async")
    JyMainAsync.drawMenuTitle()
    
    -- 渲染对话（在场景之上，对话框之下）
    local TalkAsync = require("talk_async")
    TalkAsync.draw()
    
    -- 渲染对话框（在最上层）
    AsyncDialog.getInstance():draw()
end

-- 创建协程
function EventBridge:createCoroutine(fn, name)
    return CoroutineScheduler.getInstance():create(fn, name)
end

-- 启动协程
function EventBridge:startCoroutine(id, ...)
    return CoroutineScheduler.getInstance():start(id, ...)
end

-- 在协程中等待按键
function EventBridge:waitForKey()
    return CoroutineScheduler.getInstance():waitForKey()
end

-- 在协程中等待时间
function EventBridge:waitForTime(seconds)
    return CoroutineScheduler.getInstance():waitForTime(seconds)
end

-- 显示确认对话框
function EventBridge:showYesNo(message, callback, options)
    AsyncDialog.getInstance():showYesNo(message, callback, options)
end

-- 显示输入对话框
function EventBridge:showInput(prompt, callback, options)
    AsyncDialog.getInstance():showInput(prompt, callback, options)
end

-- 显示选择对话框
function EventBridge:showSelect(title, items, callback, options)
    AsyncDialog.getInstance():showSelect(title, items, callback, options)
end

-- 获取输入管理器实例
function EventBridge:getInputManager()
    return InputManager.getInstance()
end

-- 获取状态机实例
function EventBridge:getStateMachine()
    return StateMachine.getInstance()
end

-- 获取协程调度器实例
function EventBridge:getCoroutineScheduler()
    return CoroutineScheduler.getInstance()
end

-- 获取对话框管理器实例
function EventBridge:getAsyncDialog()
    return AsyncDialog.getInstance()
end

-- 向后兼容的GetKey函数
function EventBridge:getKey()
    return InputManager.getInstance():getKey()
end

-- 向后兼容的EnableKeyRepeat函数
function EventBridge:enableKeyRepeat(delay, interval)
    InputManager.getInstance():setKeyRepeat(delay > 0)
    if delay > 0 and interval > 0 then
        InputManager.getInstance():setKeyRepeatParams(delay / 1000, interval / 1000)
    end
end

-- 检查按键是否按下
function EventBridge:isKeyDown(key)
    return InputManager.getInstance():isKeyDown(key)
end

-- 获取游戏状态常量
function EventBridge:getGameStates()
    return GAME_STATES
end

-- 重置桥接器
function EventBridge:reset()
    StateMachine.getInstance():reset()
    InputManager.getInstance():reset()
    CoroutineScheduler.getInstance():reset()
    AsyncDialog.getInstance():reset()
    stateHandlers = {}
    instance = nil
end

-- 获取已注册的状态处理器
function EventBridge:getStateHandlers()
    return stateHandlers
end

return EventBridge
