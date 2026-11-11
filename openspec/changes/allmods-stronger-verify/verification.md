# Verification: allmods-stronger-verify

> Change: `allmods-stronger-verify` · Slice: `allmods-slice3` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

对 stronger 的构建结果做人工可复核的内容审计；并在过程中修正审计工具的两个缺陷。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实测 | 状态 |
|-----|------|------|------|
| REQ-STRV-1 | `diff.md` 逐条审计 | 13 项 MOD 独有全部有判定，需修复 = 0 | ✅ |
| REQ-STRV-2 | 「基准独有」逐项定性 | 21 项 = 回退原版 17 + save/ 3 + 死文件 1 | ✅ |
| REQ-STRV-3 | MOD 独有内容加载 | 韋大寶/胡斐/程靈素；talk 3727（非基线值） | ✅ |
| REQ-STRV-4 | `kysmod.ini` 判定修正 | 20/20 `in_product=true`；`cc/*.txt` `false`；矛盾 = 0 | ✅ |
| REQ-STRV-5 | 零引擎改动 | 未触碰 `engine-*/**`、`jyconst.lua`、`reference/**` | ✅ |
| REQ-STRV-6 | 报告 + 回归测试 | 报告 8 节；+3 测试；`test_mod_boot` 备份恢复 | ✅ |

## 3. 实测证据

### 3.1 `diff.md` 逐条审计（REQ-STRV-1/2）

**MOD 独有 13 项**：12 项预期资源 + 1 项 `BUILD_INPUT`（`kysmod.ini`，在产物中）。
**需修复 = 0**。

**基准独有 21 项**：
```
回退原版 17  (allsinbk.grp 除外 → 死文件)
在 save/  3  (d1.grp, r1.grp, s1.grp)
死文件    1  (allsinbk.grp)
Σ        21
```

运行时证据：
```
CC.D_Filename[1]    = mods/stronger/save/d1.grp   ← 在 save/
CC.R_GRPFilename[1] = mods/stronger/save/r1.grp   ← 在 save/
CC.S_Filename[1]    = mods/stronger/save/s1.grp   ← 在 save/
CC.TempS_Filename   = data/allsinbk.grp           ← 死文件（0 引用）
CC.ThingPicFile[1]  = data/thing.idx              ← 回退原版
```

### 3.2 MOD 独有内容（REQ-STRV-3）

| 判据 | stronger | pascal | 区分度 |
|------|----------|--------|--------|
| 主角姓名 | 韋大寶 | 小蝦米 | ✅ |
| `JY.Person[1]` | 胡斐 | （不同） | ✅ |
| `JY.Person[2]` | 程靈素 | （不同） | ✅ |
| 对话条目数 | 3727 | 2977 | ✅ |

### 3.3 缺陷 A：`kysmod.ini` `in_product` 误判（REQ-STRV-4）

**修复前**：
```
$ lua -e '...auditAll("stronger")...'
  path=kysmod.ini  category=BUILD_INPUT  in_product=false
$ ls game/mods/stronger/data/kysmod.ini   ← 文件实际存在！
```

**错误尝试**（证明类别级一刀切是错的）：
```
IN_PRODUCT_BY_CATEGORY[BUILD_INPUT] = true
→ 矛盾: BUILD_INPUT openc_cc_dict pascal/cc/STCharacters.txt
→ 矛盾: BUILD_INPUT openc_cc_dict pascal/cc/STPhrases.txt
→ 矛盾: BUILD_INPUT openc_cc_dict pascal/cc/TSCharacters.txt
→ 矛盾: BUILD_INPUT openc_cc_dict pascal/cc/TSPhrases.txt
（4 个矛盾）
```

**修复后**：
```
$ lua tools/mod_audit.lua --all
total=11220 in_product=9245 not_in_product=1975 unclassified=0 bad_evidence=0

$ 矛盾检查
矛盾数 = 0
stronger kysmod.ini in_product = true      ✅
cc: cc/STCharacters.txt in_product = false ✅

$ 20/20 MOD 的 kysmod.ini in_product=true  ✅
```

**证据文本修正**：
```
修复前: ref=game/framework/mod_ini.lua
        text="kysmod.ini 由构建期解析为 CONFIG/CC 覆盖，不进入产物"  ← 与代码矛盾
修复后: ref=game/tools/mod_build.lua
        cmd=grep -n 'kysmod' tools/mod_build.lua
        text="kysmod.ini 由构建器复制到 data/（mod_build.lua:879-882）；引擎不读，..."
```
```
$ lua tools/mod_audit.lua --all --evidence
evidence: checked=17 failed=0 ✅
```

**回归测试**：
```bash
lua tests/test_runner.lua mod_audit
→ Results: 249 tests, 249 passed, 0 failed
```
- `testKysmodIniIsBuildInputButShipped` ✅（20/20 `in_product=true`）
- `testCcDictsAreBuildInputAndNotShipped` ✅（全部 `in_product=false`）

### 3.4 缺陷 B：`test_mod_boot` 销毁产物（REQ-STRV-6）

**修复前**：
```
测试后 mingdong save/r1.grp = 223688 B（源 222888 B）
残留 r1.idx / r1.ovr
```

**修复后**：
```
lua tests/test_runner.lua mod_boot
→ Results: 85 tests, 85 passed, 0 failed
测试后 mingdong save/r1.grp = 222888 B（= 源）✅
无 r1.idx/r1.ovr 残留 ✅
```

**全 MOD 校验**：
```
全部 MOD 的 save/r1.grp 与源 md5 一致: 不一致 = 0 ✅
```

**回归测试**：`testProductSavesNotDestroyedByTests`（`mod_boot.runAll` 末位）✅

### 3.5 零回归

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
| `openspec/changes/allmods-stronger-verify/reports/stronger-verify.md` | 验证报告（8 节） |
| `game/tools/mod_audit.lua` | per-rule `in_product` + 根级候选 + 证据修正 |
| `game/tests/unit/test_mod_audit.lua` | 派生断言 + 2 个新测试 |
| `game/tests/unit/test_mod_boot.lua` | 备份恢复 + 1 个新测试 |
| `MOD_RESOURCE_AUDIT.md` | 重新生成（11220 锚点） |

## 5. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `openspec/changes/allmods-stronger-verify/reports/**` | 报告 | ✅ |
| `game/tools/mod_audit.lua` | 缺陷修复 | ✅ |
| `game/tests/unit/test_mod_audit.lua` | 测试 | ✅ |
| `game/tests/unit/test_mod_boot.lua` | 测试 | ✅ |

**未触碰**：`game/engine-love2d/**` ✅ · `game/engine-mud/**` ✅ ·
`game/script/jyconst.lua` 常量定义 ✅ · `reference/allmods/**` ✅

## 6. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| 首次尝试把 `BUILD_INPUT` 类别改 `true` | 未意识到同类文件产物状态不同 | 产生 4 个矛盾 → 改为 per-rule 覆盖 |
| 35 个测试失败（硬编码计数漂移） | `in_product` 语义修正 | 改为派生断言 |
| `not_in_product` 1995 → 1975 | `kysmod.ini` 20 个重新计入产物 | 全局统计更新 |
| 测试数 907 → 958 | 新增 3 个测试函数 | 覆盖增强 |

## 7. 结论

**PASS**。REQ-STRV-1~6 全部满足。

本 change 修正了**两个工具缺陷**：
1. `mod_audit.lua` 的 `kysmod.ini` `in_product` 误判（+ 与代码矛盾的证据文本）
2. `test_mod_boot.lua` 销毁产物 `r1.grp`（与 Slice 2 的 `mod_check_one` 同源）

两者都印证了 Slice 0c「穷举驱动 DoD」的价值：**数据同形 ≠ 工具链无缺陷**。

---

## 字段/格式支持复核（2026-10-29 补）

> 本节回答：**本 MOD 用到的每个字段与格式，是否都有真实的引擎/构建期消费者支持？**

### 1. 逐格式实测（当前工作树）

```
$ cd game && lua tools/format_spec.lua --mod stronger
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

| 旧记录 `formats=12 checked=196` | **已过时**（当时真实值，但 `formats` 计数与 `checked` 均已被补注册改变） |
| 现值 | `formats=14 checked=198 gaps=0`（+2） |

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

本 MOD `total=198`，在 20 个 MOD 中排 **第 18**。

### 5. 结论

| 维度 | 结论 |
|------|------|
| 字段级覆盖 | ✅ `gaps=0`，198 条记录字节全覆盖 |
| 引擎消费者 | ✅ 除 `list/*.bin` 外全部有真实消费者 |
| `list/*.bin` | ⚠ 已知缺口，由 `allmods-list-bin-support` 修复 |
| 数字准确性 | ✅ 本节已纠正旧记录 |
