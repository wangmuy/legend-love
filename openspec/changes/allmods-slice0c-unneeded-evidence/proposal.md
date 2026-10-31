---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice0c
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-slice0c-unneeded-evidence

## Why

用户明确要求：**"不需要的需要列出来，需要给出证据"**。

前两个子 change 建立了机制（`needed` 字段、`needed=false` 必须有 `evidence`），
但证据的**内容**尚未收集。若证据为空壳（如 `evidence={kind="manual", text="looks unused"}`），
机制就退化为形式主义——正是 `sdx/smp` 漏判的根源（当时也"看过"清单，但没有可复现证据）。

## What Changes

1. **收集可复现证据**：对每个 `needed=false` 的文件/字段，产出至少一条
   **可复现**证据（附命令），种类：
   - `code` — 引擎源码中 0 引用的具体位置
   - `strings` — `kys.exe` strings 中 0 引用
   - `offset_table` — offset 表推导（如 `last offset == grp size` → `tail=0`）
   - `format` — 命名规则证明（如 `%03d` 生成不出 `fight030_02`）
   - `external` — 外部工具依赖（如 `.mid` 需 MIDI→OGG）
   - `manual` — 人工判定（必须附可复现命令）

2. **产出权威文档** `MOD_RESOURCE_AUDIT.md`：一行一判定，
   每行可追溯到 `audit.json` 的记录。

3. **测试断言证据质量**：拒绝空壳证据（`text` 长度下限、`ref` 必须能在源码定位）。

## In Scope

- `game/tools/mod_audit.lua` 的证据收集增强（`collectEvidence()`）
- `MOD_RESOURCE_AUDIT.md`（仓库根目录，权威归类表）
- `tests/unit/test_mod_audit.lua` 的证据质量断言
- 更新 `DATA_FILES.md` §8 交叉引用
- 更新 epic `TODO.md`（Slice 0c 进度）

## Out of Scope

- 修复任何 `needed=false` 的资源（只归类 + 给证据）
- 字段级证据的完整覆盖（本 change 覆盖**文件级**；字段级证据由 format-spec 的 spec 内联）
- 修改 `reference/allmods/**`、引擎层

## Requirements

### [REQ-EVID-1] 每个 `needed=false` 都有可复现证据

- **GIVEN** `audit.json` 中所有 `needed=false` 的记录
- **WHEN** 检查
- **THEN** 每条含 `#evidence >= 1`，且至少一条的 `kind ∈ {code, strings, offset_table, format, external}`

### [REQ-EVID-2] 证据可复现（附命令）

`code`/`strings`/`format` 类证据必须含可执行的复现命令（`cmd` 字段）。

- **GIVEN** 证据 `{kind="code", ref="tools/mod_build.lua:IGNORE_DIRS"}`
- **WHEN** 执行 `grep -n "IGNORE_DIRS" game/tools/mod_build.lua`
- **THEN** 输出包含 `head`、`item`、`eft`（证明这些目录被显式忽略）

### [REQ-EVID-3] 拒绝空壳证据

`evidence.text`（若有）长度 ≥ 10 字符；`evidence.ref`（若有）必须能在
`game/` 或 `reference/allmods/` 中定位到非空匹配。

- **GIVEN** 证据 `{kind="manual", text="unused"}`
- **WHEN** 质量检查
- **THEN** 判定为不合格（长度不足）

### [REQ-EVID-4] 权威文档可追溯

`MOD_RESOURCE_AUDIT.md` 的每一行判定含 `类别 | 文件/模式 | MOD 数 | 是否进产物 | 证据`，
且证据与 `audit.json` 一致。

- **GIVEN** `MOD_RESOURCE_AUDIT.md` 已生成
- **WHEN** 抽取某行证据
- **THEN** 在 `audit.json` 中找到对应记录的相同证据

### [REQ-EVID-5] 未进产物的 1971 个文件全部有理由

- **GIVEN** 1971 个 `in_product=false` 的文件
- **WHEN** 检查
- **THEN** 每个都有 `reason`（归入某 `needed=false` 类别）与非空 `evidence`

### [REQ-EVID-6] 零回归

- **GIVEN** 本 change 只增强证据与文档
- **WHEN** 运行全量测试与构建基线
- **THEN** 全绿 / PASS / 0 failures

## Impact

- **新增**：`MOD_RESOURCE_AUDIT.md`
- **修改**：`game/tools/mod_audit.lua`（证据收集）、`game/tests/unit/test_mod_audit.lua`（质量断言）、`DATA_FILES.md`（交叉引用）、`openspec/epics/2026-10-allmods-compat/TODO.md`
- **未触碰**：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`、`game/mods/**`（只读）

## DoD

1. `audit.json` 中所有 `needed=false` 记录有 ≥1 条非空壳证据
2. `MOD_RESOURCE_AUDIT.md` 生成，行数与类别数一致，证据可追溯
3. 1971 个未进产物文件全部有理由
4. `test_mod_audit.lua` 全绿（含证据质量断言）
5. `lua tests/test_runner.lua` 全绿（无回归）
