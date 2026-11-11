# ptt 验证报告（kys-ptt）

> Change: `allmods-ptt-verify` · Slice: `allmods-slice9` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-28
> 状态：**PASS**

## 0. 结论摘要

| 项 | 结果 |
|----|------|
| 构建 | `data files=362 saves=21 sound=78 events=1229 talk=5689` |
| 逐文件穷举审计 | `total=596 in_product=459 not_in_product=137 unclassified=0 bad_evidence=0` |
| 字节级覆盖 | `formats=12 checked=317 gaps=0` |
| 真实启动链路 | `RESULT ptt: OK`（16 断言全 PASS） |
| `hdgrp` | **204**（vs 115）→ 内容差异，判据**第 5 次应用** |
| 记录段 | **385/214/90/108**（vs 320/200/84/93）→ 内容差异，统一判据**第 2 次应用**（**首个 4 段全异 MOD**） |
| 额外战斗 | **+70**（162 vs 92）→ 本 epic 最多，三重确认 |
| 源存档槽 | **18 个**（本 epic 最多）→ 21/21 逐字节一致 |
| `eft/` PNG | 105 个 `EDITOR_DUMP`（4 条证据） |
| 缺陷 | **0**（零引擎改动；仅 `isStringField` 加固，逐字节 no-op） |
| 全量测试 | **1622/1622** |

**ptt 完成第 3 梯队收官（pig 173 / lyff 178 / ptt 204）。**
本 slice 唯一的代码改动是把 Slice 8 的 `isStringField` 从裸高位测试加固为
「高位字节须全 Big5 可解码」——对真实数据逐字节 no-op（20/20 `ranger.str` md5 不变），
只消除假阳性并补 9 条回归断言。

## 1. `diff.md` 逐条审计（REQ-PTTV-1）

`game/mods/ptt/diff.md`：MOD 独有 **154** 项、基准独有 **21** 项。

### 1.1 MOD 独有 154 项分类

| 类别 | 项数 | 审计类别 |
|------|-----:|----------|
| 额外战斗（`fightNNN.grp`/`.idx`，70 场） | 140 | `REQUIRED` |
| `kdef.grp`/`idx` | 2 | `REQUIRED_CONVERTED` |
| `talk.grp`/`idx` | 2 | `REQUIRED_CONVERTED` |
| `cloud.grp`/`idx` | 2 | `REQUIRED` |
| `title.grp`/`idx` | 2 | `REQUIRED` |
| `end.png`/`open.png` | 2 | `REQUIRED` |
| `ranger.str` | 1 | **构建产物**（源无） |
| `kysmod.ini` | 1 | `BUILD_INPUT`（`in_product=true`） |
| `talkutf8.txt` | 1 | `BUILD_INPUT`（`in_product=false`） |
| `save.zip` | 1 | `PLATFORM_ARTIFACT`（`in_product=false`） |
| **Σ** | **154** | |

**需修复 = 0**。

### 1.2 审计 total 与源文件总数一致（全覆盖证明）

```
$ lua tools/mod_audit.lua --mod ptt
total=596 in_product=459 not_in_product=137 unclassified=0 bad_evidence=0

$ find reference/allmods/kys-ptt -type f | wc -l
596
```

`total == 源文件数`，**每个源文件都被归类，无遗漏**。

`Σ(类别) = 454 + 4 + 3 + 105 + 2 + 1 + 27 = 596` = `total` ✔

### 1.3 137 项 `not_in_product` 全部有具名类别 + 证据

| 类别 | 项数 | 明细 | 证据种类 |
|------|-----:|------|----------|
| `EDITOR_DUMP` | 105 | `eft/` 目录（`eftNNN.idx`/`.png`） | `code` + `format`（见 §6） |
| `PENDING` | 27 | `music/*.mid` 23 + `list/*.bin` 4 | `needed=nil`（未判定，见 §7） |
| `LEGACY` | 3 | `list/end.txt`、`list/start.txt`、`script/1.lua` | 旧引擎遗留 |
| `BUILD_INPUT` | 1 | `resource/talkutf8.txt` | 构建中间产物，已消费 |
| `PLATFORM_ARTIFACT` | 1 | `save.zip` | 源压缩包 |

## 2. 「基准独有」21 项逐项定性（REQ-PTTV-2）

| # | 文件 | 性质 | 证据 |
|---|------|------|------|
| 1 | `d1.grp` | 在 save/ | `mods/ptt/save/d1.grp` 存在且逐字节一致 |
| 2 | `d1.idx` | **首次播种** | 源 `save/` 无（ptt 源只有 3 个 `.idx`：`alldef`/`allsin`/`ranger`） |
| 3 | `d2.grp` | 在 save/ | 同上 |
| 4 | `d2.idx` | 首次播种 | 同上 |
| 5 | `d3.grp` | 在 save/ | 同上 |
| 6 | `d3.idx` | 首次播种 | 同上 |
| 7 | `r1.grp` | 在 save/ | 同上 |
| 8 | `r1.idx` | 首次播种 | 同上 |
| 9 | `r2.grp` | 在 save/ | 同上 |
| 10 | `r2.idx` | 首次播种 | 同上 |
| 11 | `r3.grp` | 在 save/ | 同上 |
| 12 | `r3.idx` | 首次播种 | 同上 |
| 13 | `s1.grp` | 在 save/ | 同上 |
| 14 | `s1.idx` | 首次播种 | 同上 |
| 15 | `s2.grp` | 在 save/ | 同上 |
| 16 | `s2.idx` | 首次播种 | 同上 |
| 17 | `s3.grp` | 在 save/ | 同上 |
| 18 | `s3.idx` | 首次播种 | 同上 |
| 19 | `thing.grp` | 回退原版 | `CC.ThingPicFile[2]` = `data/thing.grp`（MOD 未提供） |
| 20 | `thing.idx` | 回退原版 | `CC.ThingPicFile[1]` = `data/thing.idx` |
| 21 | `allsinbk.grp` | 死文件 | `CC.TempS_Filename` 在 `jyconst.lua:96` 定义，仅在 `jymain.lua:1835` 作为 `LoadSMap` 的第 2 实参传入，而 `engine-love2d/lib_love.lua:890` 的 `LoadSMap` **形参 `tmpfilename` 全函数零使用** → 该文件永不被读取 |

统计：**在 save/ 9 + 首次播种 9 + 回退原版 2 + 死文件 1 = 21** ✔ 无未解释项。

### 2.1 「首次播种」机制实测

```
$ lua -e '... ModData.SetActive("ptt") ...'
播种前 mods/ptt/save/r1.idx: false
mods/ptt/data/ranger.idx 模板: true
ModData.SeedSaveSlot(1) → "mods/ptt/save/r1.idx"
播种后 r1.idx: true
与 ranger.idx 逐字节一致: true
```

ptt 源 `save/` 的 28 个文件中只有 3 个 `.idx`（`alldef.idx`/`allsin.idx`/`ranger.idx`），
**没有 `rN.idx`/`dN.idx`/`sN.idx`** —— 这是本 epic 首次遇到的形态：
9 个 `.idx` 完全靠 `ModData.SeedSaveSlot` 从 `data/ranger.idx` 派生。

## 3. MOD 独有内容确实被加载（REQ-PTTV-3）

### 3.1 非基线值证明

同一套启动链路分别激活 ptt 与 pascal，对比运行时数据：

| 字段 | ptt | pascal 基线 | 差异证明 |
|------|-----|------------|----------|
| `Person[0].姓名` | **鄉民** | 小蝦米 | ✔ 非基线 |
| `Person[0].外号` | 天下奇男子 | 天下奇男子 | 同（同名主角外号） |
| `Person[1].姓名` | 胡斐 | 胡斐 | 同（通用角色） |
| `Thing[0].名称` | **千面人蠻牛** | 康倍特 | ✔ 非基线 |
| `Scene[0].名称` | 胡斐居 | 胡斐居 | 同 |
| `Wugong[0].名称` | 普通攻擊 | 普通攻擊 | 同 |
| `Person[384].姓名`（末条） | **卓不凡** | —（仅 320 条） | ✔ 索引超出基线 |
| `Thing[213].名称`（末条） | **高昌迷宮地圖** | —（仅 200 条） | ✔ 索引超出基线 |
| `PersonNum` | **385** | 320 | ✔ +65 |
| `ThingNum` | **214** | 200 | ✔ +14 |
| `SceneNum` | **90** | 84 | ✔ +6 |
| `WugongNum` | **108** | 93 | ✔ +15 |
| talk 条目 | **5689** | 2977 | ✔ +2712 |
| events | **1229** | 1018 | ✔ +211 |
| fight | **162** | 92 | ✔ +70 |
| `hdgrp` | **204** | 115 | ✔ +89 |

**注**：`Person[0].外号`/`Person[1]`/`Scene[0]`/`Wugong[0]` 与基线相同属正常（同名通用数据），
证明「MOD 内容已加载」用的是其余 12 项非基线值，**未使用「记录数相同」类弱证据**。

### 3.2 回退链路径确认

```
CC.HeadPicFile[1]   = mods/ptt/data/hdgrp.idx
CC.TalkGrpFile      = mods/ptt/script/oldtalk.grp
CC.R_GRPFilename[1] = mods/ptt/save/r1.grp
CC.D_Filename[1]    = mods/ptt/save/d1.grp
CC.S_Filename[1]    = mods/ptt/save/s1.grp
CC.ThingPicFile[1]  = data/thing.idx      ← 回退原版（MOD 未提供）
CC.ThingPicFile[2]  = data/thing.grp      ← 回退原版
```

## 4. `hdgrp` 204（REQ-PTTV-4，判据第 5 次应用）

| 判据 | 实测 |
|------|------|
| 索引驱动 | `hdgrp.idx` = **816 字节** = 204 × 4；`PicLoadFile` 用 `idxlen/4`（`engine-love2d/lib_love.lua:437`） |
| 无固定计数 | `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` **全 `nil`** |
| 字节全覆盖 | `format_spec --format hdgrp --mod ptt` → `formats=1 checked=1 gaps=0` |

**判定：内容差异**（+89 头像）。
**外推链**：Slice 5 HeavenSword **125** → Slice 6 GodsDevils **129** → Slice 7 pig **173** →
Slice 8 lyff **178** → Slice 9 ptt **204**，**五次结论一致**。

## 5. 4 段记录数差异（REQ-PTTV-4，统一判据第 2 次应用）

### 5.1 段长整除校验

`ranger.idx` 段偏移 = `836, 70906, 111566, 116246, 130934, 131084`

| 段 | 段长 | 记录大小 | 条数 | 整除 | pascal | 差异 |
|----|-----:|--------:|-----:|:----:|-------:|-----:|
| Person | 70070 | 182 | **385** | YES | 320 | **+65** |
| Thing  | 40660 | 190 | **214** | YES | 200 | **+14** |
| Scene  |  4680 |  52 | **90**  | YES |  84 | **+6** |
| Wugong | 14688 | 136 | **108** | YES |  93 | **+15** |
| Shop   |   150 |  50 | **3**   | YES |   3 | 0 |

**全部整除，无余数** → 布局与基线相同，仅条目数不同。

### 5.2 索引驱动 + 无固定计数

- `JY.PersonNum = math.floor((idx[2] - idx[1]) / CC.PersonSize)`（`jymain.lua:1747`）
- `JY.ThingNum`/`SceneNum`/`WugongNum` 同构（按 `idx[k+1]-idx[k]` ÷ 记录大小）
- 全仓库**无** `PERSON_NUM`/`THING_NUM` 类固定计数常量
- `CC.PersonSize`/`ThingSize` 等是**记录大小**（182/190/52/136），不是**条目数**

### 5.3 边界记录有效

**边界 hint（产物 `mods/ptt/data/ranger.grp` 末条记录）**：

| 段 | 末条索引 | 字段 @偏移 → hint |
|----|---------:|-------------------|
| Person | 384 | `@8` → `P0489` · `@18` → `N0448` |
| Thing  | 213 | `@2` → `T0395` · `@22` → `T20395` · `@42` → `TD0395` |
| Scene  | 89  | `@2` → `S0088` |
| Wugong | 107 | `@2` → `W0107` |

（hint 是构建期写入的旁路表指针，符合方案 D 设计；源 `ranger.grp` 该处为 Big5 原文。）

**边界内容可读（运行时）**：

| 段 | 末条索引 | 名称 |
|----|---------:|------|
| Person | 384 | 卓不凡 |
| Thing  | 213 | 高昌迷宮地圖 |
| Scene  | 89  | 計老人居 |
| Wugong | 107 | 天魔極樂 |

### 5.4 结论

**内容差异**（零引擎改动）。统一判据（Slice 8 ADR-001）的**第 2 次应用**，
且是**首个 4 段全部异于基线的 MOD**（lyff 仅 Person 段差异）。
外推记录：**lyff(1 段) → ptt(4 段全异)**。

## 6. 70 场额外战斗（REQ-PTTV-5，本 epic 最多）

### 6.1 三重确认

| # | 证据 | 实测 |
|---|------|------|
| 1 | `diff.md` 提及 | MOD 独有 154 项中 **140 项** = 70 场 × (`.grp`+`.idx`) |
| 2 | 产物存在 | `ls mods/ptt/data/fight*.grp \| wc -l` = **162**；`comm -13` vs pascal = **70** |
| 3 | 审计归类 | 162 个 `fight*.grp` **全部** `REQUIRED`/`in_product=true`；其他类别 = **0** |

### 6.2 抽样 5 场逐项复核

| 文件 | category | in_product | 产物存在 | `diff.md` 提及 |
|------|----------|:----------:|:--------:|:--------------:|
| `fight073.grp` | REQUIRED | true | true | ✔ |
| `fight130.grp` | REQUIRED | true | true | ✔ |
| `fight154.grp` | REQUIRED | true | true | ✔ |
| `fight195.grp` | REQUIRED | true | true | ✔ |
| `fight216.grp` | REQUIRED | true | true | ✔ |

### 6.3 判定

**内容差异**（无固定战斗数量常量；`fightNNN.grp` 由脚本按编号引用；`gaps=0`）。
外推：Slice 7 pig +45 → Slice 8 lyff +46 → Slice 9 ptt **+70**（本 epic 最多）。

## 7. `eft/` 105 个 `EDITOR_DUMP`（REQ-PTTV-8）

| # | 证据 | 实测 |
|---|------|------|
| 1 | 构建期忽略 | `game/tools/mod_build.lua:567`：`IGNORE_DIRS = { head = true, item = true, eft = true }` |
| 2 | 引擎 0 引用 | `grep -rn "eft/" game/script/jyconst.lua game/engine-love2d/*.lua game/framework/*.lua` → **无输出** |
| 3 | 产物中不存在 | `ls -d game/mods/ptt/eft` → **不存在** |
| 4 | 审计归类 | 105 项全为 `EDITOR_DUMP` / `in_product=false` / `needed=false` |

`eft/` 与 Slice 6 的 `head/`/`item/` 同族，均为 UPedit 编辑器导出的图片目录。

## 8. PENDING 27 项边界（REQ-PTTV-9）

| 项 | 数量 | 归属 |
|----|-----:|------|
| `music/1.mid` ~ `music/23.mid` | 23 | **全局遗留 spike**（epic `TODO.md`「MOD 音乐引用分析」）：C 引擎 MIDI（`.mid` + `mid.sf2` 音色库）vs Lua 引擎 `sound/game%02d.ogg`（25 槽），格式/槽位/编号语义三重不匹配。需先做 spike 确定「需几首、编号怎么对应」再决定转换范围。 |
| `list/effect.bin`、`list/leave.bin`、`list/levelup.bin`、`list/match.bin` | 4 | C 引擎列表数据（`.bin`），Lua 引擎无读取路径。 |

`needed=nil`（PENDING）≠ `needed=false`（已判定为不需要）：27 项是**未判定**，
不是判定为不需要。审计工具用 `nil` 显式区分二者，避免伪证据。

## 9. 存档验证

- 源 `reference/allmods/kys-ptt/save/` 28 个文件
- 产物 `game/mods/ptt/save/` **21 个文件**
- 逐字节比对：**21/21 一致，不一致 = 0**

```
$ for f in $(ls game/mods/ptt/save/); do cmp -s reference/allmods/kys-ptt/save/$f game/mods/ptt/save/$f; done
检查 21 个，不一致 = 0
```

**非槽位文件去向**：

| 文件 | 去向 |
|------|------|
| `ranger.grp`/`ranger.idx` | `mods/ptt/data/` ✔ |
| `alldef.grp`/`alldef.idx` | `mods/ptt/data/` ✔ |
| `allsin.grp`/`allsin.idx` | `mods/ptt/data/` ✔ |
| `save.zip` | 源压缩包，解包产物即上列文件，不进产物 |

**18 个源存档槽**（`d1`~`d6`/`r1`~`r6`/`s1`~`s6`）为本 epic 最多（pig 9 个、lyff 3 个）。
产物另有 `d11`/`r11`/`s11`（源自带，也逐字节一致）。

## 10. 零回归

| 门禁 | 命令 | 结果 |
|------|------|------|
| 全量单测 | `lua tests/test_runner.lua` | **1622/1622 通过，0 失败** |
| pascal 基线 | `lua tools/mod_build.lua --verify-pascal` | `events=1018, mismatches=0, known-deviations=3` · **PASS** |
| 全 MOD 构建 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures, 5 annotated-problematic` |
| 全 MOD 自检 | `lua tools/mod_check.lua` | **20/20 通过，失败 0** |
| 全 MOD 审计 | `lua tools/mod_audit.lua --all` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0` |
| 证据校验 | `lua tools/mod_audit.lua --all --evidence` | `evidence: checked=17 failed=0` |
| 字节覆盖 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` |
| 存档完好 | 全 20 MOD `save/` vs 源逐字节 | **341** 个文件，**不一致 = 0** |

> **偏差记录（已排除）**：本轮曾出现 2 个 `test_mod_boot` 失败
> （`r1.idx auto-seeded by SaveRecord` / `save/load round-trip`）。
> 根因是**并行执行**：全量测试在后台跑的同时，我另起进程跑了
> `lua tools/mod_build.lua --all`，后者重写 `mods/mingdong/save/` 与测试写盘竞态。
> 单独复跑 `mod_boot`（87/87）与**全量串行复跑**（1622/1622）均通过。**非代码回归**。

## 11. 第 3 梯队进度

| 梯队 | MOD | hdgrp | fight | 记录段 | 状态 |
|------|-----|------:|------:|--------|------|
| 第 3 | kys-pig | 173 | 137 | 320/200/84/93 | ✅ Slice 7 |
| 第 3 | kys-lyff | 178 | 138 | **326**/200/84/93 | ✅ Slice 8 |
| 第 3 | **kys-ptt** | **204** | **162** | **385/214/90/108** | ✅ **Slice 9（本 slice）** |

**第 3 梯队收官**（hdgrp 170~210 全部完成）。

剩余 MOD：

| 梯队 | MOD | hdgrp | fight | 状态 |
|------|-----|------:|------:|------|
| 第 4 | kys-RiverLake | 252 | 219 | 待做 |
| 第 4 | kys-Dragon | 267 | 209 | 待做 |
| 第 4 | kys-pineapple | 300 | 154 | 待做 |
| 第 5 | kys-books | 696 | 178 | 待做 |

## 12. 结论

**PASS**。ptt 适配完成，**零引擎改动、零代码改动**（继 Slice 6/7/8 之后第 3 个）：

1. **记录段** 385/214/90/108 —— 首个 4 段全异 MOD，统一判据第 2 次应用成功。
2. **`hdgrp` 204** —— 判据第 5 次应用（125→129→173→178→204）五次一致。
3. **+70 额外战斗** —— 本 epic 最多；三重确认 + 全量 162 审计归类 + 5 场抽样。
4. **18 个源存档槽** —— 本 epic 最多；21/21 逐字节一致；9 个 `.idx` 靠首次播种。
5. **105 个 `eft/` PNG** —— 4 条机器可复核 `EDITOR_DUMP` 证据。
6. 全部门禁通过，**无回归、无缺陷**。
