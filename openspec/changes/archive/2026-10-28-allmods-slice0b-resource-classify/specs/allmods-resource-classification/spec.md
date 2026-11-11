## ADDED Requirements

### Requirement: thing 资源设计性回退 [REQ-CLASSIFY-1]

系统 SHALL 将 `thing.idx`/`thing.grp` 在源 MOD 中缺失判定为**设计性回退**（非缺陷）：引擎从 `mods/<mod>/data/thing.*` 读不到时回退 `data/thing.*`（原版）是预期行为。

测试 SHALL 断言：20 个源 MOD 均不提供 `thing.idx`/`thing.grp`。

#### Scenario: 源 MOD 不提供 thing

- **WHEN** 扫描 `reference/allmods/kys-*/resource/` 与 `reference/allmods/kys-*/save/`
- **THEN** 0 个 MOD 提供 `thing.idx` 或 `thing.grp`

#### Scenario: 引擎回退原版

- **WHEN** 激活某 MOD 并加载 `CC.ThingPicFile`
- **THEN** 路径以 `data/thing.idx`/`data/thing.grp` 结尾（回退原版，非 MOD 路径）

---

### Requirement: allsinbk 为死参数 [REQ-CLASSIFY-2]

系统 SHALL 将 `allsinbk.grp` 判定为**死参数**：它是 `lib.LoadSMap` 的 `tmpfilename` 形参，但在函数体内从未被引用。

测试 SHALL 断言 `game/` 的 Lua 源码中，`allsinbk`/`TempS_Filename` 除常量定义与参数传递外无其他引用。

#### Scenario: 源 MOD 不提供 allsinbk

- **WHEN** 扫描 `reference/allmods/kys-*/resource/` 与 `reference/allmods/kys-*/save/`
- **THEN** 0 个 MOD 提供 `allsinbk.grp`

#### Scenario: 引擎不读取 allsinbk

- **WHEN** 检查 `game/engine-love2d/lib_love.lua` 的 `LoadSMap` 函数体
- **THEN** 形参 `tmpfilename` 在函数体内 0 次被引用

#### Scenario: 常量仅定义与传递

- **WHEN** 扫描 `game/` 下 Lua 源码中的 `allsinbk`/`TempS_Filename`
- **THEN** 命中仅出现在 `jyconst.lua` 的常量定义行与 `jymain.lua` 的 `LoadSMap` 调用实参位置

---

### Requirement: 编辑器副产物不被复制 [REQ-CLASSIFY-3]

系统 SHALL 将 `head/`、`item/`、`eft/`、`cc/` 判定为**编辑器副产物**，不复制进 MOD 产物。

测试 SHALL 断言 `IGNORE_DIRS` 含 `head`/`item`/`eft`，且构建产物中无这些目录。

#### Scenario: IGNORE_DIRS 覆盖编辑器目录

- **WHEN** 检查 `game/tools/mod_build.lua` 的 `IGNORE_DIRS`
- **THEN** 含 `head`、`item`、`eft`

#### Scenario: 产物无编辑器目录

- **WHEN** 检查 `game/mods/<任意已构建 MOD>/`
- **THEN** 不含 `head/`、`item/`、`eft/` 目录

---

### Requirement: 死文件不可达 [REQ-CLASSIFY-4]

系统 SHALL 将以下判定为**死文件**（引擎无法通过其命名规则访问）：
- `fightNNN..grp`/`fightNNN..idx`（双点）
- `fightNNN_02.grp`/`fightNNN_02.idx`（`_02` 后缀）
- `new.idx`（无 `new.grp` 的损坏备份）
- `fight23.idx`（非 3 位编号）
- `war1.sta`（引擎只读 `war.sta`）

测试 SHALL 断言引擎的 `%03d` 命名规则无法生成这些名字。

#### Scenario: fight 命名规则无法生成双点或后缀

- **WHEN** 用 `string.format("fight%03d.grp", n)` 生成任意 `n`
- **THEN** 结果永不含 `..` 或 `_02`

#### Scenario: war1.sta 不在引擎引用中

- **WHEN** 扫描 `game/` 下 Lua 源码对 `war` 相关的文件常量
- **THEN** 只引用 `war.sta`，无 `war1.sta`

#### Scenario: 死文件策略为保留拷贝

- **WHEN** 检查构建产物（如 `game/mods/awaken/data/fight000..grp`）
- **THEN** 死文件被忠实复制（不主动过滤）——判定其不可达，但不改变构建行为

---

### Requirement: name.grp 遗留与 music 待决策 [REQ-CLASSIFY-5]

系统 SHALL 文档化 `name.idx`/`name.grp` 为 **C 引擎/编辑器遗留**（Lua 引擎不读取，人名来自 `ranger.grp`），并将 `music/*.mid` 记录为**待决策**（PENDING）。

#### Scenario: name.grp 使用 MOD 列表正确

- **WHEN** 扫描 `reference/allmods/kys-*/resource/name.grp`
- **THEN** 恰好 4 个 MOD 提供（BookCalamity、Dragon、pineapple、RiverLake），`books` 不在其中

#### Scenario: 引擎不读取 name.grp

- **WHEN** 扫描 `game/` 下 Lua 源码中的 `name.grp`/`name.idx`
- **THEN** 无任何读取引用

#### Scenario: music 待决策记录在案

- **WHEN** 检查 `openspec/epics/2026-10-allmods-compat/TODO.md`
- **THEN** 含 `music/*.mid` 的待决策条目，说明格式/槽位/编号体系三重不匹配

---

### Requirement: 分类零回归 [REQ-CLASSIFY-6]

本 change MUST NOT 改变任何运行时或构建时行为。

#### Scenario: 测试全绿

- **WHEN** 未激活 MOD 且运行 `cd game && lua tests/test_runner.lua`
- **THEN** 全部测试通过（含新增的分类断言）

#### Scenario: 无行为代码变更

- **WHEN** 检查本 change 的 `git diff`
- **THEN** `game/engine-love2d/**`、`game/framework/**`、`game/script/**`、`game/tools/mod_build.lua` 无变更

#### Scenario: pascal 基线仍通过

- **WHEN** 运行 `cd game && lua tools/mod_build.lua --verify-pascal`
- **THEN** 输出 PASS
