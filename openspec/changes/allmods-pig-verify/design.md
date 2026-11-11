---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice7
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-pig-verify

## Context

pig 是第 3 梯队第 1 个，含 45 场额外战斗与 9 个源自带存档。
本 change 复核 activate 的机器验证结果，做人工可复核的内容审计。

## ADR-001: 额外战斗的判定 = 「索引驱动 + 三重证据」

**Context**：pig 有 137 场战斗（pascal 92，**+45**）。需判定这是内容差异而非结构异常，
且需证明 45 场确实来自 MOD。

**Decision**：判据分两层：

**层 1：内容差异 vs 结构异常**（复用 Slice 5 判据，扩展到 fight）

| 条件 | 实测 |
|------|------|
| 索引驱动 | `fightNNN.grp` 由脚本按编号引用（无固定数量常量） |
| 记录布局常量同 | `182`/`190`/`52`/`136` |
| 字节全覆盖 | `gaps=0` |
| `fight*.idx` 一致性 | `format_spec` 的 `verifyPair` 通过 |

**层 2：45 场来自 MOD 的三重证据**

| # | 证据 | 方式 |
|---|------|------|
| 1 | `diff.md` 提及 | 45 项，各 ≥1 次 |
| 2 | 产物存在 | 137 个 `fight*.grp` |
| 3 | 审计归类 | `REQUIRED` + `in_product=true` |

**Alternatives**：
1. 只判「内容差异」不证明来源 —— 无法排除「重命名/覆盖」。
2. 只统计数量 —— 无法证明每场都可用。

**Consequences**：
- 45 场额外战斗有**三重独立证据**。
- 判据可外推到后续 MOD（lyff 138、ptt 162、RiverLake 219 等）。

## ADR-002: 「基准独有」逐项定性，注意 9 个源自带存档

**Context**：21 项「基准独有」。pig 源自带 **9 个**存档槽
（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`），比第 2 梯队（3~6 个）更多。

**Decision**：逐项定性：

| 性质 | 判据 | pig 项数 |
|------|------|---------:|
| 回退原版 | `CC.*` 指向 `data/` | 11 |
| 在 save/ | 文件存在于 `mods/pig/save/` | 9 |
| 死文件 | 引擎无引用 | 1（`allsinbk.grp`） |
| **Σ** | | **21** |

**Alternatives**：
1. 笼统写「均回退原版」—— 掩盖区别（违反负约束）。

**Consequences**：
- 21 项无一未解释。

## ADR-003: 103 项 MOD 独有的分类

**Context**：pig 的 MOD 独有项达 **103 项**（本 epic 目前最多）。

**Decision**：按类别分解：

| 类别 | 项数 |
|------|-----:|
| 额外战斗（`fightNNN.grp`/`.idx`） | 90（45 场 × 2） |
| `kdef.grp`/`.idx` | 2 |
| `talk.grp`/`.idx` | 2 |
| `cloud.grp`/`.idx` | 2 |
| `title.grp`/`.idx` | 2 |
| `dead.png`/`end.png`/`open.png` | 3 |
| `ranger.str` | 1 |
| `kysmod.ini` | 1（`BUILD_INPUT`） |
| **Σ** | **103** |

**Alternatives**：
1. 逐条列出 103 项 —— 冗长；按类别分解更清晰。

**Consequences**：
- 103 项全部有判定，**需修复 = 0**。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**把 `hdgrp` 173 / fight 137 差异判定为结构异常。
5. **不得**用「均回退原版」这类笼统表述。
6. **不得**只统计数量就断言 45 场额外战斗（ADR-001 要求三重证据）。
7. **不得**用「记录数相同」作为 MOD 内容已加载的证据。

## Review Checklist

- [ ] 103 项 MOD 独有全部有判定（按类别分解）
- [ ] 21 项基准独有全部定性（11 + 9 + 1，无未解释）
- [ ] MOD 独有内容用非基线值证明
- [ ] `hdgrp` 173 / fight 137 判定为内容差异 + 记录判据第 3 次应用
- [ ] 45 场额外战斗三重证据复核
- [ ] 零引擎改动
- [ ] 零回归
