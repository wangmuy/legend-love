---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice7 — 小猪闯江湖（kys-pig）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 7（**第 3 梯队第 1 个**）

## Slice Type

Feature

## User Story

玩家激活 MOD「小猪闯江湖」（kys-pig）后，Love2D 引擎按回退链加载 pig 的数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 pig（排序依据）

第 3 梯队（hdgrp 170~210）第 1 个：

| 维度 | pig | pascal 基线 | 差异 |
|------|----:|-----------:|------|
| **`hdgrp` 条目** | **173** | 115 | +58 头像 |
| `eft.grp` | 714 项 | 714 项 | 同形 |
| `warfld.grp` | 26 项 | 26 项 | 同形 |
| `cloud.grp` | 9 项 | 9 项 | 同形 |
| `title.grp` | 9 项 | 9 项 | 同形 |
| `kdef.grp` | 1288 项 | 1018 项 | 内容更多（+270 事件） |
| **fight** | **137** | 92 | **+45 额外战斗** |
| `talk.grp` | 4123 项 | 2977 项 | 内容更多（+1146 对话） |

**独特之处**：
1. **+45 额外战斗**（本 epic 目前最多）—— 检验 `fightNNN.grp` 索引驱动加载。
2. **9 个源自带存档**（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`），比第 2 梯队更多。
3. `hdgrp` 173 是判据外推的**第 3 个样本**。

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("pig")` 后，验证回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **pig 数据包构建**：`lua tools/mod_build.lua kys-pig`。
3. **逐文件穷举审计**：`lua tools/mod_audit.lua --mod pig` → `unclassified=0`，无「必需但未进产物」矛盾。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod pig` → `gaps=0`。
5. **真实启动链路端到端验证**（独立进程）：`boot_one_mod.lua pig 320 200 84 93 小小豬`。
6. **`hdgrp` 173 差异验证**（判据第 3 次应用）。
7. **45 场额外战斗验证**：三重确认（diff.md + 产物 + 审计归类）。
8. **存档验证**：21 个产物存档文件完好。
9. **原版零回归**。

## Out of Scope

- 其余 11 个 MOD（Slice 8-18）
- `music/*.mid`（27 个 PENDING 项）—— 全局遗留 spike

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-pig` | 退出码 0，`events=1288` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod pig` | `total=440 unclassified=0 bad_evidence=0` |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("pig")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod pig` | `gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=pig lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua pig 320 200 84 93 小小豬` | `RESULT pig: OK` |
| 7 | `hdgrp` 差异判定 | `hdgrp.idx` 173 条目，`gaps=0` | 内容差异 |
| 8 | 45 场额外战斗 | 产物 `fight*.grp` = 137 | 三重确认 |
| 9 | 存档完好 | 21 个产物存档与源逐字节一致 | 一致 |
| 10 | 无回归 | `lua tests/test_runner.lua` | 全绿 |

## 依赖

- **Slice 0 / 0b / 0c**（回退链、别名映射、穷举审计工具链）
- **Slice 2~6**（定型模板 + 4 个工具缺陷的修复 + `hdgrp` 判据）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-pig-activate` | 构建 + 逐文件/字节级审计 + 真实启动链路 + `hdgrp` 差异 + 额外战斗验证 |
| `allmods-pig-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 报告 + 零回归 |
