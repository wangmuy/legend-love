-- input_async.lua
-- 异步输入函数
-- 提供非阻塞版本的WaitKey和其他输入函数

local InputAsync = {}

-- 导入协程调度器
local CoroutineScheduler = require("coroutine_scheduler")

-- 等待按键（协程版本）
-- 在协程中使用，不会阻塞游戏主循环
function InputAsync.WaitKey()
    local scheduler = CoroutineScheduler.getInstance()
    return scheduler:waitForKey()
end

-- WaitKeyCoroutine 是 WaitKey 的别名，保持命名一致性
InputAsync.WaitKeyCoroutine = InputAsync.WaitKey

-- 等待按键（带超时，协程版本）
-- @param timeout: 超时时间（秒）
-- @return: 按键值，如果超时返回-1
function InputAsync.WaitKeyTimeout(timeout)
    local scheduler = CoroutineScheduler.getInstance()
    local startTime = love.timer.getTime()
    
    while true do
        local key = lib.GetKey()
        if key ~= -1 then
            return key
        end
        
        if love.timer.getTime() - startTime >= timeout then
            return -1
        end
        
        scheduler:yield("input_timeout")
    end
end

-- 等待任意按键（协程版本）
-- 等待用户按下任意键，返回按键值
function InputAsync.WaitAnyKey()
    return InputAsync.WaitKey()
end

-- 等待特定按键（协程版本）
-- @param targetKey: 等待的按键值
-- @return: 返回按下的按键值
function InputAsync.WaitForKey(targetKey)
    local key
    repeat
        key = InputAsync.WaitKey()
    until key == targetKey
    return key
end

-- 等待按键释放（协程版本）
-- 等待特定按键被释放
function InputAsync.WaitKeyRelease(targetKey)
    local scheduler = CoroutineScheduler.getInstance()
    local InputManager = require("input_manager")
    local im = InputManager.getInstance()
    
    while im:isKeyDown(targetKey) do
        scheduler:yield("key_release")
    end
end

-- 获取按键状态（非阻塞）
function InputAsync.GetKeyState(key)
    local InputManager = require("input_manager")
    return InputManager.getInstance():isKeyDown(key)
end

-- 检查是否有按键按下（非阻塞）
function InputAsync.IsAnyKeyPressed()
    local key = lib.GetKey()
    return key ~= -1, key
end

return InputAsync
