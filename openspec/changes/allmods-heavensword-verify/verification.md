# Verification: allmods-heavensword-verify

> Change: `allmods-heavensword-verify` · Slice: `allmods-slice5` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

对 HeavenSword 的构建结果做人工可复核的内容审计；判定 `hdgrp` 125 差异的性质；
确认零引擎改动。记录缺陷 D。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-HSV-1 | `diff.md` 逐条审计 | 15 项 MOD 独有全部有判定，需修复 = 0 | ✅ |
| REQ-HSV-2 | 「基准独有」逐项定性 | 21 项 = 回退原版 19 + save/ 1 + 死文件 1 | ✅ |
| REQ-HSV-3 | MOD 独有内容加载 | 楊千葉/胡斐/程靈素；talk 3315；events 1066；hdgrp 125 | ✅ |
| REQ-HSV-4 | `hdgrp` 差异判定 | 三重判据确认内容差异；判据可外推 | ✅ |
| REQ-HSV-5 | 零引擎改动 | 未触碰 `engine-*/**`、`jyconst.lua`、`reference/**` | ✅ |
| REQ-HSV-6 | 验证报告 | 报告 10 节 + 累计缺陷汇总 | ✅ |

## 3. 实测证据

### 3.1 `diff.md` 逐条审计（REQ-HSV-1/2）

**MOD 独有 15 项**：13 预期资源 + 1 额外战斗（`fight073`）+ 1 `BUILD_INPUT`。**需修复 = 0**。

**基准独有 21 项**：
```
回退原版 19  (d1/d2/d3、r1/r2/r3、s1/s2/s3 的 grp+idx 中除 r1.idx 外 + thing.grp/idx)
在 save/  1  (r1.idx)
死文件    1  (allsinbk.grp)
Σ        21
```
```
CC.D_Filename[1]    = mods/HeavenSword/save/d1.grp   ← 路径指向 save，文件不存在 → 播种
CC.R_GRPFilename[1] = mods/HeavenSword/save/r1.grp   ← 同上
CC.S_Filename[1]    = mods/HeavenSword/save/s1.grp   ← 同上
CC.TempS_Filename   = data/allsinbk.grp              ← 死文件
CC.ThingPicFile[1]  = data/thing.idx                 ← 回退原版
```

**`r1.idx` = `ranger.idx` 副本**：
```
md5 r1.idx     = 3746f89bd755157160d7bc9575d8e2e4
md5 ranger.idx = 3746f89bd755157160d7bc9575d8e2e4  ← 相同
```

### 3.2 `hdgrp` 差异判定（REQ-HSV-4）

| 条件 | 实测 |
|------|------|
| `hdgrp.idx` 大小 | 500 字节 = **125** × 4 |
| `CC.HeadPicFile[1]` | `mods/HeavenSword/data/hdgrp.idx` |
| `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` | 全 `nil` |
| `PicLoadFile` 条目数 | `local num = idxlen/4`（`lib_love.lua:437`） |
| 记录布局常量 | `182`/`190`/`52`/`136` == pascal |
| 字节全覆盖 | `formats=12 checked=197 gaps=0` |

**结论**：`hdgrp` 125 为**内容差异**，引擎索引驱动加载，**零引擎改动**。
**判据可外推**到第 2~5 梯队全部 hdgrp ≠ 115 的 MOD。

### 3.3 MOD 独有内容（REQ-HSV-3）

| 判据 | HeavenSword | pascal | 区分度 |
|------|-------------|--------|--------|
| 主角姓名 | 楊千葉 | 小蝦米 | ✅ |
| `JY.Person[1]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 3315 | 2977 | ✅ |
| 事件脚本数 | 1066 | 1018 | ✅ |
| `hdgrp` 条目数 | 125 | 115 | ✅ |

### 3.4 缺陷 D（详见报告 §5）

```
=== 修复前基线 md5 ===
7b3f195fa18529eb9175dee577cf1730  pascal/save/d1.grp
ab90a4a5b40c420e54a8556a6eb691db  pascal/save/s1.grp

=== 运行 mod_check ===
总计: 20 MOD, 通过 20, 失败 0

=== 修复后 md5 ===
7b3f195fa18529eb9175dee577cf1730  pascal/save/d1.grp   ← 不变 ✅
ab90a4a5b40c420e54a8556a6eb691db  pascal/save/s1.grp   ← 不变 ✅

=== 全 MOD save/ 与源一致性 ===
不一致 = 0 ✅
```

### 3.5 零回归

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **1612/1612** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0` ✅ |
| `mod_audit --all --evidence` | `checked=17 failed=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |
| 全量测试后全 MOD save/ | 不一致 = 0 ✅ |

## 4. 产物清单

| 文件 | 说明 |
|------|------|
| `openspec/changes/allmods-heavensword-verify/reports/heavensword-verify.md` | 验证报告（10 节） |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `openspec/changes/allmods-heavensword-verify/**` | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**本 change 零代码改动**（缺陷 D 修复在 activate 子 change）。

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| `hdgrp` 125 vs 115 | MOD 内容更多 | 内容差异（索引驱动，零改动） |
| `d1.grp`/`s1.grp` 不在 save/ | 源存档包不含 | 归为「回退原版（首次存档时播种）」 |
| 缺陷 D 发现 | `SLOTS` 只列 `r1.*` | 已修复（activate 子 change） |

## 7. 累计工具缺陷（4 个）

| # | Slice | 缺陷 | 根因 |
|---|-------|------|------|
| 1 | 2 | `mod_check_one` 销毁 `r1.grp` | 直接 `os.remove` 真实产物 |
| 2 | 3 | `mod_audit` `kysmod.ini` `in_product` 误判 | 类别级一刀切 |
| 3 | 3 | `test_mod_boot` 销毁 `r1.grp` | 与 #1 同源 |
| 4 | 5 | `mod_check_one` 销毁 `d1.grp`/`s1.grp` | #1 的第三次遗漏 |

## 8. 结论

**PASS**。REQ-HSV-1~6 全部满足。HeavenSword **零引擎改动**通过全部验证。

**关键产出**：
1. 验证 `hdgrp` 差异无需引擎改动（索引驱动），判据可外推到后续全部 MOD。
2. 发现并修复第 4 个工具缺陷（`SLOTS` 遗漏 `d1`/`s1` 槽），回归测试强化为
   「比对源 `save/` 全部文件」。

第 2 梯队剩 `kys-GodsDevils`（天龙八部，hdgrp 129 / fight 92）。

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod HeavenSword
formats=14 checked=200 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **93** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **78** | `lib_love.PlayWAV` |
| png | `png_image` | 3 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 1 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **200** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=197` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=200 gaps=0`（+3） |

`formats=12 → 14` 的原因：`allsin` / `alldef` 被补注册为 `grid_save` 族
（每 MOD 各 1 条记录），故 `formats` +2。`+2` 之外无变化，说明本 MOD 其余格式
**从未少验** —— 旧数字只是过时，不是缺陷。

### 3. 真实支持缺口 —— **已修复**（2026-10-29 更新）

`list/*.bin`（本 MOD 有 **4** 个）原为**引擎完全不读**，现已由
`openspec/changes/allmods-list-bin-support` **落地修复**：

| 文件 | 原状态 | 现状态 |
|------|--------|--------|
| `effect.bin` | 构建器不搬 + 引擎硬编码 53 项替代 | **进产物** `data/effect.bin` + `ModData.LoadEffectTable` 装载，`CC.Effect` 取真实条目数 |
| `match.bin` | 构建器不搬 | **进产物** `data/match.bin`（`CC.ExtraOffense` 的数据侧） |
| `leave.bin` / `levelup.bin` / `*.txt` | 不搬 | **维持不进产物**（`LEGACY`，引擎零消费，有 evidence） |

**实测证据**（详见 `allmods-list-bin-support/verification.md`）：

- `effect.bin` / `match.bin` 在 **20/20** MOD 上逐字节一致地进入 `data/`
- 运行时 `CC.Effect` 项数：pascal **64** / BookCalamity **200**（原硬编码 53）
- `mod_audit` 的 `PENDING` **663 → 581**（`.bin` 残留 **0**），`in_product` **9245 → 9285**
- 负向对照：3 项短文件→`3`、删文件→`53` 兜底、恢复→`64`（三者互斥）

⇒ 本 MOD 的 `effect.bin` 超过 53 项时，`eft >= 53` 的静默退化**已消除**。

### 4. 20 MOD 横向对照

（禁止只报自身数字）

| MOD | total | fight | sound | png | list | slots |
|-----|-------|-------|-------|-----|------|-------|
| mingdong | 831 | 267 | 201 | 338 | 4 | 0 |
| BookCalamity | 589 | 327 | 234 | 2 | 5 | 0 |
| Dragon | 537 | 209 | 80 | 222 | 5 | 0 |
| GodsDevils | 477 | 92 | 78 | 282 | 4 | 0 |
| RiverLake | 415 | 219 | 170 | 1 | 4 | 0 |
| awaken | 342 | 237 | 79 | 1 | 4 | 0 |
| pig3dos | 328 | 180 | 111 | 3 | 4 | 9 |
| ptt | 319 | 162 | 78 | 54 | 4 | 0 |
| pineapple | 300 | 154 | 109 | 3 | 4 | 9 |
| books | 295 | 178 | 84 | 2 | 4 | 6 |
| lyff | 244 | 138 | 78 | 3 | 4 | 0 |
| pig | 243 | 137 | 78 | 3 | 4 | 0 |
| dream | 227 | 123 | 77 | 2 | 4 | 0 |
| loving | 212 | 107 | 77 | 3 | 4 | 0 |
| lostbook | 203 | 97 | 78 | 3 | 4 | 0 |
| HeavenSword | 200 | 93 | 78 | 3 | 4 | 1 |
| SweeOan | 198 | 92 | 78 | 3 | 4 | 0 |
| stronger | 198 | 92 | 78 | 3 | 4 | 0 |
| zheng | 197 | 92 | 78 | 2 | 4 | 0 |

本 MOD `total=200`，在 20 个 MOD 中排 **第 16**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，200 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
