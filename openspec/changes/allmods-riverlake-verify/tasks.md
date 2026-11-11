# Tasks: allmods-riverlake-verify

> 全部任务已完成，证据见 `verification.md` 与 `reports/riverlake-verify.md`。

## 1. `diff.md` 差异报告审计（REQ-RIVV-1）

- [x] 解析 `mods/RiverLake/diff.md` 的 MOD 独有段 → **268** 项
- [x] 独立重算：`grp 132` + `idx 132` + `ini 1` + `png 1` + `str 1` + `txt 1` = 268 ✅
- [x] 细分：`fight*.grp` 127 + `fight*.idx` 127 + 非 fight **14** = 268 ✅
- [x] 重算「基准独有」21 项 = `diff.md` 声称 21 ✅
- [x] 重算 `hdgrp` 252、`fight` 219 = `diff.md` 声称一致 ✅
- [x] `diff.md` 无漏报、无虚报

**Blast Radius**：只读。
**DoD**：三组数字（268 / 21 / 252+219）重算与声称**完全一致**，且 268 的组成可解释。

## 2. 「基准独有」21 项四类定性（REQ-RIVV-2）

- [x] 打印运行时 `CC.*` 解析值（`R_IDXFilename`/`R_GRPFilename`/`S_Filename`/
      `D_Filename`/`ThingPicFile`/`TempS_Filename`/`LoadThingPic`）
- [x] A 类 9 项（`d1`~`d3`/`r1`~`r3`/`s1`~`s3` 的 `.grp`）：源存在 + 产物存在 + **逐字节一致**
- [x] B 类 9 项（对应 `.idx`）：源不存在 + 产物不存在 + `CC.R_IDXFilename[1]` 指向
      **MOD 存档目录** + `SeedSaveSlot(1)` 播种实测（== MOD `ranger.idx` True，
      == 基线 `ranger.idx` False）
- [x] C 类 2 项（`thing.{grp,idx}`）：源 `resource/` 无 + 产物无 + `CC.ThingPicFile`
      指向**基线** `data/` + `CC.LoadThingPic=1`
- [x] D 类 1 项（`allsinbk.grp`）：源无 + 产物无 + `CC.TempS_Filename` 传入
      `LoadSMap`，但 `tmpfilename` 形参**未使用**（`grep` 仅 1 处命中=签名）
- [x] Σ = 9 + 9 + 2 + 1 = **21** ✅
- [x] 补充证据：A 类 6/9 项与基线**尺寸不同**（`d3` 440000≠369600、`r1`~`r3` 各异、`s3` 4915200≠4128768）
- [x] 负约束遵守：无「不确定」「待查」；B 未误归 C/D

**Blast Radius**：只读 + 播种测试临时产物（已清理）。
**DoD**：21 项每项唯一归类 + 逐项机器证据 + Σ=21。

## 3. 268 项 MOD 独有全量归类（REQ-RIVV-3）

- [x] `lua tools/mod_audit.lua --mod RiverLake` → `unclassified=0 bad_evidence=0`
- [x] 254 项 fight 三重确认（`diff.md` 127 / 产物差集 127 / 审计全 REQUIRED）
- [x] 14 项非 fight 逐项归类：`cloud.*` 2 / `kdef.*` 2 / `title.*` 2 / `talk.*` 2 /
      `name.*` 2（LEGACY）/ `kysmod.ini` 1 / `talkutf8.txt` 1 / `ranger.str` 1 / `open.png` 1
- [x] Σ = 254 + 14 = 268 ✅

**Blast Radius**：只读。
**DoD**：`unclassified=0` 且 268 项全部具名归类。

## 4. `not_in_product` 33 项显式证据（REQ-RIVV-4）

- [x] PENDING **27** 逐项列出：`list/{effect,leave,levelup,match}.bin` 4 +
      `music/1..23.mid` 23
- [x] LEGACY **5** 逐项列出：`list/{end,start}.txt` 2 + `resource/name.{grp,idx}` 2 +
      `script/1.lua` 1
- [x] BUILD_INPUT **1**：`resource/talkutf8.txt`
- [x] Σ = 27 + 5 + 1 = **33** ✅
- [x] **显式标注矛盾**：`list/effect.bin` 是 `CC.Effect` 修复所需数据，
      但归 PENDING 不进产物；本 change 不提升（属独立 change）

**Blast Radius**：只读。
**DoD**：33 项逐项文件名 + 类别 + 每类证据。

## 5. 范围外发现记录完整性（REQ-RIVV-5）

- [x] `CC.Effect` 6 要素：现象 / **7/20 MOD** 范围 / `effect.bin`+`UPedit.ini:80` 根因 /
      非致命实测 / 不修复理由 / 修复路径
- [x] 0 字节 fight 6 要素：现象 / **5/20 MOD** 范围 / 源既有根因 / 非致命实测 /
      不修复理由（伪造+索引语义）/ 修复路径
- [x] 两项均写入 activate `verification.md`、本 change `verification.md`、
      `reports/riverlake-verify.md`
- [x] 两项均写入 epic `TODO.md`

**Blast Radius**：`openspec/**`。
**DoD**：每项 6 要素齐备，缺一即不合格。

## 6. 零引擎改动 + 零回归（REQ-RIVV-6）

- [x] 门禁 1：`lua tests/test_runner.lua` → **1842/1842 passed, 0 failed**
- [x] 门禁 2：`lua tools/mod_build.lua --verify-pascal` → `mismatches=0` PASS
- [x] 门禁 3：`lua tools/mod_build.lua --all` → `20 mods, 0 build failures`
- [x] 门禁 4：`lua tools/mod_check.lua` → **20/20**
- [x] 门禁 5：`lua tools/mod_audit.lua --all --evidence` → `unclassified=0 bad_evidence=0`，`failed=0`
- [x] 门禁 6：`lua tools/format_spec.lua --all` → `gaps=0`
- [x] 门禁 7：20 MOD `save/` vs 源 → **451 文件，不一致/残留 = 0**
- [x] 门禁 8：脏态幂等 → `mod_resources` 从脏态起跑 959/959 ✅
- [x] `game/engine-love2d/**` 零改动
- [x] `game/engine-mud/**` 零改动
- [x] `game/script/jyconst.lua` 常量定义零改动
- [x] `reference/allmods/**` 零改动

**Blast Radius**：只读。
**DoD**：8 道门禁全 Green 且四类禁改路径零改动。

## 7. 修复测试工具缺陷 F（ADR-002，第 6 个工具缺陷）

- [x] 定位根因：`test_mod_boot` round-trip 写 `mods/mingdong/save/`，
      仅正常结束时恢复；runner 顺序 `mod_resources`(16) 先于 `mod_boot`(21)
- [x] 确定性复现：`printf 'DIRTY' >> r1.grp` → `mod_resources` 2 条 FAIL
- [x] 修复：新增 `TestModResources.restoreAllProductSaves()`
      （与 `mod_check_one` 的备份+恢复不同，此处为**自愈式按源包重建**）
- [x] 脏态验证：修复后从脏态起跑 → 959/959 passed
- [x] 全量验证：1842/1842 passed
- [x] 记录测试数变化（1622 → 1842，+220 = 覆盖扩充，非新增断言）

**Blast Radius**：`game/tests/unit/test_mod_resources.lua`（允许路径）。
**DoD**：脏态下 `mod_resources` 全 Green 且全量 1842/1842。

## 8. 报告产出（REQ-RIVV-7）

- [x] `reports/riverlake-verify.md` 含 6 章节：
      重算对账 / 21 项逐项表 / 268 项归类表 / 33 项未进产物表 /
      2 项范围外发现 ×6 要素 / 8 道门禁原文
- [x] 读者可只凭报告重算全部数字

**Blast Radius**：`openspec/changes/allmods-riverlake-verify/reports/**`。
**DoD**：6 章节齐备 + 数字可独立重算。

---

## 代码改动汇总

**本 change 唯一代码改动** = `game/tests/unit/test_mod_resources.lua`
（新增 `restoreAllProductSaves()`，修复缺陷 F）。属允许路径，**不触碰引擎/常量/参考数据**。

**零引擎改动**。产物变化仅 `game/mods/RiverLake/**`（构建产物，gitignore）。
