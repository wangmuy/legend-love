---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice6
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-godsdevils-verify

## Context

GodsDevils 是第 2 梯队收官 MOD（hdgrp 129 / kdef 1123 / talk 4640 / fight 92）。
本 change 的核心问题是：**「基准独有」23 项的逐项定性必须基于源码级引用证据**，
而非文件是否存在——粗粒度分类（如「回退原版 14」）会把引擎根本不读的
`d/s*.idx` 误归为「回退原版」。

## ADR-001: `hdgrp` 129 差异 = Slice 5 三重判据的第二次外推

**Context**：Slice 5（HeavenSword）建立了 `hdgrp` 差异的三重判据并在本 MOD
（activate 子 change）完成首次外推。本 change 复核该判定，并确认其外推链：
HeavenSword（125，首次）→ GodsDevils（129，第二次）。

**Decision**：沿用三重判据，不重新推导：

| 条件 | 实测 |
|------|------|
| 索引驱动 | `PicLoadFile` 用 `local num = idxlen/4`（`lib_love.lua:437`） |
| 无固定计数 | `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全 `nil` |
| 字节全覆盖 | `format_spec --mod GodsDevils` → `checked=475 gaps=0` |

**Consequences**：
- 两次外推结果一致（125、129 均为内容差异、零引擎改动）→ 判据对第 3~5 梯队可信。
- 第 3 梯队起 hdgrp 跨度更大（173+），若出现 `gaps≠0` 才需要重新分析。

## ADR-002: 23 项「基准独有」= 6 在 save/ + 9 死文件 + 8 回退/播种

**Context**：粗分类（按「文件是否在产物」）得出「回退原版 14 + save 6 + 死文件 3」。
但其中 6 个 `d/s*.idx` 被误归为「回退原版」——**引擎从不引用它们**。

**Decision**：用引擎引用证据细化：

| 性质 | 判据 | 项（数） |
|------|------|---------|
| 在 save/ | 源自带且产物逐字节一致 | `d1/d2/r1/r2/s1/s2 .grp`（6） |
| 死文件 | 引擎无任何引用 | `alldef.idx`、`allsin.idx`（引擎只引用对应 `.grp`：`CC.D_Filename[0]`/`CC.S_Filename[0]`）；`allsinbk.grp`（引擎临时场景文件是 `data/allsinbk.grp`，非 save/ 副本）；**`d1/d2/d3.idx`、`s1/s2/s3.idx`**（引擎无 S/D idx 常量）（9） |
| 回退原版（含首次存档播种） | 引擎引用、源未自带；运行期生成或回退 `data/` | `r1.idx`、`r2.idx`、`r3.grp`、`r3.idx`、`s3.grp`、`d3.grp`（存档槽 1~3 首次保存生成）；`thing.grp`/`thing.idx`（`CC.ThingPicFile[1]=data/thing.idx` 回退原版）（8） |
| **Σ** | | **23** |

**关键源码证据**（`game/script/jyconst.lua:80-90`）：
```lua
--定义记录文件名。S和D由于是固定大小，因此不再定义idx了。
CC.R_IDXFilename={[0]=CONFIG.DataPath .. "ranger.idx", "save/r1.idx", "save/r2.idx", "save/r3.idx",};
CC.R_GRPFilename={[0]=CONFIG.DataPath .. "ranger.grp", "save/r1.grp", "save/r2.grp", "save/r3.grp",};
```
全仓库 `grep -rn "S_IDX\|D_IDX"` = 0 命中 → S/D 槽无 idx 文件存在。

**Alternatives**：
1. 沿用粗分类「回退原版 14」—— 掩盖「引擎根本不读」与「运行期播种」的本质区别，
   误导后续 MOD 的存档包分析。
2. 笼统写「均回退原版」—— 违反 Slice 2 起确立的负约束。

**Consequences**：
- 23 项全部有源码级或运行时证据，无未解释项。
- **可外推规则**：后续 MOD 的 `d/s*.idx` 一律判死文件（引擎无 S/D idx）。

## ADR-003: fight 92 == pascal 92 不作为内容证据

**Context**：GodsDevils 的 fight 数量与 pascal 基线相同（92），与 HeavenSword
（93）、lostbook（97）不同。

**Decision**：沿用 Slice 4 / Slice 5 负约束：**不得**以「记录数相同」证明 MOD 内容
已加载（无区分度）。MOD 内容已加载的证据改用非基线值：主角姓名（蝦米 vs 小蝦米）、
`Person[1]=胡斐`、`Person[2]=程靈素`、talk 4640、events 1123、hdgrp 129。

**Consequences**：报告中 fight 项显式标注「同数，无区分度」。

## ADR-004: 第 3 种存档形态（`r1.grp` 有、`r1.idx` 无）= 引擎守卫 + 播种

**Context**：前两种形态：源自带完整 `r1.grp`（多数 MOD）；HeavenSword 仅有
`r1.idx` 无 `r1.grp`。GodsDevils 是第 3 种：有 `r1.grp` 无 `r1.idx`。

**Decision**：行为判定（round-trip 实测，见 activate verification §3.9）：
1. **半状态读取**：`LoadRecord(1)`（`jymain.lua:1697-1701`）在 `rN.idx`/`rN.grp`/
   `sN.grp`/`dN.grp` 任一缺失时跳过加载（`return false`，不崩溃）——槽位表现为空。
2. **首次保存补全**：`SaveRecord(1)` 经 `ModData.SeedSaveSlot` 从 `ranger.idx`
   模板播种 `r1.idx`，随后正常写入 `r1.grp`/`r1.ovr`/`s1.grp`/`d1.grp`。
3. **补全后可读回**：`LoadRecord(1)` 成功，字符串覆盖表 round-trip 正确
   （改名「測試改名GD」回读一致）。

**Consequences**：
- 三种形态全部覆盖，存档隔离机制（Slice 1 决策 Q1/Q2）在全部形态下成立。
- 引擎守卫（缺文件跳过）是原有设计（注释：「存档文件不存在时，不做任何读取，
  避免崩溃」），无需改动。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**把 `hdgrp` 129 差异判定为结构异常（ADR-001）。
5. **不得**用「均回退原版」这类笼统表述（ADR-002）。
6. **不得**把 `d/s*.idx` 归为「回退原版」（它们是死文件，ADR-002）。
7. **不得**用「fight 92 == pascal 92」作为 MOD 内容已加载的证据（ADR-003）。

## Review Checklist

- [x] 13 项 MOD 独有全部有判定，需修复 = 0
- [x] 23 项基准独有全部定性（6 + 9 + 8，无未解释项）
- [x] `d/s*.idx` 6 项正确归为死文件（源码证据：无 S/D idx 常量）
- [x] `r1.idx`/`r2.idx` 归为「首次存档播种」（round-trip 佐证）
- [x] MOD 独有内容用非基线值证明（fight 同数已标注无区分度）
- [x] `hdgrp` 129 判定为内容差异（三重判据，第二次外推）
- [x] 第 3 种存档形态 round-trip 通过
- [x] 零引擎改动
- [x] 零回归
