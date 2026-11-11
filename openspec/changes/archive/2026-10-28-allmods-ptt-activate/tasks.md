# Tasks: allmods-ptt-activate

## 1. 构建（REQ-PTT-1）

- [x] `cd game && lua tools/mod_build.lua kys-ptt` → 退出码 0
- [x] 产物计数：`data files=362, saves=21, sound=78, events=1229, talk=5689`
- [x] `diff.md` 生成（`mods/ptt/diff.md`）

**Blast Radius**：仅 `game/mods/ptt/**`（构建产物，gitignore）。

**DoD**：`events=1229` 且 `talk=5689` 且 `fight*.grp` = 162。

## 2. 逐文件穷举审计（REQ-PTT-2）

- [x] `lua tools/mod_audit.lua --mod ptt` → `total=596 in_product=459 not_in_product=137 unclassified=0 bad_evidence=0`
- [x] 类别分布 Σ=596：REQUIRED 454 / REQUIRED_CONVERTED 4 / LEGACY 3 / EDITOR_DUMP 105 /
      BUILD_INPUT 2 / PLATFORM_ARTIFACT 1 / PENDING 27
- [x] 「必需但未进产物」矛盾数 = 0

**Blast Radius**：只读（`reference/allmods/kys-ptt/` + 产物），无修改。

**DoD**：`unclassified=0 bad_evidence=0` 且 Σ(类别)=596。

## 3. 字节级覆盖（REQ-PTT-3）

- [x] `lua tools/format_spec.lua --mod ptt` → `formats=12 checked=317 gaps=0`

**Blast Radius**：只读。

**DoD**：`gaps=0`。

## 4. `hdgrp` 差异验证（REQ-PTT-4）

- [x] `hdgrp.idx` = 816 字节 = 204 条目（pascal 115）
- [x] 索引驱动：`PicLoadFile` 用 `idxlen/4`（`lib_love.lua:437`）
- [x] 无固定计数常量（`CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM` 全 `nil`）
- [x] `format_spec` `gaps=0` 佐证
- [x] 判定：内容差异（判据第 5 次应用：125/129/173/178/204）

**Blast Radius**：只读。

**DoD**：三重判据全部机器可验证且结论一致。

## 5. 4 段记录数差异验证（REQ-PTT-5）

- [x] Person 70070=385×182、Thing 40660=214×190、Scene 4680=90×52、
      Wugong 14688=108×136、Shop 150=3×50（全部整除）
- [x] 索引驱动：`JY.PersonNum=(idx[2]-idx[1])/CC.PersonSize`（`jymain.lua:1747`）等
- [x] 边界有效：末条记录 tail32 含有效 hint（`P0489`/`N0448`/`T0395`/`T20395`/`S0088`/`W0107`）
- [x] 判定：内容差异（统一判据第 2 次应用，首个全段差异 MOD）

**Blast Radius**：只读。

**DoD**：4 段全部整除 + 边界可读 + `gaps=0`。

## 6. 70 场额外战斗验证（REQ-PTT-6）

- [x] `diff.md` 提及 140 个 fight 文件（70×2）
- [x] 产物 `fight*.grp` = 162（pascal 92 + 70）
- [x] 抽样审计归类：`fight/fight104.grp` = `REQUIRED`/`in_product=true`/`needed=true`
- [x] 70 场编号清单见 `change-manifest.md` Contract F

**Blast Radius**：只读。

**DoD**：三重确认全部通过。

## 7. 产物四项检查

- [x] `MOD_SLUG=ptt lua tools/mod_check_one.lua` →
      `PERSON=385 THING=214 SCENE=90 WUGONG=108 HERO=鄉民 STRINGS=OK EVENTS=OK SAVE=OK`

**Blast Radius**：`mods/ptt/save/`（备份+恢复，验证后无残留）。

**DoD**：四项全 OK。

## 8. 真实启动链路（REQ-PTT-7）

- [x] `lua tests/unit/boot_one_mod.lua ptt 385 214 90 108 鄉民` → `RESULT ptt: OK`
- [x] 16 项断言全 PASS（扫描字段 1610、0 U+FFFD、0 控制符、10 帧无报错）

**Blast Radius**：`mods/ptt/save/`（备份+恢复）。

**DoD**：`RESULT ptt: OK`。

## 9. 存档验证（REQ-PTT-8）

- [x] 产物 `save/` 21 个文件（`d1`~`d6`/`r1`~`r6`/`s1`~`s6` + `d11`/`r11`/`s11`）
      与源 `reference/allmods/kys-ptt/save/` 逐字节一致（21/21）
- [x] 源自带 18 个存档槽（本 epic 最多）
- [x] 运行时 `CC.D_Filename[1]`/`R_GRPFilename[1]`/`S_Filename[1]` 指向 `mods/ptt/save/`

**Blast Radius**：`mods/ptt/save/`（备份+恢复）。

**DoD**：21/21 逐字节一致。

## 10. 零回归（REQ-PTT-9）

- [x] 全量门禁 7/7（见 `verification.md` §6）

**Blast Radius**：无代码改动（`git diff` 无 engine/framework/script 路径）。

**DoD**：门禁全绿。

## 11. 验证

- [x] 写 `verification.md`（REQ 追溯矩阵 + 实测证据 + 偏差记录）
