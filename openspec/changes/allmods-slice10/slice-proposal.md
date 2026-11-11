---
status: active
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice10 — RiverLake（kys-RiverLake）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 10（**第 4 梯队开场**）

## Slice Type

Feature

## User Story

玩家激活 MOD「RiverLake」（kys-RiverLake）后，Love2D 引擎按回退链加载其数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 RiverLake（排序依据）

第 4 梯队（`hdgrp` 250~300）第 1 个（开场）—— 梯队内按 `hdgrp` 条目数升序
（RiverLake 252 → Dragon 267 → pineapple 300），与 epic `TODO.md` 的排序键一致。

| 维度 | RiverLake | pascal 基线 | 差异 |
|------|----------:|-----------:|------|
| **`hdgrp` 条目** | **252** | 115 | **+137 头像** |
| `eft` 条目 | 921 | 714 | +207（**非同形**） |
| `warfld` 条目 | 26 | 26 | 同形 |
| `cloud` / `title` 条目 | 9 / 9 | 9 / 9 | 同形 |
| **fight** | **219** | 92 | **+127 额外战斗** |
| `kdef` 事件 | 1232 | 1018 | +214 |
| **`talk` 条目** | **8015** | 2977 | **+5038** |
| **记录段** | **325/249/84/96** | 320/200/84/93 | Person +5 / Thing +49 / Scene 同 / Wugong +3 |
| `ranger.grp` 字节 | 124870 | 114242 | +10628 |

**在 20 个 MOD 中的排名（实测）**：

| 维度 | RiverLake | 全 MOD 排名 | 榜首 |
|------|----------:|:-----------:|------|
| `talk` 条目 | 8015 | **第 1** | RiverLake 自身（次席 awaken 7717） |
| `fight` 数 | 219 | **第 2** | awaken 237 |
| `hdgrp` 条目 | 252 | 第 8 | books 696 |

**独特之处**：

1. **`talk` 8015 = 本 epic 第 1**（次席 awaken 7717、books 6655）—— `oldtalk.idx` 索引分段的
   最强检验；`+5038` 是本 epic 最大 `talk` 增量。
2. **`fight` 219 = 本 epic 第 2**（次席于 awaken 237，超过 ptt 162）—— 127 场额外战斗的
   索引驱动加载检验（三重确认）。
3. **`hdgrp` 252 = 判据第 6 个样本**（外推链 125/129/173/178/204/**252**）。
4. **记录段 3 段异 / 1 段（Scene）与基线相同** —— 统一判据第 3 次应用。
   与既有两例模式不同：lyff 是「1 段异 / 4 段同」，ptt 是「4 段全异」，RiverLake 是
   「3 段异 / Scene 同」。**Scene 段与基线同为 84 是阴性对照**：判据必须能区分
   「段数相同但内容不同」与「段数不同」，不得把「Scene 84」误判为内容未加载
   （REQ-RIV-4）。
5. **`eft` 921 vs 714（+207）** —— 与 ptt「eft 同形」不同，本 MOD 的 `eft` 是内容扩展。
   需确认 `eft.idx` 索引驱动（非固定计数常量）。
6. **28 个 0 字节 `e72.wav`~`e98.wav`**（Slice 0c 已记录）—— 验证 `PlayWAV`
   （`lib_love.lua:602-621`）的 `pcall` 容错确实吞掉空文件错误、不中断游戏。
7. `resource/name.grp`/`name.idx` = `LEGACY`（引擎 0 引用，`EV_LEGACY_NAME` 证据）。
8. `list/*.bin`（4 项 PENDING）+ `list/*.txt`（2 项 LEGACY）—— 与 ptt 同族。

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("RiverLake")` 后验证回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **RiverLake 数据包构建**：`lua tools/mod_build.lua kys-RiverLake`。
3. **逐文件穷举审计**：`lua tools/mod_audit.lua --mod RiverLake` → `unclassified=0`，无「必需但未进产物」矛盾。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod RiverLake` → `gaps=0`。
5. **真实启动链路端到端验证**（独立进程）：`boot_one_mod.lua RiverLake 325 249 84 96 茲`。
6. **`hdgrp` 252 差异验证**（判据第 6 次应用）。
7. **记录段差异验证**（325/249/84/96，统一判据第 3 次应用，含「1 段与基线相同」的阴性对照）。
8. **127 场额外战斗验证**：三重确认（diff.md + 产物 + 审计归类），本 epic 最多。
9. **存档验证**：21 个产物存档文件与源逐字节一致（18 个源自带存档槽）。
10. **空 WAV 容错验证**：28 个 0 字节 `e72`~`e98` 不导致运行时报错。
11. **原版零回归**。

## Out of Scope

- 其余 3 个 MOD（Slice 11-13：Dragon / pineapple / books）
- `music/*.mid`（23 个 PENDING 项）—— 全局遗留 spike
- `list/*.bin`（4 个 PENDING 项）—— C 引擎列表数据，同 ptt
- 引擎任何改动

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-RiverLake` | 退出码 0，`events=1232 talk=8015` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod RiverLake` | `total=699 unclassified=0 bad_evidence=0`（= 源文件数 699） |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("RiverLake")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod RiverLake` | `formats=12 checked=413 gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=RiverLake lua tools/mod_check_one.lua` | `PERSON=325 THING=249 SCENE=84 WUGONG=96 STRINGS/EVENTS/SAVE=OK` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua RiverLake 325 249 84 96 茲` | `RESULT RiverLake: OK` |
| 7 | `hdgrp` 差异判定 | `hdgrp.idx` 1008B = **252** 条目，`gaps=0` | 内容差异（判据第 6 次应用） |
| 7b | `eft` 差异判定 | `eft.idx` 3684B = **921** 条目（基线 714），`gaps=0` | 内容差异，索引驱动 |
| 8 | 记录段差异 | 4 段全部整除（325/249/84/96），Scene 84 = 基线的**阴性对照** | 内容差异（统一判据第 3 次应用） |
| 9 | 127 场额外战斗 | 产物 `fight*.grp` = **219**（差集 127） | 三重确认，全部 `REQUIRED`/`in_product` |
| 10 | 存档完好 | 21 个产物存档与源逐字节一致 | 一致 |
| 11 | 空 WAV 容错 | 28 个 0 字节 `e72`~`e98` 存在且不报错 | 运行时无报错 |
| 12 | 无回归 | `lua tests/test_runner.lua` | 1622/1622 |

## 依赖

- **Slice 0 / 0b / 0c**（回退链、别名映射、穷举审计工具链）
- **Slice 2~9**（定型模板 + 5 个工具缺陷修复 + `hdgrp` 判据 + 记录段统一判据 + 首次播种类别）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-riverlake-activate` | 构建 + 逐文件/字节级审计 + 真实启动链路 + `hdgrp`/`eft` 差异 + 记录段差异 + 127 额外战斗 + 空 WAV |
| `allmods-riverlake-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 21 项基准独有定性 + 报告 + 零回归 |
