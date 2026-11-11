# SweeOan（瑞安群侠传）验证报告

> Change: `allmods-sweeOan-verify` · Slice: `allmods-slice2` · Epic: `2026-10-allmods-compat`
> 日期：2026-10-19
> 结论：**PASS**（发现并修复 1 个跨 20 MOD 的真实缺陷）

---

## 1. 结论摘要

| 维度 | 结果 |
|------|------|
| 构建 | ✅ `events=1018`，退出码 0 |
| 逐文件穷举 | ✅ `total=334 unclassified=0 bad_evidence=0` |
| 「必需但未进产物」矛盾 | ✅ **0** |
| 字节级覆盖 | ✅ `formats=12 checked=196 gaps=0` |
| 产物四项检查 | ✅ `STRINGS/EVENTS/SAVE=OK` |
| 真实启动链路 | ✅ `RESULT SweeOan: OK`（16 项断言） |
| MOD 独有内容 | ✅ 确认为 MOD 内容（非回退） |
| 引擎改动 | ✅ **零改动** |
| 零回归 | ✅ 867/867 测试通过 |
| **发现缺陷** | ⚠️ **1 个**（`mod_check_one.lua` 删除产物 `r1.grp`）→ 已修复 + 回归测试 |

---

## 2. `diff.md` 逐条审计（REQ-SWEEV-1）

### 2.1 MOD 独有（14 项）

| # | 文件 | 判定 | 引擎行为 |
|---|------|------|---------|
| 1 | `cloud.grp` | 预期 | `CC.CloudPicFile` → MOD |
| 2 | `cloud.idx` | 预期 | 同上 |
| 3 | `dead.png` | 预期 | 死亡画面 |
| 4 | `end.png` | 预期 | 结束画面 |
| 5 | `kdef.grp` | 预期 | 事件脚本（1018 个） |
| 6 | `kdef.idx` | 预期 | 同上 |
| 7 | `kysmod.ini` | 预期（`BUILD_INPUT`） | 构建期解析为 `CONFIG`/`CC` 覆盖，**不进产物** |
| 8 | `open.png` | 预期 | 开场画面 |
| 9 | `ranger.str` | 预期 | 构建期生成的 UTF-8 旁路表（`REQUIRED_CONVERTED`） |
| 10 | `talk.grp` | 预期 | 对话表（2977 条） |
| 11 | `talk.idx` | 预期 | 同上 |
| 12 | `title.grp` | 预期 | 标题画面 |
| 13 | `title.idx` | 预期 | 同上 |
| 14 | `修改档说明.txt` | 死文件（`LEGACY`） | 作者说明文档，引擎不读 |

**结论**：14 项全部有判定，**0 项需修复**。

> **注**：`kysmod.ini` 与 `修改档说明.txt` 出现在 `diff.md`（因为它比对 `data/` 目录）
> 但**不在产物中**。这正是 Slice 0c 指出的 `diff.md` 盲区 —— 穷举审计（§4）才是权威。

### 2.2 基准独有（23 项，REQ-SWEEV-2）

逐项用**运行时事实**定性（非笼统归为「回退原版」）：

| # | 文件 | 性质 | 运行时证据 |
|---|------|------|-----------|
| 1 | `alldef.idx` | **死文件** | 引擎无引用 |
| 2 | `allsin.idx` | **死文件** | 引擎无引用 |
| 3 | `allsinbk.grp` | **死文件** | `CC.TempS_Filename = data/allsinbk.grp`，但 `LoadSMap` 形参 `tmpfilename` 0 引用 |
| 4 | `d1.grp` | **在 save/** | `CC.D_Filename[1] = mods/SweeOan/save/d1.grp` ✅ |
| 5 | `d1.idx` | 回退原版 | 引擎无 `D_IDXFilename` |
| 6-9 | `d2/d3.grp/idx` | 回退原版 | 槽位 2/3 未提供，回退 |
| 10 | `r1.grp` | **在 save/** | `CC.R_GRPFilename[1] = mods/SweeOan/save/r1.grp` ✅ |
| 11 | `r1.idx` | **在 save/** | `CC.R_IDXFilename[1] = mods/SweeOan/save/r1.idx` ✅ |
| 12-15 | `r2/r3.grp/idx` | 回退原版 | 槽位 2/3 未提供 |
| 16 | `s1.grp` | **在 save/** | `CC.S_Filename[1] = mods/SweeOan/save/s1.grp` ✅ |
| 17 | `s1.idx` | 回退原版 | 引擎无 `S_IDXFilename` |
| 18-21 | `s2/s3.grp/idx` | 回退原版 | 槽位 2/3 未提供 |
| 22 | `thing.grp` | 回退原版 | `CC.ThingPicFile[1] = data/thing.idx` ✅（0/20 MOD 提供） |
| 23 | `thing.idx` | 回退原版 | 同上 |

**结论**：23 项全部定性，**0 项未解释**。

**三类性质的运行时证据**：

```
CC.R_IDXFilename[1] = mods/SweeOan/save/r1.idx     ← MOD 槽位
CC.R_GRPFilename[1] = mods/SweeOan/save/r1.grp     ← MOD 槽位
CC.D_Filename[1]    = mods/SweeOan/save/d1.grp     ← MOD 槽位
CC.S_Filename[1]    = mods/SweeOan/save/s1.grp     ← MOD 槽位
CC.TempS_Filename   = data/allsinbk.grp            ← 死文件（0 引用）
CC.ThingPicFile[1]  = data/thing.idx               ← 回退原版
```

### 2.3 结构对比（与 pascal 基线）

| 格式 | SweeOan | pascal | 判定 |
|------|--------:|-------:|------|
| `hdgrp` | 115 项 / 249276 B | 115 / 249276 | **同形** |
| `eft` | 714 / 691627 | 714 / 691627 | **同形** |
| `warfld` | 26 / 532480 | 26 / 532480 | **同形** |
| `cloud` | 9 / 38120 | 9 / 38120 | **同形** |
| `title` | 9 / 8179 | 9 / 8179 | **同形** |
| `kdef` | 1018 / 121214 | 1018 / 121214 | **同形** |
| `talk` | 2977 / 151382 | 2977 / 186513 | 条目同形，内容不同（预期） |
| fight | 92 | 92 | **同形** |

---

## 3. MOD 独有内容验证（REQ-SWEEV-3）

用**非基线值**证明加载来自 MOD（而非静默回退）：

| 判据 | SweeOan | pascal 基线 | 区分度 |
|------|---------|------------|--------|
| 主角姓名 | **王小石** | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | **衛悲回** | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | **伊小深** | （不同） | ✅ |
| 对话条目数 | 2977 | 2977 | ❌（同数，不可作证据） |
| 事件脚本数 | 1018 | 1018 | ❌（同数） |

**资源路径**：
```
CC.MMAPPicFile[1] = mods/SweeOan/data/mmap.idx
CC.SMAPPicFile[1] = mods/SweeOan/data/smap.idx
CC.WMAPPicFile[1] = mods/SweeOan/data/wmap.idx
CC.TalkGrpFile    = mods/SweeOan/script/oldtalk.grp
CC.WarFile        = mods/SweeOan/data/war.sta
```

**结论**：人物姓名有区分度，证明 MOD 数据确实被加载。对话/事件条目数与基线相同，
因此**不作为证据**（见 `design.md` ADR-002）。

---

## 4. 穷举审计（Slice 0c 工具链）

```
$ cd game && lua tools/mod_audit.lua --mod SweeOan
total=334 in_product=302 not_in_product=32 unclassified=0 bad_evidence=0
  REQUIRED             298
  REQUIRED_CONVERTED   4
  LEGACY               4
  BUILD_INPUT          1
  PENDING              27
```

**32 个未进产物文件**（全部有类别 + 证据）：

| 类别 | 数 | 文件 |
|------|--:|------|
| `PENDING` | 27 | `music/1.mid` … `music/23.mid` |
| `PENDING` | 4 | `list/{effect,leave,levelup,match}.bin` |
| `LEGACY` | 2 | `list/{end,start}.txt` |
| `LEGACY` | 1 | `script/1.lua` |
| `LEGACY` | 1 | `resource/修改档说明.txt` |
| `BUILD_INPUT` | 1 | `kysmod.ini` |

**「必需但未进产物」矛盾数 = 0** ✅

```
$ cd game && lua tools/format_spec.lua --mod SweeOan
formats=12 checked=196 gaps=0
```

---

## 5. 发现的缺陷（REQ-SWEEV-6）

### 5.1 缺陷：`mod_check_one.lua` 删除产物 `r1.grp`

**现象**：审计报告 `save/r1.grp` 为 `REQUIRED` 但不在产物中，且**同一次构建内**
（07:48）文件存在、一分钟后（07:49）消失。

**根因**：`game/tools/mod_check_one.lua` 的存档自检直接操作**真实产物目录**
`mods/<slug>/save/`：

```lua
-- 修复前
os.remove(dir .. "r1.grp"); os.remove(dir .. "r1.idx"); os.remove(dir .. "r1.ovr")
SaveRecord(1)
...
os.remove(dir .. "r1.grp"); os.remove(dir .. "r1.idx"); os.remove(dir .. "r1.ovr")
```

它先删除 MOD 自带的 `r1.grp`，写入测试存档，**再删除测试存档** —— 结果 MOD 自带的
`r1.grp` 被**永久销毁**。

**影响面**：`mod_check.lua` 对**全部 20 个 MOD** 逐个调用 `mod_check_one.lua`，
因此**每个 MOD 的 `r1.grp` 都会被删除**。这是数据销毁级缺陷。

**证据（mingdong）**：
```
源  reference/allmods/kys-mingdong/save/r1.grp = 222888 B
产物（损坏）game/mods/mingdong/save/r1.grp   = 223688 B   ← SaveRecord(1) 覆盖
残留 game/mods/mingdong/save/r1.idx / r1.ovr  ← 测试存档残留
```

**修复**：自检前**备份**产物目录的槽文件，自检后**字节级恢复**（无论自检成败）。

**验证**：
```
build:      222888 B   (与源一致)
after check: 222888 B   (未被破坏)
无 r1.idx/r1.ovr 残留 ✓
```

**回归测试**（`game/tests/unit/test_mod_resources.lua`）：
- `testCheckOneDoesNotDeleteProductSaves`：断言工具有备份 + 恢复逻辑
- `testProductSaveSlotMatchesSource`：断言全部 MOD 的产物 `r1.grp` 与源**逐字节相同**
  （实测 17 个 MOD 有 `r1.grp`，全部一致）

**为何 Slice 0c 之前未发现**：旧 DoD 只比对 `data/` 目录，`save/` 是盲区。
这是 Slice 0c「穷举驱动」DoD 的**首个实际战果**。

---

## 6. 零引擎改动（REQ-SWEEV-4）

本 slice 的改动**全部**在允许路径：

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/tools/mod_check_one.lua` | 修复数据销毁缺陷 | ✅ |
| `game/tests/unit/test_mod_resources.lua` | +2 回归测试 | ✅ |
| `game/mods/SweeOan/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice2/**` 等 | 文档 | ✅ |

**未触碰**：
- `game/engine-love2d/**` ✅
- `game/engine-mud/**` ✅
- `game/script/jyconst.lua` 常量定义 ✅
- `reference/allmods/**` ✅

---

## 7. 零回归

```
lua tests/test_runner.lua                        → 867/867 ✅
lua tools/mod_build.lua --verify-pascal          → events=1018, mismatches=0 ✅
lua tools/mod_build.lua --all                    → 20 mods, 0 build failures ✅
lua tools/mod_check.lua                          → 20 MOD, 通过 20, 失败 0 ✅
lua tools/mod_audit.lua --all                    → total=11220 unclassified=0 ✅
lua tools/format_spec.lua --all                  → formats=12 checked=6773 gaps=0 ✅
```

---

## 8. 结论

**PASS**。SweeOan 与基线完全同形，**零引擎改动**即通过全部验证。

本 slice 的核心价值是**发现并修复了 `mod_check_one.lua` 的数据销毁缺陷**：
该工具会删除每个 MOD 产物的 `r1.grp`，影响全部 20 个 MOD。
这直接印证了 Slice 0c 把 DoD 从「抽样驱动」改为「穷举驱动」的必要性 ——
旧 DoD 的 `data/` 目录比对**永远不会**看到 `save/` 下的这个问题。

**对后续 MOD 的影响**：第 1 梯队其余 2 个（`stronger`、`lostbook`）与基线同形，
可预期同样零改动通过。但**不应预设**——每个 MOD 仍须跑完整的穷举审计 + 启动链路验证。
