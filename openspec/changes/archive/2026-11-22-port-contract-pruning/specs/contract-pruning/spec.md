# 契约裁剪

## REMOVED Requirements

### Requirement: REQ-CP-1 删除 sprite.getSize / coroutine.yieldPoint / coroutine.waitFor

`engine_api.lua` SHALL NOT 声明以下 3 个契约，4 个引擎实现
（LÖVE / MUD / Web / 测试桩）SHALL NOT 实现它们：

- `sprite.getSize(archiveId, spriteId)` —— 与 `sprite.getMeta(handle)` 重复
- `coroutine.yieldPoint()` —— framework 的 `coroutine_scheduler` 已覆盖
- `coroutine.waitFor(condition, timeout)` —— 同上

依据（实测）：3 者在 `framework/` + `script/` 的调用点都是 **0**，
且 4 个引擎实现里都只有定义行、无内部引用。

#### Scenario: 契约文件里没有这 3 个声明

- **WHEN** 执行 `grep -c 'sprite.getSize\|coroutine.yieldPoint\|coroutine.waitFor' game/engine-love2d/engine_api.lua`
- **THEN** 命中数 = 0

#### Scenario: 4 个引擎都没有这 3 个实现

- **WHEN** 对 `engine_love2d.lua` / `engine_mud.lua` / `engine_web.lua` / `engine_test.lua` 执行同样的 grep
- **THEN** 每个文件的命中数 = 0

#### Scenario: 契约总数从 79 降到 76

- **WHEN** 统计 `engine_api.lua` 里的 `function M.*` 声明
- **THEN** 总数 = 76

### Requirement: REQ-CP-2 行为零变化

删除这 3 个契约 SHALL NOT 改变任何运行时行为。

依据：它们本来就没有消费者，删掉等于移除死代码。

#### Scenario: 全量测试零回归

- **WHEN** 四版本 Lua 全量测试
- **THEN** 除删掉的 3 条 `assertNotNil` 外，其余断言全部通过

#### Scenario: 实机画面零变化

- **WHEN** 实机截图（战斗 / 主地图 / 场景）
- **THEN** 与删除前逐字节相同
