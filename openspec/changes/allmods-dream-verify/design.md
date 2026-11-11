---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
---
# Design: allmods-dream-verify

> Slice 14 子 change 2/2 的审计设计。每个关键判断记作 ADR。

## ADR-DRMV-001 fight 必须从「四象限」升级为「五分类」

**Context**

epic 前 13 个 MOD 的 fight 分析一直用四象限（A 同名同容 / B 同名异容 /
C MOD 独有 / D 零字节），并用

```
A + B     = 基线组数
A + B + C = MOD 组数
```

作自洽校验。books 与 pineapple 都满足（前者 `89+3=92`，后者 `2+90=92`）。

dream 实测：

```
A = 2    B = 49    C = 71    D = 0
A + B = 51  ≠ 92   ← 校验失败！
A + B + C = 122 = MOD 组数 ✅
```

**Decision**

缺失的是一个**删除象限 E**（基线有、MOD 无）：

```
E = 41（回退原版基线）
A + B + E = 2 + 49 + 41 = 92  = 基线组数  ✅
A + B + C = 2 + 49 + 71 = 122 = MOD 组数   ✅
92 − 41 + 71 = 122 ✅
```

被删的 41 组：
`43,46,49,50,56..65,67,68,70,71,76..83,85..88,90..93,95..99,101,102,109`

它们在基线与源侧**均存在**，但在产物中**不存在**（`diff.md` 的 `removed` 各 41 条 `.grp`/`.idx`）。

**Consequences**

20 个 MOD 的 fight 形态已出现**三种模式**：

| MOD | 形态 | A | B | E(删) | C(增) | D(零) | `A+B` |
|-----|------|---:|---:|---:|---:|---:|------:|
| books | 保留 + 新增增量 | 89 | 3 | 0 | 86 | 2 | 92 ✅ |
| pineapple | 几乎全改写 | 2 | 90 | 0 | 62 | 115 | 92 ✅ |
| **dream** | **增删并行** | **2** | **49** | **41** | **71** | **0** | **51 ✗** |

⇒ **「四象限」不足以覆盖 dream**，必须五分类。

**Negative Constraint**

不得再用 `A + B == 基线组数` 作为唯一自洽判据 —— dream 下必然失败。
必须先测 `removed` 中的 `fight*.grp` 数量得到 `E`，再验 `A+B+E`。

## ADR-DRMV-002 `added 156` 含一个**孤儿** `fight23.idx`，必须单列

**Context**

`added` 156 的自然分解是「71 组 fight × 2 = 142 + 非 fight」。
但实测 fight 条目数：

```
fight*.grp 在 added 中 = 71
fight*.idx 在 added 中 = 72   ← 差 1
差集 = {23}
```

`fight23.idx` 存在于产物与源，但 `fight23.grp` 在两侧**都不存在**。

**Decision**

`added 156` 三分：

```
142（71 组配对：.grp + .idx）
+ 1（孤儿 fight23.idx）
+ 13（非 fight）
= 156 ✅
```

`fight23.idx` 定性：**MOD 作者残留**（删了 grp 但漏删 idx）。
流水线**忠实保留**（`REQUIRED` + `in_product=true`），引擎**不读**（无对应 grp）。

**Consequences**

- 任何「`added` 中 fight 都是成对」的假设都不成立，必须分别计 `.grp` 与 `.idx`。
- 非 fight 是 **13** 项（不是 14），因为孤儿 idx 已单列。

**Negative Constraint**

不得把 `fight23.idx` 判为构建缺陷或多余产物；不得假设 fight `.grp` 与 `.idx` 一一配对。

## ADR-DRMV-003 `eft` 零改动必须用 md5 三重证明

**Context**

dream `eft` 条目数 **714**，与基线 **714** 相同。这有两种可能：

1. dream 恰好也打包了 714 条（内容可能不同）
2. dream 完全沿用基线文件（内容相同）

`hdgrp` 就是前者的例子：dream `484` vs 基线 `115`，条目数不同但都合法。
而「条目数相同」绝不能推出「内容相同」。

**Decision**

三重独立证明：

1. **md5 相同**：`md5(eft.idx)` / `md5(eft.grp)` 与基线**全同**（2856B / 691627B）
2. **diff 缺席**：`eft.*` **不在** `diff.md` 的 `added` 也不在 `removed`
   ⇒ 产物侧**真实存在**（排除「构建器回退基线」）
3. **大小相同**：`691627B == 691627B`

旁证：源 `resource/eft.{idx,grp}` 与产物 md5 相同 ⇒ 构建器未改动（无字符串字段需编码转换）。

**Consequences**

dream 是 epic 中 `eft` **零改动**的唯一正样本：

| MOD | eft | 关系 |
|-----|----:|------|
| **dream** | **714** | **md5 全同** |
| books | 973 | 改动 |
| pineapple | 1378 | 改动 |
| mingdong | 2268 | 改动 |
| BookCalamity | 2857 | 改动 |

**Negative Constraint**

不得用「条目数相同」断定内容相同；必须 md5 + diff 缺席双重佐证。

## ADR-DRMV-004 `removed 105` 的 `9+9` 是两类槽，不是同类

**Context**

`removed` 里有 18 个槽文件（`d/r/s` × `{1,2,3}` × `.grp`/`.idx`）。看起来是同类，
但实测源侧：

```
9 个 .grp：源 save/ 中存在 9/9  ✅
9 个 .idx：源 save/ 中一个都没有 0/9
```

**Decision**

拆成两类：

| 类别 | 数量 | 机制 |
|------|-----:|------|
| 槽 `.grp` | 9 | 源提供 → 改道产物 `save/`（与源 md5 一致 9/9） |
| 槽 `.idx` | 9 | 源**不存在** → 运行时 `ModData.SeedSaveSlot(id)` 从 `data/ranger.idx` 播种 |

`SeedSaveSlot` 实测（dream）：

```bash
$ lua /tmp/dream_seed.lua
Resolve(save/r1.idx) = data/save/r1.idx
SaveDir() = mods/dream/save/
SeedSaveSlot(1) -> ok=true path=mods/dream/save/r1.idx
SeedSaveSlot(2) -> ok=true path=mods/dream/save/r2.idx
SeedSaveSlot(3) -> ok=true path=mods/dream/save/r3.idx
```

⇒ `.idx` 是**按需生成**（首次保存时播种），产物目录当前无 `.idx` 文件属正常。

**Consequences**

四分法：`9（槽 grp）+ 9（槽 idx）+ 84（fight 82 + thing 2）+ 3（死文件）+ 0（真删除）= 105` ✅

**Negative Constraint**

不得把 18 个槽文件当同类；不得因「产物 `save/` 无 `.idx`」判为缺失（按需播种）。

## ADR-DRMV-005 源 `ranger.idx` 完好 —— 推翻 manifest 初稿的「RepairIdx 案例」断言

**Context**

slice14 `change-manifest.md` 初稿含断言：

> 「源 `ranger.idx`：5 段长全不可整除 → 构建期 `RepairIdx` → 结构修复（第 2 案例）」

该断言是**从 zheng 的先例外推**，未实测。

**Decision**

实测源文件与三重佐证（同 `allmods-dream-activate` ADR-DRM-002）：

```
源 save/ranger.idx = 24B  offsets=[836,75274,111754,118098,131970,132270]
seglen=[74438,36480,6344,13872,300]  全部整除 182/190/52/136/50
末 offset 132270 == ranger.grp 132270 ✅
md5(产物 idx) == md5(源 idx) ✅
构建日志无 RepairIdx ⌀
encoding-report.md 无 idxRepaired ⌀
```

⇒ **完好无损，`RepairIdx` 未触发，dream 不是该案例。**

**Consequences**

- `RepairIdx` 在本 epic 中仍是 **zheng 唯一案例**。
- slice14 manifest 已按实测勘误（保留原文 + 勘误说明，不抹去历史）。

**Negative Constraint**

不得因「某 MOD 有某缺陷」而推定其他 MOD 也有；每个 MOD 必须独立实测。

## ADR-DRMV-006 `hdgrp` 的 72 个零长段是内容特征，且有 `eft` 反证

**Context**

dream `hdgrp`：484 offsets / 483 段，其中 **72 段零长**（`offs[i+1] == offs[i]`）。
若按「每段都必须有合法 RLE 头」判，会得 72 个假缺陷。

**Decision**

分两类判 + 一个反证：

1. **411 个非空段**：解析 8 字节头，要求 `w>0, h>0`；实测异常 **0**，`w 1..58 / h 1..71`
2. **72 个零长段**：属 `idx_grp_rle` 家族合法表达，`verifyPair` 用 `b > a` 主动跳过
3. **`eft` 反证**：`eft` 同属该家族且 dream 的 `eft` 与基线**逐字节相同**，
   其 713 段**零长 0**。同一文件集、同一解析器、同一 MOD 内，
   `hdgrp` 有 72 个零长而 `eft` 有 0 个 ⇒ 零长是 `hdgrp` 的**内容特征**（共享帧），
   不是解析器或格式缺陷。

零长块分布：`(381, 69)` + `(480, 3)` = **72**

基线对照：`115 offsets / 114 段 = PNG 2 + RLE 112 + 零长 0`，`w 13..56`

**Consequences**

- `format_spec --mod dream` 的 `gaps=0` 与「零长段被跳过」一致。
- 判据写成 `411 + 72 = 483`，且「头异常 = 0」。

**Negative Constraint**

不得把零长段计为 gap / 缺陷；不得用 `hdgrp` 段数（483）当条目数（484，末 offset 是哨兵）。

---

## Negative Constraints（本 change 全局）

1. 不得以数量相等代替集合相等（`added`/`removed` 必须双向集合比对）。
2. 不得用 `A+B == 基线组数` 作唯一 fight 自洽判据（dream 需加删除象限 E）。
3. 不得假设 fight `.grp` 与 `.idx` 一一配对（存在孤儿 `fight23.idx`）。
4. 不得把 `fight23.idx` 判为构建缺陷或多余产物（作者残留，忠实保留）。
5. 不得用「`eft` 条目数相同」断定「内容相同」（必须 md5）。
6. 不得把 `eft` 判为「构建器回退基线」（`diff.md` 中缺席即证明产物存在）。
7. 不得把 18 个槽文件当同类（9 `.grp` 源有 / 9 `.idx` 源无）。
8. 不得因「产物 `save/` 无 `.idx`」判为缺失（`SeedSaveSlot` 按需播种）。
9. 不得把「源 `save/` 31」与「产物 `save/` 27」写成「逐字节一致」。
10. 不得因 zheng 曾损坏 `ranger.idx` 推定 dream 也损坏（实测完好）。
11. 不得把 `hdgrp` 的 72 个零长段计为 gap / 缺陷。
12. 不得把 `hdgrp` 的 484 offsets 当作 484 段（末 offset 是哨兵，实为 483 段）。
13. 不得把 `kdef.grp` 尾部 12B 残留判为截断（源侧本有，md5 全同）。
14. 不得把 `new.idx`（LEGACY）判为遗漏（引擎无引用）。
15. 不得出现无全 20-MOD 实测支撑的「第 1 / 最多 / 最大」断言。
16. 不得改 `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量、`reference/allmods/**`。
17. 不得改 `game/tools/**`（本 change 未发现工具缺陷）。
18. 不得用 `mod_audit.lua dream` 位置参数（须 `--mod dream`）。

## Review Checklist

- [x] REQ-DRMV-1 `add==实测 True` / `rem==实测 True`（双向集合相等）
- [x] REQ-DRMV-2 `9+9+84+3+0=105` 闭合
- [x] REQ-DRMV-3 `142+1+13=156`，孤儿 `fight23.idx` 已单列并溯源
- [x] REQ-DRMV-4 `A2/B49/E41/C71/D0`，`A+B+E=92`、`A+B+C=122`、`92−41+71=122`
- [x] REQ-DRMV-5 三种 fight 形态对照表（books/pineapple/dream）
- [x] REQ-DRMV-6 `411 RLE + 72 零长 = 483`，头异常 0，`eft` 反证
- [x] REQ-DRMV-7 `eft` md5 三重证明（md5 同 + diff 缺席 + 大小同）
- [x] REQ-DRMV-8 `ranger.str 763` 三重闭合（行/分段/字段）
- [x] REQ-DRMV-9 `save/` 27 vs 源 31，4 项改道已逐项 md5 核验
- [x] REQ-DRMV-10 8 项排名全部实测（`kdef 1/20`、`hdgrp 2/20`、`fight 12/20`）
