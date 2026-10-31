---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice3
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-stronger-verify

## Why

`allmods-stronger-activate` 完成了构建与机器验证。本 change 做**人工可复核的内容审计**：
逐条核对 `diff.md` 差异，确认 MOD 独有内容确实被加载，并确认零引擎改动。

## What Changes

1. 审计 `game/mods/stronger/diff.md` 的 MOD 独有 + 21 项基准独有差异。
2. 逐项定性 21 项「基准独有」（回退原版 / 在 save/ / 死文件）。
3. 核对 MOD 独有内容确实被加载（非基线值）。
4. 产出验证报告 `reports/stronger-verify.md`。
5. **修正审计工具对 `kysmod.ini` 的 `in_product` 误判**（发现于本 change）。
6. 确认原版零回归。

## In Scope

- stronger 的 `diff.md` 逐条审计
- MOD 独有内容验证
- 审计工具的 `kysmod.ini` 判定修正
- 验证报告

## Out of Scope

- 引擎改动
- 其余 16 个 MOD

## Requirements

### REQ-STRV-1: `diff.md` 逐条审计

对 `diff.md` 中每一项差异给出判定（预期 / 需修复 / 死文件），并说明引擎行为。

### REQ-STRV-2: 「基准独有」项性质确认

21 项「基准独有」必须逐项归类：`回退原版` / `在 save/` / `死文件`。不得有未解释项。

### REQ-STRV-3: MOD 独有内容确实被加载

人物（韋大寶/胡斐/程靈素）、对话（3727 条）、事件（1018 个）必须来自 MOD。

### REQ-STRV-4: `kysmod.ini` 的 `in_product` 判定修正

审计工具必须正确报告 `kysmod.ini` 的 `in_product=true`（构建器复制到 `data/`），
同时保持 `cc/*.txt`（构建期词典）的 `in_product=false`。

### REQ-STRV-5: 零引擎改动

不得修改 `game/engine-love2d/**`、`game/engine-mud/**`、
`game/script/jyconst.lua` 常量定义、`reference/allmods/**`。

### REQ-STRV-6: 验证报告 + 回归测试

产出报告，并为 `kysmod.ini`/`cc/*.txt` 判定新增回归测试。
