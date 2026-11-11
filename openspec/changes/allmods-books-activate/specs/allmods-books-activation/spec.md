---
status: done
created: 2026-10-26
---
# Spec: allmods-books-activation

> Change: `allmods-books-activate`　|　Slice 13（最后一个 MOD）
> MOD：`kys-books`（天书奇侠试玩）→ 产物 `game/mods/books/`
> 所有判据必须可在 `game/` 下用命令复跑。

---

## REQ-BK-1 构建产物

**Given** 源目录 `../reference/allmods/kys-books/`（525 个文件）
**When** 执行 `cd game && lua tools/mod_build.lua kys-books`
**Then** 输出必须**逐字**包含：

```
[mod_build] kys-books: data files=392, saves=19, sound=84, events=573, talk=6655
```

**And** 生成 `game/mods/books/diff.md`
**And** `game/mods/books/data/` 实测 **393** 个文件、`save/` **19** 个、`sound/` **84** 个

> 口径说明：`data files=392` 是构建器口径，目录实测 393。两者不矛盾，须显式说明。

---

## REQ-BK-2 穷举审计闭合

**Given** 已构建的 `game/mods/books/`
**When** 执行 `lua tools/mod_audit.lua --mod books --evidence`
**Then** 必须输出：

```
total=525 in_product=495 not_in_product=30 unclassified=0 bad_evidence=0
```

**And** 分类明细：

```
REQUIRED 490 / REQUIRED_CONVERTED 4 / LEGACY 3 / BUILD_INPUT 1 / PENDING 27
```

**And** 两处算术必须闭合：

- `490 + 4 + 3 + 1 + 27 = 525` = `total`（逐类闭合）
- `495 + 30 = 525`（产物内外双向闭合）

**And** `evidence: checked=8 failed=0`

> **不得**用位置参数 `lua tools/mod_audit.lua books`（会静默审计全部 20 个 MOD）。

---

## REQ-BK-3 字节级格式覆盖

**Given** 已构建的 `game/mods/books/`
**When** 执行 `lua tools/format_spec.lua --mod books`
**Then** 输出 `formats=12 checked=287 gaps=0`

**And** `gaps=0` 是唯一可接受值（任何 gap 都须逐条列入偏差表）。

---

## REQ-BK-4 独立进程启动链路

**Given** 干净状态（`rm -f game/active_mod.txt`）
**When** 执行：

```
lua tests/unit/boot_one_mod.lua books 382 200 84 100 古天奇
```

**Then** 末行必须是 `RESULT books: OK`
**And** 以下断言必须全 PASS：

```
[PASS] CC.SceneSize=52（MOD 布局） (期望 52, 实际 52)
[PASS] CC.WugongSize=136（MOD 布局） (期望 136, 实际 136)
[PASS] LoadRecord(0) 无报错: true
[PASS] PersonNum (期望 382, 实际 382)
[PASS] ThingNum  (期望 200, 实际 200)
[PASS] SceneNum  (期望 84, 实际 84)
[PASS] WugongNum (期望 100, 实际 100)
[PASS] 主角姓名 (期望 古天奇, 实际 古天奇)
[PASS] 扫描字段数 > 100（实际 1548）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
```

**And** 5 个位置参数**全部是期望值**——传错任一个必须 FAIL
（防止「传什么就报什么」的假通过）。

---

## REQ-BK-5 记录段边界整除

**Given** `game/mods/books/data/ranger.idx`（24B）与 `ranger.grp`（126478B）
**When** 解析 offsets 并计算各段长度 ÷ 记录长
**Then** 五段余数必须**全 0**：

| 段 | offsets | 字节 | 记录长 | 条数 | 余数 |
|----|---------|-----:|-------:|-----:|-----:|
| Person | 836→70360 | 69524 | 182 | **382** | **0** |
| Thing  | 70360→108360 | 38000 | 190 | **200** | **0** |
| Scene  | 108360→112728 | 4368 | 52 | **84** | **0** |
| Wugong | 112728→126328 | 13600 | 136 | **100** | **0** |
| Shop   | 126328→126478 | 150 | 50 | **3** | **0** |

**And** `Σ(段长) = 126328`，`grp = 126478` ⇒ 头部 **836** + 尾部 **150**
**And** 必须做**基线差异对照**（否则整除只证明算术对）：

| 维度 | 基线 | books | 判定 |
|------|-----:|------:|------|
| Person | 320 | **382** | 异 |
| Thing | 200 | 200 | **同** |
| Scene | 84 | 84 | **同** |
| Wugong | 93 | **100** | 异 |
| Shop | 3 | 3 | **同** |
| `ranger.grp` | 136412 | **126478** | **变小** |

基线 offsets = `[836, 65476, 117476, 122684, 136262, 136412]`，seglens = `[64640, 52000, 5208, 13578, 150]`。

> **注意**：books 是少数 `ranger.grp` 比基线**更小**的 MOD（126478 < 136412），
> 而 `Person` 更多（382 > 320）——因为基线 Thing 段更大（52000 vs 38000）。

---

## REQ-BK-6 内容真实性（四类直接证据）

### 6.1 边界记录必须解出语义字符串

**Given** `LoadRecord(0)` 已完成
**When** 读 `JY.Person[i]["姓名"]` / `["外号"]`、`JY.Thing[i]["名称"]`、`JY.Scene[i]["名称"]`
**Then** 必须是**真实繁体中文**，**不得**是 hint 占位符（`P0000`/`N0001`/`T0002`）：

```
Person[  0] 姓名=古天奇   外号=天下奇男子
Person[  1] 姓名=胡斐     外号=雪山飛狐
Person[  2] 姓名=程靈素   外号=毒手藥王
Person[381] 姓名=閻基     外号=毒手藥王
Thing[  0] 名称=腐骨穿心膏
Thing[199] 名称=最後
Scene[  0] 名称=崑侖山
Scene[ 83] 名称=待定
```

### 6.2 `ranger.str` 侧表

**Given** `game/mods/books/data/ranger.str`
**When** 统计有效条目（跳过 `#` 注释行）
**Then** 必须是 **957** 条：

```
分段: Person 419 / Thing 368 / Scene 72 / Wugong 98   (Σ = 957)
字段: Name 670 / Nick 119 / Desc 168                  (Σ = 957)
唯一值 934 / 重复值 23
```

**And** 文件总行数 **964**（957 + 4 行 `#` 注释 + 3 行说明）
**And** 必须证明根目录 `ranger.grp` 中的 `P0000` 是**设计内 hint**
（见 design ADR-BK-001），运行时被回填。

### 6.3 `573` 事件 / `6655` 对话

**Given** 源 `resource/kdef.*` 与 `resource/talk.*`
**When** 构建并统计
**Then** 事件 **573**、对话 **6655**，与构建器输出一致
**And** 必须说明这是 MOD 设计（试玩版）而非构建截断——佐证：`kdef.grp`/`kdef.idx`
与 `talk.grp`/`talk.idx` 均出现在 `diff.md` 的新增列表（MOD 侧文件被完整搬运）。

### 6.4 `kysmod.ini` 反向对照

**Given** 同一快照脚本分别以 baseline 与 books 运行
**When** 比对 35 个 `CC.*` 键
**Then** **28 项**必须从 `nil` 变为有值：

```
CC.SoftStarBeginTalk=2547   CC.SoftStarNumTalk=18     CC.MaxPhysicalPower=100
CC.CompassID=182            CC.BeginLeaveEvent=1      CC.BeginBattleRolePic=2553
CC.MaxLevel=30              CC.MaxWeaponMatch=7       CC.MinKnowledge=80
CC.MaxItemAmount=200        CC.LifeHurt=10            CC.MaxHP=999
CC.MaxMP=999                CC.MaxAddPro=0            CC.ItemBeginPic=3501
CC.MaxProList43=100         CC.MaxProList44=100       CC.MaxProList58=1
CC.MODVersion=21            CC.BattleSpeed=10         CC.SceneAmi=2
CC.SemiReal=1               CC.Simple=0               CC.Smooth=1
CC.Glhr=1                   CC.ExpandGround=0         CC.NightEffect=0
CC.KdefScript=0
```

**And** **5 项**必须与基线**同值**（代码默认已相同）：

```
NewGameSceneID=70  NewGameEvent=691  NewGameSceneX=19  NewGameSceneY=20  MoneyID=174
```

---

## REQ-BK-7 `kysmod.ini` 生效（反向对照）

**Given** 源/产物 `kysmod.ini` 各 96 行
**When** 逐行 diff 并解析
**Then** 仅首行注释差异（`;霂亙潸[system]`），其余逐行相同
**And** 非注释键 **52** 个（`constant 36 / system 13 / music 3`）
**And** 映射成功 **56** 个 CC 键（含 1 对多：`begin_scene`/`begin_scence` → `NewGameSceneID`）
**And** `unknown` 仅 **1** 个：`SOUND3D`（`mod_ini.lua` 的 `SECTION_MAP.music`
只有 `volume`/`volumewav`），属设计内

> **反向对照的意义**：若 ini 未被应用，REQ-BK-6(4) 的 28 项应全部为 `nil`。

---

## REQ-BK-8 `hdgrp` 696 逐条结构验证

**Given** `hdgrp.idx` = 2784B、`hdgrp.grp` = 1233815B
**When** 逐条解析 RLE 头 8 字节（`w,h,xoff,yoff`，小端 `<HHhh`）
**Then** 必须：

```
hdgrp 记录 696: 头有效 474, 零长(重复帧) 222, 头异常 0
  w: min=1 max=82 mean=46.4
  h: min=1 max=70 mean=51.2
```

**And** 零长段必须呈 **4 个块**：`(215,54)`、`(270,2)`、`(273,165)`、`(695,1)`，`Σ=222`
**And** 必须解释零长段 = **RLE 重复帧**（`format_spec.lua:232` `idx_grp_rle` 家族，
`verifyPair` 用 `b > a` 跳过零长段），**不得**计为 gap
**And** 必须做基线对照：

```
基线 hdgrp 115: PNG 2 + RLE 112 + 零长 1,   w 13..56 / h 9..58
books  hdgrp 696: PNG 0 + RLE 474 + 零长 222, w 1..82  / h 1..70
```

---

## REQ-BK-9 `Wugong` 100 字段映射

**Given** `Wugong` 段 13600B / 136 = 100 条，`CC.Wugong_S` 共 64 字段
**When** 用 `pairs(CC.Wugong_S)` 取全部字段名并逐字段统计 100 条记录
**Then** 必须：

```
Wugong_S 字段数: 64
全 nil 字段数: 0
名称 非空: 100 / 100
```

**And** 边界抽样语义正确：

```
[  0] 名称=普通攻擊   武功类型=1 出招音效= 1 武功动画&音效=12 消耗内力点数= 1
[  1] 名称=天地雙絕刀 武功类型=3 出招音效=20 武功动画&音效= 9 消耗内力点数=20
[  2] 名称=圓月刀法   武功类型=3 出招音效= 1 武功动画&音效=24 消耗内力点数=14
[ 97] 名称=凝碧柔云劍 武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 98] 名称=柔云劍法   武功类型=2 出招音效= 2 武功动画&音效=16 消耗内力点数=10
[ 99] 名称=震天三十掌 武功类型=1 出招音效= 1 武功动画&音效=27 消耗内力点数= 8
```

> **字段实名是 `武功动画&音效`（含 `&`），不是 `动画`**。
> 写错字段名会得到 `nil` 而静默通过抽样——这是必须用「全 nil 字段数 = 0」兜底的原因。

**And** `武功动画&音效` 越界（`> 52`）**2 条**、`max = 55`
（对照 pineapple 62 条 / max 83）

> **不得**用 `pairs(JY.Wugong[i])` 遍历记录（元表使 `pairs` 返回 0 字段）。

---

## REQ-BK-10 fight 三分支降级（含 `FILE_MISSING` 真实实例）

**Given** `fight 0..177` 共 178 组
**When** 逐组测 `FileLength`（文件事实）+ `PicLoadFile`/`PicGetXY`（运行时）
**Then** 必须：

**10.1 `ZERO_BYTE` 2 个**

```
fight104: grp=0B idx=0B   PicGetXY=0x0  pcall=true   被引用 0 次
fight164: grp=0B idx=0B   PicGetXY=0x0  pcall=true   被引用 1 次
SRC fight104/164.grp/.idx 全部 0B；源 fight/ 目录全部零字节文件 = 恰好这 4 个
```

**10.2 `FILE_MISSING` 4 个被引用**

| 代号 | 引用者 | 姓名 |
|-----:|-------:|------|
| 30 | `Person[30]` | 風清揚 |
| 39 | `Person[39]` | 石中玉 |
| 66 | `Person[66]` | 段正淳 |
| 110 | `Person[122]` | 張召重 |

```
被引用不同代号: 174   min: 0   max: 185
被引用但文件不存在: 4   代号: 30,39,66,110
源侧与基线侧均不存在（src=MISSING base=MISSING）
```

**10.3 未引用的 4 个缺失**

`fight052`、`fight111`、`fight112`、`fight113`（`引用次数 = 0`，不影响运行）

**10.4 全量扫描**

```
PicGetXY 有效(>0)=168,  返回 0x0=10
返回 0x0 的代号: 30,39,52,66,104,110,111,112,113,164
```

**10.5 必须显式声明不可区分性**

`PicGetXY` 对 `ZERO_BYTE` 与 `FILE_MISSING` **返回完全相同的 `0,0`**，
**运行时不可区分**。分支归属只能由「文件事实（`FileLength`）+ 代码路径
（`lib_love.lua:435` 早退 vs `:270-273` 索引失败）」判定。

**10.6 负对照**

人造代号 `400`（文件不存在）必须同样返回 `0,0` 且 `pcall` 为 `true`
⇒ 证明「返回 `0,0`」不是测量方法失效。

---

## REQ-BK-11 `ranger.str` 是构建生成物

**Given** 源目录 `../reference/allmods/kys-books/`
**When** 执行 `find ../reference/allmods/kys-books -name "ranger.str"`
**Then** **无输出**（源中不存在）
**And** 产物 `game/mods/books/data/ranger.str` 存在（964 行 / 957 条有效）
**And** 判定为 `tools/mod_encoding.lua` 的 hint 抽取**构建产物**，不是多余文件

---

## REQ-BK-12 `name.*` 不存在于 books

**Given** books 产物与源
**When** 检查：
1. `ls game/mods/books/data/ | grep -c "^name\\."`
2. `grep "  - + " mods/books/diff.md | grep -c "name\\."`
3. `find ../reference/allmods/kys-books -name "name.*" | wc -l`
**Then** 三者输出**均为 0 命中**
**And** 必须与 4 个有 `name.grp` 的 MOD 对照：

```
BookCalamity: 有    Dragon: 有    pineapple: 有    RiverLake: 有    books: 无
```

**And** 必须证明 `ranger.str` 生成**不依赖** `name.*`（它读 `ranger.grp`）。

---

## REQ-BK-13 8 道门禁

**Given** 当前 worktree
**When** 依次执行下表命令
**Then** 全部满足判据：

| # | 命令 | 判据 |
|---|------|------|
| 1 | `lua tests/test_runner.lua` | `通过: 1842 失败: 0` |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `PASS`，`mismatches=0` |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures`（退出码 1 属设计） |
| 4 | `lua tools/mod_check.lua` | `总计: 20 MOD, 通过 20, 失败 0` |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` |
| 6 | `lua tools/format_spec.lua --all` | `gaps=0` |
| 7 | 20 MOD `save/` vs 源 | 真实问题 0 |
| 8 | 禁改路径 | 三处 porcelain 为空；`jyconst.lua` 无 `CC.*=` 增删 |
