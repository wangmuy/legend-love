# Tasks: allmods-pig-verify

## 1. `diff.md` 逐条审计（REQ-PIGV-1）

- [x] 1.1 审计 103 项 MOD 独有（按类别分解）
  Blast Radius: `["openspec/changes/allmods-pig-verify/reports/**"]`
  DoD:
    - [x] 额外战斗 90 项（45 场 × 2）
    - [x] `kdef`/`talk`/`cloud`/`title` 8 项
    - [x] `dead.png`/`end.png`/`open.png` 3 项
    - [x] `ranger.str` 1 项
    - [x] `kysmod.ini` 1 项（`BUILD_INPUT`）
    - [x] `Σ = 103`，需修复项 = 0

## 2. 「基准独有」逐项定性（REQ-PIGV-2）

- [x] 2.1 用文件系统事实 + 运行时 `CC.*` 值定性 21 项
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 回退原版 11（9 个 `.idx` 变体 + `thing.grp`/`.idx`）
    - [x] 在 save/ 9（`d1`~`d3`/`r1`~`r3`/`s1`~`s3`）
    - [x] 死文件 1（`allsinbk.grp`）
    - [x] `11+9+1 = 21`，无未解释项

## 3. MOD 独有内容验证（REQ-PIGV-3）

- [x] 3.1 用非基线值证明加载来自 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 主角姓名 = 小小豬（pascal = 小蝦米）
    - [x] `JY.Person[1]` = 胡斐
    - [x] `JY.Person[2]` = 程靈素
    - [x] 对话条目数 = 4123（pascal 2977）
    - [x] 事件脚本数 = 1288（pascal 1018）
    - [x] `hdgrp` 条目数 = 173（pascal 115）
    - [x] 战斗数 = 137（pascal 92）

## 4. `hdgrp` / fight 差异判定（REQ-PIGV-4）

- [x] 4.1 复用 Slice 5 判据（第 3 次应用）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `hdgrp.idx` = 692 字节 = 173 条目
    - [x] 索引驱动（`PicLoadFile` 用 `idxlen/4`）
    - [x] 无固定计数常量
    - [x] fight 索引驱动（脚本按编号引用）
    - [x] 字节全覆盖 `gaps=0`
    - [x] 结论：内容差异，非结构异常
    - [x] 记录为判据**第 3 次应用**（125/129/173）

## 5. 45 场额外战斗复核（REQ-PIGV-5）

- [x] 5.1 复核三重证据
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 抽样 5 场（`030`/`039`/`137`/`145`/`170`）三重确认通过
    - [x] `diff.md` 提及 45 项
    - [x] 产物 `fight*.grp` = 137
    - [x] 审计归类 `REQUIRED` + `in_product=true`

## 6. 零引擎改动确认（REQ-PIGV-6）

- [x] 6.1 检查改动路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `game/engine-love2d/**` 未改
    - [x] `game/engine-mud/**` 未改
    - [x] `game/script/jyconst.lua` 未改
    - [x] `reference/allmods/**` 未改

## 7. 验证报告（REQ-PIGV-7）

- [x] 7.1 写 `reports/pig-verify.md`
  Blast Radius: `["openspec/changes/allmods-pig-verify/reports/pig-verify.md"]`
  DoD:
    - [x] 结论摘要表
    - [x] `diff.md` 逐条审计表（103 + 21）
    - [x] `hdgrp` / fight 差异判定 + 判据第 3 次应用记录
    - [x] 45 场额外战斗三重证据
    - [x] MOD 独有内容非基线值证据
    - [x] 第 3 梯队进度
    - [x] 零回归实测输出

## 8. 零回归

- [x] 8.1 全部门禁
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

## 9. 验证

- [x] 9.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-pig-verify/verification.md"]`
  DoD:
    - [x] 含 REQ-PIGV-1~7 追溯矩阵
    - [x] 含判据第 3 次应用记录
    - [x] 含 Blast Radius 合规检查
