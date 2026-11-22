# Design: battle-extensibility — 战斗架构改造

> 父 slice: `engine-portability`

## Context

用户要求战斗场景支持「半即时 / 即时 / Hades 式」。当前做不到，三个结构性原因：

### 1. 战斗代码在 MOD 无法覆盖的位置

MOD 回退链**只有两条**（`framework/mod_data.lua:335-352` 的 `ScriptFile`）：

```
mods/<mod>/script/<rel>   优先
script/<rel>              兜底
```

`framework/` 不在其中。而战斗代码在：
- `framework/war_async.lua` —— 19 个 `War_*Coroutine`，91 处协程引用
- `script/jymain.lua` —— 54 个 `War_*` 算法 + `GetWarMap`/`SetWarMap` + `Rnd`

**两处都不可覆盖。**

### 2. 战斗是「等键驱动」

```
War_MoveCoroutine
  → FlowFacade.waitKey()    ← 挂起
  → 玩家按键
  → 恢复
```

即时战斗需要每帧 `tick(ctx, dt)`，而这个协程模型里**没有 dt**。

### 3. 三种战斗是三种架构

| 类型 | 驱动 | 输入 | 时间 |
|------|------|------|------|
| 回合制 | 等键 | 阻塞 | 离散 |
| ATB | 计时条填充 | 随时可输入 | 连续计时 + 离散行动 |
| 即时 | 每帧 tick | 持续输入 | 完全连续 |

不是开关，是三种循环模型。

---

## ADR-BE-001：战斗代码搬到 `script/battle/`，不搬进 framework

### Decision

```
script/battle/
├── battle_flow.lua      流程（回合边界、谁先动、结束判定）
├── battle_rules.lua     规则策略（唯一有 kind 字段的模块）
├── battle_ai.lua        敌方 AI
├── battle_action.lua    动作执行（移动/攻击/武功/道具）
└── battle_render.lua    绘制
```

`framework/war_async 降为适配层：只调 `battle_flow.step(ctx)` 与
`battle_rules.tick(ctx, dt)`。

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| A. 保持现状（战斗在 framework + script 两处） | MOD 完全无法覆盖，扩展性为零 |
| B. 全搬到 framework | 更糟：MOD 连 framework 都碰不到 |
| C. 全搬到 script/jymain.lua | 2000 行单文件，MOD 覆盖整个 jymain 不现实 |
| **D. 搬到 script/battle/ 五模块** | **采纳**：走既有 MOD 回退链，且模块化后单个 MOD 只需覆盖其中一个 |

### Consequences

- MOD 作者可以只覆盖 `battle_rules.lua` 实现新玩法，其余四个模块照用
- 五个模块之间有依赖图需要理清（见 ADR-BE-003）
- `script/battle/` 是**新目录**，需要确认 MOD 回退链对它生效（实测应该生效，
  因为回退链只看 `script/` 前缀）

---

## ADR-BE-002：策略接口用 kind + 五个可选钩子

### Decision

```lua
-- script/battle/battle_rules.lua 的返回契约
return {
    kind = "turnbased",                     -- 决定 war_async 走哪条路径
    init = function(ctx) end,               -- 战斗开始（初始化计时条等）
    tick = function(ctx, dt) end,           -- 每帧推进（realtime/atb 用）
    requestAction = function(ctx, unit, cb) end,  -- 请求行动（turnbased 主路径）
    onKey = function(ctx, key) end,         -- 输入分发（realtime 用）
    isOver = function(ctx) return false end, -- 结束判定（三种共用）
}
```

**为什么 `kind` 而不是让 war_async 自己分支**：
`kind` 是**单点决策**。war_async 读一次 kind，之后只调钩子。
新增第四种战斗类型只需实现新钩子 + 新 kind，war_async 零改动。

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| A. 每种战斗一个独立入口函数 | war_async 里要写 if/elseif 分支，新增类型要改 war_async |
| B. 用配置文件切换 | 配置无法表达「每帧 tick」这种结构性差异 |
| **C. kind + 钩子** | **采纳**：单点决策 + 可扩展 |

---

## ADR-BE-003：先纯搬移，再改结构（两阶段）

### Context

54 个 `War_*` + 19 个协程 + 40 处 `Rnd` + 40 处 `GetWarMap/SetWarMap`
互相交叉引用。一次性重构必然漏依赖。

### Decision

**阶段 1（纯搬移）**：把代码从 `framework/war_async.lua` 与
`script/jymain.lua` 挪到 `script/battle/` 五个文件，
**逻辑一字不改**，只是位置变了。跑全量测试 + 实机验证。

**阶段 2（改结构）**：引入 `battle_rules` 策略接口，把 war_async 降为适配层。

两阶段各自一个 commit，阶段 1 出问题可以完全回退。

### Consequences

- 阶段 1 的验证标准是「零回归」，不是「有改进」
- 阶段 2 才引入 kind 字段
- 阶段 1 有个**必须解决的前置问题**：`framework/war_async.lua` 调用的
  `War_*` 是**全局函数**，搬走后调用方要能找到它们

### 前置问题：全局函数如何跨文件可见

现有代码靠**全局函数**（`function War_CalMoveStep(...)`）跨文件调用。
搬到 `script/battle/battle_action.lua` 后，如果仍用 `function` 定义，
它还是全局的（Lua 的 `function x()` = `_G.x = ...`），**照旧可见**。

所以阶段 1 可以**保留全局函数定义**，只换文件位置。这样：
- 零风险（函数仍是全局）
- MOD 覆盖生效（文件路径走了回退链）

阶段 2 再考虑是否改成模块表（那时候要同步改所有调用点，是更大的改动）。

---

## ADR-BE-004：dt 从 EventBridge 传到战斗

### Context

`EventBridge:update(dt)` 已经把 dt 传到 `StateMachine:update(dt)`，
但战斗跑在协程里，协程收不到 dt。

### Decision

`war_async.tick(dt)` 由 `EventBridge:update(dt)` 直接调（不经过协程）：

```lua
-- framework/war_async.lua
function WarAsync.tick(dt)
    if not inBattle then return end
    local rules = require("script.battle.battle_rules")
    if rules and rules.tick then
        rules.tick(battleCtx, dt)
    end
end
```

`EventBridge:update(dt)` 里加一行 `pcall(WarAsync.tick, dt)`。

### Consequences

- 战斗中「每帧推进」成为可能
- 回合制下 `tick` 是空实现，零开销
- 协程与 tick 并存：回合制的 `requestAction` 仍走协程 + waitKey

---

## ADR-BE-005：门禁断言

### Decision

新增 `game/tests/gate_battle_extensibility.sh`：

```
A. framework/ 无 War_* 算法定义（只能有适配层）
B. script/battle/ 五个模块都存在
C. battle_rules 有 kind 字段
D. framework/war_async.lua 不含伤害公式特征（War_WugongHurtLife 等）
```

---

## Negative Constraints

```
✗ 不得在本 change 里实现 Hades 式战斗（只提供架构）
✗ 不得改变原回合制战斗的任何可见行为
✗ 不得把战斗代码搬进 framework
✗ 不得一次性完成两阶段（必须先跑通纯搬移的零回归）
✗ 不得引入新的全局函数名（复用既有的 War_* 名字）
✗ 不得在阶段 1 改任何逻辑（包括"顺手修个小 bug"）
```

## Review Checklist

```
[ ] 阶段 1：五模块文件存在，全量测试零回归，实机战斗零回归
[ ] 阶段 2：battle_rules 有 kind + 五钩子
[ ] dt 真的传进 tick（实测 dt > 0）
[ ] 门禁 4 组断言 + 负向对照全部生效
[ ] 四版本 Lua 全量测试零失败
[ ] MOD 覆盖测试：写一个最小 MOD 覆盖 battle_rules，验证生效
```
