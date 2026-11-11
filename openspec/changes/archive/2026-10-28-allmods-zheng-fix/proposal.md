---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

实施 zheng 的数据驱动 idx 修复：从 `ranger.grp` 字节推断分段边界，构建期产出正确 idx。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-zheng/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-zheng/change-manifest.md`

## What Changes

1. 实现 `M.IdxIsConsistent` / `M.DetectLayout` / `M.RepairIdx`
2. `mod_build.lua` 构建期调用并写出修复后的 `data/ranger.idx`

## Requirements

### REQ-ZHENG-2 数据驱动修复
只依据字节与 UPedit 记录大小判定，不得按 MOD 名分支。

