# Verification: allmods-lyff-activate

> 状态：**done** · 日期：2026-10-22 · Slice: `allmods-slice8` · Epic: `2026-10-allmods-compat`
> 结论：**PASS**（零引擎改动；**首个记录数差异 MOD**（326 人物段）；`isStringField` 跨 MOD 工具修复 +1）

## 1. 目标回顾

激活 `kys-lyff`（刘亦纷飞版，hdgrp 178 / fight 138 / 人物 326）：构建 → 穷举审计 →
字节覆盖 → 启动链路 → 存档验证，零引擎改动。第 3 梯队第 2 个。

## 2. REQ 追溯矩阵

| REQ | 状态 | 证据 |
|-----|------|------|
| REQ-LYF-0 | ✅ | `isStringField` 守卫 + 8 MOD 重建 + 回归测试（§3.1） |
| REQ-LYF-1 | ✅ | 构建 `events=1358 talk=5655`（§3.2） |
| REQ-LYF-2 | ✅ | `total=425 unclassified=0`，矛盾=0（§3.3） |
| REQ-LYF-3 | ✅ | `formats=12 checked=242 gaps=0`（§3.4） |
| REQ-LYF-4 | ✅ | 326 人物段 = 内容差异（§3.5） |
| REQ-LYF-5 | ✅ | `hdgrp` 178 = 内容差异，判据第 4 次应用（§3.6） |
| REQ-LYF-6 | ✅ | `PERSON=326 … SAVE=OK`（§3.7） |
| REQ-LYF-7 | ✅ | `RESULT lyff: OK`（§3.8） |
| REQ-LYF-8 | ✅ | 存档第 3 种形态 + 字节一致（§3.9） |
| REQ-LYF-9 | ✅ | 零引擎改动（§3.10） |

## 3. 实测证据

### 3.1 `isStringField` 守卫（REQ-LYF-0）——跨 MOD 工具修复

lyff `Person[0].姓名` 源字节为纯 ASCII `AAA`（无 Big5 高字节）。原 `hasHighByte`
守卫把纯 ASCII 文本当数值槽中和成空串，导致启动链路 `HERO=` 为空。

**修复**（`game/tools/mod_encoding.lua`）：字符串判定 = 含高字节 **或**（全可打印
ASCII 且长度 ≥ 2）。单字节残留（`" "`、`"<"`、`"K"` 等）仍判为数值槽。

| MOD | 修复字段 | 值 |
|-----|---------|-----|
| lyff | `Person[0].姓名` | `AAA` |
| HeavenSword | `Person[74].姓名` | `killer-G` |
| GodsDevils | `Person[191].外号` | `123` |
| ptt | `Scene[64].名称` | `PTT` |
| dream | `Thing[80].名称`/`别名` | `------` ×2 |

- 重建 8 MOD（lyff + HeavenSword/GodsDevils/ptt/dream/pig3dos/pineapple/zheng）
- 回归测试：`test_mod_encoding.lua`「ConvertRanger 保留纯 ASCII 文本」断言 lyff `AAA`
  （测试数 1612 → 1613）
- 单字节噪声全保留：zheng 31 条、pineapple 623 条仍跳过（`-1` 空条目不新增）

### 3.2 构建（REQ-LYF-1）

```
$ lua tools/mod_build.lua kys-lyff
data files=311, saves=6, sound=78, events=1358, talk=5655
```
退出码 0；`game/mods/lyff/diff.md` 生成。

### 3.3 逐文件穷举（REQ-LYF-2）

```
$ lua tools/mod_audit.lua --mod lyff
total=425 in_product=395 not_in_product=30 unclassified=0 bad_evidence=0
  REQUIRED 390 · REQUIRED_CONVERTED 4 · LEGACY 3 · BUILD_INPUT 1 · PENDING 27
```
`Σ = 425`；**矛盾 = 0**。30 未进产物 = PENDING 27（music 23 + list bin 4）+ LEGACY 3。
lyff 无 `head/`/`item/` PNG 副产物（本 epic 无 279 类 EDITOR_DUMP）。

### 3.4 字节级覆盖（REQ-LYF-3）

```
$ lua tools/format_spec.lua --mod lyff
formats=12 checked=242 gaps=0
```

### 3.5 326 人物段（REQ-LYF-4）——本 epic 首个记录数差异

| 判据 | 实测 |
|------|------|
| 动态推导 | `PersonNum = (idx[2]-idx[1])/CC.PersonSize`（`jymain.lua:1747`）；`59332 = 326×182`（pascal `58240 = 320×182`） |
| 无固定计数 | 全仓库无 `PERSON_NUM` 类常量 |
| 边界有效 | `Person[325]` = 枯榮/南帝（可读，非 nil/乱码） |
| 字节全覆盖 | `gaps=0`（含 326 条人物段） |

**结论**：内容差异（+6 人物），零引擎改动。判据与 `hdgrp`（`idxlen/4`）同属索引
驱动，统一为「索引驱动 + 无固定计数 + 字节全覆盖 + 边界有效 = 内容差异」。

### 3.6 `hdgrp` 178（REQ-LYF-5）——判据第 4 次应用

`hdgrp.idx` = 712 字节 = 178 × 4；`CC.HeadPicFile[1] = mods/lyff/data/hdgrp.idx`；
`PicLoadFile` 索引驱动（`lib_love.lua:437`）；固定计数常量全 `nil`；`gaps=0`。
外推链：125 → 129 → 173 → **178**，四次一致。

### 3.7 产物四项检查（REQ-LYF-6）

```
PERSON=326 THING=200 SCENE=84 WUGONG=93 HERO=AAA STRINGS=OK EVENTS=OK SAVE=OK
```

### 3.8 真实启动链路（REQ-LYF-7）

```
$ lua tests/unit/boot_one_mod.lua lyff 326 200 84 93 AAA
RESULT lyff: OK   （16 项断言全 PASS）
```
全量字符串无控制符（期望 0，实际 0）；运行时 10 帧无报错。

### 3.9 存档（REQ-LYF-8）——第 3 种形态

- 源自带 `save/` 10 文件，含 3 个槽（`d1`/`r1`/`s1`，**无 `r1.idx`**）
- 产物 `save/` 6 文件（`d11`/`r11`/`s11` + `d1`/`r1`/`s1`）；源自带 3 个逐字节一致
  （`r1.grp` md5 = `38d143021c82c7063113e5f8123f8d4d`，全量测试后仍一致）
- 半状态 `LoadRecord(1)` 由 `jymain.lua:1697-1701` 守卫优雅跳过（不崩溃）
- 首次 `SaveRecord(1)` 经 `ModData.SeedSaveSlot` 播种 `r1.idx`（机制 Slice 6 已验证）

### 3.10 零引擎改动（REQ-LYF-9）

改动仅：`game/tools/mod_encoding.lua`（跨 MOD 工具修复）+ `game/tests/**` +
`game/mods/lyff/**`（产物）+ `openspec/**`。未触碰 `engine-love2d/**`、
`engine-mud/**`、`jyconst.lua`、`reference/allmods/**`。

## 4. 零回归

```
test_runner.lua                     → 1613/1613
mod_build --verify-pascal           → events=1018 mismatches=0 known-deviations=3
mod_build --all                     → 20 mods, 0 build failures
mod_check                           → 20/20
mod_audit --all                     → total=11220 unclassified=0 bad_evidence=0
mod_audit --all --evidence          → checked=17 failed=0
format_spec --all                   → formats=12 checked=6773 gaps=0
全量测试后全 MOD save/ 与源一致      → mismatch=0
```

## 5. 产物清单

- `game/mods/lyff/`：`data/`（311 文件）、`script/`、`save/`（6 文件）、`sound/`、`diff.md`
- `openspec/changes/allmods-lyff-activate/`：proposal / design / specs / tasks / verification

## 6. Blast Radius 合规检查

- `game/engine-love2d/**` ✅ 未改 · `game/engine-mud/**` ✅ 未改
- `game/script/jyconst.lua` ✅ 未改 · `reference/allmods/**` ✅ 未改
- `game/tools/mod_encoding.lua` ✅ 允许（工具，跨 MOD 修复有 5 MOD 证据 + 回归测试）

## 7. 偏差记录

无。

## 8. 结论

**PASS**。lyff 激活完成：首个记录数差异 MOD 判定为内容差异（零引擎改动）；
`isStringField` 守卫修复 5 MOD 纯 ASCII 文本误丢；全部门禁通过。
