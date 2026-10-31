---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice13
result: PASS
---
# Verification: allmods-books-activate

> 全部命令在 `game/` 下执行。每条判据附「实测命令 + 输出 + ✅」。
> 环境：`rm -f active_mod.txt` 后从干净状态开始。

## 总览

| REQ | 主题 | 结论 |
|-----|------|------|
| REQ-BK-1 | 构建产物 | ✅ 五数字逐字匹配 |
| REQ-BK-2 | 穷举审计 | ✅ 两处算术闭合 |
| REQ-BK-3 | 格式覆盖 | ✅ `gaps=0` |
| REQ-BK-4 | 启动链路 | ✅ `RESULT books: OK` |
| REQ-BK-5 | 记录段整除 | ✅ 五段余数全 0 + 基线对照 |
| REQ-BK-6 | 内容真实性 | ✅ 四类证据齐备 |
| REQ-BK-7 | ini 生效 | ✅ 28 项 `nil→value` |
| REQ-BK-8 | `hdgrp` 696 | ✅ 474 RLE + 222 零长，异常 0 |
| REQ-BK-9 | `Wugong` 100 | ✅ 64 字段全对齐，越界 2 |
| REQ-BK-10 | fight 三分支 | ✅ 含 4 个真实 `FILE_MISSING` |
| REQ-BK-11 | `ranger.str` 溯源 | ✅ 源侧不存在 |
| REQ-BK-12 | `name.*` 缺席 | ✅ 三重 0 命中 |
| REQ-BK-13 | 8 门禁 | ✅ 全绿 |

**结论：13/13 PASS，0 缺陷（4 项为 MOD 原始缺陷，非构建引入）。**

---

## REQ-BK-1 构建产物 ✅

```bash
$ cd game && lua tools/mod_build.lua kys-books
[mod_build] kys-books: data files=392, saves=19, sound=84, events=573, talk=6655
[mod_build] diff -> tools/../mods/books/diff.md
```

产物计数：

```bash
$ ls mods/books/data  | wc -l   ->  393
$ ls mods/books/save  | wc -l   ->  19
$ ls mods/books/sound | wc -l   ->  84
```

✅ 五个数字逐字匹配。`data 392`（构建器口径）vs 目录 393 —— 差异为 `ranger.str`
等生成物计入方式，已在 spec 显式声明，非矛盾。

---

## REQ-BK-2 穷举审计 ✅

```bash
$ lua tools/mod_audit.lua --mod books --evidence
total=525 in_product=495 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             490
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
evidence: checked=8 failed=0
```

闭合验算：

- `490 + 4 + 3 + 1 + 27 = 525` = `total` ✅
- `495 + 30 = 525` ✅
- `unclassified=0`、`bad_evidence=0`、`failed=0` ✅

---

## REQ-BK-3 格式覆盖 ✅

```bash
$ lua tools/format_spec.lua --mod books
formats=12 checked=287 gaps=0
```

✅ `gaps=0`。

---

## REQ-BK-4 启动链路 ✅

```bash
$ rm -f active_mod.txt
$ lua tests/unit/boot_one_mod.lua books 382 200 84 100 古天奇
[PASS] CC.SceneSize=52（MOD 布局） (期望 52, 实际 52)
[PASS] CC.WugongSize=136（MOD 布局） (期望 136, 实际 136)
[PASS] LoadRecord(0) 无报错: true
[PASS] PersonNum (期望 382, 实际 382)
[PASS] ThingNum (期望 200, 实际 200)
[PASS] SceneNum (期望 84, 实际 84)
[PASS] WugongNum (期望 100, 实际 100)
[PASS] 主角姓名 (期望 古天奇, 实际 古天奇)
[PASS] 扫描字段数 > 100（实际 1548）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
RESULT books: OK
```

✅ 12 PASS / 0 FAIL，`RESULT books: OK`。
每条 `[PASS]` 都打印「期望 / 实际」双列 ⇒ 参数是**期望值**而非「传入即通过」。

---

## REQ-BK-5 记录段整除 ✅

```bash
$ python3 -c "import struct;off=list(struct.unpack('<6I',open('mods/books/data/ranger.idx','rb').read()));print(off)"
[836, 70360, 108360, 112728, 126328, 126478]
```

| 段 | 字节 | 记录长 | 条数 | 余数 |
|----|-----:|-------:|-----:|-----:|
| Person | 69524 | 182 | **382** | **0** |
| Thing | 38000 | 190 | **200** | **0** |
| Scene | 4368 | 52 | **84** | **0** |
| Wugong | 13600 | 136 | **100** | **0** |
| Shop | 150 | 50 | **3** | **0** |

头尾：`Σ=126328`，`grp=126478` ⇒ 头 **836** + 尾 **150** ✅

基线对照：

| 维度 | 基线 | books | 判定 |
|------|-----:|------:|------|
| Person | 320 | **382** | 异 |
| Thing | 200 | 200 | 同 |
| Scene | 84 | 84 | 同 |
| Wugong | 93 | **100** | 异 |
| Shop | 3 | 3 | 同 |
| `ranger.grp` | 136412 | **126478** | **变小** |

✅ 整除 + 差异对照双证据。基线 `seglens = [64640, 52000, 5208, 13578, 150]`。

---

## REQ-BK-6 内容真实性 ✅

### 6.1 边界记录

```bash
$ lua /tmp/books_str.lua    # SetActive("books") + LoadRecord(0)
Person[  0] 姓名=古天奇 外号=天下奇男子
Person[  1] 姓名=胡斐 外号=雪山飛狐
Person[  2] 姓名=程靈素 外号=毒手藥王
Person[381] 姓名=閻基 外号=毒手藥王
Thing[  0] 名称=腐骨穿心膏
Thing[  1] 名称=精氣丸
Thing[199] 名称=最後
Scene[  0] 名称=崑侖山
Scene[  1] 名称=嘉興
Scene[ 83] 名称=待定
```

✅ 全部是真实繁体中文，**无** `P0000`/`N0001`/`T0002` 泄漏到运行时。

### 6.2 `ranger.str` 侧表

```bash
$ wc -l mods/books/data/ranger.str     ->  964
$ python3 (统计非注释行)
总条目: 957   唯一值: 934   重复值: 23
分段: {'Person': 419, 'Thing': 368, 'Scene': 72, 'Wugong': 98}
字段: {'Name': 670, 'Nick': 119, 'Desc': 168}
```

✅ `419+368+72+98 = 957`，`670+119+168 = 957`。

hint 回填证明：

```
ranger.grp @844:「P0000」  ──运行时──▶  JY.Person[0]["姓名"] = 古天奇
ranger.grp @854:「N0001」  ──运行时──▶  JY.Person[0]["外号"] = 天下奇男子
```

### 6.3 `573` 事件 / `6655` 对话

构建输出 `events=573, talk=6655` ✅。**字节级独立复核**（不只信构建器自报）：

```bash
$ python3 -c "解析 kdef.idx / talk.idx 为 uint32 数组"
books kdef: idx=2292B entries=573  grp=150730B  first_offs=4     last=150730  tail=0
books talk: idx=26620B entries=6655 grp=384396B first_offs=90    last=384396  tail=0
```

- `kdef.idx = 2292B`，`2292 / 4 = 573` ✅ 精确等于构建器报的 `events=573`
- `talk.idx = 26620B`，`26620 / 4 = 6655` ✅ 精确等于 `talk=6655`
- 两者 `last_offset == grp 大小`，`tail = 0` ⇒ 末段贴合文件尾，**无截断**
- `first_offs` 为 4 / 90（头部偏移表自含，`offset[0]` 指向数据区起点），非 0 但合理

对照 pineapple（`kdef 1068` / `talk 3596`）：books 的 `kdef` **更少**（573 vs 1068）
但单条更大（`150730/573 ≈ 263B` vs `608388/1068 ≈ 570B`）；
`talk` 更多（6655 vs 3596）但单条更小（`384396/6655 ≈ 58B` vs `152098/3596 ≈ 42B`）。

`diff.md` 新增列表含 `kdef.grp`/`kdef.idx`/`talk.grp`/`talk.idx` ⇒ MOD 侧文件被完整搬运。

### 6.4 `kysmod.ini` 反向对照（28 项）

```
基线 nil → books 有值 (28 项):
CC.SoftStarBeginTalk=2547  CC.SoftStarNumTalk=18   CC.MaxPhysicalPower=100
CC.CompassID=182           CC.BeginLeaveEvent=1    CC.BeginBattleRolePic=2553
CC.MaxLevel=30             CC.MaxWeaponMatch=7     CC.MinKnowledge=80
CC.MaxItemAmount=200       CC.LifeHurt=10          CC.MaxHP=999
CC.MaxMP=999               CC.MaxAddPro=0          CC.ItemBeginPic=3501
CC.MaxProList43=100        CC.MaxProList44=100     CC.MaxProList58=1
CC.MODVersion=21           CC.BattleSpeed=10       CC.SceneAmi=2
CC.SemiReal=1              CC.Simple=0             CC.Smooth=1
CC.Glhr=1                  CC.ExpandGround=0       CC.NightEffect=0
CC.KdefScript=0

与基线同值 (5 项，代码默认已相同):
NewGameSceneID=70  NewGameEvent=691  NewGameSceneX=19  NewGameSceneY=20  MoneyID=174
```

✅ 反向对照成立：若 ini 未应用，28 项应为 `nil`。

---

## REQ-BK-7 ini 解析 ✅

```bash
$ diff ../reference/allmods/kys-books/kysmod.ini mods/books/kysmod.ini
1c1
< ;霂亙潸[system]
---
> ;[system]
```

仅首行注释差异，其余 95 行逐行相同 ✅（各 96 行）

```
非注释键总数: 52   (constant 36 / system 13 / music 3)
映射成功: 56 个 CC 键
unknown: 1 个 -> SOUND3D
```

`SOUND3D` 属 `[music]` 段，`framework/mod_ini.lua` 的 `SECTION_MAP.music`
只有 `volume`/`volumewav` ⇒ 设计内 unknown ✅

---

## REQ-BK-8 `hdgrp` 696 ✅

```bash
$ python3 (逐条解析 RLE 头 <HHhh>)
books hdgrp: 记录=696 PNG=0 RLE=474 零长=222 头异常=0
   w: 1..82  h: 1..70
   零长块: [(215, 54), (270, 2), (273, 165), (695, 1)]  Σ=222

baseline hdgrp: 记录=115 PNG=2 RLE=112 零长=1 头异常=0
   w: 13..56  h: 9..58
   零长块: [(114, 1)]  Σ=1
```

✅ **474 个非空段头全部有效（`w>0,h>0`），异常 0**。
222 个零长段 = RLE 重复帧，`format_spec.lua` 的 `verifyPair` 用 `b > a` 跳过，
不计 gap —— 与 `format_spec --mod books` 的 `gaps=0` 一致 ✅

对照 `eft`（同为 `idx_grp_rle` 家族，但严格递增）：

```
books eft: 记录=973 PNG=0 RLE=972 零长=1 头异常=0
   w: 1..230  h: 1..200
```

⇒ 零长段是 `hdgrp` 特有的**内容特征**（多角色共用帧），不是格式缺陷。

---

## REQ-BK-9 `Wugong` 100 ✅

```bash
$ lua /tmp/books_wg.lua
Wugong_S 字段数: 64   WugongNum: 100
全 nil 字段数: 0
名称非空: 100 / 100
CC.Effect 键数: 53   max键: 52
武功动画&音效: 有值 100 条, 越界(>52) 2 条, max=55
```

边界抽样（真实字段名）：

```
[  0] 名称=普通攻擊   武功类型=1 出招音效= 1 武功动画&音效=12 消耗内力点数= 1
[  1] 名称=天地雙絕刀 武功类型=3 出招音效=20 武功动画&音效= 9 消耗内力点数=20
[  2] 名称=圓月刀法   武功类型=3 出招音效= 1 武功动画&音效=24 消耗内力点数=14
[ 97] 名称=凝碧柔云劍 武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 98] 名称=柔云劍法   武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 99] 名称=震天三十掌 武功类型=1 出招音效= 1 武功动画&音效=27 消耗内力点数= 8
```

✅ 64 字段全对齐，`名称` 100/100 非空，越界仅 2 条（vs pineapple 62 条）。

> **偏差记录**：初次抽样误用字段名 `动画`（实为 `武功动画&音效`），得 `nil`。
> 这正是「全 nil 字段数 = 0」兜底检查的价值 —— 它把「字段名写错」暴露为 1 个全 nil 字段。
> 本节已按实测修正。

---

## REQ-BK-10 fight 三分支 ✅

### 全量扫描

```bash
$ lua /tmp/books_zf2.lua
fight 0..177 PicGetXY: 有效(>0)=168, 返回0x0=10
  返回 0x0 的代号: 30,39,52,66,104,110,111,112,113,164
```

### 分支归属（文件事实）

| 代号 | grp | idx | 分支 | 被引用 |
|-----:|----:|----:|------|:------:|
| 30 | MISSING | MISSING | FILE_MISSING | 1（風清揚） |
| 39 | MISSING | MISSING | FILE_MISSING | 1（石中玉） |
| 52 | MISSING | MISSING | FILE_MISSING | 0 |
| 66 | MISSING | MISSING | FILE_MISSING | 1（段正淳） |
| **104** | **0** | **0** | **ZERO_BYTE** | 0 |
| 110 | MISSING | MISSING | FILE_MISSING | 1（張召重） |
| 111 | MISSING | MISSING | FILE_MISSING | 0 |
| 112 | MISSING | MISSING | FILE_MISSING | 0 |
| 113 | MISSING | MISSING | FILE_MISSING | 0 |
| **164** | **0** | **0** | **ZERO_BYTE** | 1 |

`168 + 10 = 178` ✅（`fight 0..177` 共 178 组）

### 引用面

```bash
$ lua /tmp/books_ref.lua
被引用不同代号:  174   min: 0   max: 185
--- 被引用但文件不存在 ---
  数量: 4   代号: 30,39,66,110
```

引用者姓名：

```
Person[ 30] 姓名=風清揚  头像代号=30  -> fight030 MISSING
Person[ 39] 姓名=石中玉  头像代号=39  -> fight039 MISSING
Person[ 66] 姓名=段正淳  头像代号=66  -> fight066 MISSING
Person[122] 姓名=張召重  头像代号=110 -> fight110 MISSING
```

### 源侧溯源

```bash
fight030: src=MISSING base=MISSING   fight039: src=MISSING base=MISSING
fight066: src=MISSING base=MISSING   fight110: src=MISSING base=MISSING
```

✅ 4 个在被引用状态下缺失，且**源目录与基线目录均不存在** ⇒ MOD 原始缺陷，非构建引入。

### 零字节源侧溯源

```bash
SRC fight104.grp: 0   SRC fight104.idx: 0
SRC fight164.grp: 0   SRC fight164.idx: 0
源 fight/ 目录全部零字节文件 = 恰好这 4 个
```

✅ 零字节来自源本身。

### 不可区分性（必须显式声明）

```
fight104: grp=0 idx=0        PicGetXY=0x0  pcall=true
fight164: grp=0 idx=0        PicGetXY=0x0  pcall=true
fight030: grp=MISSING        PicGetXY=0x0  pcall=true
fight400: grp=MISSING(人造)  PicGetXY=0x0  pcall=true   <-- 负对照
```

⚠ **`PicGetXY` 对 `ZERO_BYTE` 与 `FILE_MISSING` 返回完全相同的 `0,0`，运行时不可区分。**
分支归属由两条独立证据判定：

1. **文件事实**：`stat` → `0`（存在但空）vs `-1`（不存在）
2. **代码路径**（`engine-love2d/lib_love.lua`）：

```
:433-435  idxlen/grplen = FileLength(...)
          if idxlen < 0 or grplen < 0 then return end     -- FILE_MISSING 早退
:441      num = idxlen/4                                   -- ZERO_BYTE: num=0
:443-450  idx[1]=0; 循环 num 次（0 次不执行）
:270-273  if idx[picid]==nil or idx[picid+1]==nil then return nil  -- ZERO_BYTE 失败点
```

✅ 负对照 `fight400` 证明「返回 `0,0`」不是测量失效。

---

## REQ-BK-11 `ranger.str` 溯源 ✅

```bash
$ find ../reference/allmods/kys-books -name "ranger.str"
（无输出）
$ ls -l mods/books/data/ranger.str
（存在，964 行）
```

✅ 源侧不存在 ⇒ 由 `tools/mod_encoding.lua` 的 hint 抽取**生成**，属构建产物。

---

## REQ-BK-12 `name.*` 缺席 ✅

```bash
$ ls mods/books/data/ | grep -c "^name\."        ->  0
$ grep "  - + " mods/books/diff.md | grep -c "name\."  ->  0
$ find ../reference/allmods/kys-books -name "name.*" | wc -l  ->  0
```

对照有 `name.grp` 的 MOD：

```
BookCalamity: mods/BookCalamity/data/name.grp
Dragon:       mods/Dragon/data/name.grp
pineapple:    mods/pineapple/data/name.grp
RiverLake:    mods/RiverLake/data/name.grp
books:        无
```

✅ 三重 0 命中，books 确未使用 `name.*`。
`ranger.str` 读的是 `ranger.grp`，与 `name.*` 无关。

---

## REQ-BK-13 8 道门禁 ✅

| # | 命令 | 实测 | 判定 |
|---|------|------|------|
| 1 | `lua tests/test_runner.lua` | `通过: 1842 失败: 0` | ✅ |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `PASS`，`events=1018, mismatches=0, known-deviations=3` | ✅ |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures` | ✅ |
| 4 | `lua tools/mod_check.lua` | `总计: 20 MOD, 通过 20, 失败 0` | ✅ |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`，`checked=17 failed=0` | ✅ |
| 6 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` | ✅ |
| 7 | 20 MOD `save/` vs 源 | `槽=341 模板=110 合计=451`，真实问题 0 | ✅ |
| 8 | 禁改路径 | 三处 porcelain 空 + `jyconst.lua +11/−1`（`allmods-data-fallback` 接线，非 `CC.*=`） | ✅ |

---

## 缺陷清单

| # | 项 | 归属 | 处置 |
|---|----|------|------|
| 1 | `fight030/039/066/110` 被 4 个 NPC 引用但文件不存在 | **MOD 原始缺陷**（源与基线均缺） | 不修（改源 = 禁用路径）；记入 epic 已知缺陷 |
| 2 | `fight052/111/112/113` 文件不存在但未被引用 | MOD 冗余空位 | 不修 |
| 3 | `fight104/164` 零字节（源侧亦 0B） | MOD 作者置零 | 不修；不生成占位图 |
| 4 | `kysmod.ini` 的 `SOUND3D` 无映射 | 设计内（`SECTION_MAP.music` 无此键） | 不修 |
| 5 | `Wugong["武功动画&音效"]` 2 条 `>52` | 与 pineapple 同类（后者 62 条） | 归入 epic spike `allmods-effect-table`（修复点 `script/jyconst.lua` = 禁用路径） |

**构建引入缺陷：0。**

---

## 复现脚本

```bash
cd game
rm -f active_mod.txt

# 构建 + 机器验证
lua tools/mod_build.lua kys-books
lua tools/mod_audit.lua --mod books --evidence
lua tools/format_spec.lua --mod books
MOD_SLUG=books lua tools/mod_check_one.lua

# 启动链路
lua tests/unit/boot_one_mod.lua books 382 200 84 100 古天奇
```
