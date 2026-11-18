-- input_actions.lua（游戏层）
-- 游戏私有动作注册
--
-- 这里**只有**金庸群侠传特有的动作。framework 通用层（ui.*）不包含它们，
-- 因为 framework 要能复用到仙剑、白金英雄坛说等任意游戏
-- （见 openspec/changes/input-action-layer/design.md ADR-1）。

local InputBindings = require("framework.input_bindings")

local GameInputActions = {}

-- ---------------------------------------------------------------------------
-- 金庸特有动作
-- ---------------------------------------------------------------------------
-- 原版的「是/否」快捷键。注意它们**不是** ui.accept / ui.cancel：
--   Y 表达的是「对『要不要当帮主』答是」（语义上的是）
--   ui.accept 表达的是「推进 / 确认当前选中」
-- 两者在是/否框里结果相反，所以必须分开。

GameInputActions.Y = "jy.y"
GameInputActions.N = "jy.n"

GameInputActions.ALL = { GameInputActions.Y, GameInputActions.N }

--- 注册绑定（把 y / n 键绑到 jy.y / jy.n）
--
-- 幂等：重复调用不会产生重复绑定。
--
-- @return boolean ok
function GameInputActions.register()
    InputBindings.bindAction("key", "y", GameInputActions.Y)
    InputBindings.bindAction("key", "n", GameInputActions.N)
    return true
end

return GameInputActions
