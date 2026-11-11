---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

实施 天书劫 的数据驱动修复：构建期剥离字段内 CR/LF（`M.TrimControl`）

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-bookcalamity/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-bookcalamity/change-manifest.md`

## What Changes

1. 构建期剥离字段内 CR/LF（`M.TrimControl`）
2. 重建全部 MOD 验证

## Requirements

### REQ-BOOKCALAMITY-2 数据驱动修复
只依据字节/数值判定，不得按 MOD 名分支。

