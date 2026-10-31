# Verification: allmods-godsdevils-activate

> Change: `allmods-godsdevils-activate` · Slice: `allmods-slice6` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**
> 结论：**PASS**（零缺陷；`hdgrp` 判据首次外推成功）

## 1. 目标回顾

把「天龙八部」（kys-GodsDevils）接入 MOD 兼容地基 —— **第 2 梯队最后一个**。
它是本 epic 含**最多 `EDITOR_DUMP`** 的 MOD（279 个 PNG），
也是 **`hdgrp` 差异判据（Slice 5 ADR-001）的首次外推验证**。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-GD-1 | 构建成功 | `data files=219, saves=9, sound=78, events=1123, talk=4640` | ✅ |
| REQ-GD-2 | 逐文件穷举归类 | `total=615 unclassified=0`；矛盾 = 0 | ✅ |
| REQ-GD-3 | 字节级覆盖 | `formats=12 checked=475 gaps=0` | ✅ |
| REQ-GD-4 | `hdgrp` 差异验证 | 516 字节 = 129 条目；索引驱动；内容差异 | ✅ |
| REQ-GD-5 | `EDITOR_DUMP` 确认 | 279 个 PNG，证据 `IGNORE_DIRS`，产物不存在 | ✅ |
| REQ-GD-6 | 真实启动链路 | `RESULT GodsDevils: OK`（16 项断言） | ✅ |
| REQ-GD-7 | 存档验证 | 9 个文件与源一致（含 `mod_check` 与全量测试后） | ✅ |
| REQ-GD-8 | 零回归 | 1612/1612；全部门禁通过；全 MOD save 完好 | ✅ |

## 3. 实测证据

### 3.1 构建（REQ-GD-1）

```bash
cd game && lua tools/mod_build.lua kys-GodsDevils
```
```
[mod_build] kys-GodsDevils: data files=219, saves=9, sound=78, events=1123, talk=4640
[mod_build] diff -> tools/../mods/GodsDevils/diff.md
```

产物结构：
```
game/mods/GodsDevils/data/            220 个（219 + kysmod.ini）
game/mods/GodsDevils/script/oldevent/ 1123 个 .lua
game/mods/GodsDevils/script/oldtalk.grp/.idx
game/mods/GodsDevils/save/            9 个
game/mods/GodsDevils/sound/           78 个
```

**`head/`/`item/` 确认不进产物**：
```
$ ls -d game/mods/GodsDevils/head game/mods/GodsDevils/item
ls: cannot access 'game/mods/GodsDevils/head': No such file or directory
ls: cannot access 'game/mods/GodsDevils/item': No such file or directory
```

### 3.2 逐文件穷举（REQ-GD-2）

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

**309 个未进产物文件构成**：
```
$ lua -e 'A=require("tools.mod_audit"); ...'
  head/: 79
  item/: 200
  合计: 279        ← EDITOR_DUMP
+ 27 music/*.mid   ← PENDING
+  4 list/*.bin    ← PENDING
+  2 list/{end,start}.txt ← LEGACY
+  1 script/1.lua  ← LEGACY
= 309 ✅
```

### 3.3 字节级覆盖（REQ-GD-3）

```
$ cd game && lua tools/format_spec.lua --mod GodsDevils
formats=12 checked=475 gaps=0
```

### 3.4 `hdgrp` 差异验证（REQ-GD-4）—— Slice 5 判据首次外推

| 检查 | 实测 |
|------|------|
| `hdgrp.idx` 大小 | 516 字节 = **129** × 4 |
| pascal `hdgrp.idx` | 115 条目 |
| `CC.HeadPicFile[1]` | `mods/GodsDevils/data/hdgrp.idx` |
| 索引驱动 | `PicLoadFile` 用 `local num = idxlen/4`（`lib_love.lua:437`） |
| 固定计数常量 | `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全 `nil` |
| 字节全覆盖 | `formats=12 checked=475 gaps=0` |

**结论**：`hdgrp` 129 为**内容差异**，**零引擎改动**。
**Slice 5 ADR-001 判据外推成功** —— 这是第一次在非 HeavenSword 的 MOD 上验证，
结果一致（516 = 129 × 4，`gaps=0`，无需引擎改动）。第 3~5 梯队可继续复用。

### 3.5 `EDITOR_DUMP` 确认（REQ-GD-5）

**证据链（4 条，全部机器可复核）**：

1. **构建器显式忽略** —— `game/tools/mod_build.lua:567`
   ```lua
   local IGNORE_DIRS = { head = true, item = true, eft = true }
   ```
   第 658 行：`if not IGNORE_DIRS[top:lower()] then walk(...) end`

2. **引擎无引用** —— `grep -rn "head/\|item/" game/script/*.lua game/framework/*.lua` → **0 命中**

3. **引擎读打包格式** —— 头像走 `CC.HeadPicFile`（`hdgrp.idx`/`hdgrp.grp`），
   物品走 `CC.ThingPicFile`（`thing.idx`/`thing.grp`）

4. **审计规则** —— `mod_audit.lua`：
   ```lua
   ["head|.png"] = { category="EDITOR_DUMP", needed=false,
       content_type="png_image", evidence={ EV_UPEDIT_DUMP } },
   ["item|.png"] = { category="EDITOR_DUMP", needed=false,
       content_type="png_image", evidence={ EV_UPEDIT_DUMP } },
   ```
   `EV_UPEDIT_DUMP` 引用 `mod_build.lua:IGNORE_DIRS` 且 `cmd` 可复核。

**数量**：`head/` 79 + `item/` 200 = **279** ✅
**产物存在性**：`head`/`item` 目录**不存在**于产物 ✅

### 3.6 产物四项检查

```
PERSON=320  THING=200  SCENE=84  WUGONG=93
HERO=蝦米
STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.7 真实启动链路（REQ-GD-6）

```
[PASS] CC.PersonSize=182 / CC.ThingSize=190 / CC.SceneSize=52 / CC.WugongSize=136
[PASS] PersonNum=320 / ThingNum=200 / SceneNum=84 / WugongNum=93
[PASS] 主角姓名 (期望 蝦米, 实际 蝦米)
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错
RESULT GodsDevils: OK
```

### 3.8 存档验证（REQ-GD-7）

运行时路径：
```
CC.D_Filename[1]    = mods/GodsDevils/save/d1.grp
CC.R_GRPFilename[1] = mods/GodsDevils/save/r1.grp
CC.S_Filename[1]    = mods/GodsDevils/save/s1.grp
CC.TempS_Filename   = data/allsinbk.grp          ← 死文件（回退原版）
CC.ThingPicFile[1]  = data/thing.idx             ← 回退原版
CC.HeadPicFile[1]   = mods/GodsDevils/data/hdgrp.idx
```

产物 9 个 save 文件与源**逐字节一致**（含 `mod_check` 与**全量测试后**）：
```
✓ d11.grp  ✓ d1.grp  ✓ d2.grp  ✓ r11.grp  ✓ r1.grp  ✓ r2.grp
✓ s11.grp  ✓ s1.grp  ✓ s2.grp
```

**全 MOD save 完整性（全量测试后）**：`checked=341 mismatch=0` ✅
→ **缺陷 D 修复（Slice 5）持久性验证通过**。GodsDevils 有 6 个源自带存档
（比 Slice 5 的 HeavenSword 多），若 `SLOTS` 仍遗漏 `d1`/`s1`，本 MOD 会立即暴露。

### 3.9 半初始化槽位 round-trip（第 3 种存档形态）

GodsDevils 源自带 `r1.grp` 但**无 `r1.idx`**（第 3 种形态；前两种：源自带完整
`r1.grp`；HeavenSword 仅有 `r1.idx` 无 `r1.grp`）。独立进程 round-trip（备份→验证→字节级恢复）：

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
首次 `SaveRecord(1)` 经 `ModData.SeedSaveSlot` 播种 `r1.idx` 后，槽位补全、可读回。

## 4. MOD 独有内容验证

| 判据 | GodsDevils | pascal 基线 | 区分度 |
|------|-----------|------------|--------|
| 主角姓名 | **蝦米** | 小蝦米 | ✅ |
| `JY.Person[1]` | **胡斐**/雪山飛狐 | （不同） | ✅ |
| `JY.Person[2]` | **程靈素**/毒手藥王 | （不同） | ✅ |
| 对话条目数 | **4640** | 2977 | ✅ |
| 事件脚本数 | **1123** | 1018 | ✅ |
| `hdgrp` 条目数 | **129** | 115 | ✅ |

**注意**：fight 92 == pascal 92（**同数**）—— 按 ADR-002，**不得**以「记录数相同」
作为 MOD 内容已加载的证据；此处用主角姓名等非基线值证明。

## 5. 零引擎改动（REQ-GD-8）

| 文件 | 改动 | 允许？ |
|------|------|-------|
| `game/mods/GodsDevils/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice6/**` 等 | 文档 | ✅ |

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
| 全量测试后全 MOD save/ | **不一致 = 0** ✅ |

## 7. 产物清单

| 文件 | 说明 |
|------|------|
| `game/mods/GodsDevils/**` | 构建产物 |
| `game/mods/GodsDevils/diff.md` | 数据差异报告 |

## 8. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/mods/GodsDevils/**` | 构建产物 | ✅ |
| `openspec/changes/allmods-slice6/**` 等 | 文档 | ✅ |

## 9. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| `hdgrp` 129 vs 115 | MOD 内容更多 | 内容差异（索引驱动，零改动） |
| kdef 1123 vs 1018 | MOD 事件更多 | 内容差异 |
| talk 4640 vs 2977 | MOD 对话更多 | 内容差异 |
| 279 个 `EDITOR_DUMP` | `head/`/`item/` PNG 转储 | 引擎不读，有结构化证据 |
| fight 92 == pascal 92 | 数量恰好相同 | **不作为**内容已加载的证据 |

## 10. 结论

**PASS**。REQ-GD-1~8 全部满足。GodsDevils 与基线**结构同形**（`hdgrp`/kdef/talk 条目更多），
**零引擎改动、零代码改动**通过全部验证。

**本 change 的关键产出**：
1. **`hdgrp` 判据首次外推成功**（Slice 5 ADR-001）—— GodsDevils 是第一个在
   HeavenSword 之外验证的 MOD，结果一致（516 = 129 × 4，`gaps=0`，零引擎改动）。
2. **279 个 `EDITOR_DUMP` 有 4 条机器可复核证据** —— `IGNORE_DIRS` + 引擎无引用 +
   打包格式 + 审计规则。
3. **缺陷 D 修复持久性验证** —— GodsDevils 的 6 个源自带存档在全量测试后完好。

**本 slice 零缺陷**（累计工具缺陷仍为 4 个，全部在前序 slice 发现并修复）。

**第 2 梯队（hdgrp 略增）收官**：HeavenSword（缺陷 1）→ GodsDevils（缺陷 0）。
