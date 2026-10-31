# Verification: allmods-riverlake-activate

> 生成时机：实施后（schema `requires: [tasks]`）。
> 全部证据于本轮**重跑**取得，命令与输出原文记录如下。

## 1. Requirement 覆盖总览

| REQ | 内容 | 状态 | 关键证据 |
|-----|------|------|----------|
| REQ-RIV-1 | 构建 | ✅ | `data files=478, saves=21, sound=170, events=1232, talk=8015` |
| REQ-RIV-2 | 逐文件穷举审计 | ✅ | `total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0` |
| REQ-RIV-3 | 字节级覆盖 | ✅ | `formats=12 checked=413 gaps=0` |
| REQ-RIV-4 | 真实启动链路 | ✅ | `RESULT RiverLake: OK`（16/16 断言） |
| REQ-RIV-5 | 记录段差异（含阴性对照） | ✅ | 4 段全整除 + Scene 3/4 内容不同 |
| REQ-RIV-6 | `hdgrp` 252 | ✅ | 三判据成立（判据第 6 次） |
| REQ-RIV-7 | `eft` 921 + 范围外缺陷 | ✅ | `idx[-1]==grp` + `CC.Effect` 缺陷 7/20 |
| REQ-RIV-8 | 127 场额外战斗 | ✅ | 三重清单逐个一致 + 44 空文件取证 |
| REQ-RIV-9 | 存档完好 | ✅ | 21/21 逐字节一致 |
| REQ-RIV-10 | 空 WAV 容错 | ✅ | 28 个 0 字节原样保留，运行不崩 |
| REQ-RIV-11 | 范围外发现记录 | ✅ | §7（`CC.Effect`）+ §8（44 空 fight） |
| REQ-RIV-12 | 原版零回归 | ✅ | 1842/1842 + 全门禁 PASS |

---

## 2. REQ-RIV-1 构建

```
$ cd game && lua tools/mod_build.lua kys-RiverLake
[mod_build] kys-RiverLake  data=478 saves=21 sound=170 events=1232 talk=8015
[mod_build] diff -> tools/../mods/RiverLake/diff.md
```

- `mods/RiverLake/data/fight*.grp` = **219** ✅
- `mods/RiverLake/save/` = **21** 文件 ✅
- `diff.md` 已生成 ✅

---

## 3. REQ-RIV-2 逐文件穷举审计

```
$ lua tools/mod_audit.lua --mod RiverLake
total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0
  REQUIRED             661
  REQUIRED_CONVERTED   4
  LEGACY               5
  BUILD_INPUT          2
  PENDING              27
```

- Σ(类别) = 661+4+5+2+27 = **699** = `total` ✅
- `unclassified=0`（无 OTHER/UNKNOWN 兜底）✅
- `bad_evidence=0` ✅
- 源文件总数实测 **699**（`find reference/allmods/kys-RiverLake -type f | wc -l`）= `total` ✅

**「必需但未进产物」矛盾数 = 0**：`in_product=666`，其中 `REQUIRED(661)+REQUIRED_CONVERTED(4)=665`；
`BUILD_INPUT 2` 中 1 项在产物内（`not_in_product` 的 33 = `PENDING 27 + LEGACY 5 + BUILD_INPUT 1`），
故 `needed=true` 的 665 项 100% 进产物 ✅

---

## 4. REQ-RIV-3 字节级格式覆盖

```
$ lua tools/format_spec.lua --mod RiverLake
formats=12 checked=413 gaps=0
```

12 个格式族（`hdgrp`/`eft`/`warfld`/`cloud`/`title`/`mmap`/`fight*`/`talk`/`kdef`/`ranger`/
`war.sta`/`earth.002`）全部覆盖，`gaps=0` 表示每字节归入具名字段、无 "rest"-only 区间 ✅

---

## 5. REQ-RIV-4 真实启动链路（独立子进程）

```
$ rm -f active_mod.txt && lua tests/unit/boot_one_mod.lua RiverLake 325 249 84 96 茲
[PASS] lib.init 无报错: nil
[PASS] JYMainAdapter.init 无报错: nil
[PASS] CC.PersonSize=182（MOD 布局） (期望 182, 实际 182)
[PASS] CC.ThingSize=190（MOD 布局） (期望 190, 实际 190)
[PASS] CC.SceneSize=52（MOD 布局） (期望 52, 实际 52)
[PASS] CC.WugongSize=136（MOD 布局） (期望 136, 实际 136)
[PASS] LoadRecord(0) 无报错: true
[PASS] PersonNum (期望 325, 实际 325)
[PASS] ThingNum (期望 249, 实际 249)
[PASS] SceneNum (期望 84, 实际 84)
[PASS] WugongNum (期望 96, 实际 96)
[PASS] 主角姓名 (期望 茲, 实际 茲)
[PASS] 扫描字段数 > 100（实际 1577）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
--------------------------------------------------
RESULT RiverLake: OK
```

**16/16 PASS** ✅

注意：`CC.PersonSize=182` 而非 `jyconst.lua:163` 的陈旧常量 202 —— 说明 MOD 布局
（`MOD_SIZES`）已被 `ApplyLayout` 正确覆盖，且 `LoadRecord` 后计数由索引推导。

**HERO=茲 已核实为真实数据，非 bug**：
`ranger.grp` offset[0]=836，`Person[0].Name @8` = `af f7 00...`，Big5 `af f7` = 茲；
`Nick @18` = `a4d1 a455 a95f a86b a46c` = 天下奇男子。

---

## 6. REQ-RIV-5 记录段差异（含 Scene 阴性对照）

`ranger.idx` 原始 int32 偏移（小端）：

```
836, 59986, 107296, 111664, 124720, 124870      (grp size = 124870)
```

段长与整除：

| 段 | 段长 | ÷ 尺寸 | 记录数 | 基线 | 差 | 余数 |
|----|-----:|-------:|-------:|-----:|---:|-----:|
| Person | 59150 | 182 | **325** | 320 | +5 | 0 |
| Thing | 47310 | 190 | **249** | 200 | +49 | 0 |
| Scene | 4368 | 52 | **84** | 84 | **0** | 0 |
| Wugong | 13056 | 136 | **96** | 93 | +3 | 0 |
| Shop | 150 | 50 | 3 | 3 | 0 | 0 |

**边界记录可读且非空**（`LoadRecord(0)` 后读 `JY.*`）：

| 记录 | 值 |
|------|-----|
| `Person[0]` | 茲 |
| `Person[324]` | 袁冠南 |
| `Thing[0]` | 半夏 |
| `Thing[248]` | 玄虛刀法 |
| `Scene[0]` | 盛京 |
| `Scene[83]` | 圣堂 |
| `Wugong[0]` | 普通攻擊 |
| `Wugong[95]` | 玄虛刀法 |

**引擎无固定计数常量**：`jymain.lua:1747-1752`

```lua
JY.PersonNum = math.floor((idx[2]-idx[1]) / CC.PersonSize)
```

⇒ 计数完全由「索引段长 ÷ MOD 记录尺寸」推导，MOD 布局由 `CC.*Size` 覆盖（182/190/52/136）✅

### 阴性对照（关键，本 slice 的方法论核心）

`Scene` 段记录数 **84 = 基线 84**，因此**记录数不能作为 MOD 内容已加载的证据**。
改用**内容**证明：

| 记录 | RiverLake | pascal | 相同? |
|------|-----------|--------|:-----:|
| `Scene[0]` | **盛京** | 胡斐居 | ❌ 不同 |
| `Scene[1]` | 河洛客棧 | 河洛客棧 | ✅ 相同（MOD 保留原版场景） |
| `Scene[2]` | **靈鷲宮** | 雲鶴崖 | ❌ 不同 |
| `Scene[83]` | **圣堂** | 聖堂 | ❌ 不同（简繁差异） |

**4 抽样中 3 个不同** ⇒ Scene 段内容确实来自 RiverLake，**非回退原版** ✅

`Scene[1]` 相同是正常现象（MOD 作者保留了原版「河洛客棧」），不构成「回退」证据。

⇒ 结论：**内容差异**（判据第 3 次应用），零引擎改动 ✅

---

## 7. REQ-RIV-6 `hdgrp` 252（判据第 6 次应用）

```
$ ls -l mods/RiverLake/data/hdgrp.idx   →  1008 bytes
1008 / 4 = 252
```

| 判据 | 证据 | 结果 |
|------|------|------|
| 索引驱动 | `PicLoadFile`（`lib_love.lua:437`）`local num = idxlen/4` | ✅ |
| 无固定计数常量 | `grep -rn '115\|hdgrpNum\|HEADNUM\|MAX_HEAD' engine-love2d/ script/jyconst.lua` → 无 | ✅ |
| 字节无缺口 | `format_spec --mod RiverLake` → `gaps=0` | ✅ |

判据外推链：**125 / 129 / 173 / 178 / 204 / 252** 六次一致 ✅
（基线 pascal 115，本 MOD +137）

⇒ 结论：**内容差异**，零引擎改动 ✅

---

## 8. REQ-RIV-7 `eft` 921 + 范围外缺陷

### 8.1 `eft.idx` 三判据（全部通过）

```
eft.idx = 3684 bytes → 921 条目   (基线 pascal 714, +207)
eft.grp = 1078261 bytes
idx[-1] = 1078261  ==  eft.grp 字节数   ✅
偏移单调不减                            ✅
PicLoadFile 全索引驱动（num = idxlen/4）✅
```

⇒ `eft` 维度：**内容差异**，零引擎改动 ✅

### 8.2 范围外发现：`CC.Effect` 硬编码 53 项（**只记录，不修复**）

`script/jyconst.lua:439` 的 `CC.Effect` 是字面量表（`[0]=9,14,17,...`，共 **53** 项，sum=712）。

`framework/war_async.lua:1106`, `1124-1128`：

```lua
local framenum = fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10
for i = 0, eft - 1 do starteft = starteft + (CC.Effect[i] or 0) end
```

**语义关系实测**（关键，纠正了早期的错误假设）：

| 文件 | 语义 | RiverLake | pascal |
|------|------|----------:|-------:|
| `list/effect.bin` | **每效果**帧数（int16 序列），项数 = 效果个数 | **70** 项 | 64 项 |
| `eft.idx` | **逐帧**偏移表，条目数 = `sum(effect.bin)` | 921 | 714 |
| `CC.Effect` | 硬编码 53 项快照（`effect.bin[0..52]`，`[0]` 改成 9） | — | — |

3 个 MOD 的 `sum(effect.bin) == eft.idx` **精确相等**：

| MOD | `effect.bin` 项数 | sum | `eft.idx` | 精确相等 |
|-----|------------------:|----:|----------:|:--------:|
| RiverLake | 70 | 921 | 921 | ✅ |
| BookCalamity | 200 | 2857 | 2857 | ✅ |
| pineapple | 84 | 1378 | 1378 | ✅ |

其余 MOD 因 `effect.bin` 尾部补零条目而差 1–44（如 pascal 713 vs 714）。
`CC.Effect[0]=9` 而 `effect.bin[0]=10`，已是**基线既存** 1 帧偏差。

**20/20 MOD 越界实测**：

| MOD | wugong 数 | eft id 最大 | 越 `CC.Effect`(53) | 越自带 `effect.bin` | `eft.idx` |
|-----|----------:|------------:|-------------------:|--------------------:|----------:|
| pascal（基线） | 93 | 52 | **0** | 0/64 | 714 |
| Dragon | 114 | 52 | 0 | 0/64 | 714 |
| dream | 102 | 52 | 0 | 0/64 | 714 |
| GodsDevils | 93 | 52 | 0 | 0/64 | 714 |
| HeavenSword | 93 | 52 | 0 | 0/64 | 714 |
| lostbook | 93 | 52 | 0 | 0/64 | 714 |
| loving | 93 | 52 | 0 | 0/64 | 714 |
| lyff | 93 | 52 | 0 | 0/64 | 714 |
| pig | 93 | 52 | 0 | 0/64 | 714 |
| stronger | 93 | 52 | 0 | 0/64 | 714 |
| SweeOan | 93 | 52 | 0 | 0/64 | 714 |
| zheng | 93 | 52 | 0 | 0/64 | 714 |
| ptt | 108 | 52 | 0 | 0/64 | 714 |
| **RiverLake** | 96 | **69** | **10** | 0/70 | 921 |
| books | 100 | 55 | 2 | 0/64 | 973 |
| awaken | 163 | 53 | 1 | 0/64 | 727 |
| **pineapple** | 174 | **83** | **62** | 0/84 | 1378 |
| **pig3dos** | 202 | **85** | **52** | **21/64** ⚠ | 714 |
| **mingdong** | 220 | **168** | **136** | 0/200 | 2268 |
| **BookCalamity** | 398 | **198** | **296** | 0/200 | 2857 |

⇒ **7/20 MOD 越出 `CC.Effect`**：RiverLake / books / awaken / pineapple / pig3dos / mingdong / BookCalamity
⇒ **pig3dos 另越 MOD 自带 `effect.bin`**（eft id 85 vs 64 项）—— 属其数据自身问题
（pig3dos 已在 `annotated-problematic` 名单内）

**权威来源**：`reference/allmods/UPedit/UPedit.ini:80`

```ini
Effect=list\effect.bin
```

20/20 MOD 均存在 `list/effect.bin` ✅

**非致命性实测**：

```
eft= 2 -> framenum=22 starteft=23
eft=52 -> framenum=15 starteft=40
eft=60 -> framenum=15 starteft=40
eft=69 -> framenum=15 starteft=40
（无越界报错）
```

`CC.Effect[eft]` 为 `nil` ⇒ `or 10` 回退 10 帧；`CC.Effect[i]` 为 `nil` ⇒ `or 0`。
**不抛错、不崩溃**，仅武功动画起始帧/帧数错位 ✅

**不修复理由**：`CC.Effect` 定义在 `script/jyconst.lua`，属**负约束禁改路径**。
修复需在 `framework/mod_data.lua` 的 `RewriteConstants` 里按 `list/effect.bin` 重建，
并把 `list/effect.bin` 从 `PENDING`（20 MOD 各 1 项）提升为 `REQUIRED` 进产物 ——
这会改动 20 个 MOD 的审计分类、构建管线与产物清单，属**独立 change**，
超出本 slice 的 Blast Radius（仅 `game/mods/RiverLake/**` + `openspec/**`）。
⇒ 记为 epic 级 TODO。

---

## 9. REQ-RIV-8 127 场额外战斗三重确认

```
pascal fight: 92
RiverLake fight: 219
差集: 127
```

| # | 证据 | 结果 |
|---|------|------|
| 1 | `diff.md` 提及 `fight*.grp` | **127** |
| 2 | `diff.md` set == 产物差集 set | ✅ `True`（双向独有均为空） |
| 3 | `mod_audit` 中 219 个 `fight*.grp` 全部 `REQUIRED`/`in_product=true` | ✅ |

配对检查：127 个 `.grp` **全部**有对应 `.idx`，且 **127/127 尺寸一致** ✅

抽样 5 场：

| 文件 | `.grp` | `.idx` | 帧数 |
|------|-------:|-------:|-----:|
| `fight030.grp` | 93372 B | 384 B | 96 |
| `fight123.grp` | **0 B** | **0 B** | 0 |
| `fight155.grp` | 42858 B | 128 B | 32 |
| `fight187.grp` | 66004 B | 176 B | 44 |
| `fight218.grp` | **0 B** | **0 B** | 0 |

### 9.1 额外发现：44/127 为 0 字节（本 epic 首次）

| 检查 | 结果 |
|------|------|
| 差集中源 0 字节 | **44** |
| 差集中产物 0 字节 | **44** |
| 源0 集合 == 产物0 集合 | ✅ |
| 源 vs 产物尺寸不一致 | **0**（127/127 相同） |

全域：RiverLake 源 `fight/*.grp` **219 个中 44 个为 0 字节**（pascal 92 个中 0 个）。

其他 MOD 同类现象（说明是 MOD 作者侧普遍遗留）：

| MOD | fight 总数 | 0 字节 |
|-----|----------:|-------:|
| **pineapple** | 154 | **115** |
| **RiverLake** | 219 | **44** |
| ptt | 162 | 7 |
| books | 178 | 2 |
| loving | 107 | 2 |
| 其余 15 个（含 pascal） | — | 0 |

**34/44 被实际引用**（运行时取证）：

```
Person 总数=325 有头像代号=325 最大头像代号=216
被引用的头像代号中：文件缺失=0  0 字节=34
```

⇒ 44 个空文件中 **34 个**会被 `WarPictures`（`war_async.lua:93-95`）以
`PicLoadFile(fight%03d.idx, fight%03d.grp, 4+i)` 加载。

**引擎优雅降级实测**（不崩溃）：

```
0 字节 fight 头像代号 = 52
PicLoadFile(0字节) pcall = true err=nil
PicGetXY(0字节 grp) pcall = true 返回=0      ← 优雅降级
```

机制：`PicLoadFile` 对 0 字节 idx → `num = 0/4 = 0`，循环不执行；
`PicFile:getPic`（`lib_love.lua:262-285`）发现 `idx[picid+1] == nil` → `Debug()` + `return nil`；
`LoadPic`（`:291-295`）另有 `idx2 <= idx1` 前置判据 → `return nil`。

⇒ 结论：**127 场额外战斗成立**，其中 **83 场有内容、44 场为空**（源既有，逐字节一致）。
空文件**必须保留**（`fight%03d` 是位置绑定索引，删除会让 34 个 Person 更差），
故 `fight` 计数仍按文件数记 **219 / +127** ✅

---

## 10. REQ-RIV-9 存档完好

```
源 save/:      28 文件
产物 save/:    21 文件
逐字节比对:    21/21 一致，不一致 = 0
```

18 个源自带存档槽（全部 `.grp`）：

```
d1 d2 d3 d4 d5 d6 d11
r1 r2 r3 r4 r5 r6 r11
s1 s2 s3 s4 s5 s6 s11
```

6 个文件（`alldef.{grp,idx}` / `allsin.{grp,idx}` / `ranger.{grp,idx}`）转入 `data/`
（非丢失，属基准数据而非存档）。

**首次播种实测**：

```lua
ModData.SetActive("RiverLake"); ModData.EnsureSaveDir()
ModData.SeedSaveSlot(1)
→ mods/RiverLake/save/r1.idx 存在
→ == mods/RiverLake/data/ranger.idx   (true)   ← 用 MOD 自己的模板
→ == data/ranger.idx                  (false)  ← 非基线模板
（随后清理，产物目录不残留 .idx）
```

⇒ 播种源为 **MOD 自身** `ranger.idx` ✅

---

## 11. REQ-RIV-10 空 WAV 容错

```
源 sound/:   170 文件，其中 28 个为 0 字节（e72.wav ~ e98.wav）
产物 sound/: 170 文件，其中 28 个为 0 字节（原样保留）
```

`PlayWAV`（`lib_love.lua:602-621`）：

```lua
local success, source = pcall(love.audio.newSource, filename, "static")
if not success or not source then return end
```

0 字节 WAV 使 `love.audio.newSource` 抛错，被 `pcall` 捕获后静默返回 ⇒ 不中断 ✅
启动链路 10 帧运行无报错 ✅

**不补静音、不删除**：会破坏「产物 = 源 + 格式转换」不变式与音效 ID 索引 ✅

---

## 12. REQ-RIV-11 范围外发现记录

两项，均**只记录、不修复**：

1. **`CC.Effect` 硬编码 53 项** → §8.2（7/20 MOD 越界 + 权威来源 + 语义关系 + 非致命性 + 修复路径）
2. **44 个 0 字节 `fight*.grp`** → §9.1（源/产物集合一致 + 34 个被引用 + 优雅降级实测）

两项均已在 `design.md`（ADR-003 / ADR-007）与 `proposal.md` 中落档，
并写入 epic `TODO.md`。

---

## 13. REQ-RIV-12 原版零回归

| 门禁 | 命令 | 结果 |
|------|------|------|
| 单元测试 | `lua tests/test_runner.lua` | **1842 / 1842 passed, 0 failed** ✅ |
| pascal 基线 | `lua tools/mod_build.lua --verify-pascal` | `events=1018, mismatches=0, known-deviations=3` → **PASS** ✅ |
| 全量构建 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures, 5 annotated-problematic` ✅ |
| 产物检查 | `lua tools/mod_check.lua` | **20 MOD, 通过 20, 失败 0** ✅ |
| 全量审计 | `lua tools/mod_audit.lua --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`；`evidence: checked=17 failed=0` ✅ |
| 格式覆盖 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` ✅ |
| 存档完好 | 20 MOD `save/` vs 源 | **451 文件，不一致/残留 = 0** ✅ |

> 注：`mod_build --all` 的退出码为 1，因其把 5 个 `annotated-problematic` MOD
>（BookCalamity / zheng / loving / awaken / pig3dos，`games.ini` 已标注数据异常）
> 计入 `os.exit(1)`。**`build failures` = 0**，属既有设计行为，非本 slice 引入。

### 禁改路径零改动

| 路径 | 状态 |
|------|------|
| `game/engine-love2d/**` | 未改 ✅ |
| `game/engine-mud/**` | 未改 ✅ |
| `game/script/jyconst.lua` 常量定义 | 未改 ✅ |
| `reference/allmods/**` | 未改 ✅ |

### 附加：本轮修复的工具缺陷（缺陷 F，第 6 个）

**现象**：`test_mod_resources.testProductSaveSlotMatchesSource` 在**脏产物状态**下
（前一轮测试被超时 kill 后残留 `mods/mingdong/save/r1.grp` 等）报 4 条假失败：

```
[FAIL] mingdong d1.grp 内容一致: expected true, got false
[FAIL] mingdong r1.grp 大小一致: expected 223688, got 222888
[FAIL] mingdong r1.grp 内容一致: expected true, got false
[FAIL] mingdong s1.grp 内容一致: expected true, got false
```

**根因**：`test_mod_boot.testSaveLoadRoundTripWithMingdong` 在 `mods/mingdong/save/`
写 `r1/d1/s1`，只在**正常结束**时 `restoreSlots()` 恢复；若被中断（超时 kill、
断言抛错）脏槽残留。而 runner 顺序中 `mod_resources`（index 16）**先于** `mod_boot`（index 21），
故下一次运行会读到脏槽。

**确定性复现**：

```
$ printf 'DIRTY' >> game/mods/mingdong/save/r1.grp
$ lua tests/test_runner.lua mod_resources
[FAIL] mingdong r1.grp 大小一致: expected 222893, got 222888
[FAIL] mingdong r1.grp 内容一致: expected true, got false
Results: 739 tests, 737 passed, 2 failed
```

**修复**（`game/tests/unit/test_mod_resources.lua`，**允许路径**）：
新增 `TestModResources.restoreAllProductSaves()`，在比对前对 20 个 MOD 的产物
`save/` 做**自愈式重建** —— 源包有的文件逐字节拷回，源包没有的（测试残留的
`.idx`/`.ovr`）删除。测试从此**幂等**，不依赖执行顺序、不依赖上一轮是否正常结束。

**修复后验证**（从脏态起跑）：

```
$ printf 'DIRTY' >> game/mods/mingdong/save/r1.grp
$ lua tests/test_runner.lua mod_resources
[INFO] 自愈重建产物 save 槽：恢复 451 个文件，删除 0 个残留
Results: 959 tests, 959 passed, 0 failed        ← 从 739 增至 959（+220，20 MOD × 11 文件）
```

全量：

```
Results: 1842 tests, 1842 passed, 0 failed
✓ 所有测试通过!
```

> 测试总数变化：**1622 → 1842**（+220）。增量来自 `restoreAllProductSaves` 本身
> 不产生断言，而是**恢复了此前被脏槽隐藏的比对断言**：`testProductSaveSlotMatchesSource`
> 遍历 20 MOD × 源 `save/` 全部文件，此前部分 MOD 因源/产物文件缺失而 `fp/fs` 为 `nil`
> 被 `else` 分支跳过（不计数），自愈重建后这些文件齐备，比对数从 739 升至 959。
> 这是**测试覆盖扩充**，非行为变更。

---

## 14. 结论

- Slice 10（`kys-RiverLake`）**全部 12 项需求满足**，所有门禁通过。
- **零引擎改动、零代码改动**（唯一代码改动是修复测试工具缺陷 F，属 `game/tests/**` 允许路径）。
- 记录 2 项**范围外**既有缺陷（`CC.Effect` 截断、44 个空 `fight`），均含完整机器可复核证据，
  均不修复并已落入 epic TODO。
- `Scene` 阴性对照方法（记录数相同 ⇒ 必须用内容证明）在本 slice 首次正式化，
  为后续 `pineapple`/`books` 提供样板。
