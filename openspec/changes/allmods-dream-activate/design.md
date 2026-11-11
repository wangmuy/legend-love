---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
---
# Design: allmods-dream-activate

> Slice 14 子 change 1/2 的设计决策。每个关键判断记作 ADR。

## ADR-DRM-001 记录段 5/5 全异 ≠ MOD 自定义布局

**Context**

dream 的 5 个记录段**全部**与基线不同（`409/192/122/102/6` vs `320/200/84/93/3`）。
前序 MOD 中 lyff 只有 1 段异、ptt 有 4 段异。5/5 全异是本 epic 首次。

直觉风险：段长全异可能是 MOD 用了**非标准记录尺寸**（自定义布局），
那样统一判据就不适用，必须另建判据。

**Decision**

对每一段同时验证两个条件：

1. **整除**：`段长 % CC 尺寸 == 0`，且商 == 实测记录数
2. **CC 尺寸为标准值**：`182/190/52/136/50`（与基线完全一致）

实测：

| 记录 | 段长 | CC 尺寸 | 商 | 余数 | 标准尺寸？ |
|------|-----:|--------:|---:|-----:|:----------:|
| Person | 74438 | 182 | 409 | 0 | ✅ |
| Thing | 36480 | 190 | 192 | 0 | ✅ |
| Scene | 6344 | 52 | 122 | 0 | ✅ |
| Wugong | 13872 | 136 | 102 | 0 | ✅ |
| Shop | 300 | 50 | 6 | 0 | ✅ |

**Consequences**

- 5/5 全异只是**记录数**不同，**布局完全标准** ⇒ 统一判据成立（第 3 次应用）。
- 「段长不同」不能被解释为「布局不同」——必须分开验。

**Negative Constraint**

不得因段长与基线不同就判为「MOD 自定义布局」；必须先验 CC 尺寸是否标准值。

## ADR-DRM-002 源 `ranger.idx` **完好**，`RepairIdx` 未触发（勘误）

**Context**

slice14 的 `change-manifest.md` 初稿写：

> 「源 `ranger.idx`：5 段长全不可整除 → 构建期 `RepairIdx`（`mod_build.lua:709-717`）
> → **结构修复（第 2 案例，首个 zheng）**」

这是从「zheng 曾损坏」这一先例**外推**出来的假设，未实测。

**Decision**

实测源文件：

```
../reference/allmods/kys-dream/save/ranger.idx = 24B
offsets = [836, 75274, 111754, 118098, 131970, 132270]
seglen  = [74438, 36480, 6344, 13872, 300]
整除 182/190/52/136/50 : [True, True, True, True, True]
末 offset 132270 == ranger.grp 132270  ✅
```

三重佐证「未修复」：

1. `mod_build` 日志无任何 `RepairIdx` 输出
2. 产物 `mods/dream/data/ranger.idx` 与源 `save/ranger.idx` **md5 相同**
3. `mods/dream/encoding-report.md` 无 `idxRepaired` 字段

**Consequences**

- dream **不是** `RepairIdx` 案例；**zheng 仍是唯一案例**。
- manifest 已按实测修正（保留勘误说明，不删原文）。

**Negative Constraint**

不得因「某 MOD 曾出现某缺陷」而推定另一 MOD 也有；必须逐 MOD 实测。

## ADR-DRM-003 `eft` 与基线逐字节相同，是「零改动」的正样本

**Context**

epic 前序 MOD 的 `eft` 全部有改动：pineapple 1378、mingdong 2268、
BookCalamity 2857、books 973。dream 报 714，与基线 714 相同。

需要判断：是「dream 恰好也有 714 条」，还是「文件完全一样」？

**Decision**

用 md5 判定：

```
dream  eft.idx = 2856B  eft.grp = 691627B
baseline eft.idx = 2856B  eft.grp = 691627B
md5(eft.idx) 相同 ? True
md5(eft.grp) 相同 ? True
```

⇒ **逐字节相同**，dream 完全沿用基线 `eft`，未改任何特效。

排除「构建器回退到基线」的可能：`diff.md` 中 `eft.*` **未出现在 `added`/`removed`**，
即产物侧存在该文件（不是回退），只是内容与基线相同。

**Consequences**

- dream 是 `eft` 零改动的**正样本**，与 books（全 RLE、改动）、
  pineapple（1378、改动）形成对照。
- 「`eft` 条目数 == 基线」时必须用 md5 区分「内容相同」与「数量巧合」。

**Negative Constraint**

不得用条目数相等推断内容相同（1842 测试的教训同样适用）。

## ADR-DRM-004 产物 `save/` 27 ≠ 源 `save/` 31（4 个改道 `data/`）

**Context**

源 `save/` 有 31 个文件，产物 `save/` 有 27 个。
manifest 初稿写「产物 31 与源 31 逐字节一致」——与实测不符。

**Decision**

逐文件实测：

```
产物 save/ = 27 个，全部是槽 .grp（d/r/s × {1,2,3,4,5,6,7,9,11}）
            无任何 .idx
源   save/ = 31 个 = 27 槽 .grp + alldef.grp + allsin.grp + ranger.grp + ranger.idx
差额 4 个 → 改道到产物 data/
```

md5 验证：

| 文件 | 源 save → 产物 data | md5 |
|------|---------------------|:---:|
| `alldef.grp` | 536800B → 536800B | **同** |
| `allsin.grp` | 5996544B → 5996544B | **同** |
| `ranger.idx` | 24B → 24B | **同** |
| `ranger.grp` | 132270B → 132270B | **异**（UTF-8 编码转换，预期） |

27 个槽 `.grp` 与源**逐字节一致 27/27**。

**Consequences**

- 建档口径必须说清：产物 `save/` = **27**，不是 31。
- `ranger.grp` 因编码转换而 md5 不同，但**大小不变**（hint 方案保证）。

**Negative Constraint**

不得把「源 `save/` 31」与「产物 `save/` 27」写成「逐字节一致」；
不得把 4 个改道文件计入 `save/`。

## ADR-DRM-005 fight 三分法：保留 2 / 改写 49 / 删除 41 / 新增 71

**Context**

dream 的 fight 是 `122 = 92 − 41 + 71`。前序已有的分析框架是「四象限」
（A 同名同容 / B 同名异容 / C MOD 独有 / D 零字节），
但 dream 有 41 组**基线有而 MOD 没有**（删除），这个象限前序未单列。

**Decision**

扩展为五分类（含删除象限 E）：

```
基线 92 = A 2 + B 49 + E 41        ✅ 2+49+41 = 92
MOD 122 = A 2 + B 49 + C 71        ✅ 2+49+71 = 122
D（零字节）= 0
92 − 41 + 71 = 122                 ✅
```

删除的 41 组（回退原版基线）：`43,46,49,50,56..65,67,68,70,71,76..83,85..88,90..93,95..99,101,102,109`

**Consequences**

20 个 MOD 的 fight 形态已出现**三种不同模式**：

| MOD | 形态 | A | B | E(删) | C(增) | D(零) |
|-----|------|---:|---:|---:|---:|---:|
| books | 保留+新增增量 | 89 | 3 | 0 | 86 | 2 |
| pineapple | 几乎全改写 | 2 | 90 | 0 | 62 | 115 |
| **dream** | **增删并行** | **2** | **49** | **41** | **71** | **0** |

⇒ 任何**单一计数口径都会漏项**。必须五分类。

**Negative Constraint**

不得用「A + B == 基线组数」作为唯一自洽判据——dream 下该式不成立
（`2+49=51 ≠ 92`），必须加删除象限 `E`。

---

## Negative Constraints（本 change 全局）

1. 不得以「数量相等」代替「内容相同」（`eft` 必须用 md5 判定）。
2. 不得因段长与基线不同就判为「MOD 自定义布局」。
3. 不得因「zheng 曾损坏 ranger.idx」推定 dream 也损坏（实测完好）。
4. 不得把「源 `save/` 31」与「产物 `save/` 27」写成「逐字节一致」。
5. 不得把 4 个改道 `data/` 的文件计入产物 `save/`。
6. 不得用「A+B == 基线组数」作唯一 fight 自洽判据（dream 需加删除象限 E）。
7. 不得把 `hdgrp` 的 484 offsets 当作 484 段（末 offset 是哨兵，实为 483 段）。
8. 不得把 72 个零长段计为缺陷（`idx_grp_rle` 家族特性，头异常 0）。
9. 不得把 `fight23.idx` 孤儿判为构建缺陷（作者残留，流水线忠实保留）。
10. 不得把 `new.idx`（LEGACY）判为遗漏（引擎无引用）。
11. 不得把 `kdef.grp` 尾部 12B 残留判为截断/损坏（源侧本有，忠实搬运）。
12. 不得改 `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量、`reference/allmods/**`。
13. 不得改 `game/tools/**`（本 change 未发现工具缺陷）。
14. 不得用 `mod_audit.lua dream` 位置参数（须 `--mod dream`）。
15. 不得在启动链路中传入「实际值」当期望值（必须传规格期望值，防假通过）。

## Review Checklist

- [x] REQ-DRM-1 `data files=280` + 目录实测 `281` 口径差已声明
- [x] REQ-DRM-2 `378+4+3+1+1+29=416` 闭合，`evidence checked=9 failed=0`
- [x] REQ-DRM-3 `formats=12 checked=225 gaps=0`
- [x] REQ-DRM-4 5 段整除全 0 余数 + CC 尺寸全标准值
- [x] REQ-DRM-5 `RESULT dream: OK`，16 断言全 PASS，5 位置参数为期望值
- [x] REQ-DRM-6 `ranger.str` 763 条，双重 Σ 闭合
- [x] REQ-DRM-7 `hdgrp 484 offsets / 483 段 = 411 RLE + 72 零长`，头异常 0
- [x] REQ-DRM-8 `eft` md5 与基线**全同**
- [x] REQ-DRM-9 8 道门禁全绿（见 verification）
- [x] ADR-DRM-002 勘误已写入 manifest（`RepairIdx` 未触发）
- [x] ADR-DRM-004 勘误已写入 manifest（`save/` 27 vs 31）
