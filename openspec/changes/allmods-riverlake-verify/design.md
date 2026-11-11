# Design: allmods-riverlake-verify

## Negative Constraints

- **不得**用「均回退原版」「不需要」等笼统表述；每一项必须有机器可复核证据。
- **不得**把「首次播种」归为「回退原版」或「死文件」。
- **不得**把 `hdgrp`/`eft` 条目数差异判为结构异常（ADR-001 索引驱动判据）。
- **不得**把 44 个 0 字节 `fight*.grp` 判为构建缺陷（ADR-007：源既有、逐字节一致）。
- **不得**修改 `game/engine-love2d/**`、`game/engine-mud/**`、
  `game/script/jyconst.lua` 常量定义、`reference/allmods/**`。
- **不得**把「记录数相同」当作 MOD 内容已加载的证据（Scene 阴性对照）。

---

## ADR-001：「基准独有」四项定性判据（本 epic 第 3 次应用，首次含「死文件」）

### Context

`diff.md` 列出「基准独有 21」—— 即 `game/data/`（或基线 `save/`）有、RiverLake 产物没有的
21 个文件。必须证明它们**不是被构建丢失**的必需品。

### Decision

四类，每类判据必须机器可复核：

| 类别 | 判据（全部必须满足） | RiverLake 命中 |
|------|---------------------|----------------|
| **A. 在 save/（源自带存档）** | ① 源 `save/` 存在同名文件 ② 产物 `save/` 存在 ③ 逐字节一致 | **9**（`d1`~`d3`/`r1`~`r3`/`s1`~`s3` 的 `.grp`） |
| **B. 首次播种** | ① 源不存在 ② 产物不存在 ③ `SeedSaveSlot` 从 MOD `ranger.idx` 派生（已实测） | **9**（对应 9 个 `.idx`） |
| **C. 回退原版** | ① 源不存在 ② 产物不存在 ③ 运行时 `CC.*` 解析到 `data/<file>`（回退链） | **2**（`thing.grp`/`thing.idx`） |
| **D. 死文件** | ① 源不存在 ② 产物不存在 ③ 常量存在但**引擎从不读取**（代码级证据） | **1**（`allsinbk.grp`） |

合计 **9 + 9 + 2 + 1 = 21** ✅

### 关键区分：B vs C

两者都「源不存在 + 产物不存在」，差别在**运行时行为**：

- **B（播种）**：`CC.R_IDXFilename[1] = mods/RiverLake/save/r1.idx`（MOD 存档目录），
  首次 `SaveRecord` 时由 `ModData.SeedSaveSlot` 从 **MOD 自己的** `ranger.idx` 播种。
  即：**运行时会产生**这个文件。
- **C（回退）**：`CC.ThingPicFile[1] = data/thing.idx`（**基线** `data/` 目录，非 MOD 目录），
  运行时读基线文件。即：**运行时读别人**。

区分方法 = 打印 `CC.*` 常量的**实际解析值**。

### Evidence（实测）

```
--- A. 9 个 .grp 逐字节 ---
d1.grp  源=369600   产物=369600   一致=True
d2.grp  源=369600   产物=369600   一致=True
d3.grp  源=440000   产物=440000   一致=True
r1.grp  源=125894   产物=125894   一致=True
r2.grp  源=124870   产物=124870   一致=True
r3.grp  源=114242   产物=114242   一致=True
s1.grp  源=4128768  产物=4128768  一致=True
s2.grp  源=4128768  产物=4128768  一致=True
s3.grp  源=4915200  产物=4915200  一致=True
```

```
--- B. 9 个 .idx 源不存在 ---
d1.idx 源存在=False 产物存在=False   (d2/d3/r1/r2/r3/s1/s2/s3 同)
运行时: CC.R_IDXFilename[1] = mods/RiverLake/save/r1.idx
播种实测: SeedSaveSlot(1) -> save/r1.idx == mods/RiverLake/data/ranger.idx (True)
                                    == data/ranger.idx                 (False)
```

```
--- C. 2 项 thing.* ---
源 resource/ 无 thing.*；基线 data/thing.{grp,idx} 存在；产物 mods/RiverLake/data/thing.* 不存在
运行时: CC.ThingPicFile[1] = data/thing.idx
        CC.ThingPicFile[2] = data/thing.grp
        CC.LoadThingPic     = 1
⇒ 运行时读基线 data/thing.*（回退链），非 MOD
```

```
--- D. 1 项 allsinbk.grp ---
源 save/ 无；基线 data/allsinbk.grp 存在(4128768B)；产物无
运行时: CC.TempS_Filename = "data/allsinbk.grp"（RewritedConstants 回退到基线）
        jymain.lua:1835  lib.LoadSMap(sFile, CC.TempS_Filename, ...)
        lib_love.lua:890 function LoadSMap(Sfilename, tmpfilename, num, x_max, y_max, Dfilename, ...)
          ↑ tmpfilename 形参在函数体内【完全未被使用】
⇒ 该文件被传入，但引擎从不读取其内容 ⇒ 死文件
```

**D 的代码级证据**（`grep -n tmpfilename engine-love2d/lib_love.lua` 只有 1 处命中，
即函数签名本身）：形参未使用是「死文件」的充分证据。

### Alternatives

- **把 `allsinbk.grp` 归「回退原版」**：它确实从基线解析到路径，但**引擎不读**，
  叫「回退」会误导（暗示有内容被用上）。**否决**，单列「死文件」。
- **把 9 个 `.idx` 归「回退原版」**：运行时这些路径指向 **MOD 存档目录**，
  不是基线目录；且首次保存会产生文件。**否决**，单列「首次播种」。
- **把 `thing.*` 归「首次播种」**：`thing.*` 不是存档槽，无播种机制，
  路径指向基线 `data/`。**否决**。

### Consequences

- ✅ 21 项全部有唯一归属，Σ = 21。
- ✅ 「B vs C vs D」的区分有明确可执行判据（打印 `CC.*` 解析值 + 检查代码路径），
  后续 slice 可复用。
- ⚠ `allsinbk.grp` 是 epic 首个「死文件」样本（前 9 个 slice 的「基准独有」
  只有 A/B/C 三类）。已在 `mod_audit` 归类上属 `REQUIRED`（因为路径被引用），
  但**运行时无效果** —— 这个「路径被引用 ≠ 内容被使用」的细微差别在本 ADR 首次记录。

---

## ADR-002：缺陷 F —— `test_mod_resources` 在脏产物状态下报假失败

### Context

本轮首跑全量测试时出现 4 条失败：

```
[FAIL] mingdong d1.grp 内容一致: expected true, got false
[FAIL] mingdong r1.grp 大小一致: expected 223688, got 222888
[FAIL] mingdong r1.grp 内容一致: expected true, got false
[FAIL] mingdong s1.grp 内容一致: expected true, got false
```

### Root Cause

`test_mod_boot.testSaveLoadRoundTripWithMingdong` 在 `mods/mingdong/save/` 写
`r1.grp`/`d1.grp`/`s1.grp`/`r1.idx`/`r1.ovr`，只在**正常结束**时调 `restoreSlots()` 恢复。
若该测试被中断（前台超时 `kill`、断言抛错提前 `return`），脏槽残留。

而 runner 顺序中 `mod_resources`（index 16）**先于** `mod_boot`（index 21），
故下一次运行时 `testProductSaveSlotMatchesSource` 会读到上一轮残留的脏槽 → 4 条假失败。

**确定性复现**：

```
$ printf 'DIRTY' >> game/mods/mingdong/save/r1.grp
$ lua tests/test_runner.lua mod_resources
[FAIL] mingdong r1.grp 大小一致: expected 222893, got 222888
[FAIL] mingdong r1.grp 内容一致: expected true, got false
Results: 739 tests, 737 passed, 2 failed
```

### Decision

在 `test_mod_resources` 里新增 `TestModResources.restoreAllProductSaves()`，
在比对前对 20 个 MOD 的产物 `save/` 做**自愈式重建**：

1. 删除产物 `save/` 中源包不存在的文件（测试残留 `.idx`/`.ovr`）。
2. 把源包 `save/` 中的每个文件逐字节拷回产物。

测试从此**幂等**：可从任意初始状态（干净/脏/半恢复）自愈，
不依赖执行顺序，也不依赖上一轮是否正常结束。

### Alternatives

- **调整 runner 顺序，让 `mod_boot` 先跑**：只掩盖问题——若 `mod_boot` 被中断，
  下一次运行仍会脏；且 `mod_resources` 单独运行（`test_runner.lua mod_resources`）仍会失败。
  **否决**（不解决根因）。
- **在 `test_mod_boot` 里改成「先备份再恢复备份」**：历史已踩过这个坑
  （Slice 5 注释明确写了：备份的就是脏状态，会连环污染）。**否决**。
- **在 `test_mod_boot` 里加 `pcall` + 保证 `restoreSlots` 一定执行**：能修「断言抛错」路径，
  但**修不了「进程被 kill」**路径。**否决**（不完整）。
- **自愈式重建（选用）**：无论前面发生什么，比对前都按源包重建 ⇒ 根因解决。

### Consequences

- ✅ 从脏态起跑 `mod_resources` → `959 tests, 959 passed, 0 failed`。
- ✅ 全量 → `1842 tests, 1842 passed, 0 failed`。
- ⚠ **测试总数 1622 → 1842 (+220)**：增量**不是**新增断言，而是自愈重建让此前
  被「源/产物文件缺失」跳过的比对断言真正执行了（`fp`/`fs` 任一为 `nil` 时
  代码走 `else` 分支不计数）。属**覆盖扩充**，非行为变更。
- ⚠ 该缺陷是**第 6 个**工具缺陷（前 5 个见 epic `epic.md`）。

---

## ADR-003：范围外发现 —— 只记录、不修复、必须完整

### Context

本 slice 发现两项**既有**缺陷（非本 slice 引入）：

1. `CC.Effect` 硬编码 53 项 vs **7/20 MOD** 的 eft id 越界（activate ADR-003）
2. **44 个 0 字节** `fight*.grp`（activate ADR-007），另 pineapple 有 115 个

### Decision

两项均**只记录、不修复**，且记录必须包含 6 要素：

| 要素 | `CC.Effect` | 0 字节 fight |
|------|-------------|--------------|
| ① 现象 | eft id 越 `CC.Effect` 上界 52 | 文件存在但 0 字节 |
| ② 受影响范围 | **7/20 MOD** + 每 MOD 条数 | **5/20 MOD** + 每 MOD 个数 |
| ③ 权威来源/根因 | `list/effect.bin` + `UPedit.ini:80` | 源包本身 0 字节，逐字节一致 |
| ④ 严重性 | 非致命（`or 10`/`or 0` 回退，仅动画帧错位） | 非致命（`PicFile:getPic` 返回 `nil`，调用方 `or` 兜底） |
| ⑤ 不修复理由 | `jyconst.lua` 禁改；修复需改 20 MOD 审计分类+构建管线，属独立 change | 补数据=伪造；删除=破坏 `fight%03d` 索引语义 |
| ⑥ 修复路径 | `mod_data.RewriteConstants` 按 `effect.bin` 重建 `CC.Effect` | 无需修复（源如此），或由 MOD 作者补数据 |

### Negative Constraint

**不得**因为「不在本 change 范围」就简化记录。缺任一要素即视为记录不合格。

### Consequences

- ✅ 两项均写入 activate `verification.md`、本 change `verification.md`、
  `reports/riverlake-verify.md`、以及 epic `TODO.md`。
- ✅ 为后续 `pineapple`（115 个空 fight）建立了记录模板。

---

## ADR-004：报告结构 —— 「逐项表 + 重算对账」而非「结论段」

### Context

前几个 slice 的 `reports/<slug>-verify.md` 质量不一：有的只写结论（「21 项均已定性」），
无法复核。

### Decision

`reports/riverlake-verify.md` 必须包含**可重算的对账表**：

1. **重算对账**：`diff.md` 声称的数字 vs 本轮实际重算的数字，两列并列。
2. **21 项逐项表**：文件名 | 源存在 | 产物存在 | 基线 data 存在 | 类别 | 证据
3. **268 项归类表**：按类别聚合（254 fight + 14 非 fight），非 fight 逐项列出。
4. **33 项未进产物表**：PENDING 27 / LEGACY 5 / BUILD_INPUT 1，**逐项列文件名**。
5. **范围外发现**：2 项 × 6 要素。
6. **门禁结果**：8 道门禁的命令 + 输出原文。

### Consequences

- ✅ 任何读者可只凭报告重算全部数字。
- ✅ 「逐项列出文件名」使报告长度增加，但可复核性优先。
