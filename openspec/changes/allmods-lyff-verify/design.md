---
status: active
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice8
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-lyff-verify

## Context

lyff 是**首个记录数与基线不同的 MOD**（人物段 326 vs 320）。本 change 的核心
问题是：**记录数差异的判定是否与 `hdgrp` 条目数差异同理**（索引驱动 → 内容差异、
零引擎改动），且判定必须机器可验证、可外推到后续记录数不同的 MOD
（第 4~5 梯队可能有更多）。

## ADR-001: 记录数差异 = 内容差异（动态推导 + 边界验证）

**Context**：`LoadRecord` 的各段记录数全部由 `ranger.idx` 分段偏移动态推导
（`jymain.lua:1747-1818`），无任何固定计数常量。lyff 人物段
`idx[2]-idx[1] = 59332 = 326 × 182`（pascal 320 × 182 = 58240）。

**Decision**：记录数差异的判定判据（4 条，全部机器可验证）：

| # | 条件 | 判据 | 工具/证据 |
|---|------|------|----------|
| 1 | 动态推导 | `PersonNum = (idx[2]-idx[1])/CC.PersonSize` | `jymain.lua:1747`（源码引用） |
| 2 | 无固定计数 | 不存在 `PERSON_NUM` 等固定计数常量 | 全仓库 grep |
| 3 | 边界记录有效 | `Person[325]`（第 326 条）姓名/外号可读 | 独立进程运行时检查 |
| 4 | 字节全覆盖 | `format_spec --mod lyff` → `gaps=0` | `format_spec.lua` |

四条同时成立 → 记录数差异**不改变记录布局**，为内容差异，零引擎改动。

**与 `hdgrp` 判据的关系**：`hdgrp`（`PicLoadFile` 用 `idxlen/4`）与记录段
（`idx[2]-idx[1]`）同属「索引驱动」——**条目数/记录数由索引文件大小或分段偏移
推导，无固定常量**。两个判据可统一为一条原则：**索引驱动 + 无固定计数 +
字节全覆盖 + 边界有效 = 内容差异**。

**Alternatives**：
1. 为记录数硬编码适配 —— 引入固定计数，下一 MOD 又是别的数，不可持续。
2. 只验证 `PersonNum=326` 不验证边界 —— 可能漏掉「只解析前 320 条」类缺陷
   （如 idx 错位导致后 6 条读越界数据）。

**Consequences**：
- **记录数差异无需引擎改动**，判定可外推到后续所有记录数 ≠ 基线的 MOD。
- 边界记录验证成为记录数差异 MOD 的标准验证项。

## ADR-002: `hdgrp` 178 = 判据第 4 次应用

**Context**：外推链 HeavenSword（125）→ GodsDevils（129）→ pig（173）→
**lyff（178）**。

**Decision**：沿用三重判据，不重新推导。

**Consequences**：第 4 次一致 → 第 4 梯队（252/267/300）与第 5 梯队（books 696）
可继续复用。

## ADR-003: 23 项「基准独有」沿用 Slice 6 细化规则

**Context**：lyff 的 23 项基准独有与 GodsDevils **完全同集合**
（`alldef.idx`/`allsin.idx`/`allsinbk.grp` + `d1/d2/d3`/`r1/r2/r3`/`s1/s2/s3` 的
`grp`+`idx` + `thing.grp`/`thing.idx`），但 lyff 源自带槽文件只有 3 个
（`d1`/`r1`/`s1`，GodsDevils 是 6 个）。

**Decision**：沿用 Slice 6 的 6/9/8 规则，按 lyff 实际源自带调整：

| 性质 | 项数 | 项 |
|------|-----:|----|
| 在 save/（源自带） | 3 | `d1.grp`、`r1.grp`、`s1.grp` |
| 死文件（引擎无引用） | 9 | `alldef.idx`、`allsin.idx`、`allsinbk.grp` + `d1/d2/d3.idx`、`s1/s2/s3.idx` |
| 回退原版（含首次播种） | 11 | `d2.grp`、`d3.grp`、`r1.idx`、`r2.grp`、`r2.idx`、`r3.grp`、`r3.idx`、`s2.grp`、`s3.grp`、`thing.grp`、`thing.idx` |
| **Σ** | **23** | |

**Consequences**：规则可复用于后续全部 MOD（仅需按源自带槽文件数调整第一类）。

## ADR-004: 105 项 MOD 独有 = 46 场战斗 + 13 项标准资源

**Context**：lyff 的 MOD 独有项达 105（本 epic 最多；pig 为 103 = 45×2 + 13）。

**Decision**：46 场额外战斗复用 Slice 7 三重确认（`diff.md` 列出 + 产物 138 +
审计 `REQUIRED`）；13 项标准资源（`cloud`/`dead.png`/`end.png`/`kdef`/`kysmod.ini`/
`open.png`/`ranger.str`/`talk`/`title`）与前序 slice 同判定。

**Consequences**：46 场战斗为**本 epic 额外战斗最多**（超过 pig 的 45）。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**把 326 人物段判定为结构异常（ADR-001）。
5. **不得**把 `hdgrp` 178 差异判定为结构异常（ADR-002）。
6. **不得**用「均回退原版」这类笼统表述（ADR-003）。
7. **不得**把 `d/s*.idx` 归为「回退原版」（它们是死文件）。
8. **不得**用「Thing/Scene/Wugong 数相同」作为 MOD 内容已加载的证据（与基线同数，无区分度）。

## Review Checklist

- [x] 105 项 MOD 独有全部有判定，需修复 = 0
- [x] 23 项基准独有全部定性（3 + 9 + 11，无未解释项）
- [x] 326 人物段判定为内容差异（4 条判据）
- [x] 边界记录 `Person[325]` 有效
- [x] MOD 独有内容用非基线值证明（Thing/Scene/Wugong 同数已标注无区分度）
- [x] `hdgrp` 178 判定为内容差异（判据第 4 次应用）
- [x] 46 场额外战斗三重确认
- [x] 零引擎改动
- [x] 零回归
