---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice5 — 倚天剑（kys-HeavenSword）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 5（剩余 MOD 清单第 2 梯队第 1 个）

## Slice Type

Feature

## User Story

玩家激活 MOD「倚天剑」（kys-HeavenSword）后，Love2D 引擎按回退链加载 HeavenSword 的数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 HeavenSword（排序依据）

`openspec/epics/2026-10-allmods-compat/TODO.md` 的剩余 MOD 清单按「与基线（kys-pascal）的数据形态距离」
排序。HeavenSword 位列**第 2 梯队（hdgrp 略增）**第 1 个：

| 维度 | HeavenSword | pascal 基线 | 差异 |
|------|------------:|-----------:|------|
| **`hdgrp` 条目** | **125** | 115 | **+10 头像**（第 1 个 hdgrp 不同的 MOD） |
| `eft.grp` | 714 项 | 714 项 | 同形 |
| `warfld.grp` | 26 项 | 26 项 | 同形 |
| `cloud.grp` | 9 项 | 9 项 | 同形 |
| `title.grp` | 9 项 | 9 项 | 同形 |
| `kdef.grp` | 1066 项 | 1018 项 | 内容更多（+48 事件） |
| fight | 93 | 92 | 内容更多（+1 战斗） |
| `talk.grp` | 3315 项 | 2977 项 | 内容更多（+338 对话） |

**关键**：`hdgrp` 125 是本 epic 遇到的**第一个 hdgrp 条目数不同的 MOD**。需验证：
- `hdgrp.idx` 条目数不同是否影响引擎加载（索引驱动 vs 固定计数）
- 记录布局常量是否仍与 pascal 相同

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("HeavenSword")` 后，验证回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **HeavenSword 数据包构建**：`lua tools/mod_build.lua kys-HeavenSword` 产出 `game/mods/HeavenSword/**`。
3. **逐文件穷举审计**：`lua tools/mod_audit.lua --mod HeavenSword` → `unclassified=0`，无「必需但未进产物」矛盾。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod HeavenSword` → `gaps=0`。
5. **真实启动链路端到端验证**（独立进程）：`boot_one_mod.lua HeavenSword 320 200 84 93 楊千葉`。
6. **`hdgrp` 差异验证**：确认 125 条目为内容差异，索引驱动加载无固定计数依赖。
7. **存档验证**：HeavenSword 源自带 `r1.idx`（= `ranger.idx` 副本）但无 `r1.grp`。
8. **原版零回归**。

## Out of Scope

- 其余 14 个 MOD（Slice 6-18）
- `music/*.mid`（27 个 PENDING 项）—— 全局遗留 spike

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-HeavenSword` | 退出码 0，`events=1066` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod HeavenSword` | `total=335 unclassified=0 bad_evidence=0` |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("HeavenSword")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod HeavenSword` | `gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=HeavenSword lua tools/mod_check_one.lua` | `STRINGS/EVENTS/SAVE=OK` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua HeavenSword 320 200 84 93 楊千葉` | `RESULT HeavenSword: OK` |
| 7 | `hdgrp` 差异判定 | `hdgrp.idx` 125 条目，`gaps=0` | 内容差异，非结构异常 |
| 8 | 存档验证 | save→load round trip | `r1.grp` 播种；`r1.ovr` 覆盖；无残留 |
| 9 | 无回归 | `lua tests/test_runner.lua` | 全绿 |

## 依赖

- **Slice 0 / 0b / 0c**（回退链、别名映射、穷举审计工具链）
- **Slice 2 / 3 / 4**（定型模板 + 3 个工具缺陷的修复）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-heavensword-activate` | 构建 + 逐文件/字节级审计 + 真实启动链路 + `hdgrp` 差异验证 |
| `allmods-heavensword-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 报告 + 零回归 |
