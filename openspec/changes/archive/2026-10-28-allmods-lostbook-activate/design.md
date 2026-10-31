---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice4
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-lostbook-activate

## Context

lostbook 与 pascal **结构同形**（hdgrp/eft/warfld/cloud/title 尺寸一致），但**内容更多**：
kdef 1071（vs 1018）、fight 97（vs 92）、talk 3181（vs 2977）。

它是**第 1 梯队的最后一个**，且有一个前两个 MOD 没有的特征：**源 `save/` 无 `r1.grp`**。

## ADR-001: 内容差异（更多事件/战斗）是「同形」的一部分，不是异常

**Context**：lostbook 的 kdef 1071 vs pascal 1018、fight 97 vs 92。初看像「布局异常」。

**Decision**：确认这是**内容量差异**，非结构差异：
- kdef 条目数 = `kdef.idx` 的条目数（1071）—— MOD 自己的事件更多
- fight 数 = `fight/*.grp` 文件数（97）—— MOD 自己多 5 场战斗

两者都**不改变记录布局**（`CC.PersonSize` 等仍与 pascal 相同），因此**无需引擎改动**。

**判据**：`format_spec.lua --mod lostbook` 报 `gaps=0` —— 每个字节仍被具名字段覆盖。

**Alternatives**：
1. 把 kdef/fight 差异当作「需修复」—— 错误：这是 MOD 的正常内容。
2. 只比对文件大小 —— 会漏掉「条目数不同但每项尺寸相同」的情形。

**Consequences**：
- 记录数差异（320/200/84/93）与 pascal 相同（布局不变）。
- 条目数差异（kdef/fight/talk）被显式记录为内容差异。

## ADR-002: 存档播种是本 MOD 的核心验证点

**Context**：SweeOan/stronger 的源 `save/` **自带** `r1.grp`；lostbook **没有**
（只有 `d11/r11/s11` + `d1/s1`）。这正好覆盖「首次存档」路径。

**Decision**：显式验证：
1. `CC.R_GRPFilename[1] = mods/lostbook/save/r1.grp`（路径正确）
2. 存档前 `r1.grp` **不存在**
3. `SaveRecord(1)` 后 `r1.grp`/`r1.idx`/`r1.ovr` **存在**（从 `ranger.idx` 播种）
4. 字符串改写写入 `r1.ovr`，读档时覆盖表优先
5. 验证后恢复至原始状态（无残留）

**Alternatives**：
1. 只验证启动链路 —— 会漏掉播种路径（前两个 MOD 因自带 `r1.grp` 未覆盖此路径）。

**Consequences**：
- 覆盖了 MOD 存档隔离的「首次存档」分支。
- 与 `test_mod_boot.testSaveLoadRoundTripWithMingdong` 互补。

## ADR-003: 测试写产物 `save/` 必须备份+恢复（沿用 Slice 3 教训）

**Context**：Slice 2/3 发现 `mod_check_one.lua` 与 `test_mod_boot.lua` 都会销毁产物存档。
lostbook 的 `d1.grp`/`s1.grp` 是**源自带**的，同样有被销毁风险。

**Decision**：任何写入 `mods/lostbook/save/` 的验证都必须：
1. 先备份既有槽文件
2. 验证
3. 字节级恢复

**Alternatives**：
1. 直接写 —— 会销毁 lostbook 的 `d1.grp`/`s1.grp`（重蹈 Slice 2/3 覆辙）。

**Consequences**：
- 验证后 `save/` 与源逐字节一致。
- `test_mod_boot.testProductSavesNotDestroyedByTests` 已提供全 MOD 防护网。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**因「内容更多」而判定结构异常（ADR-001）。
5. **不得**在验证中破坏 lostbook 的 `save/d1.grp`/`s1.grp`（ADR-003）。

## Review Checklist

- [ ] 构建退出码 0，`events=1071`
- [ ] `mod_audit --mod lostbook` `unclassified=0`
- [ ] 「必需但未进产物」矛盾 = 0
- [ ] `format_spec --mod lostbook` `gaps=0`
- [ ] 确认 kdef 1071 / fight 97 为内容差异
- [ ] `boot_one_mod` `RESULT lostbook: OK`
- [ ] 存档播种验证通过且无残留
- [ ] 零引擎改动
- [ ] 零回归
