-- input_async.lua
-- 异步输入函数
-- 提供非阻塞版本的WaitKey和其他输入函数

local FlowFacade = require("framework.flow_facade")
local InputAsync = {}

-- 导入协程调度器
local CoroutineScheduler = require("framework.coroutine_scheduler")

-- 等待按键（协程版本）
-- 在协程中使用，不会阻塞游戏主循环
function InputAsync.WaitKey()
    local scheduler = CoroutineScheduler.getInstance()
    return scheduler:waitForKey()
end

-- WaitKeyCoroutine 是 WaitKey 的别名，保持命名一致性
InputAsync.WaitKeyCoroutine = InputAsync.WaitKey

--- 等待按键（带超时，**绕过 disableInput**，协程版本）
--
-- 与 WaitKeyTimeout 的差别只有一处：用 scheduler 的内部取键
-- （_peekKeyInternal / _getKeyInternal）而不是 EngineAPI.input.getKey()。
--
-- 为什么需要它：物品清单/人物状态等模态 UI 会在自己运行期间设
-- InputManager.disableInput = true（阻止地图主循环吃键）。
-- 但**它们自己仍需读键**，所以必须绕过那个标志 ——
-- 这正是 scheduler 的 keyWaiting 机制在做的事（waitForKey →
-- yield("key") → update 里用 _peekKeyInternal）。
--
-- 本函数在 waitForKey 的基础上加超时：
--   * 先看有没有键，有就返回
--   * 没键时 yield("input_timeout")，让 scheduler 每帧都 resume
--     （不会被当成 keyWaiting 而错过超时判断）
--
-- @param timeout number 秒
-- @return number 按键码；超时返回 -1
function InputAsync.WaitKeyTimeoutBypass(timeout)
    local scheduler = CoroutineScheduler.getInstance()
    local InputManager = require("framework.input_manager")
    local startTime = EngineAPI.time.getTimeSeconds()

    while true do
        local im = InputManager.getInstance()
        local key = im:_peekKeyInternal()
        if key ~= -1 then
            im:_getKeyInternal()
            return key
        end

        if EngineAPI.time.getTimeSeconds() - startTime >= timeout then
            return -1
        end

        scheduler:yield("input_timeout")
    end
end

-- 等待按键（带超时，协程版本）
-- @param timeout: 超时时间（秒）
-- @return: 按键值，如果超时返回-1
function InputAsync.WaitKeyTimeout(timeout)
    local scheduler = CoroutineScheduler.getInstance()
    local startTime = EngineAPI.time.getTimeSeconds()
    
    while true do
        local key = EngineAPI.input.getKey()
        if key ~= -1 then
            return key
        end
        
        if EngineAPI.time.getTimeSeconds() - startTime >= timeout then
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
    local InputManager = require("framework.input_manager")
    local im = InputManager.getInstance()
    
    while im:isKeyDown(targetKey) do
        scheduler:yield("key_release")
    end
end

--- 等待一个语义动作（协程版本，input-action-layer）
--
-- 与 WaitKey 的差别：返回**动作名**（"ui.accept"）而不是 VK 整数。
-- 这是迁移期的新通道，旧调用点仍可用 WaitKey。
--
-- @return string 动作名（不会返回 nil）
function InputAsync.WaitAction()
    local scheduler = CoroutineScheduler.getInstance()
    local InputManager = require("framework.input_manager")
    while true do
        local action = InputManager.getAction()
        if action then return action end
        scheduler:yield("action")
    end
end

--- 非阻塞取一个语义动作
-- @return string|nil
function InputAsync.GetAction()
    local InputManager = require("framework.input_manager")
    return InputManager.getAction()
end

--- 非阻塞查看语义动作（不消费）
-- @return string|nil
function InputAsync.PeekAction()
    local InputManager = require("framework.input_manager")
    return InputManager.peekAction()
end

-- 获取按键状态（非阻塞）
function InputAsync.GetKeyState(key)
    local InputManager = require("framework.input_manager")
    return InputManager.getInstance():isKeyDown(key)
end

-- 检查是否有按键按下（非阻塞）
function InputAsync.IsAnyKeyPressed()
    local key = EngineAPI.input.getKey()
    return key ~= -1, key
end

return InputAsync
