# Battle Extensibility

## ADDED Requirements

### Requirement: REQ-BE-1 战斗代码必须在 MOD 可覆盖路径

战斗逻辑（流程 / 规则 / AI / 动作 / 渲染）SHALL 位于 `script/battle/`，
SHALL NOT 位于 `framework/`。

依据：MOD 系统的回退链只有 `mods/<mod>/script/<rel>` → `script/<rel>` 两条，
`framework/` 不在其中。实测 17 个既有 MOD 都靠这条链注入 `script/oldevent/`。

#### Scenario: MOD 可以覆盖战斗流程

- **GIVEN** 一个 MOD 在 `mods/<mod>/script/battle/battle_flow.lua` 放了实现
- **WHEN** 游戏启动并进入战斗
- **THEN** 加载的是该 MOD 的实现，不是 `script/battle/battle_flow.lua`

#### Scenario: framework 里没有战斗算法

- **GIVEN** 改造完成
- **WHEN** 执行 `grep -c 'function War_' game/framework/*.lua`
- **THEN** 命中数 = 0（`war_async.lua` 只留适配层的 `war_async.tick(dt)`）

### Requirement: REQ-BE-2 策略接口支持三种战斗类型

`battle_rules` SHALL 提供统一的策略接口，至少支持：

- `turnbased` —— 回合制（现状，等键驱动）
- `atb` —— 半即时（计时条填充）
- `realtime` —— 即时（每帧 tick + 持续输入）

#### Scenario: 策略通过 kind 字段选择

- **GIVEN** `battle_rules` 返回 `{ kind = "turnbased", ... }`
- **WHEN** 战斗开始
- **THEN** `war_async` 按 kind 走回合制路径

#### Scenario: realtime 策略必须实现 tick

- **GIVEN** `battle_rules.kind == "realtime"`
- **WHEN** 每帧调用
- **THEN** `battle_rules.tick(ctx, dt)` 被调用，且 `dt > 0`

#### Scenario: turnbased 的 tick 可以是空实现

- **GIVEN** `battle_rules.kind == "turnbased"`
- **WHEN** 每帧调用
- **THEN** `tick` 不抛错即可（回合制推进在 `requestAction` 里）

### Requirement: REQ-BE-3 dt 传播到战斗

`dt` SHALL 从 `EventBridge:update(dt)` 传播到 `battle_rules.tick(ctx, dt)`。

现状缺口：`dt` 传到 `StateMachine:update(dt)`，但战斗在协程里跑，
**协程收不到 dt**。

#### Scenario: 战斗 tick 收到正确的 dt

- **GIVEN** 战斗进行中
- **WHEN** `EventBridge:update(0.016)` 被调用
- **THEN** `battle_rules.tick(ctx, 0.016)` 被调用

### Requirement: REQ-BE-4 原回合制战斗零回归

改造 SHALL NOT 改变原版回合制战斗的任何可见行为。

#### Scenario: 手动战斗流程不变

- **GIVEN** 改造前录制的战斗过程（移动 / 攻击 / 武功 / 道具 / 结束）
- **WHEN** 用改造后版本执行同样操作
- **THEN** 每一步的结果（伤害数值 / 命中判定 / 移动步数 / 结算）逐项一致

#### Scenario: 自动战斗结果可复现

- **GIVEN** 相同的 `Rnd` 种子（`math.randomseed`）
- **WHEN** 跑一场自动战斗
- **THEN** 改造前后结果完全一致

### Requirement: REQ-BE-5 framework 只留适配层

`framework/war_async.lua` SHALL 只做「把 battle_flow 接到事件驱动循环」的适配，
SHALL NOT 包含战斗规则 / 伤害公式 / AI 决策。

#### Scenario: war_async 不再定义战斗算法

- **GIVEN** 改造完成
- **WHEN** 检查 `framework/war_async.lua`
- **THEN** 只有 `War_*Coroutine` 的调度调用，没有 `War_CalMoveStep` 之类的算法调用
  （算法全在 `script/battle/battle_action.lua`）

#### Scenario: 门禁拦住新算法进 framework

- **GIVEN** 有人往 `framework/war_async.lua` 里写了伤害公式
- **WHEN** 运行 `gate_battle_extensibility.sh`
- **THEN** 门禁 FAIL
