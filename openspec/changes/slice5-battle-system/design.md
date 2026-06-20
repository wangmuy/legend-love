## Context

当前有 3 个游戏状态：GAME_START(0), GAME_MMAP(2), GAME_SMAP(4)。需要新增 GAME_WMAP(3) 用于战斗。
战斗基于 1D 线性距离模型，与 Love2D 原版的 war.sta 数据兼容。

## Decisions

### GAME_WMAP 状态

```lua
JY.Status = 3  -- GAME_WMAP
```

### 运行时战斗状态

```lua
JY.War = {
    enemies = {},        -- 敌方队伍 [{personId, hp, mp, x}]
    teammates = {},      -- 我方队伍 [{personId, hp, mp, x}]
    turn = 0,            -- 0=我方 1=敌方
    round = 1,           -- 回合数
    distance = 5,        -- 敌我距离
    warId = 0,           -- war.sta 中的战斗 ID
}
```

### 伤害计算公式

```
物理伤害 = 攻击力 - 防御力/2 + 随机(0~20)
武功伤害 = 武功威力 + 攻击力/3 - 防御力/3 + 随机(0~10)
```

### 敌我距离

```
move 阎基 3  → 我方走近 3 步，距离减 3
move 阎基 -2 → 我方远离 2 步，距离加 2
武器攻击范围: 拳掌 0-1, 剑/刀 0-2, 特殊 0-3, 暗器 1-4
```

## Review Checklist

1. 进入 WMAP 后 look 显示战场态势
2. move 命令能改变敌我距离
3. attack 命令能在范围内攻击
4. 敌回合 AI 能做出决策
