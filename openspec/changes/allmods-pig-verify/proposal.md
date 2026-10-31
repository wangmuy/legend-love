---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice7
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-pig-verify

## Why

`allmods-pig-activate` 完成了构建、`hdgrp` 差异验证（判据第 3 次应用）、
45 场额外战斗三重确认。本 change 做**人工可复核的内容审计**：逐条核对 `diff.md` 差异，
确认 MOD 独有内容确实被加载，并确认零引擎改动。

## What Changes

1. 审计 `game/mods/pig/diff.md` 的 103 项 MOD 独有 + 21 项基准独有差异。
2. 逐项定性 21 项「基准独有」（回退原版 / 在 save/ / 死文件）。
3. 核对 MOD 独有内容确实被加载（非基线值）。
4. 确认 `hdgrp` 173 / kdef 1288 / fight 137 为内容差异而非结构异常。
5. 复核 45 场额外战斗的三重确认。
6. 产出验证报告 `reports/pig-verify.md`。
7. 确认原版零回归。

## In Scope

- pig 的 `diff.md` 逐条审计
- MOD 独有内容验证
- `hdgrp` / fight 差异 vs 结构异常的判定
- 验证报告

## Out of Scope

- 引擎改动
- 其余 11 个 MOD

## Requirements

### REQ-PIGV-1: `diff.md` 逐条审计

对 `diff.md` 中每一项差异给出判定（预期 / 需修复 / 死文件）。

### REQ-PIGV-2: 「基准独有」项性质确认

21 项「基准独有」必须逐项归类：`回退原版` / `在 save/` / `死文件`。不得有未解释项。
pig 有 9 个源自带存档（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`）。

### REQ-PIGV-3: MOD 独有内容确实被加载

人物（小小豬/胡斐/程靈素）、对话（4123 条）、事件（1288 个）、战斗（137 场）必须来自 MOD。

### REQ-PIGV-4: `hdgrp` / fight 差异 vs 结构异常判定

`hdgrp` 173（vs 115）与 fight 137（vs 92）必须被判定为**内容差异**，
判据复用 Slice 5 ADR-001 并记录其**第 3 次应用**。

### REQ-PIGV-5: 45 场额外战斗复核

45 场额外战斗的三重确认必须复核（`diff.md` + 产物 + 审计）。

### REQ-PIGV-6: 零引擎改动

不得修改 `game/engine-love2d/**`、`game/engine-mud/**`、
`game/script/jyconst.lua` 常量定义、`reference/allmods/**`。

### REQ-PIGV-7: 验证报告

产出 `reports/pig-verify.md`，含逐条审计表、实测证据、结论。
