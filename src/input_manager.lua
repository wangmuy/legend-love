-- input_manager.lua
-- 输入管理模块
-- 提供事件驱动的输入处理，替代阻塞式GetKey

local InputManager = {}
InputManager.__index = InputManager

-- 事件队列
local eventQueue = {}
local currentKey = -1
local keyStates = {}
local keyRepeatEnabled = false
local keyConsumed = false  -- 标记按键是否已被消费

-- 按键映射表 (Love2D键名 -> 游戏内键值)
-- 使用硬编码值，因为VK_*常量在此模块加载时还未定义
local keyMap = {
    ["escape"] = 27,   -- VK_ESCAPE
    [" "] = 32,        -- VK_SPACE
    ["return"] = 13,   -- VK_RETURN
    ["up"] = 1073741906,    -- VK_UP (SDLK_UP)
    ["down"] = 1073741905,  -- VK_DOWN (SDLK_DOWN)
    ["left"] = 1073741904,  -- VK_LEFT (SDLK_LEFT)
    ["right"] = 1073741903, -- VK_RIGHT (SDLK_RIGHT)
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
    currentKey = -1
    keyStates = {}
    keyRepeatEnabled = false
end

-- 注册Love2D按键到游戏键值的映射
function InputManager:registerKey(loveKey, gameKey)
    keyMap[loveKey] = gameKey
end

-- 调试输出函数
local function debugLog(msg)
    if lib and lib.Debug then
        lib.Debug(msg)
    else
        print(msg)
    end
end

-- 日志函数
local function log(msg)
    if _G.Debug then
        Debug(msg)
    elseif _G.lib and _G.lib.Debug then
        lib.Debug(msg)
    end
end

-- 处理love.keypressed事件
function InputManager:onKeyPressed(key, scancode, isrepeat)
    log("InputManager:onKeyPressed: " .. tostring(key))
    local gameKey = keyMap[key]
    log("Mapped to: " .. tostring(gameKey))
    if gameKey then
        -- 添加到事件队列
        table.insert(eventQueue, {
            type = "pressed",
            key = gameKey,
            isRepeat = isrepeat
        })
        -- 更新当前按键状态
        currentKey = gameKey
        keyStates[gameKey] = true
        keyConsumed = false  -- 新按键，标记为未消费
        log("Key set to currentKey: " .. tostring(gameKey))
    else
        log("Key not in keyMap")
    end
end

-- 处理love.keyreleased事件
function InputManager:onKeyReleased(key, scancode)
    local gameKey = keyMap[key]
    if gameKey then
        -- 添加到事件队列
        table.insert(eventQueue, {
            type = "released",
            key = gameKey
        })
        -- 更新按键状态
        keyStates[gameKey] = false
        -- 如果释放的是当前按键，重置currentKey
        if currentKey == gameKey then
            currentKey = -1
        end
    end
end

-- 获取当前按键 (兼容原有GetKey API)
-- 注意：此方法会消费按键，同一帧内多次调用只有第一次返回有效值
function InputManager:getKey()
    if keyConsumed then
        return -1  -- 按键已被消费
    end
    local key = currentKey
    if key ~= -1 then
        keyConsumed = true  -- 标记为已消费
    end
    return key
end

-- 查看当前按键但不消费 (用于调试或检查)
function InputManager:peekKey()
    return currentKey
end

-- 重置消费状态 (在每帧update开始时调用)
function InputManager:resetKeyConsumed()
    keyConsumed = false
    currentKey = -1  -- 同时重置当前按键
end

-- 查询按键是否被按下
function InputManager:isKeyDown(gameKey)
    return keyStates[gameKey] == true
end

-- 获取并清空事件队列
function InputManager:pollEvents()
    local events = {}
    for _, event in ipairs(eventQueue) do
        table.insert(events, event)
    end
    eventQueue = {}
    return events
end

-- 处理所有待处理的事件 (在update中调用)
function InputManager:processEvents()
    local events = self:pollEvents()
    -- 事件处理逻辑可以在这里扩展
    return events
end

-- 设置按键重复
function InputManager:setKeyRepeat(enabled)
    keyRepeatEnabled = enabled
    if love.keyboard then
        love.keyboard.setKeyRepeat(enabled)
    end
end

-- 是否启用了按键重复
function InputManager:isKeyRepeatEnabled()
    return keyRepeatEnabled
end

-- 清空所有按键状态
function InputManager:clear()
    eventQueue = {}
    currentKey = -1
    keyStates = {}
end

-- 重置输入管理器 (用于测试)
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

-- 获取按键映射表 (调试用)
function InputManager:getKeyMap()
    return keyMap
end

return InputManager
