---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice5
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-heavensword-activate

## Why

Slice 0/0b/0c 建立了 MOD 兼容地基；Slice 2/3/4 完成第 1 梯队（与基线同形）。本 change
把 **倚天剑（kys-HeavenSword）** 接入地基 —— 它是**第 2 梯队第 1 个**，也是本 epic 遇到的
**第一个 `hdgrp` 条目数不同的 MOD**。

| 维度 | HeavenSword | pascal | 差异 |
|------|------------:|-------:|------|
| **`hdgrp`** | **125** | 115 | **+10 头像** ← 首个 hdgrp 不同 |
| `kdef` | 1066 | 1018 | +48 事件 |
| fight | 93 | 92 | +1 战斗 |
| `talk` | 3315 | 2977 | +338 对话 |
| eft/warfld/cloud/title | 同形 | 同形 | — |

**核心风险**：`hdgrp` 条目数不同是否引入固定计数依赖？需验证引擎为**索引驱动**加载。

## What Changes

1. 构建 HeavenSword 数据包到 `game/mods/HeavenSword/`。
2. 逐文件穷举审计：每个源文件归入具名类别，无缺口。
3. 字节级覆盖审计：每个字节归入具名字段。
4. **`hdgrp` 差异验证**：确认 125 条目为内容差异，索引驱动加载无固定计数。
5. 真实启动链路端到端验证（独立进程）。
6. **存档验证**：源自带 `r1.idx`（= `ranger.idx` 副本）但无 `r1.grp`。
7. 确认零引擎改动、零回归。

## In Scope

- HeavenSword 的构建、审计、启动链路验证
- `hdgrp` 条目数差异的影响验证
- 存档验证

## Out of Scope

- 引擎改动
- 其余 14 个 MOD
- `music/*.mid`（27 个 PENDING）

## Requirements

### REQ-HS-1: 构建成功

`lua tools/mod_build.lua kys-HeavenSword` 退出码 0，产出完整产物目录。

### REQ-HS-2: 逐文件穷举归类

每个源文件归入具名类别，`unclassified=0`，`Σ(类别) = total`，
且「必需但未进产物」矛盾数 = 0。

### REQ-HS-3: 字节级覆盖

`format_spec.lua --mod HeavenSword` 输出 `gaps=0`。

### REQ-HS-4: `hdgrp` 差异验证

`hdgrp.idx` = 125 条目（pascal 115）。引擎为索引驱动加载，无固定计数依赖。
判定为**内容差异**，非结构异常。

### REQ-HS-5: 真实启动链路

独立进程 `boot_one_mod.lua` 输出 `RESULT HeavenSword: OK`，16 项断言全 PASS。

### REQ-HS-6: 存档验证

源自带 `r1.idx`（= `ranger.idx` 字节相同）但无 `r1.grp`；
首次存档播种 `r1.grp`；`r1.ovr` 覆盖生效；验证后无残留。

### REQ-HS-7: 零回归

全量测试、pascal 基线、`--all`、`mod_check` 全部通过。
