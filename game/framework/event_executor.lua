-- event_executor.lua
-- 事件执行器模块
-- 提供协程版本的事件执行函数
-- 所有事件都在协程中执行，支持异步调用

local EventExecutor = {}

local CoroutineScheduler = require("framework.coroutine_scheduler")
local AsyncWrapper = require("framework.async_wrapper")
local AsyncGlobals = require("framework.async_globals")
local ScriptLoader = require("framework.script_loader")

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
        EventExecutor.oldEventExecuteCoroutine(flag)
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
    
    if eventnum == nil or eventnum <= 0 then
        eventnum = JY.CurrentD  -- fallback: 直接用事件 ID
    end
    
    lib.Debug(string.format("oldEventExecuteCoroutine: eventnum=%d", eventnum or -1))
    
    if eventnum and eventnum > 0 then
        EventExecutor.oldCallEventCoroutine(eventnum)
    end
end

-- 协程版本的调用旧事件
function EventExecutor.oldCallEventCoroutine(eventnum)
    local eventfilename = string.format("oldevent_%d.lua", eventnum)
    lib.Debug(string.format("oldCallEventCoroutine: %s START", eventfilename))
    
    -- 设置 JY.CurrentD（原版 EventExecuteCoroutine 的行为，供 instruct_3 用 id=-2 获取当前事件编号）
    -- 注意：调用方（smapUseItemOnNpc 等）可能已设置 CurrentD = 触发事件的 tile 索引
    -- （原版语义：instruct_3(-2,...) 写回 NPC 所在 tile，如谢逊 tile2 field3 铁焰令→头颅65）。
    -- 若调用方已设置有效值则保留，否则回退为事件编号（兼容旧 NPC 对话模型）。
    if JY and (JY.CurrentD == nil or JY.CurrentD < 0) then
        JY.CurrentD = eventnum
    end
    
    -- 安装异步全局函数替换
    AsyncGlobals.install()
    
    local chunk, err = ScriptLoader.load(CONFIG.OldEventPath .. eventfilename)
    if chunk then
        -- 兼容两种 oldevent 文件格式：
        --   1) "--function oldevent_N() ... --end"（函数定义被注释，chunk() 直接执行指令）
        --   2) "function oldevent_N() ... end"（完整函数定义，chunk() 只定义函数不执行）
        -- 对格式 2，chunk() 执行后会定义全局函数 oldevent_N，需调用它以执行事件指令。
        -- 仅在 chunk 新定义了该函数时调用（避免重复执行旧函数）。
        local funcName = "oldevent_" .. tostring(eventnum)
        local fnBefore = rawget(_G, funcName)
        chunk()  -- 直接执行，不在 pcall 中
        local fnAfter = rawget(_G, funcName)
        if fnAfter ~= fnBefore and type(fnAfter) == "function" then
            fnAfter()
        end
    else
        lib.Debug("oldCallEventCoroutine: failed to load " .. eventfilename .. ": " .. tostring(err))
        if JY_Error then
            JY_Error("oldCallEventCoroutine load failed: %s (%s)", tostring(eventfilename), tostring(err))
        end
    end
    
    -- 卸载异步全局函数替换
    AsyncGlobals.uninstall()
    
    -- 重置 JY.CurrentD
    if JY then JY.CurrentD = -1 end
    
    lib.Debug(string.format("oldCallEventCoroutine: %s FINISHED", eventfilename))
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
        -- 检查是否已经有事件协程在运行（只检查状态为 "suspended" 的协程）
        local scheduler = CoroutineScheduler.getInstance()
        local coroutines = scheduler:getAllCoroutines()
        for _, coId in ipairs(coroutines) do
            local info = scheduler:getInfo(coId)
            if info and info.status == "suspended" and info.name and string.find(info.name, "event_") then
                lib.Debug("EventExecuteSync: event already running, ignoring new trigger")
                return
            end
        end
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
