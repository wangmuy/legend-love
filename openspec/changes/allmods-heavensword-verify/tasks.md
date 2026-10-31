# Tasks: allmods-heavensword-verify

## 1. `diff.md` 逐条审计（REQ-HSV-1）

- [x] 1.1 审计 15 项 MOD 独有
  Blast Radius: `["openspec/changes/allmods-heavensword-verify/reports/**"]`
  DoD:
    - [x] 13 项判定为预期资源
    - [x] 1 场额外战斗（`fight073`）判定为预期
    - [x] `kysmod.ini` 判定为 `BUILD_INPUT`（在产物中）
    - [x] 需修复项 = 0

## 2. 「基准独有」逐项定性（REQ-HSV-2）

- [x] 2.1 用文件系统事实 + 运行时 `CC.*` 值定性 21 项
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 回退原版 19
    - [x] 在 save/ 1（`r1.idx`）
    - [x] 死文件 1（`allsinbk.grp`）
    - [x] `19+1+1 = 21`，无未解释项

- [x] 2.2 确认 `d1.grp`/`s1.grp` 不在 save/
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 源 `save/` 不含 `d1.grp`/`s1.grp`
    - [x] 归为「回退原版（首次存档时播种）」
    - [x] 与第 1 梯队（源自带 `d1.grp`/`s1.grp`）区分

- [x] 2.3 确认 `r1.idx` = `ranger.idx` 副本
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 两者 md5 相同（`3746f89bd755157160d7bc9575d8e2e4`）

## 3. MOD 独有内容验证（REQ-HSV-3）

- [x] 3.1 用非基线值证明加载来自 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 主角姓名 = 楊千葉（pascal = 小蝦米）
    - [x] `JY.Person[1]` = 胡斐
    - [x] `JY.Person[2]` = 程靈素
    - [x] 对话条目数 = 3315（pascal 2977）
    - [x] 事件脚本数 = 1066（pascal 1018）
    - [x] `hdgrp` 条目数 = 125（pascal 115）

- [x] 3.2 核对资源路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 路径全部指向 `mods/HeavenSword/`
    - [x] `CC.ThingPicFile[1]` = `data/thing.idx`（回退原版）

## 4. `hdgrp` 差异判定（REQ-HSV-4）

- [x] 4.1 用三重机器可验证判据判定
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 索引驱动：`PicLoadFile` 用 `idxlen/4`（`lib_love.lua:437`）
    - [x] 无固定计数：`CC.HDGRPNum` 等 5 个常量全 `nil`
    - [x] 记录布局常量与 pascal 相同（182/190/52/136）
    - [x] 字节全覆盖 `gaps=0`
    - [x] 结论：内容差异，非结构异常
    - [x] 确认判据可外推到后续 hdgrp ≠ 115 的 MOD

## 5. 零引擎改动确认（REQ-HSV-5）

- [x] 5.1 检查改动路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `game/engine-love2d/**` 未改
    - [x] `game/engine-mud/**` 未改
    - [x] `game/script/jyconst.lua` 未改
    - [x] `reference/allmods/**` 未改

## 6. 验证报告（REQ-HSV-6）

- [x] 6.1 写 `reports/heavensword-verify.md`
  Blast Radius: `["openspec/changes/allmods-heavensword-verify/reports/heavensword-verify.md"]`
  DoD:
    - [x] 结论摘要表
    - [x] `diff.md` 逐条审计表（15 + 21）
    - [x] `hdgrp` 差异 vs 结构异常判定（含源码证据）
    - [x] MOD 独有内容非基线值证据
    - [x] 缺陷 D 说明（含同源缺陷对照表）
    - [x] 累计 4 个工具缺陷汇总
    - [x] 零回归实测输出

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
    - [x] 全量测试后全 MOD `save/` 与源一致

## 8. 验证

- [x] 8.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-heavensword-verify/verification.md"]`
  DoD:
    - [x] 含 REQ-HSV-1~6 追溯矩阵
    - [x] 含累计工具缺陷汇总
    - [x] 含 Blast Radius 合规检查
