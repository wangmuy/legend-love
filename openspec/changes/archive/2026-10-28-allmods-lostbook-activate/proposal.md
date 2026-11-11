---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice4
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-lostbook-activate

## Why

Slice 0/0b/0c 建立了 MOD 兼容地基。本 change 把 **失传天书-越女剑（kys-lostbook）** 接入该地基。

lostbook 位列剩余清单**第 1 梯队第 3 个**（最后一个）：hdgrp 115 / eft 714 / warfld 26 / cloud 9 / title 9
与 pascal 同形，但**内容更多**：

| 维度 | lostbook | pascal | 差异 |
|------|---------:|-------:|------|
| `kdef.grp` | **1071** | 1018 | +53 事件 |
| fight | **97** | 92 | +5 战斗（039-042, 052） |
| `talk.grp` | 3181 | 2977 | +204 对话 |

## What Changes

1. 构建 lostbook 数据包到 `game/mods/lostbook/`。
2. 逐文件穷举审计：每个源文件归入具名类别，无缺口。
3. 字节级覆盖审计：每个字节归入具名字段。
4. 真实启动链路端到端验证（独立进程）。
5. **存档播种验证**：lostbook 源无 `r1.grp`，验证首次存档播种。
6. 确认零引擎改动、零回归。

## In Scope

- lostbook 的构建、审计、启动链路验证
- 存档播种行为验证

## Out of Scope

- 引擎改动
- 其余 15 个 MOD
- `music/*.mid`（27 个 PENDING）

## Requirements

### REQ-LOST-1: 构建成功

`lua tools/mod_build.lua kys-lostbook` 退出码 0，产出完整产物目录。

### REQ-LOST-2: 逐文件穷举归类

每个源文件归入具名类别，`unclassified=0`，`Σ(类别) = total`，
且「必需但未进产物」矛盾数 = 0。

### REQ-LOST-3: 字节级覆盖

`format_spec.lua --mod lostbook` 输出 `gaps=0`。

### REQ-LOST-4: 真实启动链路

独立进程 `boot_one_mod.lua` 输出 `RESULT lostbook: OK`，16 项断言全 PASS。

### REQ-LOST-5: 存档播种

lostbook 源无 `r1.grp`；首次存档从 `ranger.idx` 播种 `r1.idx`/`r1.grp`；
字符串改写写入 `r1.ovr` 且读档时优先；验证后无残留。

### REQ-LOST-6: 零回归

全量测试、pascal 基线、`--all`、`mod_check` 全部通过。
