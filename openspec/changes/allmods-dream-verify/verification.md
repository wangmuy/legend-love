---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice14
result: PASS
---
# Verification: allmods-dream-verify

> 全部命令在 `game/` 下执行。审计对象 `game/mods/dream/`。

## 总览

| REQ | 主题 | 结论 |
|-----|------|------|
| REQ-DRMV-1 | `diff.md` 双向 set 相等 | ✅ 对称差**空集** |
| REQ-DRMV-2 | `removed 105` 四分法 | ✅ `9+9+84+3+0=105` |
| REQ-DRMV-3 | `added 156` 三分 | ✅ `142+1+13=156` |
| REQ-DRMV-4 | fight 五分类 | ✅ `A2/B49/E41/C71/D0`，`A+B=51≠92` |
| REQ-DRMV-5 | 三形态跨 MOD 对照 | ✅ books/pineapple/dream 三模式 |
| REQ-DRMV-6 | `hdgrp` 484 有效性 | ✅ `411 RLE+72 零长`，头异常 0 |
| REQ-DRMV-7 | `eft` 零改动 | ✅ md5 三重证明 |
| REQ-DRMV-8 | `ranger.str` 763 | ✅ 行/分段/字段三重闭合 |
| REQ-DRMV-9 | `save/` 27 vs 31 | ✅ 27/27 逐字节一致 |
| REQ-DRMV-10 | 8 项排名实测 | ✅ 全实测，`kdef` 唯一第 1 |

**结论：10/10 PASS，0 内容缺陷，0 工具缺陷。**

---

## REQ-DRMV-1 `diff.md` 双向 set 相等 ✅

```bash
$ python3 (解析 diff.md + 独立计算差集)
diff added=156  removed=105
实测 MOD独有=156  基线独有=105
add == 实测独有 ? True
rem == 实测基线独有 ? True
对称差 add: set()
对称差 rem: set()
```

✅ **集合相等**（不只是数量相等）：双向对称差均为空集。
判据：`added` 的 156 个文件名逐一 == `set(产物data) − set(基线data)`。

---

## REQ-DRMV-2 `removed` 105 的四分法闭合 ✅

```bash
$ python3 (分类 removed 105)
removed 总=105
  槽 .grp=9 -> ['d1.grp','d2.grp','d3.grp','r1.grp','r2.grp','r3.grp','s1.grp','s2.grp','s3.grp']
  槽 .idx=9 -> ['d1.idx','d2.idx','d3.idx','r1.idx','r2.idx','r3.idx','s1.idx','s2.idx','s3.idx']
  fight .grp=41 .idx=41  合计=82
  模板 thing=2 -> ['thing.grp','thing.idx']
  死文件=3 -> ['alldef.idx','allsin.idx','allsinbk.grp']
  Σ=105  == 105? True

四分法: 9(槽grp) + 9(槽idx) + 84(fight82 + thing2) + 3(死) = 105
```

| 类别 | 数量 | 机制 |
|------|-----:|------|
| 槽 `.grp` | **9** | 源提供 → 改道产物 `save/` |
| 槽 `.idx` | **9** | 源**不存在** → `SeedSaveSlot` 按需播种 |
| 回退原版战斗 | **82** | 41 组 × `.grp`/`.idx` |
| 回退原版模板 | **2** | `thing.grp`、`thing.idx` |
| 死文件 | **3** | `alldef.idx`、`allsin.idx`、`allsinbk.grp` |
| 真删除 | **0** | — |
| **合计** | **105** | ✅ |

### 2.1 槽 `.grp` / `.idx` 是两类（不是同类）

```bash
$ python3
  9 槽 .grp 在产物save: 9/9
  9 槽 .grp 在源save  : 9/9
  9 槽 .idx 在源save  : 0/9   ← 源一个都没有
```

### 2.2 `SeedSaveSlot` 实测

```bash
$ rm -f active_mod.txt && lua /tmp/dream_seed.lua
Resolve(save/r1.idx) =	data/save/r1.idx
SaveDir() =	mods/dream/save/
SeedSaveSlot(1) -> ok=mods/dream/save/r1.idx path=nil
SeedSaveSlot(2) -> ok=mods/dream/save/r2.idx path=nil
SeedSaveSlot(3) -> ok=mods/dream/save/r3.idx path=nil
```

> **返回值勘误**：`SeedSaveSlot(id)` 返回**单个路径值**（成功）或 `nil`（失败），
> 不是 `ok, path` 两值。上面的 `ok=` 是探针脚本的变量名，`path=nil` 是因为
> 第二返回值根本不存在。判定成功须看**第一返回值非 nil**。

播种结果核验：

```bash
$ python3 (md5)
ranger.idx md5=08e488fefacf2e1fe43a757ad609bcab size=24
r1.idx size=24 md5==ranger ? True
r2.idx size=24 md5==ranger ? True
r3.idx size=24 md5==ranger ? True
```

✅ 播种内容 == `data/ranger.idx`（权威基础模板优先，`mod_data.lua:190-194`）。
探针文件已清理（`rm -f mods/dream/save/r{1,2,3}.idx`），`save/` 恢复 27。

### 2.3 41 组被删战斗

```
43,46,49,50,56,57,58,59,60,61,62,63,64,65,67,68,70,71,
76,77,78,80,81,82,83,85,86,87,88,90,91,92,93,95,96,97,98,99,101,102,109
```

（注意：`79` **不在**被删列表，它是 B 象限「同名异容」，见 REQ-DRMV-4）

---

## REQ-DRMV-3 `added` 156 的三分拆解 ✅

```bash
$ python3
added=156  fight.grp=71 fight.idx=72  非fight=13
  idx 独有组（有 idx 无 grp）: [23]
  grp 独有组（有 grp 无 idx）: []
  交集=71

fight23.idx 是否在 added? True
  产物 fight23.idx 存在=True   产物 fight23.grp 存在=False
  源   fight23.idx 存在=True   源   fight23.grp 存在=False

分解: 71 组配对 ×2 = 142 + 孤儿 fight23.idx 1 + 非fight 13 = 156
```

✅ `142 + 1 + 13 = 156`

**孤儿 `fight23.idx` 定性**：MOD 作者删了 `fight23.grp` 但**漏删** `fight23.idx`。
流水线忠实保留（计入 `REQUIRED`、`in_product=true`），引擎**不读**（无对应 grp）。

13 项非 fight 溯源：

```bash
$ python3 (在源树中查找每个 added 非 fight 文件)
    cloud.grp        -> ['resource/']        cloud.idx        -> ['resource/']
    icon.png         -> ['resource/']        kdef.grp         -> ['resource/']
    kdef.idx         -> ['resource/']        kysmod.ini       -> ['root']
    new.idx          -> ['resource/']        open.png         -> ['resource/']
    ranger.str       -> NO-SRC(构建生成)
    talk.grp         -> ['resource/']        talk.idx         -> ['resource/']
    title.grp        -> ['resource/']        title.idx        -> ['resource/']
```

✅ 11 项在 `resource/`、1 项（`kysmod.ini`）在根目录、1 项（`ranger.str`）源中不存在（构建生成）。

### 3.1 偏差记录（推翻 proposal 初稿）

proposal 初稿写「`142（71 组 fight × 2）+ 14 非 fight`」——**实测为误**。
fight `.idx` 在 `added` 中有 **72** 个（`.grp` 只有 71），差集恰为 `{23}`。
正确分解是 `142 + 1（孤儿） + 13（非 fight） = 156`。已修正。

---

## REQ-DRMV-4 fight 五分类 ✅

```bash
$ python3 (md5 分象限)
A=2 B=49 E=41 C=71 D=0
A+B+E=92 (应=92=92)  True
A+B+C=122 (应=122=122) True
A+B=51 != 92 -> 四象限失效: True
E == removed 中 fight.grp 条数 ? True
B 组: [1..29(缺11,30), 31..38, 44,45,47,48,51,53,54,55,69,79,84,94,100]
E 组: [43,46,49,50,56..65,67,68,70,71,76..83,85..88,90..93,95..99,101,102,109]
```

| 象限 | 定义 | 数量 |
|------|------|-----:|
| A | 保留（同名同容，md5 相等） | **2** |
| B | 改写（同名异容，md5 不同） | **49** |
| E | **删除（基线有、MOD 无）** | **41** |
| C | 新增（MOD 独有） | **71** |
| D | 零字节 | **0** |

三重自洽：`A+B+E=92` ✅、`A+B+C=122` ✅、`92−41+71=122` ✅

**四象限失效证明**：`A+B = 2+49 = 51 ≠ 92`。
若沿用 books/pineapple 的 `A+B == 基线组数` 判据，dream 会被**误判为缺陷**。
必须加删除象限 `E`（`E=41` 与 `removed` 中 `fight*.grp` 条数**独立计算一致**）。

---

## REQ-DRMV-5 三种 fight 形态跨 MOD 对照 ✅

| MOD | 形态 | A | B | E(删) | C(增) | D(零) | `A+B` | 判据 |
|-----|------|---:|---:|---:|---:|---:|------:|:----:|
| books | 保留 + 新增增量 | 89 | 3 | 0 | 86 | 2 | 92 | ✅ |
| pineapple | 几乎全改写 | 2 | 90 | 0 | 62 | 115 | 92 | ✅ |
| **dream** | **增删并行** | **2** | **49** | **41** | **71** | **0** | **51** | **✗** |

✅ 三种模式互不相同 ⇒ 任何单一计数口径都会漏项，必须五分类。

---

## REQ-DRMV-6 `hdgrp` 484 内容有效性 ✅

```bash
$ python3 (解析 hdgrp.idx / hdgrp.grp)
hdgrp: 记录=483 PNG=0 RLE=411 零长=72 头异常=0
   w: 1..58  h: 1..71
   offs[0]=2895 last=944448 grp=944448 tail=0 严格递增=True
零长块: [(381, 69), (480, 3)]  Σ=72
```

- `484 offsets` ↔ `483 段`（末 offset `944448` 是**哨兵**）✅
- `411 RLE + 72 零长 = 483` ✅
- **头异常 = 0** ✅
- 尺寸上限 `w 1..58` / `h 1..71` ✅
- 零长块：段 `381..449`（69 段）+ 段 `480..482`（3 段）= **72** ✅

基线对照：

```bash
baseline hdgrp: 记录=114 PNG=2 RLE=112 零长=0 头异常=0 w:13..56
```

`eft` 反证（同一 MOD、同一 `idx_grp_rle` 家族、同一解析器）：

```bash
dream eft: 记录=713 PNG=0 RLE=713 零长=0 头异常=0 w:1..214 h:1..189
```

✅ `hdgrp` 有 72 零长而 `eft` 有 0 ⇒ 零长是 `hdgrp` 的**内容特征**（共享/占位帧），
非解析器或格式缺陷。与 `format_spec --mod dream` 的 `gaps=0` 一致
（`format_spec.lua:232` `idx_grp_rle`；`verifyPair` 用 `b > a` 跳过零长）。

---

## REQ-DRMV-7 `eft` 零改动的三重证明 ✅

**证明 1 — md5 相同**

```bash
$ python3
eft.idx      dream==baseline ? True
eft.grp      dream==baseline ? True
  dream    eft.idx=2856B  eft.grp=691627B
  baseline eft.idx=2856B  eft.grp=691627B
```

**证明 2 — diff 缺席（排除「构建器回退基线」）**

```bash
$ grep -E "^\s*-\s*[-+]\s*eft\." mods/dream/diff.md
（无输出）
```

⇒ `eft.*` 既不在 `added` 也不在 `removed` ⇒ 产物侧**真实存在**，非回退。

**证明 3 — 大小相同**：`691627B == 691627B` ✅

**旁证**：源 `resource/eft.{idx,grp}` 与产物 md5 相同
（构建器未改动 —— 无字符串字段需编码转换）。

| MOD | eft | 与基线关系 |
|-----|----:|------------|
| **dream** | **714** | **md5 全同（零改动）** |
| books | 973 | 改动 |
| pineapple | 1378 | 改动 |
| mingdong | 2268 | 改动 |
| BookCalamity | 2857 | 改动 |

✅ dream 是 epic 中 `eft` 零改动的**唯一正样本**。

---

## REQ-DRMV-8 `ranger.str` 763 条完整性 ✅

```bash
$ python3 (跳过 # 注释行统计)
总行=770 有效=763 注释=7
分段: {'Person': 243, 'Thing': 343, 'Scene': 82, 'Wugong': 95} Σ= 763
字段: {'Name': 513, 'Nick': 82, 'Desc': 168} Σ= 763
唯一值=732 重复=31
```

**格式与首行**：

```bash
$ sed -n '1,5p' mods/dream/data/ranger.str
# ranger.str - MOD side string table (UTF-8)
# format: index,segment,record,field,value
# index is segment-local, matching the hint in ranger.grp
# Person
0000,Person,0,Name,隨小破
```

```bash
$ grep -n "^#" mods/dream/data/ranger.str
1:# ranger.str - MOD side string table (UTF-8)
2:# format: index,segment,record,field,value
3:# index is segment-local, matching the hint in ranger.grp
4:# Person
248:# Thing
592:# Scene
675:# Wugong
```

- 注释 **7** 行（3 表头 + 4 分段标记）✅
- 首个**数据**行在第 5 行 `0000,Person,0,Name,隨小破` ✅
- **逗号分隔** `id,段,索引,字段,值`（非 tab）✅

与 `encoding-report.md` 对齐：

```bash
$ grep "旁路表条目" mods/dream/encoding-report.md
| 旁路表条目 | 763 |
```

✅ 三重一致：报告 763 == 有效行 763 == 分段 Σ 763 == 字段 Σ 763。

> **陷阱**：`ranger.str` 是**逗号分隔**（books 亦同），
> 若按 tab 切分会得到 `len(p)<5`，误报「条目数 0」。本 change 已按 `,` 解析。

---

## REQ-DRMV-9 存档 `save/` 27 vs 源 31 ✅

```bash
$ python3 (清理探针后重新统计)
产物 save/ = 27   源 save/ = 31
  产物 .grp=27  .idx=0
  逐字节一致 = 27/27
  源独有 4: ['alldef.grp', 'allsin.grp', 'ranger.grp', 'ranger.idx']
    alldef.grp     源=  536800  产物data=  536800  md5同=True
    allsin.grp     源= 5996544  产物data= 5996544  md5同=True
    ranger.grp     源=  132270  产物data=  132270  md5同=False
    ranger.idx     源=      24  产物data=      24  md5同=True
```

27 个槽 `.grp` 覆盖 `d/r/s × {1,2,3,4,5,6,7,9,11}` —— **源缺 8 号槽**（作者删除）。

| 改道项 | md5 | 说明 |
|--------|:---:|------|
| `alldef.grp` | **同** | 纯二进制，无编码转换 |
| `allsin.grp` | **同** | 纯二进制 |
| `ranger.idx` | **同** | 纯偏移表 |
| `ranger.grp` | **异** | **UTF-8 编码转换**（hint 方案，大小 132270B 不变） |

✅ **不得**表述为「产物 `save/` 31 与源 31 逐字节一致」——
实测产物是 **27**，差额 4 项改道 `data/`。

---

## REQ-DRMV-10 8 项排名实测 ✅

```bash
$ python3 (扫全部 20 MOD 的 mods/*/data/)
hdgrp   dream=  484  排名 2/20  前5: books=696, dream=484, pig3dos=412, BookCalamity=373, awaken=353
kdef    dream= 4569  排名 1/20  前5: dream=4569, BookCalamity=1701, mingdong=1654, lyff=1358, pig=1288
talk    dream= 6464  排名 4/20  前5: RiverLake=8015, awaken=7717, books=6655, dream=6464, BookCalamity=5967
fight   dream=  122  排名 12/20 前5: BookCalamity=326, mingdong=267, awaken=237, RiverLake=219, Dragon=209
Person  dream=  409  排名 7/20  前5: BookCalamity=800, awaken=720, pineapple=720, mingdong=632, pig3dos=607
```

| 指标 | dream | 排名 | 前序实测 |
|------|------:|-----:|----------|
| `kdef` | 4569 | **1/20** | BookCalamity 1701 > mingdong 1654 > lyff 1358 > pig 1288 |
| `hdgrp` | 484 | **2/20** | books 696 > **dream 484** > pig3dos 412 > BookCalamity 373 > awaken 353 |
| `talk` | 6464 | **4/20** | RiverLake 8015 > awaken 7717 > books 6655 > **dream 6464** |
| `Person` | 409 | **7/20** | BookCalamity 800 > awaken 720 = pineapple 720 > mingdong 632 > pig3dos 607 > Dragon 589 > **dream 409** |
| `fight` | 122 | **12/20** | BookCalamity 326 > mingdong 267 > awaken 237 > RiverLake 219 > Dragon 209 > pig3dos 180 > books 178 > ptt 162 > pineapple 154 > lyff 138 > pig 137 > **dream 122** |
| `eft` 零改动 | 714 | **唯一** | 其余改动型：books 973 / pineapple 1378 / mingdong 2268 / BookCalamity 2857 |
| 零字节 fight | 0 | 并列最少 | pineapple 115 / RiverLake 44 / ptt 7 / books 2 / loving 2 |
| 记录段全异 | **5/5** | **本 epic 唯一** | lyff 1 段 / ptt 4 段 / 其余基线同形 |

✅ 只有 `kdef` 是真正「第 1」；`hdgrp` 明确第 2；`fight 122` 仅第 12。
✅ 每个排名均附前序 MOD 具体数值，无无实测断言。

---

## Blast Radius 合规检查

```bash
$ git status --porcelain | grep -E "engine-love2d|engine-mud|reference/allmods"
（无输出）
```

| 路径 | 是否改动 | 判定 |
|------|:--------:|------|
| `game/engine-love2d/**` | 无 | ✅ |
| `game/engine-mud/**` | 无 | ✅ |
| `game/script/jyconst.lua` 常量 | 仅既有 `+11/−1` 接线（非本 change） | ✅ |
| `reference/allmods/**` | 无 | ✅ |
| `game/tools/**` | 无 | ✅ |
| `game/mods/dream/**` | 仅 `SeedSaveSlot` 探针临时文件（已清理） | ✅ |

---

## 偏差记录汇总

| # | 项 | 初稿断言 | 实测结论 | 处置 |
|---|----|----------|----------|------|
| 1 | `added` 分解 | `71×2=142 + 14 非 fight = 156` | fight `.idx` 72 个（含孤儿 `fight23.idx`），非 fight **13** | `142+1+13=156`，proposal 已改 |
| 2 | `SeedSaveSlot` 返回值 | 写作 `ok, path` 两值 | **单返回值**（路径或 `nil`） | verification 已注明 |
| 3 | `ranger.str` 首行 | 「首行是 `0000,Person,...`」 | 首行是 `# ranger.str...` 注释；首**数据**行在第 5 行 | spec/tasks 已改 |
| 4 | fight 自洽 | 未给删除象限 | `A+B=51≠92`，需 `E=41` | 五分类已落文档 |

---

## 复现命令

```bash
cd game

# diff 双向集合相等 + fight 五分类 + save/ 统计（Python 一次性）
python3 - <<'PY'
import os,re,hashlib
md5=lambda p: hashlib.md5(open(p,'rb').read()).hexdigest()
md=open("mods/dream/diff.md",encoding="utf-8").read()
added=sorted(re.findall(r"^\s*-\s*\+\s*(\S+)\s*$",md,re.M))
removed=sorted(re.findall(r"^\s*-\s*-\s*(\S+)\s*$",md,re.M))
prod=set(os.listdir("mods/dream/data")); base=set(os.listdir("data"))
print(len(added), len(removed), added==sorted(prod-base), removed==sorted(base-prod))
PY

# SeedSaveSlot
rm -f active_mod.txt && lua /tmp/dream_seed.lua
rm -f mods/dream/save/r1.idx mods/dream/save/r2.idx mods/dream/save/r3.idx

# hdgrp / eft 结构
python3 -c "import struct; b=open('mods/dream/data/hdgrp.idx','rb').read(); print(len(b)//4)"
```

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod dream
formats=14 checked=227 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **123** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **77** | `lib_love.PlayWAV` |
| png | `png_image` | 2 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **227** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=225` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=227 gaps=0`（+2） |

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

本 MOD `total=227`，在 20 个 MOD 中排 **第 13**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，227 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
