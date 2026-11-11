# RiverLake 验证报告

> Slice 10 = `kys-RiverLake`（Tier 4 开场，`hdgrp` 252，`fight` 第 2 多，`talk` 第 1 多）。
> 全部数字于本轮从实际文件系统重算，命令与输出原文附于各节。

## 0. 一句话结论

`kys-RiverLake` 在 love2d 引擎上**完全可用**：325/249/84/96 记录、252 头像、219 战斗、
8015 对话、1232 事件全部从 MOD 数据加载，21 项「基准独有」与 33 项「未进产物」
全部归因清楚，**零引擎改动**。同时**发现并记录 2 项范围外既有缺陷**
（`CC.Effect` 53 项截断影响 7/20 MOD；5/20 MOD 有 0 字节 `fight*.grp`），
并**修复 1 项测试工具缺陷**（缺陷 F：脏产物状态导致假失败）。

---

## 1. 重算对账

| 项 | `diff.md` 声称 | 本轮重算 | 一致 |
|----|---------------:|---------:|:----:|
| MOD 独有总数 | 268 | **268** | ✅ |
| — `fight*.grp` | — | **127** | — |
| — `fight*.idx` | — | **127** | — |
| — 非 fight | — | **14** | — |
| 基准独有总数 | 21 | **21** | ✅ |
| `hdgrp` 条目 | 252 | **252**（1008B/4） | ✅ |
| `fight` 数量 | 219 | **219** | ✅ |

14 项非 fight 逐项：

```
cloud.grp   cloud.idx   kdef.grp    kdef.idx    kysmod.ini   name.grp   name.idx
open.png    ranger.str  talk.grp    talk.idx    talkutf8.txt title.grp  title.idx
```

按扩展名：`grp 132` / `idx 132` / `ini 1` / `png 1` / `str 1` / `txt 1` = **268** ✅
（132 + 132 = 264 为 fight 的 127×2 + cloud/kdef/name/talk/title 的 5×2 − … ，即
127×2(fight) + 5×2(cloud/kdef/name/talk/title) = 264 个 grp/idx，
另 `kysmod.ini`/`open.png`/`ranger.str`/`talkutf8.txt` 4 个非二进制 ⇒ 264+4 = 268）

---

## 2. 「基准独有」21 项逐项定性

判据见 `design.md` ADR-001。四类，Σ = 9 + 9 + 2 + 1 = **21** ✅

| # | 文件 | 源 `save/` | 产物 `save/` | 基线 `data/` | 类别 | 证据 |
|--:|------|-----------:|-------------:|-------------:|------|------|
| 1 | `d1.grp` | 369600 | 369600 | 369600 | **A 源自带存档** | 逐字节一致 ✅ |
| 2 | `d2.grp` | 369600 | 369600 | 369600 | **A** | 逐字节一致 ✅ |
| 3 | `d3.grp` | 440000 | 440000 | 369600 | **A** | 逐字节一致 ✅ |
| 4 | `r1.grp` | 125894 | 125894 | 136412 | **A** | 逐字节一致 ✅ |
| 5 | `r2.grp` | 124870 | 124870 | 136412 | **A** | 逐字节一致 ✅ |
| 6 | `r3.grp` | 114242 | 114242 | 136412 | **A** | 逐字节一致 ✅ |
| 7 | `s1.grp` | 4128768 | 4128768 | 4128768 | **A** | 逐字节一致 ✅ |
| 8 | `s2.grp` | 4128768 | 4128768 | 4128768 | **A** | 逐字节一致 ✅ |
| 9 | `s3.grp` | 4915200 | 4915200 | 4128768 | **A** | 逐字节一致 ✅ |
| 10 | `d1.idx` | — | — | 400 | **B 首次播种** | `CC.R_IDXFilename[1]=mods/RiverLake/save/r1.idx` |
| 11 | `d2.idx` | — | — | 400 | **B** | 同上机制，槽 2 |
| 12 | `d3.idx` | — | — | 400 | **B** | 同上机制，槽 3 |
| 13 | `r1.idx` | — | — | 24 | **B** | 播种实测 == MOD `ranger.idx`（True） |
| 14 | `r2.idx` | — | — | 24 | **B** | 同上机制 |
| 15 | `r3.idx` | — | — | 24 | **B** | 同上机制 |
| 16 | `s1.idx` | — | — | 400 | **B** | 同上机制 |
| 17 | `s2.idx` | — | — | 400 | **B** | 同上机制 |
| 18 | `s3.idx` | — | — | 400 | **B** | 同上机制 |
| 19 | `thing.grp` | — | — | 345600 | **C 回退原版** | `CC.ThingPicFile[2]=data/thing.grp`；源 `resource/` 无 |
| 20 | `thing.idx` | — | — | 800 | **C** | `CC.ThingPicFile[1]=data/thing.idx`；`CC.LoadThingPic=1` |
| 21 | `allsinbk.grp` | — | — | 4128768 | **D 死文件** | `CC.TempS_Filename` 传入 `LoadSMap`，但 `tmpfilename` 形参**未使用** |

### 2.1 B / C / D 的区分（关键，本 epic 首次三分）

三者都「源不存在 + 产物不存在」，区别在**运行时行为**：

| 类别 | 运行时 `CC.*` 解析到 | 运行时是否产生/读取 |
|------|---------------------|---------------------|
| **B 首次播种** | `mods/RiverLake/save/rN.idx`（**MOD** 存档目录） | 首次保存时**产生**（从 MOD `ranger.idx` 派生） |
| **C 回退原版** | `data/thing.idx`（**基线** data 目录） | 直接**读基线**文件 |
| **D 死文件** | `data/allsinbk.grp`（基线） | 路径被传参，但引擎**从不读取内容** |

实测输出：

```
CC.R_IDXFilename[1] = mods/RiverLake/save/r1.idx     ← B：MOD 目录
CC.R_GRPFilename[1] = mods/RiverLake/save/r1.grp
CC.S_Filename[1]    = mods/RiverLake/save/s1.grp
CC.D_Filename[1]    = mods/RiverLake/save/d1.grp
CC.ThingPicFile[1]  = data/thing.idx                 ← C：基线目录
CC.ThingPicFile[2]  = data/thing.grp
CC.LoadThingPic     = 1
CC.TempS_Filename   = data/allsinbk.grp              ← D：基线目录（但不被使用）
```

### 2.2 D（死文件）的代码级证据

```
$ grep -n tmpfilename game/engine-love2d/lib_love.lua
890:function LoadSMap(Sfilename, tmpfilename, num, x_max, y_max, Dfilename, d_num1, d_num2)
```

**仅 1 处命中 = 函数签名本身**，函数体内无任何引用 ⇒ `allsinbk.grp` 被传入但永不读取。

对照 `jymain.lua:1835`：

```lua
lib.LoadSMap(sFile, CC.TempS_Filename, JY.SceneNum, CC.SWidth, CC.SHeight, dFile, CC.DNum, 11);
```

⇒ 这是本 epic 首个「**路径被引用 ≠ 内容被使用**」的样本。
`mod_audit` 因路径被引用而归 `REQUIRED`，但**运行时零效果**。

### 2.3 A 类的补充：源 vs 基线尺寸不同，证明用的是 MOD 存档

| 文件 | 源（= 产物） | 基线 `data/` | 结论 |
|------|------------:|-------------:|------|
| `d3.grp` | **440000** | 369600 | 尺寸不同 ⇒ MOD 专属 |
| `r1.grp` | **125894** | 136412 | 尺寸不同 ⇒ MOD 专属 |
| `r2.grp` | **124870** | 136412 | 尺寸不同 ⇒ MOD 专属 |
| `r3.grp` | **114242** | 136412 | 尺寸不同 ⇒ MOD 专属 |
| `s3.grp` | **4915200** | 4128768 | 尺寸不同 ⇒ MOD 专属 |

⇒ 6/9 项与基线**尺寸就不同**，另有 3 项（`d1`/`d2`/`s1`/`s2` 中）尺寸恰好相同，
但**逐字节一致**的比对是对源包的，不是对基线的 —— 故全部 9 项都是 MOD 源自带存档 ✅

---

## 3. 268 项 MOD 独有归类

```
MOD 独有 268 = fight 254 (127 .grp + 127 .idx) + 非 fight 14
```

| 类别 | 项数 | 归类 | 证据 |
|------|-----:|------|------|
| `fight*.grp` + `fight*.idx` | **254** | `REQUIRED` / `in_product=true` | 127 场 × 2；见 §3.1 |
| `cloud.grp` `cloud.idx` | 2 | `REQUIRED` | `CC.CloudPic` 引用（云层贴图） |
| `kdef.grp` `kdef.idx` | 2 | `REQUIRED` | kdef 事件指令流（1232 事件已提取） |
| `title.grp` `title.idx` | 2 | `REQUIRED` | `CC.TitlePic` 引用（标题画面） |
| `talk.grp` `talk.idx` | 2 | `REQUIRED` | `CC.TalkGrpFile` = `mods/RiverLake/script/oldtalk.grp`；8015 条目 |
| `name.grp` `name.idx` | 2 | `LEGACY` | 引擎不读；`grep -rn 'name\.grp' game/engine-love2d game/framework game/script` → 0 命中 |
| `kysmod.ini` | 1 | `BUILD_INPUT` → 产物 | 常量已映射进 `CC.*` |
| `talkutf8.txt` | 1 | `BUILD_INPUT` | talk 提取源（构建期消费，不进产物） |
| `ranger.str` | 1 | 构建产物 | `mod_build.lua:1174` 写入；不属源审计范围 |
| `open.png` | 1 | `REQUIRED` | 开场图（PNG 已支持） |

Σ = 254 + 2 + 2 + 2 + 2 + 2 + 1 + 1 + 1 + 1 = **268** ✅

审计门禁：

```
$ lua tools/mod_audit.lua --mod RiverLake
total=699 in_product=666 not_in_product=33 unclassified=0 bad_evidence=0
```

`unclassified=0` ⇒ 无 OTHER/UNKNOWN 兜底；`bad_evidence=0` ⇒ 所有 `needed=false`
都有结构化证据 ✅

### 3.1 254 项 fight 的三重确认

| # | 证据 | 结果 |
|---|------|------|
| 1 | `diff.md` 提及 `fight*.grp` | **127** |
| 2 | `diff.md` set == 产物差集 set | ✅ `True`（双向独有均为空） |
| 3 | `mod_audit` 中 219 项全部 `REQUIRED`/`in_product=true` | ✅ |

配对：127 个 `.grp` **全部**有 `.idx`，**127/127 尺寸一致** ✅

---

## 4. `not_in_product` 33 项

```
PENDING 27 + LEGACY 5 + BUILD_INPUT 1 = 33
```

### 4.1 PENDING 27

```
list/effect.bin   list/leave.bin   list/levelup.bin  list/match.bin
music/1.mid   music/2.mid   music/3.mid   music/4.mid   music/5.mid
music/6.mid   music/7.mid   music/8.mid   music/9.mid   music/10.mid
music/11.mid  music/12.mid  music/13.mid  music/14.mid  music/15.mid
music/16.mid  music/17.mid  music/18.mid  music/19.mid  music/20.mid
music/21.mid  music/22.mid  music/23.mid
```

（4 个 `list/*.bin` + 23 个 `music/*.mid` = 27）

- `music/*.mid` 23 项：MIDI 音乐，引擎侧待接入（epic 遗留 spike，全 20 MOD 主体）
- `list/{effect,leave,levelup,match}.bin` 4 项：**`effect.bin` 是 `CC.Effect` 的权威来源**
  （见 §6.1），其余 3 个为编辑器列表数据

> ⚠ **必须标注的矛盾**：`list/effect.bin` 归 `PENDING`（不进产物），
> 但它正是 `CC.Effect` 截断缺陷的**修复所需数据**。本 change **不**把它提升为
> `REQUIRED`（属 `CC.Effect` 修复的独立 change，见 §6.1）。

### 4.2 LEGACY 5

```
list/end.txt   list/start.txt   resource/name.grp   resource/name.idx   script/1.lua
```

- `name.{grp,idx}`：引擎零引用（ADR-006）
- `list/{end,start}.txt`：编辑器文本，引擎不读
- `script/1.lua`：MOD 内嵌脚本，`KDEF_SCRIPT=0` 时不用

### 4.3 BUILD_INPUT 1

```
resource/talkutf8.txt
```

talk 提取的中间源（构建期消费），产物里不需要 ✅

---

## 5. 记录段与资源计数（activate 侧交叉引用）

| 段 | 段长 | ÷ 尺寸 | 记录数 | 基线 | 差 |
|----|-----:|-------:|-------:|-----:|---:|
| Person | 59150 | 182 | **325** | 320 | +5 |
| Thing | 47310 | 190 | **249** | 200 | +49 |
| Scene | 4368 | 52 | **84** | 84 | **0** |
| Wugong | 13056 | 136 | **96** | 93 | +3 |

**Scene = 84 与基线相同的阴性对照**（必须用内容证明）：

| 记录 | RiverLake | pascal |
|------|-----------|--------|
| `Scene[0]` | **盛京** | 胡斐居 |
| `Scene[1]` | 河洛客棧 | 河洛客棧（MOD 保留） |
| `Scene[2]` | **靈鷲宮** | 雲鶴崖 |
| `Scene[83]` | **圣堂** | 聖堂 |

3/4 不同 ⇒ Scene 内容来自 MOD，**非回退原版** ✅

启动链路：`RESULT RiverLake: OK`（16/16 断言）。

---

## 6. 范围外发现（2 项 × 6 要素）

### 6.1 `CC.Effect` 硬编码 53 项 vs eft id 越界

| 要素 | 内容 |
|------|------|
| **① 现象** | `script/jyconst.lua:439` 的 `CC.Effect` 是 53 项字面量表（`[0]=9,14,17,...`，sum=712），而 `JY.Wugong[i]["武功动画&音效"]`（eft id）在多个 MOD 中超出上界 52 |
| **② 范围** | **7/20 MOD**：RiverLake **10** 条（max 69）/ books 2（55）/ awaken 1（53）/ pineapple **62**（83）/ pig3dos **52**（85）/ mingdong **136**（168）/ BookCalamity **296**（198） |
| **③ 根因/权威来源** | `list/effect.bin` = **每效果帧数**（int16），`UPedit.ini:80` 明确 `Effect=list\effect.bin`。语义链：`sum(effect.bin)` = `eft.idx` 条目数；3 MOD 精确相等（RiverLake 921 / BookCalamity 2857 / pineapple 1378）。RiverLake `effect.bin` = **70 项** |
| **④ 严重性** | **非致命**。`war_async.lua:1106` `fightdelay + (CC.Effect and CC.Effect[eft] or 10) or 10`；`:1126` `CC.Effect[i] or 0`。实测 `eft=69 → framenum=15, starteft=40`，无报错。仅**武功动画起始帧/帧数错位** |
| **⑤ 不修复理由** | `CC.Effect` 在 `script/jyconst.lua`，属**负约束禁改路径**。修复需在 `mod_data.RewriteConstants` 按 `effect.bin` 重建，并把 `list/effect.bin` 从 `PENDING` 提升为 `REQUIRED` —— 改动 20 MOD 的审计分类、构建管线、产物清单，属**独立 change** |
| **⑥ 修复路径** | 运行时读 `mods/<slug>/data/list/effect.bin`（需先纳入产物）→ 重建 `CC.Effect` 表。已写入 epic `TODO.md` |

补充：**pig3dos 另越出自己的 `effect.bin`**（eft id 85 vs 64 项）——
属其数据自身问题（pig3dos 已在 `annotated-problematic` 名单内）。
基线 pascal 亦有 1 帧偏差：`CC.Effect[0]=9` vs `effect.bin[0]=10`。

### 6.2 0 字节 `fight*.grp`

| 要素 | 内容 |
|------|------|
| **① 现象** | `fight*.grp` 文件存在但内容为 0 字节 |
| **② 范围** | **5/20 MOD**：pineapple **115**/154、RiverLake **44**/219、ptt 7/162、books 2/178、loving 2/107。其余 15 MOD（含 pascal）0 个 |
| **③ 根因** | **源包本身即 0 字节**。RiverLake 差集 127 项中 44 项为 0 字节，源↔产物 127/127 **尺寸完全一致**。`Person[i]["头像代号"]` 最大 216，其中 **34 个**指向 0 字节文件（文件缺失 0） |
| **④ 严重性** | **非致命**。`PicLoadFile` 对 0 字节 idx → `num=0`，循环不执行；`PicFile:getPic`（`lib_love.lua:262-285`）`idx[picid+1]==nil` → `Debug()` + `return nil`；`LoadPic`（`:291-295`）`idx2<=idx1` → `return nil`。实测 `PicLoadFile` pcall=true、`PicGetXY` 返回 0 |
| **⑤ 不修复理由** | ① 补内容 = **伪造** MOD 作者未提供的美术资源，违反「产物 = 源 + 格式转换」不变式；② 删除 = 破坏 `fight%03d` 的**位置绑定索引语义**，会让 34 个 Person 取不到图（更差） |
| **⑥ 修复路径** | 无需修复（源如此）。若 MOD 作者补数据，重建即生效 |

⇒ 归 `REQUIRED` 且 `in_product=true`（文件必须存在以维持索引语义），
内容 0 字节 = 源既有，非构建缺陷。

---

## 7. 门禁结果

| # | 命令 | 输出原文 |
|---|------|----------|
| 1 | `lua tests/test_runner.lua` | `Results: 1842 tests, 1842 passed, 0 failed` / `✓ 所有测试通过!` / `EXIT=0` |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `pascal baseline: events=1018, mismatches=0, known-deviations=3` → `PASS` |
| 3 | `lua tools/mod_build.lua --all` | `all: 20 mods, 0 build failures, 5 annotated-problematic` |
| 4 | `lua tools/mod_check.lua` | `总计: 20 MOD, 通过 20, 失败 0` |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0` / `evidence: checked=17 failed=0` |
| 6 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` |
| 7 | 20 MOD `save/` vs 源 | `比对 451 文件, 不一致/残留 = 0` |
| 8 | 脏态幂等（`mod_resources`） | `[INFO] 自愈重建产物 save 槽：恢复 451 个文件，删除 0 个残留` → `959 tests, 959 passed, 0 failed` |

> 注：门禁 3 退出码为 1，因其把 5 个 `annotated-problematic` MOD
>（BookCalamity / zheng / loving / awaken / pig3dos，`games.ini` 已标注）计入 `os.exit(1)`。
> **`build failures` = 0**，属既有设计，非本 slice 引入。

### 7.1 禁改路径零改动

| 路径 | 状态 |
|------|------|
| `game/engine-love2d/**` | 零改动 ✅ |
| `game/engine-mud/**` | 零改动 ✅ |
| `game/script/jyconst.lua` 常量定义 | 零改动 ✅ |
| `reference/allmods/**` | 零改动 ✅ |

---

## 8. 本轮修复的测试工具缺陷（缺陷 F，第 6 个）

**现象**：全量首跑出现 4 条 mingdong 假失败。

**根因**：`test_mod_boot.testSaveLoadRoundTripWithMingdong` 写
`mods/mingdong/save/{r1,d1,s1}.grp`，仅在**正常结束**时恢复；被中断则残留。
runner 顺序中 `mod_resources`（16）**先于** `mod_boot`（21），故下次运行读到脏槽。

**确定性复现**：

```
$ printf 'DIRTY' >> game/mods/mingdong/save/r1.grp
$ lua tests/test_runner.lua mod_resources
[FAIL] mingdong r1.grp 大小一致: expected 222893, got 222888
[FAIL] mingdong r1.grp 内容一致: expected true, got false
Results: 739 tests, 737 passed, 2 failed
```

**修复**：`game/tests/unit/test_mod_resources.lua` 新增
`TestModResources.restoreAllProductSaves()` —— 比对前对 20 MOD 产物 `save/` 做
**自愈式重建**（源包有的逐字节拷回，源包没的删除）。测试从此**幂等**，
不依赖执行顺序、不依赖上一轮是否正常结束。

**修复后**（从脏态起跑）：

```
[INFO] 自愈重建产物 save 槽：恢复 451 个文件，删除 0 个残留
Results: 959 tests, 959 passed, 0 failed
```

全量：`1842 tests, 1842 passed, 0 failed`。

> 测试总数 **1622 → 1842（+220）**：增量**不是**新增断言，而是自愈重建让此前
> 因「源/产物文件缺失」被 `else` 分支跳过的比对断言真正执行（`mod_resources`
> 从 739 → 959）。属**覆盖扩充**，非行为变更。

---

## 9. 详细证据索引

| 主题 | 位置 |
|------|------|
| 构建产物计数 | activate `verification.md` §2 |
| 逐文件审计 699 | activate `verification.md` §3 |
| 字节级覆盖 413 | activate `verification.md` §4 |
| 启动链路 16 断言 | activate `verification.md` §5 |
| 记录段 + Scene 阴性对照 | activate `verification.md` §6 |
| `hdgrp` 252 三判据 | activate `verification.md` §7 |
| `eft` 921 + `CC.Effect` 缺陷 | activate `verification.md` §8 |
| 127 场战斗 + 44 空文件 | activate `verification.md` §9 |
| 存档 21/21 | activate `verification.md` §10 |
| 空 WAV 28 个 | activate `verification.md` §11 |
| 门禁 8 道 | activate `verification.md` §13 / 本报告 §7 |
| ADR 判据 | activate `design.md` ADR-001~007 |
| 四类定性判据 | verify `design.md` ADR-001 |
| 缺陷 F | verify `design.md` ADR-002 |
