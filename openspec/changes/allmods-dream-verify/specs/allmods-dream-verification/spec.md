---
status: done
created: 2026-10-26
---
# Spec: allmods-dream-verification

> Change: `allmods-dream-verify`　|　Slice 14 子 change 2/2
> 审计对象：`game/mods/dream/`（已由 `allmods-dream-activate` 构建）

---

## REQ-DRMV-1 `diff.md` 双向 set 相等

**Given** `game/mods/dream/diff.md`
**When** 解析 `  - + <file>` 为 `added`、`  - - <file>` 为 `removed`，
并与独立计算的「实测 MOD 独有」「实测基线独有」比对
**Then** 必须：

```
diff.md added: 156   removed: 105
实测 MOD 独有: 156   实测基线独有: 105
add == 实测独有 ?    True
rem == 实测基线独有 ? True
```

**And** 必须是**集合相等**（逐一相同），**不得**只比数量

---

## REQ-DRMV-2 `removed` 105 的四分法闭合

**Given** `removed` 的 105 项
**When** 按「源 `save/` 是否存在」「是否为 fight」「是否为模板/死文件」分类
**Then** 必须：

| 类别 | 数量 | 文件 |
|------|-----:|------|
| 槽 `.grp`（源提供，改道 `save/`） | **9** | `d1/d2/d3/r1/r2/r3/s1/s2/s3.grp` |
| 槽 `.idx`（源不存在，`SeedSaveSlot` 播种） | **9** | 同上 9 槽的 `.idx` |
| 回退原版：被删基线战斗 | **82** | 41 组 × `.grp`/`.idx` |
| 回退原版：模板 | **2** | `thing.grp`、`thing.idx` |
| 死文件 | **3** | `alldef.idx`、`allsin.idx`、`allsinbk.grp` |
| 真删除 | **0** | — |
| **合计** | **105** | ✅ |

**And** 闭合验算：`9 + 9 + 84 + 3 + 0 = 105`（其中回退原版 `84 = 82 + 2`）
**And** 9 个槽 `.grp` 必须在产物 `save/` 中**9/9 逐字节一致**
**And** 9 个槽 `.idx` 必须在源 `save/` 中**0/9**（源无 `.idx`）
**And** `ModData.SeedSaveSlot(id)` 必须实测可用：

```
SeedSaveSlot(1) -> ok=true path=mods/dream/save/r1.idx
SeedSaveSlot(2) -> ok=true path=mods/dream/save/r2.idx
SeedSaveSlot(3) -> ok=true path=mods/dream/save/r3.idx
```

**And** 41 个被删战斗必须逐组列出：
`43,46,49,50,56..65,67,68,70,71,76..83,85..88,90..93,95..99,101,102,109`

---

## REQ-DRMV-3 `added` 156 的三分拆解

**Given** `added` 的 156 项
**When** 分别统计 `fight*.grp`、`fight*.idx`、非 fight
**Then** 必须：

```
fight*.grp 在 added 中 = 71
fight*.idx 在 added 中 = 72    ← 差 1
差集 = {23}
```

**And** 必须单列孤儿：

```
142（71 组配对 × 2）+ 1（孤儿 fight23.idx）+ 13（非 fight）= 156 ✅
```

**And** 孤儿定性必须给出证据：

```
产物 fight23.idx 存在 = True    产物 fight23.grp 存在 = False
源   fight23.idx 存在 = True    源   fight23.grp 存在 = False
```

⇒ MOD 作者残留（删 grp 漏删 idx），流水线**忠实保留**，引擎**不读**。

**And** 13 项非 fight 必须逐项溯源：

| 文件 | 源侧 |
|------|------|
| `cloud.grp` / `cloud.idx` | `resource/` |
| `icon.png` | `resource/` |
| `kdef.grp` / `kdef.idx` | `resource/` |
| `kysmod.ini` | **根目录** |
| `new.idx` | `resource/`（LEGACY） |
| `open.png` | `resource/` |
| `ranger.str` | **源中不存在（构建生成）** |
| `talk.grp` / `talk.idx` | `resource/` |
| `title.grp` / `title.idx` | `resource/` |

---

## REQ-DRMV-4 fight **五分类**（含删除象限）

**Given** 产物 122 组 fight 与基线 92 组
**When** 按「同名同容 / 同名异容 / 仅在基线 / 仅 MOD / 零字节」五分类
**Then** 必须：

| 象限 | 定义 | 数量 |
|------|------|-----:|
| A | 保留（同名同容，md5 相等） | **2** |
| B | 改写（同名异容，md5 不同） | **49** |
| E | **删除（基线有、MOD 无）** | **41** |
| C | 新增（MOD 独有） | **71** |
| D | 零字节 | **0** |

**And** 自洽校验必须全部成立：

```
A + B + E = 2 + 49 + 41 = 92   = 基线组数  ✅
A + B + C = 2 + 49 + 71 = 122  = MOD 组数   ✅
92 − 41 + 71 = 122 ✅
```

**And** 必须显式指出 **`A + B = 51 ≠ 92`** —— 「四象限」框架在 dream 下失效，
必须加删除象限 `E`

**And** `E` 必须等于 `removed` 中 `fight*.grp` 的条数（41），两处独立计算须一致

---

## REQ-DRMV-5 三种 fight 形态的跨 MOD 对照

**Given** books / pineapple / dream 三个 MOD 的 fight 五分类
**When** 并表对照
**Then** 必须：

| MOD | 形态 | A | B | E(删) | C(增) | D(零) | `A+B` |
|-----|------|---:|---:|---:|---:|---:|------:|
| books | 保留 + 新增增量 | 89 | 3 | 0 | 86 | 2 | 92 ✅ |
| pineapple | 几乎全改写 | 2 | 90 | 0 | 62 | 115 | 92 ✅ |
| **dream** | **增删并行** | 2 | 49 | **41** | 71 | 0 | **51 ✗** |

**And** 必须给出结论：20 个 MOD 的 fight 形态已出现**三种模式**，
任何**单一计数口径都会漏项**

---

## REQ-DRMV-6 `hdgrp` 484 内容有效性

**Given** `hdgrp.idx` = 1936B、`hdgrp.grp` = 944448B
**When** 解析全部 offsets 与段头
**Then** 必须：

```
offs 数 = 484    段数 = 483    offs[0] = 2895    末 off = 944448    tail = 0
483 段 = 411 有效 RLE + 72 零长     头异常 = 0
w: 1..58   h: 1..71
零长块: (381, 69) (480, 3)   Σ = 72
```

**And** `484 offsets` ↔ `483 段`（末 offset 是**哨兵**）
**And** 「头异常 = 0」必须成立
**And** 必须给基线对照：

```
基线 hdgrp: 115 offsets / 114 段 = PNG 2 + RLE 112 + 零长 0，w 13..56
```

**And** 必须给 `eft` 反证（同一 MOD、同一家族、同一解析器）：

```
dream eft: 714 offsets / 713 段 = RLE 713，零长 0
```

⇒ `hdgrp` 有 72 零长而 `eft` 有 0 ⇒ 零长是 `hdgrp` 内容特征

---

## REQ-DRMV-7 `eft` 零改动的三重证明

**Given** `mods/dream/data/eft.{idx,grp}` 与基线 `data/eft.{idx,grp}`
**When** 三重独立检验
**Then** 必须：

1. **md5 相同**

```
dream    eft.idx = 2856B   eft.grp = 691627B
baseline eft.idx = 2856B   eft.grp = 691627B
md5(eft.idx) 相同 ? True
md5(eft.grp) 相同 ? True
```

2. **diff 缺席**（排除「构建器回退基线」）

```
grep -E "^\s*-\s*[-+]\s*eft\." mods/dream/diff.md
→ 无输出
```

即 `eft.*` 既不在 `added` 也不在 `removed` ⇒ 产物侧**真实存在**

3. **大小相同**：`691627B == 691627B`

**And** 必须声明 dream 是 epic 中 `eft` **零改动**的正样本：

| MOD | eft | 与基线关系 |
|-----|----:|------------|
| **dream** | **714** | **md5 全同** |
| books | 973 | 改动 |
| pineapple | 1378 | 改动 |
| mingdong | 2268 | 改动 |
| BookCalamity | 2857 | 改动 |

**And** 必须提供旁证：源 `resource/eft.{idx,grp}` 与产物 md5 相同
（构建器未改动，因无字符串字段需编码转换）

---

## REQ-DRMV-8 `ranger.str` 763 条完整性

**Given** `game/mods/dream/data/ranger.str` 与 `mods/dream/encoding-report.md`
**When** 跳过 `#` 注释行后统计
**Then** 必须：

```
总行 770  有效 763  注释 7
分段: Person 243 / Thing 343 / Scene 82 / Wugong 95 = 763 ✅
字段: Name 513 / Nick 82 / Desc 168 = 763 ✅
唯一值 732 / 重复 31
```

**And** 必须与 `encoding-report.md` 的「旁路表条目 **763**」一致
**And** 格式必须为**逗号分隔** `id,段,索引,字段,值`（**不是** tab）
**And** 首 **3** 行为表头注释 + 4 个分段注释共 **7** 行注释
（行 1-3 表头，行 4 `# Person`、248 `# Thing`、592 `# Scene`、675 `# Wugong`）
**And** 首**数据**行（第 5 行）必须是 `0000,Person,0,Name,隨小破`

---

## REQ-DRMV-9 存档 `save/` 27 vs 源 31

**Given** 产物 `mods/dream/save/` 与源 `save/`
**When** 逐文件比对
**Then** 必须：

```
产物 save/ = 27 个（全为槽 .grp：d/r/s × {1,2,3,4,5,6,7,9,11}；无任何 .idx）
源   save/ = 31 个
27 个槽 .grp 与源逐字节一致 27/27
```

**And** 源多出的 4 个必须逐项给出改道与 md5：

| 文件 | 源 save → 产物 data | md5 |
|------|---------------------|:---:|
| `alldef.grp` | 536800B → 536800B | **同** |
| `allsin.grp` | 5996544B → 5996544B | **同** |
| `ranger.idx` | 24B → 24B | **同** |
| `ranger.grp` | 132270B → 132270B | **异**（UTF-8 编码转换，预期） |

**And** **不得**把「源 `save/` 31」与「产物 `save/` 27」写成「逐字节一致」

---

## REQ-DRMV-10 8 项排名必须逐项实测

**Given** dream 涉及的排名断言
**When** 扫全部 20 个 MOD 的 `mods/*/data/` 实测
**Then** 必须：

| 指标 | dream | 排名 | 前序实测 |
|------|------:|-----:|----------|
| `kdef` | 4569 | **1/20** | BookCalamity 1701 > mingdong 1654 > lyff 1358 > pig 1288 |
| `hdgrp` | 484 | **2/20** | books 696 > **dream 484** > pig3dos 412 > BookCalamity 373 > awaken 353 |
| `talk` | 6464 | **4/20** | RiverLake 8015 > awaken 7717 > books 6655 > **dream 6464** |
| `Person` | 409 | **7/20** | BookCalamity 800 > awaken 720 = pineapple 720 > mingdong 632 > pig3dos 607 > Dragon 589 > **dream 409** |
| `fight` | 122 | **12/20** | BookCalamity 326 > mingdong 267 > awaken 237 > RiverLake 219 > Dragon 209 > pig3dos 180 > books 178 > ptt 162 > pineapple 154 > lyff 138 > pig 137 > **dream 122** |
| `eft` 与基线相同 | 714 | 唯一 | 其余 4 个改动型 MOD：books 973 / pineapple 1378 / mingdong 2268 / BookCalamity 2857 |
| 零字节 fight | 0 | 并列最少 | pineapple 115 / RiverLake 44 / ptt 7 / books 2 / loving 2 |
| 记录段全异 | **5/5** | **本 epic 唯一** | lyff 1 段 / ptt 4 段 / 其余基线同形 |

**And** 只有 `kdef` 是真「第 1」；`hdgrp` 是第 2；`fight 122` 仅第 12
**And** 每个排名必须附**前序 MOD 的具体数值**
**And** **不得**出现无实测的「最大 / 最多」断言
