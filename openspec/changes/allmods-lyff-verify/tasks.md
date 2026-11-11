# Tasks: allmods-lyff-verify

## 1. `diff.md` 逐条审计（REQ-LYFFV-1）

- [x] 1.1 审计 105 项 MOD 独有（按类别分解）
  Blast Radius: `["openspec/changes/allmods-lyff-verify/reports/**"]`
  DoD:
    - [x] 额外战斗 92 项（46 场 × 2：`fight030`/`039`/`040`/`110`/`115`~`121`/`125`/`126`/`128`~`131`/`133`~`146`/`152`~`162`/`167`/`169`/`170`/`173`）
    - [x] `cloud.grp`/`.idx`、`kdef.grp`/`.idx`、`talk.grp`/`.idx`、`title.grp`/`.idx` 8 项
    - [x] `dead.png`/`end.png`/`open.png` 3 项
    - [x] `ranger.str` 1 项（`REQUIRED_CONVERTED`）
    - [x] `kysmod.ini` 1 项（`BUILD_INPUT`）
    - [x] `Σ = 92+8+3+1+1 = 105`，需修复项 = 0

- [x] 1.2 穷举审计复核
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `total=425 in_product=395 not_in_product=30 unclassified=0 bad_evidence=0`
    - [x] `Σ(类别) = 390+4+3+1+27 = 425`
    - [x] 30 个未进产物 = PENDING 27（music 23 + list bin 4）+ LEGACY 3，无「必需但未进产物」矛盾

## 2. 「基准独有」逐项定性（REQ-LYFFV-2）

- [x] 2.1 用文件系统事实 + 运行时 `CC.*` 值定性 23 项
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 在 save/（源自带，产物逐字节一致）3：`d1.grp`、`r1.grp`、`s1.grp`
    - [x] 死文件 9：`alldef.idx`、`allsin.idx`、`allsinbk.grp`、`d1/d2/d3.idx`、`s1/s2/s3.idx`（`d/s*.idx` 判据：`jyconst.lua:80` 引擎无 S/D idx 常量）
    - [x] 回退原版（含首次存档播种）11：`d2.grp`、`d3.grp`、`r1.idx`（首次 `SaveRecord(1)` 播种）、`r2.grp`、`r2.idx`、`r3.grp`、`r3.idx`、`s2.grp`、`s3.grp`、`thing.grp`、`thing.idx`
    - [x] `3+9+11 = 23`，无未解释项

## 3. MOD 独有内容验证（REQ-LYFFV-3）

- [x] 3.1 用非基线值证明加载来自 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 主角姓名 = **AAA**（pascal = 小蝦米；纯 ASCII 保留依赖 `isStringField` 守卫，回归测试覆盖）
    - [x] `JY.Person[1]` = 胡斐/雪山飛狐、`JY.Person[2]` = 程靈素/毒手藥王
    - [x] 边界记录 `JY.Person[325]` = 枯榮/南帝（pascal 仅 320 条，不存在）
    - [x] 对话条目数 = 5655（pascal 2977，本 epic 最多）
    - [x] 事件脚本数 = 1358（pascal 1018）
    - [x] `hdgrp` 条目数 = 178（pascal 115）
    - [x] 战斗数 = 138（pascal 92）
    - [x] Thing/Scene/Wugong = 200/84/93 与基线同数——**显式不作为证据**

## 4. 记录数差异 vs 结构异常判定（REQ-LYFFV-4）

- [x] 4.1 326 人物段判定（**本 epic 首个记录数差异 MOD**）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 动态推导：`PersonNum = math.floor((idx[2]-idx[1])/CC.PersonSize)`（`jymain.lua:1747`）；lyff `59332 = 326 × 182`（pascal `58240 = 320 × 182`）
    - [x] 无固定计数常量（全仓库无 `PERSON_NUM` 类常量）
    - [x] 边界记录 `Person[325]` 有效（姓名/外号可读）
    - [x] 字节全覆盖 `formats=12 checked=242 gaps=0`
    - [x] 结论：内容差异，零引擎改动

- [x] 4.2 `hdgrp` 178 判定（判据**第 4 次应用**）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `hdgrp.idx` = 712 字节 = 178 × 4
    - [x] 索引驱动（`lib_love.lua:437` `idxlen/4`）+ 固定计数常量全 `nil` + `gaps=0`
    - [x] 外推链 125/129/173/178 四次一致

- [x] 4.3 46 场额外战斗三重确认
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `diff.md` 提及 46 场 × 2 = 92 项
    - [x] 产物 `fight*.grp` = 138（92 + 46）
    - [x] 审计归类 `REQUIRED` + `in_product=true`

## 5. 零引擎改动确认（REQ-LYFFV-5）

- [x] 5.1 检查改动路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `game/engine-love2d/**` 未改
    - [x] `game/engine-mud/**` 未改
    - [x] `game/script/jyconst.lua` 未改
    - [x] `reference/allmods/**` 未改
    - [x] 两个子 change 零代码改动（activate 仅含 `mod_encoding.lua` 跨 MOD 工具修复，见 REQ-LYF-0）

## 6. 零回归

- [x] 6.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 1613/1613
    - [x] `--verify-pascal` `mismatches=0 known-deviations=3`
    - [x] `--all` `20 mods, 0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `total=11220 unclassified=0 bad_evidence=0`
    - [x] `mod_audit --all --evidence` `checked=17 failed=0`
    - [x] `format_spec --all` `formats=12 checked=6773 gaps=0`
    - [x] 全量测试后全 MOD `save/` 与源一致（不一致 = 0）

## 7. 验证报告 + verification（REQ-LYFFV-6）

- [x] 7.1 写 `reports/lyff-verify.md`
  Blast Radius: `["openspec/changes/allmods-lyff-verify/reports/lyff-verify.md"]`
  DoD:
    - [x] 结论摘要表（12 行维度）
    - [x] `diff.md` 逐条审计表（105 + 23）
    - [x] 326 人物段判定 4 条判据 + 判据统一原则（可外推）
    - [x] `hdgrp` 判据第 4 次应用记录
    - [x] 46 场额外战斗三重证据
    - [x] MOD 独有内容非基线值证据（含 AAA 解析依赖说明）
    - [x] 存档第 3 种形态
    - [x] 零回归实测输出 + 累计缺陷表（4 个，本 slice +0）

- [x] 7.2 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-lyff-verify/verification.md"]`
  DoD:
    - [x] 含 REQ-LYFFV-1~6 追溯矩阵
    - [x] 含判据统一原则（记录数差异 = hdgrp 判据同族）
    - [x] 含 Blast Radius 合规检查
