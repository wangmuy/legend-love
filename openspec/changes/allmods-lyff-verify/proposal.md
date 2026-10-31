---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice8
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-lyff-verify

## Why

`allmods-lyff-activate` 完成了构建、穷举审计、字节级覆盖、326 人物段验证、
`hdgrp` 178 判据第 4 次应用与存档验证。本 change 做**人工可复核的内容审计**：
逐条核对 `diff.md` 差异（105 项 MOD 独有 + 23 项基准独有），确认 MOD 独有内容
确实被加载，并记录**首个记录数差异 MOD** 的判定。

## What Changes

1. 审计 `game/mods/lyff/diff.md` 的 105 项 MOD 独有 + 23 项基准独有差异。
2. 逐项定性 23 项「基准独有」（沿用 Slice 6 细化规则：在 save/ + 死文件 + 回退/播种）。
3. 核对 MOD 独有内容确实被加载（非基线值）。
4. 确认 326 人物段 / `hdgrp` 178 / kdef 1358 / talk 5655 / 46 场战斗为内容差异而非结构异常。
5. 产出验证报告 `reports/lyff-verify.md`。
6. 确认原版零回归。

## In Scope

- lyff 的 `diff.md` 逐条审计
- MOD 独有内容验证
- 记录数差异（326 人物段）判定
- `hdgrp` 差异 vs 结构异常的判定（判据第 4 次应用）
- 验证报告

## Out of Scope

- 引擎改动
- 其余 11 个 MOD

## Requirements

### REQ-LYFFV-1: `diff.md` 逐条审计

对 `diff.md` 中每一项差异给出判定（预期 / 需修复 / 死文件）。
105 项 MOD 独有 = 46 场额外战斗（92 文件）+ 13 项标准资源；23 项基准独有逐项定性。

### REQ-LYFFV-2: 「基准独有」项性质确认

23 项「基准独有」必须逐项归类：**在 save/** / **死文件** / **回退原版（含首次存档播种）**。
不得有未解释项。沿用 Slice 6 规则：`d/s*.idx` 为死文件（引擎无 S/D idx 常量）。

### REQ-LYFFV-3: MOD 独有内容确实被加载

人物（AAA/胡斐/程靈素/枯榮@325）、对话（5655 条）、事件（1358 个）、
46 场战斗必须来自 MOD。**注意**：Thing/Scene/Wugong 为 200/84/93（与基线同数，
无区分度），不得作为内容已加载的证据。

### REQ-LYFFV-4: 记录数差异 vs 结构异常判定

人物段 326（vs 320）必须被判定为**内容差异**：`PersonNum` 由
`(idx[2]-idx[1])/CC.PersonSize` 动态推导（`jymain.lua:1747`），无固定计数，
边界记录 `Person[325]` 有效，`gaps=0`。

### REQ-LYFFV-5: 零引擎改动

不得修改 `game/engine-love2d/**`、`game/engine-mud/**`、
`game/script/jyconst.lua` 常量定义、`reference/allmods/**`。

### REQ-LYFFV-6: 验证报告

产出 `reports/lyff-verify.md`，含逐条审计表、实测证据、结论。
