# Verification: allmods-lostbook-activate

> Change: `allmods-lostbook-activate` · Slice: `allmods-slice4` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

把「失传天书-越女剑」（kys-lostbook）接入 MOD 兼容地基，并验证**首次存档播种**路径。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-LOST-1 | 构建成功 | `data files=231, saves=3, sound=78, events=1071, talk=3181` | ✅ |
| REQ-LOST-2 | 逐文件穷举归类 | `total=342 in_product=312 not_in_product=30 unclassified=0`；矛盾 = 0 | ✅ |
| REQ-LOST-3 | 字节级覆盖 | `formats=12 checked=201 gaps=0` | ✅ |
| REQ-LOST-4 | 真实启动链路 | `RESULT lostbook: OK`（16 项断言） | ✅ |
| REQ-LOST-5 | 存档播种 | `r1.grp` 从 `ranger.idx` 播种；`r1.ovr` 覆盖；无残留 | ✅ |
| REQ-LOST-6 | 零回归 | 958/958；7 项门禁全通过 | ✅ |

## 3. 实测证据

### 3.1 构建（REQ-LOST-1）

```bash
cd game && rm -rf mods/lostbook && lua tools/mod_build.lua kys-lostbook
```
```
[mod_build] kys-lostbook: data files=231, saves=3, sound=78, events=1071, talk=3181
[mod_build] diff -> tools/../mods/lostbook/diff.md
```

产物目录：
| 目录 | 文件数 |
|------|-------:|
| `data/` | 231（+ `kysmod.ini`） |
| `script/oldevent/` | **1071** |
| `script/`（`oldtalk.grp`/`.idx`） | 2 |
| `save/` | 5（`d11`/`r11`/`s11` + `d1`/`s1`） |
| `sound/` | 78 |

**关键**：源 `save/` **无** `r1.grp`，产物亦无 —— `r1` 为首次存档播种槽。

### 3.2 逐文件穷举（REQ-LOST-2）

```bash
lua tools/mod_audit.lua --mod lostbook
```
```
total=342 in_product=312 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             307
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
```

`Σ(类别) = 307+4+3+1+27 = 342` ✅ · **矛盾 = 0** ✅

**30 个未进产物文件**：
| 类别 | 数 | 文件 |
|------|--:|------|
| `PENDING` | 27 | `music/*.mid` |
| `PENDING` | 4 | `list/*.bin` |
| `LEGACY` | 2 | `list/{end,start}.txt` |
| `LEGACY` | 1 | `script/1.lua` |

### 3.3 字节级覆盖（REQ-LOST-3）

```bash
lua tools/format_spec.lua --mod lostbook
```
```
formats=12 checked=201 gaps=0
```

与 pascal 结构对比：

| 格式 | lostbook | pascal | 判定 |
|------|---------:|-------:|------|
| `hdgrp` | 115 | 115 | 同形 |
| `eft` | 714 | 714 | 同形 |
| `warfld` | 26 | 26 | 同形 |
| `cloud` | 9 | 9 | 同形 |
| `title` | 9 | 9 | 同形 |
| `kdef` | **1071** | 1018 | **内容差异**（+53 事件） |
| fight | **97** | 92 | **内容差异**（+5 战斗） |
| `talk` | **3181** | 2977 | **内容差异**（+204 对话） |

**结论**：kdef/fight 差异是**内容量**差异（每项尺寸不变），非结构异常 —— `gaps=0` 佐证。

### 3.4 产物四项检查

```bash
MOD_SLUG=lostbook lua tools/mod_check_one.lua
```
```
PERSON=320  THING=200  SCENE=84  WUGONG=93
HERO=金迷
STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.5 真实启动链路（REQ-LOST-4）

```bash
lua tests/unit/boot_one_mod.lua lostbook 320 200 84 93 金迷
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
[PASS] 主角姓名 (期望 金迷, 实际 金迷)
[PASS] 扫描字段数 > 100（实际 1417）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错
RESULT lostbook: OK
```

### 3.6 存档播种（REQ-LOST-5）

lostbook 源无 `r1.grp`，首次存档必须从 `ranger.idx` 播种：

```
save 前 r1.grp 存在:  false   ✅（干净状态）
CC.R_GRPFilename[1] = mods/lostbook/save/r1.grp   ✅
save 后 r1.grp 存在:  true    ✅（播种）
save 后 r1.idx 存在:  true    ✅（从 ranger.idx 播种）
save 后 r1.ovr 存在:  true    ✅（字符串改写）
回读姓名:             测试改名  ✅（覆盖表优先）
恢复后 r1.grp 存在:  false   ✅（无残留）
```

### 3.7 零回归（REQ-LOST-6）

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
| `game/mods/lostbook/**` | 构建产物（231 data + 1071 events + 5 saves + 78 sound） |
| `game/mods/lostbook/diff.md` | 数据差异报告 |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/mods/lostbook/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice4/**` | 文档 | ✅ |
| `openspec/changes/allmods-lostbook-*/**` | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**零引擎改动** —— 内容差异（更多事件/战斗）不改变记录布局。

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| kdef 1071 vs pascal 1018 | MOD 内容更多 | 内容差异，非结构异常（`gaps=0`） |
| fight 97 vs pascal 92 | MOD 多 5 场战斗 | 同上 |
| 源无 `r1.grp` | lostbook 存档包不含槽 1 | 覆盖「首次存档播种」路径（补充验证） |

## 7. 结论

**PASS**。REQ-LOST-1~6 全部满足。lostbook 与基线**结构同形**（内容更多），
**零引擎改动**通过全部验证。

本 change 补充验证了**首次存档播种**路径（前两个 MOD 因源自带 `r1.grp` 未覆盖）。
第 1 梯队（与基线同形）**3 个 MOD 全部完成**。
