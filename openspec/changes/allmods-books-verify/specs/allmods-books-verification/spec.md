---
status: done
created: 2026-10-26
---
# Spec: allmods-books-verification

> Change: `allmods-books-verify`　|　Slice 13 子 change 2/2
> 审计对象：`game/mods/books/`（已由 `allmods-books-activate` 构建）

---

## REQ-BKV-1 `diff.md` 双向 set 相等

**Given** `game/mods/books/diff.md`
**When** 解析 `  - + <file>` 为 `added` 集合、`  - - <file>` 为 `removed` 集合，
并与「实测 MOD 独有」「实测基线独有」两个独立计算的集合比对
**Then** 必须：

```
diff.md added: 184   removed: 21
实测 MOD 独有: 184   实测基线独有: 21
add == 实测独有 ?    True
rem == 实测基线独有 ? True
```

**And** 比对必须是**集合相等**（元素逐一相同），**不得**只比数量

---

## REQ-BKV-2 `removed` 21 的三分法闭合

**Given** `removed` 的 21 项
**When** 按「源 `save/` 是否存在」与「是否为模板」分类
**Then** 必须满足：

| 类别 | 数量 | 文件 |
|------|-----:|------|
| 槽改道到 `save/` | **13** | `d1.grp`、`r1.grp/.idx`、`r2.grp/.idx`、`r3.grp/.idx`、`s1.grp/.idx`、`s2.grp/.idx`、`s3.grp/.idx` |
| 槽位完全缺席（走回退） | **5** | `d1.idx`、`d2.grp`、`d2.idx`、`d3.grp`、`d3.idx` |
| 模板回退 | **3** | `thing.grp`、`thing.idx`、`allsinbk.grp` |
| 真删除 | **0** | — |

**And** `13 + 5 + 3 + 0 = 21` ✅
**And** 13 项必须在 `mods/books/save/` 中与源 `save/` **md5 全同（13/13）**
**And** 5 项必须在源 `save/` 中**同样不存在**

**And** 必须显式声明 `save/` 19 与 `removed` 18 **不是同一集合**：

```
save/ 有而 removed 无: d11 d6 r11 r6 s11 s6   （基线 data/ 本无这些槽）
removed 有而 save/ 无: d2 d3                   （只在基线 data/，源未提供）
```

---

## REQ-BKV-3 `added` 184 的拆解与溯源

**Given** `added` 184 项
**When** 按是否为 fight 分类并逐项溯源
**Then** 必须：

```
fight: 172 = 86 组 × 2（.grp + .idx）
非 fight: 12
合计: 184 ✅
```

**And** 12 项非 fight 必须逐项给出源侧路径：

| 文件 | 源侧位置 |
|------|----------|
| `cloud.grp` / `cloud.idx` | `resource/` |
| `end.png` | `resource/` |
| `kdef.grp` / `kdef.idx` | `resource/` |
| `kysmod.ini` | 根目录 |
| `open.png` | `resource/` |
| `ranger.str` | **源中不存在**（构建生成） |
| `talk.grp` / `talk.idx` | `resource/` |
| `title.grp` / `title.idx` | `resource/` |

**And** `find ../reference/allmods/kys-books -name "ranger.str"` 必须**无输出**

---

## REQ-BKV-4 `hdgrp` 696 内容有效性

**Given** `hdgrp.idx` = 2784B（696 条）、`hdgrp.grp` = 1233815B
**When** 逐条解析 8 字节 RLE 头 `<HHhh>`（`w,h,xoff,yoff`）
**Then** 必须：

```
记录=696  PNG=0  RLE=474  零长=222  头异常=0
w: 1..82   h: 1..70
零长块: (215,54) (270,2) (273,165) (695,1)   Σ=222
```

**And** `474 + 222 = 696` ✅
**And** 「头异常 = 0」必须成立（474 个非空段全部 `w>0, h>0`）
**And** 必须给上限检查（`w ≤ 82`、`h ≤ 70`，无异常巨值）

**And** 必须有 `eft` 的**同家族对照**（决定零长是内容特征而非格式缺陷）：

```
books eft: 记录=973  RLE=972  零长=1   头异常=0   w 1..230  h 1..200
```

⇒ 同一 `idx_grp_rle` 家族、同一解析器，`eft` 零长仅 1（末尾哨兵），
`hdgrp` 零长 222 ⇒ 属 `hdgrp` 的内容特征。

**And** 必须给基线对照：`基线 115 = PNG 2 + RLE 112 + 零长 1`，`w 13..56 / h 9..58`

---

## REQ-BKV-5 `Wugong` 100 字段对齐

**Given** `Wugong` 100 条、`CC.Wugong_S` 64 字段
**When** 用 `pairs(CC.Wugong_S)` 取全部字段名，逐字段统计 100 条记录
**Then** 必须：

```
Wugong_S 字段数: 64
全 nil 字段数: 0
名称非空: 100 / 100
```

**And** 抽样必须使用**实名** `武功动画&音效`（含 `&`），不得用 `动画`：

```
[  0] 名称=普通攻擊   武功类型=1 出招音效= 1 武功动画&音效=12 消耗内力点数= 1
[  1] 名称=天地雙絕刀 武功类型=3 出招音效=20 武功动画&音效= 9 消耗内力点数=20
[  2] 名称=圓月刀法   武功类型=3 出招音效= 1 武功动画&音效=24 消耗内力点数=14
[ 97] 名称=凝碧柔云劍 武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 98] 名称=柔云劍法   武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 99] 名称=震天三十掌 武功类型=1 出招音效= 1 武功动画&音效=27 消耗内力点数= 8
```

**And** `CC.Effect` 越界统计必须用 `pairs` 计数与 `max键`：

```
CC.Effect 键数: 53    max键: 52
武功动画&音效: 有值 100 条，越界(>52) 2 条，max=55
```

**And** **不得**用 `#CC.Effect`（含 `[0]` 键，`#` 语义不可靠）

---

## REQ-BKV-6 fight 四象限

**Given** `fight 0..177`（178 组）与基线 `fight` 92 组
**When** 按（是否同名，内容是否同 md5）四象限分解
**Then** 必须：

| 象限 | 定义 | 数量 |
|------|------|-----:|
| A | 同名同容（md5 相等） | **89** |
| B | 同名异容（md5 不同） | **3** |
| C | MOD 独有（基线无此名） | **86** |
| D | MOD 侧零字节 | **2** |

**And** 自洽校验必须全部成立：

```
A + B     = 89 + 3      = 92   = 基线组数   ✅
A + B + C = 89 + 3 + 86 = 178  = MOD 组数   ✅
D ∩ B = 0
D ∩ C = 2
```

**And** D 的具体编号：`fight104`、`fight164`（`.grp`/`.idx` 均 0B）

---

## REQ-BKV-7 fight 与 pineapple 的**反向**分布

**Given** books 与 pineapple 的四象限
**When** 比较「改动性质」而非「总数」
**Then** 必须：

| 象限 | books | pineapple |
|------|-----:|----------:|
| A 同名同容 | **89** | 2 |
| B 同名异容 | **3** | 90 |
| C MOD 独有 | **86** | 62 |
| D 零字节 | 2 | 115 |
| **B/(A+B)** | **3.3%** | **97.8%** |

**And** 必须给出结论：
- books = **保留基线 + 新增增量**（89 组未动 + 86 组新增）
- pineapple = **几乎全部改写存量**（90/92 组被改写）

**And** 必须说明 `fight` 总数接近（178 vs 154）但**改动性质完全相反**
⇒ 四象限是唯一可靠的分析方式

---

## REQ-BKV-8 `FILE_MISSING` 4 实例的引用链

**Given** `Person.头像代号` 共引用 174 个不同代号
**When** 对每个被引用代号检查 `fight*.grp/.idx` 是否存在
**Then** 必须发现 **4 个**被引用但缺失：

| 代号 | 引用者 | 姓名 | 缺失文件 |
|-----:|-------:|------|----------|
| 30 | `Person[30]` | 風清揚 | `fight030.grp/.idx` |
| 39 | `Person[39]` | 石中玉 | `fight039.grp/.idx` |
| 66 | `Person[66]` | 段正淳 | `fight066.grp/.idx` |
| 110 | `Person[122]` | 張召重 | `fight110.grp/.idx` |

**And** 必须证明源侧与基线侧均不存在：

```
fight030: src=MISSING base=MISSING      fight039: src=MISSING base=MISSING
fight066: src=MISSING base=MISSING      fight110: src=MISSING base=MISSING
```

**And** 必须列出「文件不存在但未被引用」的 4 个：`fight052/111/112/113`（引用 0 次）
**And** 必须与 pineapple 对照：pineapple `FILE_MISSING = 0`

---

## REQ-BKV-9 `ranger.str` 957 条完整性

**Given** `game/mods/books/data/ranger.str`
**When** 跳过 `#` 注释行后统计
**Then** 必须：

```
总行数: 964
有效条目: 957
分段: Person 419 / Thing 368 / Scene 72 / Wugong 98      (Σ = 957)
字段: Name 670 / Nick 119 / Desc 168                      (Σ = 957)
唯一值 934 / 重复 23
```

**And** 必须证明 hint → 真实字符串的回填：
`ranger.grp @844 = "P0000"` → 运行时 `JY.Person[0]["姓名"] = 古天奇`

---

## REQ-BKV-10 排名断言必须逐项实测

**Given** books 涉及 8 项「全 20 MOD 第 N / 最 X」断言
**When** 用脚本扫全部 20 个 MOD 的 `mods/*/data/` 实测
**Then** 必须：

| 指标 | books | 排名 | 前序实测 |
|------|------:|-----:|----------|
| `hdgrp` | 696 | **1/20** | dream 484 > pig3dos 412 > BookCalamity 373 > awaken 353 > pineapple 300 |
| `kdef` | 573 | **20/20（最少）** | 次少 1018（SweeOan/pascal/stronger）；最多 dream 4569 |
| `talk` | 6655 | **3/20** | RiverLake 8015 > awaken 7717 > **books** > dream 6464 > BookCalamity 5967 |
| `eft` | 973 | **4/20** | BookCalamity 2857 > mingdong 2268 > pineapple 1378 > **books** > RiverLake 921 |
| `fight` | 178 | **7/20** | BookCalamity 326 > mingdong 267 > awaken 237 > RiverLake 219 > Dragon 209 > pig3dos 180 > **books** |
| `Person` | 382 | **9/20** | BookCalamity 800 > awaken 720 = pineapple 720 > mingdong 632 > pig3dos 607 > Dragon 589 > ptt 385 > **books** |
| `ranger.grp` | 126478 | **9/20** | BookCalamity 313242 > pineapple 229680 > mingdong 223688 > awaken 207180 > pig3dos 191828 > Dragon 174230 > dream 132270 > ptt 131084 > **books** |
| 零字节 fight | 2 | **4/20** | pineapple 115 > RiverLake 44 > ptt 7 > **books 2** = loving 2 |

**And** 只有 `hdgrp` 与 `kdef` 是真「第 1 / 最」；`Person`/`ranger.grp` 均第 9
**And** 每个排名必须附**前序 MOD 的具体数值**（只写名次不可核验）
**And** **不得**出现无实测的「最大 / 最多」断言
