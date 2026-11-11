---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice4
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-lostbook-verify

## Context

lostbook 与 pascal 结构同形，但内容更多（kdef 1071、fight 97、talk 3181）。
本 change 的核心问题是：**如何区分「内容差异」与「结构异常」**。

## ADR-001: 内容差异的判定标准 = 「每项尺寸不变 + 字节全覆盖」

**Context**：lostbook 的 kdef 条目数 1071（pascal 1018）、fight 97（pascal 92）。
初看像「布局异常」，但需要机器可验证的判据。

**Decision**：用两个条件判定为**内容差异**：

| 条件 | 判据 | 工具 |
|------|------|------|
| 每项尺寸不变 | 记录布局常量与 pascal 相同（`CC.PersonSize=182` 等） | `boot_one_mod` |
| 字节全覆盖 | `format_spec --mod lostbook` → `gaps=0` | `format_spec` |

若为结构异常（如记录尺寸不同），`format_spec` 会报 `gaps > 0`（因为按 pascal 尺寸解析会错位）。

**Alternatives**：
1. 只比对文件大小 —— 会漏掉「条目数不同但每项尺寸相同」的情形。
2. 人工目视 —— 不可机器验证。

**Consequences**：
- 内容差异有机器可验证的判据。
- `gaps=0` 成为「结构未变」的强证据。

## ADR-002: 额外战斗文件必须被确认在产物中

**Context**：lostbook 比 pascal 多 5 场战斗（`fight039`~`042`、`fight052`）。

**Decision**：确认这 5 对文件（`.grp`+`.idx`）：
1. 出现在 `diff.md` 的「MOD 独有」
2. 存在于产物 `game/mods/lostbook/data/`
3. 被 `mod_audit` 归为 `REQUIRED`

**Alternatives**：
1. 只看 `diff.md` —— 无法确认是否真的进产物。

**Consequences**：
- 额外战斗被三重确认（diff + 产物 + 审计）。

## ADR-003: 「基准独有」逐项定性，不用笼统表述

**Context**：21 项「基准独有」混杂三种性质。

**Decision**：逐项用**运行时 `CC.*` 值**定性：

| 性质 | 判据 |
|------|------|
| 回退原版 | `CC.*` 指向 `data/` |
| 在 save/ | `CC.*_Filename[1]` 指向 `mods/lostbook/save/` |
| 死文件 | 引擎无引用（`allsinbk.grp` 形参 0 引用） |

**Alternatives**：
1. 笼统写「均回退原版」—— 掩盖「在 save/」与「死文件」的区别。

**Consequences**：
- 21 项无一未解释。

## ADR-004: 存档播种是「在 save/」类别的特殊子情形

**Context**：lostbook 源无 `r1.grp`，但 `CC.R_GRPFilename[1] = mods/lostbook/save/r1.grp`。
`diff.md` 把 `r1.grp` 列为「基准独有」（pascal 有、lostbook 无）。

**Decision**：判定为「**在 save/**（首次存档时播种）」——
路径指向 MOD 的 save 目录，文件在首次 `SaveRecord(1)` 时从 `ranger.idx` 生成。

**Alternatives**：
1. 归为「回退原版」—— 错误：`CC.R_GRPFilename[1]` 明确指向 MOD save 目录，不会回退。
2. 归为「死文件」—— 错误：它是可写的活跃槽位。

**Consequences**：
- 「在 save/」细分为「源自带」与「首次播种」两种。
- 播种路径已由 `allmods-lostbook-activate` REQ-LOST-5 验证。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**把内容差异（更多事件/战斗）判定为结构异常（ADR-001）。
5. **不得**用「均回退原版」这类笼统表述（ADR-003）。
6. **不得**把播种槽 `r1.grp` 归为「回退原版」或「死文件」（ADR-004）。

## Review Checklist

- [ ] 24 项 MOD 独有全部有判定
- [ ] 21 项基准独有全部定性（无未解释）
- [ ] MOD 独有内容用非基线值证明
- [ ] kdef 1071 / fight 97 判定为内容差异（`gaps=0` 佐证）
- [ ] 5 场额外战斗三重确认
- [ ] `r1.grp` 归为「在 save/（首次播种）」
- [ ] 零引擎改动
- [ ] 零回归
