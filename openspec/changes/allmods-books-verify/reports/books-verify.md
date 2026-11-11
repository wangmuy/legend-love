---
status: active
created: 2026-10-26
change: allmods-books-verify
slice: allmods-slice13
---
# books 审计报告（天书奇侠试玩）

> **MOD**：`kys-books` → `game/mods/books/`
> **规模**：源 525 文件 → `data 393` / `save 19` / `sound 84`
> **记录**：`Person 382` / `Thing 200` / `Scene 84` / `Wugong 100`
> **构建**：`data files=392, saves=19, sound=84, events=573, talk=6655`
> **结论**：**构建忠实，0 构建缺陷**；5 类 MOD 原始缺陷（不修）

---

## 0. 一句话结论

books 是 epic 的最后一个 MOD，也是**唯一在 `hdgrp` 上达到 696 条目（全 20 MOD 第 1）
并把 `kdef` 压到 573（全 20 MOD 最少）**的 MOD。它的 fight 分布
（A 89 / B 3 / C 86 / D 2）与 pineapple（A 2 / B 90 / C 62 / D 115）**互为极端**，
是本 epic 最有价值的 cross-MOD 对照样本。

---

## 1. 独特性 ①：`hdgrp` 696 —— 全 20 MOD 第 1，且 222 个零长段

| 维度 | books | 基线 | 全 20 MOD 排名 |
|------|------:|-----:|----------------|
| `hdgrp` 条目 | **696** | 115 | **1/20** |
| `hdgrp.idx` | 2784B | — | — |
| `hdgrp.grp` | 1233815B | — | — |

前序：dream 484 > pig3dos 412 > BookCalamity 373 > awaken 353 > pineapple 300。

**逐条结构解析**：

```
记录=696  PNG=0  RLE=474  零长=222  头异常=0
w: 1..82   h: 1..70
零长块: (215,54) (270,2) (273,165) (695,1)   Σ=222
```

- `474 + 222 = 696` ✅
- **头异常 0**：474 个非空段全部 `w>0, h>0`，上限 `w ≤ 82 / h ≤ 70`
- 基线含 **2 个 PNG**（非 RLE），books **全部 RLE**

**零长段的合法性（同家族对照）**：

| 文件 | 记录 | RLE | 零长 | 头异常 |
|------|-----:|----:|-----:|-------:|
| `books hdgrp` | 696 | 474 | **222** | 0 |
| `books eft` | 973 | 972 | **1** | 0 |

同一 `idx_grp_rle` 家族、同一解析器 ⇒ `hdgrp` 的 222 个零长段是**内容特征**
（多角色共用同一帧 → RLE 重复引用），非格式缺陷。
`format_spec.lua` 的 `verifyPair` 用 `b > a` 主动跳过零长段，
故 `format_spec --mod books` 报 `gaps=0`。

---

## 2. 独特性 ②：`kdef` 573 —— 全 20 MOD **最少**

```
books kdef: idx=2292B  entries=573  grp=150730B  last=150730  tail=0
```

`2292 / 4 = 573` ✅ 精确等于构建器报的 `events=573`。

全 20 MOD 排名：books **573（20/20，最少）**，
次少是 SweeOan/pascal/stronger 的 **1018**，最多是 dream 的 **4569**。
books 只有最少者的 **56%**。

**对照 `talk`（同一 MOD 内）**：

```
books talk: idx=26620B  entries=6655  grp=384396B  last=384396  tail=0
```

`kdef 573` + `talk 6655` ⇒ **每个事件平均 11.6 条对话**。
而 pineapple：`kdef 1068` + `talk 3596` ⇒ 平均 3.4 条/事件。
⇒ books 是「**少事件、长对话**」结构，pineapple 是「多事件、短对话」结构。

> 这与 books 是**试玩版**（剧情集中、条目精简）相符，非构建截断。
> 佐证：`kdef.*` 与 `talk.*` 均在 `diff.md` 的 `added` 列表（MOD 侧文件完整搬运）。

---

## 3. 独特性 ③：fight 分布与 pineapple **互为极端**

| 象限 | books | pineapple | 含义 |
|------|-----:|----------:|------|
| A 同名同容 | **89** | 2 | 与基线逐字节相同 |
| B 同名异容 | **3** | 90 | 同名但内容被改写 |
| C MOD 独有 | **86** | 62 | 基线没有 |
| D 零字节 | 2 | 115 | — |
| `fight` 总数 | **178** | 154 | — |
| **B/(A+B)** | **3.3%** | **97.8%** | 改写存量比例 |

自洽校验（全部成立）：

```
A + B     = 89 + 3      = 92   = 基线组数   ✅
A + B + C = 89 + 3 + 86 = 178  = MOD 组数   ✅
D ∩ B = 0     D ∩ C = 2
```

**B 象限独立验证**（第二路径）：md5 比对得 fight 同名异容 **6 文件 = 3 组**
（`fight003` / `fight037` / `fight088`）——
与四象限脚本的 `B=3` 精确一致，排除脚本自证。

**结论**：

- books = **保留基线 + 新增增量**（89/92 未动，86 组新增）
- pineapple = **几乎全部改写存量**（90/92 被改写）

⚠ `fight` 总数接近（178 vs 154），若只看总数会误判「改动量类似」，
实际**性质完全相反**。这是本 epic 中「不能用总数代替四象限」的最强论据。

---

## 4. 独特性 ④：`FILE_MISSING` 4 个**被引用**的真实实例 —— epic 首个

`Person.头像代号` 引用 **174 个**不同代号（min 0 / max 185），其中 **4 个文件不存在**：

| 代号 | 引用者 | 姓名 | 缺失文件 | 源侧 | 基线侧 |
|-----:|-------:|------|----------|:----:|:------:|
| 30 | `Person[30]` | 風清揚 | `fight030.grp/.idx` | MISSING | MISSING |
| 39 | `Person[39]` | 石中玉 | `fight039.grp/.idx` | MISSING | MISSING |
| 66 | `Person[66]` | 段正淳 | `fight066.grp/.idx` | MISSING | MISSING |
| 110 | `Person[122]` | 張召重 | `fight110.grp/.idx` | MISSING | MISSING |

另有 4 个**未被引用**的缺失：`fight052/111/112/113`（引用 0 次）。

```
book    被引用但缺失: 4  (30,39,66,110)
pineapple 被引用但缺失: 0
```

⇒ books 是 epic 中**首个**「被引用但文件缺失」的真实实例
（pineapple 为 0；Dragon 的 1 个缺失未被引用）。

**为何不修**：补 4 个 fight 包 = 改源数据 = 禁用路径；
且缺失在源目录与基线目录**均存在** ⇒ 是 MOD 作者的原始状态，
构建器行为正确（不凭空造文件）。

**运行时表现**：`PicGetXY` 返回 `0,0`（无图），**不崩溃**。
与 `ZERO_BYTE` **不可区分**（两者返回值相同）：

```
fight104: grp=0 idx=0        PicGetXY=0x0  pcall=true
fight030: grp=MISSING        PicGetXY=0x0  pcall=true
fight400: grp=MISSING(人造)  PicGetXY=0x0  pcall=true   <-- 负对照
```

分支归属靠**文件事实 + 代码路径**（`lib_love.lua:435` 早退 vs `:270-273` 索引失败）。

---

## 5. 独特性 ⑤：`ranger.grp` 比基线**更小**（126478 < 136412）

| 维度 | 基线 | books | 判定 |
|------|-----:|------:|------|
| `ranger.grp` | 136412 | **126478** | **变小** |
| Person | 320 | **382** | 变多 |
| Thing | 200 | 200 | 同 |
| Scene | 84 | 84 | 同 |
| Wugong | 93 | **100** | 变多 |
| Shop | 3 | 3 | 同 |

**反直觉点**：`Person` 更多（382 > 320）却 `grp` 更小 ——
因为基线 Thing 段更大（`52000` vs books `38000`），Scene 段也更小
（`4368` vs `5208`）。五段 offsets：

```
books:    [836, 70360, 108360, 112728, 126328, 126478]
seglen:   [     69524,  38000,   4368,  13600,    150]
reclen:   [       182,    190,     52,    136,     50]
count:    [       382,    200,     84,    100,      3]   余数全 0 ✅

baseline: [836, 65476, 117476, 122684, 136262, 136412]
seglen:   [     64640,  52000,   5208,  13578,    150]
```

`ranger.grp` 全 20 MOD 排名：books **126478 = 第 9**（非最大）。
前序：BookCalamity 313242 > pineapple 229680 > mingdong 223688 > awaken 207180 >
pig3dos 191828 > Dragon 174230 > dream 132270 > ptt 131084 > **books 126478**。

---

## 6. 独特性 ⑥：`ranger.str` 957 条侧表 —— hint 占位符方案

`ranger.grp` 的字符串字段被替换为定宽 hint（`P0000`/`N0001`/…），
真实 UTF-8 值写入 `ranger.str`（源中不存在，由 `tools/mod_encoding.lua` 生成）。

```
总行数: 964
有效条目: 957
分段: Person 419 + Thing 368 + Scene 72 + Wugong 98    = 957 ✅
字段: Name 670 + Nick 119 + Desc 168                   = 957 ✅
唯一值 934 / 重复 23（段内去重所致）
```

**为何必须这样做**：Big5 字符 2 字节、UTF-8 BMP 字符 3 字节。
定宽字段（10/20/30 字节）装不下 UTF-8 —— 就地重编码会截断 **41%** 的字符串，
而截断是明令禁止的。hint 方案保持记录布局与文件大小**完全不变**。

**回填验证**：

```
ranger.grp @844: "P0000"  --LoadRecord(0)-->  JY.Person[0]["姓名"] = 古天奇
ranger.grp @854: "N0001"  --LoadRecord(0)-->  JY.Person[0]["外号"] = 天下奇男子
Person[1]   = 胡斐 / 雪山飛狐
Person[381] = 閻基 / 毒手藥王
```

⚠ **陷阱**：直接读 `ranger.grp` 会看到 `P0000`，那是**设计内占位符**，
判据必须用**运行时**取值。

---

## 7. 独特性 ⑦：`diff.md` 双向集合相等 + `removed` 精确三分法

```
diff.md added: 184   removed: 21
实测 MOD 独有: 184   实测基线独有: 21
add == mod_only ?   True   (双向差集为空)
rem == base_only ?  True   (双向差集为空)
```

**`added` 184 拆解**：

```
172（86 fight 组 × 2）+ 12（非 fight）= 184
非 fight 12: cloud.grp/idx  end.png  kdef.grp/idx  kysmod.ini  open.png
             ranger.str  talk.grp/idx  title.grp/idx
溯源: 11 项在源 resource/（kysmod.ini 在根），ranger.str 源中不存在（构建生成）
```

**`removed` 21 三分法**：

| 类别 | 数量 | 证据 |
|------|-----:|------|
| 槽改道到 `save/` | **13** | 与源 `save/` md5 **13/13 全同** |
| 槽位完全缺席（走回退） | **5** | 源 `save/` 中**同样不存在** |
| 模板回退 | **3** | `thing.grp/.idx`、`allsinbk.grp`，源与产物均无 |
| 真删除 | **0** | — |
| 合计 | **21** | ✅ |

⚠ **两集合不同**（必须声明）：

```
save/ 有而 removed 无: d11 d6 r11 r6 s11 s6   （基线 data/ 本无这些槽）
removed 有而 save/ 无: d2 d3                   （只在基线 data/，源未提供）
```

**同名异容 27 个不计入 add/remove**（同时存在于两侧）：
6 个 fight 文件（= 3 组）+ 21 个非 fight。其中：
- 20 个与源 `save/`/`resource/` **md5 相同**
- `ranger.grp` 因 UTF-8 编码转换而不同（**预期**）
- `smap.*`/`wmap.*` 来自资源别名转换（`sdx→smap.idx` 等，md5 全同）

---

## 8. 全 20 MOD 排名汇总（books 相关 8 项，全部实测）

| 指标 | books | 排名 | 前序 |
|------|------:|-----:|------|
| `hdgrp` | 696 | **1/20** | dream 484, pig3dos 412, BookCalamity 373 |
| `kdef` | 573 | **20/20（最少）** | 次少 1018；最多 dream 4569 |
| `talk` | 6655 | **3/20** | RiverLake 8015, awaken 7717 |
| `eft` | 973 | **4/20** | BookCalamity 2857, mingdong 2268, pineapple 1378 |
| `fight` | 178 | **7/20** | BookCalamity 326 … pig3dos 180 |
| `Person` | 382 | **9/20** | BookCalamity 800, awaken 720, pineapple 720 |
| `ranger.grp` | 126478 | **9/20** | BookCalamity 313242 … ptt 131084 |
| 零字节 fight | 2 | **4/20** | pineapple 115, RiverLake 44, ptt 7 |

**只有 `hdgrp` 与 `kdef` 是真「第 1 / 最」**。
`Person 382` 与 `ranger.grp 126478` 均为**第 9**，不得称「最大」。

---

## 9. 缺陷清单

| # | 项 | 归属 | 处置 |
|---|----|------|------|
| 1 | `fight030/039/066/110` 被 4 NPC 引用但文件不存在（源与基线均缺） | **MOD 原始缺陷** | 不修（改源 = 禁用路径） |
| 2 | `fight052/111/112/113` 文件不存在但未被引用 | MOD 冗余空位 | 不修 |
| 3 | `fight104/164` 零字节（源侧亦 0B） | MOD 作者置零 | 不修；不生成占位图 |
| 4 | `kysmod.ini` 的 `SOUND3D` 无映射 | 设计内（`SECTION_MAP.music` 无此键） | 不修 |
| 5 | `Wugong["武功动画&音效"]` 2 条 `>52`（`max=55`） | 与 pineapple 同类（后者 62 条 / max 83） | epic spike `allmods-effect-table` |

**构建引入缺陷：0。工具缺陷：0。**

---

## 10. 机器可核验摘要

```bash
cd game && rm -f active_mod.txt

# 构建与机器验证
lua tools/mod_build.lua kys-books
#   -> data files=392, saves=19, sound=84, events=573, talk=6655
lua tools/mod_audit.lua --mod books --evidence
#   -> total=525 in_product=495 not_in_product=30 unclassified=0 bad_evidence=0
#      evidence: checked=8 failed=0
lua tools/format_spec.lua --mod books
#   -> formats=12 checked=287 gaps=0
MOD_SLUG=books lua tools/mod_check_one.lua
#   -> PERSON=382 THING=200 SCENE=84 WUGONG=100 HERO=古天奇 STRINGS=OK EVENTS=OK SAVE=OK

# 启动链路（5 个位置参数均为期望值）
lua tests/unit/boot_one_mod.lua books 382 200 84 100 古天奇
#   -> 12 × [PASS] ; RESULT books: OK
```

审计面覆盖：`diff.md` 双向集合、`removed` 三分法、`added` 溯源、`hdgrp` 696 逐条、
`Wugong` 100 字段、fight 四象限、`FILE_MISSING` 引用链、`ranger.str` 957 条、
8 项排名实测。**全部通过。**
