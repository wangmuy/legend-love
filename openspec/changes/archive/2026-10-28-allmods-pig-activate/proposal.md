---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice7
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-pig-activate

## Why

Slice 5/6 在 2 个 MOD 上验证了 `hdgrp` 差异无需引擎改动（索引驱动）。
本 change 把 **小猪闯江湖（kys-pig）** 接入地基 —— 它是**第 3 梯队第 1 个**，
也是本 epic 目前**额外战斗最多**的 MOD（+45）。

| 维度 | pig | pascal | 差异 |
|------|----:|-------:|------|
| **`hdgrp`** | **173** | 115 | +58 头像 |
| `kdef` | 1288 | 1018 | +270 事件 |
| **fight** | **137** | 92 | **+45 战斗** |
| `talk` | 4123 | 2977 | +1146 对话 |

**核心验证点**：
1. `hdgrp` 173 差异（判据**第 3 次应用**）
2. **45 场额外战斗**三重确认（`diff.md` + 产物 + 审计）
3. **9 个源自带存档**（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`）完好

## What Changes

1. 构建 pig 数据包到 `game/mods/pig/`。
2. 逐文件穷举审计：每个源文件归入具名类别，无缺口。
3. 字节级覆盖审计：每个字节归入具名字段。
4. **`hdgrp` 173 差异验证**（判据第 3 次应用）。
5. **45 场额外战斗三重确认**。
6. 真实启动链路端到端验证（独立进程）。
7. 存档验证（21 个产物文件）。
8. 确认零引擎改动、零回归。

## In Scope

- pig 的构建、审计、启动链路验证
- `hdgrp` 差异验证
- 额外战斗验证
- 存档验证

## Out of Scope

- 引擎改动
- 其余 11 个 MOD
- `music/*.mid`（27 个 PENDING）

## Requirements

### REQ-PIG-1: 构建成功

`lua tools/mod_build.lua kys-pig` 退出码 0，产出完整产物目录。

### REQ-PIG-2: 逐文件穷举归类

每个源文件归入具名类别，`unclassified=0`，`Σ(类别) = total = 440`，
且「必需但未进产物」矛盾数 = 0。

### REQ-PIG-3: 字节级覆盖

`format_spec.lua --mod pig` 输出 `gaps=0`。

### REQ-PIG-4: `hdgrp` 差异验证

`hdgrp.idx` = 173 条目（pascal 115）。引擎索引驱动加载，无固定计数依赖。
判定为**内容差异**。判据第 3 次应用结论一致。

### REQ-PIG-5: 45 场额外战斗

45 场额外战斗（`fight030`/`039`/`040`/`110`/`115`~`121`/`125`/`126`/`128`~`131`/
`133`~`146`/`152`~`162`/`167`/`169`/`170`）每场三重确认：
`diff.md` 提及 + 产物存在 + 审计归类 `REQUIRED`/`in_product=true`。
产物 `fight*.grp` 总数 = 137。

### REQ-PIG-6: 真实启动链路

独立进程 `boot_one_mod.lua` 输出 `RESULT pig: OK`，16 项断言全 PASS。

### REQ-PIG-7: 存档验证

产物 21 个存档文件与源逐字节一致；源自带 9 个槽；运行时路径指向 MOD save 目录；
验证后无残留。

### REQ-PIG-8: 零回归

全量测试、pascal 基线、`--all`、`mod_check`、全 MOD save 完整性全部通过。
