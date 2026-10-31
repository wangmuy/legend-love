---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice6 — 天龙八部（kys-GodsDevils）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 6（剩余 MOD 清单第 2 梯队第 2 个，**第 2 梯队收官**）

## Slice Type

Feature

## User Story

玩家激活 MOD「天龙八部」（kys-GodsDevils）后，Love2D 引擎按回退链加载 GodsDevils 的数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 GodsDevils（排序依据）

第 2 梯队（hdgrp 略增）最后 1 个：

| 维度 | GodsDevils | pascal 基线 | 差异 |
|------|-----------:|-----------:|------|
| **`hdgrp` 条目** | **129** | 115 | +14 头像 |
| `eft.grp` | 714 项 | 714 项 | 同形 |
| `warfld.grp` | 26 项 | 26 项 | 同形 |
| `cloud.grp` | 9 项 | 9 项 | 同形 |
| `title.grp` | 9 项 | 9 项 | 同形 |
| `kdef.grp` | 1123 项 | 1018 项 | 内容更多（+105 事件） |
| fight | 92 | 92 | **同数** |
| `talk.grp` | 4640 项 | 2977 项 | 内容更多（+1663 对话） |

**独特之处**：含独立的 `head/`（79 PNG）与 `item/`（200 PNG）目录，
**已确认引擎不读**（`EDITOR_DUMP`）。

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("GodsDevils")` 后，验证回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **GodsDevils 数据包构建**：`lua tools/mod_build.lua kys-GodsDevils`。
3. **逐文件穷举审计**：`lua tools/mod_audit.lua --mod GodsDevils` → `unclassified=0`，无「必需但未进产物」矛盾。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod GodsDevils` → `gaps=0`。
5. **真实启动链路端到端验证**（独立进程）：`boot_one_mod.lua GodsDevils 320 200 84 93 蝦米`。
6. **`hdgrp` 129 差异验证**（复用 Slice 5 判据）。
7. **`head/`/`item/` EDITOR_DUMP 确认**：279 个 PNG 引擎不读。
8. **存档验证**：6 个存档文件（`d1`/`d2`/`r1`/`r2`/`s1`/`s2`）完好。
9. **原版零回归**。

## Out of Scope

- 其余 13 个 MOD（Slice 7-18）
- `music/*.mid`（27 个 PENDING 项）—— 全局遗留 spike

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-GodsDevils` | 退出码 0，`events=1123` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod GodsDevils` | `total=615 unclassified=0 bad_evidence=0` |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("GodsDevils")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod GodsDevils` | `gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=GodsDevils lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua GodsDevils 320 200 84 93 蝦米` | `RESULT GodsDevils: OK` |
| 7 | `hdgrp` 差异判定 | `hdgrp.idx` 129 条目，`gaps=0` | 内容差异 |
| 8 | `head/`/`item/` EDITOR_DUMP | 279 个 PNG 归类 | `EDITOR_DUMP`，引擎不读 |
| 9 | 存档完好 | 6 个存档文件与源逐字节一致 | 一致 |
| 10 | 无回归 | `lua tests/test_runner.lua` | 全绿 |

## 依赖

- **Slice 0 / 0b / 0c**（回退链、别名映射、穷举审计工具链）
- **Slice 2~5**（定型模板 + 4 个工具缺陷的修复）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-godsdevils-activate` | 构建 + 逐文件/字节级审计 + 真实启动链路 + `hdgrp` 差异验证 + EDITOR_DUMP 确认 |
| `allmods-godsdevils-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 报告 + 零回归 |
