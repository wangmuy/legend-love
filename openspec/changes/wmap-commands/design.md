## Context

WMAP 状态的战斗命令全部通过菜单驱动（look + choose），无独立命令。
与 SMAP 一致，`choose N` 路由到队友/行动/目标三级选择。

## Decisions

```
look → 战场态势 + 可选队友
choose N → 选队友 → 行动菜单 → 选目标 → 执行
```

行动菜单：攻击/武功/物品/防御/移动/查看

## Tasks

Traceability: [REQ-002]

- [x] 1.1 look — 战场态势 + 队友列表
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: 显示敌我双方位置/HP/MP，标记已行动队友
- [x] 1.2 choose N — 队友/行动/目标路由
  Blast Radius: `["game/engine-web/wmap_handlers.lua", "game/engine-web/web_game_bridge.lua"]`
  DoD: 三级路由（选队友→选行动→选目标）正常流转
- [x] 1.3 攻击 — 选目标 + 伤害计算
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `doAttack()` 检查距离、计算伤害、更新 HP
- [x] 1.4 防御 — 减伤
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `doDefend()` 标记防御状态
- [x] 1.5 移动 — 走近/远离
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `doMove()` 改变 `war.distance` 值
- [x] 1.6 武功 — 列出可用武功 + 范围检查
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `showMartialArts()` 显示所有已学武功
- [x] 1.7 物品 — 使用药品/暗器
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `showItems()` 显示背包物品，使用后从背包移除
- [x] 1.8 查看状态 — 角色属性
  Blast Radius: `["game/engine-web/wmap_handlers.lua"]`
  DoD: `showTeammateStatus()` 显示 ATK/DEF/SPD/HP/MP
