-- game_states.lua
-- 游戏状态处理器定义
-- 将原有的Game_MMap和Game_SMap拆分为update和draw

local GameStates = {}

-- 导入必要的模块
local EventBridge = require("framework.event_bridge")
local EventExecutor = require("framework.event_executor")
local JyMainAsync = require("framework.jymain_async")
local CoroutineScheduler = require("framework.coroutine_scheduler")
local MenuAsync = require("framework.menu_async")
local TalkAsync = require("framework.talk_async")
local PerfLog = require("framework.perf_log")

-- 鼠标点击寻路（slice 3）
local AutoMove = require("framework.auto_move")
local MouseHover = require("framework.mouse_hover")
local Pathfind = require("framework.pathfind")
local MouseMenu = require("framework.mouse_menu")
local Settings = require("framework.settings")
local Interact = require("framework.interact")

-- 游戏状态处理器表
local handlers = {}

-- 前向声明：getStateId 在后面才定义，但 enterSubScene 等更早的函数要用它。
-- 若不加这行，`local function getStateId` 在 275 行才生效，
-- 之前引用的会被解析成**全局** getStateId（nil）→ 运行时 attempt to call a nil value。
local getStateId

-- 启动菜单协程的辅助函数
local function startMenuCoroutine()
    local scheduler = CoroutineScheduler.getInstance()
    local co = scheduler:create(function()
        EngineAPI.debug.log("MMenuCoroutine: starting")
        JyMainAsync.MMenuCoroutine()
        EngineAPI.debug.log("MMenuCoroutine: ended, calling MenuAsync.clear()")
        -- 菜单关闭后清理状态
        MenuAsync.clear()
        local InputManager = require("framework.input_manager")
        EngineAPI.debug.log("MMenuCoroutine: MenuAsync.clear() done, disableInput=" .. tostring(InputManager.disableInput))
    end, "main_menu")
    scheduler:start(co)
end

--------------------------------------------------------------------
-- 点击寻路（REQ-MS3-3）
--------------------------------------------------------------------

-- 主地图可走性：**逐字对照** Game_MMap 的判定（jymain.lua:429）
--   边界：limitX(x, 10, CC.MWidth-10)
--   条件：GetMMap(x,y,3)==0 and GetMMap(x,y,4)==0
local function mmapWalkable(x, y)
    if x < 10 or y < 10 or x > CC.MWidth - 10 or y > CC.MHeight - 10 then
        return false
    end
    return lib.GetMMap(x, y, 3) == 0 and lib.GetMMap(x, y, 4) == 0
end

-- 子场景可走性：**直接复用 SceneCanPass**，不得重写
--   （SceneCanPass 内含「水面 / 物品 / 事件 D* 数据」三条判定，
--     自行重写必然漏条件 —— 见 ADR-MS3-007）
local function smapWalkable(x, y)
    if x < 1 or y < 1 or x > CC.SWidth - 2 or y > CC.SHeight - 2 then
        return false
    end
    return SceneCanPass(x, y) == true
end

--- 进入子场景（**键盘与自动移动共用**）
--
-- 为什么不各自写一份：进场景不只是改 JY.Status，还要
--   ① 把主角放到场景的入口坐标（人X1/人Y1）
--   ② 通过 switchState 触发 GAME_SMAP.enter → Init_SMap(1) → 载入场景数据
--   ③ 传 showname=1 让场景名显示
-- 漏掉任何一步的表现：进去后站在大地图坐标上、场景黑屏、没有场景名。
--
-- （实测踩过：自动移动最初直接写 `JY.Status = GAME_SMAP`，
--   跳过 enter 导致 Init_SMap 未执行。）
--
-- @param subScene number 场景 id
local function enterSubScene(subScene)
    PerfLog.mark("GAME_MMAP entering subscene", tostring(subScene))
    EngineAPI.debug.log("Entering subscene: " .. tostring(subScene))

    local newState = getStateId("GAME_SMAP")
    JY.MmapMusic = -1

    JY.MyPic = GetMyPic()
    JY.Base["人X1"] = JY.Scene[subScene]["入口X"]
    JY.Base["人Y1"] = JY.Scene[subScene]["入口Y"]

    -- 对齐原版 Game_MMap：进子场景后调用 Init_SMap(1) 提示场景名
    -- （原版 jymain.lua:430）。通过 switchTo 的 data 把 showname 传给
    -- GAME_SMAP.enter，避免在 update 里直接调 Init_SMap 造成闪烁。
    PerfLog.mark("GAME_MMAP.switchState(GAME_SMAP, showname=1)")
    EventBridge.getInstance():switchState(newState, { showname = 1 })

    EngineAPI.debug.log("Subscene transition completed")
end

GameStates._enterSubScene = enterSubScene

--- 处理一次鼠标左键点击（无菜单时）
-- @param mx, my number 屏幕坐标
-- @return boolean 是否处理了
local function handleMapClick(mx, my)
    if not MouseMenu.isEnabled() then return false end

    -- **关键守卫**：与键盘完全一致的冻结条件
    --
    -- 不加这层的后果（用户实测报告）：对话期间点击地图，主角照样走过去，
    -- 还能在对话框上叠加悬停菱形 —— 因为鼠标是独立输入通道，
    -- 绕过了 GAME_SMAP.update 里对 keypress 的 CurrentD/talkActive 检查。
    --
    -- canPlayerAct 汇总了 6 项检查（菜单/disableInput/CurrentD/talkActive/
    -- 动画/状态），保证鼠标与键盘走同一套闸门。
    if not AutoMove.canPlayerAct() then
        return false
    end

    local isMMAP = (JY.Status == GAME_MMAP)

    -- **必须带相机**：屏幕格点 ≠ 世界格坐标，差一个相机偏移。
    -- 不带相机的后果（用户实测）：点近处不动、点别处跑很远、走出大地图。
    local camX, camY = MouseHover.camera(isMMAP and "MMAP" or "SMAP")
    local gx, gy = MouseHover.screenToTile(mx, my, camX, camY)

    -- 当前所在格
    local curX, curY
    if isMMAP then
        curX, curY = JY.Base["人X"], JY.Base["人Y"]
    else
        curX, curY = JY.Base["人X1"], JY.Base["人Y1"]
    end

    -- 点自己脚下：无动作
    if gx == curX and gy == curY then return true end

    local walkable = isMMAP and mmapWalkable or smapWalkable
    local mapKind = isMMAP and "MMAP" or "SMAP"

    -- **交互目标**：不可站立但可以交互的格子（REQ-MS3-6）
    --
    -- 典型：客栈门口（建筑，不可走）、场景里的 NPC / 物品（D* 事件格）。
    -- 键盘早就能处理（CanEnterScene 在可走性检查**之前**判定；
    -- SPACE 键直接取「面前一格」的事件），但 A* 要求终点可走，
    -- 所以点这些格子只会红闪 —— 表现为「只能走到门口，进不去」。
    --
    -- 处理方式与键盘一致：走到**旁边的可走格**，面朝它，再触发。
    if not walkable(gx, gy) then
        local plan = Interact.plan(mapKind, gx, gy, curX, curY, walkable)
        if plan then
            -- 目标本身就是接近点（人已站在旁边）→ 直接触发
            if plan.ax == curX and plan.ay == curY then
                Interact.trigger(mapKind, gx, gy)
                return true
            end

            -- 先走到接近点，到达后再触发
            local p2 = Pathfind.find(curX, curY, plan.ax, plan.ay, walkable,
                { maxNodes = Pathfind.DEFAULT_MAX_NODES })
            if p2 then
                AutoMove.start(p2, mapKind, {
                    -- 到达后要做的事（由 stepAutoMove 检查）
                    onArrive = { kind = "interact", tx = gx, ty = gy },
                })
                return true
            end
        end
        -- 既不可走也不可交互 → 红闪
        MouseHover.flashDenied(gx, gy)
        return true
    end

    -- A* 只在**点击瞬间**跑一次（REQ-MS3-4）
    local path, err = Pathfind.find(curX, curY, gx, gy, walkable,
        { maxNodes = Pathfind.DEFAULT_MAX_NODES })

    if not path then
        MouseHover.flashDenied(gx, gy)
        EngineAPI.debug.log("handleMapClick: 寻路失败 err=" .. tostring(err))
        return true
    end

    AutoMove.start(path, mapKind)
    return true
end

--- 路径走完后执行「到达动作」（REQ-MS3-6）
--
-- 目前只有一种：走到可交互目标的旁边，面朝它并触发
-- （大地图进门 / 小场景开箱对话）。
--
-- 为什么必须等走到位再触发：
--   若在点击瞬间就触发，人会站在原地（甚至隔着半张地图）进场景，
--   视觉上是明显的 bug。必须等真的走到旁边。
--
-- @param mapKind string "MMAP" | "SMAP"
function runOnArrive(mapKind)
    local action = AutoMove.takeOnArrive()
    if not action or action.kind ~= "interact" then
        return
    end
    local ok, triggered = pcall(Interact.trigger, mapKind, action.tx, action.ty)
    if not ok then
        EngineAPI.debug.log("runOnArrive: 触发交互失败")
        return
    end
    if not triggered then
        -- 走到了但触发不了（例如中途数据变化）→ 红闪一下，别静默失败
        MouseHover.flashDenied(action.tx, action.ty)
    end
end

--- 主地图自动移动一步
-- @return boolean 是否走了一格
function stepAutoMoveMMap()
    local nextPt = AutoMove.peek()
    if not nextPt then
        AutoMove.stop()
        return false
    end

    local cx, cy = JY.Base["人X"], JY.Base["人Y"]
    -- 只允许相邻一格（4 向），否则说明路径与当前位置脱节
    local dx = nextPt.x - cx
    local dy = nextPt.y - cy
    if math.abs(dx) + math.abs(dy) ~= 1 then
        AutoMove.stop()
        return false
    end

    -- 方向码：0=上 1=右 2=左 3=下（与 CC.DirectX/DirectY 一致）
    local direct
    if dx == 0 and dy == -1 then direct = 0
    elseif dx == 1 and dy == 0 then direct = 1
    elseif dx == -1 and dy == 0 then direct = 2
    else direct = 3 end

    -- MyTick 是「无按键的持续帧数」，键盘路径每次按键都会清零
    -- （jymain.lua:397 / game_states 的 `if keypress ~= -1 then JY.MyTick = 0`）。
    -- 它累加到 20 时会把 MyCurrentPic 复位成站立帧；自动移动若不重置，
    -- 走路动画每 20 帧会「闪一下站立姿势」，看起来一顿一顿的。
    JY.MyTick = 0

    AddMyCurrentPic()
    JY.Base["人方向"] = direct
    JY.Base["人X"] = nextPt.x
    JY.Base["人Y"] = nextPt.y
    JY.oldMMapX = -1
    JY.oldMMapY = -1

    -- 进子场景判定（走到入口格就直接进入，剩余路径丢弃 —— 需求明确）
    local sub = CanEnterScene(nextPt.x, nextPt.y)
    JY.SubScene = sub
    if sub and sub >= 0 then
        AutoMove.interruptBySceneChange()
        -- 必须走共享函数：直接改 JY.Status 会跳过 GAME_SMAP.enter，
        -- 导致 Init_SMap 未执行、主角坐标没设成入口（实测踩过）
        enterSubScene(sub)
        return true
    end

    AutoMove.markStep()
    local hasMore = AutoMove.advance()
    if not hasMore then
        -- 路径走完 —— 若这次点击是「走过去交互」，现在执行（REQ-MS3-6）
        runOnArrive("MMAP")
    end
    return true
end

--- 子场景自动移动一步
-- @return boolean 是否走了一格
function stepAutoMoveSMAP()
    local nextPt = AutoMove.peek()
    if not nextPt then
        AutoMove.stop()
        return false
    end

    local cx, cy = JY.Base["人X1"], JY.Base["人Y1"]
    local dx = nextPt.x - cx
    local dy = nextPt.y - cy
    if math.abs(dx) + math.abs(dy) ~= 1 then
        AutoMove.stop()
        return false
    end

    local direct
    if dx == 0 and dy == -1 then direct = 0
    elseif dx == 1 and dy == 0 then direct = 1
    elseif dx == -1 and dy == 0 then direct = 2
    else direct = 3 end

    JY.MyTick = 0    -- 与键盘路径一致，保持走路动画连续（见 MMAP 分支注释）

    AddMyCurrentPic()
    JY.Base["人方向"] = direct
    JY.Base["人X1"] = nextPt.x
    JY.Base["人Y1"] = nextPt.y
    JY.oldSMapX = -1
    JY.oldSMapY = -1

    -- **必须重算贴图**（用户实测报告的 bug）
    --
    -- 小场景的绘制链是 DrawSMap(0) → lib.DrawSMap(..., JY.MyPic)，
    -- 它直接用全局 JY.MyPic，**不像 MMAP 那样每帧 GetMyPic() 重算**
    -- （对比：GAME_MMAP.draw 里 `local pic = GetMyPic()`，
    --          GAME_SMAP.draw 里只有 `DrawSMap(0)`）。
    --
    -- 键盘移动路径会在 update 结束时执行 `JY.MyPic = GetMyPic()`，
    -- 但自动移动是**提前 return** 的，跳过了那一步 —— 于是 JY.MyPic 一直
    -- 停留在点击前的朝向，表现为「人朝新方向滑走，贴图还是旧朝向」。
    --
    -- 为什么大地图没这个问题：MMAP.draw 每帧重算，朝向自动跟上。
    --
    -- 守卫条件与键盘路径逐字一致（动画/对话/事件执行中不覆盖贴图）。
    local _talkActive = TalkAsync.getCurrentTalk() ~= nil
    -- 注意 CurrentD 要写成 `JY.CurrentD and JY.CurrentD >= 0`：
    -- 既有代码用的是 `JY.CurrentD >= 0`，在 CurrentD 为 nil 时（测试环境、
    -- 或某些初始化顺序下）会 `attempt to compare number with nil`。
    local _eventRunning = JY.CurrentD ~= nil and JY.CurrentD >= 0
    if not JY.AnimationState.active and not _talkActive
        and not _eventRunning then
        JY.MyPic = GetMyPic()
    end
    DtoSMap()

    AutoMove.markStep()
    local hasMore = AutoMove.advance()
    if not hasMore then
        runOnArrive("SMAP")
    end
    return true
end

GameStates._handleMapClick = handleMapClick
GameStates._mmapWalkable = mmapWalkable
GameStates._smapWalkable = smapWalkable
GameStates._stepAutoMoveMMap = stepAutoMoveMMap
GameStates._stepAutoMoveSMAP = stepAutoMoveSMAP
GameStates._runOnArrive = runOnArrive

-- 获取状态ID的辅助函数
-- 在模块加载时，常量可能还未定义，所以使用函数延迟获取
getStateId = function(stateName)
    if stateName == "GAME_MMAP" then
        return GAME_MMAP or 2
    elseif stateName == "GAME_SMAP" then
        return GAME_SMAP or 4
    elseif stateName == "GAME_FIRSTMMAP" then
        return GAME_FIRSTMMAP or 1
    elseif stateName == "GAME_START" then
        return GAME_START or 0
    elseif stateName == "GAME_WMAP" then
        return GAME_WMAP or 5
    elseif stateName == "GAME_END" then
        return GAME_END or 7
    elseif stateName == "GAME_FIRSTSMAP" then
        return GAME_FIRSTSMAP or 3
    elseif stateName == "GAME_DEAD" then
        return GAME_DEAD or 6
    end
    return nil
end

-- GAME_MMAP 状态处理器
handlers["GAME_MMAP"] = {
    -- 状态进入时调用
    enter = function()
        EngineAPI.debug.log("Enter GAME_MMAP state")
        -- REQ-MS3-5：进入地图状态时清空自动移动（避免跨状态残留路径）
        AutoMove.reset()

        -- 初始化主地图
        -- 注意：需要加载地图数据，否则会导致黑屏
        Init_MMap()
    end,
    
    -- 状态退出时调用
    exit = function()
        EngineAPI.debug.log("Exit GAME_MMAP state")
        -- 清理大地图资源
        CleanMemory()
        lib.UnloadMMap()
        lib.PicInit()
        lib.ShowSlow(50, 1)
    end,
    
    -- 每帧更新逻辑
    update = function(dt)
        -- 如果有活动菜单，不处理游戏输入
        if MenuAsync.hasActiveMenu() then
            return
        end

        -- REQ-MS3-3 / REQ-MS3-5：自动移动优先于按键
        --
        -- **但必须先确认玩家可以行动**：对话/动画/事件期间不能推进路径，
        -- 否则自动移动会穿透对话冻结（用户实测报告的核心问题）。
        if AutoMove.isActive() then
            if not AutoMove.canPlayerAct() then
                -- 冻结期间：暂停推进，但保留路径（对话结束后继续走完）
                return
            end
            local keypress = EngineAPI.input.getKey()
            if keypress ~= -1 then
                -- 按键中断：吃掉这次按键与后续 repeat，不响应为方向移动
                AutoMove.interruptByKey(keypress)
                return
            end
            -- 步进节流：未到间隔就不推进（否则 60fps 下 60 格/秒 = 瞬移）
            if not AutoMove.readyToStep() then
                return
            end
            if stepAutoMoveMMap() then
                return    -- 本帧走了一格
            end
            -- 路径走完或中断，落到下面的普通逻辑
        elseif AutoMove.isDraining() then
            -- drain 期间吞掉被中断的那个键的 repeat
            local keypress = EngineAPI.input.getKey()
            if keypress ~= -1 and AutoMove.shouldDrainKey(keypress) then
                return
            end
        end
        
        -- 原有的Game_MMap逻辑(除去渲染部分)
        local direct = -1
        local keypress = EngineAPI.input.getKey()
        
        if keypress ~= -1 then
            JY.MyTick = 0
            if keypress == VK_ESCAPE then
                startMenuCoroutine()
                if JY.Status == getStateId("GAME_FIRSTMMAP") then
                    return
                end
                JY.oldMMapX = -1
                JY.oldMMapY = -1
            elseif keypress == VK_UP then
                direct = 0
            elseif keypress == VK_DOWN then
                direct = 3
            elseif keypress == VK_LEFT then
                direct = 2
            elseif keypress == VK_RIGHT then
                direct = 1
            end
        end
        
        local x, y
        if direct ~= -1 then
            AddMyCurrentPic()
            x = JY.Base["人X"] + CC.DirectX[direct + 1]
            y = JY.Base["人Y"] + CC.DirectY[direct + 1]
            JY.Base["人方向"] = direct
        else
            x = JY.Base["人X"]
            y = JY.Base["人Y"]
        end
        
        JY.SubScene = CanEnterScene(x, y)
        
        if lib.GetMMap(x, y, 3) == 0 and lib.GetMMap(x, y, 4) == 0 then
            JY.Base["人X"] = x
            JY.Base["人Y"] = y
        end
        
        JY.Base["人X"] = limitX(JY.Base["人X"], 10, CC.MWidth - 10)
        JY.Base["人Y"] = limitX(JY.Base["人Y"], 10, CC.MHeight - 10)
        
        if CC.MMapBoat[lib.GetMMap(JY.Base["人X"], JY.Base["人Y"], 0)] == 1 then
            JY.Base["乘船"] = 1
        else
            JY.Base["乘船"] = 0
        end
        
        -- 检查是否进入子场景（与自动移动共用 enterSubScene）
        if JY.SubScene >= 0 then
            enterSubScene(JY.SubScene)
        end

        -- 云朵漂移：原版 kys_main.cpp 主循环每 40ms 移动一次（MMAPAMI>0 门控
        -- 在 CloudTick 内部），与主角移动解耦，每帧调用即可。
        lib.CloudTick()
    end,
    
    -- 每帧渲染
    draw = function()
        local pic = GetMyPic()
        
        -- 在 Love2D 中，每一帧都需要重新绘制整个屏幕
        -- 原来的 FastShowScreen 优化在 SDL 中有效，但在 Love2D 中会导致黑屏
        -- 因此简化绘制逻辑，始终全屏重绘
        lib.SetClip(0, 0, CC.ScreenW, CC.ScreenH)
        lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)
        
        if CC.ShowXY == 1 then
            DrawString(10, CC.ScreenH - 20, string.format("%d %d", JY.Base["人X"], JY.Base["人Y"]), C_GOLD, 16)
        end
        
        -- 在 Love2D 中，love.draw() 结束时会自动调用 present()
        -- 不需要手动调用 ShowScreen，否则可能导致抖动
        -- ShowScreen(CONFIG.FastShowScreen)
        lib.SetClip(0, 0, 0, 0)
        
        JY.oldMMapX = JY.Base["人X"]
        JY.oldMMapY = JY.Base["人Y"]
        JY.oldMMapPic = pic
    end
}

-- GAME_SMAP 状态处理器
handlers["GAME_SMAP"] = {
    enter = function(prevState, data)
        EngineAPI.debug.log("Enter GAME_SMAP state")
        -- showname=1 表示要提示场景名。原版两处调用带 1：
        --   Game_MMap 进子场景（jymain.lua:430）、场景内跳转（jymain.lua:1331）
        -- LÖVE 版把「主地图进子场景」改成 switchTo 传参，必须在这里接住，
        -- 否则进客栈等小场景时永远只走 Init_SMap(0)，场景名不显示。
        local showname = (data and data.showname) or 0

        -- Init_SMap(1) 内部会调 jymain 的 ShowSceneName()，后者转发到全局
        -- ShowSceneNameAsyncImpl。该全局正常由 AsyncGlobals.install() 注入，
        -- 但那条路径只在事件脚本执行时才会走；从主地图进场景时可能尚未安装，
        -- 因此这里兜底注入一次（幂等）。
        if showname == 1 then
            local SceneNameAsync = require("framework.scene_name_async")
            rawset(_G, "ShowSceneNameAsyncImpl", SceneNameAsync.Show)
        end

        local t = PerfLog.begin("GAME_SMAP.enter.Init_SMap(" .. tostring(showname) .. ")")
        Init_SMap(showname)
        PerfLog.finish(t)
    end,
    
    exit = function()
        EngineAPI.debug.log("Exit GAME_SMAP state")

        -- 清掉场景名提示（用户实测：出场景后名字一直留在屏幕上）
        --
        -- 场景名靠一个挂起等键的协程维持，切走状态时它不会被唤醒。
        -- 不清的连锁后果：
        --   ① currentName 残留 → 每帧照画 → 名字不消失
        --   ② disableInput 残留 true → 之后所有点击被判为「不可行动」
        --      → 「小场景内点箱子/NPC 都没反应」
        pcall(function()
            local SceneNameAsync = require("framework.scene_name_async")
            if SceneNameAsync and SceneNameAsync.dismissOnStateChange then
                SceneNameAsync.dismissOnStateChange()
            end
        end)

        -- 顺带清掉自动移动（场景已离开，旧路径无意义）
        AutoMove.reset()
        pcall(function()
            if MouseHover and MouseHover.clearFlash then MouseHover.clearFlash() end
        end)
    end,
    
    update = function(dt)
        -- 场景名提示期间，StateMachine 会优先更新子状态并跳过本函数
        -- （见 state_machine.lua 的 update：有子状态时直接 return），
        -- 因此这里不需要再判断提示状态。
        
        -- 如果有活动菜单，不处理游戏输入
        if MenuAsync.hasActiveMenu() then
            return
        end
        
        -- 检查是否正在播放动画，如果是则禁用输入
        local InputManager = require("framework.input_manager")
        if JY.AnimationState.active then
            InputManager.disableInput = true
        else
            InputManager.disableInput = false
        end
        
        -- 处理动画（事件驱动架构）
        if JY.AnimationState.active then
            local anim = JY.AnimationState
            local now = EngineAPI.time.getTime()
            local elapsed = now - anim.startTime
            local frameIndex = math.floor(elapsed / anim.frameDuration)
            local i = anim.startFrame + frameIndex * 2
            
            if i > anim.endFrame then
                -- 动画结束
                anim.active = false
                anim.currentFrame = 0  -- 重置为初始状态
            else
                -- 设置当前帧贴图
                if anim.id == -1 then
                    JY.MyPic = i / 2
                else
                    SetD(JY.SubScene, anim.id, 5, i)
                    SetD(JY.SubScene, anim.id, 6, i)
                    SetD(JY.SubScene, anim.id, 7, i)
                end
                DtoSMap()
            end
        end
        
        -- 处理路过事件
        local d_pass = GetS(JY.SubScene, JY.Base["人X1"], JY.Base["人Y1"], 3)
        if d_pass >= 0 then
            if d_pass ~= JY.OldDPass then
                -- REQ-MS3-5：事件触发中断自动移动，且**不恢复**剩余路径。
                --
                -- **只在事件真的会做事时才中断**（用户实测报告）。
                --
                -- 背景：门槛/入口这类 tile 的事件通常是「一次性」的 ——
                -- 首次进入时脚本执行，之后事件数据被改（或脚本里自带
                -- 「已触发」判断），再踩上去是 no-op。
                --
                -- 但 OldDPass 在离开该格时会被重置成 -1，所以**每次**
                -- 踩上去都满足 `d_pass ~= OldDPass`，都会走到这里并调用
                -- EventExecuteSync。此时若无条件中断自动移动：
                --   玩家从客栈一侧点到另一侧 → 路径在门口被砍断
                --   → 停在门口、什么也没发生 → 表现为「点远处只走到门口」
                --
                -- 修法：先问「这个事件还能不能跑」。不能跑就**不中断**，
                -- 让自动移动继续走完剩余路径。
                -- 先看静态判据（tile 上还有没有事件号）：
                -- 已经完全没有事件的 tile → 连 EventExecuteSync 都不用调，
                -- 自动移动直接继续。
                local willRun = AutoMove.eventWouldRun(JY.SubScene, d_pass)
                if AutoMove.isActive() then
                    if not willRun then
                        EngineAPI.debug.log("Game_SMAP: 路过事件已被清空，不中断自动移动 d="
                            .. tostring(d_pass))
                    else
                        -- 还有事件号，但脚本可能自己 no-op（一次性事件）。
                        -- 静态判断不了，改为「下一帧看 CurrentD 是否跨帧保持」：
                        -- 真事件会 yield（对话/动画），CurrentD 保持 >= 0；
                        -- no-op 同帧跑完，CurrentD 已回 -1。
                        AutoMove.watchEvent(JY.SubScene, d_pass)
                        EngineAPI.debug.log("Game_SMAP: 登记路过事件待判定 d="
                            .. tostring(d_pass))
                    end
                end
                if willRun then
                    EventExecuteSync(d_pass, 3)
                end
                JY.OldDPass = d_pass
                JY.oldSMapX = -1
                JY.oldSMapY = -1
                JY.D_Valid = nil
            end
        else
            JY.OldDPass = -1
        end
        
        -- 检查是否退出到主地图
        local isout = 0
        if (JY.Scene[JY.SubScene]["出口X1"] == JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y1"] == JY.Base["人Y1"]) or
           (JY.Scene[JY.SubScene]["出口X2"] == JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y2"] == JY.Base["人Y1"]) or
           (JY.Scene[JY.SubScene]["出口X3"] == JY.Base["人X1"] and JY.Scene[JY.SubScene]["出口Y3"] == JY.Base["人Y1"]) then
            isout = 1
        end
        
        if isout == 1 then
            PerfLog.mark("GAME_SMAP exit-to-mmap start")
            if JY.MmapMusic < 0 then
                JY.MmapMusic = JY.Scene[JY.SubScene]["出门音乐"]
            end

            JY.SubScene = -1
            JY.oldSMapX = -1
            JY.oldSMapY = -1

            -- 立即切换状态，避免当前帧继续按 GAME_SMAP 绘制导致黑屏闪烁。
            local t = PerfLog.begin("GAME_SMAP.exit.switchState(GAME_MMAP)")
            EventBridge.getInstance():switchState(getStateId("GAME_MMAP"))
            PerfLog.finish(t)

            PerfLog.mark("GAME_SMAP exit-to-mmap done")
            return
        end
        
        -- 检查场景跳转
        if JY.Scene[JY.SubScene]["跳转场景"] >= 0 then
            if JY.Base["人X1"] == JY.Scene[JY.SubScene]["跳转口X1"] and JY.Base["人Y1"] == JY.Scene[JY.SubScene]["跳转口Y1"] then
                JY.SubScene = JY.Scene[JY.SubScene]["跳转场景"]
                lib.ShowSlow(50, 1)
                PerfLog.mark("GAME_SMAP jump scene", tostring(JY.SubScene))
                
                if JY.Scene[JY.SubScene]["外景入口X1"] == 0 and JY.Scene[JY.SubScene]["外景入口Y1"] == 0 then
                    JY.Base["人X1"] = JY.Scene[JY.SubScene]["入口X"]
                    JY.Base["人Y1"] = JY.Scene[JY.SubScene]["入口Y"]
                else
                    JY.Base["人X1"] = JY.Scene[JY.SubScene]["跳转口X2"]
                    JY.Base["人Y1"] = JY.Scene[JY.SubScene]["跳转口Y2"]
                end
                
                local t = PerfLog.begin("GAME_SMAP.jump.Init_SMap(1)")
                Init_SMap(1)
                PerfLog.finish(t)
                return
            end
        end
        
        -- 处理输入
        local x, y
        local keypress = EngineAPI.input.getKey()
        local direct = -1
        
        -- 检查是否正在显示人物状态或物品选择，如果是则跳过按键处理
        -- 注意：现在统一通过 InputManager.disableInput 实现
        local InputManager = require("framework.input_manager")
        if InputManager.disableInput then
            keypress = -1  -- 忽略按键
        end

        -- REQ-MS3-3 / REQ-MS3-5：自动移动优先于按键（与 MMAP 同构）
        -- 同样必须先确认玩家可以行动（见 MMAP 分支的注释）
        if AutoMove.isActive() then
            -- 先确认上一帧触发的事件是否真的在跑（真事件 → 中断路径）
            if AutoMove.checkWatchedEvent() then
                return
            end
            if not AutoMove.canPlayerAct() then
                return
            end
            if keypress ~= -1 then
                AutoMove.interruptByKey(keypress)
                return
            end
            if not AutoMove.readyToStep() then
                return
            end
            if stepAutoMoveSMAP() then
                return
            end
        elseif AutoMove.isDraining() then
            if keypress ~= -1 and AutoMove.shouldDrainKey(keypress) then
                return
            end
        end

        -- 事件执行期间（JY.CurrentD >= 0，含开场强制对话）冻结玩家输入：
        -- 原版 Game_SMap 是阻塞式，事件执行时主循环不轮询按键。事件驱动下若不冻结，
        -- 玩家连按的方向键会让主角在对话期间移动（甚至走进路过事件实体），
        -- 空格键会触发面向 tile 的事件，破坏强制流程并污染 JY.CurrentD/MyPic。
        if keypress ~= -1 and not (JY and JY.CurrentD >= 0) then
            JY.MyTick = 0
            if keypress == VK_ESCAPE then
                startMenuCoroutine()
                JY.oldSMapX = -1
                JY.oldSMapY = -1
            elseif keypress == VK_UP then
                direct = 0
            elseif keypress == VK_DOWN then
                direct = 3
            elseif keypress == VK_LEFT then
                direct = 2
            elseif keypress == VK_RIGHT then
                direct = 1
            elseif keypress == VK_SPACE or keypress == VK_RETURN then
                EngineAPI.debug.log("GAME_SMAP.update: SPACE/RETURN pressed")
                if JY.Base["人方向"] >= 0 then
                    local targetX = JY.Base["人X1"] + CC.DirectX[JY.Base["人方向"] + 1]
                    local targetY = JY.Base["人Y1"] + CC.DirectY[JY.Base["人方向"] + 1]
                    local d_num = GetS(JY.SubScene, targetX, targetY, 3)
                    EngineAPI.debug.log(string.format("GAME_SMAP.update: checking target (%d,%d), d_num=%d", targetX, targetY, d_num))
                    if d_num >= 0 then
                        EngineAPI.debug.log(string.format("GAME_SMAP.update: executing event d_num=%d", d_num))
                        EventExecuteSync(d_num, 1)
                        JY.oldSMapX = -1
                        JY.oldSMapY = -1
                        JY.D_Valid = nil
                    else
                        EngineAPI.debug.log("GAME_SMAP.update: no event at target position")
                    end
                else
                    EngineAPI.debug.log("GAME_SMAP.update: no direction set")
                end
            end
        end
        
        if JY.Status ~= getStateId("GAME_SMAP") then
            return
        end
        
        if direct ~= -1 then
            AddMyCurrentPic()
            x = JY.Base["人X1"] + CC.DirectX[direct + 1]
            y = JY.Base["人Y1"] + CC.DirectY[direct + 1]
            JY.Base["人方向"] = direct
        else
            x = JY.Base["人X1"]
            y = JY.Base["人Y1"]
        end
        
        -- 更新主角贴图（根据方向和走路帧）
        -- 跳过条件：
        --   1. 动画播放期间（instruct_27 等）：动画帧贴图由 update 驱动，不能被覆盖
        --   2. 事件执行期间（JY.CurrentD >= 0）：原版 Game_SMap 是阻塞式，事件执行
        --      时主循环暂停，贴图保持不变。事件驱动下事件协程挂起（instruct_1 对话
        --      yield 等按键）期间 update 仍在跑，若照常重算 GetMyPic()，开场新游戏
        --      （卧姿 3445）的卧姿贴图会在对话期间被覆盖成站立（GetMyPic 只能算出
        --      站立/行走帧 2494~2522，永远算不出卧姿），直到 instruct_27 动画
        --      开始才恢复卧姿（用户报告的开场 bug 根因）。
        --   3. 对话框显示中（TalkAsync.currentTalk ~= nil）：兜底守卫。CurrentD 是
        --      共享全局，若开场事件被内联执行（startNewGame 内联路径）而玩家连按
        --      空格触发面向 tile 的嵌套事件协程，其结束时会把 CurrentD 复位 -1，
        --      条件 2 失效、卧姿仍会被覆盖；对话显示中贴图必须保持不变，故以
        --      currentTalk 为第二道闸。
        local _talkActive = TalkAsync.getCurrentTalk() ~= nil
        if not JY.AnimationState.active and not _talkActive and not (JY and JY.CurrentD >= 0) then
            JY.MyPic = GetMyPic()
        end
        DtoSMap()
        
        if SceneCanPass(x, y) == true then
            JY.Base["人X1"] = x
            JY.Base["人Y1"] = y
        end
        
        JY.Base["人X1"] = limitX(JY.Base["人X1"], 1, CC.SWidth - 2)
        JY.Base["人Y1"] = limitX(JY.Base["人Y1"], 1, CC.SHeight - 2)
    end,
    
    draw = function()
        -- 在 Love2D 中，每一帧都需要重新绘制
        -- 禁用 FastShowScreen 优化以避免黑屏
        DrawSMap(0)
        
        -- 场景名提示由 EventBridge:draw() 里的 SceneNameAsync.draw() 负责：
        -- 它排在 StateMachine:draw()（含本函数的 DrawSMap）之后，
        -- 因此不会被全屏重绘覆盖。
        
        if CC.ShowXY == 1 then
            DrawString(10, CC.ScreenH - 20, string.format("%s %d %d", JY.Scene[JY.SubScene]["名称"], JY.Base["人X1"], JY.Base["人Y1"]), C_GOLD, 16)
        end
        
        -- 在 Love2D 中，love.draw() 结束时会自动调用 present()
        -- ShowScreen(0)
        lib.SetClip(0, 0, 0, 0)
    end
}

-- GAME_START 状态处理器(开始菜单)
handlers["GAME_START"] = {
    enter = function()
        EngineAPI.debug.log("Enter GAME_START state")
    end,
    
    exit = function()
        EngineAPI.debug.log("Exit GAME_START state")
    end,
    
    update = function(dt)
        -- 开始菜单的更新逻辑在jymain_adapter中处理
    end,
    
    draw = function()
        -- 绘制开始界面背景
        if CC.FirstFile then
            lib.LoadPicture(CC.FirstFile, -1, -1)
        end
    end
}

-- GAME_FIRSTMMAP 状态处理器(首次进入主地图)
handlers["GAME_FIRSTMMAP"] = {
    enter = function()
        EngineAPI.debug.log("Enter GAME_FIRSTMMAP state")
        CleanMemory()
        lib.ShowSlow(50, 1)
        JY.MmapMusic = 16
        
        Init_MMap()
        
        lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], GetMyPic())
        lib.ShowSlow(50, 0)
    end,
    
    exit = function()
        EngineAPI.debug.log("Exit GAME_FIRSTMMAP state")
    end,
    
    update = function(dt)
        -- 首次进入后立即切换到主地图状态
        local newState = getStateId("GAME_MMAP")
        EngineAPI.debug.log("GAME_FIRSTMMAP update: setting JY.Status=" .. tostring(newState))
        JY.Status = newState
    end,
    
    draw = function()
        -- 绘制主地图
        local pic = GetMyPic()
        lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)
        -- 在 Love2D 中，love.draw() 结束时会自动调用 present()
        -- ShowScreen(0)
    end
}

-- GAME_WMAP 状态处理器(战斗)
handlers["GAME_WMAP"] = {
    enter = function()
        EngineAPI.debug.log("Enter GAME_WMAP state (battle)")
        -- REQ-MS3-5：进入战斗时清空自动移动与 drain
        --
        -- 不清空的后果：战斗结束后回到 MMAP，之前的路径会继续走 ——
        -- 玩家会看到主角「自己」在战斗后莫名移动。
        AutoMove.reset()
        pcall(function()
            local MouseHover = require("framework.mouse_hover")
            if MouseHover and MouseHover.clearFlash then MouseHover.clearFlash() end
        end)
    end,
    
    exit = function()
        EngineAPI.debug.log("Exit GAME_WMAP state (battle)")
        -- 清理战斗资源
        if WAR then
            WAR.Person = {}
            WAR.Data = {}
        end
    end,
    
    update = function(dt)
        -- 战斗逻辑在 WarMain 协程中处理
        -- 这里不需要额外处理
    end,
    
    draw = function()
        if JY.Status == GAME_WMAP and WAR and WAR.Person and WAR.CurID and WAR.Person[WAR.CurID] then
            local drawMode = WAR.DrawMode or 0
            
            if drawMode == 1 and WAR.MoveCursorX and WAR.MoveCursorY then
                WarDrawMap(1, WAR.MoveCursorX, WAR.MoveCursorY)
            elseif drawMode == 2 then
                if WAR.MoveCursorX and WAR.MoveCursorY then
                    WarDrawMap(2, WAR.MoveCursorX, WAR.MoveCursorY)
                else
                    WarDrawMap(2)
                end
            elseif drawMode == 3 and WAR.MoveCursorX and WAR.MoveCursorY then
                WarDrawMap(1, WAR.MoveCursorX, WAR.MoveCursorY)
            elseif drawMode == 4 and WAR.AnimPic then
                WarDrawMap(4, WAR.AnimPic, WAR.AnimType or 0, WAR.AnimEffect or -1)
            elseif drawMode == 5 and WAR.HitNumbers then
                WarDrawMap(0)
                local y_off = WAR.HitYOffset or 0
                local effectColor = WAR.EffectColor and WAR.EffectColor[WAR.HitEffect] or C_WHITE
                for j = 0, WAR.HitNum - 1 do
                    if WAR.HitClips[j] then
                        DrawString(WAR.HitClips[j].x1, WAR.HitClips[j].y1 - y_off, 
                            WAR.HitNumbers[j][3], effectColor, CC.DefaultFont)
                    end
                end
            else
                WarDrawMap(0)
            end
        end
    end
}

-- GAME_END 状态处理器(游戏结束)
handlers["GAME_END"] = {
    enter = function()
        EngineAPI.debug.log("Enter GAME_END state")
        -- 退出游戏
        EngineAPI.app.quit()
    end,
    
    exit = function()
        EngineAPI.debug.log("Exit GAME_END state")
    end,
    
    update = function(dt)
        -- 游戏结束状态不需要更新
    end,
    
    draw = function()
        -- 游戏结束状态不需要绘制
    end
}

-- GAME_DEAD 状态处理器(死亡/游戏结束界面)
handlers["GAME_DEAD"] = {
    enter = function()
        EngineAPI.debug.log("Enter GAME_DEAD state")
        PlayMIDI(0)
        JY.DeadScreen = {
            name = JY.Person[0]["姓名"],
            datetime = os.date("%Y-%m-%d %H:%M")
        }
    end,
    
    exit = function()
        EngineAPI.debug.log("Exit GAME_DEAD state")
        JY.DeadScreen = nil
    end,
    
    update = function(dt)
    end,
    
    draw = function()
        lib.FillColor(0, 0, 0, 0, 0)
        lib.LoadPicture(CC.DeadFile, -1, -1)
        
        if JY.DeadScreen then
            DrawString(CC.GameOverX, CC.GameOverY, JY.DeadScreen.name, RGB(216, 20, 24), CC.DefaultFont)
            
            local x = CC.ScreenW - 9 * CC.DefaultFont
            DrawString(x, 10, JY.DeadScreen.datetime, RGB(216, 20, 24), CC.DefaultFont)
            DrawString(x, 10 + CC.DefaultFont + CC.RowPixel, "在地球的某处", RGB(216, 20, 24), CC.DefaultFont)
            DrawString(x, 10 + (CC.DefaultFont + CC.RowPixel) * 2, "当地人口的失踪数", RGB(216, 20, 24), CC.DefaultFont)
            DrawString(x, 10 + (CC.DefaultFont + CC.RowPixel) * 3, "又多了一笔。。。", RGB(216, 20, 24), CC.DefaultFont)
        end
    end
}

-- 注册所有状态到状态机
function GameStates.registerAll()
    local eb = EventBridge.getInstance()
    
    -- 使用字符串键注册，然后在注册时转换为实际的状态ID
    for stateName, handler in pairs(handlers) do
        local stateId = getStateId(stateName)
        if stateId then
            eb:registerState(stateId, handler)
        end
    end
end

-- 获取处理器(用于测试)
function GameStates.getHandler(stateName)
    return handlers[stateName]
end

-- 获取状态ID
function GameStates.getStateId(stateName)
    return getStateId(stateName)
end

--- 请求呼出主菜单（等价 ESC）
--
-- 供鼠标右键调用（REQ-MS2-1）。走与键盘 ESC 完全相同的路径，
-- 保证两条入口行为一致（菜单栈、disableInput、状态恢复都相同）。
--
-- 注意：调用方负责判断「当前是否允许呼出」（状态、事件执行中、
-- 阻塞输入等），本函数只负责真正启动菜单协程。
function GameStates.requestMainMenu()
    startMenuCoroutine()
end

return GameStates
