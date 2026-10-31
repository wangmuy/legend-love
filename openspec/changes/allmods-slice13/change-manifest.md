---
status: done
created: 2026-10-26
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice13 — books

> books 是第 5 梯队唯一成员、累计第 13 个、**本 epic 最后一个 MOD**。
> 在全部 20 个 MOD 中：**`hdgrp` 条目第 1（696）**、**`kdef` 事件最少（573，反向第 1）**、
> **`talk` 条目第 3（6655）**、`eft` 第 4（973）。
> 其 fight 分布（A 89 / B 3 / C 86 / D 2）与 pineapple（A 2 / B 90 / C 62 / D 115）**互为极端**，
> 是本 epic 最有价值的 cross-MOD 对照。

## 子 change

| # | 子 change | 职责 | 状态 |
|---|-----------|------|------|
| 1 | `allmods-books-activate` | 构建 + 单项机器验证 + 启动链路 + 内容真实性 | active |
| 2 | `allmods-books-verify` | `diff.md` 逐项审计 + `hdgrp`/`Wugong`/fight 取证 + 报告 | active |

---

## Contract A — 构建产物（activate → verify）

`mod_build.lua kys-books` 必须输出且仅输出：

```
[mod_build] kys-books: data files=392, saves=19, sound=84, events=573, talk=6655
```

实测（`cd game && lua tools/mod_build.lua kys-books`）：

```
[mod_build] kys-books: data files=392, saves=19, sound=84, events=573, talk=6655
[mod_build] diff -> tools/../mods/books/diff.md
```

- `game/mods/books/data/` 实测 **393** 个文件（含 `ranger.str` / `kysmod.ini` 等生成物）
- `data/` 内 `kdef.*` + `talk.*` = 4 个（573 事件 / 6655 对话的载体）
- `save/` = **19**（与源 `save/` 中 19 个槽文件逐字节同 md5）
- `sound/` = **84**（与源 `sound/` 同数）

> **口径说明**：`data files=392` 是构建器口径（不含 `ranger.str` 等生成物），
> 目录实测 393 个。两者**不是矛盾**，见 Contract D。

## Contract B — 穷举审计闭合

```
total=525 in_product=495 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED 490 / REQUIRED_CONVERTED 4 / LEGACY 3 / BUILD_INPUT 1 / PENDING 27
evidence: checked=8 failed=0
```

- `490 + 4 + 3 + 1 + 27 = 525` = `total` ✅（逐类相加闭合）
- `in_product + not_in_product = 495 + 30 = 525` ✅（双向闭合）
- `unclassified=0`、`bad_evidence=0` → 无未分类、无伪证

## Contract C — 字节级格式覆盖

```
formats=12 checked=287 gaps=0
```

## Contract D — 记录段边界整除

`ranger.idx` offsets = `[836, 70360, 108360, 112728, 126328, 126478]`

| 段 | 字节 | 记录长 | 条数 | 余数 |
|----|-----:|-------:|-----:|-----:|
| Person | 69524 | 182 | **382** | **0** |
| Thing  | 38000 | 190 | **200** | **0** |
| Scene  |  4368 |  52 |  **84** | **0** |
| Wugong | 13600 | 136 | **100** | **0** |
| Shop   |   150 |  50 |   **3** | **0** |

`Σ = 126328`，`grp = 126478` ⇒ 头部 **836** + 尾部 **150**（= Shop 段）。
基线 offsets = `[836, 65476, 117476, 122684, 136262, 136412]`，
seglens = `[64640, 52000, 5208, 13578, 150]`，`grp = 136412`。

**与基线对照**：Person 320→**382**、Thing 200→200（**相同**）、Scene 84→84（**相同**）、
Wugong 93→**100**、Shop 3→3（相同）、`grp` 136412→**126478**（**变小**）。

> books 是少数 `ranger.grp` **比基线更小**的 MOD（126478 < 136412），
> 而 `Person` 条数**更多**（382 > 320）—— 因为基线 Thing 段更大（52000 vs 38000）。

## Contract E — `ranger.str` 侧表（hint 占位符方案）

`ranger.grp` 的字符串字段被替换为定宽 hint（`P0000`/`N0001`/`T0002`…），
真实 UTF-8 值写入 `ranger.str`：

```
wc -l mods/books/data/ranger.str   ->  964（含 4 行注释 + 3 行说明）
有效条目 = 957
  分段: Person 419 / Thing 368 / Scene 72 / Wugong 98   (Σ = 957)
  字段: Name 670 / Nick 119 / Desc 168                  (Σ = 957)
  唯一值 934 / 重复值 23
```

**运行时必须回填**：`LoadRecord(0)` 后 `JY.Person[0]["姓名"]` 必须是 `古天奇`
（源 `ranger.grp` Big5 字节 `a5 6a a4 d1 a9 5f`），而非 hint `P0000`。

实测：

```
Person[  0] 姓名=古天奇 外号=天下奇男子
Person[  1] 姓名=胡斐   外号=雪山飛狐
Person[  2] 姓名=程靈素 外号=毒手藥王
Person[381] 姓名=閻基   外号=毒手藥王
Thing[  0] 名称=腐骨穿心膏
Thing[199] 名称=最後
Scene[  0] 名称=崑侖山
Scene[ 83] 名称=待定
```

> **陷阱**：直接读 `mods/books/data/ranger.grp` 会看到 `P0000`/`N0001`，
> 那是**设计内的占位符**，不是编码失败。判据必须是**运行时**取值。

## Contract F — `hdgrp` 696（全 20 MOD 最多）

`hdgrp.idx` = 2784B → **696** 条（2784 / 4）；`hdgrp.grp` = **1233815B**。

逐条结构解析（RLE 头部 8 字节 = `w,h,xoff,yoff`，小端）：

```
hdgrp 记录 696: 头有效 474, 零长(重复帧) 222, 头异常 0
  w: min=1 max=82 mean=46.4
  h: min=1 max=70 mean=51.2
```

- **0 条异常**：474 个非空段全部有合法 `w>0, h>0`
- **222 个零长段** = RLE 重复帧引用，格式规范允许（`format_spec.lua:232` `idx_grp_rle`，
  `verifyPair` 只对 `b > a` 建区间，零长段被跳过，不计为 gap）
- 零长段呈 **4 个块**：`(215,len 54)`、`(270,len 2)`、`(273,len 165)`、`(695,len 1)`，
  `Σ=222`（前 3 块是连续重复帧群，`(695,1)` 为末尾哨兵位）

基线对照：115 条 = **PNG 2 + RLE 112 + 零长 1**，`w 13..56 / h 9..58`。
books **全部 RLE，无 PNG**。

## Contract G — `eft` 973

`eft.idx` = 3892B → **973** 条；`eft.grp` = **1338023B**。
offsets 严格递增 ✅，`offs[0]=107`，`offs[-1]=1338023`，尾部 **0**。
基线 714 条 / `eft.grp` 大小见 `data/eft.grp`。

## Contract H — fight 四象限

| 象限 | 定义 | books | pineapple 对照 |
|------|------|-----:|---------------:|
| A | 同名同内容（md5 相等） | **89** | 2 |
| B | 同名异内容（md5 不同） | **3** | 90 |
| C | MOD 独有（基线无此名） | **86** | 62 |
| D | MOD 侧零字节 | **2** | 115 |

自洽校验（**必须全部成立**）：

- `A + B = 89 + 3 = 92` = 基线 fight 组数 ✅
- `A + B + C = 89 + 3 + 86 = 178` = MOD fight 组数 ✅
- `D ∩ B = 0`（零字节不与「同名异容」重叠）
- `D ∩ C = 2`（零字节全部落在 MOD 独有）

零字节具体编号：`fight104`、`fight164`（`.grp` 与 `.idx` 均 0 字节）。

**源侧溯源**（决定性）：

```
SRC fight104.grp: 0    SRC fight104.idx: 0
SRC fight164.grp: 0    SRC fight164.idx: 0
源 fight/ 目录全部零字节文件 = 恰好这 4 个
```

⇒ 零字节**来自源文件本身**，不是构建缺陷，也不是「被清零」。
（与 pineapple 的 115 个同构：源侧也是 0B。）

### H.1 `FILE_MISSING` —— books 独有，且是**本 epic 首个真实性实例**

`Person.头像代号` 共引用 **174 个不同代号**（min 0, max 185）。
其中 **4 个被引用但 `fight*.grp` 文件不存在**：

| 代号 | 引用者 | 引用者姓名 | 缺失文件 |
|-----:|-------:|-----------|----------|
| 30 | `Person[30]` | 風清揚 | `fight030.grp/.idx` |
| 39 | `Person[39]` | 石中玉 | `fight039.grp/.idx` |
| 66 | `Person[66]` | 段正淳 | `fight066.grp/.idx` |
| 110 | `Person[122]` | 張召重 | `fight110.grp/.idx` |

实测命令（`/tmp/books_ref.lua`）：

```
被引用不同代号:  174   min: 0   max: 185
--- 被引用但文件不存在 ---
  数量: 4   代号: 30,39,66,110
```

**源侧与基线侧均不存在**（不是构建丢文件）：

```
fight030: src=MISSING base=MISSING     fight039: src=MISSING base=MISSING
fight066: src=MISSING base=MISSING     fight110: src=MISSING base=MISSING
```

**另有 4 个文件不存在但未被引用**：`fight052/111/112/113`（`引用次数=0`，
属 MOD 冗余空位，不影响运行）。

### H.2 三分支实测（`lib_love.lua` 路径级取证）

| 代号 | 文件状态 | `PicLoadFile` | `PicGetXY` | 判定 |
|-----:|----------|:-------------:|:----------:|------|
| 103 | `grp=67212B idx=208B` | 正常 | 抛错（该包 idx 结构特殊） | 非本次判据 |
| **104** | **`grp=0 idx=0`** | 不早退（`0<0` 假） | **`0,0`** | **ZERO_BYTE** |
| **164** | **`grp=0 idx=0`** | 不早退 | **`0,0`** | **ZERO_BYTE**（被引用 1 次） |
| **30/39/66/110** | **不存在**（`FileLength=-1`） | **早退**（`idxlen<0 or grplen<0`，`lib_love.lua:435`） | **`0,0`** | **FILE_MISSING** |
| 400（人造） | 不存在 | 早退 | `0,0` | 负对照 ✅ |

全量扫描（`fight 0..177`）：

```
PicGetXY 有效(>0)=168,  返回 0x0=10
返回 0x0 的代号: 30,39,52,66,104,110,111,112,113,164
```

10 个 `0x0` = **4 个 FILE_MISSING（被引用）+ 4 个 FILE_MISSING（未引用）+ 2 个 ZERO_BYTE**。

> **重要限制（必须显式声明）**：`PicGetXY` 对 `ZERO_BYTE` 与 `FILE_MISSING`
> **返回完全相同的 `0,0`**，运行时**不可区分**。这与 pineapple 的情形一致
> （pineapple 也是两者都返回 `0,0`）。分支归属只能靠**文件系统事实 + 代码路径**判定，
> 不能靠 `PicGetXY` 返回值。
>
> books 与 pineapple 的差异在**分布**：
> pineapple `FILE_MISSING = 0`（被引用代号全部 ≤299 且不缺失），books `FILE_MISSING = 4`。

## Contract I — `diff.md` 双向 set 相等

```
diff.md added: 184   removed: 21
实测 MOD 独有: 184   实测基线独有: 21
add == 实测独有 ?          True
rem == 实测基线独有 ?      True
```

- `added` 分类：**fight 172**（86 组 × 2 文件）+ **非 fight 12**
- 非 fight 12 项：`cloud.grp cloud.idx end.png kdef.grp kdef.idx kysmod.ini
  open.png ranger.str talk.grp talk.idx title.grp title.idx`
- `removed` 21 项：**13 槽改道 save + 5 槽缺席走回退 + 3 模板回退 + 0 真删除**

### I.1 21 条基线独有的精确三分法

`diff.md` 的对比面是 **产物 `data/` vs 基线 `data/`**（`save/` 不参与），
所以基线 `data/` 里的 9 组槽文件（`d1/d2/d3/r1/r2/r3/s1/s2/s3` × `.grp`/`.idx` = 18 项）
在产物 `data/` 中消失，全部落在 `removed`。

| 类别 | 数量 | 文件 | 证据 |
|------|-----:|------|------|
| **槽改道到 `save/`** | **13** | `d1.grp`、`r1.grp/.idx`、`r2.grp/.idx`、`r3.grp/.idx`、`s1.grp/.idx`、`s2.grp/.idx`、`s3.grp/.idx` | 源 `save/` 中存在同名文件，且 `mods/books/save/` 与之一一 **md5 相同（13/13）** |
| **槽位完全缺席（走回退）** | **5** | `d1.idx`、`d2.grp`、`d2.idx`、`d3.grp`、`d3.idx` | 源 `save/` 中**同样不存在** ⇒ MOD 未提供，运行期由 `ModData.Resolve` 回退到基线 |
| **模板回退** | **3** | `thing.grp`、`thing.idx`、`allsinbk.grp` | 源与产物均无，`ModData.Resolve` 回退到基线 `data/` |
| **真删除** | **0** | — | 无任何基线文件在两侧都不存在 |

合计 `13 + 5 + 3 + 0 = 21` = `removed` ✅

实测命令：

```bash
# 18 项 removed 逐项核对「产物 save 有 / 源 save 有」
d1.grp  产物save=有  源save=有        d1.idx  产物save=无  源save=无
d2.grp  产物save=无  源save=无        d2.idx  产物save=无  源save=无
d3.grp  产物save=无  源save=无        d3.idx  产物save=无  源save=无
r1.grp  产物save=有  源save=有        r1.idx  产物save=有  源save=有
r2.grp  产物save=有  源save=有        r2.idx  产物save=有  源save=有
r3.grp  产物save=有  源save=有        r3.idx  产物save=有  源save=有
s1.grp  产物save=有  源save=有        s1.idx  产物save=有  源save=有
s2.grp  产物save=有  源save=有        s2.idx  产物save=有  源save=有
s3.grp  产物save=有  源save=有        s3.idx  产物save=有  源save=有

源save有=13: d1.grp r1.grp r1.idx r2.grp r2.idx r3.grp r3.idx
              s1.grp s1.idx s2.grp s2.idx s3.grp s3.idx    -> md5 相同 13/13 ✅
源无=5: d1.idx d2.grp d2.idx d3.grp d3.idx
```

> **`save/` 19 与 `removed` 18 不是同一个集合**：
> `save/` 含 `d6/d11/r6/r11/s6/s11` 这几个**基线 `data/` 里本来就没有**的槽
> （基线只有 `d1..d3`/`r1..r3`/`s1..s3`），所以它们不出现在 `removed` 里。
> 实测交集：`save/` 有而 `removed` 无 = `d11 d6 r11 r6 s11 s6`；
> `removed` 有而 `save/` 无 = `d2 d3`（`d2`/`d3` 只在基线 `data/` 中存在，
> 源 save 未提供 ⇒ 走回退）。**两套口径不可混用。**

### I.2 12 项非 fight 新增的溯源

| 文件 | 判定 | 依据 |
|------|------|------|
| `cloud.grp/.idx`、`title.grp/.idx`、`open.png`、`end.png` | MOD 新增资源 | 源 `resource/` 中存在 |
| `kdef.grp/.idx` | MOD 剧情（573 事件） | 源 `resource/` |
| `talk.grp/.idx` | MOD 对话（6655 条） | 源 `resource/` |
| `kysmod.ini` | MOD 配置 | 源根目录 |
| `ranger.str` | **构建生成** | 源中不存在；由 `mod_encoding.lua` hint 抽取生成 |

## Contract J — `kysmod.ini` 覆盖（反向对照）

源 `kysmod.ini` 96 行、产物 96 行，逐行相同（仅首行注释 `;霂亙潸[system]` 差异）。

解析结果：

```
非注释键总数: 52   (constant 36 / system 13 / music 3)
映射成功: 56 个 CC 键（含 1 对多，如 begin_scene→NewGameSceneID）
unknown: 1 个（SOUND3D —— [music] 段无对应映射，设计内）
```

**运行时差异（基线 vs books，28 项覆盖）**：

| 类别 | 数量 | 说明 |
|------|-----:|------|
| ini 新增有值（基线为 `nil`） | **28** | ini 真正生效项 |
| 与代码默认同值（未改变） | **5** | `NewGameSceneID 70` / `NewGameEvent 691` / `NewGameSceneX 19` / `NewGameSceneY 20` / `MoneyID 174` |
| 未纳入快照 | 18 | `MaxProList45..57`（抽样 43/44/58 已验证） |
| unknown 未映射 | 1 | `SOUND3D` |

28 项新增实测值（摘录）：

```
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
```

> **反向对照的意义**：若 ini 未被应用，这 28 项应全部为 `nil`。
> 实测全部有值 ⇒ 证明 ini 生效，而非「恰好代码默认值相同」。

## Contract K — 启动链路（独立进程）

```
lua tests/unit/boot_one_mod.lua books 382 200 84 100 古天奇
```

必须全 PASS，含：

```
[PASS] CC.SceneSize=52（MOD 布局） (期望 52, 实际 52)
[PASS] CC.WugongSize=136（MOD 布局） (期望 136, 实际 136)
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

**5 个位置参数全部是期望值**，任何一个不符即 FAIL
（防止「传什么就报什么」的假通过）。

## Contract L — `Wugong` 100 的字段映射

`Wugong_S` 共 **64 个字段**，在 100 条记录上：

```
全 nil 字段数: 0
名称 非空: 100 / 100
```

边界抽样：

```
[  0] 名称=普通攻擊   武功类型=1 出招音效= 1 武功动画&音效=12 消耗内力点数= 1
[  1] 名称=天地雙絕刀 武功类型=3 出招音效=20 武功动画&音效= 9 消耗内力点数=20
[  2] 名称=圓月刀法   武功类型=3 出招音效= 1 武功动画&音效=24 消耗内力点数=14
[ 97] 名称=凝碧柔云劍 武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 98] 名称=柔云劍法   武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 99] 名称=震天三十掌 武功类型=1 出招音效= 1 武功动画&音效=27 消耗内力点数= 8
```

> 字段实名 `武功动画&音效`（含 `&`）；写成 `动画` 会得 `nil` 而静默通过。

⇒ 100 条记录**字段全对齐，无越界、无错位**。

**`CC.Effect` 越界**：`CC.Effect` 键数 **53**（`max键 = 52`，即 `0..52`）。
`Wugong["武功动画&音效"]` 100 条全有值，`> 52` 的记录 **2 条**，`max = 55`
（远轻于 pineapple 的 62 条 / max 83）。

## Contract M — 8 道门禁

| # | 门禁 | 判据 |
|---|------|------|
| 1 | `tests/test_runner.lua` | `通过: 1842 失败: 0` |
| 2 | `mod_build --verify-pascal` | `PASS`，`mismatches=0` |
| 3 | `mod_build --all` | `20 mods, 0 build failures`（退出码 1 属设计） |
| 4 | `mod_check.lua` | `20 MOD, 通过 20, 失败 0` |
| 5 | `mod_audit --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` |
| 6 | `format_spec --all` | `gaps=0` |
| 7 | 20 MOD `save/` vs 源 | 真实问题 0 |
| 8 | 禁改路径 | 三处空；`jyconst.lua` 无 `CC.*=` 增删 |
