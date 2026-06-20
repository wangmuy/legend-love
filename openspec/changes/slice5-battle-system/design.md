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

### 菜单驱动交互（与 SMAP 一致）

```
WMAP 交互流:

  look → 战场态势 + 行动队友列表（编号列表）
  choose N → 选队友 → 行动菜单 → 选目标 → 执行

  三级菜单流程:
  1. look → 显示战场 + 可选队友（✓ = 未行动）
  2. choose N → 选择队友 → 显示该队友的行动菜单
  3. 攻击/武功 → 选目标（敌方）→ 执行
  4. 物品 → 选目标（己方/敌方）→ 执行
  5. 防御/移动/查看 → 执行/选参数

  单人战斗时"选队友"自动跳过（仅主角一个选项）。
```

## Review Checklist

1. 进入 WMAP 后 look 显示战场态势
2. move 命令能改变敌我距离
3. attack 命令能在范围内攻击
4. 敌回合 AI 能做出决策
