---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice2
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-sweeOan-verify

## Why

`allmods-sweeOan-activate` 完成了构建与机器验证。本 change 做**人工可复核的内容审计**：
逐条核对 `diff.md` 的每一项差异，确认引擎加载点对 SweeOan 数据形态的容忍度，
并确认 MOD 独有内容（对话/事件/战斗/人物）确实来自 MOD 而非静默回退原版。

## What Changes

1. 审计 `game/mods/SweeOan/diff.md` 的 14 项 MOD 独有 + 23 项基准独有差异。
2. 核对 23 项「基准独有」中每一项的真实性质（回退原版 / 在 save/ / 死文件）。
3. 核对 MOD 独有内容确实被加载。
4. 产出验证报告 `reports/sweeOan-verify.md`。
5. 确认原版零回归。

## In Scope

- SweeOan 的 `diff.md` 逐条审计
- MOD 独有内容验证
- 验证报告

## Out of Scope

- 引擎改动
- 其余 17 个 MOD

## Requirements

### REQ-SWEEV-1: `diff.md` 逐条审计

对 `diff.md` 中每一项差异给出判定（预期 / 需修复 / 死文件），并说明引擎行为。

### REQ-SWEEV-2: 「基准独有」项性质确认

23 项「基准独有」必须逐项归类：`回退原版`（引擎从 `data/` 读取）、`在 save/`（用户存档）、
`死文件`（引擎不读）。不得有未解释项。

### REQ-SWEEV-3: MOD 独有内容确实被加载

对话（2977 条）、事件（1018 个）、战斗（92 对）、人物（王小石/衛悲回/伊小深）
必须来自 MOD 目录，而非静默回退。

### REQ-SWEEV-4: 零引擎改动

本 slice 必须**不修改** `game/engine-love2d/**`、`game/engine-mud/**`、
`game/script/jyconst.lua` 常量定义。

### REQ-SWEEV-5: 验证报告

产出 `reports/sweeOan-verify.md`，含逐条审计表、实测证据、结论。

### REQ-SWEEV-6: 发现的问题已修复并回归

本 slice 发现的缺陷必须修复并有回归测试。
