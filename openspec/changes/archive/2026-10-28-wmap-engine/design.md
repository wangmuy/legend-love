## Context

GAME_WMAP(5) 是战斗状态，需要独立的运行时数据结构和回合交替系统。
基于 1D 线性距离模型，与 Slice 4 的菜单驱动交互一致。

## Decisions

### 运行时战斗状态 `JY.War`

```lua
JY.War = {
    teammates = {{personId, hp, hpMax, mp, mpMax, x}},
    enemies = {{personId, hp, hpMax, mp, mpMax, x}},
    turn = 0, round = 1, distance = 5, warId = 0, acted = {}
}
```

### 回合交替

我方回合 → 选队友 → 选行动 → 选目标 → 执行 → 下个队友/敌回合

## Review Checklist

1. WmapHandlers.initWar 初始化战斗
2. look 显示战场态势 + 可选队友
3. 回合交替正确
4. AI 能做基本决策
