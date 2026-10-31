---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

复现并定位 kys-zheng 的真实缺陷（Thing 196 U+FFFD + 47 控制符；Scene 54 空 + 24 控制符；Wugong 214 空）。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-zheng/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-zheng/change-manifest.md`

## What Changes

1. 深度审计复现缺陷
2. 证明根因是 `save/ranger.idx` 描述的是 138596 字节存档而非 114242 字节 `ranger.grp`
3. 证明 zheng 布局本来就是标准的
4. 产出 `reports/reverse.md`

## Requirements

### REQ-ZHENG-1 缺陷复现
从数据本身推导，不得硬编码 MOD 名。

