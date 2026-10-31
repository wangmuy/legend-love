---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

复现并定位 真龙苏醒 的真实缺陷（6 个控制符（字段内 CRLF））。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-awaken/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-awaken/change-manifest.md`

## What Changes

1. 深度审计复现缺陷
2. 从字节定位根因
3. 产出 `reports/reverse.md`

## Requirements

### REQ-AWAKEN-1 缺陷复现
从数据本身推导，不得硬编码 MOD 名。

