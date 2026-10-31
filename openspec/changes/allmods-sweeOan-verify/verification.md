# Verification: allmods-sweeOan-verify

> Change: `allmods-sweeOan-verify` · Slice: `allmods-slice2` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

对 `allmods-sweeOan-activate` 的构建结果做**人工可复核的内容审计**：
逐条核对 `diff.md` 差异，确认 MOD 独有内容确实被加载，并确认零引擎改动。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-SWEEV-1 | `diff.md` 逐条审计 | 14 项 MOD 独有全部有判定，需修复 = 0 | ✅ |
| REQ-SWEEV-2 | 「基准独有」逐项定性 | 23 项 = 回退原版 16 + 在 save/ 4 + 死文件 3，无未解释 | ✅ |
| REQ-SWEEV-3 | MOD 独有内容加载 | 王小石/衛悲回/伊小深（非基线值）；路径全指向 MOD | ✅ |
| REQ-SWEEV-4 | 零引擎改动 | 未触碰 `engine-*/**`、`jyconst.lua` 常量、`reference/**` | ✅ |
| REQ-SWEEV-5 | 验证报告 | `reports/sweeOan-verify.md`（8 节） | ✅ |
| REQ-SWEEV-6 | 缺陷已修复 + 回归 | `mod_check_one.lua` 修复；+2 回归测试；修复前后证据完整 | ✅ |

## 3. 实测证据

### 3.1 `diff.md` 逐条审计（REQ-SWEEV-1）

**MOD 独有（14 项）**：12 项预期资源进产物、1 项 `BUILD_INPUT`（`kysmod.ini`）、
1 项死文件（`修改档说明.txt`）。**需修复 = 0**。

### 3.2 「基准独有」定性（REQ-SWEEV-2）

运行时 `CC.*` 交叉验证：

```
CC.R_IDXFilename[1] = mods/SweeOan/save/r1.idx     ← 在 save/
CC.R_GRPFilename[1] = mods/SweeOan/save/r1.grp     ← 在 save/
CC.D_Filename[1]    = mods/SweeOan/save/d1.grp     ← 在 save/
CC.S_Filename[1]    = mods/SweeOan/save/s1.grp     ← 在 save/
CC.TempS_Filename   = data/allsinbk.grp            ← 死文件（0 引用）
CC.ThingPicFile[1]  = data/thing.idx               ← 回退原版
```

分类：**回退原版 16 + 在 save/ 4 + 死文件 3 = 23** ✅ 无未解释项。

### 3.3 MOD 独有内容（REQ-SWEEV-3）

| 判据 | SweeOan | pascal | 区分度 |
|------|---------|--------|--------|
| 主角姓名 | 王小石 | 小蝦米 | ✅ |
| `JY.Person[1]` | 衛悲回 | （不同） | ✅ |
| `JY.Person[2]` | 伊小深 | （不同） | ✅ |

（对话/事件条目数与基线相同 → **不作证据**，符合 ADR-002）

### 3.4 缺陷修复（REQ-SWEEV-6）

**修复前**（mingdong）：
```
源     reference/allmods/kys-mingdong/save/r1.grp = 222888 B
产物   game/mods/mingdong/save/r1.grp             = 223688 B   ← SaveRecord(1) 覆盖
残留   game/mods/mingdong/save/r1.idx / r1.ovr
```

**根因**：`mod_check_one.lua` 的存档自检直接 `os.remove` 真实产物目录的 `r1.grp`。

**修复后**（SweeOan）：
```
build:       3240110332f1f663a9828bbcd473a9bb
after check: 3240110332f1f663a9828bbcd473a9bb   ← md5 不变
```

**修复后**（mingdong）：
```
build:       222888 B（与源一致）
after check: 222888 B
无 r1.idx/r1.ovr 残留 ✓
```

**回归测试**：
```bash
lua tests/test_runner.lua mod_resources
→ Results: 85 tests, 85 passed, 0 failed
```
- `testCheckOneDoesNotDeleteProductSaves` ✅
- `testProductSaveSlotMatchesSource` ✅（17 个 MOD 的 `r1.grp` 逐字节一致）

### 3.5 零回归

| 门禁 | 结果 |
|------|------|
| `test_runner.lua` | **907/907** ✅ |
| `--verify-pascal` | `events=1018 mismatches=0` ✅ |
| `--all` | `20 mods, 0 build failures` ✅ |
| `mod_check` | `20 MOD, 通过 20, 失败 0` ✅ |
| `mod_audit --all` | `total=11220 unclassified=0` ✅ |
| `format_spec --all` | `formats=12 checked=6773 gaps=0` ✅ |

## 4. 产物清单

| 文件 | 说明 |
|------|------|
| `openspec/changes/allmods-sweeOan-verify/reports/sweeOan-verify.md` | 验证报告（8 节） |
| `game/tools/mod_check_one.lua` | 修复（备份 + 恢复） |
| `game/tests/unit/test_mod_resources.lua` | +2 回归测试 |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `openspec/changes/allmods-sweeOan-verify/reports/**` | 报告 | ✅ |
| `game/tools/mod_check_one.lua` | 修复 | ✅ |
| `game/tests/unit/test_mod_resources.lua` | +2 测试 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| 「基准独有」分类非 `diff.md` 直接给出 | `diff.md` 只列文件名 | 用运行时 `CC.*` 值定性，更严格 |
| 报告发现 `diff.md` 有盲区（列出不在产物的 `kysmod.ini`） | `diff.md` 只比对 `data/` | 报告注明「穷举审计才是权威」 |
| 本 slice 出现非计划内的工具修复 | 审计发现真实缺陷 | 修复 + 回归测试；属允许路径 |

## 7. 结论

**PASS**。REQ-SWEEV-1~6 全部满足。

本 change 的核心产出是**发现并修复 `mod_check_one.lua` 的数据销毁缺陷**：
该工具会删除每个 MOD 产物的 `r1.grp`（影响全部 20 个 MOD）。
这直接证明了 Slice 0c「穷举驱动 DoD」的价值 —— 旧的 `data/` 目录比对**永远不会**
看到 `save/` 下的这个问题。

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod SweeOan
formats=14 checked=198 gaps=0
```

| 格式 | 族 | 本 MOD 记录数 | 消费者 |
|------|-----|--------------|--------|
| fight | `idx_grp_rle` | **92** | `lib_love.PicLoadFile` |
| sound | `wav_pcm` | **78** | `lib_love.PlayWAV` |
| png | `png_image` | 3 | `lib_love.PicLoadFile`（head/ 直接 PNG） |
| list (`*.bin`) | `bin_table` | 4 | `ModData.LoadEffectTable`（本轮修复，见 §3） |
| save 槽 | `save_slot` | 0 | `jymain.LoadRecord` |
| allsin/alldef | `grid_save` | 2 | `lib_love.LoadSMap`（定长 uint16 网格） |
| 其余单例格式 | 见 spec | 各 1 | 见 `format_spec.lua` 的 `consumer` 字段 |
| **合计** | | **198** | `gaps=0` |

### 2. 数字修正（勘误）

| 旧记录 `formats=12 checked=196` | **已过时**（当时真实值；`formats` 与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=198 gaps=0`（+2） |

`formats=12 → 14` 的原因：`allsin` / `alldef` 被补注册为 `grid_save` 族
（每 MOD 各 1 条），故 `formats` +2。`+2` 之外无变化，说明本 MOD 其余格式
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

本 MOD `total=198`，在 20 个 MOD 中排 **第 17**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，198 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
