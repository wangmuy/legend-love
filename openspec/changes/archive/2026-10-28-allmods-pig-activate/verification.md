# Verification: allmods-pig-activate

> Change: `allmods-pig-activate` · Slice: `allmods-slice7` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**
> 结论：**PASS**（零缺陷；`hdgrp` 判据第 3 次应用成功）

## 1. 目标回顾

把「小猪闯江湖」（kys-pig）接入 MOD 兼容地基 —— **第 3 梯队第 1 个**。
它是本 epic **额外战斗最多**的 MOD（+45），含 **9 个**源自带存档。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-PIG-1 | 构建成功 | `data files=311, saves=21, sound=78, events=1288, talk=4123` | ✅ |
| REQ-PIG-2 | 逐文件穷举归类 | `total=440 unclassified=0`；矛盾 = 0 | ✅ |
| REQ-PIG-3 | 字节级覆盖 | `formats=12 checked=241 gaps=0` | ✅ |
| REQ-PIG-4 | `hdgrp` 差异验证 | 692 字节 = 173 条目；索引驱动；内容差异 | ✅ |
| REQ-PIG-5 | 45 场额外战斗 | 三重确认通过；产物 `fight*.grp` = 137 | ✅ |
| REQ-PIG-6 | 真实启动链路 | `RESULT pig: OK`（16 项断言） | ✅ |
| REQ-PIG-7 | 存档验证 | 21 个文件与源一致（含 `mod_check` 与全量测试后） | ✅ |
| REQ-PIG-8 | 零回归 | 1612/1612；全部门禁通过；341 save 文件完好 | ✅ |

## 3. 实测证据

### 3.1 构建（REQ-PIG-1）

```bash
cd game && lua tools/mod_build.lua kys-pig
```
```
[mod_build] kys-pig: data files=311, saves=21, sound=78, events=1288, talk=4123
[mod_build] diff -> tools/../mods/pig/diff.md
```

### 3.2 逐文件穷举（REQ-PIG-2）

```
$ cd game && lua tools/mod_audit.lua --mod pig
total=440 in_product=410 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             405
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
```
`Σ = 405+4+3+1+27 = 440` ✅ · **矛盾 = 0** ✅

### 3.3 字节级覆盖（REQ-PIG-3）

```
$ cd game && lua tools/format_spec.lua --mod pig
formats=12 checked=241 gaps=0
```

### 3.4 `hdgrp` 差异验证（REQ-PIG-4）—— 判据第 3 次应用

| 检查 | 实测 |
|------|------|
| `hdgrp.idx` 大小 | 692 字节 = **173** × 4 |
| pascal `hdgrp.idx` | 115 条目 |
| `CC.HeadPicFile[1]` | `mods/pig/data/hdgrp.idx` |
| 索引驱动 | `PicLoadFile` 用 `local num = idxlen/4`（`lib_love.lua:437`） |
| 固定计数常量 | `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全 `nil` |
| 字节全覆盖 | `formats=12 checked=241 gaps=0` |

**结论**：`hdgrp` 173 为**内容差异**，**零引擎改动**。

**判据应用记录**：
| 应用 | MOD | hdgrp | 结论 |
|------|-----|------:|------|
| 建立 | HeavenSword | 125 | 内容差异 |
| 外推 | GodsDevils | 129 | 内容差异 |
| **第 3 次** | **pig** | **173** | **内容差异** ✅ |

→ 判据在 3 个 MOD（125/129/173）上结论一致，可继续外推到第 4~5 梯队。

### 3.5 45 场额外战斗三重确认（REQ-PIG-5）

**额外战斗编号（45 个）**：
```
030 039 040 110 115 116 117 118 119 120 121 125 126 128 129 130 131
133 134 135 136 137 138 139 140 141 142 143 144 145 146 152 153 154
155 156 157 158 159 160 161 162 167 169 170
```

**抽样 5 场（首/中/尾）三重确认**：
```
fight030: diff提及=2 产物=yes 审计=REQUIRED	true
fight039: diff提及=2 产物=yes 审计=REQUIRED	true
fight137: diff提及=2 产物=yes 审计=REQUIRED	true
fight145: diff提及=2 产物=yes 审计=REQUIRED	true
fight170: diff提及=2 产物=yes 审计=REQUIRED	true
```

**产物总数**：
```
$ ls game/mods/pig/data/fight*.grp | wc -l
137        (= pascal 92 + 45) ✅
```

**三重证据**：
| # | 证据 | 结果 |
|---|------|------|
| 1 | `diff.md` 提及 | 45 项，各 2 次 |
| 2 | 产物存在 | 137 个 `fight*.grp` |
| 3 | 审计归类 | `REQUIRED` + `in_product=true` |

→ 验证了引擎 `fightNNN` **索引驱动**加载（无需固定数量常量）。

### 3.6 产物四项检查

```
PERSON=320  THING=200  SCENE=84  WUGONG=93
HERO=小小豬
STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.7 真实启动链路（REQ-PIG-6）

```
[PASS] CC.PersonSize=182 / CC.ThingSize=190 / CC.SceneSize=52 / CC.WugongSize=136
[PASS] PersonNum=320 / ThingNum=200 / SceneNum=84 / WugongNum=93
[PASS] 主角姓名 (期望 小小豬, 实际 小小豬)
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错
RESULT pig: OK
```

### 3.8 存档验证（REQ-PIG-7）

运行时路径：
```
CC.D_Filename[1]    = mods/pig/save/d1.grp
CC.R_GRPFilename[1] = mods/pig/save/r1.grp
CC.S_Filename[1]    = mods/pig/save/s1.grp
CC.TempS_Filename   = data/allsinbk.grp          ← 死文件（回退原版）
CC.HeadPicFile[1]   = mods/pig/data/hdgrp.idx
```

产物 21 个 save 文件与源**逐字节一致**（含 `mod_check` 与**全量测试后**）：
```
d11.grp  d1.grp  d2.grp  d3.grp  d4.grp  d5.grp  d6.grp
r11.grp  r1.grp  r2.grp  r3.grp  r4.grp  r5.grp  r6.grp
s11.grp  s1.grp  s2.grp  s3.grp  s4.grp  s5.grp  s6.grp
```

**全 MOD save 完整性（全量测试后）**：检查 **341** 个文件，`不一致 = 0` ✅

**意义**：pig 源自带 **9 个槽**（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`），
比 Slice 6 的 GodsDevils（6 个）更多。若 Slice 5 的 `SLOTS` 修复只补了 `d1`/`s1`，
本 MOD 的 `d2`/`d3`/`r2`/`r3`/`s2`/`s3` 会暴露 —— **修复完整性验证通过**。

## 4. MOD 独有内容验证

| 判据 | pig | pascal 基线 | 区分度 |
|------|-----|------------|--------|
| 主角姓名 | **小小豬** | 小蝦米 | ✅ |
| `JY.Person[1]` | **胡斐**/雪山飛狐 | （不同） | ✅ |
| `JY.Person[2]` | **程靈素**/毒手藥王 | （不同） | ✅ |
| 对话条目数 | **4123** | 2977 | ✅ |
| 事件脚本数 | **1288** | 1018 | ✅ |
| `hdgrp` 条目数 | **173** | 115 | ✅ |
| 战斗数 | **137** | 92 | ✅ |

## 5. 零引擎改动（REQ-PIG-8）

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/mods/pig/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice7/**` 等 | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**本 change 零代码改动**（纯构建 + 验证）。

## 6. 零回归

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **1612/1612** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0 bad_evidence=0` ✅ |
| `mod_audit --all --evidence` | `checked=17 failed=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |
| 全量测试后全 MOD save/ | 341 文件，**不一致 = 0** ✅ |

## 7. 产物清单

| 文件 | 说明 |
|------|------|
| `game/mods/pig/**` | 构建产物 |
| `game/mods/pig/diff.md` | 数据差异报告 |

## 8. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/mods/pig/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice7/**` 等 | 文档 | ✅ |

## 9. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| `hdgrp` 173 vs 115 | MOD 内容更多 | 内容差异（索引驱动，零改动） |
| kdef 1288 vs 1018 | MOD 事件更多 | 内容差异 |
| **fight 137 vs 92** | **+45 额外战斗** | 内容差异（索引驱动） |
| talk 4123 vs 2977 | MOD 对话更多 | 内容差异 |
| 9 个源自带存档 | 比第 2 梯队更多 | 缺陷 D 修复完整性检验 |

## 10. 结论

**PASS**。REQ-PIG-1~8 全部满足。pig 与基线**结构同形**（`hdgrp`/kdef/fight/talk 更多），
**零引擎改动、零代码改动**通过全部验证。

**本 change 的关键产出**：
1. **`hdgrp` 判据第 3 次应用成功** —— 3 个 MOD（125/129/173）结论一致。
2. **45 场额外战斗三重确认** —— `diff.md` + 产物 + 审计，验证了 `fightNNN` 索引驱动加载。
3. **缺陷 D 修复完整性验证** —— 9 个源自带存档（含 `d2`/`d3`/`r2`/`r3`/`s2`/`s3`）完好。

**本 slice 零缺陷**（累计工具缺陷仍为 4 个）。

**第 3 梯队进度**：pig（Slice 7）✅ → lyff → ptt。
