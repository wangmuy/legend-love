# Spec: allmods-unneeded-evidence

> Change: `allmods-slice0c-unneeded-evidence` · Slice: `allmods-slice0c`
> 需求前缀：`REQ-EVID-*`（与 `proposal.md` 一一对应）

## 概述

对每个"不需要"的文件/字段给出**可机器校验的证据**，并产出可追溯的权威文档。

---

## [REQ-EVID-1] 每个 `needed=false` 都有可复现证据

#### Scenario: 所有不需要的记录都有证据
- **GIVEN** `auditAll()` 返回的记录中所有 `needed == false` 的项
- **WHEN** 检查
- **THEN** 每项 `#evidence >= 1`，且至少一条 `kind ∈ {code, strings, offset_table, format, external}`

#### Scenario: PENDING 不被当作 needed=false
- **GIVEN** `music/*.mid` 的记录
- **WHEN** 检查
- **THEN** `category == "PENDING"` 且 `needed == nil`（既非 true 也非 false）

---

## [REQ-EVID-2] 证据可复现（附命令）

#### Scenario: IGNORE_DIRS 证据可复现
- **GIVEN** 证据 `{kind="code", ref="game/tools/mod_build.lua:IGNORE_DIRS",
  cmd="grep -n IGNORE_DIRS game/tools/mod_build.lua", expect="head"}`
- **WHEN** 执行 `cmd`
- **THEN** 输出包含 `head`、`item`、`eft`

#### Scenario: 命名规则证据可复现
- **GIVEN** 证据 `{kind="format", cmd="lua -e 'print(string.format(\"fight%03d.grp\",30))'",
  expect="fight030.grp"}`
- **WHEN** 执行
- **THEN** 输出 `fight030.grp` ≠ `fight030_02.grp`（证明死文件名不可生成）

#### Scenario: 格式不兼容证据可复现
- **GIVEN** `music/*.mid` 的证据 `{kind="external", cmd="head -c 4 <midfile>"}`
- **WHEN** 执行
- **THEN** 输出 `MThd`（MIDI 魔数）≠ `OggS`/`RIFF`（引擎期望）

---

## [REQ-EVID-3] 拒绝空壳证据

#### Scenario: 过短文本被拒
- **GIVEN** 证据 `{kind="manual", text="unused"}`
- **WHEN** `checkEvidenceQuality(ev)`
- **THEN** 返回 `false`（`text` 长度 < 10）

#### Scenario: 缺失 cmd 的 code 证据被拒
- **GIVEN** 证据 `{kind="code", ref="game/x.lua:foo"}`
- **WHEN** 检查
- **THEN** 返回 `false`（`kind="code"` 必须有 `cmd`）

#### Scenario: 合法证据通过
- **GIVEN** 证据 `{kind="code", ref="game/tools/mod_build.lua:IGNORE_DIRS",
  cmd="grep -n IGNORE_DIRS game/tools/mod_build.lua", text="构建器忽略这些目录"}`
- **WHEN** 检查
- **THEN** 返回 `true`

---

## [REQ-EVID-4] 权威文档可追溯

#### Scenario: 文档含锚点
- **GIVEN** `MOD_RESOURCE_AUDIT.md` 已生成
- **WHEN** 检查
- **THEN** 每行判定含 `<!-- rec:<mod>:<path> -->` 锚点

#### Scenario: 锚点可追溯
- **GIVEN** 文档中任意锚点 `rec:mingdong:head/hdgrp001.png`
- **WHEN** 在 `audit.json` 查找
- **THEN** 找到对应记录，且证据字段与文档一致

#### Scenario: 文档数字与 JSON 一致
- **GIVEN** 文档汇总表与 JSON
- **WHEN** 比对每类文件数
- **THEN** 完全一致

---

## [REQ-EVID-5] 未进产物的文件全部有理由

#### Scenario: 1971 个未进产物文件全部有理由
- **GIVEN** 所有 `in_product == false` 的记录
- **WHEN** 检查
- **THEN** 每条 `category ∈ {DESIGNED_FALLBACK, DEAD_PARAM, LEGACY, DEAD_FILE,
  EDITOR_DUMP, PLATFORM_ARTIFACT, PENDING}` 且有非空 `evidence`

#### Scenario: 未进产物数可复现
- **GIVEN** 审计完成
- **WHEN** 统计
- **THEN** `#(in_product=false) == 1971`

---

## [REQ-EVID-6] 零回归

#### Scenario: 全量测试仍全绿
- **GIVEN** 本 change 已实施
- **WHEN** 运行 `cd game && lua tests/test_runner.lua`
- **THEN** 全部通过

#### Scenario: 构建与基线不受影响
- **GIVEN** 本 change 已实施
- **WHEN** 运行 `lua tools/mod_build.lua --all` 与 `--verify-pascal`
- **THEN** `0 build failures`，pascal baseline `PASS`
