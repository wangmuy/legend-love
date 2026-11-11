# Verification: allmods-lyff-verify

> 状态：**done** · 日期：2026-10-22 · Slice: `allmods-slice8` · Epic: `2026-10-allmods-compat`
> 结论：**PASS**（零缺陷；首个记录数差异 MOD 判定沉淀为统一判据，可外推第 4~5 梯队）

## 1. 目标回顾

逐条审计 lyff 的 `diff.md` 差异，确认所有差异均为预期行为；用非基线值证明 MOD
内容真实加载；判定记录数差异 vs 结构异常；零引擎改动、零回归。

## 2. REQ 追溯矩阵

| REQ | 状态 | 证据 |
|-----|------|------|
| REQ-LYFFV-1 | ✅ | `diff.md` 105 项 MOD 独有逐条定性，需修复 = 0（§3.1） |
| REQ-LYFFV-2 | ✅ | 23 项基准独有逐项定性，无未解释项（§3.1） |
| REQ-LYFFV-3 | ✅ | 非基线值证明内容已加载（§3.3） |
| REQ-LYFFV-4 | ✅ | 326 人物段 + `hdgrp` 178 + 46 场战斗全部判定（§3.2） |
| REQ-LYFFV-5 | ✅ | 零引擎改动（§3.5） |
| REQ-LYFFV-6 | ✅ | `reports/lyff-verify.md`（12 节）+ 本文件 |

## 3. 实测证据

### 3.1 `diff.md` 逐条审计（REQ-LYFFV-1/2）

**MOD 独有 105 项**（§2.1 报告）：额外战斗 46 场 × 2 = 92 + 标准资源 13
（`cloud`/`kdef`/`talk`/`title` 各 grp+idx 8 + `dead/end/open.png` 3 +
`ranger.str` 1 + `kysmod.ini` 1）。需修复 = 0。

**基准独有 23 项**（§2.2 报告）：

| 性质 | 项数 | 说明 |
|------|-----:|------|
| 在 save/（源自带） | 3 | `d1.grp`/`r1.grp`/`s1.grp`，产物逐字节一致 |
| 死文件 | 9 | `alldef.idx`/`allsin.idx`/`allsinbk.grp` + `d1~3.idx`/`s1~3.idx`（`jyconst.lua:80` 引擎无 S/D idx 常量） |
| 回退原版（含播种） | 11 | `d2/d3.grp`、`r1.idx`（首次播种）、`r2/r3.grp`+`.idx`、`s2/s3.grp`、`thing.grp`/`.idx` |

**穷举审计交叉验证**：`total=425 in_product=395 not_in_product=30 unclassified=0`；
30 未进产物 = PENDING 27（music 23 + list bin 4）+ LEGACY 3，无「必需但未进产物」矛盾。

### 3.2 记录数差异 vs 结构异常（REQ-LYFFV-4）

**326 人物段（本 epic 首个记录数差异 MOD）**——4 条机器可验证判据：
① 动态推导（`jymain.lua:1747`，`59332 = 326×182` vs pascal `320×182`）；
② 无固定计数常量；③ 边界记录 `Person[325]` = 枯榮/南帝有效；④ `gaps=0`。
→ 内容差异，零引擎改动。

**判据统一原则**（可外推）：
> 索引驱动 + 无固定计数 + 字节全覆盖 + 边界有效 = 内容差异（零引擎改动）

`hdgrp`（`idxlen/4`）与记录段（`idx[2]-idx[1]`）同属索引驱动。
`hdgrp` 判据第 4 次应用：178（712B = 178×4），外推链 125/129/173/178 一致。

**46 场额外战斗（本 epic 最多）**：`diff.md` 提及 + 产物 `fight*.grp` = 138 +
审计 `REQUIRED`/`in_product=true`，三重确认。

### 3.3 MOD 独有内容验证（REQ-LYFFV-3）

主角 **AAA**（pascal 小蝦米）· `Person[1]` 胡斐/雪山飛狐 · `Person[2]` 程靈素/毒手藥王 ·
边界 `Person[325]` 枯榮/南帝（pascal 不存在）· talk 5655（pascal 2977，epic 最多）·
kdef 1358（pascal 1018）· hdgrp 178（pascal 115）· fight 138（pascal 92）。
Thing/Scene/Wugong 与基线同数——**显式不作为证据**。
`AAA` 解析依赖 `isStringField` 守卫（REQ-LYF-0），回归测试覆盖。

### 3.4 存档（第 3 种形态）

源自带 3 槽（`d1`/`r1`/`s1`，无 `r1.idx`）；产物 6 文件；源自带 3 个逐字节一致
（全量测试后仍一致）；半状态 `LoadRecord(1)` 优雅跳过（`jymain.lua:1697-1701`）；
播种机制 Slice 6 已验证。

### 3.5 零回归 + 零引擎改动（REQ-LYFFV-5）

```
test_runner.lua               → 1613/1613
mod_build --verify-pascal     → mismatches=0 known-deviations=3
mod_build --all               → 20 mods, 0 build failures
mod_check                     → 20/20
mod_audit --all               → total=11220 unclassified=0 bad_evidence=0
mod_audit --all --evidence    → checked=17 failed=0
format_spec --all             → formats=12 checked=6773 gaps=0
全量测试后全 MOD save/ 与源   → mismatch=0
```
未触碰 `engine-love2d/**`、`engine-mud/**`、`jyconst.lua` 常量定义、`reference/allmods/**`。
累计工具缺陷仍为 4 个（本 slice 新增 0）。

## 4. 产物清单

- `openspec/changes/allmods-lyff-verify/reports/lyff-verify.md`（12 节，253 行）
- `openspec/changes/allmods-lyff-verify/verification.md`（本文件）
- `openspec/changes/allmods-lyff-verify/tasks.md`（全部 `[x]`）

## 5. Blast Radius 合规检查

`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ · `game/script/jyconst.lua` ✅ ·
`reference/allmods/**` ✅ · 本 change 零代码改动 ✅

## 6. 偏差记录

无。

## 7. 第 3 梯队进度

pig（173，Slice 7）→ **lyff（178，Slice 8，done）** → ptt（204，Slice 9，收尾）。

## 8. 结论

**PASS**。REQ-LYFFV-1~6 全部满足。关键产出：① 首个记录数差异 MOD 判定（326 人物段）；
② 判据统一原则（记录数差异 = hdgrp 判据同族，可外推第 4~5 梯队）；③ 46 场额外战斗
为本 epic 最多（动态战斗数量再验证）；④ `hdgrp` 判据第 4 次应用成功。

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod lyff
formats=14 checked=244 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **138** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **78** | `lib_love.PlayWAV` |
| png | `png_image` | 3 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **244** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=242` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=244 gaps=0`（+2） |

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

本 MOD `total=244`，在 20 个 MOD 中排 **第 11**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，244 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
