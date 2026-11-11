---
status: active
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice14

> 纵向切片：1 个 MOD（kys-dream 笑梦游记）的端到端适配 + 机器验证。
> 复用 Slice 2~10 定型的 6 步模板（构建 → 穷举审计 → 字节覆盖 → 产物四项检查
> → 真实启动链路 → diff 逐条审计 + 报告）。

## Why

dream（kys-dream，笑梦游记）是本 epic **hdgrp 第 2 大**（484，仅次于 books 696），且携带
**三个本 epic 首次出现的形态**：

1. **记录段 5/5 全异**（409/192/122/102/6 vs 基线 320/200/84/93/3）—— 统一记录段判据的
   **第 3 次应用**（lyff 1 段 → ptt 4 段 → dream 5/5 段），且全部使用**标准记录尺寸**
   （182/190/52/136/50），排除了「MOD 自定义记录布局」变量。
2. **源 `ranger.idx` 损坏**（5 个段长全部不可整除；zheng 之后的第 2 个案例）—— 构建期
   既有 `RepairIdx` 机制（`mod_build.lua:709-717`）从字节推导修复并持久化进产物，
   **零引擎改动、零新代码**。
3. **战斗集合「增 + 删」结构**（122 = 92 − 41 删 + 71 增）—— 本 epic 首个同时大量删除
   基线战斗（41 场，回退原版）与新增战斗（71 场）的 MOD。

| 维度 | dream | pascal | 差异 |
|------|------:|-------:|------|
| **`hdgrp`** | **484** | 115 | +369 头像（判据第 7 次应用） |
| **fight** | **122** | 92 | +71 增 / −41 删 |
| `kdef` 事件 | 4569 | 1018 | +3551 |
| `talk` | 6464 | 2977 | +3487 |
| **记录段** | **409/192/122/102/6** | 320/200/84/93/3 | 5/5 段全异 |
| **源 `ranger.idx`** | **损坏** | 正常 | 构建期 RepairIdx（第 2 案例） |
| 源自带存档 | 27 槽（缺 8 号） | 3 槽 | +24 槽 |

## In Scope

- `game/mods/dream/**`（构建产物）
- `openspec/changes/allmods-slice14/**`
- `openspec/changes/allmods-dream-activate/**`、`openspec/changes/allmods-dream-verify/**`

## Out of Scope

- 引擎任何改动（`engine-love2d/**` / `engine-mud/**`）、`script/jyconst.lua` 常量、`reference/allmods/**`
- `music/*.mid`（25 项 PENDING）、`list/*.bin`（4 项 PENDING）—— epic 级遗留 spike
- `fight23.idx` 作者残留的处理（仅记录；流水线忠实保留，引擎不读）
- `new.idx`（LEGACY，引擎无引用）的处理（仅记录）

## 子 change

| # | 子 change | 类型 |
|---|-----------|------|
| 1 | `allmods-dream-activate` | 构建 + 机器验证 |
| 2 | `allmods-dream-verify` | 内容审计 + 报告 |

## Definition of Done

- 6 步验证全绿（契约见 `change-manifest.md` A~H）
- `unclassified=0`、`gaps=0`、`RESULT dream: OK`（16 断言）
- 零引擎改动、零代码改动、零回归
