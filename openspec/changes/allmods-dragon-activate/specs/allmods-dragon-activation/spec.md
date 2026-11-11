# Spec: allmods-dragon-activation

> 需求 ID 前缀 `REQ-DRG-`。Given / When / Then。

## REQ-DRG-1：构建

**Given** `reference/allmods/kys-Dragon/`
**When** `cd game && lua tools/mod_build.lua kys-Dragon`
**Then**

```
[mod_build] kys-Dragon: data files=458, saves=21, sound=80, events=1087, talk=4020
[mod_build] diff -> mods/Dragon/diff.md
```

**And** `mods/Dragon/data/fight*.grp` = **209** 个
**And** `mods/Dragon/save/` = **27** 个文件
**And** `mods/Dragon/diff.md` 已生成

---

## REQ-DRG-2：逐文件穷举审计

**Given** 源包 **811** 个文件
**When** `lua tools/mod_audit.lua --mod Dragon`
**Then**

```
total=811 in_product=555 not_in_product=256 unclassified=0 bad_evidence=0
  REQUIRED             550
  REQUIRED_CONVERTED   4
  LEGACY               5
  DEAD_FILE            1
  EDITOR_DUMP          220
  BUILD_INPUT          2
  PENDING              29
```

**And** Σ(类别) = 550 + 4 + 5 + 1 + 220 + 2 + 29 = **811** = `total` = 源文件总数 ✅
**And** `unclassified=0`（无 OTHER/UNKNOWN 兜底）
**And** `bad_evidence=0`
**And** 「必需但未进产物」矛盾数 = 0：
`needed=true` 的 554 项（550 + 4）全部 `in_product=true`；
`not_in_product=256` = `EDITOR_DUMP 220 + PENDING 29 + LEGACY 5 + DEAD_FILE 1 + BUILD_INPUT 1`

---

## REQ-DRG-3：字节级格式覆盖

**Given** 12 个格式族
**When** `lua tools/format_spec.lua --mod Dragon`
**Then** `formats=12 checked=535 gaps=0`
（每字节归入具名字段，无 "rest"-only 区间）

---

## REQ-DRG-4：真实启动链路（独立子进程）

**Given** 干净 `active_mod.txt`（已删除）
**When** `lua tests/unit/boot_one_mod.lua Dragon 589 237 106 114 資`
**Then** 16/16 PASS：

```
[PASS] lib.init 无报错
[PASS] JYMainAdapter.init 无报错
[PASS] CC.PersonSize=182（MOD 布局）
[PASS] CC.ThingSize=190（MOD 布局）
[PASS] CC.SceneSize=52（MOD 布局）
[PASS] CC.WugongSize=136（MOD 布局）
[PASS] LoadRecord(0) 无报错
[PASS] PersonNum = 589
[PASS] ThingNum  = 237
[PASS] SceneNum  = 106
[PASS] WugongNum = 114
[PASS] 主角姓名 = 資
[PASS] 扫描字段数 > 100（实际 2109）
[PASS] 全量字符串无 U+FFFD (0)
[PASS] 全量字符串无控制符 (0)
[PASS] 运行时 10 帧无报错
RESULT Dragon: OK
```

---

## REQ-DRG-5：`hdgrp` 267（判据第 7 次应用）

**Given** `mods/Dragon/data/hdgrp.idx` = 1068 字节
**When** 应用三重判据
**Then**

| 判据 | 证据 | 成立 |
|------|------|:----:|
| ① 索引驱动 | `lib_love.lua:437` `local num = idxlen/4` | ✅ |
| ② 无固定计数常量 | `grep -rn "hdgrpNum\|HDGRPNum\|HDPicNum\|MAX_HEAD"` → 0 命中 | ✅ |
| ③ 字节无缺口 | `format_spec --mod Dragon` → `gaps=0` | ✅ |

**And** `1068 ÷ 4 = 267` 条目（基线 115，+152）
**And** 判为**内容差异**，零引擎改动
**And** 外推链 125 / 129 / 173 / 178 / 204 / 252 / **267** 七次一致

---

## REQ-DRG-6：`eft` 714 同形 —— 同形 ≠ 回退原版

**Given** `mods/Dragon/data/eft.idx` = 2856B、`eft.grp` = 691627B
**When** 与基线比对并检查运行时路径
**Then**

| 检查 | 结果 |
|------|------|
| `eft.idx` 条目数 | **714**（= 基线 714） |
| `eft.grp` 字节 | **691627**（= 基线） |
| `eft.idx[-1] == eft.grp` 大小 | ✅ `691627 == 691627` |
| 偏移单调不减 | ✅ |
| `eft.grp` md5 | `1c5aef33893e078ade30f6d237ec6cb1` = 基线 |
| `eft.idx` md5 | `35ccc7e5cc1a096e183d3ff2919f743b` = 基线 |
| 源文件存在 | ✅ `reference/allmods/kys-Dragon/resource/eft.{grp,idx}` |
| 产物文件存在 | ✅ `mods/Dragon/data/eft.{grp,idx}` |
| 运行时路径 | `CC.EffectFile[1] = mods/Dragon/data/eft.idx`、`[2] = mods/Dragon/data/eft.grp` |

**And** 判定为 **「MOD 未修改该资源」**（内容差异为零）
**And** **不得**表述为「回退原版」—— 因为源文件存在、产物存在、路径指向 MOD 目录

---

## REQ-DRG-7：eft id 上界 52 —— 不触发 `CC.Effect` 截断

**Given** Dragon `WugongNum = 114`
**When** 扫描 `JY.Wugong[*]["武功动画&音效"]`
**Then** 最大值 = **52**
**And** 未越 `CC.Effect` 上界 52 ⇒ 本 MOD **不受** RiverLake 发现的 `CC.Effect` 53 项截断缺陷影响
**And** 归入 13/20 个「不越界」MOD 之一

---

## REQ-DRG-8：记录段 589/237/106/114（判据第 4 次应用）

**Given** `ranger.idx` 原始偏移
**When** 计算段长并整除
**Then**

```
offsets: 836, 108034, 153064, 158576, 174080, 174230
grp size: 174230
```

| 段 | 段长 | ÷ 尺寸 | 记录数 | 基线 | 差 | 余数 |
|----|-----:|-------:|-------:|-----:|---:|-----:|
| Person | 107198 | 182 | **589** | 320 | **+269** | **0** |
| Thing | 45030 | 190 | **237** | 200 | **+37** | **0** |
| Scene | 5512 | 52 | **106** | 84 | **+22** | **0** |
| Wugong | 15504 | 136 | **114** | 93 | **+21** | **0** |
| Shop | 150 | 50 | 3 | 3 | 0 | **0** |

**And** Σ 段长 = `174230 - 836 = 173394` = `107198+45030+5512+15504+150` ✅
**And** **4 段全异**（含 Scene）⇒ 判据第 4 次应用（lyff 1 段 / ptt 4 段 / RiverLake 3 段 /
Dragon 4 段 + Scene 异）

### 边界记录可读且非空

| 记录 | 值 |
|------|-----|
| `Person[0]` | 資 |
| `Person[588]` | 李卡多 |
| `Thing[0]` | 小還丹 |
| `Thing[236]` | 真武劍 |
| `Scene[0]` | 胡斐居 |
| `Scene[105]` | 西部農村 |
| `Wugong[0]` | 普通攻擊 |
| `Wugong[113]` | 閃電貂 |

### Scene 用内容证明（非计数）

| 记录 | Dragon | pascal | 相同 |
|------|--------|--------|:----:|
| `Scene[0]` | 胡斐居 | 胡斐居 | ✅（MOD 保留原版首场景） |
| `Scene[1]` | 河洛客棧 | 河洛客棧 | ✅（保留） |
| `Scene[2]` | **雪山** | 云鶴崖 | ❌ |
| `Scene[50]` | **閰基居** | （超出基线 84） | ❌ |
| `Scene[105]` | **西部農村** | （超出基线 84） | ❌ |

**And** 3/5 不同且 2 项超出基线范围 ⇒ Scene 内容确实来自 MOD

---

## REQ-DRG-9：额外战斗（119 新增 / 2 移除 / 净 +117）

**Given** pascal 92 个 `fight*.grp`
**When** 与 Dragon 209 个比对
**Then**

```
pascal fight grp: 92   Dragon: 209   diff: 119   removed: ['fight101.grp','fight102.grp']
209 = 92 - 2 + 119   ✅
```

**And** 三重确认：

| # | 证据 | 结果 |
|---|------|------|
| 1 | `diff.md` 中 `fight*.grp` MOD 独有 | **119** |
| 2 | `diff.md` set == 实测差集 set | ✅ `True` |
| 3 | 产物 209 个全部 `REQUIRED`/`in_product=true` | ✅ |

**And** 每个 `.grp` 有配对 `.idx`

---

## REQ-DRG-10：`fight101`/`fight102` 缺失容错

**Given** Dragon 的 `Person["头像代号"]` **实际引用 101 和 102**

```
Person 总数=589 有头像代号=217 最大=219
引用 101 ? true   引用 102 ? true
```

**When** 引擎尝试加载缺失的 `fight101`/`fight102`
**Then** 三级优雅降级生效：

| 级 | 位置 | 行为 |
|----|------|------|
| 1 | `PicLoadFile`（`lib_love.lua:423`） | `FileLength` 打开失败返回 **-1** ⇒ `if idxlen < 0 or grplen < 0 then return end` |
| 2 | `PicFile:getPic`（`:262`） | `f == nil` 或 `idx[picid] == nil` ⇒ `Debug()` + `return nil` |
| 3 | `PicGetXY`（`:454`） | 上游 nil 保护 |

实测：

```
PicLoadFile(缺失 fight101) pcall=true err=nil
PicGetXY        pcall=true ret=0
```

**And** 判定为 **MOD 作者侧数据不一致**（非构建缺陷），不复制基线文件、不篡改数据

---

## REQ-DRG-11：存档完好 + 25 项「基准独有」五分法（新增第 5 类）

**Given** 源 `save/` **27** 文件、`diff.md`「基准独有」**25** 项
**When** 逐字节比对并逐项定性
**Then**

```
源 save: 27   产物 save: 27
缺失/不一致: []
产物多余: []
```

**And** 27 个产物文件 = 21 个 `.grp`（`alldef`/`allsin`/`ranger` + `d1`~`d6`/`d11` +
`r1`~`r6`/`r11` + `s1`~`s6`/`s11`）+ 6 个 `.idx`（`alldef`/`allsin`/`ranger`/`r1`/`r2`/`r3`）。

> **修正（本 change 初稿错误）**：初稿曾声称「源 `save/` 无 `.idx` 槽 ⇒ 无首次播种类别」。
> 实测源 `save/` 含 `alldef.idx` 336B、`allsin.idx` 336B、`ranger.idx` 24B，
> 但**不含** `r1.idx`/`r2.idx`/`r3.idx` ⇒ **仍存在 9 项首次播种**。

**25 项「基准独有」五分法**：

| 类别 | 项数 | 判据要点（运行时实测） |
|------|-----:|------------------------|
| **A 在 save/（源自带存档）** | 9 | `d1`~`d3`/`r1`~`r3`/`s1`~`s3` `.grp`；源↔产物**逐字节一致** |
| **B 首次播种** | 9 | `d1`~`d3`/`r1`~`r3`/`s1`~`s3` `.idx`；源无、产物有；`SeedSaveSlot` 播种 |
| **C 回退原版** | 2 | `thing.{grp,idx}`；`CC.ThingPicFile = data/thing.*`（**基线**目录） |
| **D 死文件** | 1 | `allsinbk.grp`；`CC.TempS_Filename` 传入 `LoadSMap` 但 `tmpfilename` 形参**零引用** |
| **E 数据引用但资源缺失（本 epic 新增）** | **4** | `fight101`/`fight102` 的 `.grp`+`.idx`；MOD 删除贴图但 `Person["头像代号"]` **仍引用 101/102** |

Σ = 9 + 9 + 2 + 1 + 4 = **25** ✅

**B 类可执行判据（打印 `CC.*` 运行时值）**：

```
slot 0 idx=mods/Dragon/data/ranger.idx   size=24    ← MOD 目录（模板）
slot 1 idx=mods/Dragon/save/r1.idx       size=-1    ← 尚不存在 ⇒ 触发播种
slot 2 idx=mods/Dragon/save/r2.idx       size=-1
slot 3 idx=mods/Dragon/save/r3.idx       size=-1
```

`SeedSaveSlot(1..3)` 实测返回 `mods/Dragon/save/r{1,2,3}.idx`，播种后 size=24；
逐字节比对：`r1/2/3.idx == MOD ranger.idx` → **True**；`== 基线 ranger.idx` → **False**
⇒ 播种源是 **MOD** 的模板，不是基线。

**E 类（本 epic 第 5 个类别，首次出现）**：

| 维度 | 说明 |
|------|------|
| 与 A 的区别 | A 是「基准有、MOD 也有」（在 `save/`）；E 是「基准有、MOD 完全没有」 |
| 与 D 的区别 | D 是「源里有、引擎不读」；E 是「源里没有、数据仍引用」 |
| 与 RiverLake 0 字节 fight 的区别 | RiverLake「文件在但内容空」；Dragon「文件根本不在」 |
| 引擎行为 | 三级降级，不崩溃（见 REQ-DRG-10） |

---

## REQ-DRG-12：`war1.sta` `DEAD_FILE`

**Given** `reference/allmods/kys-Dragon/resource/war1.sta` = 66030B（`66030 ÷ 186 = 355` 记录）
**When** 检查引擎可达性
**Then**

| # | 证据 | 结果 |
|---|------|------|
| 1 | `CC.WarFile` 只指向 `war.sta` | `script/jyconst.lua:129` `CC.WarFile = CONFIG.DataPath .. "war.sta"` |
| 2 | 代码零引用 | `grep -rn "war1" script/ framework/ engine-love2d/` → **0 命中** |
| 3 | 审计已标 `DEAD_FILE` | `tools/mod_audit.lua:189` `category="DEAD_FILE", needed=false` |

**And** 与 RiverLake `allsinbk.grp` 的机制区别必须显式说明：

| 维度 | RiverLake `allsinbk.grp` | Dragon `war1.sta` |
|------|--------------------------|-------------------|
| 常量 | **存在**（`CC.TempS_Filename`） | **不存在** |
| 传参 | **传入** `LoadSMap` | 从不传入 |
| 引擎侧 | 形参声明但**未使用** | 完全无代码路径 |
| 语义 | **路径被引用 ≠ 内容被使用** | **路径从未被引用** |

---

## REQ-DRG-13：`head/` 220 PNG = `EDITOR_DUMP`

**Given** `reference/allmods/kys-Dragon/head/` 220 个 PNG
**When** 应用四条证据
**Then**

| # | 证据 | 结果 |
|---|------|------|
| 1 | 构建忽略 | `tools/mod_build.lua:567` `IGNORE_DIRS = { head = true, item = true, eft = true }` |
| 2 | 引擎零引用 | `grep -rn 'head/\|"head"' engine-love2d/ framework/ script/` → **0 命中** |
| 3 | 产物无该目录 | `ls mods/Dragon/` → `data diff.md encoding-report.md save script sound` |
| 4 | 审计归类 | 220 项全 `EDITOR_DUMP` / `in_product=false` |

**And** 运行时头像数据源 = `hdgrp.{idx,grp}`（267 条目），PNG 仅编辑器预览

---

## REQ-DRG-14：原版零回归

**Given** 全部验证完成
**When** 执行 8 道门禁
**Then**

| # | 门禁 | 期望 |
|---|------|------|
| 1 | `lua tests/test_runner.lua` | **1842/1842** |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `mismatches=0` PASS |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures` |
| 4 | `lua tools/mod_check.lua` | **20/20** |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` |
| 6 | `lua tools/format_spec.lua --all` | `gaps=0` |
| 7 | 20 MOD `save/` vs 源 | 不一致/残留 = 0 |
| 8 | 禁改路径 | 零改动 |

**And** `game/engine-love2d/**`、`game/engine-mud/**`、`game/script/jyconst.lua` 常量定义、
`reference/allmods/**` 零改动
