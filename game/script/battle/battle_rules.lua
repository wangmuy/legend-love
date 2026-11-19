-- battle_rules.lua
-- 战斗规则策略（battle-extensibility 阶段 1：占位实现）
--
-- 阶段 1 只返回 kind = "turnbased"，不改变任何现有行为。
-- 阶段 2 才让它成为真正的策略接口（init/tick/requestAction/onKey/isOver）。
--
-- **本文件是本 change 的可扩展性核心**：
--   MOD 只要在 `mods/<mod>/script/battle/battle_rules.lua` 放一个
--   同样返回 shape 的文件，就能整体替换战斗规则（回合制 → ATB / 实时）。
--
-- 契约（阶段 2 完整版的形状，阶段 1 只填 kind）：
--   return {
--       kind = "turnbased",                       -- "turnbased"|"atb"|"realtime"
--       init          = function(ctx) end,        -- 战斗开始
--       tick          = function(ctx, dt) end,    -- 每帧推进
--       requestAction = function(ctx, unit, cb) end,  -- 请求行动
--       onKey         = function(ctx, key) end,   -- 输入分发（realtime 用）
--       isOver        = function(ctx) return false end, -- 结束判定
--   }

return {
    kind = "turnbased",
}
