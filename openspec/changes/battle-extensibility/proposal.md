# Change Proposal: battle-extensibility — 战斗场景可扩展化

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）

## Why

用户要求：**战斗场景要能支持后续修改，譬如改为半即时、即时或 Hades 一样的战斗。**

当前**做不到**，有两个结构性原因。

### 原因 1：战斗代码住在 MOD 无法覆盖的位置

实测 MOD 系统的回退链只有两条：

```
mods/<mod>/script/<rel>   优先
script/<rel>              兜底
```

`framework/` **完全不在回退链里**（`grep framework game/framework/mod_data.lua`
无作为路径的命中）。

而战斗代码分布在两处：

```
framework/war_async.lua   19 个 War_*Coroutine（事件驱动化的战斗流程）
                          91 处协程引用
script/jymain.lua         54 个 War_*（战斗算法/伤害公式/移动步数/AI）
```

**两处都不能被 MOD 覆盖。**

### 原因 2：战斗流程是「等键驱动」，无法每帧推进

现有战斗是回合制：`War_MoveCoroutine` 调用 `FlowFacade.waitKey()` 挂起，
等玩家按键才继续。

```
War_MoveCoroutine
  → WaitKey() 挂起          ← 战斗在这里停止推进
  → 玩家按键
  → 恢复执行
```

**即时战斗需要每帧 `tick(ctx, dt)`**，而 `dt` 现在根本没有传进战斗
（`EventBridge:update(dt)` 传到 `StateMachine:update(dt)`，但战斗在协程里跑）。

### 原因 3：「三种战斗」是三种架构，不是参数开关

| 类型 | 驱动方式 | 玩家输入 | 时间 |
|------|---------|---------|------|
| 回合制（现状） | 等键 | 阻塞 | 离散 |
| 半即时（ATB） | 计时条填充 | 随时可输入 | 连续计时 + 离散行动 |
| 即时（Hades） | 每帧 tick | 持续输入 | 完全连续 |

**不是加个 `if kind == "realtime"` 就能切换的** —— 事件循环、输入模型、
渲染循环三者都要变。

---

## In Scope

### 1. 抽出 `script/battle/` 五模块（先搬不改逻辑）

```
script/battle/
├── battle_flow.lua      战斗主流程（谁先动、回合边界、结束判定）
├── battle_rules.lua     规则策略（turnbased / realtime / atb）
├── battle_ai.lua        敌方 AI 选敌与行动
├── battle_action.lua    动作执行（移动/攻击/武功/道具）
└── battle_render.lua    战斗绘制
```

关键约束：**先纯搬移，不改逻辑**。原回合制战斗行为必须逐帧不变。

### 2. `battle_rules` 策略接口

```lua
-- 策略模块的契约（三种实现共用）
return {
    kind = "turnbased",                 -- "turnbased" | "atb" | "realtime"
    init = function(ctx) end,           -- 战斗开始
    tick = function(ctx, dt) end,       -- 每帧推进（turnbased 可空实现）
    requestAction = function(ctx, unit) end,  -- 请求一个行动（可能异步）
    onKey = function(ctx, key) end,     -- 输入分发（realtime 用）
    isOver = function(ctx) return false end,
}
```

### 3. `war_async.lua` 降为适配层

现在 `war_async.lua` 拥有战斗逻辑；改造后它只做：

```
EventBridge:update(dt)
  → war_async.tick(dt)
    → battle_rules.tick(ctx, dt)      ← 真正的推进在这里
    → battle_flow.step(ctx)           ← 流程（回合边界等）
```

### 4. `dt` 传播到战斗

`battle_rules.tick(ctx, dt)` 每帧被调，`dt` 来自 `EventBridge:update(dt)`。

与 `port-sprite-animation` 的 `sprite_anim.update(dt)` 是同类改造。

### 5. 门禁：战斗代码位置断言

```
✗ framework/ 不得出现 War_* 战斗算法（只能有适配层调用）
✓ script/battle/ 的五个模块必须存在且可被 MOD 覆盖
```

## Out of Scope

```
✗ 实际实现 Hades 式战斗  —— 本 change 只提供架构与接口，不写玩法
✗ 改造现有回合制的手感    —— 零回归是硬约束
✗ ATB 计时条的 UI        —— 后续按需
✗ 战斗渲染的视觉重做     —— 只搬不改
✗ 骨骼动画 / 粒子特效    —— 无消费方
```

## 关键度量

| 指标 | 基线 | 目标 |
|------|------|------|
| `framework/` 里的 `War_*` 算法 | war_async 里 19 协程 + 调用 script 54 个 | **只能在 `script/battle/`** |
| MOD 能否覆盖战斗流程 | ❌（在 framework） | ✅（在 script/battle） |
| 原回合制战斗行为 | — | **逐帧零变化** |
| `dt` 传播 | ❌ 战斗收不到 dt | ✅ `tick(ctx, dt)` |
| 策略切换 | 硬编码分支 | `battle_rules.kind` 单点 |

## 风险

| 风险 | 缓解 |
|------|------|
| 搬移 54 个函数 + 19 个协程时漏依赖 | 先只搬文件位置（值/函数不动），跑全量测试 |
| 战斗回归只在实机可见 | 每批改动后实机跑一场手动战斗 + 一场自动战斗 |
| `War_*` 之间有隐式全局依赖 | 搬移前先 grep 所有交叉引用，画出依赖图 |
| ATB / realtime 接口设计过早 | 只为 turnbased 提供完整实现，另两个只留接口 |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-BE-1 | 战斗代码必须在 MOD 可覆盖路径 | specs/battle-extensibility/spec.md |
| REQ-BE-2 | 策略接口支持三种 kind | 同上 |
| REQ-BE-3 | dt 传播到战斗 | 同上 |
| REQ-BE-4 | 原回合制零回归 | 同上 |
| REQ-BE-5 | framework 只留适配层 | 同上 |
