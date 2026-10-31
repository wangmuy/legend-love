---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice8
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-lyff-activate

## Why

Slice 7（pig）验证了 45 场额外战斗与 9 个源自带存档。本 change 把 **刘亦纷飞版（kys-lyff）**
接入地基 —— 它是**第 3 梯队第 2 个**，也是本 epic **首次出现非 320 人物数**（PERSON=326）的 MOD。

| 维度 | lyff | pascal | 差异 |
|------|----:|-------:|------|
| **`hdgrp`** | **178** | 115 | +63 头像 |
| `kdef` | 1358 | 1018 | +340 事件 |
| **fight** | **138** | 92 | **+46 战斗（本 epic 最多）** |
| `talk` | 5655 | 2977 | +2678 对话（本 epic 最多） |
| **Person** | **326** | 320 | **+6 人物（本 epic 首次非 320）** |

**核心验证点**：
1. **PERSON 326 差异**（本 epic 首次非 320，需验证索引驱动加载）
2. `hdgrp` 178 差异（判据**第 4 次应用**）
3. **46 场额外战斗**三重确认（比 pig 多 `fight173`）
4. **talk 5655 条**（本 epic 最多）
5. 主角姓名 = **AAA**（MOD 作者测试名）

## What Changes

1. 构建 lyff 数据包到 `game/mods/lyff/`。
2. 逐文件穷举审计：每个源文件归入具名类别，无缺口。
3. 字节级覆盖审计：每个字节归入具名字段。
4. **`hdgrp` 178 差异验证**（判据第 4 次应用）。
5. **PERSON 326 差异验证**（本 epic 首次非 320，索引驱动判定）。
6. **46 场额外战斗三重确认**。
7. 真实启动链路端到端验证（独立进程，`boot_one_mod.lua lyff 326 200 84 93 AAA`）。
8. 存档验证（6 个产物文件）。
9. 确认零引擎改动、零回归。

## In Scope

- lyff 的构建、审计、启动链路验证
- `hdgrp` / PERSON 差异验证
- 额外战斗验证
- 存档验证

## Out of Scope

- 引擎改动
- 其余 10 个 MOD
- `music/*.mid`（27 个 PENDING）

## Requirements

### REQ-LYF-1: 构建成功

`lua tools/mod_build.lua kys-lyff` 退出码 0，产出完整产物目录。

### REQ-LYF-2: 逐文件穷举归类

每个源文件归入具名类别，`unclassified=0`，`Σ(类别) = total = 425`，
且「必需但未进产物」矛盾数 = 0。

### REQ-LYF-3: 字节级覆盖

`format_spec.lua --mod lyff` 输出 `gaps=0`。

### REQ-LYF-4: `hdgrp` 差异验证

`hdgrp.idx` = 178 条目（pascal 115）。引擎索引驱动加载，无固定计数依赖。
判定为**内容差异**。判据第 4 次应用结论一致。

### REQ-LYF-5: **PERSON 差异验证（本 epic 首次非 320）**

`JY.PersonNum = 326`（pascal 320，+6）。`ranger.grp` seg1 = 59332 字节 = 326 × 182。
`JY.PersonNum = math.floor((idx[2]-idx[1])/CC.PersonSize)` —— **索引驱动**，无固定常量。
判定为**内容差异**，**零引擎改动**。

### REQ-LYF-6: 46 场额外战斗

46 场额外战斗（`fight030`/`039`/`040`/`110`/`115`~`121`/`125`/`126`/`128`~`131`/
`133`~`146`/`152`~`162`/`167`/`169`/`170`/`173`）每场三重确认：
`diff.md` 提及 + 产物存在 + 审计归类 `REQUIRED`/`in_product=true`。
产物 `fight*.grp` 总数 = 138。

### REQ-LYF-7: 真实启动链路

独立进程 `boot_one_mod.lua` 输出 `RESULT lyff: OK`，16 项断言全 PASS。
主角姓名 = **AAA**。

### REQ-LYF-8: 存档验证

产物 6 个存档文件与源逐字节一致；源自带 3 个槽（`d1`/`r1`/`s1`）；
运行时路径指向 MOD save 目录；验证后无残留。

### REQ-LYF-9: 零回归

全量测试、pascal 基线、`--all`、`mod_check`、全 MOD save 完整性全部通过。
