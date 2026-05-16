## ADDED Requirements

### Requirement: yieldable 函数适配

事件驱动适配层 SHALL 基于 EngineAPI 的 yieldable 函数契约，在协程上下文中自动将阻塞调用转为 coroutine.yield。

#### Scenario: waitForKey 在协程中 yield
- **WHEN** 在协程中调用 `EngineAPI.input.waitForKey()`
- **THEN** 当前协程 SHALL yield，等待 `CoroutineScheduler` 恢复

#### Scenario: sleep 在协程中 yield
- **WHEN** 在协程中调用 `EngineAPI.time.sleep(100)`
- **THEN** 当前协程 SHALL yield，等待指定时间后恢复

#### Scenario: 非协程中直接阻塞
- **WHEN** 不在协程中调用 `EngineAPI.input.waitForKey()`
- **THEN** SHALL 使用轮询方式阻塞等待（回退行为）

### Requirement: 全局函数替换

事件驱动适配层 SHALL 提供 `install()` 和 `uninstall()` 函数，在事件脚本执行前后替换/恢复全局阻塞函数。

#### Scenario: install 替换全局函数
- **WHEN** 调用 `install()`
- **THEN** 全局 `WaitKey`、`ShowMenu`、`DrawStrBoxWaitKey`、`DrawStrBoxYesNo`、`TalkEx`、`ShowScreen` SHALL 被替换为异步版本

#### Scenario: uninstall 恢复全局函数
- **WHEN** 调用 `install()` 后调用 `uninstall()`
- **THEN** 所有被替换的全局函数 SHALL 恢复为原始版本

#### Scenario: lib.Delay 被替换
- **WHEN** 调用 `install()`
- **THEN** `lib.Delay` SHALL 被替换为基于 `EngineAPI.time.sleep` 的异步版本

### Requirement: 协程上下文检测

适配层 SHALL 自动检测当前是否在协程中，在协程中使用 yieldable 版本，否则使用阻塞版本。

#### Scenario: 协程中使用 yieldable
- **WHEN** 在协程中调用被替换的 `WaitKey`
- **THEN** 内部 SHALL 调用 `EngineAPI.input.waitForKey()`（yieldable 版本）

#### Scenario: 非协程中使用阻塞版本
- **WHEN** 不在协程中调用被替换的 `WaitKey`
- **THEN** 内部 SHALL 使用轮询方式阻塞等待

### Requirement: 向后兼容

事件驱动适配层 SHALL 保持与现有 `async_globals.lua` 相同的行为，现有事件脚本无需修改。

#### Scenario: oldevent 脚本正常执行
- **WHEN** 通过 `event_executor.lua` 执行 oldevent 脚本
- **THEN** 脚本中的 `instruct_1`、`WaitKey`、`ShowMenu` 等调用 SHALL 正常工作

#### Scenario: newevent 脚本正常执行
- **WHEN** 通过 `JY.SceneNewEventFunction` 执行 newevent 脚本
- **THEN** 脚本中的 `Cls`、`DrawStrBox`、`lib.Delay` 等调用 SHALL 正常工作