# battle-extensibility 依赖测绘（Task 1）

## 1. 代码分布

```
script/jymain.lua            7347 行（其中 War_* 区块约 1501 行）
framework/war_async.lua      1651 行（19 个协程）
```

## 2. 54 个 War_* 函数的调用形态统计

| 形态 | 数量 | 例子 |
|------|------|------|
| 普通调用 `War_X(args)` | 44 个函数 | `War_CalMoveStep`（18 次，最高） |
| 菜单回调引用 `{"移动", War_MoveMenu, 1}` | 7 个函数 | `War_MoveMenu` / `War_FightMenu` / `War_PoisonMenu` / `War_DecPoisonMenu` / `War_DoctorMenu` / `War_ThingMenu` / `War_StatusMenu` |
| 两者都有 | 3 个（`War_RestMenu` / `War_WaitMenu` / `War_AutoMenu`） | |

**重要**：那 7 个"零调用"函数不是死代码 —— 它们是
`War_Manual_Sub` 里菜单项的第 2 项（回调函数引用，没有括号）。

## 3. 跨文件调用关系

```
framework/war_async.lua  ← 19 个 War_*Coroutine（战斗流程协程）
        │  直接调用全局函数（无 require）
        ▼
script/jymain.lua        ← 54 个 War_*（算法/伤害/移动/AI）
```

**双方都调用对方的函数**：

| 函数 | war_async 调用 | jymain 调用 |
|------|---------------|------------|
| `War_CalMoveStep` | ✅ | ✅ |
| `War_Direct` | ✅ | ✅ |
| `War_ShowFight` | ✅（协程版） | ✅（同步版） |
| `War_EndPersonData` | ✅ | ✅ |
| `War_PoisonHurt` | ✅ | ✅ |
| `War_AutoSelectEnemy` 等 AI | ✅ | ✅ |

## 4. 加载顺序约束

```
main.lua:61   require(CONFIG.ScriptPath .. "jymain")
main.lua:64   JYMainAdapter.init()
                └─ war_async 由 game_states / async_globals require
```

`jymain.lua` 先加载 → 它的 `War_*` 成为**全局函数** → war_async 才能调用。

**搬移时必须保持这个顺序**：`script/battle/*.lua` 必须在
`war_async` 首次被 require 之前加载完（否则全局函数还没定义）。

## 5. MOD 覆盖的可行性

MOD 回退链（`framework/mod_data.lua:335` 的 `ScriptFile`）：

```
mods/<mod>/script/<rel>   优先
script/<rel>              兜底
```

所以 `script/battle/battle_rules.lua` **可以被 MOD 覆盖**。

但 `main.lua:61` 是 `require(CONFIG.ScriptPath .. "jymain")`，
**不走 `ModData.ScriptFile`** → MOD 无法覆盖 `jymain.lua` 本身。
这正是把战斗搬到 `script/battle/` 的意义。

## 6. 搬移计划（阶段 1）

| 目标文件 | 搬入内容 | 约行数 |
|---------|---------|--------|
| `script/battle/battle_action.lua` | `War_CalMoveStep` / `War_MovePerson` / `War_Fight_Sub` / `War_WugongHurtLife` / `War_WugongHurtNeili` / `War_AnqiHurt` / `War_FindNextStep` / `War_CanMoveXY` / `War_Direct` | ~600 |
| `script/battle/battle_ai.lua` | `War_AutoSelectEnemy` / `War_AutoCalMaxEnemy` / `War_AutoEscape` / `War_ThinkDrug` / `War_Auto*` 系列 | ~400 |
| `script/battle/battle_flow.lua` | 19 个协程（从 war_async 搬入）+ `War_Manual` / `War_Auto` / `War_Manual_Sub` | ~1400 |
| `script/battle/battle_render.lua` | `War_ShowFight` / `WarDrawMap` 相关 | ~150 |
| `script/battle/battle_rules.lua` | 阶段 1 只放 `return { kind = "turnbased" }` | ~10 |

**总计约 2560 行**。这是本 change 阶段 1 的实际工作量。

## 7. 关键风险

| 风险 | 说明 |
|------|------|
| 全局函数可见性 | 阶段 1 保留 `function War_X()` 全局定义形式，只换文件位置 |
| 加载顺序 | `script/battle/*.lua` 必须在 war_async 之前加载 |
| 交叉引用 | 54 个函数之间有 30 个互相调用，必须整体搬（不能分批） |
| `War_Manual_Sub` 的菜单回调 | 7 个回调引用的函数要和它同文件或保证加载顺序 |
