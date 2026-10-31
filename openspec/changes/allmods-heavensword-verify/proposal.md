---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice5
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-heavensword-verify

## Why

`allmods-heavensword-activate` 完成了构建、`hdgrp` 差异验证与缺陷 D 修复。本 change 做
**人工可复核的内容审计**：逐条核对 `diff.md` 差异，确认 MOD 独有内容确实被加载，
并确认零引擎改动。

## What Changes

1. 审计 `game/mods/HeavenSword/diff.md` 的 15 项 MOD 独有 + 21 项基准独有差异。
2. 逐项定性 21 项「基准独有」（回退原版 / 在 save/ / 死文件）。
3. 核对 MOD 独有内容确实被加载（非基线值）。
4. 确认 `hdgrp` 125 / kdef 1066 / fight 93 为内容差异而非结构异常。
5. 产出验证报告 `reports/heavensword-verify.md`。
6. 确认原版零回归。

## In Scope

- HeavenSword 的 `diff.md` 逐条审计
- MOD 独有内容验证
- `hdgrp` 差异 vs 结构异常的判定
- 验证报告

## Out of Scope

- 引擎改动
- 其余 14 个 MOD

## Requirements

### REQ-HSV-1: `diff.md` 逐条审计

对 `diff.md` 中每一项差异给出判定（预期 / 需修复 / 死文件）。

### REQ-HSV-2: 「基准独有」项性质确认

21 项「基准独有」必须逐项归类：`回退原版` / `在 save/` / `死文件`。不得有未解释项。
注意 HeavenSword 的 `d1.grp`/`s1.grp` **不在** save/（仅 `r1.idx` 在）。

### REQ-HSV-3: MOD 独有内容确实被加载

人物（楊千葉/胡斐/程靈素）、对话（3315 条）、事件（1066 个）、额外战斗（1 场）必须来自 MOD。

### REQ-HSV-4: `hdgrp` 差异 vs 结构异常判定

`hdgrp` 125（vs 115）必须被判定为**内容差异**，判据必须机器可验证且可外推到后续 MOD。

### REQ-HSV-5: 零引擎改动

不得修改 `game/engine-love2d/**`、`game/engine-mud/**`、
`game/script/jyconst.lua` 常量定义、`reference/allmods/**`。

### REQ-HSV-6: 验证报告

产出 `reports/heavensword-verify.md`，含逐条审计表、实测证据、结论。
