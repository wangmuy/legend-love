# Verification: allmods-lostbook-verify

> Change: `allmods-lostbook-verify` · Slice: `allmods-slice4` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

对 lostbook 的构建结果做人工可复核的内容审计；判定 kdef/fight 差异的性质；
确认零引擎改动。**第 1 梯队收官**。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-LOSTV-1 | `diff.md` 逐条审计 | 24 项 MOD 独有全部有判定，需修复 = 0 | ✅ |
| REQ-LOSTV-2 | 「基准独有」逐项定性 | 21 项 = 回退原版 18 + save/ 2 + 死文件 1 | ✅ |
| REQ-LOSTV-3 | MOD 独有内容加载 | 金迷/胡斐/程靈素；talk 3181；events 1071 | ✅ |
| REQ-LOSTV-4 | 内容差异 vs 结构异常 | 三重判据确认内容差异（`gaps=0`） | ✅ |
| REQ-LOSTV-5 | 零引擎改动 | 未触碰 `engine-*/**`、`jyconst.lua`、`reference/**` | ✅ |
| REQ-LOSTV-6 | 验证报告 | 报告 9 节 + 第 1 梯队小结 | ✅ |

## 3. 实测证据

### 3.1 `diff.md` 逐条审计（REQ-LOSTV-1/2）

**MOD 独有 24 项**：17 预期资源 + 5 场额外战斗（10 文件）+ 1 `BUILD_INPUT`。
**需修复 = 0**。

**5 场额外战斗三重确认**：
```
fight039: diff提及=2 产物存在=yes 审计=REQUIRED/in_product=true
fight040: diff提及=2 产物存在=yes 审计=REQUIRED/in_product=true
fight041: diff提及=2 产物存在=yes 审计=REQUIRED/in_product=true
fight042: diff提及=2 产物存在=yes 审计=REQUIRED/in_product=true
fight052: diff提及=2 产物存在=yes 审计=REQUIRED/in_product=true
```

**基准独有 21 项**：
```
回退原版 18  (d2/d3/r2/r3/s2/s3 的 grp+idx, thing.grp/idx, allsinbk.grp 除外)
在 save/  2  (d1.grp, s1.grp)
死文件    1  (allsinbk.grp)
Σ        21
```
运行时证据：
```
CC.D_Filename[1]    = mods/lostbook/save/d1.grp   ← 在 save/
CC.R_GRPFilename[1] = mods/lostbook/save/r1.grp   ← 在 save/（首次播种）
CC.S_Filename[1]    = mods/lostbook/save/s1.grp   ← 在 save/
CC.TempS_Filename   = data/allsinbk.grp           ← 死文件（0 引用）
CC.ThingPicFile[1]  = data/thing.idx              ← 回退原版
```

### 3.2 内容差异判定（REQ-LOSTV-4）

| 条件 | 实测 | 判定 |
|------|------|------|
| 记录布局常量 | `182`/`190`/`52`/`136` == pascal | ✅ |
| 记录数 | `320`/`200`/`84`/`93` == pascal | ✅ |
| 字节全覆盖 | `formats=12 checked=201 gaps=0` | ✅ |

**结论**：kdef 1071（vs 1018）、fight 97（vs 92）为**内容差异**。
若为结构异常，按 pascal 尺寸解析会错位 → `gaps > 0`；实测 `gaps=0`。

### 3.3 MOD 独有内容（REQ-LOSTV-3）

| 判据 | lostbook | pascal | 区分度 |
|------|----------|--------|--------|
| 主角姓名 | 金迷 | 小蝦米 | ✅ |
| `JY.Person[1]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 3181 | 2977 | ✅ |
| 事件脚本数 | 1071 | 1018 | ✅ |

**存档播种**：
```
save 前 r1.grp: false → save 后: true
save 后 r1.idx: true（从 ranger.idx 播种）
save 后 r1.ovr: true（字符串改写）
回读姓名: 测试改名（覆盖表优先）
恢复后 r1.grp: false（无残留）
```

### 3.4 零回归

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **958/958** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0` ✅ |
| `mod_audit --all --evidence` | `checked=17 failed=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |

## 4. 产物清单

| 文件 | 说明 |
|------|------|
| `openspec/changes/allmods-lostbook-verify/reports/lostbook-verify.md` | 验证报告（9 节） |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `openspec/changes/allmods-lostbook-verify/reports/**` | 报告 | ✅ |
| `openspec/changes/allmods-lostbook-verify/*.md` | 文档 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

**本 slice 零代码改动** —— 未发现缺陷。

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| kdef 1071 vs 1018 / fight 97 vs 92 | MOD 内容更多 | 判定为内容差异（三重判据） |
| `r1.grp` 列入「基准独有」 | lostbook 源自带存档包不含槽 1 | 归为「在 save/（首次播种）」 |
| 无缺陷发现 | 工具链已在前两个 slice 修复 | 正面信号 |

## 7. 第 1 梯队收官

| MOD | Slice | 构建 | 穷举 | 字节 | 启动 | 引擎改动 | 缺陷 |
|-----|-------|------|------|------|------|---------|------|
| SweeOan | 2 | ✅ | `unclassified=0` | `gaps=0` | ✅ | 零 | 1 |
| stronger | 3 | ✅ | `unclassified=0` | `gaps=0` | ✅ | 零 | 2 |
| lostbook | 4 | ✅ | `unclassified=0` | `gaps=0` | ✅ | 零 | 0 |

## 8. 结论

**PASS**。REQ-LOSTV-1~6 全部满足。lostbook **零引擎改动**通过全部验证，**未发现缺陷**。

**第 1 梯队（与基线同形）3 个 MOD 全部完成。**
下一梯队为第 2 梯队（hdgrp 125~129）：HeavenSword、GodsDevils。

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod lostbook
formats=14 checked=203 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **97** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **78** | `lib_love.PlayWAV` |
| png | `png_image` | 3 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **203** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=201` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=203 gaps=0`（+2） |

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

本 MOD `total=203`，在 20 个 MOD 中排 **第 15**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，203 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
