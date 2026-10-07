## 1. GAME_WMAP 状态注册
- [x] 1.1 注册 GAME_WMAP(5) + 命令表（look + choose）
  Blast Radius: `["game/engine-web/web_game_bridge.lua", "game/engine-web/wmap_handlers.lua"]`
  DoD: WMAP 状态注册后可通过 `look` 和 `choose` 命令交互
- [x] 1.2 JY.War 运行时战斗状态表
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `initWar()` 创建完整 `JY.War` 结构
- [x] 1.3 1D 距离模型（位置/移动/攻击范围计算）
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `inRange()` + `doMove()` 正确计算并更新距离
- [x] 1.4 回合交替系统
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `afterAction()` → `enemyTurn()` → 下回合
- [x] 1.5 伤害计算公式
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `calcDamage()` 实现物理/武功伤害

## 2. 测试
- [x] 2.1 WMAP E2E 测试（6 个测试覆盖 initWar → look → choose → attack → 胜利/奖励）
  Blast Radius: `["game/engine-web/tests/wmap-e2e.spec.js"]`
  DoD: 全部通过
