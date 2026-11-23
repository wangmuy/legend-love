-- input_manager.lua
-- 输入管理模块
-- 提供事件驱动的输入处理，替代阻塞式GetKey
-- 纯事件驱动架构：按键事件进入队列，getKey从队列消费

local InputManager = {}
InputManager.__index = InputManager

-- 获取时间（秒）
local function getTimeSeconds()
    return EngineAPI.time.getTimeSeconds()
end

-- 事件队列（环形缓冲区）
local eventQueue = {}
local queueHead = 1
local queueTail = 1
local maxQueueSize = 64

-- 鼠标事件队列（REQ-MS1-5）
--
-- **独立于键盘队列**，不混在一起。原因有两个：
--
--   ① 若混入同一队列，getKey() 会把鼠标事件当按键返回
--      （鼠标事件没有 key 字段，会返回 nil 或 x 坐标），
--      污染全仓 20+ 处 lib.GetKey() 的调用点，风险全在既有功能上。
--
--   ② 鼠标按下是【状态】不是【事件】（love.mouse.isDown 按住期间持续 true），
--      必须在 love.mousepressed 回调里入队，否则一次点击会触发几十次。
--
-- 事件形状：
--   { type = "pressed"|"released", x = number, y = number,
--     button = number, time = number }
local mouseQueue = {}
local mouseHead = 1
local mouseTail = 1
local maxMouseQueueSize = 64

-- 按键状态（用于判断是否按住）
local keyStates = {}

-- ---------------------------------------------------------------------------
-- 动作事件队列（input-action-layer Task 1）
-- ---------------------------------------------------------------------------
-- 与键队列、鼠标队列**三队列并存**，互不干扰：
--
--   eventQueue  → getKey()         整数 VK（迁移期兼容，36 处调用点仍在用）
--   mouseQueue  → getMouseEvent()  原始鼠标事件（pollMouse/pollHover 在用）
--   actionQueue → getAction()      语义动作 + provenance（新契约）
--
-- 为什么单独一条队列而不是把动作塞进 eventQueue：
--   ① getKey() 返回整数、getAction() 返回字符串，混在一起就得靠类型判断猜，
--      这是「同一份数据两种形状」的老坑（synthetic 脏标记就是这么来的）。
--   ② 动作事件带 source，而 getKey 的消费方（地图主循环等）必须能按 source
--      过滤（ADR-3 的核心）。键队列没有这个字段，硬塞会污染 36 处调用点。
--
-- 事件结构（见 input_actions.lua 的 EVENT_KEYS）：
--   { action, source, value, char, position, index, ray, time }
local actionQueue = {}
local actionHead = 1
local actionTail = 1
local maxActionQueueSize = 64

-- 输入禁用标志
InputManager.disableInput = false

-- 按键重复配置
local keyRepeatEnabled = false
local keyRepeatDelay = 0.3   -- 首次重复延迟（秒）
local keyRepeatInterval = 0.04  -- 重复间隔（秒）
local keyRepeatTimers = {}

-- 按键映射表
local baseKeyMap = {
    ["escape"] = 27,
    [" "] = 32,
    ["space"] = 32,
    ["return"] = 13,
    ["backspace"] = 8,
    ["up"] = 1073741906,
    ["down"] = 1073741905,
    ["left"] = 1073741904,
    ["right"] = 1073741903,
}

local function initKeyMap()
    local km = {}
    for k, v in pairs(baseKeyMap) do
        km[k] = v
    end
    if VK_Y then km["y"] = VK_Y end
    if VK_N then km["n"] = VK_N end
    return km
end

--- LÖVE 键名 → SDL keycode（动作事件带 keyCode 用）
--
-- 与 initKeyMap 的区别：initKeyMap 每次新建一张表（热路径别用），
-- 这里只在「按键产生动作」时查一次，且只查一个键。
--
-- 未映射的键（字母等）返回该键的 ASCII 码（LÖVE 的单字符键名本身就是字符）。
-- 这样 `AutoMove` 的 drain 对字母键也能工作。
local function gameKeyOf(loveKeyName)
    if type(loveKeyName) ~= "string" then return nil end
    local km = initKeyMap()
    local code = km[loveKeyName]
    if code then return code end
    -- 单字符键名（"y" / "n" / "a"）→ ASCII
    if #loveKeyName == 1 then
        return loveKeyName:byte(1)
    end
    return nil
end

local instance = nil

function InputManager.getInstance()
    if not instance then
        instance = setmetatable({}, InputManager)
    end
    return instance
end

function InputManager:init()
    eventQueue = {}
    queueHead = 1
    queueTail = 1
    keyStates = {}
    keyRepeatTimers = {}
    mouseQueue = {}
    mouseHead = 1
    mouseTail = 1
    actionQueue = {}
    actionHead = 1
    actionTail = 1
end

-- 添加事件到队列
local function enqueueEvent(event)
    local nextTail = queueTail + 1
    if nextTail > maxQueueSize then
        nextTail = 1
    end
    
    if nextTail == queueHead then
        queueHead = queueHead + 1
        if queueHead > maxQueueSize then
            queueHead = 1
        end
    end
    
    eventQueue[queueTail] = event
    queueTail = nextTail
end

-- 从队列取出事件
local function dequeueEvent()
    if queueHead == queueTail then
        return nil
    end
    
    local event = eventQueue[queueHead]
    eventQueue[queueHead] = nil
    local oldHead = queueHead
    queueHead = queueHead + 1
    if queueHead > maxQueueSize then
        queueHead = 1
    end
    
    return event
end

-- 查看队列头部事件但不移除
local function peekEvent()
    if queueHead == queueTail then
        return nil
    end
    return eventQueue[queueHead]
end

-- 处理love.keypressed事件
--
-- 两条产出（input-action-layer）：
--   ① 键队列：gameKey 在 baseKeyMap 里时入队（迁移期 36 处 getKey 调用点在用）
--   ② 动作队列：经 InputBindings.resolveKey 映射成 ui.* 或游戏私有动作
--
-- 为什么②不能只对 baseKeyMap 内的键生效：
--   baseKeyMap 只有 9 个键，字母全部落在白名单外。若只在白名单内产动作，
--   输入框永远收不到 ui.text（这是历史缺陷的直接原因）。
--   所以②对所有键都跑一次，映射失败（如 f12）才静默跳过。
function InputManager:onKeyPressed(key, scancode, isrepeat)
    -- 忽略 love.keyboard 的 repeat 事件，使用自己的定时器
    if isrepeat then
        return
    end

    -- ② 动作队列（对所有键生效，见上方注释）
    local okIB, InputBindings = pcall(require, "framework.input_bindings")
    if okIB and InputBindings and InputBindings.resolveKey then
        local action, char = InputBindings.resolveKey(key)
        if action then
            InputManager.enqueueAction({
                action = action,
                source = "key",
                char = char,
                -- 原始键码：AutoMove 的 drain 机制需要「具体哪个键」
                -- （`ui.accept` 同时对应 space/return，光看动作名分不出）
                keyCode = gameKeyOf(key),
            })
        end
    end

    -- ① 键队列（仅 baseKeyMap 内的键）
    local km = initKeyMap()
    local gameKey = km[key]

    if not gameKey then
        return
    end
    
    -- 添加按键按下事件到队列
    enqueueEvent({
        type = "pressed",
        key = gameKey,
        time = getTimeSeconds()
    })
    
    -- 更新按键状态
    keyStates[gameKey] = true
    
    -- 初始化重复计时器
    if keyRepeatEnabled then
        keyRepeatTimers[gameKey] = {
            pressedTime = getTimeSeconds(),
            lastRepeatTime = getTimeSeconds(),
            repeatCount = 0
        }
    end
end

-- 处理love.keyreleased事件
function InputManager:onKeyReleased(key, scancode)
    local km = initKeyMap()
    local gameKey = km[key]
    
    if not gameKey then
        return
    end
    
    -- 不在队列中添加释放事件，因为游戏不需要处理释放事件
    -- 只有按下和重复事件才需要处理
    
    -- 更新按键状态
    keyStates[gameKey] = false
    keyRepeatTimers[gameKey] = nil

    -- REQ-MS3-5：自动移动被按键中断后，松开该键才解除 drain
    --
    -- 用 pcall 是因为 auto_move 可能未加载（如纯输入测试），
    -- 且这里绝不能因 drain 逻辑抛错而丢按键状态。
    pcall(function()
        local AutoMove = require("framework.auto_move")
        if AutoMove and AutoMove.onKeyReleased then
            AutoMove.onKeyReleased(gameKey)
        end
    end)
end

-- 惰性引用 InputBindings（顶层 require 会与 input_bindings → input_actions 形成环）
local InputBindingsForRepeat
local function getBindingsForRepeat()
    if InputBindingsForRepeat == nil then
        local ok, mod = pcall(require, "framework.input_bindings")
        InputBindingsForRepeat = ok and mod or false
    end
    return InputBindingsForRepeat or nil
end

-- 更新按键重复
function InputManager:update(dt)
    if not keyRepeatEnabled then
        return
    end

    InputBindingsForRepeat = getBindingsForRepeat()
    
    local currentTime = getTimeSeconds()
    
    for gameKey, timer in pairs(keyRepeatTimers) do
        if keyStates[gameKey] then
            local elapsed = currentTime - timer.pressedTime
            local timeSinceLastRepeat = currentTime - timer.lastRepeatTime
            
            local shouldRepeat = false
            if timer.repeatCount == 0 then
                shouldRepeat = elapsed >= keyRepeatDelay
            else
                shouldRepeat = timeSinceLastRepeat >= keyRepeatInterval
            end
            
            if shouldRepeat then
                -- 添加重复事件到队列
                enqueueEvent({
                    type = "repeat",
                    key = gameKey,
                    time = currentTime
                })

                -- **动作队列也要发 repeat**（input-action-layer Task 5 的前置）
                --
                -- 为什么必须补：菜单长按连翻、状态页长按翻页都靠 repeat 事件。
                -- 原来的 repeat 只进键队列 → 迁移到动作队列后这些功能会静默失效
                -- （按一下能动、按住不动），属于「迁移后才暴露」的坑。
                --
                -- 用反向映射把 gameKey（SDL keycode）转回动作名。
                if InputBindingsForRepeat then
                    local action = InputBindingsForRepeat.actionForKeyCode(gameKey)
                    if action then
                        InputManager.enqueueAction({
                            action = action,
                            source = "key",
                            -- repeat 与 pressed 用同一 action；消费者本来就
                            -- 逐个处理事件，不区分首次/重复
                            keyCode = gameKey,
                        })
                    end
                end

                timer.repeatCount = timer.repeatCount + 1
                timer.lastRepeatTime = currentTime
            end
        end
    end
end

-- 获取当前按键（消费队列中的事件）
--
-- **按来源过滤**（input-action-layer ADR-3，取代旧的 synthetic 脏标记）
--
-- 注入的键（enqueueKeyEvent）只服务于「协程等键」：
--   对话推进 / 场景名关闭 / 物品选中 / 状态页翻页
-- 它们消费键的路径是 scheduler 的 _peekKeyInternal（绕过 disableInput）。
--
-- **主循环的 getKey() 必须看不到它们**，否则会当成玩家真按了键：
--   实测 bug（用户报告）：河洛客栈站在店小二旁，鼠标悬停物品格
--   → 悬停注入 VK_SPACE 唤醒物品协程
--   → 同一帧 GAME_SMAP.update 的 getKey() 也读到这个 SPACE
--   → 走进 SPACE 分支「触发面向 tile 的事件」→ 冒出店小二对话
--
-- 为什么改成"按 source 过滤"而不是继续用 synthetic：
--   synthetic 是「我不告诉你来源，只打个脏标记」，消费方没法据此决策。
--   source 是明确契约：主循环拒绝 source=="mouse"/"pad"/"touch" 的事件，
--   因为它们不是「玩家敲键盘」。
--
-- 兼容：enqueueKeyEvent 产生的 source="compat" 也在此被跳过（历史行为不变）。
function InputManager:getKey()
    if InputManager.disableInput then
        return -1
    end

    while true do
        local event = dequeueEvent()
        if not event then
            return -1
        end
        -- 只接受「玩家真按键盘」的键事件。
        -- 无 source 字段的历史事件（测试直接 enqueueEvent 造的）视为键盘。
        local src = event.source
        if src == nil or src == "key" then
            return event.key
        end
        -- compat（enqueueKeyEvent 注入）/ mouse / pad / touch：跳过
    end
end

--------------------------------------------------------------------
-- 鼠标事件队列（REQ-MS1-5）
--
-- 与键盘队列完全独立：
--   getKey()        → 只消费键队列（既有 20+ 处调用零影响）
--   getMouseEvent() → 只消费鼠标队列
--
-- 不做跨队列的严格时序保证：实际游戏中不会出现「同一帧内既按键又点击」
-- 且顺序有意义的场景。若将来需要，再引入统一序列号（见 ADR-MS-004）。
--------------------------------------------------------------------

--- 入队一个鼠标事件（由 love.mousepressed / mousereleased 回调调用）
--
-- 容量上限与键盘队列同策略：满了丢最旧的，不阻塞。
--
-- @param event table { type, x, y, button, time }
-- @return boolean 是否入队成功
function InputManager.enqueueMouseEvent(event)
    if type(event) ~= "table" then return false end

    local nextTail = mouseTail + 1
    if nextTail > maxMouseQueueSize then
        nextTail = 1
    end
    if nextTail == mouseHead then
        -- 满了：丢掉最旧的一个
        mouseHead = mouseHead + 1
        if mouseHead > maxMouseQueueSize then
            mouseHead = 1
        end
    end
    if event.time == nil then
        event.time = getTimeSeconds()
    end
    mouseQueue[mouseTail] = event
    mouseTail = nextTail
    return true
end

--- 取出一个鼠标事件（消费）
--
-- 命名注意：内部实现叫 `_dequeueMouseEvent`，**不能**直接叫
-- `InputManager.getMouseEvent` 再写一个 `InputManager:getMouseEvent` 转发 ——
-- `:` 语法是 `function InputManager.getMouseEvent(self)` 的糖，
-- 会覆盖同名点方法，于是 `InputManager.getMouseEvent()` 调到自己，
-- 且是尾调用不增长栈 → 永久死循环（不报栈溢出，只是卡住）。
--
-- @return table|nil
function InputManager._dequeueMouseEvent()
    if mouseHead == mouseTail then
        return nil
    end
    local event = mouseQueue[mouseHead]
    mouseQueue[mouseHead] = nil
    mouseHead = mouseHead + 1
    if mouseHead > maxMouseQueueSize then
        mouseHead = 1
    end
    return event
end

--- 查看鼠标队列中的下一个事件但不消费
-- @return table|nil
function InputManager.peekMouseEvent()
    if mouseHead == mouseTail then
        return nil
    end
    return mouseQueue[mouseHead]
end

--- 清空鼠标队列（场景切换等）
function InputManager.clearMouseQueue()
    mouseQueue = {}
    mouseHead = 1
    mouseTail = 1
end

--- 取鼠标事件（实例方法）
-- @return table|nil
function InputManager:getMouseEvent()
    return InputManager._dequeueMouseEvent()
end

--------------------------------------------------------------------
-- 动作事件队列（input-action-layer Task 1）
--
-- 对外入口：
--   enqueueAction(ev)    入队（带 source 的语义事件）
--   getActionEvent()     取出完整事件（消费方需要 source/char/position 时用）
--   getAction()          取出动作名（消费）
--   peekActionEvent()    查看事件不消费
--   peekAction()         查看动作名不消费
--   clearActionQueue()   清空
--
-- 与 getKey() 的关系：**并存**。迁移期 36 处业务代码仍用 getKey()，
-- 新代码用 getAction()，两者读不同队列，互不挤占。
--------------------------------------------------------------------

--- 入队一个动作事件
--
-- 最小校验：action 必须非空字符串、source 必须合法。
-- 校验失败返回 false 而不抛错 —— 输入路径绝不因一个坏事件崩主循环。
--
-- @param event table { action, source, value?, char?, position?, index?, ray? }
-- @return boolean
function InputManager.enqueueAction(event)
    if type(event) ~= "table" then return false end
    if type(event.action) ~= "string" or event.action == "" then return false end

    local okIA, InputActions = pcall(require, "framework.input_actions")
    local source = event.source or "compat"
    if okIA and InputActions and InputActions.isValidSource
        and not InputActions.isValidSource(source) then
        return false
    end

    local nextTail = actionTail + 1
    if nextTail > maxActionQueueSize then
        nextTail = 1
    end
    if nextTail == actionHead then
        actionHead = actionHead + 1
        if actionHead > maxActionQueueSize then
            actionHead = 1
        end
    end

    -- 只保留白名单字段：把调用方误传的脏字段（如历史遗留的 synthetic）剔掉，
    -- 避免「动作事件里还藏着旧契约」这种隐性回归。
    local clean = {
        action = event.action,
        source = source,
        value = event.value,
        char = event.char,
        position = event.position,
        index = event.index,
        ray = event.ray,
        time = event.time or getTimeSeconds(),
        -- 产生该动作的原始键码（仅键盘来源有；见 input_actions.EVENT_KEYS 注释）
        keyCode = event.keyCode,
    }
    actionQueue[actionTail] = clean
    actionTail = nextTail
    return true
end

--- 取出一个完整的动作事件（消费）
-- @return table|nil
function InputManager.getActionEvent()
    if actionHead == actionTail then
        return nil
    end
    local event = actionQueue[actionHead]
    actionQueue[actionHead] = nil
    actionHead = actionHead + 1
    if actionHead > maxActionQueueSize then
        actionHead = 1
    end
    return event
end

--- 取出一个动作名（消费）
-- @return string|nil
function InputManager.getAction()
    local event = InputManager.getActionEvent()
    if event then return event.action end
    return nil
end

--- 取出一个**只来自键盘**的动作（迁移期对齐 `getKey()` 的 source 过滤）
--
-- # 为什么必须有这个函数（不是可以直接用 getAction）
--
-- `getKey()` 会**跳过** `source ~= "key"` 的事件 —— 这是 ADR-3 修的
-- 「河洛客栈站店小二旁，鼠标悬停物品格 → 冒出店小二对话」：
--
-- ```
-- 悬停注入 VK_SPACE 唤醒物品协程
-- → 同一帧 GAME_SMAP.update 的 getKey() 也读到这个 SPACE
-- → 走进 SPACE 分支「触发面向 tile 的事件」→ 冒出对话
-- ```
--
-- 而 `getAction()` **不看 source**。所以「地图主循环」这类
-- 「只能由玩家真按键驱动」的地方，直接换成 `getAction()` 会让那个 bug 回归。
--
-- 本函数是 `getKey()` 的**语义镜像**：只消费 `source == "key"` 的动作，
-- 其余（mouse / pad / touch / compat）**留在队列里**给别的消费方
-- （协程等待、对话推进）—— 与 getKey 跳过而不丢弃的行为一致。
--
-- @return string|nil 动作名；没有键盘动作时返回 nil
function InputManager.getActionKeyOnly()
    if InputManager.disableInput then
        return nil
    end

    -- 从队头向后扫，找到第一个 source=="key" 的动作并**就地摘除**
    -- （不能用「弹出再放回」，那会把非键盘事件挪到队尾，破坏 FIFO 顺序）
    local i = actionHead
    while i ~= actionTail do
        local event = actionQueue[i]
        if event and event.source == "key" then
            local name = event.action
            -- 就地摘除：把 i 之后的元素前移一位（队列容量 64，代价可忽略）
            local j = i
            while j ~= actionTail do
                local nextIdx = j + 1
                if nextIdx > maxActionQueueSize then nextIdx = 1 end
                actionQueue[j] = actionQueue[nextIdx]
                j = nextIdx
            end
            -- actionTail 前移一位（相当于少了一个元素）
            local newTail = actionTail - 1
            if newTail < 1 then newTail = maxActionQueueSize end
            actionQueue[newTail] = nil
            actionTail = newTail
            return name
        end
        i = i + 1
        if i > maxActionQueueSize then i = 1 end
        -- 防死循环：环形队列最多 maxActionQueueSize 个元素
        if i == actionHead then break end
    end
    return nil
end

--- 取出一个**只来自键盘**的完整动作事件（消费）
--
-- 与 `getActionKeyOnly()` 的区别：这个返回**整个事件表**（含 `keyCode`），
-- 供需要「具体哪个键」的消费方用（典型：AutoMove 的 drain 机制）。
--
-- 与 `getActionEvent()` 的区别：那个不过滤 source。
--
-- @return table|nil
function InputManager.getActionEventKeyOnly()
    if InputManager.disableInput then
        return nil
    end

    local i = actionHead
    while i ~= actionTail do
        local event = actionQueue[i]
        if event and event.source == "key" then
            -- 就地摘除（保持其余事件的相对顺序）
            local j = i
            while j ~= actionTail do
                local nextIdx = j + 1
                if nextIdx > maxActionQueueSize then nextIdx = 1 end
                actionQueue[j] = actionQueue[nextIdx]
                j = nextIdx
            end
            local newTail = actionTail - 1
            if newTail < 1 then newTail = maxActionQueueSize end
            actionQueue[newTail] = nil
            actionTail = newTail
            return event
        end
        i = i + 1
        if i > maxActionQueueSize then i = 1 end
        if i == actionHead then break end
    end
    return nil
end

--- 查看下一个事件（不消费）
-- @return table|nil
function InputManager.peekActionEvent()
    if actionHead == actionTail then
        return nil
    end
    return actionQueue[actionHead]
end

--- 查看下一个动作名（不消费）
-- @return string|nil
function InputManager.peekAction()
    local event = InputManager.peekActionEvent()
    if event then return event.action end
    return nil
end

--- 清空动作队列
function InputManager.clearActionQueue()
    actionQueue = {}
    actionHead = 1
    actionTail = 1
end

--- 当前动作队列长度（测试用）
function InputManager.getActionQueueSize()
    if actionTail >= actionHead then
        return actionTail - actionHead
    end
    return maxActionQueueSize - actionHead + actionTail
end

--- 往键队列注入一个按键事件（供鼠标等非键盘输入使用）
--
-- 用途（REQ-MS2-6）：对话期间鼠标点击要等价于空格/Enter。
--
-- 为什么不给每条对话路径单独加鼠标处理：
--   对话推进有三条独立实现，各自都在等按键
--     talk_async:160         InputAsync.WaitKeyCoroutine()
--     async_dialog:246       VK_RETURN / VK_SPACE
--     coroutine_scheduler    update() 里 _peekKeyInternal() 偷看队列
--   逐条加鼠标分支会漏、会重复。注入一个键事件则**复用全部既有逻辑**：
--   键盘与鼠标走的是同一条路径，行为必然一致。
--
-- 注意：注入的事件进的是**键队列**，所以
--   * getKey() 能取到（菜单、地图逻辑）
--   * _peekKeyInternal() 也能取到（对话等待，绕过 disableInput）
-- 这正是我们要的 —— 对话期间 disableInput 可能为 true，但对话仍在等键。
--
-- @param key number 按键码（如 VK_SPACE / VK_RETURN）
-- @return boolean 是否入队
function InputManager.enqueueKeyEvent(key)
    if type(key) ~= "number" then return false end
    enqueueEvent({
        type = "pressed",
        key = key,
        source = "compat",    -- ADR-3：用 provenance 取代 synthetic
        time = getTimeSeconds(),
    })
    return true
end

-- 查看队列中的下一个按键但不消费
function InputManager:peekKey()
    if InputManager.disableInput then
        return -1
    end
    
    local event = peekEvent()
    if event then
        return event.key
    end
    
    return -1
end

-- 内部方法：查看动作队列里下一个**任意来源**的动作，不消费、绕过 disableInput
--
-- 这是 `_peekKeyInternal()` 的动作版镜像。为什么两者都需要：
--
--   对话推进（`scheduler:307`）/ 场景名关闭（`input_async:46`）走的是
--   「偷看队列」而不是「消费」—— 因为它们要在**不确定**是否该处理时
--   先看有没有输入（例如对话期间 disableInput=true，但对话本身仍在等）。
--
--   而且它们接受**任意来源**（鼠标点击推进对话是合法行为），
--   这正是 `_peekKeyInternal` 不过滤 source 的原因。
--
-- @return string|nil 动作名
function InputManager:_peekActionInternal()
    local event = InputManager.peekActionEvent()
    if event then
        return event.action
    end
    return nil
end

-- 内部方法：查看队列中的下一个按键但不消费（绕过 disableInput）
function InputManager:_peekKeyInternal()
    local event = peekEvent()
    if event then
        return event.key
    end
    return -1
end

-- 内部方法：获取按键并消费（绕过 disableInput）
function InputManager:_getKeyInternal()
    local event = dequeueEvent()
    if event then
        return event.key
    end
    return -1
end

-- 清除当前按键状态和队列
function InputManager:clearCurrentKey()
    eventQueue = {}
    queueHead = 1
    queueTail = 1
    keyStates = {}
    keyRepeatTimers = {}
end

-- 查询按键是否被按住
function InputManager:isKeyDown(gameKey)
    return keyStates[gameKey] == true
end

-- 处理所有待处理的事件（兼容接口）
function InputManager:processEvents()
    -- 在事件驱动架构中，事件已经在队列中
    -- 此方法不需要做任何事情
end

-- 获取所有事件（用于测试）
function InputManager:pollEvents()
    local events = {}
    while queueHead ~= queueTail do
        local event = dequeueEvent()
        if event then
            table.insert(events, event)
        else
            break
        end
    end
    return events
end

-- 设置按键重复
function InputManager:setKeyRepeat(enabled)
    EngineAPI.debug.log(string.format("InputManager:setKeyRepeat: enabled=%s", tostring(enabled)))
    keyRepeatEnabled = enabled
    -- 不使用 love.keyboard 的重复，使用我们自己的定时器机制
end

-- 设置按键重复参数（毫秒）
function InputManager:setKeyRepeatParams(delay, interval)
    keyRepeatDelay = delay or 0.3
    keyRepeatInterval = interval or 0.04
end

-- 清空所有状态
function InputManager:clear()
    eventQueue = {}
    queueHead = 1
    queueTail = 1
    keyStates = {}
    keyRepeatTimers = {}
end

-- 重置
function InputManager:reset()
    self:clear()
    instance = nil
end

-- 获取按键重复是否启用
function InputManager:isKeyRepeatEnabled()
    return keyRepeatEnabled
end

-- 获取按键映射表（用于测试）
function InputManager:getKeyMap()
    return initKeyMap()
end

-- 注册自定义按键映射
function InputManager:registerKey(key, gameKey)
    baseKeyMap[key] = gameKey
end

function InputManager:getQueueSize()
    if queueTail >= queueHead then
        return queueTail - queueHead
    else
        return maxQueueSize - queueHead + queueTail
    end
end

return InputManager
