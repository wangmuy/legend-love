-- war_async.lua
-- 战斗系统异步模块
-- 提供战斗系统的协程版本函数

local GameHooks = require("framework.game_hooks")
local FlowFacade = require("framework.flow_facade")
local RenderFacade = require("framework.render_facade")
local SpriteAtlas = require("framework.sprite_atlas")
local WarAsync = {}

local CoroutineScheduler = require("framework.coroutine_scheduler")
local MenuAsync = require("framework.menu_async")
local AsyncMessageBox = require("framework.async_message_box")
local InputAsync = require("framework.input_async")
local PersonStatusAsync = require("framework.person_status_async")

-- 战斗状态
local warState = {
    warId = nil,
    isExp = 1,
    status = "idle",  -- idle, running, ended
    result = nil,     -- true=胜利, false=失败
    round = 0,
    currentPerson = 0,
}

-- 获取调度器实例
local function getScheduler()
    return CoroutineScheduler.getInstance()
end

-- **协程已搬到 script/battle/battle_flow_coroutines.lua**（阶段 2C）。
-- 原先这里是 20 个 local 前向声明，现在全部取消 —— 改为调用本模块自己的
-- `WarAsync.XXXCoroutine` 转发（文件末尾生成）。
--
-- **踩过的实机 bug（自动化测试没抓到）**：搬走协程后，这 20 个 local
-- 变成了 nil upvalue，而 `WarMainCoroutine` 的战斗主循环里还在调用
-- `War_ManualCoroutine()` / `War_AutoCoroutine()` / `War_SettlementCoroutine()`。
-- 症状：战斗一开始就抛 "attempt to call upvalue 'War_ManualCoroutine'
-- (a nil value)"，玩家看到的是黑屏回主菜单。
--
-- 为什么测试没抓到：所有测试都直接调 `War_ManualCoroutine` 等函数，
-- 没有一个真的跑 `WarMainCoroutine`（那需要完整贴图档案 + 协程调度 + 按键）。
-- → 这就是「字节保真不等于行为正确」的具体案例。

-- 战斗主函数（协程版本）
-- @param warid: 战斗编号
-- @param isexp: 输后是否有经验
-- @return: true 战斗胜利, false 失败
function WarAsync.WarMainCoroutine(warid, isexp)
    EngineAPI.debug.log(string.format("WarMainCoroutine: warid=%d, isexp=%d", warid, isexp or 1))
    
    -- 检查 CC 模块是否加载
    if not CC or not CC.WarData_S then
        EngineAPI.debug.log("WarMainCoroutine: ERROR - CC.WarData_S not loaded")
        return false
    end
    
    EngineAPI.debug.log("WarMainCoroutine: CC.WarDataSize=" .. tostring(CC.WarDataSize))
    
    warState.warId = warid
    warState.isExp = isexp or 1
    warState.status = "running"
    warState.result = nil
    warState.round = 0
    
    -- 初始化战斗
    EngineAPI.debug.log("WarMainCoroutine: calling WarLoad")
    WarLoad(warid)
    
    EngineAPI.debug.log("WarMainCoroutine: calling WarSelectTeam")
    WarSelectTeam()
    
    EngineAPI.debug.log("WarMainCoroutine: calling WarSelectEnemy")
    WarSelectEnemy()
    
    EngineAPI.debug.log("WarMainCoroutine: WarSelectEnemy done, WAR.PersonNum=" .. tostring(WAR.PersonNum))
    
    CleanMemory()
    EngineAPI.sprite.initSprites()
    EngineAPI.render.presentAndWait(50)
    
    EngineAPI.debug.log("WarMainCoroutine: calling WarLoadMap")
    WarLoadMap(WAR.Data["地图"])
    
    -- 加载贴图文件
    --
    -- **必须同时走两套系统**（历史遗留的双轨制，不是设计选择）：
    --   ① SpriteAtlas（新）：framework 侧的战斗绘制（war_hover / item 等）
    --   ② lib.PicLoadFile（旧）：script 侧的战斗绘制
    --      —— battle_render.lua 的 WarDrawMap / WarShowHead / WarCalPersonPic
    --      至今仍读 `picFileCache`（`lib.PicGetXY` / `lib.PicLoadCache`）。
    --      SpriteAtlas 不写 picFileCache，只走 ① 会让 battle_render 崩：
    --      `PicGetXY: attempt to index a nil value`（picFileCache[2] == nil）。
    --
    -- 这是**实机才能发现的 bug**：单测里这些函数都是被 stub 的，
    -- 或者 lib 桩返回假数据，不会暴露两套系统不互通。
    --
    -- **注意**：`battle_render.lua` 已迁到 SpriteAtlas（Task 2 完成），
    -- 但这一半**仍需保留** —— 因为 `map.drawBattle` 内部依赖它（见下方）。

    SpriteAtlas.loadArchive(CC.WMAPPicFile[1], CC.WMAPPicFile[2], 0, { paletteFile = CC.PaletteFile })
    SpriteAtlas.loadArchive(CC.HeadPicFile[1], CC.HeadPicFile[2], 1, { paletteFile = CC.PaletteFile, usage = "avatar" })
    if CC.LoadThingPic == 1 then
        SpriteAtlas.loadArchive(CC.ThingPicFile[1], CC.ThingPicFile[2], 2, { paletteFile = CC.PaletteFile })
    end
    SpriteAtlas.loadArchive(CC.EffectFile[1], CC.EffectFile[2], 3, { paletteFile = CC.PaletteFile })

    -- 旧系统的档案（供**引擎内部**的 lib.PicLoadCache 使用）
    --
    -- `EngineAPI.sprite.loadArchive` 在各引擎里就是 `lib.PicLoadFile`
    -- （LÖVE 实现见 engine_love2d.lua:95-97），会把档案写进引擎的
    -- `picFileCache`。而 `SpriteAtlas.loadArchive` 走的是新解码链
    -- （framework/sprite_decoder），**不写 picFileCache**。
    --
    -- **这不是"临时妥协"，删不掉**（实测：删掉 → 战斗地图全黑，
    -- 截图从 397034 字节掉到 26865 字节）。根因：
    --
    --   EngineAPI.map.drawBattle      (engine_love2d.lua:302，只是转发)
    --     → lib.DrawWarMap            (lib_love.lua:1650)
    --        → JY_LoadPic             (lib_love.lua:582)
    --           = PicLoadCache        ← **读 picFileCache**
    --              → picFileCache[fileid]  ← 必须由 PicLoadFile 写入
    --
    -- 也就是说 `map.drawBattle` **不是** .idx/.grp 透明的契约，它把旧系统
    -- 包了一层，内部仍依赖 `PicLoadFile` 写入的数据。
    --
    -- 即使 `battle_render.lua` 已经不调 `lib.Pic*`（port-sprite-native-migration
    -- 已迁移），**引擎内部的 DrawWarMap 仍然需要**。
    --
    -- 要真正删掉这一半，前提是让 `map.drawBattle` 契约透明化
    -- （`framework/map_render.lua` 做投影 + 逐格 `sprite.draw`），
    -- 那是 `map.drawBattle` 的 @deprecated 条目，属独立 change。
    if EngineAPI and EngineAPI.sprite and EngineAPI.sprite.loadArchive then
        EngineAPI.sprite.loadArchive(CC.WMAPPicFile[1], CC.WMAPPicFile[2], 0)
        EngineAPI.sprite.loadArchive(CC.HeadPicFile[1], CC.HeadPicFile[2], 1)
        if CC.LoadThingPic == 1 then
            EngineAPI.sprite.loadArchive(CC.ThingPicFile[1], CC.ThingPicFile[2], 2)
        end
        EngineAPI.sprite.loadArchive(CC.EffectFile[1], CC.EffectFile[2], 3)
    end
    
    GameHooks.playMIDI(WAR.Data["音乐"])
    
    WarPersonSort()
    
    -- 加载战斗人物贴图
    for i = 0, WAR.PersonNum - 1 do
        local pid = WAR.Person[i]["人物编号"]
        SpriteAtlas.loadArchive(
            string.format(CC.FightPicFile[1], JY.Person[pid]["头像代号"]),
            string.format(CC.FightPicFile[2], JY.Person[pid]["头像代号"]),
            4 + i, { paletteFile = CC.PaletteFile })
    end
    
    -- 设置状态为战斗（在初始化完成后）
    local prevState = JY.Status
    JY.Status = GAME_WMAP

    -- 清掉可能残留的对话气泡。
    --
    -- 事件脚本里常见「先 TalkEx 再开战」的写法（韦大宝「佣兵行会」就是
    -- TalkEx("祝你好运！") 之后立刻 WarMain）。TalkExCoroutine 停在等键点时
    -- currentTalk 仍被设置，战斗一旦接管屏幕，那个协程再没机会执行清空语句，
    -- 而 EventBridge:draw() 每帧无条件调用 TalkAsync.draw()，对话框就会被
    -- 反复画在战斗画面之上——即「进入战斗后韦大宝的对话框没有消失」。
    local TalkAsync = require("framework.talk_async")
    if TalkAsync.clear then TalkAsync.clear() end
    
    -- 战斗主循环
    local first = 0
    local warStatus = 0  -- 0=继续, 1=赢, 2=输
    
    while warStatus == 0 do
        -- 更新战斗人物
        for i = 0, WAR.PersonNum - 1 do
            WAR.Person[i]["贴图"] = WarCalPersonPic(i)
        end
        
        -- 计算移动步数
        for i = 0, WAR.PersonNum - 1 do
            local id = WAR.Person[i]["人物编号"]
            local move = math.modf(WAR.Person[i]["轻功"] / 15) - math.modf(JY.Person[id]["受伤程度"] / 40)
            if move < 0 then move = 0 end
            WAR.Person[i]["移动步数"] = move
        end
        
        WarSetPerson()
        
        -- 让出控制权
        CoroutineScheduler.getInstance():yield("battle_round_start")
        
        -- 每回合战斗循环
        local p = 0
        while p < WAR.PersonNum do
            WAR.Effect = 0
            
            -- 让出控制权，让渲染有机会执行
            CoroutineScheduler.getInstance():yield("battle_round")
            
            -- 处理自动战斗取消
            if WAR.AutoFight == 1 then
                local keypress = EngineAPI.input.getKey()
                if keypress == VK_SPACE or keypress == VK_RETURN then
                    WAR.AutoFight = 0
                end
            end
            
            if WAR.Person[p]["死亡"] == false then
                WAR.CurID = p
                
                if first == 0 then
                    WarDrawMap(0)
                    EngineAPI.render.present()
                    first = 1
                end
                
                local r
                if WAR.Person[p]["我方"] == true then
                    if WAR.AutoFight == 0 then
                        r = WarAsync.War_ManualCoroutine()
                    else
                        r = WarAsync.War_AutoCoroutine()
                    end
                else
                    r = WarAsync.War_AutoCoroutine()
                end
                
                warStatus = War_isEnd()
                
                if math.abs(r) == 7 then
                    p = p - 1
                end
            end
            
            p = p + 1
            EngineAPI.debug.log("battle: person " .. p .. " next, WAR.CurID=" .. WAR.CurID)
            
            -- 每次人物行动后都让出控制权
            CoroutineScheduler.getInstance():yield("battle_person_done")
            EngineAPI.debug.log("battle: after yield, p=" .. p)
        end
        
        -- 回合结束处理
        if warStatus == 0 then
            War_PersonLostLife()
        end
    end
    
    -- 战斗结束
    WarAsync.War_SettlementCoroutine(warStatus)
    
    War_EndPersonData(warState.isExp, warStatus)

    -- 本场战斗经验清零。
    --
    -- 原版 WAR 数据每场重建（WarLoad 里重新读表），而事件驱动架构下 WAR
    -- 表跨场复用，不清零会让 WAR.Person[i]["经验"] 逐场累加，下一场
    -- War_EndPersonData 发放的经验就是「本场 + 上一场」的叠加值。
    -- 对齐原版 WarMain 收尾的同名循环。
    for i = 0, WAR.PersonNum - 1 do
        WAR.Person[i]["经验"] = 0
    end
    
    -- 恢复场景贴图与音乐（对齐原版 WarMain 收尾：ShowSlow/进门音乐/贴图重载。
    -- 战斗期间 PicInit 清空了 SMAP 贴图（槽0=WMAP），不重载则回场景后渲染缺图）
    EngineAPI.render.presentAndWait(50)
    if JY.Scene and JY.Scene[JY.SubScene] and JY.Scene[JY.SubScene]["进门音乐"] >= 0 then
        GameHooks.playMIDI(JY.Scene[JY.SubScene]["进门音乐"])
    else
        GameHooks.playMIDI(0)
    end
    CleanMemory()
    EngineAPI.sprite.initSprites()
    SpriteAtlas.loadArchive(CC.SMAPPicFile[1], CC.SMAPPicFile[2], 0, { paletteFile = CC.PaletteFile })
    SpriteAtlas.loadArchive(CC.HeadPicFile[1], CC.HeadPicFile[2], 1, { paletteFile = CC.PaletteFile, usage = "avatar" })
    if CC.LoadThingPic == 1 then
        SpriteAtlas.loadArchive(CC.ThingPicFile[1], CC.ThingPicFile[2], 2, { paletteFile = CC.PaletteFile })
    end
    
    -- 恢复状态
    JY.Status = prevState
    warState.status = "ended"
    warState.result = (warStatus == 1)

    -- 战败时不在这里弹「死亡画面」——
    -- 原版语义是：WarMain 返回 false → 调用方脚本自己处理
    -- （韦大宝的「佣兵行会」是 instruct_13 + "战斗失败，抱歉没有银子可挣！"）。
    -- 这里多做任何事都会让调用方的消息框被顶掉或卡住。
    --
    -- 但要保证 disableInput 不留残留：战斗期间可能被别的模块设过。
    local InputManager = require("framework.input_manager")
    InputManager.disableInput = false
    
    return warState.result
end

-- 手动战斗（协程版本）


--- 取当前战斗状态表（供 WarMain 包装器判断「是否异常结束」）
-- @return table
function WarAsync.getState()
    return warState
end

-- 导出函数（**转发到 script/battle/battle_flow_coroutines.lua**）
--
-- battle-extensibility 阶段 2C：19 个战斗协程搬到 script/battle/ 后，
-- 本模块只做转发，保持既有调用方（async_globals / game_states）
-- 的 `WarAsync.XXXCoroutine` 契约不变。
--
-- 为什么用 pcall 懒加载：协程模块由 jymain.lua 在启动时加载，
-- 而 war_async 可能在更早被 require（此时它还没被加载）。
local battleCoroutines = nil
local function getCoroutines()
    if battleCoroutines then return battleCoroutines end
    local ok, mod = pcall(require, "script.battle.battle_flow_coroutines")
    if ok and type(mod) == "table" then
        battleCoroutines = mod
    else
        -- 退化：从全局函数表取（jymain.lua 用 load 加载时会写 _G）
        battleCoroutines = {}
        for _, name in ipairs({
            "War_ManualCoroutine", "War_Manual_SubCoroutine", "War_AutoMoveCoroutine",
            "War_AutoCoroutine", "War_SettlementCoroutine", "War_GameOverCoroutine",
            "War_AttackCoroutine", "War_Fight_ExecuteCoroutine", "War_Fight_SubCoroutine",
            "War_MoveCoroutine", "War_MovePersonCoroutine", "War_ShowFightCoroutine",
            "War_PoisonCoroutine", "War_DecPoisonCoroutine", "War_DoctorCoroutine",
            "War_ExecuteMenu_SubCoroutine", "War_ExecuteMenuCoroutine",
            "War_ThingMenuCoroutine", "War_StatusMenuCoroutine",
            "SelectTargetCoroutine",
        }) do
            local f = rawget(_G, name)
            if f then battleCoroutines[name] = f end
        end
    end
    return battleCoroutines
end

-- 生成转发（惰性：调用时才查表，不是加载时就绑死）
for _, name in ipairs({
    "War_ManualCoroutine", "War_AutoCoroutine", "War_SettlementCoroutine",
    "War_AttackCoroutine", "SelectTargetCoroutine", "War_MoveCoroutine",
    "War_ShowFightCoroutine", "War_Manual_SubCoroutine", "War_MovePersonCoroutine",
    "War_Fight_SubCoroutine", "War_Fight_ExecuteCoroutine", "War_AutoMoveCoroutine",
    "War_PoisonCoroutine", "War_DecPoisonCoroutine", "War_DoctorCoroutine",
    "War_ExecuteMenuCoroutine", "War_ExecuteMenu_SubCoroutine",
    "War_ThingMenuCoroutine", "War_StatusMenuCoroutine", "War_GameOverCoroutine",
}) do
    WarAsync[name] = function(...)
        local mod = getCoroutines()
        local f = mod and mod[name]
        if f then return f(...) end
        return nil
    end
end

--- 每帧推进战斗规则（battle-extensibility Task 4）
--
-- **这是「即时战斗」的前提**：现有回合制战斗是「等键驱动」的（协程挂在
-- FlowFacade.waitKey 上），收不到 dt。本函数由 EventBridge:update(dt)
-- 每帧调用，把 dt 传给策略层。
--
-- turnbased 下 strategy.tick 是**空实现**（零开销，零回归）：
-- 回合制的推进仍在 battle_flow 的协程里。
--
-- @param dt number 帧间隔（秒）
-- @return boolean 策略是否处理了本帧
function WarAsync.tick(dt)
    if type(dt) ~= "number" or dt <= 0 then return false end
    if warState.status ~= "running" then return false end

    local ok, BattleRules = pcall(require, "script.battle.battle_rules")
    if not ok or type(BattleRules) ~= "table" then return false end

    warState.ctx = warState.ctx or {
        warId = warState.warId,
        round = 0,
        turn = 0,
    }
    warState.ctx.warId = warState.warId

    local strategy = nil
    if BattleRules.current then
        local okC, s2 = pcall(BattleRules.current)
        if okC and type(s2) == "table" then strategy = s2 end
    end
    if not strategy then return false end

    -- 首次 tick 前调一次 init（懒初始化，避免 WarMainCoroutine 的多分支漏调）
    if not warState.ctxInited then
        warState.ctxInited = true
        if type(strategy.init) == "function" then
            pcall(strategy.init, warState.ctx)
        end
    end

    if type(strategy.tick) == "function" then
        -- 返回策略的**真实结果**，不是 pcall 的成功与否
        local okT, r = pcall(strategy.tick, warState.ctx, dt)
        if okT then return r == true end
        return false
    end
    return false
end

-- 获取战斗状态
function WarAsync.getWarState()
    return warState
end

-- 重置战斗状态
function WarAsync.reset()
    warState = {
        warId = nil,
        isExp = 1,
        status = "idle",
        result = nil,
        round = 0,
        currentPerson = 0,
        ctx = nil,
        ctxInited = false,
    }
end

return WarAsync