## ADDED Requirements

### Requirement: 构建期资源别名映射 [REQ-ALIAS-1]

`tools/mod_build.lua` SHALL 在把 MOD 的 `resource/` 文件拍平到 `mods/<mod>/data/` 时，按权威别名表转换文件名：

| 源名（C 引擎） | 目标名（Lua 引擎） | 含义 |
|---|---|---|
| `sdx` | `smap.idx` | 场景地图贴图索引 |
| `smp` | `smap.grp` | 场景地图贴图数据 |
| `wdx` | `wmap.idx` | 战斗地图贴图索引 |
| `wmp` | `wmap.grp` | 战斗地图贴图数据 |

别名表 MUST 在构建器内以具名常量声明，并附权威来源注释（`reference/allmods/UPedit/UPedit.ini` 的 `[File]` 段 `File2`/`File3`/`SMAPIDX`/`SMAPGRP`）。

文件名转换 MUST NOT 改变文件内容（逐字节保留）。

#### Scenario: 单 MOD 别名转换

- **WHEN** 对 `reference/allmods/kys-mingdong/`（含 `resource/sdx`、`resource/smp`、`resource/wdx`、`resource/wmp`）运行 `lua tools/mod_build.lua kys-mingdong`
- **THEN** `game/mods/mingdong/data/` 含 `smap.idx`、`smap.grp`、`wmap.idx`、`wmap.grp`，且不含 `sdx`、`smp`、`wdx`、`wmp`
- **AND** `smap.idx` 的内容与源 `sdx` 逐字节相同，`smap.grp` 与源 `smp` 逐字节相同

#### Scenario: 全量 MOD 别名转换

- **WHEN** 运行 `lua tools/mod_build.lua --all`
- **THEN** 20 个 MOD 的产物目录均含 `smap.idx`/`smap.grp`/`wmap.idx`/`wmap.grp`
- **AND** 全部产物中 `sdx`/`smp`/`wdx`/`wmp` 的数量为 0
- **AND** 构建失败数为 0

#### Scenario: 别名表来源可审计

- **WHEN** 检查 `tools/mod_build.lua` 中的别名常量
- **THEN** 该常量带有指向 `UPedit.ini` 的注释，说明每个映射的权威依据

---

### Requirement: 别名仅作用于 resource 来源 [REQ-ALIAS-2]

别名转换 SHALL 仅对来自 `resource/` 的文件（`kind == "data"`）生效。来自 `fight/`、`save/` 的文件 MUST NOT 参与别名转换。

#### Scenario: fight 目录不参与别名

- **WHEN** 某 MOD 的 `fight/` 目录含名为 `sdx` 的文件（假设）
- **THEN** 该文件按原名（小写归一后）复制到 `mods/<mod>/data/`，不被改名为 `smap.idx`

#### Scenario: save 目录不参与别名

- **WHEN** 构建某 MOD 且 `save/` 含基础模板文件
- **THEN** 这些文件按原有 `SAVE_TEMPLATE` 逻辑路由，别名表不介入

---

### Requirement: 别名冲突显式失败 [REQ-ALIAS-3]

若别名映射的目标名在本次构建中已存在（例如某 MOD 同时提供 `sdx` 与 `smap.idx`），构建器 SHALL 以非 0 退出码失败，并在 stderr 说明冲突，MUST NOT 静默覆盖。

#### Scenario: 冲突触发硬失败

- **WHEN** 对同时含 `resource/sdx` 与 `resource/smap.idx` 的 MOD 运行构建
- **THEN** 构建以非 0 退出码结束
- **AND** stderr 含冲突文件名（`sdx` → `smap.idx`）
- **AND** 不产出半成品

#### Scenario: 已验证无实际冲突

- **WHEN** 扫描 `reference/allmods/` 下全部 20 个 MOD 的 `resource/`
- **THEN** 不存在任何 MOD 同时提供 `sdx` 与 `smap.idx`（或 `smp`/`smap.grp`、`wdx`/`wmap.idx`、`wmp`/`wmap.grp`）

---

### Requirement: diff 报告识别改名对 [REQ-ALIAS-4]

`mods/<mod>/diff.md` SHALL 含「资源别名转换」小节，列出已应用的别名映射。别名转换的目标名（`smap.idx`/`smap.grp`/`wmap.idx`/`wmap.grp`）MUST NOT 出现在「基准独有」列表（因为它们已由别名提供，不是缺失）。

#### Scenario: diff 含别名小节

- **WHEN** 生成 `mods/mingdong/diff.md`
- **THEN** 报告含标题「资源别名转换」的小节
- **AND** 小节内列出 `sdx → smap.idx`、`smp → smap.grp`、`wdx → wmap.idx`、`wmp → wmap.grp`

#### Scenario: 不再误报缺失

- **WHEN** 检查 `mods/mingdong/diff.md` 的「基准独有」列表
- **THEN** 该列表不含 `smap.idx`、`smap.grp`、`wmap.idx`、`wmap.grp`
- **AND** 「MOD 独有」列表不含 `sdx`、`smp`、`wdx`、`wmp`

---

### Requirement: 运行时地图数据来自 MOD [REQ-ALIAS-5]

别名转换完成后，激活 MOD 时引擎 SHALL 从 MOD 目录读取场景地图与战斗地图贴图，而非回退原版。

#### Scenario: SMAPPicFile 指向 MOD

- **WHEN** 激活 mingdong（`game/active_mod.txt` 内容为 `mingdong`）并加载 `CC` 常量
- **THEN** `CC.SMAPPicFile[1]` 以 `mods/mingdong/data/smap.idx` 结尾
- **AND** `CC.SMAPPicFile[2]` 以 `mods/mingdong/data/smap.grp` 结尾
- **AND** `CC.SMAPPicFile` 指向的索引条目数 = 4635（MOD 实际值，非原版 4129）

#### Scenario: WMAPPicFile 指向 MOD

- **WHEN** 激活 mingdong 并加载 `CC` 常量
- **THEN** `CC.WMAPPicFile[1]` 以 `mods/mingdong/data/wmap.idx` 结尾
- **AND** `CC.WMAPPicFile` 指向的索引条目数 = 3850（MOD 实际值，非原版 3701）

---

### Requirement: 原版零回归 [REQ-ALIAS-6]

未激活任何 MOD 时（`game/active_mod.txt` 不存在或为空），全部行为 SHALL 与别名转换引入前完全一致。

#### Scenario: 测试全绿

- **WHEN** 未激活 MOD 且运行 `cd game && lua tests/test_runner.lua`
- **THEN** 全部测试通过

#### Scenario: pascal 基线仍通过

- **WHEN** 运行 `cd game && lua tools/mod_build.lua --verify-pascal`
- **THEN** 输出 PASS（events 数一致，mismatches 为 0，仅已知偏差）

#### Scenario: 未激活时路径不变

- **WHEN** 未激活 MOD 且加载 `CC` 常量
- **THEN** `CC.SMAPPicFile[1]` 以 `data/smap.idx` 结尾（原版路径，与现状一致）
