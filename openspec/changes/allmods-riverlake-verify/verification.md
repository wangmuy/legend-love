# Verification: allmods-riverlake-verify

> 生成时机：实施后（schema `requires: [tasks]`）。
> 全部证据本轮重跑取得。

## 1. REQ 覆盖总览

| REQ | 内容 | 状态 | 关键证据 |
|-----|------|------|----------|
| REQ-RIVV-1 | `diff.md` 重算对账 | ✅ | 268 = 254 fight + 14 非 fight；21；252/219 全一致 |
| REQ-RIVV-2 | 21 项四类定性 | ✅ | 9 + 9 + 2 + 1 = 21，逐项机器证据 |
| REQ-RIVV-3 | 268 项全量归类 | ✅ | `unclassified=0 bad_evidence=0` |
| REQ-RIVV-4 | 33 项显式证据 | ✅ | 27 + 5 + 1 = 33，逐项文件名 |
| REQ-RIVV-5 | 范围外发现 6 要素 | ✅ | `CC.Effect` 7/20 + 空 fight 5/20 |
| REQ-RIVV-6 | 零引擎改动 + 零回归 | ✅ | 8 道门禁 + 4 类禁改路径 |
| REQ-RIVV-7 | 报告产出 | ✅ | `reports/riverlake-verify.md` 6 章节 |

---

## 2. REQ-RIVV-1 `diff.md` 重算对账

```
$ python3  # 解析 mods/RiverLake/diff.md
MOD 独有 268 = fight 254 + 非 fight 14
非 fight: cloud.grp cloud.idx kdef.grp kdef.idx kysmod.ini name.grp name.idx
          open.png ranger.str talk.grp talk.idx talkutf8.txt title.grp title.idx
按扩展名: {'grp': 132, 'idx': 132, 'ini': 1, 'png': 1, 'str': 1, 'txt': 1}   Σ=268
基准独有: 21
hdgrp: MOD 252 / 基准 115
fight: MOD 219
```

| 项 | 声称 | 重算 | 一致 |
|----|-----:|-----:|:----:|
| MOD 独有 | 268 | 268 | ✅ |
| — fight `.grp` | — | 127 | — |
| — fight `.idx` | — | 127 | — |
| — 非 fight | — | 14 | — |
| 基准独有 | 21 | 21 | ✅ |
| `hdgrp` | 252 | 252（1008B/4） | ✅ |
| `fight` | 219 | 219 | ✅ |

✅ 无漏报、无虚报。

---

## 3. REQ-RIVV-2 「基准独有」21 项四类定性

### 3.1 A 类：在 save/（源自带存档）= 9

```
--- A. 9 个 .grp：源自带存档，逐字节一致 ---
  d1.grp     源=  369600 产物=  369600 逐字节一致=True
  d2.grp     源=  369600 产物=  369600 逐字节一致=True
  d3.grp     源=  440000 产物=  440000 逐字节一致=True
  r1.grp     源=  125894 产物=  125894 逐字节一致=True
  r2.grp     源=  124870 产物=  124870 逐字节一致=True
  r3.grp     源=  114242 产物=  114242 逐字节一致=True
  s1.grp     源= 4128768 产物= 4128768 逐字节一致=True
  s2.grp     源= 4128768 产物= 4128768 逐字节一致=True
  s3.grp     源= 4915200 产物= 4915200 逐字节一致=True
```

### 3.2 B 类：首次播种 = 9

```
--- B. 9 个 .idx：源不存在 → 首次播种 ---
  d1.idx     源存在=False 产物存在=False
  d2.idx     源存在=False 产物存在=False
  ...（共 9 个全部 False/False）
```

运行时证据：

```
CC.R_IDXFilename[1] = mods/RiverLake/save/r1.idx
CC.R_GRPFilename[1] = mods/RiverLake/save/r1.grp
CC.S_Filename[1]    = mods/RiverLake/save/s1.grp
CC.D_Filename[1]    = mods/RiverLake/save/d1.grp
```

⇒ 指向 **MOD 存档目录**（非基线 `data/`）。

播种机制实测（activate §10 已做，本轮不重复写产物）：

```
ModData.SeedSaveSlot(1)
→ mods/RiverLake/save/r1.idx 存在
→ == mods/RiverLake/data/ranger.idx  (true)   ← MOD 模板
→ == data/ranger.idx                 (false)  ← 非基线模板
```

### 3.3 C 类：回退原版 = 2

```
--- C. 2 项 thing.*：源不存在、MOD 不提供 ---
  thing.grp  源resource=False base_data存在=True 产物存在=False
  thing.idx  源resource=False base_data存在=True 产物存在=False
```

```
CC.ThingPicFile[1] = data/thing.idx          ← 基线目录
CC.ThingPicFile[2] = data/thing.grp
CC.LoadThingPic    = 1
```

⇒ 运行时读**基线** `data/thing.*`。此外 `reference/allmods/kys-RiverLake/resource/`
目录实测无 `thing.*`（37 项中不含）。

### 3.4 D 类：死文件 = 1

```
--- D. 1 项 allsinbk.grp ---
  allsinbk.grp 源存在=False base_data存在=True 产物存在=False
```

代码级证据：

```
$ grep -n "tmpfilename" game/engine-love2d/lib_love.lua
890:function LoadSMap(Sfilename, tmpfilename, num, x_max, y_max, Dfilename, d_num1, d_num2)
```

**仅 1 处命中 = 函数签名本身**，函数体内零引用 ⇒ 文件被传入但永不读取。

传入点：`jymain.lua:1835`
```lua
lib.LoadSMap(sFile, CC.TempS_Filename, JY.SceneNum, CC.SWidth, CC.SHeight, dFile, CC.DNum, 11);
```
`CC.TempS_Filename = "data/allsinbk.grp"`（`jyconst.lua:96`），经 `RewriteConstants`
回退到基线（产物无该文件）✅

### 3.5 合计

| 类别 | 项数 |
|------|-----:|
| A 在 save/（源自带存档） | 9 |
| B 首次播种 | 9 |
| C 回退原版 | 2 |
| D 死文件 | 1 |
| **Σ** | **21** ✅ |

✅ 负约束遵守：无「不确定」「待查」；B 未误归 C/D。

---

## 4. REQ-RIVV-3 268 项全量归类

```
$ lua tools/mod_audit.lua --mod RiverLake
total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0
  REQUIRED             661
  REQUIRED_CONVERTED   4
  LEGACY               5
  BUILD_INPUT          2
  PENDING              27
```

Σ = 661 + 4 + 5 + 2 + 27 = **699** = `total` ✅

268 项归类：

| 类别 | 项数 | 审计类别 |
|------|-----:|----------|
| `fight*.grp`/`.idx` | 254 | `REQUIRED` / `in_product=true` |
| `cloud.*` | 2 | `REQUIRED` |
| `kdef.*` | 2 | `REQUIRED` |
| `title.*` | 2 | `REQUIRED` |
| `talk.*` | 2 | `REQUIRED` |
| `name.*` | 2 | `LEGACY` |
| `kysmod.ini` | 1 | `BUILD_INPUT` → 产物 |
| `talkutf8.txt` | 1 | `BUILD_INPUT` |
| `ranger.str` | 1 | 构建产物（`mod_build.lua:1174`） |
| `open.png` | 1 | `REQUIRED` |
| **Σ** | **268** ✅ | `unclassified=0` |

fight 三重确认（activate §9 详证）：`diff.md` 127 / 产物差集 127 / 审计全 REQUIRED ✅

---

## 5. REQ-RIVV-4 `not_in_product` 33 项

实测（`tools/mod_audit.lua` `auditAll` 遍历 `not in_product`）：

```
--- PENDING (27) ---
   list/effect.bin
   list/leave.bin
   list/levelup.bin
   list/match.bin
   music/1.mid  ...  music/23.mid      （共 23 个 .mid）
--- LEGACY (5) ---
   list/end.txt
   list/start.txt
   resource/name.grp
   resource/name.idx
   script/1.lua
--- BUILD_INPUT (1) ---
   resource/talkutf8.txt
```

Σ = 27 + 5 + 1 = **33** ✅ = `not_in_product`

**显式矛盾标注**：`list/effect.bin` 属 PENDING（不进产物），
但它是 `CC.Effect` 截断缺陷的修复所需数据。本 change **不**提升为 `REQUIRED`，
理由见 activate ADR-003（属独立 change，需改 20 MOD 审计分类+构建管线）。
已在 `reports/riverlake-verify.md` §4.1 与 `spec.md` REQ-RIVV-4 显式标注 ✅

---

## 6. REQ-RIVV-5 范围外发现 6 要素

### 6.1 `CC.Effect` 硬编码 53 项

| 要素 | 内容 |
|------|------|
| ① 现象 | `jyconst.lua:439` `CC.Effect` 53 项字面量表（sum=712，`[0]=9`），eft id 越上界 52 |
| ② 范围 | **7/20 MOD**：RiverLake 10 / books 2 / awaken 1 / pineapple 62 / pig3dos 52 / mingdong 136 / BookCalamity 296 |
| ③ 根因 | `list/effect.bin`（int16 帧数表）+ `UPedit.ini:80`；`sum(effect.bin)==eft.idx` 3 MOD 精确相等 |
| ④ 严重性 | 非致命：`or 10` / `or 0` 回退；`eft=69 → framenum=15, starteft=40`，无报错 |
| ⑤ 不修复理由 | `jyconst.lua` 禁改 + 需改 20 MOD 审计分类/构建管线，属独立 change |
| ⑥ 修复路径 | `mod_data.RewriteConstants` 按 `effect.bin` 重建 `CC.Effect`；已入 epic TODO |

### 6.2 0 字节 `fight*.grp`

| 要素 | 内容 |
|------|------|
| ① 现象 | 文件存在但 0 字节 |
| ② 范围 | **5/20 MOD**：pineapple 115/154、RiverLake 44/219、ptt 7/162、books 2/178、loving 2/107 |
| ③ 根因 | 源包本身 0 字节；RiverLake 差集 127 项尺寸**127/127 一致**；34/44 被 `Person["头像代号"]` 引用 |
| ④ 严重性 | 非致命：`getPic` 返回 `nil`；`PicGetXY` 返回 0；pcall=true |
| ⑤ 不修复理由 | 补内容=伪造；删除=破坏 `fight%03d` 位置索引语义 |
| ⑥ 修复路径 | 无需修复（源如此）；MOD 作者补数据后重建即生效 |

两项均写入：activate `verification.md` §9.1/§8.2、本文件 §6、`reports/riverlake-verify.md` §6、
epic `TODO.md` ✅

---

## 7. REQ-RIVV-6 零引擎改动 + 零回归

| # | 门禁 | 结果 |
|---|------|------|
| 1 | `cd game && lua tests/test_runner.lua` | `Results: 1842 tests, 1842 passed, 0 failed` / `✓ 所有测试通过!` ✅ |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `events=1018, mismatches=0, known-deviations=3` PASS ✅ |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures, 5 annotated-problematic` ✅ |
| 4 | `lua tools/mod_check.lua` | `总计: 20 MOD, 通过 20, 失败 0` ✅ |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`；`evidence: checked=17 failed=0` ✅ |
| 6 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` ✅ |
| 7 | 20 MOD `save/` vs 源 | `比对 451 文件, 不一致/残留 = 0` ✅ |
| 8 | 脏态幂等 | 见 §8 ✅ |

> 门禁 3 退出码 1 属既有设计（`tools/mod_build.lua:1224-1226` 对 `#problems>0` → `os.exit(1)`），
> `build failures = 0`。

### 7.1 禁改路径零改动（`git status` 实测）

| 路径 | 状态 |
|------|------|
| `game/engine-love2d/` | 无变更 ✅ |
| `game/engine-mud/` | 无变更 ✅ |
| `game/script/jyconst.lua` | 本轮零改动（历史已在 Slice 1 接入，非本 change） ✅ |
| `reference/allmods/` | 无变更 ✅ |

---

## 8. REQ-RIVV-6 门禁 8：脏态幂等（缺陷 F 修复验证）

**确定性复现**（修复前，历史记录）：

```
$ printf 'DIRTY' >> game/mods/mingdong/save/r1.grp
$ lua tests/test_runner.lua mod_resources
[FAIL] mingdong r1.grp 大小一致: expected 222893, got 222888
[FAIL] mingdong r1.grp 内容一致: expected true, got false
Results: 739 tests, 737 passed, 2 failed
```

**修复后**（同一脏态）：

```
[INFO] 自愈重建产物 save 槽：恢复 451 个文件，删除 0 个残留
Results: 959 tests, 959 passed, 0 failed
```

全量：`1842 tests, 1842 passed, 0 failed` ✅

### 8.1 缺陷 F 记录（第 6 个工具缺陷）

| 项 | 内容 |
|----|------|
| 现象 | `mod_resources` 在脏产物状态报 4 条 mingdong 假失败 |
| 根因 | `test_mod_boot.testSaveLoadRoundTripWithMingdong` 写 `mods/mingdong/save/`，仅正常结束恢复；runner 顺序 `mod_resources`(16) 先于 `mod_boot`(21) |
| 修复 | `game/tests/unit/test_mod_resources.lua` 新增 `restoreAllProductSaves()`：比对前按源包**自愈式重建** 20 MOD 产物 `save/` |
| 幂等性 | 从干净/脏/半恢复状态起跑均 Green |
| 测试数 | 1622 → **1842**（+220）：恢复此前因文件缺失被 `else` 跳过的断言，属**覆盖扩充** |

### 8.2 测试数变化的解释（诚实记录）

`tasks.md`（activate）此前记 `1622`。本轮权威值为 **1842**。
差值 +220 = `mod_resources` 从 739 → 959（+220），
因 `restoreAllProductSaves()` 使源/产物文件齐备，`testProductSaveSlotMatchesSource`
的比对断言真正执行（原先 `fp`/`fs` 为 `nil` 走 `else` 不计数）。
**非新增测试、非行为变更**。

---

## 9. REQ-RIVV-7 报告产出

`reports/riverlake-verify.md` 章节核对：

| # | 章节 | 存在 |
|---|------|:----:|
| 1 | 重算对账（`diff.md` vs 实测两列） | ✅ §1 |
| 2 | 21 项基准独有逐项表（含源/产物/基线三列 + 类别 + 证据） | ✅ §2 |
| 3 | 268 项归类表（254 fight 聚合 + 14 非 fight 逐项） | ✅ §3 |
| 4 | 33 项未进产物表（27/5/1 逐项文件名） | ✅ §4 |
| 5 | 范围外发现 2 项 × 6 要素 | ✅ §6 |
| 6 | 门禁 8 道（命令 + 输出原文） | ✅ §7 |

✅ 读者可只凭报告重算全部数字（每个数字旁给出推导或命令）。

---

## 10. 结论

- Slice 10（`kys-RiverLake`）**verify 侧 7 项需求全部满足**。
- **零引擎改动**；唯一代码改动是 `game/tests/unit/test_mod_resources.lua`
  （缺陷 F 修复，允许路径）。
- 21 项「基准独有」四类定性首次引入**「死文件」类别**（`allsinbk.grp`），
  并给出 B/C/D 三分的可执行判据（打印 `CC.*` 解析值 + 检查代码路径）。
- 2 项范围外既有缺陷按 6 要素完整记录，均不修复并已入 epic TODO。
- Slice 10 完成 → 继续 Slice 11 = `kys-Dragon`（`hdgrp` 267 / `fight` 209）。

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod RiverLake
formats=14 checked=415 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **219** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **170** | `lib_love.PlayWAV` |
| png | `png_image` | 1 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **415** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=413` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=415 gaps=0`（+2） |

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

本 MOD `total=415`，在 20 个 MOD 中排 **第 5**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，415 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
