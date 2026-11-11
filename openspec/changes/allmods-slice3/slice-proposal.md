---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice3 — 威力加强版（kys-stronger）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 3（剩余 MOD 清单第 1 梯队第 2 个）

## Slice Type

Feature

## User Story

玩家激活 MOD「威力加强版」（kys-stronger）后，Love2D 引擎按回退链加载 stronger 的数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 stronger（排序依据）

`openspec/epics/2026-10-allmods-compat/TODO.md` 的剩余 MOD 清单按「与基线（kys-pascal）的数据形态距离」
排序。stronger 位列**第 1 梯队（与基线完全同形）**：

| 维度 | stronger | pascal 基线 | 差异 |
|------|---------:|-----------:|------|
| hdgrp 条目 | 115 | 115 | **同形** |
| fight 数 | 92 | 92 | **同形** |
| `eft.grp` | 714 项 | 714 项 | 同形 |
| `warfld.grp` | 26 项 | 26 项 | 同形 |
| `cloud.grp` | 9 项 | 9 项 | 同形 |
| `title.grp` | 9 项 | 9 项 | 同形 |
| `kdef.grp` | 1018 项 | 1018 项 | 同形 |
| `talk.grp` | 3727 项 | 2977 项 | **条目数不同**（剧情量更大） |

**唯一差异**是 `talk.grp` 条目数（3727 vs 2977），属预期内的剧情差异。

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("stronger")` 后，验证回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **stronger 数据包构建**：`lua tools/mod_build.lua kys-stronger` 产出 `game/mods/stronger/{data,script,save,sound,diff.md}`。
3. **逐文件穷举审计**：`lua tools/mod_audit.lua --mod stronger` → `unclassified=0`，无「必需但未进产物」矛盾。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod stronger` → `gaps=0`。
5. **真实启动链路端到端验证**（独立进程）：`boot_one_mod.lua stronger 320 200 84 93 韋大寶`。
6. **MOD 独有内容验证**：对话表、事件脚本确实来自 MOD（非静默回退原版）。
7. **原版零回归**。

## Out of Scope

- 其余 16 个 MOD（Slice 4-18）
- `music/*.mid`（27 个 PENDING 项）—— 全局遗留 spike

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-stronger` | 退出码 0，`events=1018` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod stronger` | `total=335 unclassified=0 bad_evidence=0` |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("stronger")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod stronger` | `gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=stronger lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua stronger 320 200 84 93 韋大寶` | `RESULT stronger: OK` |
| 7 | 无回归 | `lua tests/test_runner.lua` | 全绿 |

## 依赖

- **Slice 0 / 0b / 0c**（回退链、别名映射、穷举审计工具链）
- **Slice 2**（定型的 6 步验证模板 + `mod_check_one` 数据销毁缺陷修复）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-stronger-activate` | 构建 + 逐文件/字节级审计 + 真实启动链路端到端验证 |
| `allmods-stronger-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 报告 + 零回归 |
