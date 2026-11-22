# engine-conformance Delta

## ADDED Requirements

### Requirement: REQ-CONF-001：引擎完整性必须用源码级判据

系统的「4 引擎是否实现全部契约」检查 SHALL NOT 依赖 `require` 后的表查询，
因为 4 个引擎里 3 个与 `engine_api.lua` **共享同一张表**，而 `engine_api`
已为每个契约声明空桩 → 表查询永真。

#### Scenario: MUD 缺一个契约

- **GIVEN** `engine_mud.lua` 里删掉了 `EngineAPI.file.read = function`
- **WHEN** 运行 `test_engine_conformance`
- **THEN** 断言 SHALL FAIL，并指出 `MUD 缺 1 个契约实现: file.read`

#### Scenario: 4 引擎全部齐全

- **GIVEN** 4 个引擎源码都显式实现了 95 个契约
- **WHEN** 运行完整性检查
- **THEN** 4 条断言 SHALL 全部 PASS
- **AND** 检查范围 SHALL 包含 LÖVE（不能只查 MUD/Web/Test）

### Requirement: REQ-CONF-002：契约语义必须在所有引擎一致

契约的**语义**（不只是存在性）SHALL 在 4 个引擎一致，且 SHALL 用
源码级判据校验（理由同 REQ-CONF-001）。

#### Scenario: playSequence 只收 number

- **GIVEN** 契约注释声明 `playSequence(id)` **只收 number**
- **WHEN** 检查 4 引擎源码
- **THEN** 每个引擎的 `playSequence` SHALL 含 `type(id) ~= "number"` 守卫
- **AND** SHALL 含 `id < 0` 拒绝
- **AND** SHALL NOT 含 `filenameOrId`（旧语义的形参名）

#### Scenario: 无音频能力的引擎必须返回 false

- **GIVEN** MUD / Web 明确无音频能力
- **WHEN** 调用 `playSequence(16)`
- **THEN** SHALL 返回 false（而不是 true）
- **AND** 理由：`false` 让调用方能区分「无能力」与「参数错」，
  `true` 会让宿主以为播放成功、无从判断是否该降级

### Requirement: REQ-CONF-003：注入点返回 nil 时调用方必须安全

`framework/game_hooks.lua` 的 `getMyPic()` SHALL 在未注册时返回 nil
（这是合法语义，用于检测「无注入实现」）。所有把它赋给 `JY.MyPic`
或传给 `map_render` 的调用点 SHALL 使用 `getMyPicOr(fallback)`。

#### Scenario: hook 未注册时走走路自动移动

- **GIVEN** 没有任何 GameHooks 注册
- **WHEN** 调用 `GameStates._stepAutoMoveSMAP()`
- **THEN** SHALL NOT 抛错
- **AND** `JY.MyPic` SHALL 保持原值（不是 nil）
- **AND** 后续 `JY.MyPic * 2` SHALL 正常计算

#### Scenario: nil 比较防护

- **GIVEN** `JY.CurrentD` 为 nil（测试环境 / 早期初始化）
- **WHEN** 执行 `JY.CurrentD >= 0` 形态的判断
- **THEN** SHALL NOT 抛 "attempt to compare number with nil"
- **AND** 每个此类比较 SHALL 前置 `JY.CurrentD ~= nil`（或 `JY.CurrentD and`）

### Requirement: REQ-CONF-004：framework 主路径不得依赖被沙箱禁用的 stdlib

framework 的运行时路径 SHALL 在 EngineAPI 能力可用时不走 `io.*` 主路径。
「兜底」分支（纯 Lua 测试环境用）SHALL 保留。

#### Scenario: MOD 激活判定（APK 内资源）

- **GIVEN** 宿主是 Android APK / .love 打包，`io.open` 看不到包内资源
- **WHEN** `ModData.readActiveFile()` 被调用
- **THEN** SHALL 走 `EngineAPI.file.read`
- **AND** SHALL NOT 因 `io.open` 失败而让 MOD 永久不激活

#### Scenario: 契约可用时零 stdlib 调用

- **GIVEN** 一个可用的 `EngineAPI.file`
- **WHEN** 调用 `ModData.readActiveFile()` 或 `ModData.WarRecordCount()`
- **THEN** `io.open` 的调用计数 SHALL 为 0

#### Scenario: 无契约时兜底仍工作

- **GIVEN** 纯 Lua 测试环境（`EngineAPI` 为 nil）
- **WHEN** 调用上述两个函数
- **THEN** SHALL 回退到 `io.open`（计数为 1）
- **AND** SHALL NOT 抛错
