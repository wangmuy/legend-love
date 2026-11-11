---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

为 真龙苏醒 的修复建立回归测试，并断言其余 MOD 零回归。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-awaken/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-awaken/change-manifest.md`

## What Changes

1. 新增/扩展单元测试
2. 在 `test_runner.lua` 注册（如需）

## Requirements

### REQ-AWAKEN-3 零回归
其余 19 个 MOD 与 pascal 基线不受影响。

