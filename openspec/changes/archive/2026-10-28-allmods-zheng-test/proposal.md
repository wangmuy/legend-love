---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

为 zheng 的 idx 修复建立回归测试，并断言其余 MOD 零回归。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-zheng/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-zheng/change-manifest.md`

## What Changes

1. 新增 `game/tests/unit/test_mod_encoding.lua`（41 断言）
2. 在 `test_runner.lua` 注册 `mod_encoding` 模块

## Requirements

### REQ-ZHENG-3 零回归
其余 19 个 MOD 与 pascal 基线不受影响。

