# 战斗健壮性

## ADDED Requirements

### Requirement: REQ-BRB-1 WarLoad 返回明确成功/失败

`WarLoad(warid)` SHALL 返回 `true`（加载成功）或 `false`（失败），
SHALL NOT 只返回 `nil`。

失败条件包括：
- `warid` 越界（`< 0` 或 `>= war.sta` 记录数）
- 数据文件读取失败

失败时 SHALL 通过 `JY_Error` 记录日志（保留既有行为），
但**返回值必须是布尔**，让调用方能分支。

#### Scenario: 越界 warid 返回 false

- **GIVEN** `war.sta` 有 N 条记录
- **WHEN** 调用 `WarLoad(N)` 或 `WarLoad(-1)`
- **THEN** 返回 `false`，且 `error.txt` 有越界日志

#### Scenario: 正常 warid 返回 true

- **WHEN** 调用 `WarLoad(0)`
- **THEN** 返回 `true`，且 `WAR.Data["地图"]` / `WAR.Data["音乐"]` 有值

### Requirement: REQ-BRB-2 WarMainCoroutine 检查 WarLoad 结果

`WarAsync.WarMainCoroutine` SHALL 在 `WarLoad` 返回 false 时：
- 不继续执行 `WarSelectTeam` / `WarSelectEnemy`
- 置 `warState.status = "ended"` 且 `warState.result = nil`
- 返回 `false`

依据（实测）：`JY_Error` 只是 `Log()`（`framework/lib_log.lua:54`），
不抛错、不终止。此前 `WarMainCoroutine` 不检查返回值，加载失败时会用
**上一场战斗的数据**继续跑 → `warState.result` 保持上个值 → 调用方读到错误胜负。

#### Scenario: 加载失败时不进入战斗循环

- **GIVEN** `WarLoad` 会返回 false 的 warid
- **WHEN** 调用 `WarMainCoroutine(warid, 1)`
- **THEN** 返回 `false`，`warState.result` 是 `nil`（不是上场的 true/false）

#### Scenario: 加载失败时 WAR.Data 不被"假用"

- **GIVEN** 上一场战斗的 `WAR.Data` 还在
- **WHEN** `WarLoad` 失败
- **THEN** `WarMainCoroutine` 立即返回，不读 `WAR.Data["地图"]` 等字段

### Requirement: REQ-BRB-3 WAR.Person 容量 >= 40 且有越界守卫

`WAR.Person` SHALL 至少提供 40 个槽位（索引 0..39）。
`WarSelectTeam` 与 `WarSelectEnemy` SHALL 在 `WAR.PersonNum` 达到上限时
**停止添加**并 `JY_Error` 记录，SHALL NOT 写入 `WAR.Person[上限]`（nil 索引）。

依据（实测容量核算）：
- `WarSelectTeam` 最多 6（`CC.TeamNum = 6`）
- `WarSelectEnemy` 最多 20（`for i=1,20`）
- 原槽数 26 = **零余量**
- MOD 改 `CC.TeamNum > 6` 或敌方 > 20 → `WAR.Person[26]` 是 nil → 崩

#### Scenario: 40 个槽位都存在

- **GIVEN** `WarSetGlobal()` 调用后
- **WHEN** 检查 `WAR.Person[0]` 到 `WAR.Person[39]`
- **THEN** 每个都是 table（不是 nil）

#### Scenario: 超过上限时被守卫拦住而非崩溃

- **GIVEN** `WAR.PersonNum` 已达 40
- **WHEN** `WarSelectEnemy` 尝试添加第 41 个
- **THEN** 不写 `WAR.Person[40]`，不抛错，`error.txt` 有记录

#### Scenario: 正常战斗仍能添加 26 个

- **GIVEN** 6 名我方 + 20 名敌方
- **WHEN** `WarSelectTeam` + `WarSelectEnemy` 完成
- **THEN** `WAR.PersonNum == 26`（容量扩大不改变正常流程）
