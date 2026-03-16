-- event_executor.lua
-- 事件执行器模块
-- 提供协程版本的事件执行函数
-- 所有事件都在协程中执行，支持异步调用

local EventExecutor = {}

local CoroutineScheduler = require("coroutine_scheduler")
local AsyncWrapper = require("async_wrapper")
local AsyncGlobals = require("async_globals")

-- 事件执行状态
local executingEvent = nil
local eventQueue = {}

-- 是否使用协程执行事件
local useCoroutine = true

-- 启用/禁用协程模式
function EventExecutor.setCoroutineMode(enabled)
    useCoroutine = enabled
end

-- 事件执行入口（自动选择同步/异步模式）
-- @param id: D*中的编号
-- @param flag: 1=空格触发, 2=物品触发, 3=路过触发
function EventExecuteCoroutine(id, flag)
    local scheduler = CoroutineScheduler.getInstance()
    
    JY.CurrentD = id
    lib.Debug(string.format("EventExecuteCoroutine: id=%d, flag=%d", id, flag))
    
    if JY.SceneNewEventFunction[JY.SubScene] == nil then
        oldEventExecuteCoroutine(flag)
    else
        JY.SceneNewEventFunction[JY.SubScene](flag)
    end
    
    JY.CurrentD = -1
    JY.Darkness = 0
end

-- 协程版本的旧事件执行
function EventExecutor.oldEventExecuteCoroutine(flag)
    local eventnum
    
    if flag == 1 then
        eventnum = GetD(JY.SubScene, JY.CurrentD, 2)
    elseif flag == 2 then
        eventnum = GetD(JY.SubScene, JY.CurrentD, 3)
    elseif flag == 3 then
        eventnum = GetD(JY.SubScene, JY.CurrentD, 4)
    end
    
    lib.Debug(string.format("oldEventExecuteCoroutine: eventnum=%d", eventnum or -1))
    
    if eventnum and eventnum > 0 then
        oldCallEventCoroutine(eventnum)
    end
end

-- 协程版本的调用旧事件
function oldCallEventCoroutine(eventnum)
    local eventfilename = string.format("oldevent_%d.lua", eventnum)
    lib.Debug(string.format("oldCallEventCoroutine: %s", eventfilename))
    
    -- 安装异步全局函数替换
    AsyncGlobals.install()
    
    -- 直接执行事件脚本，不在pcall中（pcall会干扰yield）
    dofile(CONFIG.OldEventPath .. eventfilename)
    
    -- 卸载异步全局函数替换
    AsyncGlobals.uninstall()
    
    lib.Debug(string.format("oldCallEventCoroutine: %s finished", eventfilename))
end

-- 启动事件协程
-- @param id: 事件ID
-- @param flag: 触发类型
-- @param callback: 完成回调（可选）
function EventExecutor.startEvent(id, flag, callback)
    local scheduler = CoroutineScheduler.getInstance()
    
    local co = scheduler:create(function()
        EventExecuteCoroutine(id, flag)
        if callback then
            callback()
        end
    end, "event_" .. tostring(id))
    
    scheduler:start(co, "start")  -- 传递一个参数，避免coroutine.yield返回nil
    
    return co
end

-- 同步事件执行入口（在主游戏循环中调用）
-- 此函数会自动在协程中执行事件
function EventExecuteSync(id, flag)
    if useCoroutine then
        EventExecutor.startEvent(id, flag)
    else
        -- 回退到原版同步执行
        JY.CurrentD = id
        if JY.SceneNewEventFunction[JY.SubScene] == nil then
            oldEventExecute(flag)
        else
            JY.SceneNewEventFunction[JY.SubScene](flag)
        end
        JY.CurrentD = -1
        JY.Darkness = 0
    end
end

-- 检查是否有事件正在执行
function EventExecutor.isExecuting()
    return executingEvent ~= nil
end

return EventExecutor