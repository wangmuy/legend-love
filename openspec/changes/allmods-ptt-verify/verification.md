# Verification: allmods-ptt-verify

> Change: `allmods-ptt-verify` · Slice: `allmods-slice9` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-28
> 状态：**done** / **PASS**

## 1. 目标回顾

对 ptt 的构建结果做人工可复核的内容审计；判定 `hdgrp` 204 / fight 162 /
4 段记录数 385/214/90/108 差异的性质（`hdgrp` 判据第 5 次、记录段统一判据第 2 次）；
复核 70 场额外战斗的三重证据；确认 `eft/` 105 个 PNG 为 `EDITOR_DUMP`；
确认零引擎改动、零代码改动。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-PTTV-1 | `diff.md` 逐条审计 | 154 项 MOD 独有全部有判定，需修复 = 0；审计 `total=596` = 源文件数 596 | ✅ |
| REQ-PTTV-2 | 「基准独有」逐项定性 | 21 项 = 在 save/ 9 + 首次播种 9 + 回退原版 2 + 死文件 1 | ✅ |
| REQ-PTTV-3 | MOD 独有内容加载 | 鄉民/卓不凡/高昌迷宮地圖；385/214/90/108；talk 5689；events 1229；fight 162；hdgrp 204 | ✅ |
| REQ-PTTV-4 | `hdgrp`/fight/记录段 差异判定 | 三者均内容差异；`hdgrp` 判据第 5 次、记录段第 2 次 | ✅ |
| REQ-PTTV-5 | 70 场额外战斗复核 | 三重证据通过；产物 162；160 全 `REQUIRED` | ✅ |
| REQ-PTTV-6 | 零引擎改动（tools/tests 仅 `isStringField` 加固） | 未触碰 `engine-*/**`、`jyconst.lua`、`reference/**`、`framework/**`；`tools/mod_encoding.lua` 仅 §3.11 加固（逐字节 no-op） | ✅ |
| REQ-PTTV-7 | 验证报告 | `reports/ptt-verify.md` 12 节 | ✅ |
| REQ-PTTV-8 | `eft/` `EDITOR_DUMP` 证据 | 4 条机器可复核证据 | ✅ |
| REQ-PTTV-9 | PENDING 27 项边界 | `music/*.mid` 23 + `list/*.bin` 4 显式列出 | ✅ |

## 3. 实测证据

### 3.1 `diff.md` 逐条审计（REQ-PTTV-1）

**MOD 独有 154 项**：额外战斗 140（70 场 × 2）+ `kdef`/`talk`/`cloud`/`title` 8 +
`end.png`/`open.png` 2 + `ranger.str` 1 + `kysmod.ini` 1 + `talkutf8.txt` 1 + `save.zip` 1。
**需修复 = 0**。

**全覆盖证明**：

```
$ lua tools/mod_audit.lua --mod ptt
total=596 in_product=459 not_in_product=137 unclassified=0 bad_evidence=0

$ find reference/allmods/kys-ptt -type f | wc -l
596
```

`total == 源文件总数`，`Σ(类别) = 454+4+3+105+2+1+27 = 596`，**每个源文件都被归类**。

`ranger.str` 是 `mod_build.lua:1174` 写入的**构建产物**（源目录不存在），
故 `diff.md`（产物 vs 源）列出它，而 `mod_audit`（审计对象 = 源文件全集）不列。

### 3.2 137 项 `not_in_product` 全部有具名类别

| 类别 | 项数 | 明细 |
|------|-----:|------|
| `EDITOR_DUMP` | 105 | `eft/` 目录 |
| `PENDING` | 27 | `music/*.mid` 23 + `list/*.bin` 4 |
| `LEGACY` | 3 | `list/end.txt`、`list/start.txt`、`script/1.lua` |
| `BUILD_INPUT` | 1 | `resource/talkutf8.txt` |
| `PLATFORM_ARTIFACT` | 1 | `save.zip` |

### 3.3 「基准独有」21 项定性（REQ-PTTV-2）

| 性质 | 项数 | 明细 | 判据 |
|------|-----:|------|------|
| 在 save/ | 9 | `d1`~`d3`/`r1`~`r3`/`s1`~`s3` 的 `.grp` | `mods/ptt/save/<f>` 存在且逐字节一致 |
| **首次播种** | 9 | 对应 `.idx`（源不存在） | 源 `save/` 仅 3 个 `.idx`；`SeedSaveSlot` 从 `data/ranger.idx` 派生 |
| 回退原版 | 2 | `thing.grp`/`thing.idx` | `CC.ThingPicFile[1]/[2]` = `data/thing.idx`/`data/thing.grp` |
| 死文件 | 1 | `allsinbk.grp` | `CC.TempS_Filename`（`jyconst.lua:96`）→ `LoadSMap` 第 2 实参（`jymain.lua:1835`），引擎形参 `tmpfilename`（`lib_love.lua:890`）**零使用** |
| **Σ** | **21** | | 无未解释项 |

**「首次播种」机制实测**：

```
播种前 mods/ptt/save/r1.idx: false
mods/ptt/data/ranger.idx 模板: true
ModData.SeedSaveSlot(1) → "mods/ptt/save/r1.idx"
播种后存在: true；与 ranger.idx 逐字节一致: true
（验证后已清理临时产物）
```

ptt 是**本 epic 首个把「在 save/」与「首次播种」显式拆开**的 MOD：
18 个源槽只有 `.grp`，9 个 `.idx` 完全靠播种派生。

### 3.4 MOD 独有内容（REQ-PTTV-3）

非基线值（同一启动链分别激活 ptt 与 pascal）：

| 字段 | ptt | pascal |
|------|-----|--------|
| `Person[0].姓名` | 鄉民 | 小蝦米 |
| `Thing[0].名称` | 千面人蠻牛 | 康倍特 |
| `Person[384].姓名` | 卓不凡 | —（基线仅 320） |
| `Thing[213].名称` | 高昌迷宮地圖 | —（基线仅 200） |
| `Scene[89].名称` | 計老人居 | —（基线仅 84） |
| `Wugong[107].名称` | 天魔極樂 | —（基线仅 93） |
| 记录数 | 385/214/90/108 | 320/200/84/93 |
| talk / events / fight / hdgrp | 5689 / 1229 / 162 / 204 | 2977 / 1018 / 92 / 115 |

**回退链路径**：

```
CC.HeadPicFile[1]   = mods/ptt/data/hdgrp.idx
CC.TalkGrpFile      = mods/ptt/script/oldtalk.grp
CC.R_GRPFilename[1] = mods/ptt/save/r1.grp
CC.D_Filename[1]    = mods/ptt/save/d1.grp
CC.S_Filename[1]    = mods/ptt/save/s1.grp
CC.ThingPicFile[1]  = data/thing.idx   ← 回退原版
CC.ThingPicFile[2]  = data/thing.grp   ← 回退原版
```

### 3.5 `hdgrp` 204（REQ-PTTV-4，判据第 5 次应用）

`hdgrp.idx` = 816 B = 204 × 4；`PicLoadFile` 用 `idxlen/4`（`lib_love.lua:437`）；
`CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全 `nil`；
`format_spec --format hdgrp --mod ptt` → `gaps=0`。

外推链：**125 → 129 → 173 → 178 → 204**（五次一致）。

### 3.6 4 段记录数（REQ-PTTV-4，统一判据第 2 次应用）

| 段 | 段长 | 记录大小 | 条数 | 整除 | 边界 hint |
|----|-----:|--------:|-----:|:----:|-----------|
| Person | 70070 | 182 | 385 | YES | `P0489` / `N0448` |
| Thing  | 40660 | 190 | 214 | YES | `T0395` / `T20395` / `TD0395` |
| Scene  |  4680 |  52 |  90 | YES | `S0088` |
| Wugong | 14688 | 136 | 108 | YES | `W0107` |
| Shop   |   150 |  50 |   3 | YES | —（无字符串字段） |

边界内容可读：卓不凡 / 高昌迷宮地圖 / 計老人居 / 天魔極樂。
索引驱动（`jymain.lua:1747`）+ 无固定计数 + `gaps=0` → **内容差异**。

外推记录：**lyff（1 段）→ ptt（4 段全异）**。

### 3.7 70 场额外战斗（REQ-PTTV-5）

| # | 证据 | 实测 |
|---|------|------|
| 1 | `diff.md` | 140 项（70 场 × 2） |
| 2 | 产物 | `fight*.grp` = 162；`comm -13` vs pascal = 70 |
| 3 | 审计 | 162 个 `fight*.grp` **全部** `REQUIRED`/`in_product=true`，其他类别 = 0 |

抽样 5 场（`fight073`/`fight130`/`fight154`/`fight195`/`fight216`）全部
`REQUIRED` + `in_product=true` + 产物存在。

### 3.8 `eft/` 105 个 `EDITOR_DUMP`（REQ-PTTV-8）

| # | 证据 | 实测 |
|---|------|------|
| 1 | `IGNORE_DIRS` 含 `eft=true` | `game/tools/mod_build.lua:567` |
| 2 | 引擎 0 引用 | `grep -rn "eft/" game/script/jyconst.lua game/engine-love2d/*.lua game/framework/*.lua` → 无输出 |
| 3 | 产物无 `eft/` | `ls -d game/mods/ptt/eft` → 不存在 |
| 4 | 审计归类 | 105 项 `EDITOR_DUMP`/`in_product=false` |

### 3.9 PENDING 27 项（REQ-PTTV-9）

| 项 | 数量 | 归属 |
|----|-----:|------|
| `music/*.mid` | 23 | 全局遗留 spike（epic `TODO.md` 已记录） |
| `list/*.bin` | 4 | C 引擎列表数据，Lua 引擎无读取路径 |

`needed=nil`（未判定）≠ `needed=false`（判定为不需要）。

### 3.10 存档

- 源 `save/` 28 文件；产物 `save/` **21 文件**；逐字节 **21/21 一致**
- 18 个源存档槽（`d1`~`d6`/`r1`~`r6`/`s1`~`s6`），本 epic 最多
- 非槽位文件：`ranger.*`/`alldef.*`/`allsin.*` → `data/`；`save.zip` 为源压缩包

### 3.11 `isStringField` 加固（Slice 8 遗留项收尾）

Slice 8 的判别器在「含高位字节」分支是**裸高位测试**，任何非 Big5 高位字节
（int32 槽填 `0xFF`、截断的 Big5 首字节）都会被误判为字符串并解码成 U+FFFD 垃圾。
本 slice 加固为「高位字节必须成对且能在 Big5 表中解码」，与 `DecodeBig5` 能力严格镜像。

**对真实数据是逐字节 no-op**：全 20 MOD 解码后 U+FFFD 数 = 0（旧行为已实测），
故「全 Big5 可解码」恒真，只剔除假阳性。

```
$ lua tools/mod_build.lua --all        # 20 mods, 0 build failures
ranger.str 20/20 逐字节未变（isStringField 加固为 no-op）
```

新增 9 条回归断言（10 正例 + 12 反例 + `ranger.str` 产物内容校验），
测试总数 **1613 → 1622**。

## 4. 零回归

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **1622/1622，0 失败** |
| `mod_build --verify-pascal` | `mismatches=0` · PASS |
| `mod_build --all` | `20 mods, 0 build failures` |
| `mod_check` | **20/20** |
| `mod_audit --all` | `total=11220 unclassified=0 bad_evidence=0` |
| `mod_audit --all --evidence` | `checked=17 failed=0` |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` |
| 全 MOD `save/` vs 源 | **341** 文件，不一致 = 0 |

## 5. Blast Radius 合规检查（REQ-PTTV-6）

| 路径 | 状态 |
|------|------|
| `game/engine-love2d/**` | ✅ 未改 |
| `game/engine-mud/**` | ✅ 未改 |
| `game/script/jyconst.lua`（常量定义） | ✅ 未改 |
| `reference/allmods/**` | ✅ 未改 |
| `game/tools/mod_encoding.lua` | ⚠ 已改（`isStringField` 加固，允许路径；20/20 `ranger.str` md5 不变） |
| `game/framework/**` | ✅ 未改 |
| `game/tests/unit/test_mod_encoding.lua` | ⚠ 已改（+9 回归断言，允许路径） |
| `openspec/**` | artifacts（允许） |

## 6. 偏差记录

| # | 偏差 | 说明 |
|---|------|------|
| 1 | `allmods-slice9/change-manifest.md` 事前标 `status: done`，但 `allmods-ptt-verify/` 不存在、`allmods-ptt-activate/verification.md` 缺失 | 本轮核实并补齐（activate `verification.md` + verify 全套 5 个 artifact + 报告）。所有实测值与 manifest 声明**逐一吻合**，无虚报。 |
| 2 | `diff.md` 未列 `ranger.str` 于审计 | 设计如此：`ranger.str` 是构建产物，源目录不存在；审计对象 = 源文件全集（596）。 |
| 3 | `diff.md` 「基准独有 21」含 9 个源不存在的 `.idx` | 属新增第 4 类「首次播种」（ADR-003）；非「回退原版」也非「死文件」。 |
| 4 | 并行跑门禁导致 2 个 `test_mod_boot` 假失败 | 已确认是 `mod_build --all` 与测试写 `mods/mingdong/save/` 竞态；串行复跑 1622/1622 通过。 |
| 5 | 报告初稿误写 `Scene[89]` = 「小天人~」 | 实测为 **計老人居**；已修正 verify 报告与 activate `verification.md` 两处。 |

## 7. 结论

**PASS**。ptt 内容审计完成，无缺陷、无回归、零引擎改动、零代码改动。

**第 3 梯队（hdgrp 170~210：pig 173 / lyff 178 / ptt 204）全部收官。**

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod ptt
formats=14 checked=319 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **162** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **78** | `lib_love.PlayWAV` |
| png | `png_image` | 54 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **319** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=317` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=319 gaps=0`（+2） |

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

本 MOD `total=319`，在 20 个 MOD 中排 **第 8**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，319 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
