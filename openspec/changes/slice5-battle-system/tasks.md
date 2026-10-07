## 1. wmap-engine
Traceability: [REQ-001]

- [x] 1.1 注册 GAME_WMAP 状态 + 命令表（look + choose）
  Blast Radius: `["game/engine-web/web_game_bridge.lua", "game/engine-web/wmap_handlers.lua"]`
  DoD: `JY.Status = 5` 正常工作，`look` + `choose` 命令在 WMAP 状态可访问
- [x] 1.2 JY.War 运行时战斗状态表
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `initWar()` 创建 `JY.War`，包含 teammates/enemies/turn/round/distance 字段
- [x] 1.3 1D 距离模型（位置/移动/攻击范围计算）
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `inRange()` 根据武功类型计算攻击范围，`doMove()` 改变 `war.distance`
- [x] 1.4 回合交替系统（我方行动→敌方AI→我方）
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: 所有队友行动后→`enemyTurn()`→所有敌方行动后→下回合
- [x] 1.5 伤害计算公式
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `calcDamage()` 实现物理/武功伤害计算

## 2. wmap-commands
Traceability: [REQ-002]

- [x] 2.1 look — 战场态势 + 队友列表
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `look` 显示敌我双方 HP/MP/位置/距离，回合信息
- [x] 2.2 choose N — 队友/行动/目标路由
  Blast Radius: `["game/engine-web/wmap_handlers.lua", "game/engine-web/web_game_bridge.lua"]`
  DoD: `chooseInteraction()` 按 `wmapContext.phase` 路由到对应处理函数
- [x] 2.3 攻击（含范围检查）
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `doAttack()` 检查距离、计算伤害、更新敌方 HP
- [x] 2.4 武功子菜单（列出武功 + 范围检查）
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `showMartialArts()` 列出玩家武功，`doMartial()` 执行武功伤害
- [x] 2.5 物品子菜单（药品/暗器）
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `showItems()` 列出背包物品，选中后使用并从背包移除
- [x] 2.6 查看状态
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `showTeammateStatus()` 显示角色 ATK/DEF/SPD/HP/MP

## 3. 测试

- [x] 3.1 WMAP E2E 测试（initWar → look → attack → 胜利 → 奖励）
  Blast Radius: `["game/engine-web/tests/wmap-e2e.spec.js"]`
  DoD: 6 个 E2E 测试全部通过，覆盖 initWar/look/attack/胜利/奖励/武功菜单
- [x] 3.2 武功菜单 E2E 测试
- [x] 3.3 战斗胜利奖励 E2E 测试

## 设计决策

- 金庸群侠传原版无随机遇敌，所有战斗由事件脚本触发
- MMAP 在文字版中仅作中转状态（look + list + choose N）
- wmap-encounter change 已删除（基于随机遇敌错误假设）
