# Change Manifest — 战斗系统 (Slice 5)

## 依赖顺序

```
slice5-battle-system (战斗系统)
  │
  ├── wmap-engine      (战斗状态机 + 1D距离模型 + 回合系统)
  │
  ├── wmap-commands    (move/attack/wugong/defend/item/status)
  │
  └── wmap-encounter   (遇敌 + war.sta + 战斗结果)
```

## Change Assignments

### 1. wmap-engine

| 字段 | 值 |
|------|-----|
| Scope | 战斗核心引擎 |
| Responsibility | GAME_WMAP 状态管理、1D 距离模型、回合交替系统、AI 决策 |
| Depends on | Slice 4, event-system-integration |

### 2. wmap-commands

| 字段 | 值 |
|------|-----|
| Scope | 战斗命令 |
| Responsibility | move/attack/wugong/defend/item/status/look/help |
| Depends on | wmap-engine |

### 3. wmap-encounter

| 字段 | 值 |
|------|-----|
| Scope | 遇敌 + 数据 |
| Responsibility | 从 war.sta 读取战斗配置、随机遇敌、战斗胜利/失败处理 |
| Depends on | wmap-engine, wmap-commands |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| `CC.WarData_S` | 战斗配置结构体（186 字节） |
| `JY.War` | 运行时战斗状态表 |
| `WMAP_*` constants | 战斗状态命令注册 |
