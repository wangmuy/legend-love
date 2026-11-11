---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice3
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-stronger-activate

## Why

Slice 0/0b/0c 建立了 MOD 兼容地基（回退链、别名映射、穷举审计）。本 change 把
**威力加强版（kys-stronger）** 接入该地基，并验证地基对「与基线同形 MOD」是否足够。

stronger 位列剩余清单**第 1 梯队第 2 个**：hdgrp 115 / fight 92 / 全部格式尺寸与 pascal 同形，
唯一差异是 `talk.grp` 条目数（3727 vs 2977）。

## What Changes

1. 构建 stronger 数据包到 `game/mods/stronger/`。
2. 逐文件穷举审计：每个源文件归入具名类别，无缺口。
3. 字节级覆盖审计：每个字节归入具名字段。
4. 真实启动链路端到端验证（独立进程）。
5. 确认零引擎改动、零回归。

## In Scope

- stronger 的构建、审计、启动链路验证
- 产物 `save/` 完整性确认

## Out of Scope

- 引擎改动
- 其余 16 个 MOD
- `music/*.mid`（27 个 PENDING）

## Requirements

### REQ-STR-1: 构建成功

`lua tools/mod_build.lua kys-stronger` 退出码 0，产出完整产物目录。

### REQ-STR-2: 逐文件穷举归类

每个源文件归入具名类别，`unclassified=0`，`Σ(类别) = total`，
且「必需但未进产物」矛盾数 = 0。

### REQ-STR-3: 字节级覆盖

`format_spec.lua --mod stronger` 输出 `gaps=0` —— 每个字节归入具名字段。

### REQ-STR-4: 真实启动链路

独立进程 `boot_one_mod.lua` 输出 `RESULT stronger: OK`，16 项断言全 PASS。

### REQ-STR-5: MOD 独有内容加载

对话表（3727 条）、事件脚本（1018 个）、人物（韋大寶/胡斐/程靈素）来自 MOD 而非回退。

### REQ-STR-6: 零回归

全量测试、pascal 基线、`--all`、`mod_check` 全部通过。
