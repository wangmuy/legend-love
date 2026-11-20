-- coroutine_scheduler.lua
-- 协程调度器模块
-- 管理所有协程的创建、调度和销毁

local CoroutineScheduler = {}
CoroutineScheduler.__index = CoroutineScheduler

-- 导入依赖模块
-- **不在模块级缓存 InputManager 表**
--
-- 原因：事件队列是 input_manager.lua 的模块级 upvalue。若有人在运行时
-- 清掉 package.loaded["framework.input_manager"]（测试里会这么做），
-- 重新 require 会得到**全新的模块表 + 全新的空队列**，而这里缓存的
-- 还是旧表 → scheduler 看不见测试注入的键，协程永远醒不来。
--
-- 实测症状：单跑 battle_mouse 用例全过，混进全套件后
-- 「注入键后协程没被唤醒」——因为 test_mouse_hover 清过 input_manager。
--
-- 每次取用都重新 require（package.loaded 命中时开销只是一个表查找）。

-- 协程列表
local coroutines = {}
local currentCoroutine = nil
local coroutineIdCounter = 0

-- 单例实例
local instance = nil

-- 获取单例
function CoroutineScheduler.getInstance()
    if not instance then
        instance = setmetatable({}, CoroutineScheduler)
    end
    return instance
end

-- 初始化调度器
function CoroutineScheduler:init(deps)
    deps = deps or {}
    coroutines = {}
    currentCoroutine = nil
    coroutineIdCounter = 0
    -- 注入时间源
    --
    -- **不能在这里就绑定 EngineAPI 的当前函数**：测试通常在 require scheduler
    -- 之后再 stub EngineAPI（`rawset(_G, "EngineAPI", {time={getTimeSeconds=...}})`)，
    -- 构造时绑定会让 timeSource 一直指向**旧的**实现 → 假时钟推不动 →
    -- `waitForTime` 的 deadline 永远不到 → 协程永不恢复（实测 test_item_status_mouse
    -- 5 条断言 FAIL）。
    --
    -- 所以：显式注入的 deps.timeSource 优先（真正固定）；
    -- 否则留 nil，在 `_now()` 里**每次动态查** EngineAPI。
    self.timeSource = deps.timeSource or nil
end

--- 当前时间（秒）——**每次动态解析时间源**
--
-- 优先级：
--   ① 显式注入的 `self.timeSource`（测试/宿主可固定）
--   ② `EngineAPI.time.getTimeSeconds`（每帧读最新的，支持运行时换引擎/stub）
--   ③ `os.clock()`
--
-- 为什么 ② 要每帧查而不是构造时绑定：见 Init 里 `self.timeSource` 的注释。
function CoroutineScheduler:_now()
    if self.timeSource then
        return self.timeSource()
    end
    local api = rawget(_G, "EngineAPI")
    if api and api.time and api.time.getTimeSeconds then
        return api.time.getTimeSeconds()
    end
    return os.clock()
end

-- 内部调试方法，便于测试时 mock
function CoroutineScheduler:_debug(msg)
    if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
        EngineAPI.debug.log(msg)
    end
end

-- 创建新协程
-- @param fn: 协程执行的函数
-- @param name: 协程名称（可选，用于调试）
-- @return: 协程ID
function CoroutineScheduler:create(fn, name)
    coroutineIdCounter = coroutineIdCounter + 1
    local id = coroutineIdCounter
    
    local co = coroutine.create(fn)
    coroutines[id] = {
        co = co,
        name = name or "coroutine_" .. id,
        status = "suspended",
        waitingFor = nil,  -- 等待的条件（如按键、时间等）
        -- `waitForTime` 的截止时刻（毫秒，时间源同 timeSource）。
        -- nil = 没有时间约束（普通 yield）；非 nil = 到期前不恢复。
        -- 见 waitForTime 的注释：原实现记录 startTime 但从未使用，
        -- 导致 waitForTime(0.1) 实际只等 1 帧。
        deadline = nil,
        result = nil,      -- 协程返回值
        error = nil        -- 错误信息
    }
    
    self:_debug("CoroutineScheduler.create: created coroutine id=" .. tostring(id) .. ", name=" .. tostring(name or "coroutine_" .. id))
    
    return id
end

-- 启动协程
-- @param id: 协程ID
-- @param ...: 传递给协程的参数
-- @return: 成功返回true，失败返回false和错误信息
function CoroutineScheduler:start(id, ...)
    local info = coroutines[id]
    if not info then
        return false, "Coroutine not found: " .. tostring(id)
    end
    
    if info.status ~= "suspended" then
        return false, "Coroutine is not suspended: " .. info.status
    end
    
    local previousCoroutine = currentCoroutine
    currentCoroutine = id
    local success, result = coroutine.resume(info.co, ...)
    currentCoroutine = previousCoroutine
    
    if not success then
        info.status = "error"
        info.error = result
        self:_debug("CoroutineScheduler.start: ERROR in coroutine " .. tostring(id) .. ": " .. tostring(result))
        if JY_Error then
            JY_Error("CoroutineScheduler.start error id=%s name=%s err=%s", tostring(id), tostring(info.name), tostring(result))
        end
        -- 清理出错的协程，防止阻塞后续事件
        coroutines[id] = nil
        return false, result
    end
    
    local actualStatus = coroutine.status(info.co)
    self:_debug("CoroutineScheduler.start: info.status before=" .. tostring(info.status) .. ", coroutine.status=" .. tostring(actualStatus) .. ", result=" .. tostring(result))
    -- 修复：如果 coroutine.status 返回 "running"，将其视为 "suspended"
    -- 因为协程已经调用了 yield，只是 coroutine.status 返回了错误的状态
    if actualStatus == "running" then
        info.status = "suspended"
    else
        info.status = actualStatus
    end
    if info.status == "dead" then
        info.result = result
        info.status = "completed"
        self:_debug("CoroutineScheduler.start: coroutine " .. tostring(id) .. " completed with result=" .. tostring(result))
        -- 不立即清理，让调用者可以获取结果
    end
    
    return true, result
end

-- 恢复协程
-- @param id: 协程ID
-- @param ...: 传递给协程的参数
-- @return: 成功返回true，失败返回false和错误信息
function CoroutineScheduler:resume(id, ...)
    return self:start(id, ...)
end

-- 挂起当前协程
-- @param waitingFor: 等待的条件描述（可选）
-- @return: 挂起时返回的值
function CoroutineScheduler:yield(waitingFor)
    if not currentCoroutine then
        error("Cannot yield from outside a coroutine")
    end
    
    self:_debug("CoroutineScheduler.yield: currentCoroutine=" .. tostring(currentCoroutine) .. ", waitingFor=" .. tostring(waitingFor))
    
    local info = coroutines[currentCoroutine]
    if info then
        info.status = "suspended"
        info.waitingFor = waitingFor
    end
    
    return coroutine.yield(waitingFor)
end

-- 等待按键
-- @return: 按下的按键值
function CoroutineScheduler:waitForKey()
    return self:yield("key")
end

-- 等待时间（事件驱动版本）
-- @param seconds: 等待的秒数
-- 注意：这个版本只yield一次，让出时间给love.draw，然后由外部控制是否继续等待
--- 等待指定时长（**真的等待，不是 yield 一次**）
-- @param seconds number 秒；<= 0 表示不等待（下一帧恢复）
--
-- **原实现的缺陷（实测已修）**：
-- ```lua
-- local startTime = self.timeSource and self.timeSource() or 0   -- 记录了
-- self:yield("time")                                            -- 但从未使用
-- ```
-- 而 `update(dt)` 每帧无条件恢复所有非 key/action 协程 → `waitForTime` 的
-- 实际效果是「等 1 帧」，与参数无关。实测 `waitForTime(0.1)` 在帧 2 恢复
-- （期望 6+ 帧）。
--
-- 受影响调用点：async_wrapper:78 / event_bridge:248 /
-- item_async:293（0.05）/ person_status_async:132（0.1）。
-- 用户可见症状：物品栏/人物状态的「翻页防连按」节流失效。
--
-- **修法**：把截止时刻写进当前协程的 info，由 `update` 逐帧判断后才恢复。
function CoroutineScheduler:waitForTime(seconds)
    seconds = tonumber(seconds) or 0

    local info = currentCoroutine and coroutines[currentCoroutine]
    if not info then
        -- 不在协程里（或 id 不可用）：保持原有行为，yield 一次
        self:yield("time")
        return
    end

    if seconds <= 0 then
        -- 不等待：清掉 deadline，下一帧就恢复
        info.deadline = nil
        self:yield("time")
        return
    end

    local now = self:_now()
    info.deadline = now + seconds
    self:yield("time")

    -- 恢复后清空（避免残留导致下次 yield 被误判）
    info.deadline = nil
end

-- 等待条件
-- @param conditionFn: 条件函数，返回true时结束等待
function CoroutineScheduler:waitForCondition(conditionFn)
    while not conditionFn() do
        self:yield("condition")
    end
end

-- 终止所有挂起的"事件类"协程（战斗/场景切换/读档时清理僵尸）
-- 背景：update() 每帧恢复所有 waitingFor~="key" 的协程，且战斗结果用全局
-- __warComplete/__warResult 标志传递。若战斗协程被中途放弃（战斗中传送/读档/
-- 菜单劫持后 never-resume），协程永久滞留在 yield("war")，下一场战斗结束时被
-- 错误唤醒并执行错误的事件后程（P7 串台根因：115 僵尸抢读 76 的标志播放倚天后程）。
-- 只清理 name 以 "event"/"npc_talk"/"event_trigger" 开头的挂起协程，
-- 保留菜单/对话等其他框架协程。
-- @return 清理数量
function CoroutineScheduler:killStaleEvents()
    local killed = 0
    for id, info in pairs(coroutines) do
        -- 关键：跳过当前正在运行的协程（currentCoroutine）。
        -- 协程在执行期间（resume 后、yield 前）info.status 仍为旧的 "suspended"，
        -- 若不跳过，instruct_6 里调用本函数会把"正在调它的那条事件协程"误杀——
        -- 该协程随后 yield("war") 时已被移出 coroutines 表，成为孤儿永不恢复，
        -- 战斗胜利后事件后程（instruct_3 升级/给书）不执行（P6 五毒教 616 不置 611 根因）。
        -- 注意：不用 goto（Lua 5.2+ 语法），保持 5.1/LuaJIT 可解析。
        if id ~= currentCoroutine then
            local nm = info.name or ""
            local isEventCo = string.find(nm, "event_", 1, true) ~= nil
                or string.find(nm, "npc_talk_", 1, true) ~= nil
            if info.status == "suspended" and isEventCo then
                coroutines[id] = nil
                killed = killed + 1
            end
        end
    end
    if killed > 0 then
        self:_debug("CoroutineScheduler.killStaleEvents: killed " .. killed .. " stale event coroutines")
    end
    return killed
end

-- 更新所有协程
-- @param dt: delta time
function CoroutineScheduler:update(dt)
    local activeCoroutines = {}
    local keyWaitingCoroutines = {}
    local actionWaitingCoroutines = {}
    
    -- 收集所有需要更新的协程
    for id, info in pairs(coroutines) do
        if info.status == "suspended" then
            if info.waitingFor == "key" then
                -- 等待按键的协程单独处理
                table.insert(keyWaitingCoroutines, id)
            elseif info.waitingFor == "action" then
                -- 等待语义动作的协程单独处理（input-action-layer）
                table.insert(actionWaitingCoroutines, id)
            else
                table.insert(activeCoroutines, id)
            end
        end
    end
    
    -- 检查是否有按键按下
    local keyPressed = false
    local pressedKey = -1
    if #keyWaitingCoroutines > 0 then
        -- 使用内部方法绕过 disableInput 标志
        local im = require("framework.input_manager").getInstance()
        pressedKey = im:_peekKeyInternal()
        if pressedKey ~= -1 then
            im:_getKeyInternal()
            keyPressed = true
        end
    end
    
    -- 恢复等待按键的协程（如果有按键按下）
    if keyPressed then
        for _, id in ipairs(keyWaitingCoroutines) do
            local info = coroutines[id]
            if info and info.status == "suspended" and info.waitingFor == "key" then
                self:resume(id, pressedKey)  -- 传递按键值给协程
            end
        end
    end
    
    -- 恢复等待语义动作的协程（有动作才唤醒）
    --
    -- 与 keyWaiting 的区别：动作队列带 source，消费方可以判来源；
    -- 且一个动作事件只唤醒一个协程（与键的行为一致）。
    if #actionWaitingCoroutines > 0 then
        local im = require("framework.input_manager").getInstance()
        local actionName = im.getAction()
        if actionName then
            for _, id in ipairs(actionWaitingCoroutines) do
                local info = coroutines[id]
                if info and info.status == "suspended" and info.waitingFor == "action" then
                    self:resume(id, actionName)
                    break    -- 一个动作只唤醒一个等待者
                end
            end
        end
    end

    -- 恢复其他挂起的协程
    --
    -- **必须检查 deadline**（`waitForTime` 的截止时刻）：
    -- 原实现无条件 resume，导致 `waitForTime(N)` 的实际效果是「等 1 帧」，
    -- 与 N 无关（实测 waitForTime(0.1) 在帧 2 恢复，期望 6+ 帧）。
    -- 现在未到期的协程本帧跳过，等 `update` 下次被调用时再判断。
    local nowT = self:_now()
    for _, id in ipairs(activeCoroutines) do
        local info = coroutines[id]
        if info and info.status == "suspended" then
            if info.deadline ~= nil and nowT < info.deadline then
                -- 还没到时间：本帧不恢复（保留 deadline，下帧再判）
            else
                info.deadline = nil      -- 到期或本来就没有：清空并恢复
                self:resume(id)
            end
        end
    end
end

-- 获取协程状态
-- @param id: 协程ID
-- @return: 状态字符串
function CoroutineScheduler:getStatus(id)
    local info = coroutines[id]
    if not info then
        return "not_found"
    end
    return info.status
end

-- 获取当前运行的协程ID
-- @return: 当前协程ID或nil
function CoroutineScheduler:getCurrentCoroutine()
    return currentCoroutine
end

--- 当前是否在**本调度器管理的**协程里运行
-- @return boolean
--
-- 与 `EngineAPI.coroutine.isRunning()` 的区别：后者只看 `coroutine.running()`
-- 是否为主线程；本函数看**本调度器的 currentCoroutine**。
-- 只有后者非 nil 时 `waitForTime` 才能安全 yield（否则会 error）。
function CoroutineScheduler:isInCoroutine()
    return currentCoroutine ~= nil
end

--- 等一帧（毫秒）——**协程感知的阻塞替代品**
--
-- @param ms number 毫秒
-- @param fallback function|nil 非协程上下文时的退路（通常是 lib.Delay）
--
-- **为什么需要这个 helper**：
--   script 层的帧率控制模式是
--   `t1=GetTime(); 动作(); t2=GetTime(); lib.Delay(FRAME-(t2-t1))`，
--   其中 `lib.Delay` = `love.timer.sleep` → **真阻塞主线程**（实测 101ms）。
--
--   而这些 `instruct_*` 实际上是在**事件协程里**跑的
--   （`EventExecuteCoroutine` → `oldCallEventCoroutine` → `instruct_30`），
--   所以可以用 `waitForTime` 把阻塞换成协作式等待。
--
--   **但 `waitForTime` 在非协程上下文会 `error("Cannot yield from outside a coroutine")`**，
--   所以这里先判 `isInCoroutine()`，不在协程里就退回 `fallback`（阻塞但不崩）。
--
-- @return boolean 是否走了非阻塞路径
function CoroutineScheduler:waitFrame(ms, fallback)
    ms = tonumber(ms) or 0
    if ms <= 0 then return true end

    if self:isInCoroutine() then
        self:waitForTime(ms / 1000)
        return true
    end

    if type(fallback) == "function" then
        fallback(ms)
    end
    return false
end

-- 获取协程信息
-- @param id: 协程ID
-- @return: 协程信息表
function CoroutineScheduler:getInfo(id)
    return coroutines[id]
end

-- 获取所有协程列表
-- @return: 协程ID列表
function CoroutineScheduler:getAllCoroutines()
    local list = {}
    for id, _ in pairs(coroutines) do
        table.insert(list, id)
    end
    return list
end

-- 终止协程
-- @param id: 协程ID
function CoroutineScheduler:kill(id)
    coroutines[id] = nil
end

-- 清理所有协程
function CoroutineScheduler:clear()
    coroutines = {}
    currentCoroutine = nil
end

-- 重置调度器
function CoroutineScheduler:reset()
    self:clear()
    coroutineIdCounter = 0
    instance = nil
end

-- 检查协程是否活跃
-- @param id: 协程ID
-- @return: true 如果协程正在运行或挂起
function CoroutineScheduler:isActive(id)
    local info = coroutines[id]
    return info ~= nil and (info.status == "suspended" or info.status == "running")
end

-- 获取协程的结果
-- @param id: 协程ID
-- @return: 协程的结果，如果协程未完成或不存在则返回nil
function CoroutineScheduler:getResult(id)
    local info = coroutines[id]
    if not info then
        return nil
    end
    return info.result
end

-- 包装函数为协程
-- @param fn: 要包装的函数
-- @return: 返回一个可以启动协程的函数
function CoroutineScheduler:wrap(fn)
    return function(...)
        local id = self:create(fn)
        return self:start(id, ...)
    end
end

return CoroutineScheduler
