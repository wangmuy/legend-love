# Tasks: allmods-pig-activate

## 1. 构建（REQ-PIG-1）

- [x] 1.1 构建 pig 数据包
  Blast Radius: `["game/mods/pig/**"]`
  DoD:
    - [x] `lua tools/mod_build.lua kys-pig` 退出码 0
    - [x] `data files=311, saves=21, sound=78, events=1288, talk=4123`
    - [x] `game/mods/pig/diff.md` 生成

- [x] 1.2 确认产物目录结构
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `script/oldevent/` 含 1288 个 `.lua`
    - [x] `script/oldtalk.grp`/`.idx` 存在
    - [x] `save/` 含 21 个文件
    - [x] `sound/` 含 78 个文件
    - [x] `data/` 含 311 个文件

## 2. 逐文件穷举审计（REQ-PIG-2）

- [x] 2.1 运行穷举审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `total=440 in_product=410 not_in_product=30 unclassified=0 bad_evidence=0`
    - [x] `Σ(类别) = 405+4+3+1+27 = 440`

- [x] 2.2 确认无「必需但未进产物」矛盾
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 矛盾数 = 0

## 3. 字节级覆盖（REQ-PIG-3）

- [x] 3.1 运行字节级审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `formats=12 checked=241 gaps=0`

## 4. `hdgrp` 差异验证（REQ-PIG-4）

- [x] 4.1 应用 Slice 5 判据（第 3 次）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `hdgrp.idx` = 692 字节 = 173 条目（pascal 115）
    - [x] `CC.HeadPicFile[1]` = `mods/pig/data/hdgrp.idx`
    - [x] 索引驱动（`PicLoadFile` 用 `idxlen/4`）
    - [x] 无固定计数常量
    - [x] 判定为**内容差异**，非结构异常
    - [x] `gaps=0` 佐证

## 5. 45 场额外战斗验证（REQ-PIG-5）

- [x] 5.1 三重确认 45 场额外战斗
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 抽样 5 场（`030`/`039`/`137`/`145`/`170`）全部三重确认通过
    - [x] `diff.md` 提及 ≥1 次
    - [x] 产物 `data/fightNNN.grp` 存在
    - [x] 审计归类 `REQUIRED` + `in_product=true`
    - [x] 产物 `fight*.grp` 总数 = 137
    - [x] 额外战斗编号集合与 diff.md 一致（45 个）

## 6. 产物四项检查

- [x] 6.1 `MOD_SLUG=pig lua tools/mod_check_one.lua`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `PERSON=320 THING=200 SCENE=84 WUGONG=93`
    - [x] `HERO=小小豬`
    - [x] `STRINGS=OK EVENTS=OK SAVE=OK`

## 7. 真实启动链路（REQ-PIG-6）

- [x] 7.1 独立进程启动验证
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `lua tests/unit/boot_one_mod.lua pig 320 200 84 93 小小豬`
    - [x] `RESULT pig: OK`
    - [x] 16 项断言全 PASS

## 8. 存档验证（REQ-PIG-7）

- [x] 8.1 验证 9 个源自带存档完好
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 产物 `save/` 21 个文件全部与源逐字节一致
    - [x] `CC.D_Filename[1]`/`CC.R_GRPFilename[1]`/`CC.S_Filename[1]` 指向 MOD save
    - [x] 运行 `mod_check` 后仍一致
    - [x] 全量测试后仍一致（含 `d2`/`d3`/`r2`/`r3`/`s2`/`s3`）

## 9. 零回归（REQ-PIG-8）

- [x] 9.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 1612/1612
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `unclassified=0`
    - [x] `mod_audit --all --evidence` `failed=0`
    - [x] `format_spec --all` `gaps=0`
    - [x] 全量测试后全 MOD `save/` 与源一致（341 文件，不一致 = 0）

## 10. 验证

- [x] 10.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-pig-activate/verification.md"]`
  DoD:
    - [x] 含 REQ-PIG-1~8 追溯矩阵
    - [x] 含 45 场额外战斗三重确认
    - [x] 含 Blast Radius 合规检查
