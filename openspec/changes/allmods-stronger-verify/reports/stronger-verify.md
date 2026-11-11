# stronger（威力加强版）验证报告

> Change: `allmods-stronger-verify` · Slice: `allmods-slice3` · Epic: `2026-10-allmods-compat`
> 日期：2026-10-19
> 结论：**PASS**（发现并修正审计工具的 `kysmod.ini` `in_product` 误判；发现并修复 `test_mod_boot` 的产物销毁缺陷）

---

## 1. 结论摘要

| 维度 | 结果 |
|------|------|
| 构建 | ✅ `events=1018`，退出码 0 |
| 逐文件穷举 | ✅ `total=335 unclassified=0 bad_evidence=0` |
| 「必需但未进产物」矛盾 | ✅ **0** |
| 字节级覆盖 | ✅ `formats=12 checked=196 gaps=0` |
| 产物四项检查 | ✅ `STRINGS/EVENTS/SAVE=OK` |
| 真实启动链路 | ✅ `RESULT stronger: OK`（16 项断言） |
| MOD 独有内容 | ✅ 确认为 MOD 内容（非回退） |
| 引擎改动 | ✅ **零改动** |
| 零回归 | ✅ 958/958 测试通过 |
| **发现缺陷** | ⚠️ **2 个** → 均已修复 + 回归测试 |

---

## 2. `diff.md` 逐条审计（REQ-STRV-1）

### 2.1 MOD 独有（13 项）

| # | 文件 | 判定 | 引擎行为 |
|---|------|------|---------|
| 1-2 | `cloud.grp`/`.idx` | 预期 | `CC.CloudPicFile` → MOD |
| 3 | `dead.png` | 预期 | 死亡画面 |
| 4 | `end.png` | 预期 | 结束画面 |
| 5-6 | `kdef.grp`/`.idx` | 预期 | 事件脚本（1018 个） |
| 7 | `kysmod.ini` | `BUILD_INPUT`（**在产物中**） | 构建器复制到 `data/`；引擎不读 |
| 8 | `open.png` | 预期 | 开场画面 |
| 9 | `ranger.str` | `REQUIRED_CONVERTED` | 构建期生成的 UTF-8 旁路表 |
| 10-11 | `talk.grp`/`.idx` | 预期 | 对话表（3727 条） |
| 12-13 | `title.grp`/`.idx` | 预期 | 标题画面 |

**结论**：13 项全部有判定，**0 项需修复**。

> **注**：stronger **没有** `修改档说明.txt`（SweeOan 有）。

### 2.2 基准独有（21 项，REQ-STRV-2）

| # | 文件 | 性质 | 运行时证据 |
|---|------|------|-----------|
| 1 | `allsinbk.grp` | **死文件** | `CC.TempS_Filename`，`LoadSMap` 形参 0 引用 |
| 2-7 | `d1.grp` / `d2` / `d3` (+idx) | `d1.grp` **在 save/**；其余回退 | `CC.D_Filename[1] = mods/stronger/save/d1.grp` |
| 8-13 | `r1.grp` / `r2` / `r3` (+idx) | `r1.grp` **在 save/**；其余回退 | `CC.R_GRPFilename[1] = mods/stronger/save/r1.grp` |
| 14-19 | `s1.grp` / `s2` / `s3` (+idx) | `s1.grp` **在 save/**；其余回退 | `CC.S_Filename[1] = mods/stronger/save/s1.grp` |
| 20-21 | `thing.grp`/`.idx` | 回退原版 | `CC.ThingPicFile[1] = data/thing.idx`（0/20 MOD 提供） |

**分类**：**回退原版 17 + 在 save/ 3 + 死文件 1 = 21** ✅ 无未解释项。

---

## 3. MOD 独有内容验证（REQ-STRV-3）

| 判据 | stronger | pascal 基线 | 区分度 |
|------|----------|------------|--------|
| 主角姓名 | **韋大寶** | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | **胡斐** | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | **程靈素** | （不同） | ✅ |
| 对话条目数 | **3727** | 2977 | ✅ |
| 事件脚本数 | 1018 | 1018 | ❌（同数） |

**资源路径**：
```
CC.MMAPPicFile[1] = mods/stronger/data/mmap.idx
CC.TalkGrpFile    = mods/stronger/script/oldtalk.grp
CC.WarFile        = mods/stronger/data/war.sta
CC.ThingPicFile[1]= data/thing.idx               ← 回退原版
```

**结论**：人物姓名与对话条目数均有区分度，证明 MOD 数据确实被加载。

---

## 4. 穷举审计（Slice 0c 工具链）

```
$ cd game && lua tools/mod_audit.lua --mod stronger
total=335 in_product=305 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             300
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
```

**30 个未进产物文件**（全部有类别 + 证据）：

| 类别 | 数 | 文件 |
|------|--:|------|
| `PENDING` | 27 | `music/1.mid` … `music/23.mid` |
| `PENDING` | 4 | `list/{effect,leave,levelup,match}.bin` |
| `LEGACY` | 2 | `list/{end,start}.txt` |
| `LEGACY` | 1 | `script/1.lua` |

**「必需但未进产物」矛盾数 = 0** ✅

```
$ cd game && lua tools/format_spec.lua --mod stronger
formats=12 checked=196 gaps=0
```

---

## 5. 发现的缺陷（REQ-STRV-6）

### 5.1 缺陷 A：`kysmod.ini` 的 `in_product` 误判

**现象**：审计报告 `kysmod.ini` 为 `in_product=false`，但 `ls game/mods/stronger/data/`
显示该文件**确实在产物中**（全部 20 个 MOD 皆然）。

**根因（两处）**：

1. `IN_PRODUCT_BY_CATEGORY[BUILD_INPUT] = false` —— 类别级一刀切。
   但 `BUILD_INPUT` 下有两种文件：
   - `kysmod.ini`：**被复制到 `data/`**（`mod_build.lua:879-882`）
   - `cc/*.txt`：仅构建期 Big5 转换器使用，**不进产物**
2. `productCandidates` 没有 `topdir==""` 分支 —— `kysmod.ini` 在 MOD 根目录，
   返回空候选列表。

**错误尝试**：先把 `BUILD_INPUT` 类别整体改为 `true` → **产生 4 个新矛盾**
（`pascal/cc/{STCharacters,STPhrases,TSCharacters,TSPhrases}.txt`），证明类别级一刀切是错的。

**修复**：per-rule `in_product` 覆盖 + 根级文件候选路径。

```lua
-- checkInProduct
if rule.in_product == false then return false end
if rule.in_product ~= true and not M.IN_PRODUCT_BY_CATEGORY[rule.category] then
    return false
end

-- productCandidates 新增
elseif topdir == "" then
    cands[#cands + 1] = M.MODS_OUT .. "/" .. mod .. "/data/" .. filename

-- 规则
["kysmod.ini"] = { category="BUILD_INPUT", needed=false, in_product=true, ... }
```

**验证**：
```
stronger kysmod.ini in_product = true      ✅
pascal/cc/STCharacters.txt in_product = false  ✅
矛盾数 = 0                                  ✅
20/20 MOD 的 kysmod.ini in_product=true     ✅
```

**连带修正**：`EV_BUILD_INPUT` 证据文本原写「**不进入产物**」（与代码矛盾）。
已改为指向 `mod_build.lua` 并说明复制行为，可被 `grep -n 'kysmod' tools/mod_build.lua` 复核。

**新增回归测试**：
- `testKysmodIniIsBuildInputButShipped`
- `testCcDictsAreBuildInputAndNotShipped`

**派生断言**：原硬编码 `1995`/`9145`/`663` 漂移导致 35 个失败，
改为从审计结果派生（ADR-004）。

### 5.2 缺陷 B：`test_mod_boot.lua` 销毁产物 `r1.grp`

**现象**：全量测试后 mingdong 的 `save/r1.grp` 变成 223688 B（源为 222888 B），
并残留 `r1.idx`/`r1.ovr`。

**根因**：`test_mod_boot.lua:271` 直接操作真实产物目录：
```lua
os.execute("rm -f mods/mingdong/save/r1.idx mods/mingdong/save/r1.grp ...")
SaveRecord(1)   -- 覆盖 r1.grp
```
测试结束**未恢复** —— 与 Slice 2 的 `mod_check_one.lua` 缺陷同源。

**影响面**：mingdong **自带** `r1.grp`，因此每次全量测试都会销毁它。

**修复**：备份 + 恢复（`restoreSlots()`），并新增 `testProductSavesNotDestroyedByTests`
（在 `mod_boot.runAll` **末位**执行，断言全部 MOD 的 `r1.grp` 与源逐字节一致）。

**验证**：
```
test_mod_boot: 85/85 通过
测试后 mingdong r1.grp = 222888 B（= 源）✅
无 r1.idx/r1.ovr 残留 ✅
全部 20 MOD 的 save/r1.grp 与源一致 ✅
```

---

## 6. 零引擎改动（REQ-STRV-5）

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/tools/mod_audit.lua` | per-rule `in_product` + 根级候选 + 证据修正 | ✅ |
| `game/tests/unit/test_mod_audit.lua` | 派生断言 + 2 个新测试 | ✅ |
| `game/tests/unit/test_mod_boot.lua` | 备份恢复 + 1 个新测试 | ✅ |
| `game/mods/stronger/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice3/**` 等 | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

---

## 7. 零回归

```
lua tests/test_runner.lua                        → 958/958 ✅
lua tools/mod_build.lua --verify-pascal          → events=1018, mismatches=0 ✅
lua tools/mod_build.lua --all                    → 20 mods, 0 build failures ✅
lua tools/mod_check.lua                          → 20 MOD, 通过 20, 失败 0 ✅
lua tools/mod_audit.lua --all                    → total=11220 unclassified=0 bad_evidence=0 ✅
lua tools/mod_audit.lua --all --evidence         → checked=17 failed=0 ✅
lua tools/format_spec.lua --all                  → formats=12 checked=6773 gaps=0 ✅
```

---

## 8. 结论

**PASS**。stronger 与基线**结构完全同形**，**零引擎改动**通过全部验证。

本 change 的产出是**两个工具缺陷的修正**：

1. **`mod_audit.lua` 的 `kysmod.ini` `in_product` 误判** —— 类别级一刀切无法处理
   「同类不同产物状态」；修正为 per-rule 覆盖。**连带修正了与代码矛盾的证据文本**。
2. **`test_mod_boot.lua` 销毁产物 `r1.grp`** —— 与 Slice 2 的 `mod_check_one` 缺陷同源，
   现已修复并有末位断言防回归。

**方法论意义**：这再次印证「同形 ≠ 零问题」。stronger 的**数据**与基线同形，
但**工具链**仍有缺陷 —— 只有逐文件穷举 + 全量回归才能暴露。

**对后续 MOD 的影响**：第 1 梯队最后 1 个（`lostbook`）与基线同形，
可预期零改动，但仍须跑完整流程。
