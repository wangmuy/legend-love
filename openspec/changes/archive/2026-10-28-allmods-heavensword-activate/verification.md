# Verification: allmods-heavensword-activate

> Change: `allmods-heavensword-activate` · Slice: `allmods-slice5` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**
> 结论：**PASS**（发现并修复第 4 个工具缺陷：`mod_check_one` 未备份 `d1.grp`/`s1.grp`）

## 1. 目标回顾

把「倚天剑」（kys-HeavenSword）接入 MOD 兼容地基 —— 它是**第 2 梯队第 1 个**，
也是**第一个 `hdgrp` 条目数不等于基线的 MOD**（125 vs 115）。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-HS-1 | 构建成功 | `data files=223, saves=4, sound=78, events=1066, talk=3315` | ✅ |
| REQ-HS-2 | 逐文件穷举归类 | `total=335 unclassified=0`；矛盾 = 0 | ✅ |
| REQ-HS-3 | 字节级覆盖 | `formats=12 checked=197 gaps=0` | ✅ |
| REQ-HS-4 | `hdgrp` 差异验证 | 125 条目；无固定计数常量；内容差异 | ✅ |
| REQ-HS-5 | 真实启动链路 | `RESULT HeavenSword: OK`（16 项断言） | ✅ |
| REQ-HS-6 | 存档验证 | `r1.idx` 保留 + `r1.grp` 播种 + `r1.ovr` 覆盖；无残留 | ✅ |
| REQ-HS-7 | 零回归 | 1612/1612；全部门禁通过；全 MOD save 完好 | ✅ |

## 3. 实测证据

### 3.1 构建（REQ-HS-1）

```bash
cd game && lua tools/mod_build.lua kys-HeavenSword
```
```
[mod_build] kys-HeavenSword: data files=223, saves=4, sound=78, events=1066, talk=3315
[mod_build] diff -> tools/../mods/HeavenSword/diff.md
```

### 3.2 逐文件穷举（REQ-HS-2）

```
total=335 in_product=305 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED             300
  REQUIRED_CONVERTED   4
  LEGACY               3
  BUILD_INPUT          1
  PENDING              27
```
`Σ = 300+4+3+1+27 = 335` ✅ · **矛盾 = 0** ✅

### 3.3 字节级覆盖（REQ-HS-3）

```
formats=12 checked=197 gaps=0
```

### 3.4 `hdgrp` 差异验证（REQ-HS-4）

| 检查 | 实测 |
|------|------|
| `hdgrp.idx` 大小 | 500 字节 = **125** × 4 |
| pascal `hdgrp.idx` | 115 条目 |
| `CC.HeadPicFile[1]` | `mods/HeavenSword/data/hdgrp.idx` |
| `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` | 全部 `nil`（不存在） |
| `PicLoadFile` 条目数来源 | `local num = idxlen/4`（`lib_love.lua:437`） |

**结论**：引擎为**索引驱动**加载，条目数由文件大小推导，**无固定计数依赖**。
`hdgrp` 125 为**内容差异**（更多头像），非结构异常。

### 3.5 产物四项检查

```
PERSON=320  THING=200  SCENE=84  WUGONG=93
HERO=楊千葉
STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.6 真实启动链路（REQ-HS-5）

```
[PASS] CC.PersonSize=182（MOD 布局）
[PASS] CC.ThingSize=190（MOD 布局）
[PASS] CC.SceneSize=52（MOD 布局）
[PASS] CC.WugongSize=136（MOD 布局）
[PASS] PersonNum (期望 320, 实际 320)
[PASS] ThingNum (期望 200, 实际 200)
[PASS] SceneNum (期望 84, 实际 84)
[PASS] WugongNum (期望 93, 实际 93)
[PASS] 主角姓名 (期望 楊千葉, 实际 楊千葉)
[PASS] 扫描字段数 > 100（实际 1417）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错
RESULT HeavenSword: OK
```

### 3.7 存档验证（REQ-HS-6）

```
源 r1.idx md5        = 3746f89bd755157160d7bc9575d8e2e4
源 ranger.idx md5    = 3746f89bd755157160d7bc9575d8e2e4  ← 相同（模板副本）
save 前 r1.grp: false   r1.idx: true
save 后 r1.grp: true    r1.idx: true    r1.ovr: true
回读姓名: 测试改名HS
恢复后 r1.grp: false    r1.idx: true
```

覆盖了 MOD 存档隔离的**第三种形态**（前两种：源自带 `r1.grp`；源无任何 `r1.*`）。

---

## 4. 缺陷 D：`mod_check_one` 未备份 `d1.grp`/`s1.grp`

### 4.1 现象

全量重建后运行 `mod_check`，**20 个 MOD 的 `d1.grp`/`s1.grp` 全部被改变**：

```
$ cmp -l reference/allmods/kys-pascal/save/d1.grp game/mods/pascal/save/d1.grp | wc -l
2892
$ cmp -l reference/allmods/kys-mingdong/save/d1.grp game/mods/mingdong/save/d1.grp | wc -l
6067
```

时间戳显示修改发生在测试运行期间（`00:10`，构建为 `00:04`）。

### 4.2 根因

`game/tools/mod_check_one.lua` 的自检调用 `SaveRecord(1)`：
```lua
local SLOTS = { "r1.grp", "r1.idx", "r1.ovr" }   -- ← 只有 r1.*
...
SaveRecord(1)                                     -- ← 还写 d1.grp / s1.grp
```

`SaveRecord(1)` 除写 `r1.*` 外，还会触发 `SaveMMap`/`SaveSMap` 写**存档槽 1 的地图/场景数据**
（`d1.grp`/`s1.grp`）。但 `SLOTS` 未包含它们 → **永不备份、永不恢复**。

**影响面**：`mod_check.lua` 对**全部 20 个 MOD** 调用 → 每次自检销毁 20 个 MOD 的 `d1.grp`/`s1.grp`。

**与 Slice 2/3 缺陷同源**：Slice 2 修复了 `r1.grp`，Slice 3 修复了 `test_mod_boot` 的 `r1.grp`，
但两者都只覆盖 `r1.*` —— 遗漏了 `d1`/`s1` 槽。

### 4.3 修复

```lua
-- 注意：SaveRecord(1) 除写 r1.* 外，还会写存档槽 1 的地图/场景数据
-- （d1.grp / s1.grp，由 SaveMMap/SaveSMap 触发），因此这些槽也必须
-- 备份并恢复，否则会销毁源自带的 d1.grp/s1.grp。
local SLOTS = { "r1.grp", "r1.idx", "r1.ovr", "d1.grp", "d1.idx", "s1.grp", "s1.idx" }
```

备份/恢复循环本身无需修改（自动覆盖新槽）。

### 4.4 验证

```
=== 修复前记录基线 md5 ===
7b3f195fa18529eb9175dee577cf1730  game/mods/pascal/save/d1.grp
ab90a4a5b40c420e54a8556a6eb691db  game/mods/pascal/save/s1.grp
6a1ed19c4f2cf451ab4d57286b68d3c9  game/mods/pascal/save/r1.grp

=== 运行 mod_check ===
总计: 20 MOD, 通过 20, 失败 0

=== 修复后 md5 ===
7b3f195fa18529eb9175dee577cf1730  game/mods/pascal/save/d1.grp   ← 不变 ✅
ab90a4a5b40c420e54a8556a6eb691db  game/mods/pascal/save/s1.grp   ← 不变 ✅
6a1ed19c4f2cf451ab4d57286b68d3c9  game/mods/pascal/save/r1.grp   ← 不变 ✅

=== 全 MOD save/ 与源一致性 ===
不一致 = 0 ✅
```

### 4.5 回归测试强化

- `testCheckOneDoesNotDeleteProductSaves`：新增断言 `SLOTS` 必须含
  `r1.grp`/`r1.idx`/`r1.ovr`/`d1.grp`/`s1.grp`
- `testProductSaveSlotMatchesSource`：从「只比对 `r1.grp`」扩展为**比对源 `save/` 全部文件**
  （`d1.grp`/`d11.grp`/`r1.grp`/`r11.grp`/`s1.grp`/`s11.grp`/`r1.idx`/`ranger.grp` …），
  实测检查 **≥40 个文件**（实际远超）

**测试数**：958 → **1612**（新断言遍历全部源存档文件）

---

## 5. 零引擎改动（REQ-HS-7）

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/tools/mod_check_one.lua` | `SLOTS` 扩展 | ✅ |
| `game/tests/unit/test_mod_resources.lua` | 断言强化 | ✅ |
| `game/mods/HeavenSword/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice5/**` 等 | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**零引擎改动** —— `hdgrp` 差异由索引驱动加载天然支持。

## 6. 零回归

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **1612/1612** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0` ✅ |
| `mod_audit --all --evidence` | `checked=17 failed=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |
| **全量测试后全 MOD save/** | **不一致 = 0** ✅ |

## 7. 产物清单

| 文件 | 说明 |
|------|------|
| `game/mods/HeavenSword/**` | 构建产物 |
| `game/mods/HeavenSword/diff.md` | 数据差异报告 |
| `game/tools/mod_check_one.lua` | 缺陷 D 修复 |
| `game/tests/unit/test_mod_resources.lua` | 回归测试强化 |

## 8. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/mods/HeavenSword/**` | 构建产物 | ✅ |
| `game/tools/mod_check_one.lua` | 缺陷修复 | ✅ |
| `game/tests/unit/test_mod_resources.lua` | 测试 | ✅ |
| `openspec/changes/allmods-slice5/**` 等 | 文档 | ✅ |

## 9. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| `hdgrp` 125 vs 115 | MOD 内容更多 | 内容差异（索引驱动，零改动） |
| 源有 `r1.idx` 无 `r1.grp` | 模板索引副本 | 覆盖第三种存档形态 |
| **`d1.grp`/`s1.grp` 被销毁** | `SLOTS` 遗漏 d/s 槽 | **缺陷 D，已修复** |
| 测试数 958 → 1612 | 断言遍历全部源存档文件 | 覆盖增强 |

## 10. 结论

**PASS**。REQ-HS-1~7 全部满足。HeavenSword 与基线**结构同形**（`hdgrp` 等条目更多），
**零引擎改动**通过全部验证。

**本 change 的关键产出**：
1. **验证了 `hdgrp` 条目数差异无需引擎改动** —— 引擎索引驱动加载（`idxlen/4`），
   无固定计数常量。此结论可外推到第 2~5 梯队**全部** hdgrp ≠ 115 的 MOD。
2. **发现并修复第 4 个工具缺陷**：`mod_check_one` 的 `SLOTS` 遗漏 `d1.grp`/`s1.grp`，
   导致每次自检销毁 20 个 MOD 的这两个槽。与 Slice 2/3 缺陷同源（都只覆盖 `r1.*`）。

**累计工具缺陷**：SweeOan 1 个 → stronger 2 个 → lostbook 0 个 → HeavenSword **1 个**（共 4 个）。
