# Tasks: allmods-lyff-activate

## 0. ASCII 字符串保留修复（REQ-LYF-0，跨 5 MOD 的工具修复）

- [x] 0.1 修复 `mod_encoding.lua` 纯 ASCII 字段被误判为数值槽而丢弃
  Blast Radius: `["game/tools/mod_encoding.lua", "game/tests/unit/test_mod_encoding.lua"]`
  DoD:
    - [x] 新增 `isStringField(raw)`：含 Big5 高字节 **或** 全可打印 ASCII（0x20~0x7E）且长度 ≥ 2 → 判为字符串
    - [x] `ConvertRanger` 由 `hasHighByte` 守卫改为 `isStringField` 守卫
    - [x] 回归测试 `test_mod_encoding.lua`「ConvertRanger 保留纯 ASCII 文本（不再误丢）」断言 lyff `AAA`
    - [x] 影响 5 个 MOD：lyff `AAA`、HeavenSword `killer-G`、GodsDevils `123`、ptt `PTT`、dream `------`
    - [x] 测试数 1612 → **1613**（新增 1 个 ASCII 保留测试）

## 1. 构建（REQ-LYF-1）

- [x] 1.1 构建 lyff 数据包
  Blast Radius: `["game/mods/lyff/**"]`
  DoD:
    - [x] `lua tools/mod_build.lua kys-lyff` 退出码 0
    - [x] `data files=311, saves=6, sound=78, events=1358, talk=5655`
    - [x] `game/mods/lyff/diff.md` 生成

- [x] 1.2 确认产物目录结构
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `script/oldevent/` 含 1358 个 `.lua`
    - [x] `script/oldtalk.grp`/`.idx` 存在
    - [x] `save/` 含 6 个文件
    - [x] `sound/` 含 78 个文件
    - [x] `data/` 含 311 个文件

## 2. 逐文件穷举审计（REQ-LYF-2）

- [x] 2.1 运行穷举审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `total=425 in_product=395 not_in_product=30 unclassified=0 bad_evidence=0`
    - [x] `Σ(类别) = 390+4+3+1+27 = 425`

- [x] 2.2 确认无「必需但未进产物」矛盾
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 矛盾数 = 0

## 3. 字节级覆盖（REQ-LYF-3）

- [x] 3.1 运行字节级审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `formats=12 checked=242 gaps=0`

## 4. `hdgrp` 差异验证（REQ-LYF-4，判据第 4 次应用）

- [x] 4.1 应用 Slice 5 判据（第 4 次）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `hdgrp.idx` = 712 字节 = 178 条目（pascal 115）
    - [x] `CC.HeadPicFile[1]` = `mods/lyff/data/hdgrp.idx`
    - [x] 索引驱动（`PicLoadFile` 用 `idxlen/4`）
    - [x] 无固定计数常量
    - [x] 判定为**内容差异**，非结构异常
    - [x] `gaps=0` 佐证

## 5. PERSON 326 差异验证（REQ-LYF-5，本 epic 首次非 320）

- [x] 5.1 判定 326 人物段为内容差异
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `ranger.grp` seg1（Person 段）= 59332 字节 = 326 × 182（pascal 58240 = 320 × 182）
    - [x] `JY.PersonNum = math.floor((idx[2]-idx[1])/CC.PersonSize)`（`jymain.lua:1747`）—— 索引驱动
    - [x] 无固定计数常量
    - [x] 边界记录 `Person[325]` = 枯榮/南帝（有效，非 nil/乱码）
    - [x] `gaps=0` 佐证
    - [x] 判定为**内容差异**，**零引擎改动**

## 6. 46 场额外战斗验证（REQ-LYF-6）

- [x] 6.1 三重确认 46 场额外战斗
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 抽样 5 场（`030`/`110`/`146`/`162`/`173`）全部三重确认通过
    - [x] `diff.md` 提及 ≥1 次
    - [x] 产物 `data/fightNNN.grp` 存在
    - [x] 审计归类 `REQUIRED` + `in_product=true`
    - [x] 产物 `fight*.grp` 总数 = 138
    - [x] 额外战斗编号集合与 diff.md 一致（46 个，集差法核实）

## 7. 产物四项检查

- [x] 7.1 `MOD_SLUG=lyff lua tools/mod_check_one.lua`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `PERSON=326 THING=200 SCENE=84 WUGONG=93`
    - [x] `HERO=AAA`
    - [x] `STRINGS=OK EVENTS=OK SAVE=OK`

## 8. 真实启动链路（REQ-LYF-7）

- [x] 8.1 独立进程启动验证
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `lua tests/unit/boot_one_mod.lua lyff 326 200 84 93 AAA`
    - [x] `RESULT lyff: OK`
    - [x] 16 项断言全 PASS（扫描字段 1429）

## 9. 存档验证（REQ-LYF-8）

- [x] 9.1 验证源自带存档完好
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 产物 `save/` 6 个文件（`d11`/`r11`/`s11` + `d1`/`r1`/`s1` `.grp`）与源逐字节一致
    - [x] `CC.D_Filename[1]`/`CC.R_GRPFilename[1]`/`CC.S_Filename[1]` 指向 MOD save
    - [x] 全量测试后仍一致（缺陷 D 修复持久性）

## 10. 零回归（REQ-LYF-9）

- [x] 10.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 1613/1613
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `unclassified=0`
    - [x] `mod_audit --all --evidence` `failed=0`
    - [x] `format_spec --all` `gaps=0`
    - [x] 全量测试后全 MOD `save/` 与源一致（不一致 = 0）

## 11. 验证

- [x] 11.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-lyff-activate/verification.md"]`
  DoD:
    - [x] 含 REQ-LYF-0~9 追溯矩阵
    - [x] 含 46 场额外战斗三重确认
    - [x] 含 PERSON 326 / `hdgrp` 178 判据
    - [x] 含 ASCII 字符串修复说明
    - [x] 含 Blast Radius 合规检查
