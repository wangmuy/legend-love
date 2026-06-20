## Context

金庸群侠传原版没有随机遇敌设计，所有战斗均通过事件脚本（oldevent）在具体场景中触发。
战斗系统提供 `WmapHandlers.initWar()` 接口供脚本调用，从 wars.json 读取战斗配置。
胜利后获得经验/金钱，失败则返回 MMAP。

## Decisions

```
事件脚本 (oldevent/*.lua)
  → instruct_N 调用 WmapHandlers.initWar(enemies, distance)
  → JY.Status = GAME_WMAP (5)
  → 玩家通过 choose N 操作战斗（攻击/武功/物品/防御/移动）
  → 战斗胜利 → 经验/金钱奖励 → GAME_MMAP
  → 战斗失败 → GAME_MMAP（无惩罚）
```

MMAP（大地图）在文字版中仅作为中转状态：
- `look` — 查看位置 + 附近场景
- `list` — 列出所有可去场景
- `choose N` — 选择场景进入 / 菜单选择
- `quit` — 返回开始菜单

无需行走/探索命令（无 2D 地图渲染）。
