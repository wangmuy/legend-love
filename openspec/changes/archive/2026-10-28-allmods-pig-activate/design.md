---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice7
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-pig-activate

## Context

pig 是**第 3 梯队第 1 个**，hdgrp 173（vs 115），kdef 1288（vs 1018），
**fight 137（vs 92，+45）**，talk 4123（vs 2977）。含 9 个源自带存档。

## ADR-001: `hdgrp` 173 差异 —— 判据第 3 次应用

**Context**：Slice 5 建立判据，Slice 6 首次外推成功（2 个 MOD 一致）。
本 change 是**第 3 次应用**，覆盖更大的 hdgrp（173 vs 125/129）。

**Decision**：直接应用判据，不重新推导：

| 条件 | 判据 | 实测 |
|------|------|------|
| 索引驱动 | `PicLoadFile` 用 `idxlen/4` | `lib_love.lua:437` |
| 无固定计数 | `CC` 中无 `HDGRPNum` 等 | 全 `nil` |
| 字节全覆盖 | `format_spec --mod pig` | `gaps=0` |

`hdgrp.idx` = 692 字节 = 173 × 4 ✅

**Alternatives**：
1. 因 hdgrp 更大而怀疑判据失效 —— 判据只依赖「索引驱动」，与条目数无关。

**Consequences**：
- **判据第 3 次应用成功**（3 个 MOD，hdgrp 125/129/173，结论一致）。
- 第 4~5 梯队（hdgrp 250~696）可继续复用。

## ADR-002: 45 场额外战斗 = 三重确认

**Context**：pig 有 137 场战斗（pascal 92），**+45**。这是本 epic 目前最多。
需证明这 45 场确实来自 MOD，且引擎能加载。

**Decision**：每场战斗**三重确认**：

| # | 证据 | 方式 | 期望 |
|---|------|------|------|
| 1 | `diff.md` 提及 | `grep -c "fightNNN" mods/pig/diff.md` | 2（`+` 与 `-` 各一次，或仅 `+`） |
| 2 | 产物存在 | `ls mods/pig/data/fightNNN.grp` | 存在 |
| 3 | 审计归类 | `mod_audit.classify` | `REQUIRED` + `in_product=true` |

**抽样验证 5 场**（`030`/`039`/`137`/`145`/`170`，覆盖列表首/中/尾）：
全部 `diff提及=2 产物=yes 审计=REQUIRED true` ✅

**产物总数**：`ls mods/pig/data/fight*.grp | wc -l` = **137** ✅（92 + 45）

**Alternatives**：
1. 只统计产物数量 —— 无法证明差异来源（可能是重命名或覆盖）。
2. 只信 `diff.md` —— 无法证明产物实际存在。

**Consequences**：
- 45 场额外战斗有**三重独立证据**。
- 验证了引擎的 `fightNNN` **索引驱动**加载（无需固定数量常量）。

## ADR-003: 9 个源自带存档 —— 缺陷 D 修复的更强检验

**Context**：Slice 5 修复 `mod_check_one` 的 `SLOTS` 遗漏 `d1`/`s1`；
Slice 6 用 6 个源自带存档验证了持久性。pig 有 **9 个**（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`），
且**含 `d2`/`d3`/`r2`/`r3`/`s2`/`s3`** —— 若修复不完整（如只补 `d1`/`s1`），本 MOD 会暴露。

**Decision**：验证：
1. 产物 21 个 save 文件与源逐字节一致
2. 运行 `mod_check` 后仍一致
3. 全量测试后仍一致

**Alternatives**：
1. 只验证 `d1`/`s1` —— 无法检验 `d2`/`d3`/`s2`/`s3`。

**Consequences**：
- 缺陷 D 修复的**完整性**被 9 槽检验。
- 验证后 21 个文件与源一致。

## ADR-004: 测试写产物 `save/` 必须备份+恢复

**Context**：沿用 Slice 2/3/5/6 教训。

**Decision**：任何写入 `mods/pig/save/` 的验证都必须：备份 → 验证 → 字节级恢复。

**Consequences**：
- 验证后 `save/` 与源逐字节一致。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**把 `hdgrp` 173 差异判定为结构异常（ADR-001）。
5. **不得**只统计产物数量就断言 45 场额外战斗（ADR-002 要求三重确认）。
6. **不得**在验证中破坏 pig 的 9 个源自带存档（ADR-004）。
7. **不得**用「记录数相同」作为 MOD 内容已加载的证据（本 MOD fight 数**不同**，
   但仍需用非基线值证明其他内容）。

## Review Checklist

- [ ] 构建退出码 0，`events=1288`
- [ ] `mod_audit --mod pig` `unclassified=0`
- [ ] 「必需但未进产物」矛盾 = 0
- [ ] `format_spec --mod pig` `gaps=0`
- [ ] `hdgrp.idx` = 173 条目（692 字节）
- [ ] 45 场额外战斗三重确认
- [ ] 产物 `fight*.grp` = 137
- [ ] `boot_one_mod` `RESULT pig: OK`
- [ ] 21 个存档文件与源一致（含 `mod_check` 与全量测试后）
- [ ] 零引擎改动
- [ ] 零回归
