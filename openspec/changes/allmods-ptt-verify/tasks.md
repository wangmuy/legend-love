# Tasks: allmods-ptt-verify

## 1. `diff.md` 逐条审计（REQ-PTTV-1）

- [x] 1.1 154 项「MOD 独有」逐项归类
  Blast Radius: `[]`（只读 `game/mods/ptt/diff.md`）
  DoD:
    - [x] 140 项 = 70 场额外战斗 × (`.grp` + `.idx`)
    - [x] 8 项 = `kdef`/`talk`/`cloud`/`title` 各 `grp`+`idx`
    - [x] 2 项 = `end.png`/`open.png`
    - [x] 1 项 = `ranger.str`（构建产物，源不存在）
    - [x] 1 项 = `kysmod.ini`（`BUILD_INPUT`/`in_product=true`）
    - [x] 1 项 = `talkutf8.txt`（`BUILD_INPUT`/`in_product=false`）
    - [x] 1 项 = `save.zip`（`PLATFORM_ARTIFACT`）
    - [x] Σ = 154；需修复 = 0

- [x] 1.2 审计 total 与源文件总数一致
  Blast Radius: `[]`
  DoD:
    - [x] `mod_audit --mod ptt` → `total=596`
    - [x] `find reference/allmods/kys-ptt -type f | wc -l` → 596
    - [x] `unclassified=0 bad_evidence=0`

## 2. 「基准独有」21 项逐项定性（REQ-PTTV-2）

- [x] 2.1 四类定性（新增「首次播种」类）
  Blast Radius: `[]`
  DoD:
    - [x] 9 项「在 save/」= `d1`~`d3`/`r1`~`r3`/`s1`~`s3` 的 `.grp`，逐字节一致
    - [x] 9 项「首次播种」= 对应 `.idx`（源不存在）
    - [x] 2 项「回退原版」= `thing.grp`/`thing.idx`（`CC.ThingPicFile` → `data/`）
    - [x] 1 项「死文件」= `allsinbk.grp`（`CC.TempS_Filename` 仅作 `LoadSMap` 第 2 实参，引擎形参 `tmpfilename` 零使用）

- [x] 2.2 实测「首次播种」机制
  Blast Radius: `["game/mods/ptt/save/r1.idx"]`（临时产物，验证后删除）
  DoD:
    - [x] 播种前 `r1.idx` 不存在
    - [x] `ModData.SeedSaveSlot(1)` 返回 `mods/ptt/save/r1.idx`
    - [x] 播种后与 `data/ranger.idx` 逐字节一致
    - [x] 清理临时产物

## 3. MOD 独有内容验证（REQ-PTTV-3）

- [x] 3.1 非基线值证明
  Blast Radius: `[]`
  DoD:
    - [x] `Person[0].姓名` = 鄉民（基线 小蝦米）
    - [x] `Thing[0].名称` = 千面人蠻牛（基线 康倍特）
    - [x] `Person[384]` = 卓不凡 / `Thing[213]` = 高昌迷宮地圖（基线无此索引）
    - [x] `PersonNum/ThingNum/SceneNum/WugongNum` = 385/214/90/108（基线 320/200/84/93）
    - [x] talk 5689 / events 1229 / fight 162（基线 2977/1018/92）

- [x] 3.2 回退链路径确认
  Blast Radius: `[]`
  DoD:
    - [x] `CC.HeadPicFile[1]` = `mods/ptt/data/hdgrp.idx`
    - [x] `CC.TalkGrpFile` = `mods/ptt/script/oldtalk.grp`
    - [x] `CC.R_GRPFilename[1]`/`D_Filename[1]`/`S_Filename[1]` = `mods/ptt/save/*`

## 4. 差异 vs 结构异常判定（REQ-PTTV-4）

- [x] 4.1 `hdgrp` 204 判据（第 5 次应用）
  Blast Radius: `[]`
  DoD:
    - [x] `hdgrp.idx` = 816 B = 204 × 4
    - [x] `PicLoadFile` 索引驱动（`lib_love.lua:437` `idxlen/4`）
    - [x] 固定计数常量全 `nil`
    - [x] `format_spec --format hdgrp --mod ptt` → `gaps=0`
    - [x] 外推链 125 → 129 → 173 → 178 → 204

- [x] 4.2 4 段记录数判据（第 2 次应用，首个全段差异）
  Blast Radius: `[]`
  DoD:
    - [x] 段长全部整除：70070/182=385、40660/190=214、4680/52=90、14688/136=108、150/50=3
    - [x] 索引驱动（`jymain.lua:1747`）
    - [x] 无固定计数常量
    - [x] 边界 hint 有效：`P0489`/`N0448`/`T0395`/`T20395`/`TD0395`/`S0088`/`W0107`
    - [x] 边界名称可读：卓不凡/高昌迷宮地圖
    - [x] `gaps=0`

## 5. 70 场额外战斗复核（REQ-PTTV-5）

- [x] 5.1 三重确认
  Blast Radius: `[]`
  DoD:
    - [x] `diff.md` 提及 140 项
    - [x] 产物 `fight*.grp` = 162；差集 = 70
    - [x] 162 个全部 `REQUIRED`/`in_product=true`，其他类别 = 0
    - [x] 抽样 5 场（`fight073`/`fight130`/`fight154`/`fight195`/`fight216`）逐项复核

## 6. `eft/` 105 个 `EDITOR_DUMP`（REQ-PTTV-8）

- [x] 6.1 4 条机器可复核证据
  Blast Radius: `[]`
  DoD:
    - [x] `IGNORE_DIRS` 含 `eft=true`（`mod_build.lua:567`）
    - [x] 引擎 0 引用 `eft/`
    - [x] 产物无 `eft/`
    - [x] 审计 105 项 `EDITOR_DUMP`/`in_product=false`

## 7. PENDING 27 项边界（REQ-PTTV-9）

- [x] 7.1 显式列出
  Blast Radius: `[]`
  DoD:
    - [x] `music/*.mid` 23 项 → 全局遗留 spike
    - [x] `list/*.bin` 4 项 → C 引擎列表数据，Lua 引擎无读取路径
    - [x] 说明 `needed=nil` ≠ `needed=false`

## 8. 零引擎 / 零代码改动（REQ-PTTV-6）

- [x] 8.1 Blast Radius 合规
  Blast Radius: `[]`
  DoD:
    - [x] `game/engine-love2d/**` 未改
    - [x] `game/engine-mud/**` 未改
    - [x] `game/script/jyconst.lua` 未改
    - [x] `reference/allmods/**` 未改
    - [x] `game/tools/**` 未改（本 slice 零代码改动）
    - [x] `game/framework/**` 未改

## 9. 零回归

- [x] 9.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 1613/1613
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `total=11220 unclassified=0 bad_evidence=0`
    - [x] `mod_audit --all --evidence` `checked=17 failed=0`
    - [x] `format_spec --all` `formats=12 checked=6773 gaps=0`
    - [x] 全量测试后全 MOD `save/` 与源一致（341 文件，不一致 = 0）

## 10. 验证

- [x] 10.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-ptt-verify/verification.md"]`
  DoD:
    - [x] 含 REQ-PTTV-1~9 追溯矩阵
    - [x] 含判据第 5 次 / 第 2 次应用记录
    - [x] 含 Blast Radius 合规检查

- [x] 10.2 写 `reports/ptt-verify.md`
  Blast Radius: `["openspec/changes/allmods-ptt-verify/reports/ptt-verify.md"]`
  DoD:
    - [x] 结论摘要表
    - [x] `diff.md` 逐条审计表（154 + 21）
    - [x] `hdgrp` 第 5 次 / 记录段第 2 次判据应用记录
    - [x] 70 场额外战斗三重证据
    - [x] MOD 独有内容非基线值证据
    - [x] 第 3 梯队进度
    - [x] 零回归实测输出
