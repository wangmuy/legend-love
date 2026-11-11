---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

复现并定位 问情篇 的真实缺陷（字段级零缺陷（0 FFFD / 0 控制符 / 0 空值）；`BEGIN_SCENE = -1` / `BEGIN_EVENT = -1`（作者声明「不指定」））。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-loving/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-loving/change-manifest.md`

## What Changes

1. 深度审计复现缺陷
2. 从字节定位根因
3. 产出 `reports/reverse.md`

## Requirements

### REQ-LOVING-1 缺陷复现
从数据本身推导，不得硬编码 MOD 名。

