# Tasks: allmods-godsdevils-verify

## 1. `diff.md` 逐条审计（REQ-GDV-1）

- [x] 1.1 审计 13 项 MOD 独有
  Blast Radius: `["openspec/changes/allmods-godsdevils-verify/reports/**"]`
  DoD:
    - [x] 12 项判定为预期资源
    - [x] `kysmod.ini` 判定为 `BUILD_INPUT`（在产物中）
    - [x] 无额外战斗（fight 92 == pascal 92，同集合）
    - [x] 需修复项 = 0

- [x] 1.2 用文件系统事实 + 引擎引用证据定性 23 项基准独有
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 在 save/ 6（`d1/d2/r1/r2/s1/s2 .grp`，产物与源逐字节一致）
    - [x] 死文件 9（`alldef.idx`/`allsin.idx`/`allsinbk.grp` + `d1/d2/d3.idx`/`s1/s2/s3.idx`）
    - [x] 回退原版（含首次播种）8（`r1.idx`/`r2.idx`/`r3.grp`/`r3.idx`/`s3.grp`/`d3.grp`/`thing.grp`/`thing.idx`）
    - [x] `6+9+8 = 23`，无未解释项

- [x] 1.3 确认 `d/s*.idx` 为死文件（源码级证据）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `jyconst.lua:80`「S和D由于是固定大小，因此不再定义idx了」
    - [x] 全仓库 `grep "S_IDX\|D_IDX"` = 0 命中
    - [x] `LoadRecord`/`SaveRecord` 只读写 `CC.R_IDXFilename`

## 2. MOD 独有内容验证（REQ-GDV-3）

- [x] 2.1 用非基线值证明加载来自 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 主角姓名 = 蝦米（pascal = 小蝦米）
    - [x] `JY.Person[1]` = 胡斐/雪山飛狐
    - [x] `JY.Person[2]` = 程靈素/毒手藥王
    - [x] 对话条目数 = 4640（pascal 2977）
    - [x] 事件脚本数 = 1123（pascal 1018）
    - [x] `hdgrp` 条目数 = 129（pascal 115）
    - [x] fight 92 == pascal 92 显式标注「同数，无区分度」

- [x] 2.2 核对资源路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `CC.HeadPicFile[1]`/`CC.TalkGrpFile` 等指向 `mods/GodsDevils/`
    - [x] `CC.ThingPicFile[1]` = `data/thing.idx`（回退原版）

## 3. `hdgrp` 差异判定（REQ-GDV-4）

- [x] 3.1 应用 Slice 5 三重判据（第二次外推）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `hdgrp.idx` = 516 字节 = 129 条目（pascal 115）
    - [x] 索引驱动（`PicLoadFile` 用 `idxlen/4`，`lib_love.lua:437`）
    - [x] 无固定计数常量（5 个常量全 `nil`）
    - [x] 记录布局常量与 pascal 相同（182/190/52/136）
    - [x] 字节全覆盖 `gaps=0`
    - [x] 结论：内容差异，非结构异常
    - [x] 外推链：HeavenSword（125，首次）→ GodsDevils（129，第二次）一致

## 4. 第 3 种存档形态确认

- [x] 4.1 round-trip（activate 子 change 执行，本 change 引用）
  Blast Radius: `[]`（只读，验证后已恢复）
  DoD:
    - [x] 半状态 `LoadRecord(1)` 优雅跳过（`jymain.lua:1697-1701`，不崩溃）
    - [x] 首次 `SaveRecord(1)` 播种 `r1.idx` + 写 `r1.ovr`，槽位补全
    - [x] 补全后 `LoadRecord(1)` 成功，改名回读正确（測試改名GD）
    - [x] 验证后产物恢复至原始状态

## 5. 零引擎改动确认（REQ-GDV-5）

- [x] 5.1 检查改动路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `game/engine-love2d/**` 未改
    - [x] `game/engine-mud/**` 未改
    - [x] `game/script/jyconst.lua` 未改
    - [x] `reference/allmods/**` 未改

## 6. 验证报告（REQ-GDV-6）

- [x] 6.1 写 `reports/godsdevils-verify.md`
  Blast Radius: `["openspec/changes/allmods-godsdevils-verify/reports/godsdevils-verify.md"]`
  DoD:
    - [x] 结论摘要表
    - [x] `diff.md` 逐条审计表（13 + 23）
    - [x] `hdgrp` 差异 vs 结构异常判定（含外推链）
    - [x] MOD 独有内容非基线值证据（fight 同数标注无区分度）
    - [x] 第 3 种存档形态说明
    - [x] 零回归实测输出
    - [x] 累计工具缺陷汇总

## 7. 零回归

- [x] 7.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 1612/1612
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `unclassified=0`
    - [x] `mod_audit --all --evidence` `failed=0`
    - [x] `format_spec --all` `gaps=0`
    - [x] 全量测试后全 MOD `save/` 与源一致（checked=341 mismatch=0）

## 8. 验证

- [x] 8.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-godsdevils-verify/verification.md"]`
  DoD:
    - [x] 含 REQ-GDV-1~6 追溯矩阵
    - [x] 含 `d/s*.idx` 死文件判据
    - [x] 含累计工具缺陷汇总
    - [x] 含 Blast Radius 合规检查
