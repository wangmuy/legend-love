---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice9
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-ptt-verify

## Why

`allmods-ptt-activate` 完成了构建、`hdgrp` 差异验证（判据第 5 次应用）、
4 段记录数差异验证（统一判据第 2 次应用）、70 场额外战斗三重确认。
本 change 做**人工可复核的内容审计**：逐条核对 `diff.md` 差异，确认 MOD 独有内容
确实被加载，并确认零引擎改动。

## What Changes

1. 审计 `game/mods/ptt/diff.md` 的 154 项 MOD 独有 + 21 项基准独有差异。
2. 逐项定性 21 项「基准独有」（回退原版 / 在 save/ / 死文件）。
3. 核对 MOD 独有内容确实被加载（非基线值）。
4. 确认 `hdgrp` 204 / kdef 1229 / fight 162 / 记录段 385/214/90/108 为内容差异而非结构异常。
5. 复核 70 场额外战斗的三重确认。
6. 产出验证报告 `reports/ptt-verify.md`。
7. 确认原版零回归。

## In Scope

- ptt 的 `diff.md` 逐条审计
- MOD 独有内容验证
- `hdgrp` / fight / 记录段 差异 vs 结构异常的判定
- 验证报告

## Out of Scope

- 引擎改动
- 其余 4 个未做 MOD（RiverLake / Dragon / pineapple / books）

## Requirements

### REQ-PTTV-1: `diff.md` 逐条审计

对 `diff.md` 中每一项差异给出判定（预期 / 需修复 / 死文件）。
154 项「MOD 独有」全部有判定，需修复项 = 0。

### REQ-PTTV-2: 「基准独有」项性质确认

21 项「基准独有」必须逐项归类：`回退原版` / `在 save/` / `死文件`。不得有未解释项。
ptt 有 18 个源自带存档槽（`d1`~`d6`/`r1`~`r6`/`s1`~`s6`），本 epic 最多。

### REQ-PTTV-3: MOD 独有内容确实被加载

人物（鄉民/胡斐/程靈素）、对话（5689 条）、事件（1229 个）、战斗（162 场）、
记录段（385/214/90/108）必须来自 MOD，且必须用**非基线值**证明。

### REQ-PTTV-4: `hdgrp` / fight / 记录段 差异 vs 结构异常判定

`hdgrp` 204（vs 115）、fight 162（vs 92）、4 段记录数（385/214/90/108 vs 320/200/84/93）
必须被判定为**内容差异**：
- `hdgrp` 判据复用 Slice 5 ADR-001，记录其**第 5 次应用**；
- 记录段判据复用 Slice 8 统一判据，记录其**第 2 次应用**（首个全段差异 MOD）。

### REQ-PTTV-5: 70 场额外战斗复核

70 场额外战斗的三重确认必须复核（`diff.md` + 产物 + 审计）。

### REQ-PTTV-6: 零引擎改动 / 零代码改动

不得修改 `game/engine-love2d/**`、`game/engine-mud/**`、
`game/script/jyconst.lua` 常量定义、`reference/allmods/**`。
本 slice 还应做到零 `game/tools/**` 与 `game/framework/**` 改动。

### REQ-PTTV-7: 验证报告

产出 `reports/ptt-verify.md`，含逐条审计表、实测证据、结论。

### REQ-PTTV-8: ptt 的 EDITOR_DUMP 证据

105 个 `eft/` PNG 目录必须是「不需要」且有机器可复核证据（`IGNORE_DIRS` + 引擎 0 引用）。

### REQ-PTTV-9: PENDING 的显式边界

27 项 `PENDING`（`music/*.mid` 23 + `list/*.bin` 4）必须显式声明为全局遗留 spike，
**不得**用「不确定」笼统表述。
