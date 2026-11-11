---
status: done
created: 2026-10-16
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

MOD 间 `thing.grp`/`hdgrp.grp` 条目数与原版不同（114→266），且各 MOD 数据文件清单有增删。在动 `allmods-data-fallback` 的加载点改造之前，必须先弄清物品图渲染链路（`LoadThingPic=0` 路径）与数据加载侧全部硬编码假设，否则弹性改造会漏改。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice0/slice-proposal.md`（Contract B 的前置输入）
- 依赖: none（只读审计，最先执行）

## What Changes

只读 Spike，产出审计报告（本 change 目录内 `reports/thingpic-audit.md`），不改运行代码：

1. 追踪 `LoadThingPic=0` 物品图渲染链路：`thing.grp` 条目 → 解码 → smap 场景渲染的完整调用链（含 `instruct_*` 侧）
2. 枚举数据加载侧全部硬编码假设：hdgrp/thing 条目数、fight 文件数（`CC.FightPicFile` 使用点）、数据文件清单（`jyconst.lua` 文件常量 vs 实际加载点）
3. 定界：列出 `allmods-data-fallback` 需要收敛到 `ModData.Resolve` 的加载点清单（文件 + 函数级），以及哪些条目数/文件数必须改为动态枚举
4. 风险项：ptt/GodsDevils 的 grp 条目完整性核对（探索期遗留项）

## Scope Boundaries

### In Scope
- 只读代码追踪与二进制核对
- 审计报告（含加载点清单、动态枚举改造点、风险项结论）

### Out of Scope
- 任何运行代码修改（加载点改造属于 allmods-data-fallback）
- MOD 端到端验证（Slice 1+）

## Capabilities

### New Capabilities
- `allmods-spike-report`: 物品图链路审计 + 数据弹性改造定界报告（[REQ-SPIKE-1]）

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-SPIKE-1] | 审计报告覆盖物品图链路、硬编码假设清单、加载点改造清单，作为 allmods-data-fallback 的输入 |

## DoD

1. `reports/thingpic-audit.md` 产出，含加载点清单（文件 + 函数级）
2. 报告中每个硬编码假设都有源码 `file:line` 证据
3. allmods-data-fallback 可直接按报告清单实施，无需二次探索
