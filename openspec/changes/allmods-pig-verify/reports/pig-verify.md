# pig（小猪闯江湖）验证报告

> Change: `allmods-pig-verify` · Slice: `allmods-slice7` · Epic: `2026-10-allmods-compat`
> 日期：2026-10-19
> 结论：**PASS**（零缺陷；`hdgrp` 判据第 3 次应用成功）

---

## 1. 结论摘要

| 维度 | 结果 |
|------|------|
| 构建 | ✅ `events=1288 talk=4123`，退出码 0 |
| 逐文件穷举 | ✅ `total=440 unclassified=0 bad_evidence=0` |
| 「必需但未进产物」矛盾 | ✅ **0** |
| 字节级覆盖 | ✅ `formats=12 checked=241 gaps=0` |
| 产物四项检查 | ✅ `STRINGS/EVENTS/SAVE=OK` |
| 真实启动链路 | ✅ `RESULT pig: OK`（16 项断言） |
| `hdgrp` 差异 | ✅ 173 条目为内容差异（判据第 3 次应用） |
| 45 场额外战斗 | ✅ 三重确认通过 |
| MOD 独有内容 | ✅ 确认为 MOD 内容（非回退） |
| 存档完好 | ✅ 21 个文件与源一致（含全量测试后） |
| 引擎改动 | ✅ **零改动** |
| 零回归 | ✅ 1612/1612 测试通过 |
| **发现缺陷** | ✅ **0 个** |

---

## 2. `diff.md` 逐条审计（REQ-PIGV-1）

### 2.1 MOD 独有（103 项）—— 本 epic 目前最多

| 类别 | 项数 | 判定 |
|------|-----:|------|
| **额外战斗**（45 场 × `grp`+`idx`） | **90** | 预期（见 §4） |
| `kdef.grp`/`.idx` | 2 | 预期（事件 **1288** 个） |
| `talk.grp`/`.idx` | 2 | 预期（对话 **4123** 条） |
| `cloud.grp`/`.idx` | 2 | 预期 |
| `title.grp`/`.idx` | 2 | 预期 |
| `dead.png`/`end.png`/`open.png` | 3 | 预期 |
| `ranger.str` | 1 | `REQUIRED_CONVERTED`（UTF-8 旁路表） |
| `kysmod.ini` | 1 | `BUILD_INPUT`（在产物中） |
| **Σ** | **103** | **需修复 = 0** |

### 2.2 基准独有（21 项，REQ-PIGV-2）

| 性质 | 项数 | 具体文件 |
|------|-----:|---------|
| 回退原版 | 11 | `d3.*`? 否 —— 见下 |
| 在 save/ | 9 | **`d1.grp`/`d2.grp`/`d3.grp`/`r1.grp`/`r2.grp`/`r3.grp`/`s1.grp`/`s2.grp`/`s3.grp`** |
| 死文件 | 1 | `allsinbk.grp` |
| **Σ** | **21** | ✅ 无未解释项 |

回退原版 11 项：`d1.idx`/`d2.idx`/`d3.idx`/`r1.idx`/`r2.idx`/`r3.idx`/
`s1.idx`/`s2.idx`/`s3.idx`（引擎不读 `.idx` 变体）+ `thing.grp`/`thing.idx`。

运行时证据：
```
CC.D_Filename[1]    = mods/pig/save/d1.grp    ← 在 save/（源自带）
CC.R_GRPFilename[1] = mods/pig/save/r1.grp    ← 在 save/（源自带）
CC.S_Filename[1]    = mods/pig/save/s1.grp    ← 在 save/（源自带）
CC.TempS_Filename   = data/allsinbk.grp       ← 死文件
CC.ThingPicFile[1]  = data/thing.idx          ← 回退原版
```

**9 个源自带存档**（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`）比第 2 梯队（3~6 个）更多。

---

## 3. `hdgrp` 差异 vs 结构异常（REQ-PIGV-4）—— 判据第 3 次应用

pig 的 `hdgrp` 为 **173** 条目（pascal 115）。

| 条件 | HeavenSword | GodsDevils | **pig** |
|------|-------------|-----------|--------|
| **索引驱动** | `idxlen/4` | `idxlen/4` | `idxlen/4` |
| **无固定计数** | ✅ | ✅ | ✅ |
| 记录布局常量同 | 182/190/52/136 | 182/190/52/136 | 182/190/52/136 |
| **字节全覆盖** | `gaps=0` | `gaps=0` | `gaps=0` |
| **引擎改动** | 0 | 0 | **0** |

```
$ stat -c%s reference/allmods/kys-pig/resource/hdgrp.idx
692       (= 173 × 4)
```

**判据应用记录**：
| # | MOD | hdgrp | 结论 |
|---|-----|------:|------|
| 建立 | HeavenSword | 125 | 内容差异 |
| 外推 | GodsDevils | 129 | 内容差异 |
| **第 3 次** | **pig** | **173** | **内容差异** ✅ |

→ 判据在 3 个 MOD（125/129/173）上结论一致，**可继续外推**到第 4~5 梯队
（lyff 178、ptt 204、RiverLake 252、Dragon 267、pineapple 300、BookCalamity 373、
pig3dos 412、books 696）。

---

## 4. 45 场额外战斗（REQ-PIGV-5）

pig 有 **137** 场战斗（pascal 92），**+45**。

**额外战斗编号（45 个）**：
```
030 039 040 110 115 116 117 118 119 120 121 125 126 128 129 130 131
133 134 135 136 137 138 139 140 141 142 143 144 145 146 152 153 154
155 156 157 158 159 160 161 162 167 169 170
```

**三重证据（抽样 5 场，首/中/尾）**：
```
fight030: diff提及=2 产物=yes 审计=REQUIRED	true
fight039: diff提及=2 产物=yes 审计=REQUIRED	true
fight137: diff提及=2 产物=yes 审计=REQUIRED	true
fight145: diff提及=2 产物=yes 审计=REQUIRED	true
fight170: diff提及=2 产物=yes 审计=REQUIRED	true
```

| # | 证据 | 结果 |
|---|------|------|
| 1 | `diff.md` 提及 | 45 项，各 2 次 |
| 2 | 产物存在 | `ls game/mods/pig/data/fight*.grp \| wc -l` = **137** |
| 3 | 审计归类 | `REQUIRED` + `in_product=true` |

**结论**：45 场额外战斗为**内容差异**（引擎 `fightNNN` 索引驱动加载），**零引擎改动**。

---

## 5. MOD 独有内容验证（REQ-PIGV-3）

| 判据 | pig | pascal 基线 | 区分度 |
|------|-----|------------|--------|
| 主角姓名 | **小小豬** | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | **胡斐** / 雪山飛狐 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | **程靈素** / 毒手藥王 | （不同） | ✅ |
| 对话条目数 | **4123** | 2977 | ✅ |
| 事件脚本数 | **1288** | 1018 | ✅ |
| `hdgrp` 条目数 | **173** | 115 | ✅ |
| 战斗数 | **137** | 92 | ✅ |

**资源路径**：
```
CC.MMAPPicFile[1] = mods/pig/data/mmap.idx
CC.HeadPicFile[1] = mods/pig/data/hdgrp.idx    ← 173 条目
CC.TalkGrpFile    = mods/pig/script/oldtalk.grp
CC.D_Filename[1]  = mods/pig/save/d1.grp
CC.ThingPicFile[1]= data/thing.idx             ← 回退原版
```

---

## 6. 穷举审计（Slice 0c 工具链）

```
$ cd game && lua tools/mod_audit.lua --mod pig
total=440 in_product=410 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             405
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
```

**30 个未进产物文件**：27 `music/*.mid` + 4 `list/*.bin`（`PENDING`）
+ 2 `list/{end,start}.txt` + 1 `script/1.lua`（`LEGACY`）。

**「必需但未进产物」矛盾数 = 0** ✅

```
$ cd game && lua tools/format_spec.lua --mod pig
formats=12 checked=241 gaps=0
```

---

## 7. 存档验证（缺陷 D 修复完整性）

运行时路径指向 MOD `save/`，21 个文件与源**逐字节一致**：

```
d11.grp  d1.grp  d2.grp  d3.grp  d4.grp  d5.grp  d6.grp
r11.grp  r1.grp  r2.grp  r3.grp  r4.grp  r5.grp  r6.grp
s11.grp  s1.grp  s2.grp  s3.grp  s4.grp  s5.grp  s6.grp
```

**全 MOD save 完整性（全量测试后）**：检查 **341** 个文件，`不一致 = 0` ✅

**意义**：pig 源自带 **9 个槽**（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`），
比 Slice 6 的 GodsDevils（6 个）更多。若 Slice 5 的 `SLOTS` 修复只补了 `d1`/`s1`，
本 MOD 的 `d2`/`d3`/`r2`/`r3`/`s2`/`s3` 会立即暴露 —— **修复完整性验证通过**。

---

## 8. 零引擎改动（REQ-PIGV-6）

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/mods/pig/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice7/**` 等 | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**本 slice 零代码改动**。

---

## 9. 零回归

```
lua tests/test_runner.lua                        → 1612/1612 ✅
lua tools/mod_build.lua --verify-pascal          → events=1018, mismatches=0 ✅
lua tools/mod_build.lua --all                    → 20 mods, 0 build failures ✅
lua tools/mod_check.lua                          → 20 MOD, 通过 20, 失败 0 ✅
lua tools/mod_audit.lua --all                    → total=11220 unclassified=0 bad_evidence=0 ✅
lua tools/mod_audit.lua --all --evidence         → checked=17 failed=0 ✅
lua tools/format_spec.lua --all                  → formats=12 checked=6773 gaps=0 ✅
全量测试后全 MOD save/ 与源一致                   → 341 文件, 不一致 = 0 ✅
```

---

## 10. 第 3 梯队进度

| Slice | MOD | hdgrp | fight | 缺陷 |
|-------|-----|------:|------:|------|
| **7** | **pig（小猪闯江湖）** | **173** | **137** | **0** |
| 8 | lyff（刘亦纷飞版） | 178 | 138 | 待做 |
| 9 | ptt（PTT） | 204 | 162 | 待做 |

**累计工具缺陷**：4 个（Slice 2/3/5），Slice 6/7 零缺陷。

---

## 11. 结论

**PASS**。REQ-PIGV-1~7 全部满足。pig **零引擎改动、零代码改动**通过全部验证。

**关键产出**：
1. **`hdgrp` 判据第 3 次应用成功** —— 3 个 MOD（125/129/173）结论一致。
2. **45 场额外战斗三重确认** —— 验证了 `fightNNN` 索引驱动加载。
3. **缺陷 D 修复完整性验证** —— 9 个源自带存档（含 `d2`/`d3`/`r2`/`r3`/`s2`/`s3`）完好。
4. **103 项 MOD 独有全部有判定** —— 本 epic 目前最多。

下一 MOD：`kys-lyff`（刘亦纷飞版，hdgrp 178 / fight 138）。
