# 协程等待与阻塞消除

## ADDED Requirements

### Requirement: REQ-BD-1 waitForTime 必须真的等待指定时长

`CoroutineScheduler:waitForTime(seconds)` SHALL 在 `seconds` 到期之前
**不恢复**该协程，SHALL NOT 只 yield 一次就返回。

依据（实测）：当前实现记录了 `startTime` 但从未使用，`update(dt)` 每帧
无条件恢复所有非 key/action 协程 → `waitForTime(0.1)` 实际只等 1 帧（16.7ms）。

#### Scenario: 100ms 等待至少跨 5 帧

- **GIVEN** 60fps 的 update 循环
- **WHEN** 协程调用 `scheduler:waitForTime(0.1)`
- **THEN** 协程在**第 6 帧或之后**恢复（不是在帧 2）

#### Scenario: 50ms 等待至少跨 3 帧

- **GIVEN** 60fps 的 update 循环
- **WHEN** 协程调用 `scheduler:waitForTime(0.05)`
- **THEN** 协程在第 3 帧或之后恢复

#### Scenario: 0 或负数不阻塞

- **WHEN** 调用 `waitForTime(0)` 或 `waitForTime(-1)`
- **THEN** 下一帧就恢复（等同 yield 一次）

#### Scenario: deadline 在恢复后被清空

- **GIVEN** 协程的 `waitForTime` 已到期并恢复
- **WHEN** 检查该协程的 `deadline` 字段
- **THEN** 是 `nil`（不留残留）

### Requirement: REQ-BD-2 instruct_30 必须有非阻塞版本

`instruct_30`（主角走动）SHALL 有协程版本，SHALL NOT 在协程里调用
阻塞的 `lib.Delay`。

依据（实测）：`lib.Delay` 是 `love.timer.sleep`，实测阻塞主线程 101ms；
`instruct_30` 被 7 个 oldevent 脚本调用且无 async 版本。

#### Scenario: 主角走动期间 love.update 不被阻塞

- **GIVEN** 事件脚本调用 `instruct_30` 让主角走 10 格
- **WHEN** 走动进行中
- **THEN** `love.update` 每帧都返回（不被 sleep 占用）

#### Scenario: 走动总时长与原版一致

- **GIVEN** 原版每格 `CC.PersonMoveFrame` = 100ms
- **WHEN** 走 10 格
- **THEN** 总时长约 1000ms（不是 0ms，也不是 160ms）

### Requirement: REQ-BD-3 lib.Delay 不得出现在事件回调路径

事件回调（`EventExecuteCoroutine` 及其调用的 `instruct_*`）SHALL NOT
调用阻塞的 `lib.Delay`。

#### Scenario: 26 处 lib.Delay 全部被处置

- **GIVEN** 全仓 26 处 `lib.Delay` 调用
- **WHEN** 检查每一处
- **THEN** 每处要么已改为 `waitForTime`，要么有注释说明为何保留（如已有 async 版的死代码）

#### Scenario: 门禁拦住新增的阻塞

- **GIVEN** 有人在 `instruct_*` 里新增 `lib.Delay`
- **WHEN** 运行 `gate_engine_contract.sh`
- **THEN** 门禁 FAIL
