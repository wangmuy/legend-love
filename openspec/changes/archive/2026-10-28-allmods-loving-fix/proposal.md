---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

实施 问情篇 的数据驱动修复：ini 映射对「负数表示未设置」的索引键保持引擎默认值（不覆盖）

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-loving/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-loving/change-manifest.md`

## What Changes

1. ini 映射对「负数表示未设置」的索引键保持引擎默认值（不覆盖）
2. 重建全部 MOD 验证

## Requirements

### REQ-LOVING-2 数据驱动修复
只依据字节/数值判定，不得按 MOD 名分支。

