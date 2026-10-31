# Verification: allmods-sweeOan-activate

> Change: `allmods-sweeOan-activate` · Slice: `allmods-slice2` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

验证 Slice 0/0b/0c 建立的 MOD 兼容地基对**第 1 梯队同形 MOD**（SweeOan，hdgrp 115 / fight 92）
是否需要任何引擎改动。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-SWEE-1 | 构建成功 | `data files=220, saves=6, sound=78, events=1018, talk=2977` | ✅ |
| REQ-SWEE-2 | 逐文件穷举归类 | `total=334 in_product=302 not_in_product=32 unclassified=0 bad_evidence=0`；矛盾 = 0 | ✅ |
| REQ-SWEE-3 | 字节级覆盖 | `formats=12 checked=196 gaps=0` | ✅ |
| REQ-SWEE-4 | 真实启动链路 | `RESULT SweeOan: OK`（16 项断言） | ✅ |
| REQ-SWEE-5 | MOD 独有内容加载 | 王小石/衛悲回/伊小深；资源路径全部指向 `mods/SweeOan/` | ✅ |
| REQ-SWEE-6 | 零回归 | 907/907；`--verify-pascal` mismatches=0；`--all` 0 failures；`mod_check` 20/20 | ✅ |

## 3. 实测证据

### 3.1 构建（REQ-SWEE-1）

```bash
cd game && rm -rf mods/SweeOan && lua tools/mod_build.lua kys-SweeOan
```
```
[mod_build] kys-SweeOan: data files=220, saves=6, sound=78, events=1018, talk=2977
[mod_build] diff -> tools/../mods/SweeOan/diff.md
```

产物目录：
| 目录 | 文件数 |
|------|-------:|
| `data/` | 220 |
| `script/oldevent/` | 1018 |
| `script/`（`oldtalk.grp`/`.idx`） | 2 |
| `save/` | 6 槽 |
| `sound/` | 78 |

### 3.2 逐文件穷举（REQ-SWEE-2）

```bash
lua tools/mod_audit.lua --mod SweeOan
```
```
total=334 in_product=302 not_in_product=32 unclassified=0 bad_evidence=0
  REQUIRED             298
  REQUIRED_CONVERTED   4
  LEGACY               4
  BUILD_INPUT          1
  PENDING              27
```

`Σ(类别) = 298+4+4+1+27 = 334` ✅

**「必需但未进产物」矛盾 = 0** ✅
（对每个 `in_product=false` 记录，`IN_PRODUCT_BY_CATEGORY[category]` 均不为 `true`）

### 3.3 字节级覆盖（REQ-SWEE-3）

```bash
lua tools/format_spec.lua --mod SweeOan
```
```
formats=12 checked=196 gaps=0
```

与 pascal 基线结构对比：

| 格式 | SweeOan | pascal | 判定 |
|------|--------:|-------:|------|
| `hdgrp` | 115 / 249276 | 115 / 249276 | 同形 |
| `eft` | 714 / 691627 | 714 / 691627 | 同形 |
| `warfld` | 26 / 532480 | 26 / 532480 | 同形 |
| `cloud` | 9 / 38120 | 9 / 38120 | 同形 |
| `title` | 9 / 8179 | 9 / 8179 | 同形 |
| `kdef` | 1018 / 121214 | 1018 / 121214 | 同形 |
| `talk` | 2977 / 151382 | 2977 / 186513 | 条目同形，内容不同 |

### 3.4 产物四项检查

```bash
MOD_SLUG=SweeOan lua tools/mod_check_one.lua
```
```
PERSON=320  THING=200  SCENE=84  WUGONG=93
HERO=王小石
STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.5 真实启动链路（REQ-SWEE-4）

```bash
lua tests/unit/boot_one_mod.lua SweeOan 320 200 84 93 王小石
```
```
[PASS] lib.init 无报错
[PASS] JYMainAdapter.init 无报错
[PASS] CC.PersonSize=182（MOD 布局）
[PASS] CC.ThingSize=190（MOD 布局）
[PASS] CC.SceneSize=52（MOD 布局）
[PASS] CC.WugongSize=136（MOD 布局）
[PASS] LoadRecord(0) 无报错
[PASS] PersonNum (期望 320, 实际 320)
[PASS] ThingNum (期望 200, 实际 200)
[PASS] SceneNum (期望 84, 实际 84)
[PASS] WugongNum (期望 93, 实际 93)
[PASS] 主角姓名 (期望 王小石, 实际 王小石)
[PASS] 扫描字段数 > 100（实际 1417）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错
RESULT SweeOan: OK
```

### 3.6 MOD 独有内容（REQ-SWEE-5）

资源路径：
```
CC.MMAPPicFile[1] = mods/SweeOan/data/mmap.idx
CC.SMAPPicFile[1] = mods/SweeOan/data/smap.idx
CC.WMAPPicFile[1] = mods/SweeOan/data/wmap.idx
CC.TalkGrpFile    = mods/SweeOan/script/oldtalk.grp
CC.WarFile        = mods/SweeOan/data/war.sta
```

内容（非基线值）：
```
JY.Person[0] 姓名=王小石    ← pascal = 小蝦米
JY.Person[1] 姓名=衛悲回
JY.Person[2] 姓名=伊小深
对话条目数 = 2977
oldevent 脚本数 = 1018
```

### 3.7 零回归（REQ-SWEE-6）

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **907/907** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0 known-deviations=3` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0 bad_evidence=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |

## 4. 产物清单

| 文件 | 说明 |
|------|------|
| `game/mods/SweeOan/**` | 构建产物（220 data + 1018 events + 6 saves + 78 sound） |
| `game/mods/SweeOan/diff.md` | 数据差异报告 |
| `game/tools/mod_check_one.lua` | **修复**：存档自检不再销毁产物（见 `sweeOan-verify`） |
| `game/tests/unit/test_mod_resources.lua` | **新增** 2 个回归测试 |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/mods/SweeOan/**` | 构建产物 | ✅ |
| `game/tools/mod_check_one.lua` | 修复数据销毁缺陷（本 slice 发现） | ✅ |
| `game/tests/unit/test_mod_resources.lua` | +2 回归测试 | ✅ |
| `openspec/changes/allmods-slice2/**` | 文档 | ✅ |
| `openspec/changes/allmods-sweeOan-*/**` | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**零引擎改动** —— 符合 ADR-001 的预期（同形 MOD 无需改动）。

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| 初测发现 `save/r1.grp` 报「必需但未进产物」 | `mod_check_one.lua` 删除产物（真实缺陷） | 已在 `sweeOan-verify` 修复 + 回归测试 |
| 一次全量测试出现 33 失败 | 并发重建 `mods/SweeOan` 与测试读取竞争 | 非回归；串行复跑 907/907 |
| 测试数 867 → 907 | 新增 2 个测试函数（含多断言） | 覆盖增强 |

## 7. 结论

**PASS**。REQ-SWEE-1~6 全部满足。SweeOan 与基线完全同形，**零引擎改动**通过全部验证。
本 change 在审计过程中触发了对 `mod_check_one.lua` 数据销毁缺陷的发现与修复
（详见 `allmods-sweeOan-verify/reports/sweeOan-verify.md` §5）。
