---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice6
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-godsdevils-activate

## Why

Slice 5 验证了 `hdgrp` 差异无需引擎改动（索引驱动）。本 change 把 **天龙八部（kys-GodsDevils）**
接入地基 —— 它是**第 2 梯队最后一个**，也是本 epic 遇到**最多 `EDITOR_DUMP` 文件**的 MOD。

| 维度 | GodsDevils | pascal | 差异 |
|------|-----------:|-------:|------|
| **`hdgrp`** | **129** | 115 | +14 头像 |
| `kdef` | 1123 | 1018 | +105 事件 |
| fight | 92 | 92 | 同数 |
| `talk` | 4640 | 2977 | +1663 对话 |
| `head/` PNG | **79** | — | `EDITOR_DUMP` |
| `item/` PNG | **200** | — | `EDITOR_DUMP` |

**核心验证点**：
1. `hdgrp` 129 差异（复用 Slice 5 判据）
2. **279 个 `EDITOR_DUMP`** PNG 确认引擎不读
3. 6 个存档文件（`d1`/`d2`/`r1`/`r2`/`s1`/`s2`）完好 —— 检验缺陷 D 修复的持久性

## What Changes

1. 构建 GodsDevils 数据包到 `game/mods/GodsDevils/`。
2. 逐文件穷举审计：每个源文件归入具名类别，无缺口。
3. 字节级覆盖审计：每个字节归入具名字段。
4. **`hdgrp` 129 差异验证**（复用 Slice 5 判据）。
5. **`head/`/`item/` EDITOR_DUMP 确认**（279 个）。
6. 真实启动链路端到端验证（独立进程）。
7. 存档验证（6 个文件）。
8. 确认零引擎改动、零回归。

## In Scope

- GodsDevils 的构建、审计、启动链路验证
- `hdgrp` 差异验证
- `EDITOR_DUMP` 确认
- 存档验证

## Out of Scope

- 引擎改动
- 其余 13 个 MOD
- `music/*.mid`（27 个 PENDING）

## Requirements

### REQ-GD-1: 构建成功

`lua tools/mod_build.lua kys-GodsDevils` 退出码 0，产出完整产物目录。

### REQ-GD-2: 逐文件穷举归类

每个源文件归入具名类别，`unclassified=0`，`Σ(类别) = total = 615`，
且「必需但未进产物」矛盾数 = 0。

### REQ-GD-3: 字节级覆盖

`format_spec.lua --mod GodsDevils` 输出 `gaps=0`。

### REQ-GD-4: `hdgrp` 差异验证

`hdgrp.idx` = 129 条目（pascal 115）。引擎索引驱动加载，无固定计数依赖。
判定为**内容差异**。

### REQ-GD-5: `EDITOR_DUMP` 确认

`head/`（79）+ `item/`（200）= 279 个 PNG 归类为 `EDITOR_DUMP`，引擎不读。

### REQ-GD-6: 真实启动链路

独立进程 `boot_one_mod.lua` 输出 `RESULT GodsDevils: OK`，16 项断言全 PASS。

### REQ-GD-7: 存档验证

产物 9 个存档文件与源逐字节一致；运行时路径指向 MOD save 目录；
验证后无残留。

### REQ-GD-8: 零回归

全量测试、pascal 基线、`--all`、`mod_check`、全 MOD save 完整性全部通过。
