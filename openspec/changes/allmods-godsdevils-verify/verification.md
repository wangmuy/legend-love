# Verification: allmods-godsdevils-verify

> Change: `allmods-godsdevils-verify` · Slice: `allmods-slice6` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-21
> 状态：**done**
> 结论：**PASS**（零缺陷；「基准独有」定性细化为 6/9/8；`hdgrp` 判据第二次外推成功）

## 1. 目标回顾

对 GodsDevils 的构建结果做人工可复核的内容审计；用源码级证据细化 23 项
「基准独有」的定性（发现 6 个 `d/s*.idx` 是死文件）；确认 `hdgrp` 129 差异
的性质；确认零引擎改动。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-GDV-1 | `diff.md` 逐条审计 | 13 项 MOD 独有全部有判定，需修复 = 0 | ✅ |
| REQ-GDV-2 | 「基准独有」逐项定性 | 23 项 = save/ 6 + 死文件 9 + 回退/播种 8 | ✅ |
| REQ-GDV-3 | MOD 独有内容加载 | 蝦米/胡斐/程靈素；talk 4640；events 1123；hdgrp 129 | ✅ |
| REQ-GDV-4 | `hdgrp` 差异判定 | 三重判据确认内容差异；第二次外推成功 | ✅ |
| REQ-GDV-5 | 零引擎改动 | 未触碰 `engine-*/**`、`jyconst.lua`、`reference/**` | ✅ |
| REQ-GDV-6 | 验证报告 | 报告 11 节 | ✅ |

## 3. 实测证据

### 3.1 `diff.md` 逐条审计（REQ-GDV-1/2）

**MOD 独有 13 项**：12 预期资源 + `kysmod.ini`（`BUILD_INPUT`）。**需修复 = 0**。
**无额外战斗**（fight 92 == pascal 92，同集合）。

**基准独有 23 项（细化定性 6/9/8）**：
```
在 save/  6   (d1/d2/r1/r2/s1/s2 .grp —— 源自带，产物与源逐字节一致)
死文件    9   (alldef.idx/allsin.idx/allsinbk.grp
              + d1/d2/d3.idx/s1/s2/s3.idx —— 引擎无 S/D idx 常量)
回退/播种 8   (r1.idx/r2.idx/r3.grp/r3.idx/s3.grp/d3.grp —— 存档槽首次保存生成
              + thing.grp/thing.idx —— CC.ThingPicFile[1]=data/thing.idx)
Σ        23
```

**`d/s*.idx` 死文件判据（源码级）**：
```
jyconst.lua:80  --定义记录文件名。S和D由于是固定大小，因此不再定义idx了。
全仓库 grep "S_IDX\|D_IDX" = 0 命中
LoadRecord/SaveRecord 只读写 CC.R_IDXFilename
```
> 修正了粗粒度分类（「回退原版 14」）中的 6 项误判。可外推规则：后续 MOD 的
> `d/s*.idx` 一律判死文件。

### 3.2 `hdgrp` 差异判定（REQ-GDV-4）——第二次外推

| 条件 | 实测 |
|------|------|
| `hdgrp.idx` 大小 | 516 字节 = **129** × 4 |
| `CC.HeadPicFile[1]` | `mods/GodsDevils/data/hdgrp.idx` |
| 索引驱动 | `lib_love.lua:437` `local num = idxlen/4` |
| 固定计数常量 | 5 个常量全 `nil` |
| 记录布局常量 | `182`/`190`/`52`/`136` == pascal |
| 字节全覆盖 | `formats=12 checked=475 gaps=0` |

**外推链**：HeavenSword（125，首次）→ GodsDevils（129，第二次）——结果一致，
第 3~5 梯队可复用。

### 3.3 MOD 独有内容（REQ-GDV-3）

| 判据 | GodsDevils | pascal | 区分度 |
|------|-----------|--------|--------|
| 主角姓名 | 蝦米 | 小蝦米 | ✅ |
| `JY.Person[1]` | 胡斐/雪山飛狐 | （不同） | ✅ |
| `JY.Person[2]` | 程靈素/毒手藥王 | （不同） | ✅ |
| 对话条目数 | 4640 | 2977 | ✅ |
| 事件脚本数 | 1123 | 1018 | ✅ |
| `hdgrp` 条目数 | 129 | 115 | ✅ |
| fight 数 | 92 | 92 | ❌ 同数，不作为证据 |

### 3.4 第 3 种存档形态（round-trip，activate verification §3.9）

```
save 前: r1.grp=true r1.idx=false r1.ovr=false
LoadRecord(0) → 改名 → SaveRecord(1)（播种 r1.idx + 写 r1.ovr）
LoadRecord(1) = true
回读姓名: 測試改名GD
恢复后: r1.grp=true r1.idx=false r1.ovr=false d1.grp=true s1.grp=true
```
半状态读取由 `jymain.lua:1697-1701` 守卫优雅跳过（不崩溃）。三种存档形态全部覆盖。

### 3.5 零回归

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **1612/1612** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0 bad_evidence=0` ✅ |
| `mod_audit --all --evidence` | `checked=17 failed=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |
| 全量测试后全 MOD save/ | `checked=341 mismatch=0` ✅ |

## 4. 产物清单

| 文件 | 说明 |
|------|------|
| `openspec/changes/allmods-godsdevils-verify/reports/godsdevils-verify.md` | 验证报告（11 节） |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `openspec/changes/allmods-godsdevils-verify/**` | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**本 change 零代码改动**（纯审计 + 报告）。

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| `hdgrp` 129 vs 115 | MOD 内容更多 | 内容差异（索引驱动，零改动） |
| 23 项定性为 6/9/8（非粗粒度 14/6/3） | `d/s*.idx` 引擎无引用 | 死文件判据源码级修正，可外推 |
| fight 92 == pascal 92 | 数量恰好相同 | 不作为内容已加载的证据（负约束） |
| 源自带 `r1.grp` 无 `r1.idx` | MOD 存档包第 3 种形态 | 引擎守卫 + 播种，round-trip 验证 |

## 7. 累计工具缺陷（4 个）

| # | Slice | 缺陷 | 根因 |
|---|-------|------|------|
| 1 | 2 | `mod_check_one` 销毁 `r1.grp` | 直接 `os.remove` 真实产物 |
| 2 | 3 | `mod_audit` `kysmod.ini` `in_product` 误判 | 类别级一刀切 |
| 3 | 3 | `test_mod_boot` 销毁 `r1.grp` | 与 #1 同源 |
| 4 | 5 | `mod_check_one` 销毁 `d1.grp`/`s1.grp` | #1 的第三次遗漏 |

**本 slice 新增 0 个**。

## 8. 结论

**PASS**。REQ-GDV-1~6 全部满足。GodsDevils **零引擎改动、零代码改动**通过全部验证。

**关键产出**：
1. `hdgrp` 判据第二次外推成功（129），外推链建立。
2. 「基准独有」定性从粗粒度细化到源码级（6/9/8）：`d/s*.idx` = 死文件
   （引擎无 S/D idx 常量）——可外推规则。
3. 第 3 种存档形态 round-trip 验证通过，三种形态全部覆盖。

**第 2 梯队收官**（HeavenSword 缺陷 1 → GodsDevils 缺陷 0）。

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod GodsDevils
formats=14 checked=477 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **92** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **78** | `lib_love.PlayWAV` |
| png | `png_image` | 282 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **477** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=475` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=477 gaps=0`（+2） |

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

本 MOD `total=477`，在 20 个 MOD 中排 **第 4**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，477 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
