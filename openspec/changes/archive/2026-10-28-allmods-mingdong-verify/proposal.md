---
status: done
created: 2026-10-16
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

mingdong 数据形态与原版并非完全一致（fight 267 vs 92、war.sta 309 记录、缺 `smap/wmap/thing`）。需要逐条核对引擎加载点能否容忍这些差异，并核对提取产物（事件/对话）内容确实来自 mingdong 数据，产出可审计的验证报告。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md` — Slice 1
- Slice: `openspec/changes/allmods-slice1/slice-proposal.md`
- 依赖: `allmods-mingdong-activate`（无头 E2E 验证脚本）

## What Changes

1. 审计 `game/mods/mingdong/diff.md` 的每一条差异，核对引擎加载点容忍度。
2. 核对提取产物：
   - 事件脚本数 = kdef 条目数（1654）
   - 抽样 3 个事件脚本，对话内容与 `kys-mingdong/resource/talk.grp` 解码结果一致
   - 对话表条数 = talk 条目数（5183）
3. 产出验证报告 `reports/mingdong-verify.md`。
4. 确认原版零回归。

## Scope Boundaries

### In Scope
- 差异审计、提取产物内容核对、验证报告

### Out of Scope
- 修复 mingdong 数据内容（只记录，不改）
- 其余 18 个 MOD

## Capabilities

### New Capabilities
- `allmods-mingdong-verify`: 名动天下数据可用性验证（[REQ-MDV-1]~[REQ-MDV-3]）

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-MDV-1] | `diff.md` 每条差异有引擎容忍度结论 |
| [REQ-MDV-2] | 事件/对话产物数量与 MOD 数据一致，抽样内容一致 |
| [REQ-MDV-3] | 验证报告落盘 `reports/mingdong-verify.md` |

## DoD

1. `reports/mingdong-verify.md` 存在且覆盖全部差异条目。
2. 事件数 = 1654、对话数 = 5183，抽样 3 条内容比对一致。
3. 原版零回归：`lua tests/test_runner.lua` 全绿。

## 完成情况（2026-10-17）

- **验证报告**：`reports/mingdong-verify.md`，覆盖 `diff.md` 的全部 385 MOD 独有 + 16 基准独有差异条目，
  逐条给出引擎容忍度结论。
- **回退链核验**：`smap`/`wmap`/`thing` 共 6 个基准独有文件在 MOD 缺失，回退目标 `data/` 下均存在。
- **数量一致**：事件 1654 = kdef 条目 1654；对话 5183 = talk 条目 5183。
- **内容抽样**：用独立 Python 解码器直接解码 `kys-mingdong/resource/talk.grp`，与流水线产物比对；
  talk 0/1/2978 三条一致，事件 1000 引用的 talk 2978 内容与 MOD 剧情吻合。
- **已知偏差**：`*` 折行布局（fishedit 自动折行，引擎对无 `*` 对话自动折行，不影响功能）；
  繁→简异体字差异（约 0.4%）。均已记录并评估为不影响功能。

验证记录：

- `reports/mingdong-verify.md` 存在，§7 DoD 对照 3 项均 ✅
- 事件/对话数量与抽样内容一致 ✅
- `lua tests/test_runner.lua` → **178 tests, 178 passed, 0 failed**
- `lua tools/mod_build.lua --verify-pascal` → **PASS**
