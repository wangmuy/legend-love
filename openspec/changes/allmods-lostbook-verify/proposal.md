---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice4
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-lostbook-verify

## Why

`allmods-lostbook-activate` 完成了构建与机器验证。本 change 做**人工可复核的内容审计**：
逐条核对 `diff.md` 差异，确认 MOD 独有内容确实被加载，并确认零引擎改动。

## What Changes

1. 审计 `game/mods/lostbook/diff.md` 的 24 项 MOD 独有 + 21 项基准独有差异。
2. 逐项定性 21 项「基准独有」（回退原版 / 在 save/ / 死文件）。
3. 核对 MOD 独有内容确实被加载（非基线值）。
4. 确认 kdef 1071 / fight 97 为内容差异而非结构异常。
5. 产出验证报告 `reports/lostbook-verify.md`。
6. 确认原版零回归。

## In Scope

- lostbook 的 `diff.md` 逐条审计
- MOD 独有内容验证
- 内容差异 vs 结构异常的判定
- 验证报告

## Out of Scope

- 引擎改动
- 其余 15 个 MOD

## Requirements

### REQ-LOSTV-1: `diff.md` 逐条审计

对 `diff.md` 中每一项差异给出判定（预期 / 需修复 / 死文件）。

### REQ-LOSTV-2: 「基准独有」项性质确认

21 项「基准独有」必须逐项归类：`回退原版` / `在 save/` / `死文件`。不得有未解释项。

### REQ-LOSTV-3: MOD 独有内容确实被加载

人物（金迷/胡斐/程靈素）、对话（3181 条）、事件（1071 个）、额外战斗（5 场）必须来自 MOD。

### REQ-LOSTV-4: 内容差异 vs 结构异常判定

kdef 1071 / fight 97 必须被判定为**内容差异**（每项尺寸不变），
而非结构异常。判据必须机器可验证。

### REQ-LOSTV-5: 零引擎改动

不得修改 `game/engine-love2d/**`、`game/engine-mud/**`、
`game/script/jyconst.lua` 常量定义、`reference/allmods/**`。

### REQ-LOSTV-6: 验证报告

产出 `reports/lostbook-verify.md`，含逐条审计表、实测证据、结论。
