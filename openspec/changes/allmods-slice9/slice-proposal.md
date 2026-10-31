---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice9 — PTT（kys-ptt）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 9（**第 3 梯队收官**）

## Slice Type

Feature

## User Story

玩家激活 MOD「PTT」（kys-ptt）后，Love2D 引擎按回退链加载 ptt 的数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 ptt（排序依据）

第 3 梯队（hdgrp 170~210）第 3 个（收官）：

| 维度 | ptt | pascal 基线 | 差异 |
|------|----:|-----------:|------|
| **`hdgrp` 条目** | **204** | 115 | +89 头像 |
| `eft.grp` | 714 项 | 714 项 | 同形 |
| `warfld.grp` | 26 项 | 26 项 | 同形 |
| `cloud.grp` | 9 项 | 9 项 | 同形 |
| `title.grp` | 9 项 | 9 项 | 同形 |
| `kdef.grp` | 1229 项 | 1018 项 | 内容更多（+211 事件） |
| **fight** | **162** | 92 | **+70 额外战斗（本 epic 最多）** |
| `talk.grp` | 5689 项 | 2977 项 | 内容更多（+2712 对话） |
| **记录段** | **385/214/90/108** | 320/200/84/93 | **4 段全异（本 epic 首个）** |

**独特之处**：
1. **+70 额外战斗**（本 epic 目前最多，超过 lyff 的 +46）—— 继续检验 `fightNNN.grp` 索引驱动加载。
2. **4 个记录段全部与基线不同**（Person 385 / Thing 214 / Scene 90 / Wugong 108）——
   Slice 8 统一判据（索引驱动 + 无固定计数 + 字节全覆盖 + 边界有效）的**第 2 次应用**，
   且是**首个全段差异 MOD**（lyff 仅 Person 段差异）。
3. **18 个源自带存档**（`d1`~`d6`/`r1`~`r6`/`s1`~`s6`），本 epic 最多（pig 为 9 个）。
4. 独立 `eft/` PNG 目录（105 个 `EDITOR_DUMP`）—— 与 GodsDevils 的 `head/`/`item/` 同族。
5. `hdgrp` 204 是判据外推的**第 5 个样本**。

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("ptt")` 后，验证回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **ptt 数据包构建**：`lua tools/mod_build.lua kys-ptt`。
3. **逐文件穷举审计**：`lua tools/mod_audit.lua --mod ptt` → `unclassified=0`，无「必需但未进产物」矛盾。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod ptt` → `gaps=0`。
5. **真实启动链路端到端验证**（独立进程）：`boot_one_mod.lua ptt 385 214 90 108 鄉民`。
6. **`hdgrp` 204 差异验证**（判据第 5 次应用）。
7. **4 段记录数差异验证**（385/214/90/108，统一判据第 2 次应用）。
8. **70 场额外战斗验证**：三重确认（diff.md + 产物 + 审计归类）。
9. **存档验证**：21 个产物存档文件完好（18 个源自带存档槽）。
10. **原版零回归**。

## Out of Scope

- 其余 5 个 MOD（Slice 10-14：RiverLake / Dragon / pineapple / books / dream）
- `music/*.mid`（27 个 PENDING 项）—— 全局遗留 spike

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-ptt` | 退出码 0，`events=1229 talk=5689` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod ptt` | `total=596 unclassified=0 bad_evidence=0` |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("ptt")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod ptt` | `gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=ptt lua tools/mod_check_one.lua` | `PERSON=385 THING=214 SCENE=90 WUGONG=108 STRINGS/EVENTS/SAVE=OK` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua ptt 385 214 90 108 鄉民` | `RESULT ptt: OK` |
| 7 | `hdgrp` 差异判定 | `hdgrp.idx` 204 条目（816B），`gaps=0` | 内容差异（判据第 5 次应用） |
| 8 | 4 段记录数差异 | 段长整除 + 边界记录可读 | 内容差异（统一判据第 2 次应用） |
| 9 | 70 场额外战斗 | 产物 `fight*.grp` = 162 | 三重确认 |
| 10 | 存档完好 | 21 个产物存档与源逐字节一致 | 一致 |
| 11 | 无回归 | `lua tests/test_runner.lua` | 全绿 |

## 依赖

- **Slice 0 / 0b / 0c**（回退链、别名映射、穷举审计工具链）
- **Slice 2~7**（定型模板 + 5 个工具缺陷的修复 + `hdgrp` 判据 + 记录段统一判据）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-ptt-activate` | 构建 + 逐文件/字节级审计 + 真实启动链路 + `hdgrp` 差异 + 4 段记录数差异 + 额外战斗验证 |
| `allmods-ptt-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 报告 + 零回归 |
