# Verification: allmods-stronger-activate

> Change: `allmods-stronger-activate` · Slice: `allmods-slice3` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

把「威力加强版」（kys-stronger）接入 MOD 兼容地基，验证地基对「与基线同形 MOD」是否足够。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-STR-1 | 构建成功 | `data files=221, saves=6, sound=78, events=1018, talk=3727` | ✅ |
| REQ-STR-2 | 逐文件穷举归类 | `total=335 in_product=305 not_in_product=30 unclassified=0 bad_evidence=0`；矛盾 = 0 | ✅ |
| REQ-STR-3 | 字节级覆盖 | `formats=12 checked=196 gaps=0` | ✅ |
| REQ-STR-4 | 真实启动链路 | `RESULT stronger: OK`（16 项断言） | ✅ |
| REQ-STR-5 | MOD 独有内容加载 | 韋大寶/胡斐/程靈素；talk 3727；路径全指向 MOD | ✅ |
| REQ-STR-6 | 零回归 | 958/958；7 项门禁全通过 | ✅ |

## 3. 实测证据

### 3.1 构建（REQ-STR-1）

```bash
cd game && rm -rf mods/stronger && lua tools/mod_build.lua kys-stronger
```
```
[mod_build] kys-stronger: data files=221, saves=6, sound=78, events=1018, talk=3727
[mod_build] diff -> tools/../mods/stronger/diff.md
```

产物目录：
| 目录 | 文件数 |
|------|-------:|
| `data/` | 222（221 计数 + `kysmod.ini`） |
| `script/oldevent/` | 1018 |
| `script/`（`oldtalk.grp`/`.idx`） | 2 |
| `save/` | 6 槽 |
| `sound/` | 78 |

**产物 `save/r1.grp` 完整性**（ADR-002）：
```
13a6e79648dd8b0e5c85fa74cdfe0e16  game/mods/stronger/save/r1.grp
13a6e79648dd8b0e5c85fa74cdfe0e16  reference/allmods/kys-stronger/save/r1.grp
```
逐字节相同 ✅（Slice 2 的 `mod_check_one` 修复在此生效）

### 3.2 逐文件穷举（REQ-STR-2）

```bash
lua tools/mod_audit.lua --mod stronger
```
```
total=335 in_product=305 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             300
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
```

`Σ(类别) = 300+4+3+1+27 = 335` ✅ · **「必需但未进产物」矛盾 = 0** ✅

**30 个未进产物文件**（全部有类别 + 证据）：

| 类别 | 数 | 文件 |
|------|--:|------|
| `PENDING` | 27 | `music/1.mid` … `music/23.mid` |
| `PENDING` | 4 | `list/{effect,leave,levelup,match}.bin` |
| `LEGACY` | 2 | `list/{end,start}.txt` |
| `LEGACY` | 1 | `script/1.lua` |

> **注**：`kysmod.ini` **在产物中**（`in_product=true`），归 `BUILD_INPUT` ——
> 构建器复制到 `data/`（`mod_build.lua:879-882`），引擎不读。
> 这一点在 Slice 3 中被发现并修正（详见 `allmods-stronger-verify`）。

### 3.3 字节级覆盖（REQ-STR-3）

```bash
lua tools/format_spec.lua --mod stronger
```
```
formats=12 checked=196 gaps=0
```

与 pascal 基线结构对比（**全部同形**）：

| 格式 | stronger | pascal | 判定 |
|------|---------:|-------:|------|
| `hdgrp` | 115 | 115 | 同形 |
| `eft` | 714 | 714 | 同形 |
| `warfld` | 26 | 26 | 同形 |
| `cloud` | 9 | 9 | 同形 |
| `title` | 9 | 9 | 同形 |
| `kdef` | 1018 | 1018 | 同形 |
| fight | 92 | 92 | 同形 |
| `talk` | **3727** | 2977 | **条目数不同**（剧情量更大） |

### 3.4 产物四项检查

```bash
MOD_SLUG=stronger lua tools/mod_check_one.lua
```
```
PERSON=320  THING=200  SCENE=84  WUGONG=93
HERO=韋大寶
STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.5 真实启动链路（REQ-STR-4）

```bash
lua tests/unit/boot_one_mod.lua stronger 320 200 84 93 韋大寶
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
[PASS] 主角姓名 (期望 韋大寶, 实际 韋大寶)
[PASS] 扫描字段数 > 100（实际 1417）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错
RESULT stronger: OK
```

### 3.6 MOD 独有内容（REQ-STR-5）

资源路径：
```
CC.MMAPPicFile[1] = mods/stronger/data/mmap.idx
CC.TalkGrpFile    = mods/stronger/script/oldtalk.grp
CC.WarFile        = mods/stronger/data/war.sta
CC.ThingPicFile[1]= data/thing.idx               ← 回退原版（0/20 MOD 提供）
```

内容（非基线值）：
```
JY.Person[0] 姓名=韋大寶 / 外号=天下奇男子    ← pascal = 小蝦米
JY.Person[1] 姓名=胡斐   / 外号=雪山飛狐
JY.Person[2] 姓名=程靈素 / 外号=毒手藥王
对话条目数 = 3727    ← pascal = 2977（有区分度）
oldevent 脚本数 = 1018
```

### 3.7 零回归（REQ-STR-6）

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **958/958** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0 known-deviations=3` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0 bad_evidence=0` ✅ |
| `mod_audit --all --evidence` | `checked=17 failed=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |

## 4. 产物清单

| 文件 | 说明 |
|------|------|
| `game/mods/stronger/**` | 构建产物（222 data + 1018 events + 6 saves + 78 sound） |
| `game/mods/stronger/diff.md` | 数据差异报告 |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/mods/stronger/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice3/**` | 文档 | ✅ |
| `openspec/changes/allmods-stronger-*/**` | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**零引擎改动** —— 符合预期（同形 MOD）。

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| `data/` 目录 `ls` 计 222，build 报 221 | build 计数排除 `kysmod.ini` | 已核实：222 = 221 + `kysmod.ini` |
| 审计中 `kysmod.ini` 原报 `in_product=false` | 类别级判定未考虑根级文件被复制 | 已在 `allmods-stronger-verify` 修正 |
| `talk.grp` 条目数与基线不同 | stronger 剧情量更大 | 预期内差异 |

## 7. 结论

**PASS**。REQ-STR-1~6 全部满足。stronger 与基线**结构完全同形**，
**零引擎改动**通过全部验证。

本 change 在审计过程中发现 `mod_audit.lua` 对 `kysmod.ini` 的 `in_product` 判定有误
（详见 `allmods-stronger-verify/reports/stronger-verify.md`）。
