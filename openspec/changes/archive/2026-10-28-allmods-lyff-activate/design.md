---
status: active
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice8
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-lyff-activate

## Context

lyff 是本 epic **首个记录数与基线不同的 MOD**：源模板 `ranger.grp` 人物段含
**326** 条记录（pascal 320）。此前 7 个已完成 MOD 的记录数全部为 320/200/84/93，
「记录数差异」这一维度尚未被验证。

## ADR-001: 记录数差异 = 内容差异（索引驱动，零引擎改动）

**Context**：`LoadRecord` 的各段记录数全部由 `ranger.idx` 的分段偏移动态推导：
```lua
JY.PersonNum = math.floor((idx[2]-idx[1])/CC.PersonSize)   -- jymain.lua:1747
JY.ThingNum  = math.floor((idx[3]-idx[2])/CC.ThingSize)
JY.SceneNum  = math.floor((idx[4]-idx[3])/CC.SceneSize)
JY.WugongNum = math.floor((idx[5]-idx[4])/CC.WugongSize)
JY.ShopNum   = math.floor((idx[6]-idx[5])/CC.ShopSize)
```
无任何固定计数常量（与 `hdgrp` 的 `idxlen/4` 同理）。lyff 的 326 由
`idx[2]-idx[1] = 59332 = 326 × 182` 推导。

**Decision**：复用 Slice 5 三重判据的思路（索引驱动 + 无固定计数 + 字节全覆盖），
针对记录段补充**边界记录验证**：
1. `mod_check_one` 报 `PERSON=326`（构建期按 idx 推导）；
2. 启动链路 `PersonNum=326`（运行期按 idx 推导）；
3. **边界记录 `Person[325]`（第 326 条）为有效数据**（姓名/外号可读、无乱码）——
   证明整段 326 条都被正确解析，而非只解析前 320 条；
4. `format_spec --mod lyff` → `gaps=0`（字节级全覆盖含 326 条人物段）。

**Alternatives**：
1. 硬编码支持 326 —— 引入固定计数，违反「索引驱动」原则，且下一个 MOD 可能又是别的数。
2. 截断到 320 —— 丢弃 MOD 内容，不可接受。

**Consequences**：
- **记录数差异无需引擎改动** —— 此结论与 `hdgrp` 条目数差异同理，
  可外推到后续所有记录数 ≠ 基线的 MOD。
- 边界记录验证成为记录数差异 MOD 的标准验证项。

## ADR-002: `hdgrp` 178 差异 = 判据第 4 次应用

**Context**：Slice 5 建立判据（HeavenSword 125 首次）→ Slice 6（GodsDevils 129）
→ Slice 7（pig 173）。lyff 178 为第 4 次应用。

**Decision**：直接应用三重判据（索引驱动 `idxlen/4` + 无固定计数 + `gaps=0`），
不重新推导。

**Consequences**：第 3 梯队收尾（173/178/204）+ 第 4~5 梯队（252~696）可继续复用；
`books`（696）是跨度最大的压力测试。

## ADR-003: 46 场额外战斗 = 动态数量支持

**Context**：lyff 有 138 场战斗（92 + 46），超出 pig 的 137（92 + 45），
成为本 epic **额外战斗最多的 MOD**。

**Decision**：复用 Slice 7 的三重确认：
1. `diff.md` 逐项列出 46 场（`fight030`/`fight039`/`fight040`/`fight110`/`fight115`~`121`/
   `fight125`/`fight126`/`fight128`~`131`/`fight133`~`146`/`fight152`~`162`/`fight167`/
   `fight169`/`fight170`/`fight173`，各 `.grp`+`.idx`）；
2. 产物 `data/fight*.grp` = 138；
3. 审计归类 `REQUIRED` + `in_product=true`。

**Consequences**：战斗文件数为动态（`diff.md` 驱动），引擎按文件名引用，
无固定数量依赖。

## ADR-004: 存档 = 第 3 种形态（Slice 6 已验证机制）

**Context**：lyff 源自带 `save/` 10 个文件（`alldef.grp`/`allsin.grp`/`d11`/`d1`/
`r11`/`r1`/`ranger.grp`/`ranger.idx`/`s11`/`s1`）—— 与 GodsDevils 同为
**`r1.grp` 有、`r1.idx` 无**（第 3 种形态），但只带 3 个槽文件（`d1`/`r1`/`s1`）。

**Decision**：复用 Slice 6 验证过的机制：
1. 半状态 `LoadRecord(1)` 由 `jymain.lua:1697-1701` 守卫优雅跳过（不崩溃）；
2. 首次 `SaveRecord(1)` 经 `ModData.SeedSaveSlot` 播种 `r1.idx` 补全槽位；
3. 验证只确认 3 个源自带文件（`d1`/`r1`/`s1`）在构建/测试后逐字节一致
   （机制级 round-trip 已由 Slice 6 在 GodsDevils 上完成，本 MOD 不重复）。

**Consequences**：存档验证聚焦于「构建 + 全量测试不破坏源自带存档」。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**把 326 人物段判定为结构异常（ADR-001）。
5. **不得**硬编码任何记录数（326 必须从 idx 推导）。
6. **不得**把 `hdgrp` 178 差异判定为结构异常（ADR-002）。
7. **不得**用「记录数相同」作为 MOD 内容已加载的证据（Thing/Scene/Wugong 仍为 200/84/93，与基线同数）。

## Review Checklist

- [ ] 构建退出码 0，`events=1358 talk=5655`
- [ ] `mod_audit --mod lyff` `unclassified=0`
- [ ] 「必需但未进产物」矛盾 = 0
- [ ] `format_spec --mod lyff` `gaps=0`
- [ ] `PERSON=326`（mod_check_one + 启动链路）
- [ ] 边界记录 `Person[325]` 有效
- [ ] `hdgrp.idx` = 178 条目，内容差异
- [ ] 产物 fight = 138（92 + 46）
- [ ] 3 个源自带存档与源一致（含全量测试后）
- [ ] 零引擎改动
- [ ] 零回归
