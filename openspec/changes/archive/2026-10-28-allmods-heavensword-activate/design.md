---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice5
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-heavensword-activate

## Context

HeavenSword 是本 epic **第 2 梯队的第一个**，也是**第一个 `hdgrp` 条目数不等于基线的 MOD**
（125 vs 115）。第 1 梯队的 3 个 MOD 全部 hdgrp=115，因此本 change 的核心风险是：
**`hdgrp` 条目数变化是否引入引擎侧的固定计数依赖？**

## ADR-001: `hdgrp` 为索引驱动加载，无固定计数依赖

**Context**：`hdgrp.idx` 是 4 字节小端 uint32 offset 数组。pascal 115 条，HeavenSword 125 条。
若引擎在代码里硬编码「115 个头像」，则 125 条会越界或截断。

**Decision**：验证引擎为**索引驱动**：

1. 运行时检查 `CC` 中**不存在** `HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum`
   等固定计数常量（实测全部 `nil`）。
2. `CC.HeadPicFile[1] = mods/HeavenSword/data/hdgrp.idx` —— 路径指向 MOD 产物。
3. `hdgrp.idx` 实际大小 = 500 字节 = 125 × 4，条目数由文件大小推导。
4. `format_spec --mod HeavenSword` 报 `gaps=0` —— 每个字节被具名字段覆盖（含 tail）。

**Alternatives**：
1. 若引擎硬编码 115 → 需新增 MOD 常量覆盖机制（`CC.*Size` 类）。**实测不需要**。
2. 只比对文件大小 → 会漏掉「条目数不同但每项尺寸相同」的情形。

**Consequences**：
- **零引擎改动**：hdgrp 差异无需代码修改。
- 结论可外推到后续 hdgrp 不同的 MOD（第 2~5 梯队全部 hdgrp ≠ 115）。

## ADR-002: `hdgrp` 差异判定为「内容差异」，判据与 Slice 4 一致

**Context**：需要机器可验证的判据区分「内容差异」与「结构异常」。

**Decision**：沿用 Slice 4 ADR-001 的三重判据：

| 条件 | 判据 |
|------|------|
| 记录布局常量不变 | `CC.PersonSize=182`/`ThingSize=190`/`SceneSize=52`/`WugongSize=136` |
| 记录数不变 | 320/200/84/93 |
| 字节全覆盖 | `format_spec --mod HeavenSword` → `gaps=0` |

`hdgrp.idx` 的条目数变化不改变**每项尺寸**（每项 4 字节 offset），故为内容差异。

**Alternatives**：
1. 人工目视 —— 不可机器验证。
2. 与 pascal 逐字节 diff —— 会因内容不同而失败，无法区分「内容」与「结构」。

**Consequences**：
- 后续所有 hdgrp ≠ 115 的 MOD 可复用此判据。

## ADR-003: 存档验证需处理「有 `r1.idx` 无 `r1.grp`」的半初始化槽位

**Context**：HeavenSword 源 `save/` 含 `r1.idx`（24 字节）但**无** `r1.grp`。
实测 `r1.idx` 与 `ranger.idx` **md5 相同**（`3746f89bd755157160d7bc9575d8e2e4`）——
即它是模板索引的副本。

**Decision**：验证以下行为：
1. `CC.R_GRPFilename[1] = mods/HeavenSword/save/r1.grp`（路径正确）
2. 存档前 `r1.grp` **不存在**，`r1.idx` **存在**（源提供）
3. `SaveRecord(1)` 后 `r1.grp`/`r1.ovr` **存在**（`r1.idx` 保留）
4. `LoadRecord(1)` 回读正确
5. 验证后恢复至原始状态（`r1.grp` 删除，`r1.idx` 复原）

**Alternatives**：
1. 只验证 `r1.grp` 播种 —— 会漏掉「源已有 `r1.idx`」这一情形。

**Consequences**：
- 覆盖了 MOD 存档隔离的第三种形态（前两种：源自带 `r1.grp`；源无任何 `r1.*`）。

## ADR-004: 测试写产物 `save/` 必须备份+恢复

**Context**：Slice 2/3 发现 `mod_check_one.lua` 与 `test_mod_boot.lua` 会销毁产物存档。
HeavenSword 的 `r1.idx` 是**源自带**的，有被销毁风险。

**Decision**：任何写入 `mods/HeavenSword/save/` 的验证都必须：备份 → 验证 → 字节级恢复。

**Alternatives**：
1. 直接写 —— 会销毁源自带的 `r1.idx`（重蹈 Slice 2/3 覆辙）。

**Consequences**：
- 验证后 `save/` 与源逐字节一致。
- `test_mod_boot.testProductSavesNotDestroyedByTests` 提供全 MOD 防护网。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**因 `hdgrp` 条目数不同而判定结构异常（ADR-001/002）。
5. **不得**在验证中破坏 HeavenSword 的 `save/r1.idx`（ADR-004）。
6. **不得**用「记录数相同」作为 MOD 内容已加载的证据（记录数 320/200/84/93 与 pascal 相同，无区分度）。

## Review Checklist

- [ ] 构建退出码 0，`events=1066`
- [ ] `mod_audit --mod HeavenSword` `unclassified=0`
- [ ] 「必需但未进产物」矛盾 = 0
- [ ] `format_spec --mod HeavenSword` `gaps=0`
- [ ] `hdgrp.idx` = 125 条目，无固定计数常量
- [ ] `boot_one_mod` `RESULT HeavenSword: OK`
- [ ] 存档验证通过（`r1.idx` 保留 + `r1.grp` 播种 + 无残留）
- [ ] 零引擎改动
- [ ] 零回归
