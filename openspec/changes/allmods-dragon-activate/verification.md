---
status: done
created: 2026-10-25
---

# Verification: allmods-dragon-activate

所有数字均在**本轮**于 `/home/woodfish/project/legend-love` 工作树实跑得到。

## 1. 构建（REQ-DRG-1）

```
$ cd game && rm -f active_mod.txt && lua tools/mod_build.lua kys-Dragon
[mod_build] kys-Dragon: data files=458, saves=21, sound=80, events=1087, talk=4020
[mod_build] diff -> tools/../mods/Dragon/diff.md
```

| 项 | 实测 | 期望 | ✅ |
|----|-----:|-----:|:--:|
| data files | 458 | 458 | ✅ |
| saves | 21 | 21 | ✅ |
| sound | 80 | 80 | ✅ |
| events | 1087 | 1087 | ✅ |
| talk | 4020 | 4020 | ✅ |
| `fight*.grp` | 209 | 209 | ✅ |
| `save/` 文件 | 27 | 27 | ✅ |
| `diff.md` | 已生成 | — | ✅ |

## 2. 逐文件穷举审计（REQ-DRG-2）

```
$ lua tools/mod_audit.lua --mod Dragon
total=811 in_product=555 not_in_product=256 unclassified=0 bad_evidence=0
  REQUIRED             550
  REQUIRED_CONVERTED   4
  LEGACY               5
  DEAD_FILE            1
  EDITOR_DUMP          220
  BUILD_INPUT          2
  PENDING              29
```

| 检查 | 实测 | ✅ |
|------|------|:--:|
| `total` == 源文件数 | 811 == `find … -type f \| wc -l` = 811 | ✅ |
| Σ 类别 | 550+4+5+1+220+2+29 = **811** | ✅ |
| `unclassified` | 0 | ✅ |
| `bad_evidence` | 0 | ✅ |
| `needed=true` 全 `in_product` | 550+4 = 554，全部 `in_product=true` | ✅ |
| `not_in_product` 分解 | 220+29+5+1+1 = **256** | ✅ |

**未进产物的 256 项明细**（逐项导出）：

| 类别 | 项数 | 内容 |
|------|-----:|------|
| `EDITOR_DUMP` | 220 | `head/0.png`~`head/219.png`（全 `topdir=head`） |
| `PENDING` | 29 | `list/effect.bin`、`list/leave.bin`、`list/levelup.bin`、`list/match.bin`、`list/match - 复制.bin`、`music/0.mid`~`music/23.mid` |
| `LEGACY` | 5 | `list/end.txt`、`list/start.txt`、`resource/name.grp`、`resource/name.idx`、`script/1.lua` |
| `DEAD_FILE` | 1 | `resource/war1.sta` |
| `BUILD_INPUT` | 1 | `resource/talkutf8.txt` |

> 注：`BUILD_INPUT` 共 2 项，其中 `kysmod.ini` 进产物（`in_product=true`），
> `resource/talkutf8.txt` 作为构建输入不进产物 ⇒ `not_in_product` 只计 1。

## 3. 字节级格式覆盖（REQ-DRG-3）

```
$ lua tools/format_spec.lua --mod Dragon
formats=12 checked=535 gaps=0
```

## 4. 真实启动链路（REQ-DRG-4）

```
$ rm -f active_mod.txt
$ lua tests/unit/boot_one_mod.lua Dragon 589 237 106 114 資
[PASS] lib.init 无报错: nil
[PASS] JYMainAdapter.init 无报错: nil
[PASS] CC.PersonSize=182（MOD 布局） (期望 182, 实际 182)
[PASS] CC.ThingSize=190（MOD 布局） (期望 190, 实际 190)
[PASS] CC.SceneSize=52（MOD 布局） (期望 52, 实际 52)
[PASS] CC.WugongSize=136（MOD 布局） (期望 136, 实际 136)
[PASS] LoadRecord(0) 无报错: true
[PASS] PersonNum (期望 589, 实际 589)
[PASS] ThingNum (期望 237, 实际 237)
[PASS] SceneNum (期望 106, 实际 106)
[PASS] WugongNum (期望 114, 实际 114)
[PASS] 主角姓名 (期望 資, 实际 資)
[PASS] 扫描字段数 > 100（实际 2109）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
--------------------------------------------------
RESULT Dragon: OK
```

16/16 PASS。

## 5. `hdgrp` 267（REQ-DRG-5，判据第 7 次应用）

```
$ stat -c%s mods/Dragon/data/hdgrp.idx
1068        → 1068 / 4 = 267 条目（基线 115，+152）
```

| 判据 | 证据 | 结果 |
|------|------|:----:|
| ① 索引驱动 | `engine-love2d/lib_love.lua:437` `local num = idxlen/4` | ✅ |
| ② 无固定计数常量 | `grep -rn "hdgrpNum\|HDGRPNum\|HDPicNum\|MAX_HEAD" engine-love2d/ framework/ script/jyconst.lua` → **0 命中** | ✅ |
| ③ 字节无缺口 | `format_spec --mod Dragon` → `gaps=0` | ✅ |

⇒ **内容差异**（MOD 多 152 张头像），零引擎改动。

**外推链**：125 → 129 → 173 → 178 → 204 → 252 → **267**（7 个样本一致）。

## 6. `eft` 714 同形（REQ-DRG-6，ADR-002）

```
$ stat -c%s mods/Dragon/data/eft.idx mods/Dragon/data/eft.grp
2856
691627      → 2856 / 4 = 714 条目（= 基线 714）
```

| 检查 | 实测 | ✅ |
|------|------|:--:|
| `eft.idx` 条目 | 714 | ✅ |
| `eft.grp` 字节 | 691627 | ✅ |
| 偏移单调不减 | `monotonic: True` | ✅ |
| `idx[-1] == grp` 大小 | `691627 == 691627` → True | ✅ |
| `eft.grp` md5 vs 基线 | `1c5aef33893e078ade30f6d237ec6cb1` == 基线 | ✅ |
| `eft.idx` md5 vs 基线 | `35ccc7e5cc1a096e183d3ff2919f743b` == 基线 | ✅ |
| 源文件存在 | `reference/allmods/kys-Dragon/resource/eft.{grp,idx}` | ✅ |
| 产物存在 | `mods/Dragon/data/eft.{grp,idx}` | ✅ |
| 运行时路径 | `CC.EffectFile[1] = mods/Dragon/data/eft.idx`<br>`CC.EffectFile[2] = mods/Dragon/data/eft.grp` | ✅ |

⇒ 判定为 **「MOD 未修改该资源」**，**不是**「回退原版」。
路径指向 **MOD** 目录，只是文件内容与基线恰好逐字节相同。

## 7. eft id 上界 52（REQ-DRG-7）

```
WugongNum=114  eft id max=52  (CC.Effect 上界 52)
越界条数: 无
```

⇒ Dragon 归入 **13/20 个「不越界」MOD**，**不受** RiverLake 发现的
`CC.Effect` 硬编码 53 项截断缺陷影响。

## 8. 记录段 589/237/106/114（REQ-DRG-8，判据第 4 次应用）

```
$ python3 读 reference/allmods/kys-Dragon/save/ranger.idx
offsets: [836, 108034, 153064, 158576, 174080, 174230]
grp size: 174230
```

| 段 | 段长 | ÷ 尺寸 | 记录数 | 基线 | 差 | 余数 |
|----|-----:|-------:|-------:|-----:|---:|-----:|
| Person | 107198 | 182 | **589** | 320 | **+269** | **0** |
| Thing | 45030 | 190 | **237** | 200 | **+37** | **0** |
| Scene | 5512 | 52 | **106** | 84 | **+22** | **0** |
| Wugong | 15504 | 136 | **114** | 93 | **+21** | **0** |
| Shop | 150 | 50 | 3 | 3 | 0 | **0** |

Σ 段长 = 107198+45030+5512+15504+150 = **173394** = 174230 − 836 ✅

**边界记录**：

```
Person  n=589  [0]=資          [588]=李卡多
Thing   n=237  [0]=小還丹       [236]=真武劍
Scene   n=106  [0]=胡斐居       [105]=西部農村
Wugong  n=114  [0]=普通攻擊     [113]=閃電貂
```

**4 段全异**（含 Scene +22）⇒ 判据第 4 次应用
（lyff 1 段异 / ptt 4 段异 / RiverLake 3 段异 / Dragon 4 段异 + Scene 异）。

**Scene 内容证明**（不只靠记录数）：

| 记录 | Dragon | pascal | 相同 |
|------|--------|--------|:----:|
| `Scene[0]` | 胡斐居 | 胡斐居 | ✅（MOD 保留原版首场景） |
| `Scene[1]` | 河洛客棧 | 河洛客棧 | ✅（保留） |
| `Scene[2]` | **雪山** | 云鶴崖 | ❌ |
| `Scene[50]` | **閰基居** | —（超基线 84） | ❌ |
| `Scene[105]` | **西部農村** | —（超基线 84） | ❌ |

Person 内容对照：

| 记录 | Dragon | pascal |
|------|--------|--------|
| `Person[0]` | 資（外号：天下奇男子） | 徐小俠 |
| `Person[1]` | 胡斐（雪山飛狐） | 胡斐 |
| `Person[2]` | 程靈素（毒手藥王） | 程靈素 |
| `Person[100]` | 云中鶴（崑侖弟子） | 崑侖弟子 |
| `Person[588]` | 李卡多（五毒教徒） | —（超基线 320） |

## 9. 额外战斗（REQ-DRG-9）

```
pascal fight grp: 92   Dragon: 209
diff: 119   removed: ['fight101.grp', 'fight102.grp']
校验: 92 - 2 + 119 = 209  ✅
```

三重确认：

| # | 证据 | 结果 | ✅ |
|---|------|------|:--:|
| 1 | `diff.md` 中 `fight*.grp` MOD 独有 | **119** | ✅ |
| 2 | `diff.md` set == 实测差集 set | `True` | ✅ |
| 3 | 产物 209 全部 `REQUIRED`/`in_product=true` | 209/209 | ✅ |

## 10. `fight101`/`fight102` 缺失容错（REQ-DRG-10，ADR-003/007）

**MOD 数据仍引用 101/102**：

```
Person 总数=589 有头像代号=217 最大=219
引用 101 ? true   引用 102 ? true
CC.FightPicFile[1]=mods/Dragon/data/fight%03d.idx
CC.FightPicFile[2]=mods/Dragon/data/fight%03d.grp
```

**三级降级实测**：

```
PicLoadFile(缺失 fight101) pcall=true err=nil
PicGetXY        pcall=true ret=0
```

| 级 | 位置 | 行为 |
|----|------|------|
| 1 | `PicLoadFile`（`lib_love.lua:423`） | `FileLength` 打开失败返回 **-1** ⇒ `if idxlen < 0 or grplen < 0 then return end` |
| 2 | `PicFile:getPic`（`:262`） | `f == nil` ⇒ `Debug()` + `return nil` |
| 3 | `PicGetXY`（`:454`） | pcall 保护，返回 `0` |

⇒ 不崩溃，仅该头像显示空白。判定为 **MOD 作者侧数据不一致**，不修复。

## 11. 存档完好 + 25 项「基准独有」五分法（REQ-DRG-11，ADR-007）

```
源 save: 27   产物 save: 27
缺失/不一致: []
产物多余: []
```

27 个产物文件构成：**21 个 `.grp`** + **6 个 `.idx`**
（`alldef.idx` 336B、`allsin.idx` 336B、`ranger.idx` 24B、`r1.idx`/`r2.idx`/`r3.idx` 各 24B）。

> **本 change 初稿错误已修正**：初稿称「源 `save/` 无 `.idx` 槽 ⇒ 无首次播种」。
> 实测源 `save/` **有** 3 个 `.idx`（`alldef`/`allsin`/`ranger`），但**无** `r1`~`r3.idx`，
> 故**仍有 9 项首次播种**。

**25 项「基准独有」五分法**：

| 类别 | 项数 | 判据（运行时实测） |
|------|-----:|--------------------|
| **A 在 save/（源自带存档）** | 9 | `d1`~`d3`/`r1`~`r3`/`s1`~`s3` `.grp`；源↔产物逐字节一致 |
| **B 首次播种** | 9 | 对应 9 个 `.idx`；源无、产物有；`SeedSaveSlot` 播种 |
| **C 回退原版** | 2 | `thing.{grp,idx}`；`CC.ThingPicFile = data/thing.*` |
| **D 死文件** | 1 | `allsinbk.grp`；`tmpfilename` 形参零引用 |
| **E 数据引用但资源缺失（本 epic 新增）** | **4** | `fight101/102.{grp,idx}`；`Person["头像代号"]` 仍引用 |

Σ = 9 + 9 + 2 + 1 + 4 = **25** ✅

**A 类逐字节**：

| 文件 | 源 | 产物 | 一致 |
|------|----:|-----:|:----:|
| `d1.grp` | 466400 | 466400 | ✅ |
| `d2.grp` | 466400 | 466400 | ✅ |
| `d3.grp` | 466400 | 466400 | ✅ |
| `r1.grp` | 174230 | 174230 | ✅ |
| `r2.grp` | 174230 | 174230 | ✅ |
| `r3.grp` | 174230 | 174230 | ✅ |
| `s1.grp` | 5210112 | 5210112 | ✅ |
| `s2.grp` | 5210112 | 5210112 | ✅ |
| `s3.grp` | 5210112 | 5210112 | ✅ |

**B 类播种实验（可执行判据）**：

```
slot 0 idx=mods/Dragon/data/ranger.idx   size=24
slot 1 idx=mods/Dragon/save/r1.idx       size=-1   ← 不存在 ⇒ 触发播种
slot 2 idx=mods/Dragon/save/r2.idx       size=-1
slot 3 idx=mods/Dragon/save/r3.idx       size=-1

SeedSaveSlot(1) = mods/Dragon/save/r1.idx
SeedSaveSlot(2) = mods/Dragon/save/r2.idx
SeedSaveSlot(3) = mods/Dragon/save/r3.idx

mods/Dragon/save/r1.idx size=24 (MOD ranger.idx=24)
mods/Dragon/save/r2.idx size=24 (MOD ranger.idx=24)
mods/Dragon/save/r3.idx size=24 (MOD ranger.idx=24)

r1.idx == MOD ranger.idx: True      r1.idx == baseline: False
r2.idx == MOD ranger.idx: True      r2.idx == baseline: False
r3.idx == MOD ranger.idx: True      r3.idx == baseline: False
```

⇒ 播种源为 **MOD** 的 `ranger.idx`（`ModData.DATA_DIR` 经 `Resolve` 指向 MOD），非基线。
实验后产物已恢复并校验：`src 27 prod 27 same set: True`、`byte-diff: []`。

**C 类运行时路径**：

```
CC.ThingPicFile[1]=data/thing.idx
CC.ThingPicFile[2]=data/thing.grp
```

⇒ 指向**基线** `data/`（MOD 源无 `thing.*`），符合 C 类判据。

**D 类代码级证据**：

```
$ grep -n "TempS_Filename" script/jymain.lua script/jyconst.lua
script/jymain.lua:1835:  lib.LoadSMap(sFile,CC.TempS_Filename,JY.SceneNum,...)
script/jyconst.lua:96:   CC.TempS_Filename=CONFIG.DataPath .. "allsinbk.grp";

$ grep -c "tmpfilename" engine-love2d/lib_love.lua
1
$ grep -n "tmpfilename" engine-love2d/lib_love.lua
890:function LoadSMap(Sfilename, tmpfilename, num, x_max, y_max, Dfilename, d_num1, d_num2)
```

⇒ **仅 1 处命中 = 函数签名**，函数体零引用 ⇒ 路径传入但内容永不读取。
运行时 `CC.TempS_Filename = data/allsinbk.grp`（**基线**，MOD 源无）。

## 12. `war1.sta` `DEAD_FILE`（REQ-DRG-12，ADR-005）

| # | 证据 | 实测 | ✅ |
|---|------|------|:--:|
| 1 | 文件大小与记录数 | 66030B，`66030 ÷ 186 = 355` 记录（`CC.WarDataSize=186`） | ✅ |
| 2 | `CC.WarFile` 只指向 `war.sta` | `script/jyconst.lua:129`；运行时 `mods/Dragon/data/war.sta` | ✅ |
| 3 | 代码零引用 | `grep -rn "war1" script/ framework/ engine-love2d/` → **0 命中** | ✅ |
| 4 | 审计规则已标注 | `tools/mod_audit.lua:189` `category="DEAD_FILE", needed=false`；`:132` 证据串「引擎只读 war.sta，war1.sta 不可达」 | ✅ |
| 5 | 产物含该文件 | `mods/Dragon/data/war1.sta` 66030B（照源复制，不主动删） | ✅ |

**与 RiverLake `allsinbk.grp` 的机制区别**（必须区分）：

| 维度 | RiverLake `allsinbk.grp` | Dragon `war1.sta` |
|------|--------------------------|-------------------|
| 常量 | **存在**（`CC.TempS_Filename`） | **不存在** |
| 传参 | **传入** `LoadSMap` | 从不传入 |
| 引擎侧 | 形参声明但**未使用** | 完全无代码路径 |
| 归类来源 | 运行时取证 | `mod_audit` 规则 |
| 语义 | **路径被引用 ≠ 内容被使用** | **路径从未被引用** |

## 13. `head/` 220 PNG = `EDITOR_DUMP`（REQ-DRG-13，ADR-004）

| # | 证据 | 实测 | ✅ |
|---|------|------|:--:|
| 1 | 数量 | `ls reference/allmods/kys-Dragon/head \| wc -l` → **220** | ✅ |
| 2 | 构建忽略 | `tools/mod_build.lua:567` `IGNORE_DIRS = { head = true, item = true, eft = true }` | ✅ |
| 3 | 引擎零引用 | `grep -rn 'head/\|"head"' engine-love2d/ framework/ script/` → **0 命中** | ✅ |
| 4 | 产物无该目录 | `ls mods/Dragon/` → `data diff.md encoding-report.md save script sound` | ✅ |
| 5 | 审计归类 | `EDITOR_DUMP` = 220，全 `in_product=false`，`topdir=head` | ✅ |

⇒ 第 3 次同类判定（GodsDevils 279 / ptt 105 / Dragon **220**），判据稳定。

## 14. `war.sta` 同名不同内容（ADR-006）

| 文件 | 源 = 产物 | 基线 `data/` |
|------|----------:|-------------:|
| `war.sta` | **42222B**（227 记录） | 26040B（140 记录） |

两处均 `÷ 186` 整除（227 / 140）⇒ **内容差异**，非结构异常。

## 15. 门禁（REQ-DRG-14，全部实跑）

| # | 门禁 | 命令 | 实测结果 | ✅ |
|---|------|------|----------|:--:|
| 1 | 单元测试 | `lua tests/test_runner.lua` | **1842/1842 passed** | ✅ |
| 2 | 原版基线 | `lua tools/mod_build.lua --verify-pascal` | `events=1018, mismatches=0, known-deviations=3` PASS | ✅ |
| 3 | 全量构建 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures, 5 annotated-problematic`（退出码 1 属既有设计，`mod_build.lua:1224-1226`） | ✅ |
| 4 | 产物自检 | `lua tools/mod_check.lua` | **20 MOD, 通过 20, 失败 0** | ✅ |
| 5 | 全量审计 | `lua tools/mod_audit.lua --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`；`evidence: checked=17 failed=0` | ✅ |
| 6 | 全量格式 | `lua tools/format_spec.lua --all` | `formats=12 checked=6773 gaps=0` | ✅ |
| 7 | 存档一致 | 20 MOD `save/` vs 源 | **451 文件，真实问题 0**（430 逐字节一致 + **21 项设计内转换**：`ranger.grp`×20 经 Big5→UTF-8+hint 重写、`ranger.idx`×1 由 `RepairIdx` 重建；详见 `allmods-dragon-verify/tasks.md` §15.9） | ✅ |
| 8 | 脏态幂等 | `test_runner.lua` 连跑两次 | 两次均 **1842/1842** | ✅ |

**禁改路径零改动**：

```
$ git status --porcelain game/engine-love2d game/engine-mud reference/allmods
（空）
```

`game/script/jyconst.lua` 的既有改动（+11 行 MOD 回退调用）来自
`allmods-data-fallback` change，属**既有接线**，`CC.*` 常量**定义**未改。

## 16. 结论

| REQ | 结果 |
|-----|------|
| REQ-DRG-1 构建 | ✅ `files=458 saves=21 sound=80 events=1087 talk=4020` |
| REQ-DRG-2 穷举审计 | ✅ `total=811 unclassified=0 bad_evidence=0`，Σ 类别 = 811 |
| REQ-DRG-3 字节覆盖 | ✅ `formats=12 checked=535 gaps=0` |
| REQ-DRG-4 启动链路 | ✅ `RESULT Dragon: OK`（16/16） |
| REQ-DRG-5 `hdgrp` 267 | ✅ 判据第 7 次应用 |
| REQ-DRG-6 `eft` 714 同形 | ✅ md5 相同但路径指向 MOD ⇒ 非回退 |
| REQ-DRG-7 eft 上界 52 | ✅ 不触发 `CC.Effect` 截断 |
| REQ-DRG-8 记录段 | ✅ 589/237/106/114，判据第 4 次应用 |
| REQ-DRG-9 额外战斗 | ✅ 119 新增 / 2 移除 / 净 +117，三重确认 |
| REQ-DRG-10 缺失容错 | ✅ 三级降级，pcall=true，不崩溃 |
| REQ-DRG-11 存档 + 五分法 | ✅ 27/27 一致；25 项 = 9+9+2+1+**4** |
| REQ-DRG-12 `war1.sta` | ✅ `DEAD_FILE` 四证据 |
| REQ-DRG-13 `head/` 220 | ✅ `EDITOR_DUMP` 五证据 |
| REQ-DRG-14 零回归 | ✅ 8 道门禁全 Green |

**本 slice 新增方法与类别**：

1. **E 类「数据引用但资源缺失」** —— 第 5 个「基准独有」类别，
   与 RiverLake 的 0 字节 fight 共同覆盖「缺资源」的两种形态（内容空 vs 完全缺失）。
2. **「同形 ≠ 回退」反面判据** —— 与 Slice 10 的 Scene 阴性对照互补：
   RiverLake 是「计数相同、内容不同」，Dragon 是「内容相同、来源是 MOD」。
   两者确立「来源」与「内容」两个正交维度。

**偏差记录**：本 change 初稿曾误称「源 `save/` 无 `.idx` 槽 ⇒ 无首次播种」，
已在 `spec.md` REQ-DRG-11 与 `tasks.md` 11.2 显式修正（实测有 3 个 `.idx`，
但没有 `r1`~`r3.idx`，故仍有 9 项播种）。
