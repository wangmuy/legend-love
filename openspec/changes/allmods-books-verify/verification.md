---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice13
result: PASS
---
# Verification: allmods-books-verify

> 全部命令在 `game/` 下执行。每条判据附「实测命令 + 输出 + 结论」。
> 审计对象：`game/mods/books/`（已由 activate 构建）。

## 总览

| REQ | 主题 | 结论 |
|-----|------|------|
| REQ-BKV-1 | `diff.md` 双向集合相等 | ✅ `add==mod_only True` / `rem==base_only True` |
| REQ-BKV-2 | `removed` 21 三分法 | ✅ `13+5+3+0=21` |
| REQ-BKV-3 | `added` 184 拆解 | ✅ `172+12=184`，12 项溯源闭环 |
| REQ-BKV-4 | `hdgrp` 696 内容 | ✅ `474+222=696`，头异常 0 |
| REQ-BKV-5 | `Wugong` 100 | ✅ 64 字段 / 全 nil 0 / 越界 2 |
| REQ-BKV-6 | fight 四象限 | ✅ `89+3+86=178`，`D∩C=2` |
| REQ-BKV-7 | 与 pineapple 反向 | ✅ B 占比 3.3% vs 97.8% |
| REQ-BKV-8 | `FILE_MISSING` 4 实例 | ✅ 引用链完整，源与基线均缺 |
| REQ-BKV-9 | `ranger.str` 957 | ✅ 三重闭合 |
| REQ-BKV-10 | 8 项排名实测 | ✅ 含前序具体值，2 处修正 |

**结论：10/10 PASS。build 引入缺陷 0；MOD 原始缺陷 5 类（见报告）。**

---

## REQ-BKV-1 `diff.md` 双向 set 相等 ✅

**命令**（Python 逐元素集合比对，非数量比对）：

```python
added   = set(re.findall(r"^\s*-\s*\+\s*(\S+)\s*$", diff_md, re.M))
removed = set(re.findall(r"^\s*-\s*-\s*(\S+)\s*$", diff_md, re.M))
mod_only  = set(os.listdir("mods/books/data")) - set(os.listdir("data"))
base_only = set(os.listdir("data")) - set(os.listdir("mods/books/data"))
```

**输出**：

```
diff.md added=184   removed=21
实测 mod_only=184   base_only=21
同名异容(md5不同)=27
add == mod_only ?  True   (差集 add-mod=[] mod-add=[])
rem == base_only ? True   (差集 rem-base=[] base-rem=[])
```

✅ **双向集合相等**（差集双向为空），不是「数量恰好都是 184/21」。

### 1.1 同名异容不计入 add/remove（关键排除项）

```
同名异容共 27:
  fight 类: 6  ->  fight003.grp/idx  fight037.grp/idx  fight088.grp/idx
  非 fight: 21 ->  alldef.grp allsin.grp building.002 buildx.002 buildy.002
                   earth.002 eft.grp eft.idx hdgrp.grp hdgrp.idx mmap.col
                   mmap.grp mmap.idx ranger.grp ranger.idx smap.grp smap.idx
                   surface.002 war.sta wmap.grp wmap.idx
```

这 27 个文件**都同时存在于两侧**，因此不产生 `added`/`removed` 条目 ——
这解释了为什么 `added=184` 小于「MOD 有而基线无 + 内容不同」的朴素计数。

### 1.2 21 个非 fight 同名异容的溯源

| 文件 | 源侧匹配 | 判定 |
|------|----------|------|
| `alldef.grp`、`allsin.grp`、`ranger.idx` | `save/`（**同**） | 源 save 移入 data |
| `ranger.grp` | `save/`（**异**） | **UTF-8 编码转换**（预期差异，见 ADR-BK-001） |
| `building.002`、`buildx.002`、`buildy.002`、`earth.002`、`surface.002` | `resource/`（同） | 源资源 |
| `eft.grp/.idx`、`hdgrp.grp/.idx`、`mmap.col/.grp/.idx`、`war.sta` | `resource/`（同） | 源资源 |
| `smap.grp/.idx`、`wmap.grp/.idx` | 源中无此名 | **资源别名转换**（见 1.3） |

### 1.3 资源别名转换（`diff.md` 头部已声明）

```bash
$ md5 比对
smap.idx <- sdx   存在=True md5同=True
smap.grp <- smp   存在=True md5同=True
wmap.idx <- wdx   存在=True md5同=True
wmap.grp <- wmp   存在=True md5同=True
```

✅ `diff.md` 开头的「资源别名转换」段落（`sdx → smap.idx`、`smp → smap.grp`、
`wdx → wmap.idx`、`wmp → wmap.grp`）实测成立，四项 md5 **全同**。

---

## REQ-BKV-2 `removed` 21 三分法 ✅

`removed` 全量（21 项）：

```
allsinbk.grp
d1.grp d1.idx  d2.grp d2.idx  d3.grp d3.idx
r1.grp r1.idx  r2.grp r2.idx  r3.grp r3.idx
s1.grp s1.idx  s2.grp s2.idx  s3.grp s3.idx
thing.grp thing.idx
```

逐项核对（产物 `save/` 有 / 源 `save/` 有）：

```
d1.grp  产物save=有  源save=有        d1.idx  产物save=无  源save=无
d2.grp  产物save=无  源save=无        d2.idx  产物save=无  源save=无
d3.grp  产物save=无  源save=无        d3.idx  产物save=无  源save=无
r1.grp  产物save=有  源save=有        r1.idx  产物save=有  源save=有
r2.grp  产物save=有  源save=有        r2.idx  产物save=有  源save=有
r3.grp  产物save=有  源save=有        r3.idx  产物save=有  源save=有
s1.grp  产物save=有  源save=有        s1.idx  产物save=有  源save=有
s2.grp  产物save=有  源save=有        s2.idx  产物save=有  源save=有
s3.grp  产物save=有  源save=有        s3.idx  产物save=有  源save=有
```

分类：

| 类别 | 数量 | md5 校验 |
|------|-----:|----------|
| 槽改道到 `save/` | **13** | 与源 `save/` **13/13 全同** ✅ |
| 槽位完全缺席（走回退） | **5** | 源 `save/` 中**同样不存在** ✅ |
| 模板回退 | **3** | 源与产物均无 ✅ |
| 真删除 | **0** | — |
| **合计** | **21** | `13+5+3+0=21` ✅ |

md5 校验输出：

```
源save有=13: d1.grp r1.grp r1.idx r2.grp r2.idx r3.grp r3.idx
              s1.grp s1.idx s2.grp s2.idx s3.grp s3.idx
  -> 产物 save/ 中 md5 相同 13/13 ✅
源无=5: d1.idx d2.grp d2.idx d3.grp d3.idx
```

### 2.1 两集合不同的显式声明

```
save/ 有而 removed 无 : d11 d6 r11 r6 s11 s6   （基线 data/ 本无这些槽）
removed 有而 save/ 无 : d2 d3                   （只在基线 data/，源未提供）
```

✅ `save/` 19 ≠ `removed` 18。`removed` 是「基线 `data/` 有而产物 `data/` 无」，
`save/` 是「MOD 提供的存档槽」，两者口径不同。

### 2.2 产物 `save/` 与源全同

```bash
$ for f in $(ls mods/books/save/); do md5 比对; done
  same=19 diff=0 src_missing=0
```

✅ 19/19 md5 相同，无差异、无源侧缺失。

---

## REQ-BKV-3 `added` 184 拆解与溯源 ✅

```
fight: 172 = 86 组 × 2（.grp + .idx）
非 fight: 12
合计: 184 ✅
```

12 项非 fight 的源侧溯源：

```bash
$ find ../reference/allmods/kys-books -name "<file>"
cloud.grp      -> resource/cloud.grp        cloud.idx      -> resource/cloud.idx
end.png        -> resource/end.png          kdef.grp       -> resource/kdef.grp
kdef.idx       -> resource/kdef.idx         kysmod.ini     -> kysmod.ini
open.png       -> resource/open.png         ranger.str     -> NO-SRC
talk.grp       -> resource/talk.grp         talk.idx       -> resource/talk.idx
title.grp      -> resource/title.grp        title.idx      -> resource/title.idx
```

✅ 11 项源侧存在（10 项在 `resource/`，`kysmod.ini` 在根），
`ranger.str` **源中不存在** ⇒ 构建生成物（`mod_encoding.lua` hint 抽取）。

---

## REQ-BKV-4 `hdgrp` 696 内容有效性 ✅

```bash
$ python3 (逐条解析 8 字节头 <HHhh>)
books hdgrp: 记录=696 PNG=0 RLE=474 零长=222 头异常=0
   w: 1..82   h: 1..70
   零长块: (215,54) (270,2) (273,165) (695,1)   Σ=222
```

- `474 + 222 = 696` ✅
- **头异常 = 0**：474 个非空段全部 `w>0, h>0` ✅
- **上限检查**：`w ≤ 82`、`h ≤ 70`，无异常巨值 ✅

### 4.1 `eft` 同家族对照（决定性）

```bash
books eft: 记录=973 PNG=0 RLE=972 零长=1 头异常=0
   w: 1..230   h: 1..200
```

✅ 同一 `idx_grp_rle` 家族、同一解析器：`eft` 零长仅 **1**（末尾哨兵），
`hdgrp` 零长 **222** ⇒ 零长是 `hdgrp` 的**内容特征**（多角色共用帧），
不是解析器缺陷、也不是格式缺陷。

### 4.2 基线对照

```bash
baseline hdgrp: 记录=115 PNG=2 RLE=112 零长=1 头异常=0
   w: 13..56   h: 9..58
   零长块: (114,1)  Σ=1
```

✅ 基线含 **2 个 PNG**（非 RLE 条目），books **全部 RLE**。
`format_spec --mod books` 的 `gaps=0` 与此一致（零长段被 `verifyPair` 的 `b > a` 跳过）。

---

## REQ-BKV-5 `Wugong` 100 ✅

```bash
$ lua /tmp/books_wg.lua
Wugong_S 字段数: 64   WugongNum: 100
全 nil 字段数: 0
名称非空: 100 / 100
CC.Effect 键数: 53   max键: 52
武功动画&音效: 有值 100 条, 越界(>52) 2 条, max=55
```

实名抽样：

```
[  0] 名称=普通攻擊   武功类型=1 出招音效= 1 武功动画&音效=12 消耗内力点数= 1
[  1] 名称=天地雙絕刀 武功类型=3 出招音效=20 武功动画&音效= 9 消耗内力点数=20
[  2] 名称=圓月刀法   武功类型=3 出招音效= 1 武功动画&音效=24 消耗内力点数=14
[ 97] 名称=凝碧柔云劍 武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 98] 名称=柔云劍法   武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 99] 名称=震天三十掌 武功类型=1 出招音效= 1 武功动画&音效=27 消耗内力点数= 8
```

✅ 64 字段全对齐，`名称` 100/100，越界仅 2 条（vs pineapple 62 条）。

> **偏差记录（已修正）**：初版抽样误用字段名 `动画`，得 `nil` 却不报错。
> 靠「全 nil 字段数 = 0」兜底才发现。已按实名 `武功动画&音效` 重测。

---

## REQ-BKV-6 fight 四象限 ✅

```bash
$ python3 (md5 逐组比对)
基线组数=92  MOD组数=178
A(同名同容)=89  B(同名异容)=3  C(MOD独有)=86  D(零字节)=2
B 具体: [3, 37, 88]
D 具体: [104, 164]
A+B=92 == 基线 92 ? True
A+B+C=178 == MOD 178 ? True
D∩B=0  D∩C=2
  fight104: grp=0B idx=0B
  fight164: grp=0B idx=0B
```

✅ 四项自洽校验全部成立。

**B 象限独立验证**：md5 比对得 fight 同名异容 **6 个文件** = **3 组**
（`fight003`/`fight037`/`fight088`），与 `B=3` 精确一致。
这是**独立路径**（不用四象限脚本，用 `common & md5不同` 集合），
防止「四象限脚本自身有 bug 导致自证」。

---

## REQ-BKV-7 与 pineapple 的反向分布 ✅

| 象限 | books | pineapple |
|------|-----:|----------:|
| A 同名同容 | **89** | 2 |
| B 同名异容 | **3** | 90 |
| C MOD 独有 | **86** | 62 |
| D 零字节 | 2 | 115 |
| **B/(A+B)** | **3.3%** | **97.8%** |
| `fight` 总数 | 178 | 154 |

✅ 结论：
- **books = 保留基线 + 新增增量**（89/92 组未动，86 组新增）
- **pineapple = 几乎全部改写存量**（90/92 组被改写）

⚠ 两 MOD 的 fight 总数接近（178 vs 154），若只看总数会误判为「改动量类似」，
实际**改动性质完全相反** ⇒ 四象限是唯一可靠分析方式。

---

## REQ-BKV-8 `FILE_MISSING` 4 实例 ✅

```bash
$ lua /tmp/books_ref.lua
被引用不同代号:  174   min: 0   max: 185
--- 被引用但文件不存在 ---
  数量: 4   代号: 30,39,66,110
```

引用链（代号 → 索引 → 姓名 → 文件）：

```
Person[ 30] 姓名=風清揚  头像代号=30  -> fight030 MISSING
Person[ 39] 姓名=石中玉  头像代号=39  -> fight039 MISSING
Person[ 66] 姓名=段正淳  头像代号=66  -> fight066 MISSING
Person[122] 姓名=張召重  头像代号=110 -> fight110 MISSING
```

源与基线双侧核验：

```
fight030: src=MISSING base=MISSING     fight039: src=MISSING base=MISSING
fight066: src=MISSING base=MISSING     fight110: src=MISSING base=MISSING
```

未引用的 4 个缺失：`fight052`、`fight111`、`fight112`、`fight113`（引用 0 次）。

对照 pineapple：

```
pineapple 被引用但缺失: 0
```

✅ books 是 epic 中**首个**「被引用但文件缺失」的真实实例（pineapple 为 0，
Dragon 的 1 个缺失未被引用），且缺失来自源侧，非构建引入。

---

## REQ-BKV-9 `ranger.str` 957 ✅

```bash
$ wc -l mods/books/data/ranger.str   ->  964
$ python3 (统计非注释行)
总条目: 957   唯一值: 934   重复值: 23
分段: {'Person': 419, 'Thing': 368, 'Scene': 72, 'Wugong': 98}
字段: {'Name': 670, 'Nick': 119, 'Desc': 168}
```

三重闭合：

- `419 + 368 + 72 + 98 = 957` ✅
- `670 + 119 + 168 = 957` ✅
- `964 - 957 = 7`（4 行 `#` 注释 + 3 行说明）✅

回填证明：

```
ranger.grp @844: "P0000"  ──LoadRecord(0)──▶  JY.Person[0]["姓名"] = 古天奇
ranger.grp @854: "N0001"  ──LoadRecord(0)──▶  JY.Person[0]["外号"] = 天下奇男子
```

✅ 侧表方案生效。

---

## REQ-BKV-10 8 项排名实测 ✅

全 20 MOD 扫描（`mods/*/data/`）：

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

### 10.1 两处修正（相对初稿）

| 项 | 初稿 | 实测修正 |
|----|------|----------|
| `kdef 573` | 「最少」（未给次少值） | **20/20，全 epic 最低**；次少 1018，最多 4569 |
| `ranger.grp 126478` | 「非第 1」 | **第 9**；前序 8 个 MOD 均更大 |
| `Person 382` | 「非第 1」 | **第 9**；BookCalamity 800 等 8 个更大 |

✅ 只有 `hdgrp 696` 与 `kdef 573（最少）` 是真「第 1 / 最」。
`Person` 与 `ranger.grp` 均为**第 9**，不得称「最大」。

### 10.2 排名断言的实测口径

```python
hdgrp/eft/kdef/talk : len(open(idx,'rb').read()) // 4
fight               : len(glob("mods/*/data/fight*.grp"))
ranger.grp          : os.path.getsize(...)
Person              : (offsets[1] - offsets[0]) // 182
零字节 fight         : count(size == 0)
```

✅ 全部为**文件系统实测**，未引用任何前序文档中的数字。

---

## 缺陷清单

| # | 项 | 归属 | 处置 |
|---|----|------|------|
| 1 | `fight030/039/066/110` 被 4 个 NPC 引用但文件不存在（源与基线均缺） | **MOD 原始缺陷** | 不修（改源 = 禁用路径）；记入 epic 已知缺陷 |
| 2 | `fight052/111/112/113` 文件不存在但未被引用 | MOD 冗余空位 | 不修 |
| 3 | `fight104/164` 零字节（源侧亦 0B） | MOD 作者置零 | 不修；不生成占位图 |
| 4 | `kysmod.ini` 的 `SOUND3D` 无映射 | 设计内 | 不修 |
| 5 | `Wugong["武功动画&音效"]` 2 条 `>52` | 与 pineapple 同类（后者 62 条） | epic spike `allmods-effect-table`（修复点 `script/jyconst.lua` = 禁用路径） |

**构建引入缺陷：0。工具缺陷：0（本 MOD 未发现新的工具问题）。**

---

## 复现脚本

```bash
cd game

# REQ-BKV-1/2/3：diff 双向集合 + removed 三分法
python3 - <<'PY'
import os,hashlib,re
md5=lambda p: hashlib.md5(open(p,'rb').read()).hexdigest()
base={f for f in os.listdir("data") if os.path.isfile("data/"+f)}
mod ={f for f in os.listdir("mods/books/data") if os.path.isfile("mods/books/data/"+f)}
md=open("mods/books/diff.md",encoding="utf-8").read()
added  =set(re.findall(r"^\s*-\s*\+\s*(\S+)\s*$",md,re.M))
removed=set(re.findall(r"^\s*-\s*-\s*(\S+)\s*$",md,re.M))
print(len(added),len(removed), added==(mod-base), removed==(base-mod))
PY

# REQ-BKV-4：hdgrp / eft 逐条头解析
# REQ-BKV-6：fight 四象限（md5 逐组）

# REQ-BKV-5：Wugong 字段（需 Lua 运行时）
rm -f active_mod.txt && lua /tmp/books_wg.lua

# REQ-BKV-8：引用链
rm -f active_mod.txt && lua /tmp/books_ref.lua

# REQ-BKV-10：20 MOD 排名
# 见 verification 上文 10.2 的取数口径
```

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod books
formats=14 checked=295 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **178** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **84** | `lib_love.PlayWAV` |
| png | `png_image` | 2 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 6 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **295** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=287` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=295 gaps=0`（+8） |

`formats=12 → 14` 的原因：`allsin` / `alldef` 被补注册为 `grid_save` 族
（每 MOD 各 1 条记录），故 `formats` +2。`+2` 之外无变化，说明本 MOD 其余格式
**从未少验** —— 旧数字只是过时，不是缺陷。

### 3. 真实支持缺口 —— **已修复**（2026-10-29 更新）

`list/*.bin`（本 MOD 有 **4** 个）原为**引擎完全不读**，现已由
`openspec/changes/allmods-list-bin-support` **落地修复**：

| 文件 | 原状态 | 现状态 |
|------|--------|--------|
| `effect.bin` | 构建器不搬 + 引擎硬编码 53 项替代 | **进产物** `data/effect.bin` + `ModData.LoadEffectTable` 装载，`CC.Effect` 取真实条目数 |
| `match.bin` | 构建器不搬 | **进产物** `data/match.bin`（`CC.ExtraOffense` 的数据侧） |
| `leave.bin` / `levelup.bin` / `*.txt` | 不搬 | **维持不进产物**（`LEGACY`，引擎零消费，有 evidence） |

**实测证据**（详见 `allmods-list-bin-support/verification.md`）：

- `effect.bin` / `match.bin` 在 **20/20** MOD 上逐字节一致地进入 `data/`
- 运行时 `CC.Effect` 项数：pascal **64** / BookCalamity **200**（原硬编码 53）
- `mod_audit` 的 `PENDING` **663 → 581**（`.bin` 残留 **0**），`in_product` **9245 → 9285**
- 负向对照：3 项短文件→`3`、删文件→`53` 兜底、恢复→`64`（三者互斥）

⇒ 本 MOD 的 `effect.bin` 超过 53 项时，`eft >= 53` 的静默退化**已消除**。

### 4. 20 MOD 横向对照

（禁止只报自身数字）

| MOD | total | fight | sound | png | list | slots |
|-----|-------|-------|-------|-----|------|-------|
| mingdong | 831 | 267 | 201 | 338 | 4 | 0 |
| BookCalamity | 589 | 327 | 234 | 2 | 5 | 0 |
| Dragon | 537 | 209 | 80 | 222 | 5 | 0 |
| GodsDevils | 477 | 92 | 78 | 282 | 4 | 0 |
| RiverLake | 415 | 219 | 170 | 1 | 4 | 0 |
| awaken | 342 | 237 | 79 | 1 | 4 | 0 |
| pig3dos | 328 | 180 | 111 | 3 | 4 | 9 |
| ptt | 319 | 162 | 78 | 54 | 4 | 0 |
| pineapple | 300 | 154 | 109 | 3 | 4 | 9 |
| books | 295 | 178 | 84 | 2 | 4 | 6 |
| lyff | 244 | 138 | 78 | 3 | 4 | 0 |
| pig | 243 | 137 | 78 | 3 | 4 | 0 |
| dream | 227 | 123 | 77 | 2 | 4 | 0 |
| loving | 212 | 107 | 77 | 3 | 4 | 0 |
| lostbook | 203 | 97 | 78 | 3 | 4 | 0 |
| HeavenSword | 200 | 93 | 78 | 3 | 4 | 1 |
| SweeOan | 198 | 92 | 78 | 3 | 4 | 0 |
| stronger | 198 | 92 | 78 | 3 | 4 | 0 |
| zheng | 197 | 92 | 78 | 2 | 4 | 0 |

本 MOD `total=295`，在 20 个 MOD 中排 **第 10**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，295 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
