---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

实施 金庸水浒传dos版 的数据驱动修复：字符串字段判定改为「含任意高位字节」（`hasHighByte`），纯数值字段自动跳过

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-pig3dos/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-pig3dos/change-manifest.md`

## What Changes

1. 字符串字段判定改为「含任意高位字节」（`hasHighByte`），纯数值字段自动跳过
2. 重建全部 MOD 验证

## Requirements

### REQ-PIG3DOS-2 数据驱动修复
只依据字节/数值判定，不得按 MOD 名分支。

