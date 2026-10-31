---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice3
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-stronger-activate

## Context

stronger 与 pascal 基线**结构完全同形**（hdgrp/eft/warfld/cloud/title/kdef 尺寸一致，fight 92）。
唯一差异是 `talk.grp` 条目数（3727 vs 2977）。

这与 Slice 2（SweeOan）的情形**几乎相同**。Slice 2 的教训是：**同形不等于零问题**
（SweeOan 暴露了 `mod_check_one.lua` 的 `save/` 数据销毁缺陷）。

## ADR-001: 复用 Slice 2 的 6 步验证模板，不因「同形」而简化

**Context**：stronger 与基线同形，直觉上「肯定没问题」。但 Slice 2 证明同形 MOD 也能暴露缺陷。

**Decision**：完整执行 6 步（构建 → 穷举 → 字节级 → 产物检查 → 启动链路 → diff 审计），
**不跳过任何一步**。

**Alternatives**：
1. 只跑构建 + 启动链路 —— 快，但会漏掉 `save/` 类问题（正是 Slice 2 的盲区）。
2. 只跑 `diff.md` —— `diff.md` 只比对 `data/`，看不到 `save/`、`script/`、`sound/`。

**Consequences**：
- 每 MOD 耗时约 2-3 分钟（构建 + 5 项检查）。
- 换取「每个源文件都被检查」的确定性。

## ADR-002: 产物 `save/` 完整性作为显式检查项

**Context**：Slice 2 发现 `mod_check_one.lua` 会删除产物 `r1.grp`。虽然已修复，
但**修复本身也需要在每个 MOD 上验证**。

**Decision**：本 change 显式检查「产物 `save/r1.grp` 与源文件逐字节相同」（若源提供该文件）。

**Alternatives**：
1. 信任 Slice 2 的修复 —— 但修复的回归测试只覆盖当时存在的 MOD，新 MOD 可能有新情形。

**Consequences**：
- 每个 MOD 都验证 `save/` 未被破坏。
- 新增 stronger 的 `save/` 证据。

## ADR-003: MOD 独有内容用非基线值证明

**Context**：资源路径指向 MOD 目录**不充分** —— 引擎可能读取后回退。

**Decision**：用有**区分度**的判据：
- 主角姓名 = 韋大寶（pascal = 小蝦米）
- `JY.Person[1]` = 胡斐（pascal 不同）
- `JY.Person[2]` = 程靈素（pascal 不同）

**Alternatives**：
1. 只用记录数（320/200/84/93）—— 与 pascal 相同，**无区分度**。
2. 只用路径前缀 —— 无法排除读取后回退。

**Consequences**：
- 需要知道 pascal 的对应值。
- 判据有区分度，能真正证明「来自 MOD」。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**因「同形」而跳过任一步骤（ADR-001）。
5. **不得**用「记录数与基线相同」作为 MOD 内容已加载的证据（ADR-003）。

## Review Checklist

- [ ] 构建退出码 0，产物目录完整
- [ ] `mod_audit --mod stronger` `unclassified=0`
- [ ] 「必需但未进产物」矛盾 = 0
- [ ] `format_spec --mod stronger` `gaps=0`
- [ ] 产物 `save/r1.grp` 与源逐字节相同
- [ ] `boot_one_mod` `RESULT stronger: OK`
- [ ] MOD 独有内容用非基线值证明
- [ ] 零引擎改动
- [ ] 零回归
