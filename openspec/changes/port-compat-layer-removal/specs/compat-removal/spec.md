# script 与入口程序不再依赖 `_G.lib`

## ADDED Requirements

### Requirement: REQ-CLR-1 `_G.lib` 全局 SHALL 被删除

`game/engine-love2d/engine_love2d.lua` 的
`_G.lib = setmetatable(EngineAPI, { __index = lib })` SHALL 被删除。
`game/engine-mud/engine_mud.lua` 与 `game/engine-web/engine_web.lua` 的
同名赋值 SHALL 一并删除（引擎内部若需要，改 `local lib`）。

依据（实测 2026-11-21）：27808 个事件脚本（1018 基础 + 26790 MOD）
**零** `lib.*` 引用，调用面恰好是 `instruct_0..67`。

#### Scenario: 全仓只剩引擎内部

- **WHEN** 执行 `grep -rn 'rawget(_G, *"lib")' game/framework game/script game/main.lua`
- **THEN** 命中数 = 0

#### Scenario: `_G.lib` 赋值只剩允许位置

- **WHEN** 执行 `grep -rn '_G.lib =' game/`
- **THEN** 命中数 = 0（tests/ 除外）

### Requirement: REQ-CLR-2 `lib_love.lua` SHALL NOT 自引用 `lib.`

`lib_love.lua` 用 `_ENV = M`（`__index = _G`），其 8 处 `lib.Debug(...)`
经 `M` 落到 `_G.lib` —— 与 `_G.lib.__index = lib_love` 形成**循环依赖**。
这些引用 SHALL 改为本地 `Debug(...)`。

#### Scenario: 自引用清零

- **WHEN** 执行 `grep -nE '\blib\.' game/engine-love2d/lib_love.lua`（排除注释行）
- **THEN** 命中数 = 0

#### Scenario: 门禁断言

- **WHEN** 运行 `gate_engine_contract.sh` 新增 STEP I
- **THEN** 若 `lib_love.lua` 出现 `lib.` 则 FAIL

### Requirement: REQ-CLR-3 `render.setDrawLoopFlag` SHALL 成为契约

新增 `EngineAPI.render.setDrawLoopFlag(flag)`，4 引擎实现。
`main.lua` SHALL 改调它，不再调全局 `lib.SetDrawLoopFlag`。

#### Scenario: 4 引擎都有实现

- **WHEN** 检查 `engine_api.lua` 声明与 4 个实现文件
- **THEN** 每个都有 `render.setDrawLoopFlag`

#### Scenario: present 门控语义不变

- **GIVEN** `love.draw()` 内调用 `EngineAPI.render.present()`
- **WHEN** `setDrawLoopFlag(true)` 已置位
- **THEN** 实际执行 `love.graphics.present()`

### Requirement: REQ-CLR-4 `async_globals` 的 Delay 补丁点 SHALL 改到契约

`framework/async_globals.lua` 的
`_libDelay = lib and lib.Delay` / `lib.Delay = AsyncGlobals.lib_Delay_Async`
SHALL 改为对 `EngineAPI.time.sleep` 的保存/覆盖/还原。

依据（活体缺陷）：`_G.lib` 与 `EngineAPI` 是同一张表，
`lib.Delay = ...` 实际往 `EngineAPI` 写了一个**契约外的键** `Delay`；
而 `jymain.lua:51` 的 fallback `lib.Delay(m)` 因此拿到协程版，
协程版内部又回落到 `EngineAPI.time.sleep` → 阻塞 `love.timer.sleep`。
两个补丁互相抵消，`port-blocking-delay` 在 fallback 路径上被静默撤销。

#### Scenario: fallback 仍是阻塞退路

- **GIVEN** 非协程上下文调用 `WaitFrame(20)`
- **WHEN** 记录实际被调函数
- **THEN** 落到 `EngineAPI.time.sleep`（未补丁版）

#### Scenario: 协程内 WaitFrame 不阻塞

- **GIVEN** 协程内调用 `WaitFrame(20)`
- **WHEN** 统计 `love.timer.sleep` 调用次数
- **THEN** 0 次（走 `scheduler:waitFrame`）

### Requirement: REQ-CLR-5 死变量 SHALL 被删除

`framework/interact.lua:185` 与 `framework/settings_store.lua:45` 的
`local lib = rawget(_G, "lib")` 声明后从未使用，SHALL 删除。

#### Scenario: 静态检查

- **WHEN** 执行 `grep -n 'rawget(_G, "lib")' game/framework/*.lua`
- **THEN** 命中数 = 0

## Out of Scope

- `lib_love.lua` 本体与 `LoadPic`/`PicLoadFile`/`PicLoadCache` 的删除
  → `port-legacy-picture-removal`
- 测试桩（`tests/engine_test.lua`、`tests/test_helper.lua`）里为模拟
  而建的 `_G.lib` —— 允许保留，但 SHALL NOT 被被测代码路径依赖
