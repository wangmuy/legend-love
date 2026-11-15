-- auto_move.lua
-- 点击寻路的自动移动状态机（REQ-MS3-3 / REQ-MS3-4 / REQ-MS3-5）
--
-- 设计（ADR-MS3-004）：
--   AUTO_MOVING 是 GAME_MMAP / GAME_SMAP **内部**的子状态，
--   用 JY.AutoMove 表示，不新增 GAME_* 常量。
--   原因：JY.Status 的语义是「玩家在哪个场景」，自动移动不是场景。
--
-- 性能（REQ-MS3-4）：
--   A* 只在点击瞬间跑一次；update 每帧只做 O(1) 的队列消费。
--
-- 中断（REQ-MS3-5 / ADR-MS3-005）：
--   按键 → 中断 + 吃掉全部 repeat 直到 keyreleased（不响应为方向移动）
--   事件 → 中断 + 不恢复剩余路径
--   进场景 → 中断 + 清空路径

local AutoMove = {}

-- drain 超时（防止窗口失焦时收不到 keyreleased 而永久卡住）
AutoMove.DRAIN_TIMEOUT_MS = 2000

--- 每走一格的最小间隔（毫秒）
--
-- 为什么必须节流（用户实测报告）：一开始没有节流，`update` 每帧走一格，
-- 60fps 下 = 60 格/秒，比原版快 3 倍，看起来像「瞬移」——
-- 玩家反馈「点一下，人一下子跑很远、直接跑出地图」。
--
-- 取值依据：
--   原版主循环 CC.Frame = 50ms/帧，按键每帧走一格 → 20 格/秒
--   本移植的按键重复间隔 40ms → 25 格/秒
--   自动移动取 50ms（20 格/秒）= 与按住方向键手感一致，不突兀
--
-- 注意：这是「最小间隔」，不是「每帧」——路径推进仍由 update 驱动，
-- 只是未到间隔时不推进。所以低帧率下不会变慢，高帧率下不会变快。
AutoMove.STEP_INTERVAL_MS = 50

----------------------------------------------------------------------
-- 状态
----------------------------------------------------------------------

-- 路径走完时暂存「到达动作」（REQ-MS3-6）
--
-- 为什么要暂存：advance() 走完最后一步会清空 JY.AutoMove，
-- 而调用方紧接着才调 takeOnArrive()。若不暂存，takeOnArrive 读到的
-- 已经是 nil —— 表现为「走到门口却进不去」（实测踩过）。
--
-- 注意：必须在 takeOnArrive 之前**声明为 local**。
-- 若写成「在使用处之后才 local」，前面的引用会被解析成全局变量（nil），
-- 于是赋值与读取操作的是两个不同的变量（这个坑踩过）。
local pendingOnArrive = nil

local function nowMs()
    local EngineAPI = rawget(_G, "EngineAPI")
    if EngineAPI and EngineAPI.time and EngineAPI.time.getTime then
        local ok, t = pcall(EngineAPI.time.getTime)
        if ok and type(t) == "number" then return t end
    end
    return os.clock() * 1000
end

--- 取当前自动移动状态
-- @return table|nil
function AutoMove.get()
    local JY = rawget(_G, "JY")
    return JY and JY.AutoMove or nil
end

--- 是否正在自动移动
-- @return boolean
function AutoMove.isActive()
    local s = AutoMove.get()
    return s ~= nil and type(s.path) == "table" and #s.path > 0
end

--- 开始自动移动
-- @param path table 路径点数组（含起点）
-- @param mapKind string "MMAP" | "SMAP"
-- @param opts table|nil { skipFirst = boolean }  默认跳过起点（已在起点上）
function AutoMove.start(path, mapKind, opts)
    if type(path) ~= "table" or #path < 2 then
        return false    -- 路径只有起点 → 无需移动
    end
    local JY = rawget(_G, "JY")
    if not JY then return false end

    opts = opts or {}
    -- 默认跳过第 1 个点（它就是当前位置）
    local startIndex = 2
    if opts.skipFirst == false then startIndex = 1 end

    JY.AutoMove = {
        path     = path,
        index    = startIndex,
        mapKind  = mapKind or "MMAP",
        startedMs = nowMs(),
        -- 允许第一次立即走（不等 50ms），点击后立刻有反馈
        lastStepMs = nowMs() - (AutoMove.STEP_INTERVAL_MS or 50),
        -- 到达后要做的事（REQ-MS3-6）
        --   { kind = "interact", tx =, ty = }  → 走完就面朝目标并触发
        --
        -- **不能**在点击时直接触发：人会瞬移式站在原地进场景/对话，
        -- 看起来像 bug。必须等真的走到旁边。
        onArrive = opts.onArrive,
    }
    return true
end

--- 取「到达后待执行的动作」，并清除它（保证只执行一次）
-- @return table|nil
function AutoMove.takeOnArrive()
    -- 优先取暂存区（路径刚走完，advance 已把状态清空）
    if pendingOnArrive then
        local a = pendingOnArrive
        pendingOnArrive = nil
        return a
    end
    -- 兜底：路径还在（中途被调用）
    local s = AutoMove.get()
    if not s then return nil end
    local a = s.onArrive
    s.onArrive = nil
    return a
end

--- 是否到了可以走下一格的时刻（步进节流）
-- @return boolean
function AutoMove.readyToStep()
    local s = AutoMove.get()
    if not s then return false end
    local interval = AutoMove.STEP_INTERVAL_MS or 50
    return (nowMs() - (s.lastStepMs or 0)) >= interval
end

--- 标记「刚刚走了一步」，重置节流计时
function AutoMove.markStep()
    local s = AutoMove.get()
    if s then s.lastStepMs = nowMs() end
end

--- 停止自动移动（可选清空 drain）
-- @param opts table|nil { keepDrain = boolean }
function AutoMove.stop(opts)
    pendingOnArrive = nil
    pendingEventCheck = nil
    opts = opts or {}
    local JY = rawget(_G, "JY")
    if not JY then return end
    JY.AutoMove = nil
    if not opts.keepDrain then
        -- 默认保留 drain（由中断场景决定是否设置）
    end
end

--- 取下一个要走的路径点（不推进索引；由调用方在真正移动后调 advance）
-- @return table|nil { x =, y = }
function AutoMove.peek()
    local s = AutoMove.get()
    if not s or not s.path then return nil end
    return s.path[s.index]
end

--- 推进到下一个路径点；走完则清除状态
-- @return boolean 是否还有剩余路径
function AutoMove.advance()
    local s = AutoMove.get()
    if not s then return false end
    s.index = s.index + 1
    if s.index > #s.path then
        -- 先把到达动作搬到模块级，再清状态
        pendingOnArrive = s.onArrive
        local JY = rawget(_G, "JY")
        if JY then JY.AutoMove = nil end
        return false
    end
    return true
end

--- 剩余步数（测试与调试用）
-- @return number
function AutoMove.remaining()
    local s = AutoMove.get()
    if not s or not s.path then return 0 end
    return math.max(0, #s.path - s.index + 1)
end

----------------------------------------------------------------------
-- 中断语义（REQ-MS3-5）
----------------------------------------------------------------------

--- 按键中断：停止移动 + 设置 drain 吃掉后续 repeat
-- @param key number 被吃掉的键码
function AutoMove.interruptByKey(key)
    local JY = rawget(_G, "JY")
    if not JY then return end
    JY.AutoMove = nil
    JY.InputDrain = { key = key, startMs = nowMs() }
end

--- 判断「踩到这一格触发的事件」是否真的会做事
--
-- 用途（REQ-MS3-7）：路过事件若已失效（一次性事件、脚本自带"已触发"判断），
-- 就不该中断自动移动 —— 否则玩家点远处只走到门口就停住。
--
-- 判据与 event_executor 的解析链一致：
--   ① 新式事件（JY.SceneNewEventFunction[SubScene] 存在）→ 无法静态判断，
--      保守返回 true（宁可中断，不可让自动移动穿透剧情）
--   ② 旧式事件：eventnum = GetD(scene, d, 4)（flag=3 路过）
--      eventnum > 0 才算有事件
--
-- **注意**：这里只能判断「有没有挂事件」，无法判断「事件内部会不会
-- 自己 return」（那只有执行后才知道）。所以它解决的是「tile 上的
-- 事件数据被清空/改成 0」这一类 —— 正是河洛客栈门槛的情况。
--
-- @param sceneId number
-- @param d number D* 编号
-- @return boolean
function AutoMove.eventWouldRun(sceneId, d)
    if type(d) ~= "number" or d < 0 then return false end

    local JY = rawget(_G, "JY")
    if not JY then return true end

    -- ① 新式事件：静态判断不了，保守认为会跑
    if JY.SceneNewEventFunction and JY.SceneNewEventFunction[sceneId] ~= nil then
        return true
    end

    -- ② 旧式事件：flag=3（路过）对应 GetD(...,4)
    local ok, eventnum = pcall(function() return GetD(sceneId, d, 4) end)
    if not ok or type(eventnum) ~= "number" then
        return true     -- 查不到就保守处理
    end
    return eventnum > 0
end

----------------------------------------------------------------------
-- 「事件是否真的在做事」的运行时判定（REQ-MS3-7）
--
-- 静态检查（eventWouldRun）只看 tile 上有没有挂事件号，无法判断
-- 「脚本内部自己 return」的情况。更可靠的判据来自执行时序：
--
--   EventExecuteSync → startEvent → scheduler:start
--     └─ 立刻 coroutine.resume
--        └─ EventExecuteCoroutine: JY.CurrentD = id
--           └─ 跑事件脚本
--           └─ JY.CurrentD = -1
--
-- 关键：**no-op 脚本不会 yield**，整段在同一帧内跑完，
-- CurrentD 设了又清，下一帧已经是 -1。
-- 真事件（对话/动画/等键）一定会 yield，CurrentD 保持 >= 0 跨帧。
--
-- 所以：调完 EventExecuteSync 后**下一帧**再看 CurrentD
--   >= 0 → 事件正在进行 → 应当已经中断，路径不该继续
--   == -1 → 事件什么都没做 → 路径继续走完
--
-- 这与「先假定要中断、发现没做事再恢复」相反：
-- 我们不能在中断后恢复（路径已丢），所以改成
-- 「先不中断，下一帧发现事件真的在跑才中断」。
----------------------------------------------------------------------

-- 等待判定的事件信息 { sceneId=, d=, mapKind= }
local pendingEventCheck = nil

--- 登记「刚触发了一个事件，下一帧确认它是否真在跑」
-- @param sceneId number
-- @param d number
function AutoMove.watchEvent(sceneId, d)
    pendingEventCheck = { sceneId = sceneId, d = d }
end

--- 若事件真的在跑，就中断自动移动（每帧调用）
--
-- @return boolean 是否中断了
function AutoMove.checkWatchedEvent()
    if not pendingEventCheck then return false end
    local info = pendingEventCheck
    pendingEventCheck = nil

    local JY = rawget(_G, "JY")
    if not JY then return false end

    -- 事件协程是否仍在进行（CurrentD 保持 >= 0 说明 yield 了）
    local running = (JY.CurrentD ~= nil and JY.CurrentD >= 0)
    if running then
        if AutoMove.isActive() then
            AutoMove.interruptByEvent()
            return true
        end
    end
    return false
end

--- 清空待判定状态（场景切换等）
function AutoMove.clearPendingEvent()
    pendingEventCheck = nil
end

--- 事件中断：停止移动，**不**设置 drain（事件本身要消费按键）
function AutoMove.interruptByEvent()
    local JY = rawget(_G, "JY")
    if not JY then return end
    JY.AutoMove = nil
end

--- 场景切换中断：停止移动 + 清空红闪
function AutoMove.interruptBySceneChange()
    local JY = rawget(_G, "JY")
    if not JY then return end
    JY.AutoMove = nil
    JY.InputDrain = nil
    pcall(function()
        local H = require("framework.mouse_hover")
        if H and H.clearFlash then H.clearFlash() end
    end)
end

--- 是否处于 drain 状态（吃掉按键直到松开）
-- @return boolean
function AutoMove.isDraining()
    local JY = rawget(_G, "JY")
    if not JY or not JY.InputDrain then return false end

    -- 超时保护：窗口失焦时收不到 keyreleased，避免永久卡住
    local elapsed = nowMs() - (JY.InputDrain.startMs or 0)
    if elapsed > AutoMove.DRAIN_TIMEOUT_MS then
        JY.InputDrain = nil
        return false
    end
    return true
end

--- 判断某个按键是否应被 drain 吃掉
-- @param key number
-- @return boolean true = 吃掉（不响应为方向移动）
function AutoMove.shouldDrainKey(key)
    if not AutoMove.isDraining() then return false end
    local JY = rawget(_G, "JY")
    local drainKey = JY.InputDrain.key
    -- 没有记录具体键（如外部强制设置）时吃掉所有方向键
    if drainKey == nil then return true end
    return drainKey == key
end

--- 收到 keyreleased 时解除 drain
-- @param key number
function AutoMove.onKeyReleased(key)
    local JY = rawget(_G, "JY")
    if not JY or not JY.InputDrain then return end
    if JY.InputDrain.key == nil or JY.InputDrain.key == key then
        JY.InputDrain = nil
    end
end

----------------------------------------------------------------------
-- 玩家可否行动（统一守卫）
--
-- 这是本次修复的核心：鼠标点击与自动移动**必须**与键盘遵守完全相同的
-- 冻结条件，否则会出现「对话期间还能点击移动主角」。
--
-- 既有代码的守卫本来就不一致（这是历史包袱）：
--   MMAP.update      只查 hasActiveMenu
--   SMAP.update 按键  查 disableInput + CurrentD
--   SMAP.update 贴图  查 动画 + talkActive + CurrentD   ← 三层最全
--
-- 鼠标作为**新的输入通道**，必须取三层里最严格的那一套，
-- 否则就是绕过既有的冻结机制。宁可多挡（少响应一次点击），
-- 不可漏挡（对话中角色乱走的后果严重得多）。
----------------------------------------------------------------------

--- 判断当前是否允许玩家主动行动（键盘/鼠标/自动移动）
--
-- 检查项（任一为真则禁止）：
--   ① 有活动菜单
--   ② InputManager.disableInput（动画/物品选择等显式阻塞）
--   ③ JY.CurrentD >= 0（事件/强制对话执行中）
--   ④ TalkAsync.getCurrentTalk() ~= nil（对话框显示中 —— 兜底闸）
--   ⑤ JY.AnimationState.active（动画播放中）
--   ⑥ JY.Status 不是 MMAP / SMAP
--
-- @return boolean
function AutoMove.canPlayerAct()
    local JY = rawget(_G, "JY")
    if not JY then return false end

    -- ⑥ 状态
    local GAME_MMAP = rawget(_G, "GAME_MMAP")
    local GAME_SMAP = rawget(_G, "GAME_SMAP")
    if JY.Status ~= GAME_MMAP and JY.Status ~= GAME_SMAP then
        return false
    end

    -- ① 有菜单
    local okMenu, MenuAsync = pcall(require, "framework.menu_async")
    if okMenu and MenuAsync and MenuAsync.hasActiveMenu
        and MenuAsync.hasActiveMenu() then
        return false
    end

    -- ② 显式阻塞
    local okIM, InputManager = pcall(require, "framework.input_manager")
    if okIM and InputManager and InputManager.disableInput then
        return false
    end

    -- ③ 事件执行中
    if JY.CurrentD and JY.CurrentD >= 0 then
        return false
    end

    -- ④ 对话框显示中（兜底：CurrentD 可能被内联事件提前复位）
    --
    -- 两个来源都要查：
    --   TalkAsync   打字机对话（npc 对话）
    --   AsyncDialog 消息框/是否框/选择框（"是否真的要离开游戏" 等）
    -- 只查前者会漏掉后者 —— 消息框弹出时鼠标仍能点击地图。
    local okTalk, TalkAsync = pcall(require, "framework.talk_async")
    if okTalk and TalkAsync and TalkAsync.getCurrentTalk then
        local okGet, cur = pcall(TalkAsync.getCurrentTalk)
        if okGet and cur ~= nil then
            return false
        end
    end

    -- ⑤-a 物品 / 状态 / 场景名等模态 UI 显示中
    --
    -- **必须逐个体问「你是不是开着」**，不能只靠 disableInput。
    -- 原因：GAME_SMAP.update 每帧执行
    --     if JY.AnimationState.active then InputManager.disableInput = true
    --     else InputManager.disableInput = false end
    -- 把这些模块设的 true 覆盖掉。实测症状：
    --   * 显示「全部物品」清单时，鼠标点击又去寻路了
    --   * 显示人物状态页时，同样
    --
    -- 这些都是「玩家在看的界面」，点击不该落到地图上。
    for _, mod in ipairs({
        { "framework.item_async",          "ItemAsync" },
        { "framework.person_status_async", "PersonStatusAsync" },
    }) do
        local okM, M = pcall(require, mod[1])
        if okM and M and M.isActive then
            local okA, active = pcall(M.isActive)
            if okA and active then
                return false
            end
        end
    end

    -- ⑤ 场景名提示显示中
    --
    -- 不能只靠 disableInput：GAME_SMAP.update 每帧都会把它重算成
    -- 「动画是否在播」（`if AnimationState.active then true else false`），
    -- 于是场景名提示设的 true 会在下一帧被覆盖成 false。
    -- 直接问 SceneNameAsync 才是可靠判据。
    local okSN, SceneNameAsync = pcall(require, "framework.scene_name_async")
    if okSN and SceneNameAsync and SceneNameAsync.isActive then
        local okA, active = pcall(SceneNameAsync.isActive)
        if okA and active then
            return false
        end
    end

    local okAD, AsyncDialog = pcall(require, "framework.async_dialog")
    if okAD and AsyncDialog and AsyncDialog.getInstance then
        local okInst, inst = pcall(AsyncDialog.getInstance)
        if okInst and inst and inst.getCurrentDialog then
            local okCur, dlg = pcall(inst.getCurrentDialog, inst)
            if okCur and dlg ~= nil then
                return false
            end
        end
    end

    -- ⑤ 动画播放中
    if JY.AnimationState and JY.AnimationState.active then
        return false
    end

    return true
end

--- 清空全部状态（场景切换、进入战斗等）
function AutoMove.reset()
    pendingOnArrive = nil
    pendingEventCheck = nil
    local JY = rawget(_G, "JY")
    if not JY then return end
    JY.AutoMove = nil
    JY.InputDrain = nil
end

return AutoMove
