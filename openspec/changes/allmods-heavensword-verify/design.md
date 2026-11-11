---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice5
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-heavensword-verify

## Context

HeavenSword 是本 epic **第一个 `hdgrp` 条目数不等于基线的 MOD**（125 vs 115）。
本 change 的核心问题是：**如何判定 `hdgrp` 差异为「内容差异」而非「结构异常」**，
且判据必须**可外推**到后续 14 个 hdgrp ≠ 115 的 MOD。

## ADR-001: `hdgrp` 差异判定 = 「索引驱动 + 无固定计数 + 字节全覆盖」

**Context**：第 2~5 梯队**全部** MOD 的 hdgrp ≠ 115。若每个 MOD 都要人工分析，
成本过高。需要一个可复用、机器可验证的判据。

**Decision**：三重判据：

| 条件 | 判据 | 工具 |
|------|------|------|
| **索引驱动** | `PicLoadFile` 用 `local num = idxlen/4` 推导条目数 | `lib_love.lua:437`（源码引用） |
| **无固定计数** | `CC` 中不存在 `HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` | 运行时检查（全部 `nil`） |
| **字节全覆盖** | `format_spec --mod HeavenSword` → `gaps=0` | `format_spec.lua` |

三条同时成立 → `hdgrp` 条目数差异**不改变记录布局**，为内容差异。

**Alternatives**：
1. 每个 MOD 单独人工分析 hdgrp 加载路径 —— 成本高、不可外推。
2. 与 pascal 逐字节 diff `hdgrp.idx` —— 会因内容不同而失败，无法区分内容与结构。
3. 只检查「文件大小不同」—— 无法证明引擎能正确处理。

**Consequences**：
- **判据可外推**：后续 MOD 只需跑 `format_spec` + 检查 `CC` 无固定计数常量。
- **零引擎改动**：无需为 hdgrp 差异新增 MOD 常量覆盖机制。

## ADR-002: 「基准独有」逐项定性，注意 `d1`/`s1` 不在 save/

**Context**：21 项「基准独有」。HeavenSword 与第 1 梯队不同：
**只有 `r1.idx` 在 save/**，`d1.grp`/`s1.grp` **不在**。

**Decision**：逐项用**文件系统事实 + 运行时 `CC.*` 值**定性：

| 性质 | 判据 | HeavenSword 项数 |
|------|------|----------------:|
| 回退原版 | `CC.*` 指向 `data/` | 19 |
| 在 save/ | `CC.*_Filename[1]` 指向 `mods/HeavenSword/save/` | 1（`r1.idx`） |
| 死文件 | 引擎无引用（`allsinbk.grp` 形参 0 引用） | 1 |
| **Σ** | | **21** |

**关键**：`d1.grp`/`s1.grp` 的 `CC.D_Filename[1]`/`CC.S_Filename[1]` 指向
`mods/HeavenSword/save/d1.grp`/`s1.grp`，但文件**不存在于产物**（源自带存档包不含它们）。
首次存档时会播种 —— 但 `diff.md` 仍将其列为「基准独有」（因为源无此文件）。
因此归为「回退原版（首次存档时播种）」。

**Alternatives**：
1. 笼统写「均回退原版」—— 掩盖「在 save/」与「死文件」的区别。

**Consequences**：
- 21 项无一未解释。
- 揭示 HeavenSword 与第 1 梯队的存档包差异。

## ADR-003: 内容差异的判定复用 Slice 4 的三重判据

**Context**：kdef 1066（vs 1018）、fight 93（vs 92）也是差异。

**Decision**：复用 Slice 4 ADR-001：

| 条件 | 实测 |
|------|------|
| 记录布局常量同 | `182`/`190`/`52`/`136` |
| 记录数同 | `320`/`200`/`84`/`93` |
| 字节全覆盖 | `gaps=0` |

**Consequences**：
- 与 Slice 4 判据一致，可比较。

## ADR-004: 缺陷 D 是「同源缺陷的第三次遗漏」

**Context**：Slice 2 修复了 `mod_check_one` 的 `r1.grp` 销毁；Slice 3 修复了
`test_mod_boot` 的 `r1.grp` 销毁。**两者都只覆盖 `r1.*`**。

**Decision**：确认缺陷 D（`d1.grp`/`s1.grp` 未备份）是**同一根因的第三次遗漏**：
`SaveRecord(1)` 写 `r1.*` **以及** `d1.grp`/`s1.grp`（`SaveMMap`/`SaveSMap`），
但 `SLOTS` 只列 `r1.*`。

修复 = 扩展 `SLOTS` 覆盖全部被写槽位。

**Alternatives**：
1. 只修 `mod_check_one` 的 `SLOTS` —— **已做**，但需同时检查 `test_mod_boot`
   （其 `SLOTS` 已含 `d1.grp`/`s1.grp`，故无此问题）。
2. 改用临时目录 —— `SaveDir()` 由 `ModData` 决定不易注入（Slice 2 已否决）。

**Consequences**：
- **教训**：修复「销毁产物」类缺陷时，必须枚举**全部**被写入的槽位，而非只修发现的那一个。
- 回归测试强化为「比对源 `save/` **全部**文件」，而非只比对 `r1.grp`。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**把 `hdgrp` 条目数差异判定为结构异常（ADR-001）。
5. **不得**用「均回退原版」这类笼统表述（ADR-002）。
6. **不得**用「记录数相同」作为 MOD 内容已加载的证据（无区分度）。

## Review Checklist

- [ ] 15 项 MOD 独有全部有判定
- [ ] 21 项基准独有全部定性（19 + 1 + 1，无未解释）
- [ ] `d1.grp`/`s1.grp` 正确归为「回退原版（首次存档时播种）」
- [ ] MOD 独有内容用非基线值证明
- [ ] `hdgrp` 125 判定为内容差异（三重判据）
- [ ] 缺陷 D 记录为「同源缺陷第三次遗漏」
- [ ] 零引擎改动
- [ ] 零回归
