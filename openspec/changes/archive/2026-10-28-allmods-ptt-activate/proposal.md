---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice9
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-ptt-activate

## Why

Slice 5~8 在 5 个 MOD 上验证了 `hdgrp` 差异无需引擎改动（索引驱动，判据外推链
125/129/173/178），Slice 8 进一步把判据扩展到**记录段**（lyff 326 人物）。
本 change 把 **PTT（kys-ptt）** 接入地基 —— 它是**第 3 梯队收官**，也是：

1. 本 epic 目前**额外战斗最多**的 MOD（**+70**，超过 lyff 的 +46）。
2. **首个 4 段记录数全异**的 MOD（Person 385 / Thing 214 / Scene 90 / Wugong 108 vs 基线
   320/200/84/93）—— 统一判据的第 2 次应用。
3. **源自带存档最多**的 MOD（18 个槽：`d1`~`d6`/`r1`~`r6`/`s1`~`s6`）。

| 维度 | ptt | pascal | 差异 |
|------|----:|-------:|------|
| **`hdgrp`** | **204** | 115 | +89 头像 |
| `kdef` | 1229 | 1018 | +211 事件 |
| **fight** | **162** | 92 | **+70 战斗** |
| `talk` | 5689 | 2977 | +2712 对话 |
| **记录段** | **385/214/90/108** | 320/200/84/93 | **4 段全异** |

**核心验证点**：
1. `hdgrp` 204 差异（判据**第 5 次应用**）
2. **4 段记录数差异**（统一判据**第 2 次应用**，首个全段差异 MOD）
3. **70 场额外战斗**三重确认（`diff.md` + 产物 + 审计）
4. **18 个源自带存档**完好（缺陷 D 修复的更强检验）

## What Changes

1. 构建 ptt 数据包到 `game/mods/ptt/`。
2. 逐文件穷举审计：每个源文件归入具名类别，无缺口。
3. 字节级覆盖审计：每个字节归入具名字段。
4. **`hdgrp` 204 差异验证**（判据第 5 次应用）。
5. **4 段记录数差异验证**（385/214/90/108，统一判据第 2 次应用）。
6. **70 场额外战斗三重确认**。
7. 真实启动链路端到端验证（独立进程，主角「鄉民」）。
8. 存档验证（21 个产物文件，18 个源自带存档槽）。
9. 确认零引擎改动、零回归。

## In Scope

- ptt 的构建、审计、启动链路验证
- `hdgrp` 差异验证
- 4 段记录数差异验证
- 额外战斗验证
- 存档验证

## Out of Scope

- 引擎改动
- 其余 5 个 MOD（Slice 10-14）
- `music/*.mid`（27 个 PENDING）

## Requirements

### REQ-PTT-1: 构建成功

`lua tools/mod_build.lua kys-ptt` 退出码 0，产出完整产物目录（`events=1229 talk=5689`）。

### REQ-PTT-2: 逐文件穷举归类

每个源文件归入具名类别，`unclassified=0`，`Σ(类别) = total = 596`，
且「必需但未进产物」矛盾数 = 0。

### REQ-PTT-3: 字节级覆盖

`format_spec.lua --mod ptt` 输出 `gaps=0`。

### REQ-PTT-4: `hdgrp` 差异验证

`hdgrp.idx` = 204 条目（pascal 115）。引擎索引驱动加载，无固定计数依赖。
判定为**内容差异**。判据第 5 次应用结论一致。

### REQ-PTT-5: 4 段记录数差异验证

Person 385 / Thing 214 / Scene 90 / Wugong 108（基线 320/200/84/93）：
每段段长整除记录大小、索引驱动推导、边界记录可读、字节全覆盖。
判定为**内容差异**（零引擎改动）。统一判据第 2 次应用，首个全段差异 MOD。

### REQ-PTT-6: 70 场额外战斗

70 场额外战斗每场三重确认：`diff.md` 提及 + 产物存在 + 审计归类
`REQUIRED`/`in_product=true`。产物 `fight*.grp` 总数 = 162。

### REQ-PTT-7: 真实启动链路

独立进程 `boot_one_mod.lua ptt 385 214 90 108 鄉民` 输出 `RESULT ptt: OK`，
16 项断言全 PASS。

### REQ-PTT-8: 存档验证

产物 21 个存档文件与源逐字节一致；源自带 18 个槽；运行时路径指向 MOD save 目录；
验证后无残留。

### REQ-PTT-9: 零回归

全量测试、pascal 基线、`--all`、`mod_check`、全 MOD save 完整性全部通过。
