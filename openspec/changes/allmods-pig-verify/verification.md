# Verification: allmods-pig-verify

> Change: `allmods-pig-verify` · Slice: `allmods-slice7` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

对 pig 的构建结果做人工可复核的内容审计；判定 `hdgrp` 173 / fight 137 差异的性质
（判据第 3 次应用）；复核 45 场额外战斗的三重证据；确认零引擎改动。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-PIGV-1 | `diff.md` 逐条审计 | 103 项 MOD 独有全部有判定，需修复 = 0 | ✅ |
| REQ-PIGV-2 | 「基准独有」逐项定性 | 21 项 = 回退原版 11 + save/ 9 + 死文件 1 | ✅ |
| REQ-PIGV-3 | MOD 独有内容加载 | 小小豬/胡斐/程靈素；talk 4123；events 1288；hdgrp 173；fight 137 | ✅ |
| REQ-PIGV-4 | `hdgrp`/fight 差异判定 | 两者均内容差异；判据第 3 次应用成功 | ✅ |
| REQ-PIGV-5 | 45 场额外战斗复核 | 三重证据通过；产物 137 | ✅ |
| REQ-PIGV-6 | 零引擎改动 | 未触碰 `engine-*/**`、`jyconst.lua`、`reference/**` | ✅ |
| REQ-PIGV-7 | 验证报告 | 报告 11 节 + 第 3 梯队进度 | ✅ |

## 3. 实测证据

### 3.1 `diff.md` 逐条审计（REQ-PIGV-1/2）

**MOD 独有 103 项**：额外战斗 90 + `kdef`/`talk`/`cloud`/`title` 8 + PNG 3 +
`ranger.str` 1 + `kysmod.ini` 1。**需修复 = 0**。

**基准独有 21 项**：
```
回退原版 11  (9 个 .idx 变体 + thing.grp/thing.idx)
在 save/  9  (d1.grp d2.grp d3.grp r1.grp r2.grp r3.grp s1.grp s2.grp s3.grp)
死文件    1  (allsinbk.grp)
Σ        21
```

### 3.2 `hdgrp` 差异判定（REQ-PIGV-4）—— 判据第 3 次应用

| # | MOD | hdgrp | 索引驱动 | 无固定计数 | `gaps=0` | 引擎改动 |
|---|-----|------:|:-------:|:---------:|:-------:|:-------:|
| 建立 | HeavenSword | 125 | ✅ | ✅ | ✅ | 0 |
| 外推 | GodsDevils | 129 | ✅ | ✅ | ✅ | 0 |
| **第 3 次** | **pig** | **173** | ✅ | ✅ | ✅ | **0** |

```
$ stat -c%s reference/allmods/kys-pig/resource/hdgrp.idx
692   (= 173 × 4)
```

**结论**：内容差异；判据在 3 个 MOD 上结论一致，可继续外推。

### 3.3 45 场额外战斗（REQ-PIGV-5）

```
fight030: diff提及=2 产物=yes 审计=REQUIRED	true
fight039: diff提及=2 产物=yes 审计=REQUIRED	true
fight137: diff提及=2 产物=yes 审计=REQUIRED	true
fight145: diff提及=2 产物=yes 审计=REQUIRED	true
fight170: diff提及=2 产物=yes 审计=REQUIRED	true
```
```
$ ls game/mods/pig/data/fight*.grp | wc -l
137
```

| # | 证据 | 结果 |
|---|------|------|
| 1 | `diff.md` 提及 | 45 项，各 2 次 |
| 2 | 产物存在 | 137 |
| 3 | 审计归类 | `REQUIRED` + `in_product=true` |

### 3.4 MOD 独有内容（REQ-PIGV-3）

| 判据 | pig | pascal | 区分度 |
|------|-----|--------|--------|
| 主角姓名 | 小小豬 | 小蝦米 | ✅ |
| `JY.Person[1]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 4123 | 2977 | ✅ |
| 事件脚本数 | 1288 | 1018 | ✅ |
| `hdgrp` 条目数 | 173 | 115 | ✅ |
| 战斗数 | 137 | 92 | ✅ |

### 3.5 存档（缺陷 D 修复完整性）

21 个产物 save 文件与源逐字节一致（含 `mod_check` 与全量测试后）：
```
d11.grp  d1.grp  d2.grp  d3.grp  d4.grp  d5.grp  d6.grp
r11.grp  r1.grp  r2.grp  r3.grp  r4.grp  r5.grp  r6.grp
s11.grp  s1.grp  s2.grp  s3.grp  s4.grp  s5.grp  s6.grp
```

**全 MOD save 完整性（全量测试后）**：**341** 个文件，`不一致 = 0` ✅
→ 9 个源自带存档（含 `d2`/`d3`/`r2`/`r3`/`s2`/`s3`）完好，修复完整性验证通过。

### 3.6 零回归

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **1612/1612** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0` ✅ |
| `mod_audit --all --evidence` | `checked=17 failed=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |
| 全量测试后全 MOD save/ | 341 文件，不一致 = 0 ✅ |

## 4. 产物清单

| 文件 | 说明 |
|------|------|
| `openspec/changes/allmods-pig-verify/reports/pig-verify.md` | 验证报告（11 节） |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `openspec/changes/allmods-pig-verify/**` | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**本 change 零代码改动**。

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| `hdgrp` 173 vs 115 | MOD 内容更多 | 内容差异（索引驱动，零改动） |
| kdef 1288 / talk 4123 | MOD 内容更多 | 内容差异 |
| fight 137 vs 92（+45） | MOD 额外战斗 | 内容差异（索引驱动） |
| 9 个源自带存档 | 比第 2 梯队更多 | 缺陷 D 修复完整性检验 |
| 103 项 MOD 独有 | 本 epic 目前最多 | 按类别分解审计 |

## 7. 第 3 梯队进度

| Slice | MOD | hdgrp | fight | 缺陷 |
|-------|-----|------:|------:|------|
| **7** | **pig** | **173** | **137** | **0** |
| 8 | lyff | 178 | 138 | 待做 |
| 9 | ptt | 204 | 162 | 待做 |

**累计工具缺陷**：4 个（Slice 2/3/5）。

## 8. 结论

**PASS**。REQ-PIGV-1~7 全部满足。pig **零引擎改动、零代码改动**通过全部验证。

**关键产出**：
1. **`hdgrp` 判据第 3 次应用成功** —— 3 个 MOD（125/129/173）结论一致。
2. **45 场额外战斗三重确认** —— 验证了 `fightNNN` 索引驱动加载。
3. **缺陷 D 修复完整性验证** —— 9 个源自带存档完好。
4. **103 项 MOD 独有全部有判定**。

下一 MOD：`kys-lyff`（刘亦纷飞版，hdgrp 178 / fight 138）。

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod pig
formats=14 checked=243 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **137** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **78** | `lib_love.PlayWAV` |
| png | `png_image` | 3 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **243** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=241` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=243 gaps=0`（+2） |

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

本 MOD `total=243`，在 20 个 MOD 中排 **第 12**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，243 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
