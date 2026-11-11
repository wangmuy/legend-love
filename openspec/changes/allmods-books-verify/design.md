---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice13
---
# Design: allmods-books-verify

> Slice 13 子 change 2/2 的审计设计。每个关键判断记作 ADR。

## ADR-BKV-001 `diff.md` 的对比面是「产物 `data/` vs 基线 `data/`」，`save/` 不参与

**Context**

`removed` 21 项里有 18 项是 `d1/d2/d3/r1/r2/r3/s1/s2/s3` 的 `.grp`/`.idx`。
但 `mods/books/save/` 里明明有 19 个文件。直觉上会推「MOD 删了 18 个存档槽」，
或反过来推「`save/` 的 19 个就是这 18 个」。

两种推法都错。

**Decision**

实测 `diff.md` 的生成逻辑：它比对的是**产物 `data/`** 与**基线 `data/`**。
基线 `data/` 恰好含 9 组槽文件（`d1..d3`/`r1..r3`/`s1..s3` × 2 = 18 项），
而产物 `data/` 里**一个槽文件都没有**（全部改道到 `save/`，或走回退），
所以 18 项全部落入 `removed`。

`save/` 不参与 `diff.md`。

**Consequences**

- 18 项必须按「源 `save/` 中是否存在」再拆成 13 + 5：

```
源save有=13: d1.grp r1.grp r1.idx r2.grp r2.idx r3.grp r3.idx
              s1.grp s1.idx s2.grp s2.idx s3.grp s3.idx
             -> 产物 save/ 中同名且 md5 相同 13/13 ✅
源无=5:       d1.idx d2.grp d2.idx d3.grp d3.idx
             -> MOD 未提供，运行期 ModData.Resolve 回退到基线
```

- `save/` 的 19 个 ≠ `removed` 的 18 个，**两集合不同**：

```
save/ 有而 removed 无 : d11 d6 r11 r6 s11 s6   （基线 data/ 本来就没有这些槽）
removed 有而 save/ 无 : d2 d3                   （只在基线 data/，源未提供）
```

**Negative Constraint**

不得把 `save/` 19 与 `removed` 18 当成同一集合，也不得把「18 项 removed」
解释为「MOD 删除了 18 个文件」。

## ADR-BKV-002 books 的 fight 分布与 pineapple 完全相反，因此必须用四象限

**Context**

`fight` 总数：books **178**，pineapple **154**。数量接近，
若只看总数会得出「两个 MOD 的 fight 改动量类似」——这是严重误判。

**Decision**

用四象限（A 同名同容 / B 同名异容 / C MOD 独有 / D 零字节）分解：

| 象限 | books | pineapple | 含义 |
|------|-----:|----------:|------|
| A | **89** | 2 | 与基线逐字节相同（未改动） |
| B | **3** | 90 | 与基线同名但内容不同（**改写存量**） |
| C | **86** | 62 | 基线没有（**新增**） |
| D | 2 | 115 | 零字节 |

- books：`B/(A+B) = 3/92 = 3.3%` ⇒ **保留基线 + 新增增量**
- pineapple：`B/(A+B) = 90/92 = 97.8%` ⇒ **几乎全部改写存量**

自洽校验：

```
A + B     = 89 + 3      = 92  = 基线 fight 组数  ✅
A + B + C = 89 + 3 + 86 = 178 = MOD fight 组数   ✅
D ∩ B = 0     D ∩ C = 2
```

**Consequences**

- 任何「fight 改动规模」结论必须给四象限，不得只给总数。
- books 的 `added 172`（86 组 × 2）几乎全部来自 C 象限 —— 而 pineapple 的
  `added 124`（62 组 × 2）全部来自它的 C 象限，**B 象限 90 组不在 diff.md 里**
  （同名文件不产生 add/remove 条目，只产生内容差异）。

**Negative Constraint**

不得用 `fight` 总数比较两个 MOD 的改动性质；不得把 B 类（同名异容）算进 `added`。

## ADR-BKV-003 `hdgrp` 696 的内容有效性必须看「非空段头」而非「全部段」

**Context**

696 条 offsets 不严格递增，222 处 `offs[i+1] == offs[i]`。
若按「696 条都必须有合法 RLE 头」判，会得 222 个假缺陷。

**Decision**

分两类判：

1. **474 个非空段**：解析 8 字节头 `<HHhh>`，要求 `w>0, h>0`，并**检查上限**
   （防止异常巨值）。实测 `w 1..82 / h 1..70`，异常 **0**。
2. **222 个零长段**：属 `idx_grp_rle` 家族的合法表达（重复帧引用），
   `format_spec.lua` 的 `verifyPair` 用 `b > a` 主动跳过。

**与 `eft` 的对照（决定性）**：`eft` 同属 `idx_grp_rle` 家族，但**严格递增**、
零长仅 **1**（末尾哨兵）：

```
books eft: 记录=973 PNG=0 RLE=972 零长=1 头异常=0   w 1..230  h 1..200
books hdgrp: 记录=696 PNG=0 RLE=474 零长=222 头异常=0  w 1..82  h 1..70
```

⇒ 同一个解析器、同一个家族，`eft` 只有 1 个零长而 `hdgrp` 有 222 个
⇒ 零长是 `hdgrp` 的**内容特征**（多角色共用同一帧），不是解析器或格式缺陷。

**Consequences**

- 判据写成 `474 非空 + 222 零长 = 696`，且「头异常 = 0」。
- 零长段分布须给出：`(215,54)/(270,2)/(273,165)/(695,1)`，`Σ=222`。
- 必须给基线对照：基线 115 = PNG 2 + RLE 112 + 零长 1。

**Negative Constraint**

不得把零长段计为 gap / 缺陷；不得因 `w` 上限只有 82（小于基线的 56？
—— 实际基线是 56，books 是 82，两者不同量级不能直接比）就判为「图像变小」。

> 修正记录：草稿曾写「基线 `w 13..100 / h 9..102`」，实测为 **`w 13..56 / h 9..58`**。
> 已按实测改正。

## ADR-BKV-004 `Wugong` 的字段名含 `&`，抽样必须辅以「全 nil 字段数 = 0」

**Context**

初次抽样把字段写成 `动画`，得到 `nil` 却**不报错**——抽样"通过"了，
但拿的是空值。真实字段名是 `武功动画&音效`（含 `&`）。

**Decision**

双重判据：

1. **全量兜底**：`pairs(CC.Wugong_S)` 取全部 64 字段，逐字段统计 100 条记录中非 nil 数，
   要求 **全 nil 字段数 = 0**。字段名一旦写错，该字段立刻变成"全 nil"，被兜底抓到。
2. **抽样佐证**：用**正确字段名**打印边界记录，只作语义确认。

实测：

```
Wugong_S 字段数: 64
全 nil 字段数: 0
名称非空: 100 / 100
CC.Effect 键数: 53  max键: 52
武功动画&音效: 有值 100 条, 越界(>52) 2 条, max=55
```

**Consequences**

- 抽样表的字段名必须与 `CC.Wugong_S` 逐字一致（`武功动画&音效` 而非 `动画`）。
- 越界统计用 `CC.Effect` 的真实键上界（`max键 = 52`）而非 `#CC.Effect`
  （`#` 对含 `[0]` 键的表语义未定义，会得 52 但含义不可靠）。

**Negative Constraint**

不得用 `pairs(JY.Wugong[i])` 遍历记录（元表使 `pairs` 返回 0 字段）；
不得用 `#CC.Effect` 作为键数（须 `pairs` 计数得 53，`max键` 52）。

## ADR-BKV-005 排名断言必须逐项实测，禁止从「前序 MOD 印象」外推

**Context**

Slice 12（pineapple）曾产生 8 处事实错误，全部是「第 1 / 最多」类断言未经全量实测。
典型：把 `Person 720` 写成第 1（实为第 2，BookCalamity 800 更大、awaken 720 并列），
把 `ranger.grp 229680` 写成第 1（实为第 2，BookCalamity 313242 更大），
还把基线 `ranger.grp` 写成 114242（实为 136412，114242 是 9-MOD 共享的 pascal 家族尺寸）。

**Decision**

对 books 涉及的 **8 项**排名，全部用脚本扫 20 个 MOD 实测：

```python
# 遍历 mods/*/data，对 hdgrp.eft.kdef.talk 取 idx/4，fight 取 glob 计数，
# ranger.grp 取 size，Person 取 (off[1]-off[0])//182
```

实测结果（含名次）：

| 指标 | books | 排名 | 前序 |
|------|------:|-----:|------|
| `hdgrp` | 696 | **1/20** | dream 484, pig3dos 412, BookCalamity 373 |
| `kdef` | 573 | **20/20（最少）** | 次少 1018（SweeOan/pascal/stronger） |
| `talk` | 6655 | **3/20** | RiverLake 8015, awaken 7717 |
| `eft` | 973 | **4/20** | BookCalamity 2857, mingdong 2268, pineapple 1378 |
| `fight` | 178 | **7/20** | BookCalamity 326 … pig3dos 180 |
| `Person` | 382 | **9/20** | BookCalamity 800, awaken 720, pineapple 720, mingdong 632 |
| `ranger.grp` | 126478 | **9/20** | BookCalamity 313242, pineapple 229680 … ptt 131084 |
| 零字节 fight | 2 | **4/20** | pineapple 115, RiverLake 44, ptt 7 |

**Consequences**

- 只有 `hdgrp 696` 与 `kdef 573（最少）` 是真「第 1 / 最」。
- `Person 382`、`ranger.grp 126478` 均为**第 9**，不得称「最大」。
- 每个排名必须在文档中附「前序 MOD 的具体值」，只写名次不写值 = 不可核验。

**Negative Constraint**

不得出现无实测支撑的「第 1 / 最多 / 最大」；不得用前序 MOD 文档里的数字当实测值。

---

## Negative Constraints（本 change 全局）

1. 不得以数量相等代替集合相等（`added`/`removed` 必须双向集合比对）。
2. 不得把 `save/` 19 与 `removed` 18 当成同一集合。
3. 不得把 `removed` 18 解释为「MOD 删除了 18 个文件」。
4. 不得把 B 类（同名异容）算进 `diff.md` 的 `added`。
5. 不得用 `fight` 总数比较 books 与 pineapple 的改动性质（必须四象限）。
6. 不得把 `hdgrp` 的 222 个零长段计为 gap / 缺陷。
7. 不得用 `动画` 作为 `Wugong` 字段名（实名 `武功动画&音效`）。
8. 不得用 `#CC.Effect` 当键数（须 `pairs` 得 53、`max键` 52）。
9. 不得用 `pairs(JY.Wugong[i])` 遍历记录（元表返回 0 字段）。
10. 不得出现无全 20-MOD 实测支撑的「第 1 / 最多 / 最大」断言。
11. 不得把 `Person 382` / `ranger.grp 126478` 称为最大（均为第 9）。
12. 不得把 4 个 `FILE_MISSING` 判为构建缺陷（源侧与基线侧均不存在）。
13. 不得把 `ranger.str` 判为多余产物（是 `mod_encoding.lua` 的生成物）。
14. 不得把 `thing.*` / `allsinbk.grp` 判为构建遗漏（是 `ModData.Resolve` 回退）。
15. 不得改 `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量、`reference/allmods/**`。
16. 不得改 `game/tools/**`（本 change 未发现工具缺陷）。
17. 不得为零字节 fight 生成占位图或补文件。
18. 不得用 `mod_audit.lua books` 位置参数（须 `--mod books`）。
19. 不得用 Lua pattern 的 `|` 交替（不支持）。

## Review Checklist

- [x] REQ-BKV-1 `add==实测 True`、`rem==实测 True`（双向集合相等）
- [x] REQ-BKV-2 `13+5+3+0=21` 闭合，且已声明 `save/` vs `removed` 不同集合
- [x] REQ-BKV-3 `172+12=184`，12 项非 fight 逐项溯源（11 源 + 1 生成）
- [x] REQ-BKV-4 `474 非空 + 222 零长 = 696`，头异常 0，`eft` 对照（零长 1）
- [x] REQ-BKV-5 64 字段 / 全 nil 0 / 名称 100/100 / 越界 2 max 55
- [x] REQ-BKV-6 `89+3=92`、`89+3+86=178`、`D∩B=0`、`D∩C=2`
- [x] REQ-BKV-7 B 占比 books 3.3% vs pineapple 97.8%
- [x] REQ-BKV-8 4 实例链路完整（代号→索引→姓名→文件）
- [x] REQ-BKV-9 957 条，分段/字段/唯一值三重闭合
- [x] REQ-BKV-10 8 项排名全部实测，含前序具体值
