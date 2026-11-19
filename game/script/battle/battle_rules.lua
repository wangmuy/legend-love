-- battle_rules.lua
-- 战斗规则策略（battle-extensibility）
--
-- **本文件是本 change 的可扩展性核心**：
--   MOD 只要在 `mods/<mod>/script/battle/battle_rules.lua` 放一个
--   同形状的文件，就能整体替换战斗规则：
--     回合制（turnbased）→ 半即时（ATB）→ 即时（realtime / Hades 式）
--
-- 契约（ADR-BE-002 的六字段）：
--   kind           string   "turnbased" | "atb" | "realtime"
--   init(ctx)              战斗开始（初始化计时条等）
--   tick(ctx, dt)          每帧推进（atb/realtime 用；turnbased 空实现）
--   requestAction(ctx, unit, cb)  请求一个行动
--   onKey(ctx, key)        输入分发（realtime 用）
--   isOver(ctx)            结束判定
--
-- **为什么 kind 是单点决策**：
--   war_async 读一次 kind，之后只调钩子。新增第四种战斗类型
--   只需实现新钩子 + 新 kind，war_async 零改动。
--
-- 阶段说明：
--   本文件的 turnbased 实现**复刻现有回合制行为**（推进在 battle_flow 的协程里，
--   tick 为空实现）。atb / realtime 只留接口骨架，供 MOD 继承与覆盖。

local BattleRules = {}

-- ---------------------------------------------------------------------------
-- 三种 kind 的常量
-- ---------------------------------------------------------------------------

BattleRules.KIND_TURNBASED = "turnbased"
BattleRules.KIND_ATB       = "atb"
BattleRules.KIND_REALTIME  = "realtime"

-- ---------------------------------------------------------------------------
-- turnbased（现状：回合制，等键驱动）
-- ---------------------------------------------------------------------------
--
-- tick 是**空实现**：回合制的推进由 battle_flow 的协程完成
-- （War_MoveCoroutine 等 → FlowFacade.waitKey()）。
-- 这样加 tick 不改变任何现有行为（零回归）。

local function initTurnbased(ctx)
    if type(ctx) ~= "table" then return false end
    ctx.turn = ctx.turn or 0
    if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
        EngineAPI.debug.log("battle_rules: turnbased init")
    end
    return true
end

local function tickTurnbased(ctx, dt)
    -- 回合制不需要每帧推进：这里刻意什么都不做。
    -- 若将来要做「回合倒计时」，在这里累加 ctx.turnElapsed 即可。
    return true
end

local function isOverTurnbased(ctx)
    -- 回合制的结束判定由 battle_flow（War_isEnd）负责，
    -- 策略层不做判断，保持单一职责。
    return false
end

-- ---------------------------------------------------------------------------
-- atb（半即时：计时条填充）—— 接口骨架
-- ---------------------------------------------------------------------------

local function initATB(ctx)
    if type(ctx) ~= "table" then return false end
    ctx.atb = ctx.atb or {}
    if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
        EngineAPI.debug.log("battle_rules: atb init（骨架，未实现）")
    end
    return true
end

local function tickATB(ctx, dt)
    -- **骨架**：真实的 ATB 需要为每个单位累加 atbGauge，
    -- 达到阈值时触发 requestAction。本 change 只留接口。
    if type(ctx) ~= "table" or type(ctx.atb) ~= "table" then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- realtime（即时：Hades 式）—— 接口骨架
-- ---------------------------------------------------------------------------

local function initRealtime(ctx)
    if type(ctx) ~= "table" then return false end
    ctx.realtime = ctx.realtime or { elapsed = 0 }
    if EngineAPI and EngineAPI.debug and EngineAPI.debug.log then
        EngineAPI.debug.log("battle_rules: realtime init（骨架，未实现）")
    end
    return true
end

local function tickRealtime(ctx, dt)
    -- **骨架**：真实时战斗需要每帧推进实体位置/冷却/动画。
    -- 本 change 只留接口 —— 玩法实现属 MOD 的职责。
    if type(ctx) ~= "table" or type(ctx.realtime) ~= "table" then return false end
    ctx.realtime.elapsed = ctx.realtime.elapsed + (tonumber(dt) or 0)
    return true
end

local function onKeyRealtime(ctx, key)
    -- **骨架**：即时战斗的持续输入分发。
    return true
end

-- ---------------------------------------------------------------------------
-- 导出
-- ---------------------------------------------------------------------------

--- 按 kind 取一套实现
--
-- @param kind string|nil 默认 "turnbased"
-- @return table 策略实现（六字段齐全）
function BattleRules.get(kind)
    kind = kind or BattleRules.KIND_TURNBASED

    if kind == BattleRules.KIND_ATB then
        return {
            kind = kind,
            init = initATB,
            tick = tickATB,
            requestAction = function() return true end,
            onKey = function() return true end,
            isOver = function() return false end,
        }
    elseif kind == BattleRules.KIND_REALTIME then
        return {
            kind = kind,
            init = initRealtime,
            tick = tickRealtime,
            requestAction = function() return true end,
            onKey = onKeyRealtime,
            isOver = function() return false end,
        }
    end

    -- 默认：turnbased
    return {
        kind = BattleRules.KIND_TURNBASED,
        init = initTurnbased,
        tick = tickTurnbased,
        requestAction = function() return true end,
        onKey = function() return true end,
        isOver = isOverTurnbased,
    }
end

--- 当前生效的策略（读全局 BattleRules 的 kind，缺省 turnbased）
-- @return table
function BattleRules.current()
    local g = rawget(_G, "BattleRules")
    local kind = (type(g) == "table" and g.kind) or BattleRules.KIND_TURNBASED
    return BattleRules.get(kind)
end

-- 模块自身也实现六字段（默认 turnbased）—— 让 `BattleRules.kind` 可直接读
BattleRules.kind = BattleRules.KIND_TURNBASED
BattleRules.init = initTurnbased
BattleRules.tick = tickTurnbased
BattleRules.requestAction = function() return true end
BattleRules.onKey = function() return true end
BattleRules.isOver = isOverTurnbased

return BattleRules
