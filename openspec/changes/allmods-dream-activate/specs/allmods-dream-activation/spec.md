---
status: done
created: 2026-10-26
---
# Spec: allmods-dream-activation

> Change: `allmods-dream-activate`　|　Slice 14 子 change 1/2
> MOD：`kys-dream`（笑梦游记）→ 产物 `game/mods/dream/`

---

## REQ-DRM-1 构建产物

**Given** 源 `../reference/allmods/kys-dream`（416 文件）
**When** 执行 `lua tools/mod_build.lua kys-dream`
**Then** 必须输出：

```
[mod_build] kys-dream: data files=280, saves=27, sound=77, events=4569, talk=6464
[mod_build] diff -> tools/../mods/dream/diff.md
```

**And** 目录 `game/mods/dream/data/` 实测 **281** 个文件
**And** 差 1 的原因必须声明：`ranger.str` 由 `tools/mod_encoding.lua` 生成，
**不计入**构建器的 `data files`（同 books 口径，**不是矛盾**）

---

## REQ-DRM-2 穷举审计闭合

**Given** 源 416 文件
**When** 执行 `lua tools/mod_audit.lua --mod dream --evidence`
**Then** 必须输出：

```
total=416 in_product=383 not_in_product=33 unclassified=0 bad_evidence=0
  REQUIRED             378
  REQUIRED_CONVERTED   4
  LEGACY               3
  DEAD_FILE            1
  BUILD_INPUT          1
  PENDING              29
evidence: checked=9 failed=0
```

**And** `378 + 4 + 3 + 1 + 1 + 29 = 416` ✅（不变量：类别之和 == 源文件总数）
**And** `unclassified = 0`、`bad_evidence = 0`
**And** 必须用 `--mod dream`（**不是**位置参数，位置参数会静默审计 20 个 MOD）

---

## REQ-DRM-3 字节级覆盖

**Given** 产物 `game/mods/dream/data/`
**When** 执行 `lua tools/format_spec.lua --mod dream`
**Then** 必须输出 `formats=12 checked=225 gaps=0`

**And** `gaps=0` 必须成立（零长段被 `verifyPair` 的 `b > a` 跳过，不计为 gap）

---

## REQ-DRM-4 记录段判据（统一判据第 3 次应用）

**Given** `ranger.idx` = 24B（6 offsets）与 `ranger.grp`
**When** 逐段验算段长与 CC 记录尺寸
**Then** 必须：

```
offsets = [836, 75274, 111754, 118098, 131970, 132270]
seglen  = [74438, 36480, 6344, 13872, 300]
grp     = 132270B    末 offset == grp ✅    tail = 0
```

| 记录 | 段长 | CC 尺寸 | 商 | 余数 | CC 尺寸标准？ |
|------|-----:|--------:|---:|-----:|:-------------:|
| Person | 74438 | 182 | **409** | **0** | ✅ |
| Thing | 36480 | 190 | **192** | **0** | ✅ |
| Scene | 6344 | 52 | **122** | **0** | ✅ |
| Wugong | 13872 | 136 | **102** | **0** | ✅ |
| Shop | 300 | 50 | **6** | **0** | ✅ |

**And** 所有余数必须为 **0**
**And** CC 尺寸必须为**标准值**（182/190/52/136/50，与基线一致）
⇒ 排除「MOD 自定义记录布局」，统一判据成立。

**And** 源 `ranger.idx` 必须被证明**完好**：

```
md5(mods/dream/data/ranger.idx) == md5(../reference/allmods/kys-dream/save/ranger.idx)
```

**And** `RepairIdx` 必须**未触发**：

- 无 `mod_build` 日志输出
- `mods/dream/encoding-report.md` 无 `idxRepaired`
⇒ **dream 不是 `RepairIdx` 案例**，zheng 仍是唯一案例。

---

## REQ-DRM-5 真实启动链路

**Given** 产物就绪、`rm -f active_mod.txt`
**When** 执行 `lua tests/unit/boot_one_mod.lua dream 409 192 122 102 隨小破`
**Then** 必须输出 `RESULT dream: OK`，且 16 条断言全 PASS：

| # | 断言 | 期望 |
|---|------|------|
| 1 | `lib.init` | 无报错 |
| 2 | `JYMainAdapter.init` | 无报错 |
| 3 | `CC.PersonSize` | **182** |
| 4 | `CC.ThingSize` | **190** |
| 5 | `CC.SceneSize` | **52** |
| 6 | `CC.WugongSize` | **136** |
| 7 | `LoadRecord(0)` | 无报错 |
| 8 | `PersonNum` | **409** |
| 9 | `ThingNum` | **192** |
| 10 | `SceneNum` | **122** |
| 11 | `WugongNum` | **102** |
| 12 | 主角姓名 | **隨小破** |
| 13 | 扫描字段数 | **> 100**（实际 1618） |
| 14 | 全量字符串 U+FFFD | **0** |
| 15 | 全量字符串控制符 | **0** |
| 16 | 运行时 10 帧 | 无报错 |

**And** 5 个位置参数**全部是规格期望值**（不是运行时实测值）——
若传实测值，断言退化为 `x == x`，构成假通过。

---

## REQ-DRM-6 编码转换与旁路表

**Given** `mods/dream/encoding-report.md`
**When** 读取统计
**Then** 必须：

```
转换字段数 1618  去重复用 855  旁路表条目 763  截断 0  hint 溢出 0
分段: Person 409 / Thing 192 / Scene 122 / Wugong 102
```

**And** `data/ranger.str` 实测必须与「旁路表条目 763」一致：

```
总行 770  有效 763  注释 7
分段: Person 243 / Thing 343 / Scene 82 / Wugong 95 = 763 ✅
字段: Name 513 / Nick 82 / Desc 168 = 763 ✅
唯一值 732 / 重复 31
```

**And** 格式为**逗号分隔**（`id,段,索引,字段,值`），不是 tab 分隔

---

## REQ-DRM-7 `hdgrp` 484

**Given** `hdgrp.idx` = 1936B、`hdgrp.grp` = 944448B
**When** 解析全部 offsets 与段头
**Then** 必须：

```
offs 数 = 484    段数 = 483    offs[0] = 2895    末 off = 944448    tail = 0
483 段 = 411 有效 RLE + 72 零长     头异常 = 0
w: 1..58   h: 1..71
零长块: (381, 69) (480, 3)   Σ = 72
```

**And** `484 offsets` ↔ `483 段`（末 offset 是**哨兵**，不构成段）
**And** 「头异常 = 0」必须成立（411 个非空段全部 `w>0, h>0`）
**And** 必须给基线对照：

```
基线 hdgrp: 115 offsets / 114 段 = PNG 2 + RLE 112 + 零长 0，w 13..56
```

**And** 必须给 `eft` 同家族对照（证明零长是内容特征）：

```
dream eft: 714 offsets / 713 段 = RLE 713，零长 0，头异常 0
```

---

## REQ-DRM-8 `eft` 与基线逐字节相同

**Given** `mods/dream/data/eft.{idx,grp}` 与 `data/eft.{idx,grp}`
**When** 计算 md5
**Then** 必须：

```
dream    eft.idx = 2856B   eft.grp = 691627B
baseline eft.idx = 2856B   eft.grp = 691627B
md5(eft.idx) 相同 ? True
md5(eft.grp) 相同 ? True
```

**And** 必须排除「构建器回退到基线」：`eft.*` **不出现在** `diff.md` 的
`added`/`removed` 中（即产物侧真实存在，只是内容与基线相同）
**And** 必须声明这是 epic 中 `eft` **零改动**的正样本
（对照 books 973 改动、pineapple 1378 改动）

---

## REQ-DRM-9 8 道门禁不回归

**Given** activate 完成
**When** 复跑 8 道门禁
**Then** 必须全绿：

| # | 门禁 | 期望 |
|---|------|------|
| 1 | `lua tests/test_runner.lua` | **1842** 通过 |
| 2 | `mod_build.lua --verify-pascal` | `events=1018, mismatches=0, known-deviations=3` |
| 3 | `mod_build.lua --all` | `20 mods, 0 build failures` |
| 4 | `mod_check.lua` | 20/20 通过 |
| 5 | `mod_audit.lua --all --evidence` | `total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0`，`checked=17 failed=0` |
| 6 | `format_spec.lua --all` | `formats=12 checked=6773 gaps=0` |
| 7 | 门禁 7 脚本（存档槽/模板统计） | 与 Slice 12/13 记录同口径：`槽=341 模板=110 合计=451`，真实问题 **0**（本 change 不改该脚本，仅复跑确认无回归） |
| 8 | `git status --porcelain` | 无意外改动（`jyconst.lua +11/−1` 属 allmods-data-fallback 接线，acceptable） |
