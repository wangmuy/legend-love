# HeavenSword（倚天剑）验证报告

> Change: `allmods-heavensword-verify` · Slice: `allmods-slice5` · Epic: `2026-10-allmods-compat`
> 日期：2026-10-19
> 结论：**PASS**（发现并修复**第 4 个工具缺陷**：`mod_check_one` 未备份 `d1.grp`/`s1.grp`）

---

## 1. 结论摘要

| 维度 | 结果 |
|------|------|
| 构建 | ✅ `events=1066 talk=3315`，退出码 0 |
| 逐文件穷举 | ✅ `total=335 unclassified=0 bad_evidence=0` |
| 「必需但未进产物」矛盾 | ✅ **0** |
| 字节级覆盖 | ✅ `formats=12 checked=197 gaps=0` |
| 产物四项检查 | ✅ `STRINGS/EVENTS/SAVE=OK` |
| 真实启动链路 | ✅ `RESULT HeavenSword: OK`（16 项断言） |
| `hdgrp` 差异 | ✅ 125 条目为内容差异（索引驱动） |
| MOD 独有内容 | ✅ 确认为 MOD 内容（非回退） |
| 引擎改动 | ✅ **零改动** |
| 零回归 | ✅ 1612/1612 测试通过 |
| **发现缺陷** | ⚠️ **1 个** → 已修复 + 回归测试强化 |

---

## 2. `diff.md` 逐条审计（REQ-HSV-1）

### 2.1 MOD 独有（15 项）

| # | 文件 | 判定 | 引擎行为 |
|---|------|------|---------|
| 1-2 | `cloud.grp`/`.idx` | 预期 | `CC.CloudPicFile` → MOD |
| 3 | `dead.png` | 预期 | 死亡画面 |
| 4 | `end.png` | 预期 | 结束画面 |
| 5-6 | **`fight073.grp`/`.idx`** | 预期 | **额外 1 场战斗** |
| 7-8 | `kdef.grp`/`.idx` | 预期 | 事件脚本（**1066** 个） |
| 9 | `kysmod.ini` | `BUILD_INPUT`（在产物中） | 构建器复制到 `data/` |
| 10 | `open.png` | 预期 | 开场画面 |
| 11 | `ranger.str` | `REQUIRED_CONVERTED` | UTF-8 旁路表 |
| 12-13 | `talk.grp`/`.idx` | 预期 | 对话表（**3315** 条） |
| 14-15 | `title.grp`/`.idx` | 预期 | 标题画面 |

**结论**：15 项全部有判定，**0 项需修复**。

### 2.2 基准独有（21 项，REQ-HSV-2）

| 性质 | 项数 | 说明 |
|------|-----:|------|
| 回退原版（含首次存档时播种） | 19 | `d1/d2/d3`、`r1/r2/r3`、`s1/s2/s3` 的 `grp`+`idx` 中除 `r1.idx` 外，加 `thing.grp`/`.idx` |
| 在 save/ | 1 | **`r1.idx`** |
| 死文件 | 1 | `allsinbk.grp` |
| **Σ** | **21** | ✅ 无未解释项 |

运行时证据：
```
CC.D_Filename[1]    = mods/HeavenSword/save/d1.grp   ← 路径指向 save，但文件不存在 → 播种
CC.R_GRPFilename[1] = mods/HeavenSword/save/r1.grp   ← 同上
CC.S_Filename[1]    = mods/HeavenSword/save/s1.grp   ← 同上
CC.TempS_Filename   = data/allsinbk.grp              ← 死文件（0 引用）
CC.ThingPicFile[1]  = data/thing.idx                 ← 回退原版
```

**与第 1 梯队的差异**：HeavenSword 源自带存档包**不含** `d1.grp`/`s1.grp`
（第 1 梯队如 SweeOan/stronger 自带）。因此只有 `r1.idx` 归为「在 save/」，
`d1.grp`/`s1.grp` 归为「回退原版（首次存档时播种）」。

**`r1.idx` 的特殊性**：24 字节，与 `ranger.idx` **md5 相同**
（`3746f89bd755157160d7bc9575d8e2e4`）—— 它是模板索引的副本。

---

## 3. `hdgrp` 差异 vs 结构异常（REQ-HSV-4）

HeavenSword 是本 epic **第一个 `hdgrp` 条目数 ≠ 115 的 MOD**（**125**）。

**判定为「内容差异」的三重机器可验证判据**：

| 条件 | 实测 | 说明 |
|------|------|------|
| **索引驱动** | `lib_love.lua:437` `local num = idxlen/4` | 条目数由文件大小推导 |
| **无固定计数** | `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全 `nil` | 无硬编码 115 |
| 记录布局常量同 | `CC.PersonSize=182`/`ThingSize=190`/`SceneSize=52`/`WugongSize=136` | 与 pascal 一致 |
| 记录数同 | 320/200/84/93 | 与 pascal 一致 |
| **字节全覆盖** | `formats=12 checked=197 gaps=0` | 按 pascal 尺寸解析无错位 |

**关键源码证据**（`game/engine-love2d/lib_love.lua`）：
```lua
function PicLoadFile(idxfilename, grpfilename, fileid)
    ...
    local idxlen = FileLength(idxfilename)
    ...
    local num = idxlen/4          -- ← 条目数从文件大小推导，无固定常量
    pic_file.idx[1] = 0
    for i=1,num do
        local nextidx = Byte.byte2uintl(f:read(4):byte(1,4))
        ...
    end
```

**结论**：`hdgrp` 125 是**内容差异**（更多头像），引擎索引驱动加载天然支持，**零引擎改动**。

**外推价值**：第 2~5 梯队**全部** MOD 的 hdgrp ≠ 115（125~350+）。
此判据可复用于后续全部 MOD —— 只需跑 `format_spec` + 检查 `CC` 无固定计数常量。

---

## 4. MOD 独有内容验证（REQ-HSV-3）

| 判据 | HeavenSword | pascal 基线 | 区分度 |
|------|-------------|------------|--------|
| 主角姓名 | **楊千葉** | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | **胡斐** | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | **程靈素** | （不同） | ✅ |
| 对话条目数 | **3315** | 2977 | ✅ |
| 事件脚本数 | **1066** | 1018 | ✅ |
| `hdgrp` 条目数 | **125** | 115 | ✅ |

**资源路径**：
```
CC.MMAPPicFile[1] = mods/HeavenSword/data/mmap.idx
CC.HeadPicFile[1] = mods/HeavenSword/data/hdgrp.idx    ← 125 条目
CC.TalkGrpFile    = mods/HeavenSword/script/oldtalk.grp
CC.WarFile        = mods/HeavenSword/data/war.sta
CC.ThingPicFile[1]= data/thing.idx                     ← 回退原版
```

---

## 5. 缺陷 D：`mod_check_one` 未备份 `d1.grp`/`s1.grp`

### 5.1 现象

全量重建后运行 `mod_check`，**20 个 MOD 的 `d1.grp`/`s1.grp` 全部被改变**：

```
$ cmp -l reference/allmods/kys-pascal/save/d1.grp game/mods/pascal/save/d1.grp | wc -l
2892
$ cmp -l reference/allmods/kys-mingdong/save/d1.grp game/mods/mingdong/save/d1.grp | wc -l
6067
$ cmp -l reference/allmods/kys-SweeOan/save/d1.grp game/mods/SweeOan/save/d1.grp | wc -l
88
```

时间戳证实发生在测试运行期间（产物构建 `00:04`，被改 `00:10`）。

### 5.2 根因

`game/tools/mod_check_one.lua`：
```lua
local SLOTS = { "r1.grp", "r1.idx", "r1.ovr" }   -- ← 只有 r1.*
...
SaveRecord(1)                                     -- ← 还写 d1.grp / s1.grp
```

`SaveRecord(1)` 除写 `r1.*` 外，还触发 `SaveMMap`/`SaveSMap` 写**存档槽 1 的地图/场景数据**
（`d1.grp`/`s1.grp`）。`SLOTS` 未含它们 → **永不备份、永不恢复**。

**影响面**：`mod_check.lua` 对**全部 20 个 MOD** 调用 → 每次自检销毁 20 个 MOD 的 `d1.grp`/`s1.grp`。

**同源缺陷的第三次遗漏**：
| Slice | 修复对象 | 覆盖槽位 |
|-------|---------|---------|
| 2 | `mod_check_one.lua` | 仅 `r1.*` |
| 3 | `test_mod_boot.lua` | 仅 `r1.*`（SLOTS 含 d/s 但断言只看 r1） |
| **5** | `mod_check_one.lua` | **扩展为 `r1.*` + `d1.*` + `s1.*`** |

### 5.3 修复

```lua
-- 注意：SaveRecord(1) 除写 r1.* 外，还会写存档槽 1 的地图/场景数据
-- （d1.grp / s1.grp，由 SaveMMap/SaveSMap 触发），因此这些槽也必须
-- 备份并恢复，否则会销毁源自带的 d1.grp/s1.grp。
local SLOTS = { "r1.grp", "r1.idx", "r1.ovr", "d1.grp", "d1.idx", "s1.grp", "s1.idx" }
```

### 5.4 验证

```
=== 修复前基线 md5 ===
7b3f195fa18529eb9175dee577cf1730  pascal/save/d1.grp
ab90a4a5b40c420e54a8556a6eb691db  pascal/save/s1.grp
6a1ed19c4f2cf451ab4d57286b68d3c9  pascal/save/r1.grp

=== 运行 mod_check ===
总计: 20 MOD, 通过 20, 失败 0

=== 修复后 md5 ===
7b3f195fa18529eb9175dee577cf1730  pascal/save/d1.grp   ← 不变 ✅
ab90a4a5b40c420e54a8556a6eb691db  pascal/save/s1.grp   ← 不变 ✅
6a1ed19c4f2cf451ab4d57286b68d3c9  pascal/save/r1.grp   ← 不变 ✅

=== 全 MOD save/ 与源一致性 ===
不一致 = 0 ✅
```

### 5.5 回归测试强化

- `testCheckOneDoesNotDeleteProductSaves`：新增断言 `SLOTS` 必须含
  `r1.grp`/`r1.idx`/`r1.ovr`/`d1.grp`/`s1.grp`
- `testProductSaveSlotMatchesSource`：从「只比对 `r1.grp`」扩展为**比对源 `save/` 全部文件**

**测试数**：958 → **1612**（+654 个文件级断言）

---

## 6. 穷举审计（Slice 0c 工具链）

```
$ cd game && lua tools/mod_audit.lua --mod HeavenSword
total=335 in_product=305 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             300
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
```

**30 个未进产物文件**：27 `music/*.mid` + 4 `list/*.bin`（`PENDING`）
+ 2 `list/{end,start}.txt` + 1 `script/1.lua`（`LEGACY`）。

**「必需但未进产物」矛盾数 = 0** ✅

```
$ cd game && lua tools/format_spec.lua --mod HeavenSword
formats=12 checked=197 gaps=0
```

---

## 7. 零引擎改动（REQ-HSV-5）

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/tools/mod_check_one.lua` | 缺陷 D 修复 | ✅ |
| `game/tests/unit/test_mod_resources.lua` | 断言强化 | ✅ |
| `game/mods/HeavenSword/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice5/**` 等 | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

---

## 8. 零回归

```
lua tests/test_runner.lua                        → 1612/1612 ✅
lua tools/mod_build.lua --verify-pascal          → events=1018, mismatches=0 ✅
lua tools/mod_build.lua --all                    → 20 mods, 0 build failures ✅
lua tools/mod_check.lua                          → 20 MOD, 通过 20, 失败 0 ✅
lua tools/mod_audit.lua --all                    → total=11220 unclassified=0 bad_evidence=0 ✅
lua tools/mod_audit.lua --all --evidence         → checked=17 failed=0 ✅
lua tools/format_spec.lua --all                  → formats=12 checked=6773 gaps=0 ✅
全量测试后全 MOD save/ 与源一致                   → 不一致 = 0 ✅
```

---

## 9. 累计工具缺陷（4 个）

| # | Slice | 缺陷 | 根因 |
|---|-------|------|------|
| 1 | 2 | `mod_check_one` 销毁 `r1.grp` | 自检直接 `os.remove` 真实产物目录 |
| 2 | 3 | `mod_audit` 对 `kysmod.ini` 的 `in_product` 误判 | 类别级一刀切 |
| 3 | 3 | `test_mod_boot` 销毁 `r1.grp` | 与 #1 同源 |
| 4 | **5** | **`mod_check_one` 销毁 `d1.grp`/`s1.grp`** | **#1 的第三次遗漏（`SLOTS` 只列 `r1.*`）** |

**教训**：修复「销毁产物」类缺陷时，必须枚举**全部**被写入的槽位，而非只修发现的那一个。
本次将回归测试强化为「比对源 `save/` **全部**文件」，以杜绝第四次遗漏。

---

## 10. 结论

**PASS**。REQ-HSV-1~6 全部满足。HeavenSword 与基线**结构同形**（`hdgrp` 等条目更多），
**零引擎改动**通过全部验证。

**本 change 的关键产出**：
1. **验证 `hdgrp` 差异无需引擎改动** —— 引擎索引驱动（`idxlen/4`），无固定计数常量。
   判据可外推到第 2~5 梯队**全部** hdgrp ≠ 115 的 MOD。
2. **发现并修复第 4 个工具缺陷** —— `mod_check_one` 的 `SLOTS` 遗漏 `d1.grp`/`s1.grp`。
   回归测试强化为「比对源 `save/` 全部文件」。

下一梯队继续：`kys-GodsDevils`（天龙八部，hdgrp 129 / fight 92，第 2 梯队最后 1 个）。
