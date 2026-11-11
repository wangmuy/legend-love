---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice6
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-godsdevils-verify

## Why

`allmods-godsdevils-activate` 完成了构建、穷举审计、字节级覆盖、启动链路、`hdgrp` 129
判据外推与存档验证。本 change 做**人工可复核的内容审计**：逐条核对 `diff.md` 差异，
确认 MOD 独有内容确实被加载，并用**源码级证据**细化「基准独有」项的定性
（发现 6 个 `d/s*.idx` 是死文件而非回退原版）。

## What Changes

1. 审计 `game/mods/GodsDevils/diff.md` 的 13 项 MOD 独有 + 23 项基准独有差异。
2. 逐项定性 23 项「基准独有」：在 save/ 6 + 死文件 9 + 回退原版/首次播种 8。
3. 核对 MOD 独有内容确实被加载（非基线值）。
4. 确认 `hdgrp` 129 / kdef 1123 / talk 4640 为内容差异而非结构异常（判据第二次外推）。
5. 产出验证报告 `reports/godsdevils-verify.md`。
6. 确认原版零回归。

## In Scope

- GodsDevils 的 `diff.md` 逐条审计
- MOD 独有内容验证
- `hdgrp` 差异 vs 结构异常的判定（第二次外推）
- 验证报告

## Out of Scope

- 引擎改动
- 其余 13 个 MOD

## Requirements

### REQ-GDV-1: `diff.md` 逐条审计

对 `diff.md` 中每一项差异给出判定（预期 / 需修复 / 死文件）。

### REQ-GDV-2: 「基准独有」项性质确认

23 项「基准独有」必须逐项归类：**在 save/** / **死文件** / **回退原版（含首次存档播种）**。
不得有未解释项。关键判据：引擎只有 `CC.R_IDXFilename`（`jyconst.lua:80`「S和D由于是
固定大小，因此不再定义idx了」）→ 6 个 `d/s*.idx` 为**死文件**。

### REQ-GDV-3: MOD 独有内容确实被加载

人物（蝦米/胡斐/程靈素）、对话（4640 条）、事件（1123 个）必须来自 MOD。
**注意**：fight 92 == pascal 92（同数，无区分度），不得作为内容已加载的证据。

### REQ-GDV-4: `hdgrp` 差异 vs 结构异常判定

`hdgrp` 129（vs 115）必须被判定为**内容差异**，判据复用 Slice 5 ADR-001 的
三重机器可验证判据（本 MOD 为**第二次外推验证**）。

### REQ-GDV-5: 零引擎改动

不得修改 `game/engine-love2d/**`、`game/engine-mud/**`、
`game/script/jyconst.lua` 常量定义、`reference/allmods/**`。

### REQ-GDV-6: 验证报告

产出 `reports/godsdevils-verify.md`，含逐条审计表、实测证据、结论。
