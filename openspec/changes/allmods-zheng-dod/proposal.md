---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

核实 zheng 修复的完整 DoD。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice-zheng/slice-proposal.md`
- Manifest: `openspec/changes/allmods-slice-zheng/change-manifest.md`

## What Changes

1. 运行全部验收命令
2. 产出 `reports/dod.md`

## Requirements

### REQ-ZHENG-4 端到端验证
`MOD_SLUG=zheng lua tools/mod_check_one.lua` 必须 PERSON=320 THING=200 SCENE=84 WUGONG=93 STRINGS=OK EVENTS=OK SAVE=OK。

