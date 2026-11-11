# lostbook（失传天书-越女剑）验证报告

> Change: `allmods-lostbook-verify` · Slice: `allmods-slice4` · Epic: `2026-10-allmods-compat`
> 日期：2026-10-19
> 结论：**PASS**（零缺陷；第 1 梯队 3 个 MOD 全部完成）

---

## 1. 结论摘要

| 维度 | 结果 |
|------|------|
| 构建 | ✅ `events=1071 talk=3181`，退出码 0 |
| 逐文件穷举 | ✅ `total=342 unclassified=0 bad_evidence=0` |
| 「必需但未进产物」矛盾 | ✅ **0** |
| 字节级覆盖 | ✅ `formats=12 checked=201 gaps=0` |
| 产物四项检查 | ✅ `STRINGS/EVENTS/SAVE=OK` |
| 真实启动链路 | ✅ `RESULT lostbook: OK`（16 项断言） |
| 存档播种 | ✅ `r1.grp` 从 `ranger.idx` 播种，无残留 |
| MOD 独有内容 | ✅ 确认为 MOD 内容（非回退） |
| 引擎改动 | ✅ **零改动** |
| 零回归 | ✅ 958/958 测试通过 |
| **发现缺陷** | ✅ **无**（工具链已在前两个 slice 稳定） |

---

## 2. `diff.md` 逐条审计（REQ-LOSTV-1）

### 2.1 MOD 独有（24 项）

| # | 文件 | 判定 | 引擎行为 |
|---|------|------|---------|
| 1-2 | `cloud.grp`/`.idx` | 预期 | `CC.CloudPicFile` → MOD |
| 3 | `dead.png` | 预期 | 死亡画面 |
| 4 | `end.png` | 预期 | 结束画面 |
| 5-14 | **`fight039`~`042` + `fight052`**（`.grp`/`.idx` 各 5） | 预期 | **额外 5 场战斗** |
| 15-16 | `kdef.grp`/`.idx` | 预期 | 事件脚本（**1071** 个） |
| 17 | `kysmod.ini` | `BUILD_INPUT`（在产物中） | 构建器复制到 `data/` |
| 18 | `open.png` | 预期 | 开场画面 |
| 19 | `ranger.str` | `REQUIRED_CONVERTED` | UTF-8 旁路表 |
| 20-21 | `talk.grp`/`.idx` | 预期 | 对话表（**3181** 条） |
| 22-23 | `title.grp`/`.idx` | 预期 | 标题画面 |

**结论**：24 项全部有判定，**0 项需修复**。

**5 场额外战斗三重确认**：

| 文件 | `diff.md` 提及 | 产物存在 | 审计归类 |
|------|--------------:|---------|---------|
| `fight039.grp`/`.idx` | ✅ | ✅ | `REQUIRED` / `in_product=true` |
| `fight040.grp`/`.idx` | ✅ | ✅ | `REQUIRED` / `in_product=true` |
| `fight041.grp`/`.idx` | ✅ | ✅ | `REQUIRED` / `in_product=true` |
| `fight042.grp`/`.idx` | ✅ | ✅ | `REQUIRED` / `in_product=true` |
| `fight052.grp`/`.idx` | ✅ | ✅ | `REQUIRED` / `in_product=true` |

### 2.2 基准独有（21 项，REQ-LOSTV-2）

| # | 文件 | 性质 | 运行时证据 |
|---|------|------|-----------|
| 1 | `allsinbk.grp` | **死文件** | `CC.TempS_Filename`，`LoadSMap` 形参 0 引用 |
| 2-7 | `d1.grp`/`d2`/`d3` (+idx) | `d1.grp` **在 save/**；其余回退 | `CC.D_Filename[1] = mods/lostbook/save/d1.grp` |
| 8-13 | `r1.grp`/`r2`/`r3` (+idx) | `r1.grp` **在 save/（首次播种）**；其余回退 | `CC.R_GRPFilename[1] = mods/lostbook/save/r1.grp` |
| 14-19 | `s1.grp`/`s2`/`s3` (+idx) | `s1.grp` **在 save/**；其余回退 | `CC.S_Filename[1] = mods/lostbook/save/s1.grp` |
| 20-21 | `thing.grp`/`.idx` | 回退原版 | `CC.ThingPicFile[1] = data/thing.idx` |

**分类**：**回退原版 18 + 在 save/ 2 + 死文件 1 = 21** ✅ 无未解释项。

**`r1.grp` 的特殊性（ADR-004）**：lostbook 源**无** `r1.grp`，但
`CC.R_GRPFilename[1]` 指向 `mods/lostbook/save/r1.grp` —— 该槽在首次存档时
从 `ranger.idx` **播种**。因此归为「在 save/（首次播种）」，**不是**回退原版或死文件。

---

## 3. 内容差异 vs 结构异常（REQ-LOSTV-4）

lostbook 比 pascal 内容更多：

| 维度 | lostbook | pascal | 差异 |
|------|---------:|-------:|------|
| `kdef.grp` | **1071** | 1018 | +53 事件 |
| fight | **97** | 92 | +5 战斗 |
| `talk.grp` | **3181** | 2977 | +204 对话 |

**判定为「内容差异」的三重机器可验证判据**：

| 条件 | 实测 | 说明 |
|------|------|------|
| 记录布局常量相同 | `CC.PersonSize=182`/`ThingSize=190`/`SceneSize=52`/`WugongSize=136` | 与 pascal 一致 |
| 记录数相同 | 320/200/84/93 | 与 pascal 一致 |
| **字节全覆盖** | `formats=12 checked=201 gaps=0` | 按 pascal 尺寸解析无错位 |

**关键推理**：若 lostbook 是**结构异常**（如记录尺寸不同），`format_spec` 按 pascal
尺寸解析必然错位，报 `gaps > 0`。实测 `gaps=0`，证明**结构未变，仅内容更多**。

**对照**：`hdgrp`/`eft`/`warfld`/`cloud`/`title` 与 pascal **完全同形**（条目数 + 字节数一致）。

---

## 4. MOD 独有内容验证（REQ-LOSTV-3）

| 判据 | lostbook | pascal 基线 | 区分度 |
|------|----------|------------|--------|
| 主角姓名 | **金迷** | 小蝦米 | ✅ |
| `JY.Person[1]["姓名"]` | **胡斐** | （不同） | ✅ |
| `JY.Person[2]["姓名"]` | **程靈素** | （不同） | ✅ |
| 对话条目数 | **3181** | 2977 | ✅ |
| 事件脚本数 | **1071** | 1018 | ✅ |

**资源路径**：
```
CC.MMAPPicFile[1] = mods/lostbook/data/mmap.idx
CC.TalkGrpFile    = mods/lostbook/script/oldtalk.grp
CC.WarFile        = mods/lostbook/data/war.sta
CC.ThingPicFile[1]= data/thing.idx               ← 回退原版
```

**存档播种**（lostbook 独有特征）：
```
save 前 r1.grp:  false   ✅
save 后 r1.grp:  true    ✅
save 后 r1.idx:  true    ✅（从 ranger.idx 播种）
save 后 r1.ovr:  true    ✅（字符串改写）
回读姓名:        测试改名  ✅（覆盖表优先）
恢复后 r1.grp:   false   ✅（无残留）
```

---

## 5. 穷举审计（Slice 0c 工具链）

```
$ cd game && lua tools/mod_audit.lua --mod lostbook
total=342 in_product=312 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             307
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
$ cd game && lua tools/format_spec.lua --mod lostbook
formats=12 checked=201 gaps=0
```

---

## 6. 零引擎改动（REQ-LOSTV-5）

本 slice 的改动**全部**在允许路径：

| 路径 | 改动 | 允许？ |
|------|------|-------|
| `game/mods/lostbook/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice4/**` 等 | 文档 | ✅ |

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

## 8. 第 1 梯队小结

| MOD | Slice | 构建 | 穷举 | 字节 | 启动 | 引擎改动 | 发现缺陷 |
|-----|-------|------|------|------|------|---------|---------|
| SweeOan | 2 | ✅ | `total=334 unclassified=0` | `gaps=0` | ✅ 王小石 | **零** | 1（`mod_check_one` 销毁产物） |
| stronger | 3 | ✅ | `total=335 unclassified=0` | `gaps=0` | ✅ 韋大寶 | **零** | 2（`in_product` 误判 + `test_mod_boot` 销毁产物） |
| lostbook | 4 | ✅ | `total=342 unclassified=0` | `gaps=0` | ✅ 金迷 | **零** | **0** |

**第 1 梯队（与基线同形）3 个 MOD 全部完成，零引擎改动。**

**方法论验证**：
- 3 个 MOD 的**数据**都与基线同形 → 确实**无需引擎改动**（符合排序预期）
- 但前 2 个 MOD 暴露了 **3 个工具链缺陷** → 「同形 ≠ 零问题」
- 第 3 个 MOD 零缺陷 → 工具链已稳定

## 9. 结论

**PASS**。REQ-LOSTV-1~6 全部满足。lostbook 与基线**结构同形**（内容更多），
**零引擎改动**通过全部验证，**未发现缺陷**。

**第 1 梯队收官**。下一梯队为第 2 梯队（hdgrp 125~129）：HeavenSword、GodsDevils
（zheng、loving 已在早期单独完成）。
