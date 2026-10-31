---
status: active
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice11 — Dragon（kys-Dragon）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 11（**第 4 梯队第 2 个**）

## Slice Type

Feature

## User Story

玩家激活 MOD「Dragon」（kys-Dragon / 苍龙逐日）后，Love2D 引擎按回退链加载其数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 Dragon（排序依据）

第 4 梯队（`hdgrp` 250~300）第 2 个 —— 梯队内按 `hdgrp` 条目数升序
（RiverLake 252 ✅ → **Dragon 267** → pineapple 300），与 epic `TODO.md` 排序键一致。

| 维度 | Dragon | pascal 基线 | 差异 |
|------|-------:|-----------:|------|
| **`hdgrp` 条目** | **267** | 115 | **+152 头像** |
| **`fight`** | **209** | 92 | **+117 额外战斗** |
| `kdef` 事件 | 1087 | 1018 | +69 |
| `talk` 条目 | 4020 | 2977 | +1043 |
| **记录段** | **589/237/106/114** | 320/200/84/93 | **4 段全异**（Person +269 / Thing +37 / Scene +22 / Wugong +21） |
| `ranger.grp` 字节 | 174230 | 114242 | +59988 |
| `eft` 条目 | 714 | 714 | **同形** |
| `data files` | 458 | — | — |
| `sound` | 80 | — | — |

**在 20 个 MOD 中的排名（实测）**：

| 维度 | Dragon | 全 MOD 排名 | 榜首 |
|------|-------:|:-----------:|------|
| `hdgrp` 条目 | 267 | 第 7 | books 696 |
| `fight` 数 | 209 | 第 3 | awaken 237（次席 RiverLake 219） |
| Person 记录数 | **589** | **第 2** | BookCalamity 800 |
| `talk` 条目 | 4020 | 第 10 左右 | RiverLake 8015 |

**独特之处**：

1. **Person 589 = 本 epic 第 2 多**（次席于 BookCalamity 800，超过 awaken 720）——
   人物段 107198 字节整除 182 检验。
2. **4 段记录数全异**（589/237/106/114 vs 320/200/84/93）—— 判据第 4 次应用
   （lyff 1 段 / ptt 4 段 / RiverLake 3 段 / Dragon 4 段 + Scene 段异）。
3. **`eft` 714 = 与基线同形** —— 与 RiverLake（921，+207）成对照：
   `eft` 同形 **不**意味着「回退原版」，需用 `eft.grp` 内容/索引条目数分别确认。
   同时 Dragon 的 eft id 最大值 = **52**（与基线同）⇒ **不**触发 RiverLake 发现的
   `CC.Effect` 53 项截断缺陷。
4. **`resource/war1.sta` = `DEAD_FILE`（66030B / 355 记录）** —— 本 epic 首个
   由 `mod_audit` 规则显式标注的 `DEAD_FILE`（RiverLake 的 `allsinbk.grp` 是运行时
   形参未用，Dragon 的 `war1.sta` 是**代码零引用**）。
   两者的区别需在报告中显式说明。
5. **`head/` 220 个 PNG = `EDITOR_DUMP`** —— 与 Slice 6（GodsDevils 279）/ Slice 9（ptt 105）同族。
6. **`basename 相同但内容不同`**：`resource/war.sta`（42222B / 227 记录）
   vs 基线 `data/war.sta`（26040B / 140 记录）—— 同名文件内容差异，属内容差异非结构异常。
7. **`fight101`/`fight102` = 基准独有** —— 本 epic 首次出现「基线有战斗文件、MOD 没有」
   （前 10 个 slice 的基准独有都只是存档/thing/allsinbk）。必须证明引擎不因此崩溃。

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("Dragon")` 后验证回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **Dragon 数据包构建**：`lua tools/mod_build.lua kys-Dragon`。
3. **逐文件穷举审计**：`lua tools/mod_audit.lua --mod Dragon` → `unclassified=0`，无「必需但未进产物」矛盾。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod Dragon` → `gaps=0`。
5. **真实启动链路端到端验证**（独立进程）：`boot_one_mod.lua Dragon 589 237 106 114 資`。
6. **`hdgrp` 267 差异验证**（判据第 7 次应用）。
7. **记录段差异验证**（589/237/106/114，统一判据第 4 次应用，4 段全异含 Scene）。
8. **`eft` 714 同形验证** + eft id 上界 52 确认（不触发 `CC.Effect` 截断）。
9. **117 场额外战斗验证**：三重确认。
10. **存档验证**：27 个产物存档文件与源逐字节一致（18 个源自带存档槽）。
11. **`DEAD_FILE` `war1.sta` 定性**：代码零引用证据。
12. **`fight101`/`fight102` 基准独有分析**：为何 MOD 不需要 + 引擎容错。
13. **原版零回归**。

## Out of Scope

- 其余 2 个 MOD（Slice 12-13：pineapple / books）
- `music/*.mid`（24 个 PENDING 项）+ `list/*.bin`（5 个 PENDING 项，含 `list/match - 复制.bin`）—— 全局遗留 spike
- 引擎任何改动

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-Dragon` | `data files=458 saves=21 sound=80 events=1087 talk=4020` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod Dragon` | `total=811 unclassified=0 bad_evidence=0`（= 源文件数 811） |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("Dragon")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod Dragon` | `formats=12 checked=535 gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=Dragon lua tools/mod_check_one.lua` | `PERSON=589 THING=237 SCENE=106 WUGONG=114 HERO=資` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua Dragon 589 237 106 114 資` | `RESULT Dragon: OK`（16 断言） |
| 7 | `hdgrp` 差异判定 | `hdgrp.idx` 1068B = **267** 条目，`gaps=0` | 内容差异（判据第 7 次应用） |
| 7b | `eft` 同形判定 | `eft.idx` 2856B = **714** 条目（= 基线），`gaps=0` | 同形但需内容证明 |
| 8 | 记录段差异 | 4 段全部整除（589/237/106/114） | 内容差异（判据第 4 次应用，4 段全异） |
| 9 | 117 场额外战斗 | 产物 `fight*.grp` = **209**（差集 117） | 三重确认，全部 `REQUIRED`/`in_product` |
| 10 | 存档完好 | 27 个产物存档与源逐字节一致 | 一致 |
| 11 | `war1.sta` DEAD_FILE | 代码零引用 | 证据齐备 |
| 12 | `fight101/102` 基准独有 | 引擎容错不崩 | 证据齐备 |
| 13 | 无回归 | `lua tests/test_runner.lua` | 1842/1842 |

## 依赖

- **Slice 0 / 0b / 0c**（回退链、别名映射、穷举审计工具链）
- **Slice 2~10**（定型模板 + 6 个工具缺陷修复 + `hdgrp` 判据 + 记录段统一判据 +
  四类「基准独有」定性 + Scene 阴性对照方法）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-dragon-activate` | 构建 + 逐文件/字节级审计 + 真实启动链路 + `hdgrp`/`eft` 差异 + 记录段差异 + 117 额外战斗 + 存档 |
| `allmods-dragon-verify` | `diff.md` 逐条审计 + 25 项基准独有定性 + `war1.sta`/`fight101-102` 定性 + 报告 + 零回归 |
