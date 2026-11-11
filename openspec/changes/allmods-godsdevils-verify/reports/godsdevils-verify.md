# GodsDevils（天龙八部）验证报告

> Change: `allmods-godsdevils-verify` · Slice: `allmods-slice6` · Epic: `2026-10-allmods-compat`
> 日期：2026-10-21
> 结论：**PASS**（零缺陷；`hdgrp` 判据第二次外推成功；「基准独有」定性细化为 6/9/8）

---

## 1. 结论摘要

| 维度 | 结果 |
|------|------|
| 构建 | ✅ `events=1123 talk=4640`，退出码 0 |
| 逐文件穷举 | ✅ `total=615 unclassified=0 bad_evidence=0` |
| 「必需但未进产物」矛盾 | ✅ **0** |
| 字节级覆盖 | ✅ `formats=12 checked=475 gaps=0` |
| 产物四项检查 | ✅ `STRINGS/EVENTS/SAVE=OK` |
| 真实启动链路 | ✅ `RESULT GodsDevils: OK`（16 项断言） |
| `hdgrp` 差异 | ✅ 129 条目为内容差异（判据**第二次外推**成功） |
| 279 个 `EDITOR_DUMP` | ✅ 4 条机器可复核证据 |
| MOD 独有内容 | ✅ 确认为 MOD 内容（非基线值） |
| 第 3 种存档形态 | ✅ round-trip 通过（`r1.grp` 有、`r1.idx` 无） |
| 引擎改动 | ✅ **零改动** |
| 零回归 | ✅ 1612/1612 测试通过 |
| **发现缺陷** | ✅ **0 个**（累计工具缺陷仍为 4 个） |

---

## 2. `diff.md` 逐条审计（REQ-GDV-1/2）

### 2.1 MOD 独有（13 项）

| # | 文件 | 判定 | 引擎行为 |
|---|------|------|---------|
| 1-2 | `cloud.grp`/`.idx` | 预期 | `CC.CloudPicFile` → MOD |
| 3 | `dead.png` | 预期 | 死亡画面 |
| 4 | `end.png` | 预期 | 结束画面 |
| 5-6 | `kdef.grp`/`.idx` | 预期 | 事件脚本（**1123** 个） |
| 7 | `kysmod.ini` | `BUILD_INPUT`（在产物中） | 构建器复制到 `data/` |
| 8 | `open.png` | 预期 | 开场画面 |
| 9 | `ranger.str` | `REQUIRED_CONVERTED` | UTF-8 旁路表 |
| 10-11 | `talk.grp`/`.idx` | 预期 | 对话表（**4640** 条） |
| 12-13 | `title.grp`/`.idx` | 预期 | 标题画面 |

**结论**：13 项全部有判定，**0 项需修复**。**无额外战斗**——fight 92 == pascal 92
（同集合，与 HeavenSword 93 / lostbook 97 不同）。

### 2.2 基准独有（23 项，REQ-GDV-2）——细化定性 6/9/8

| 性质 | 项数 | 项 |
|------|-----:|----|
| 在 save/（源自带，产物逐字节一致） | 6 | `d1.grp`、`d2.grp`、`r1.grp`、`r2.grp`、`s1.grp`、`s2.grp` |
| 死文件（引擎无引用） | 9 | `alldef.idx`、`allsin.idx`、`allsinbk.grp`、**`d1.idx`、`d2.idx`、`d3.idx`、`s1.idx`、`s2.idx`、`s3.idx`** |
| 回退原版（含首次存档播种） | 8 | `r1.idx`、`r2.idx`、`r3.grp`、`r3.idx`、`s3.grp`、`d3.grp`、`thing.grp`、`thing.idx` |
| **Σ** | **23** | ✅ 无未解释项 |

**死文件判据（源码级）**：

| 项 | 证据 |
|----|------|
| `alldef.idx`/`allsin.idx` | 引擎只引用对应 `.grp`（`CC.D_Filename[0]=data/alldef.grp`、`CC.S_Filename[0]=data/allsin.grp`，`jyconst.lua:91-98`） |
| `allsinbk.grp`（save/ 副本） | 引擎临时场景文件是 `data/allsinbk.grp`（`CC.TempS_Filename`），非 save/ 副本 |
| **`d1/d2/d3.idx`、`s1/s2/s3.idx`** | **引擎无 S/D idx 常量**：`jyconst.lua:80`「S和D由于是固定大小，因此不再定义idx了」；全仓库 `grep "S_IDX\|D_IDX"` = 0 命中；`LoadRecord`/`SaveRecord` 只读写 `CC.R_IDXFilename` |

> **对粗分类的修正**：按「文件是否在产物」的粗粒度分类会把这 6 个 `d/s*.idx`
> 误归为「回退原版」。它们实际是 C 引擎时代遗留、Lua 引擎从不读的死文件。
> **可外推规则**：后续 MOD 的 `d/s*.idx` 一律判死文件。

**回退/播种项的运行时证据**：
```
CC.D_Filename[1]    = mods/GodsDevils/save/d1.grp   ← 源自带
CC.R_GRPFilename[1] = mods/GodsDevils/save/r1.grp   ← 源自带
CC.R_IDXFilename[1] = mods/GodsDevils/save/r1.idx   ← 源无；首次 SaveRecord(1) 播种（round-trip 验证）
CC.S_Filename[1]    = mods/GodsDevils/save/s1.grp   ← 源自带
CC.TempS_Filename   = data/allsinbk.grp             ← 引擎临时场景文件
CC.ThingPicFile[1]  = data/thing.idx                ← 回退原版
CC.HeadPicFile[1]   = mods/GodsDevils/data/hdgrp.idx
```
（存档槽重定向见 `framework/mod_data.lua:326-329`：`R_IDXFilename`/`R_GRPFilename`/
`S_Filename`/`D_Filename` 的索引 1..3 全部重定向到 `mods/GodsDevils/save/`。）

---

## 3. `hdgrp` 差异 vs 结构异常（REQ-GDV-4）——判据第二次外推

| 条件 | 实测 | 说明 |
|------|------|------|
| `hdgrp.idx` 大小 | 516 字节 = **129** × 4 | pascal 115 |
| `CC.HeadPicFile[1]` | `mods/GodsDevils/data/hdgrp.idx` | 指向 MOD |
| 索引驱动 | `lib_love.lua:437` `local num = idxlen/4` | 条目数由文件大小推导 |
| 固定计数常量 | `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全 `nil` | 无硬编码 |
| 记录布局常量同 | `CC.PersonSize=182`/`ThingSize=190`/`SceneSize=52`/`WugongSize=136` | 与 pascal 一致 |
| 字节全覆盖 | `formats=12 checked=475 gaps=0` | 按 pascal 尺寸解析无错位 |

**外推链**：HeavenSword（125，首次外推，Slice 5 ADR-001）→ **GodsDevils（129，
第二次）**——两次结果一致：内容差异、零引擎改动。第 3~5 梯队（hdgrp 173~350+）
可继续复用；若某 MOD 出现 `gaps≠0` 才需要重新分析。

---

## 4. MOD 独有内容验证（REQ-GDV-3）

| 判据 | GodsDevils | pascal 基线 | 区分度 |
|------|-----------|------------|--------|
| 主角姓名 | **蝦米** | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | **胡斐**/雪山飛狐 | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | **程靈素**/毒手藥王 | （不同） | ✅ |
| 对话条目数 | **4640** | 2977 | ✅ |
| 事件脚本数 | **1123** | 1018 | ✅ |
| `hdgrp` 条目数 | **129** | 115 | ✅ |
| fight 数 | 92 | 92 | ❌ **同数，不作为证据** |

**注意**：fight 92 == pascal 92（数量恰好相同）——按 ADR-003，**不得**以「记录数
相同」作为 MOD 内容已加载的证据；此处用主角姓名等非基线值证明。

---

## 5. 第 3 种存档形态（`r1.grp` 有、`r1.idx` 无）

GodsDevils 源自带 `save/` 13 个文件（含 `r1.grp` 但**无 `r1.idx`**），是继
「源自带完整 `r1.grp`」「HeavenSword 仅 `r1.idx` 无 `r1.grp`」之后的**第 3 种形态**。

**round-trip 实测**（独立进程，备份→验证→字节级恢复，详见 activate
verification §3.9）：

```
save 前: r1.grp=true r1.idx=false r1.ovr=false
LoadRecord(0) → JY.Person[0]["姓名"]="測試改名GD" → SaveRecord(1)
  → r1.idx 由 SeedSaveSlot 从 ranger.idx 模板播种，r1.ovr 写入
LoadRecord(1) = true          ← 槽位补全后加载成功
回读姓名: 測試改名GD          ← 覆盖表 round-trip 正确
恢复后: r1.grp=true r1.idx=false r1.ovr=false d1.grp=true s1.grp=true
```

**半状态读取行为**：`LoadRecord(1)`（`jymain.lua:1697-1701`）在 `rN.idx`/`rN.grp`/
`sN.grp`/`dN.grp` 任一缺失时**跳过加载**（`return false`，不崩溃）——槽位表现为空。
该守卫为原有设计（「存档文件不存在时，不做任何读取，避免崩溃」），零改动。

**三种形态全部覆盖**，存档隔离机制（Slice 1 决策 Q1/Q2）在全部形态下成立。

---

## 6. `EDITOR_DUMP` 确认（279 个 PNG）

**证据链（4 条，全部机器可复核）**：

1. **构建器显式忽略** —— `game/tools/mod_build.lua:567`
   `local IGNORE_DIRS = { head = true, item = true, eft = true }`
2. **引擎无引用** —— `grep "head/\|item/"` 于 `script/`/`framework/` → 0 命中
3. **引擎读打包格式** —— 头像 `CC.HeadPicFile`（`hdgrp.*`）、物品 `CC.ThingPicFile`
4. **审计规则** —— `mod_audit.lua` `["head|.png"]`/`["item|.png"]` →
   `EDITOR_DUMP`，证据 `EV_UPEDIT_DUMP`（引用 `IGNORE_DIRS`，`cmd` 可复核）

**数量**：`head/` 79 + `item/` 200 = **279**；产物中两目录**不存在**。

---

## 7. 穷举审计（Slice 0c 工具链）

```
$ cd game && lua tools/mod_audit.lua --mod GodsDevils
total=615 in_product=306 not_in_product=309 unclassified=0 bad_evidence=0
  REQUIRED             301
  REQUIRED_CONVERTED   4
  LEGACY               3
  EDITOR_DUMP          279
  BUILD_INPUT          1
  PENDING              27
```
`Σ = 301+4+3+279+1+27 = 615` ✅ · **矛盾 = 0** ✅

**309 个未进产物文件构成**：279 `head/`/`item/` PNG（`EDITOR_DUMP`）
+ 27 `music/*.mid`（`PENDING`）+ 4 `list/*.bin`（`PENDING`）
+ 2 `list/{end,start}.txt`（`LEGACY`）+ 1 `script/1.lua`（`LEGACY`）= 309 ✅

```
$ cd game && lua tools/format_spec.lua --mod GodsDevils
formats=12 checked=475 gaps=0
```

---

## 8. 零引擎改动（REQ-GDV-5）

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/mods/GodsDevils/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice6/**` 等 | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**本 slice 两个子 change 均零代码改动**（纯构建 + 验证）。

---

## 9. 零回归

```
lua tests/test_runner.lua                        → 1612/1612 ✅
lua tools/mod_build.lua --verify-pascal          → events=1018, mismatches=0, known-deviations=3 ✅
lua tools/mod_build.lua --all                    → 20 mods, 0 build failures, 5 annotated-problematic ✅
lua tools/mod_check.lua                          → 20 MOD, 通过 20, 失败 0 ✅
lua tools/mod_audit.lua --all                    → total=11220 unclassified=0 bad_evidence=0 ✅
lua tools/mod_audit.lua --all --evidence         → checked=17 failed=0 ✅
lua tools/format_spec.lua --all                  → formats=12 checked=6773 gaps=0 ✅
全量测试后全 MOD save/ 与源一致                   → checked=341 mismatch=0 ✅
```

---

## 10. 累计工具缺陷（4 个，本 slice 新增 0）

| # | Slice | 缺陷 | 根因 |
|---|-------|------|------|
| 1 | 2 | `mod_check_one` 销毁 `r1.grp` | 自检直接 `os.remove` 真实产物目录 |
| 2 | 3 | `mod_audit` 对 `kysmod.ini` 的 `in_product` 误判 | 类别级一刀切 |
| 3 | 3 | `test_mod_boot` 销毁 `r1.grp` | 与 #1 同源 |
| 4 | 5 | `mod_check_one` 销毁 `d1.grp`/`s1.grp` | #1 的第三次遗漏（`SLOTS` 只列 `r1.*`） |

**本 slice 零缺陷** —— 第 2 梯队收官：HeavenSword（缺陷 1）→ GodsDevils（缺陷 0）。
缺陷 D 修复的持久性在本 MOD 的 6 个源自带存档 + round-trip 中得到再次验证。

---

## 11. 结论

**PASS**。REQ-GDV-1~6 全部满足。GodsDevils 与基线**结构同形**（`hdgrp`/kdef/talk
条目更多），**零引擎改动、零代码改动**通过全部验证。

**本 change 的关键产出**：
1. **`hdgrp` 判据第二次外推成功**（129，与 HeavenSword 125 一致）—— 外推链
   建立，第 3~5 梯队可复用。
2. **「基准独有」定性从粗粒度（14/6/3）细化到源码级（6/9/8）**：发现 6 个
   `d/s*.idx` 是死文件（引擎无 S/D idx 常量），而非「回退原版」。
   可外推规则：后续 MOD 的 `d/s*.idx` 一律判死文件。
3. **第 3 种存档形态 round-trip 验证**：`r1.grp` 有、`r1.idx` 无 —— 引擎守卫
   优雅跳过 + 首次保存播种补全，三种形态全部覆盖。

**第 2 梯队（hdgrp 略增）收官**。下一梯队：hdgrp 173+ 的第 3 梯队 MOD
（见 epic TODO.md 排序）。
