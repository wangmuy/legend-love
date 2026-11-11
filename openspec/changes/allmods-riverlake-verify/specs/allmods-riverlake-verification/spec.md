# Spec: allmods-riverlake-verification

> 需求 ID 前缀 `REQ-RIVV-`。每个场景使用 Given / When / Then。

## REQ-RIVV-1：`diff.md` 差异报告审计（重算对账）

**Given** `mods/RiverLake/diff.md` 声称「MOD 独有 268」「基准独有 21」
**When** 独立重算（`diff.md` 解析 vs `ls` 实际目录）
**Then** 两组数字**完全一致**，且组成正确：

| 项 | `diff.md` 声称 | 本轮重算 | 一致 |
|----|---------------:|---------:|:----:|
| MOD 独有总数 | 268 | **268** | ✅ |
| — 其中 `fight*` | （未分类） | **254**（127 `.grp` + 127 `.idx`） | — |
| — 其中非 `fight` | （未分类） | **14** | — |
| 基准独有总数 | 21 | **21** | ✅ |

**And** 14 项非 fight 逐项为：

```
cloud.grp  cloud.idx  kdef.grp  kdef.idx  kysmod.ini  name.grp  name.idx
open.png   ranger.str talk.grp  talk.idx  talkutf8.txt  title.grp  title.idx
```

**And** 按扩展名分布：`grp 132` / `idx 132` / `ini 1` / `png 1` / `str 1` / `txt 1`
（132+132+1+1+1+1 = 268）✅

**And** 不得出现 `diff.md` 与实测不符（漏报/虚报）。

---

## REQ-RIVV-2：「基准独有」21 项四类定性

**Given** 21 项基准独有清单
**When** 逐项打印 `CC.*` 运行时解析值 + 检查源/产物/基线三处存在性
**Then** 每项落入且仅落入一类，Σ = 21：

### A. 在 save/（源自带存档）= 9 项

| 文件 | 源 `save/` | 产物 `save/` | 逐字节一致 |
|------|-----------:|-------------:|:----------:|
| `d1.grp` | 369600 | 369600 | ✅ |
| `d2.grp` | 369600 | 369600 | ✅ |
| `d3.grp` | 440000 | 440000 | ✅ |
| `r1.grp` | 125894 | 125894 | ✅ |
| `r2.grp` | 124870 | 124870 | ✅ |
| `r3.grp` | 114242 | 114242 | ✅ |
| `s1.grp` | 4128768 | 4128768 | ✅ |
| `s2.grp` | 4128768 | 4128768 | ✅ |
| `s3.grp` | 4915200 | 4915200 | ✅ |

### B. 首次播种 = 9 项

`d1.idx` `d2.idx` `d3.idx` `r1.idx` `r2.idx` `r3.idx` `s1.idx` `s2.idx` `s3.idx`

| 判据 | 证据 |
|------|------|
| 源不存在 | 9 个全部 `源存在=False` |
| 产物不存在 | 9 个全部 `产物存在=False` |
| 运行时路径指向 MOD 存档目录 | `CC.R_IDXFilename[1] = mods/RiverLake/save/r1.idx` |
| 播种机制实测 | `SeedSaveSlot(1)` → `save/r1.idx` == `mods/RiverLake/data/ranger.idx`（**True**），== `data/ranger.idx`（**False**） |

### C. 回退原版 = 2 项

`thing.grp` `thing.idx`

| 判据 | 证据 |
|------|------|
| 源 `resource/` 不存在 | `ls reference/allmods/kys-RiverLake/resource/thing.*` → 无 |
| 产物不存在 | `mods/RiverLake/data/thing.*` → 不存在 |
| 基线存在 | `data/thing.grp` 345600B、`data/thing.idx` 800B |
| 运行时路径指向基线 | `CC.ThingPicFile[1] = data/thing.idx`、`[2] = data/thing.grp`、`CC.LoadThingPic = 1` |

### D. 死文件 = 1 项

`allsinbk.grp`

| 判据 | 证据 |
|------|------|
| 源不存在 | 源 `save/` 无该文件 |
| 产物不存在 | `mods/RiverLake/data/allsinbk.grp` 不存在 |
| 基线存在 | `data/allsinbk.grp` 4128768B |
| 常量存在 | `CC.TempS_Filename = "data/allsinbk.grp"`（`jyconst.lua:96`） |
| 传入引擎 | `jymain.lua:1835` `lib.LoadSMap(sFile, CC.TempS_Filename, ...)` |
| **引擎从不读取** | `lib_love.lua:890` `LoadSMap(Sfilename, tmpfilename, ...)` —— `tmpfilename` 形参在函数体内**完全未使用**（`grep -n tmpfilename` 仅命中签名本身 1 处） |

**And** 负约束：不得用「不确定」「待查」；不得把 B 归 C 或 D。

---

## REQ-RIVV-3：268 项 MOD 独有全量归类

**Given** 268 项 MOD 独有
**When** 执行 `lua tools/mod_audit.lua --mod RiverLake`
**Then** `unclassified=0 bad_evidence=0`，且 268 项全部落入具名类别：

| 类别 | 项数 | 说明 |
|------|-----:|------|
| `fight*.grp` + `fight*.idx` | **254** | 127 场 × 2；全 `REQUIRED`/`in_product=true` |
| `cloud.{grp,idx}` | 2 | `CC.WMAPPicFile` 等引用 |
| `kdef.{grp,idx}` | 2 | `CC.KDEFScript`/事件指令 |
| `title.{grp,idx}` | 2 | `CC.TitlePic` |
| `talk.{grp,idx}` | 2 | `CC.TalkGrpFile`/`CC.TalkIdxFile` |
| `name.{grp,idx}` | 2 | `LEGACY`（引擎不读） |
| `kysmod.ini` | 1 | `BUILD_INPUT`→构建产物，`REQUIRED` |
| `talkutf8.txt` | 1 | `BUILD_INPUT`（talk 提取源） |
| `ranger.str` | 1 | 构建产物（`mod_build.lua:1174` 写入），不属源审计 |
| `open.png` | 1 | PNG 资源 |

**And** Σ = 254 + 2×5 + 1 + 1 + 1 + 1 = **268** ✅

---

## REQ-RIVV-4：`not_in_product` 33 项显式证据

**Given** `not_in_product=33`
**When** 按类别枚举
**Then** `PENDING 27` + `LEGACY 5` + `BUILD_INPUT 1` = **33**，且每项列出文件名：

### PENDING 27

```
list/effect.bin  list/leave.bin  list/levelup.bin  list/match.bin
music/1.mid  music/2.mid  music/3.mid  music/4.mid  music/5.mid  music/6.mid
music/7.mid  music/8.mid  music/9.mid  music/10.mid music/11.mid music/12.mid
music/13.mid music/14.mid music/15.mid music/16.mid music/17.mid music/18.mid
music/19.mid music/20.mid music/21.mid music/22.mid music/23.mid
```

（4 个 `list/*.bin` + 23 个 `music/*.mid` = 27）

### LEGACY 5

```
list/end.txt  list/start.txt  resource/name.grp  resource/name.idx  script/1.lua
```

### BUILD_INPUT 1

```
resource/talkutf8.txt
```

**And** 关键结论：`list/effect.bin` 是 PENDING 的 4 个 `list/*.bin` 之一，
**但它实际是 `CC.Effect` 的权威来源**（activate ADR-003）。
本 change **不**把它提升为 `REQUIRED`（属 `CC.Effect` 修复的独立 change），
但必须在报告中显式标注这一矛盾。

---

## REQ-RIVV-5：范围外发现记录完整性

**Given** 两项范围外既有缺陷
**When** 写 `verification.md` 与 `reports/riverlake-verify.md`
**Then** 每项必须含 **6 要素**（ADR-003）：

| 要素 | `CC.Effect` 截断 | 44 个 0 字节 `fight*.grp` |
|------|------------------|---------------------------|
| ① 现象 | eft id 越 53 项上界 | 文件存在但 0 字节 |
| ② 范围 | **7/20 MOD**：RiverLake 10 / books 2 / awaken 1 / pineapple 62 / pig3dos 52 / mingdong 136 / BookCalamity 296 | **5/20 MOD**：pineapple 115 / RiverLake 44 / ptt 7 / books 2 / loving 2 |
| ③ 根因/权威 | `list/effect.bin` + `UPedit.ini:80`；`sum(effect.bin)==eft.idx` 3 MOD 精确相等 | 源包本身即 0 字节，源↔产物 127/127 尺寸一致 |
| ④ 严重性 | 非致命：`or 10` / `or 0` 回退，仅动画帧错位 | 非致命：`getPic` 返回 `nil`，`PicGetXY` 返回 0 |
| ⑤ 不修复理由 | `jyconst.lua` 禁改；需改 20 MOD 审计分类+构建管线 | 补数据=伪造；删除=破坏 `fight%03d` 索引语义 |
| ⑥ 修复路径 | `mod_data.RewriteConstants` 按 `effect.bin` 重建 `CC.Effect` | 无需修复（源如此） |

**And** 两项均须写入 epic `TODO.md`。

---

## REQ-RIVV-6：零引擎改动 + 零回归

**Given** 全部验证完成
**When** 执行 8 道门禁
**Then** 全部通过：

| # | 门禁 | 期望 |
|---|------|------|
| 1 | `cd game && lua tests/test_runner.lua` | **1842/1842** |
| 2 | `lua tools/mod_build.lua --verify-pascal` | `mismatches=0` PASS |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures` |
| 4 | `lua tools/mod_check.lua` | **20/20** |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `unclassified=0 bad_evidence=0`，`failed=0` |
| 6 | `lua tools/format_spec.lua --all` | `gaps=0` |
| 7 | 20 MOD `save/` vs 源 | **451 文件，不一致/残留 = 0** |
| 8 | 脏态幂等 | `mod_resources` 从脏态起跑仍全 Green |

**And** 禁改路径零改动：

| 路径 | 期望 |
|------|------|
| `game/engine-love2d/**` | 零改动 |
| `game/engine-mud/**` | 零改动 |
| `game/script/jyconst.lua` 常量定义 | 零改动 |
| `reference/allmods/**` | 零改动 |

---

## REQ-RIVV-7：报告产出

**Given** 以上全部证据
**When** 生成 `reports/riverlake-verify.md`
**Then** 必须包含 6 个章节（ADR-004）：

1. 重算对账（`diff.md` vs 实测，两列并列）
2. 21 项基准独有逐项表（文件名 | 源 | 产物 | 基线 | 类别 | 证据）
3. 268 项 MOD 独有归类表（254 fight 聚合 + 14 非 fight 逐项）
4. 33 项未进产物表（PENDING 27 / LEGACY 5 / BUILD_INPUT 1 逐项文件名）
5. 范围外发现 2 项 × 6 要素
6. 门禁结果（8 道，命令 + 输出原文）

**And** 读者须能只凭报告重算全部数字.
