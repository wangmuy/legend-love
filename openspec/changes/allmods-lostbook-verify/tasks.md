# Tasks: allmods-lostbook-verify

## 1. `diff.md` 逐条审计（REQ-LOSTV-1）

- [x] 1.1 审计 24 项 MOD 独有
  Blast Radius: `["openspec/changes/allmods-lostbook-verify/reports/**"]`
  DoD:
    - [x] 17 项判定为预期资源
    - [x] 5 场额外战斗（`fight039`~`042`、`fight052`）判定为预期
    - [x] `kysmod.ini` 判定为 `BUILD_INPUT`（在产物中）
    - [x] 需修复项 = 0

- [x] 1.2 三重确认 5 场额外战斗
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `diff.md` 提及
    - [x] 产物 `data/` 存在 `.grp`+`.idx`
    - [x] 审计归类 `REQUIRED` / `in_product=true`

## 2. 「基准独有」逐项定性（REQ-LOSTV-2）

- [x] 2.1 用文件系统事实 + 运行时 `CC.*` 值定性 21 项
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 回退原版 18
    - [x] 在 save/ 2
    - [x] 死文件 1
    - [x] `18+2+1 = 21`，无未解释项

- [x] 2.2 `r1.grp` 归为「在 save/（首次播种）」
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `CC.R_GRPFilename[1] = mods/lostbook/save/r1.grp`
    - [x] 源无 `r1.grp`，首次 `SaveRecord(1)` 播种
    - [x] 不归为「回退原版」或「死文件」

## 3. MOD 独有内容验证（REQ-LOSTV-3）

- [x] 3.1 用非基线值证明加载来自 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 主角姓名 = 金迷（pascal = 小蝦米）
    - [x] `JY.Person[1]` = 胡斐
    - [x] `JY.Person[2]` = 程靈素
    - [x] 对话条目数 = 3181（pascal 2977）
    - [x] 事件脚本数 = 1071（pascal 1018）

- [x] 3.2 核对资源路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 路径全部指向 `mods/lostbook/`
    - [x] `CC.ThingPicFile[1]` = `data/thing.idx`（回退原版）

## 4. 内容差异 vs 结构异常（REQ-LOSTV-4）

- [x] 4.1 用三重机器可验证判据判定
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 记录布局常量与 pascal 相同（182/190/52/136）
    - [x] 记录数与 pascal 相同（320/200/84/93）
    - [x] 字节全覆盖 `gaps=0`（证明结构未变）
    - [x] 结论：kdef 1071 / fight 97 为**内容差异**

## 5. 零引擎改动确认（REQ-LOSTV-5）

- [x] 5.1 检查改动路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `game/engine-love2d/**` 未改
    - [x] `game/engine-mud/**` 未改
    - [x] `game/script/jyconst.lua` 未改
    - [x] `reference/allmods/**` 未改

## 6. 验证报告（REQ-LOSTV-6）

- [x] 6.1 写 `reports/lostbook-verify.md`
  Blast Radius: `["openspec/changes/allmods-lostbook-verify/reports/lostbook-verify.md"]`
  DoD:
    - [x] 结论摘要表
    - [x] `diff.md` 逐条审计表（24 + 21）
    - [x] 内容差异 vs 结构异常判定
    - [x] MOD 独有内容非基线值证据
    - [x] 第 1 梯队小结
    - [x] 零回归实测输出

## 7. 零回归

- [x] 7.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 958/958
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `unclassified=0`
    - [x] `mod_audit --all --evidence` `failed=0`
    - [x] `format_spec --all` `gaps=0`

## 8. 验证

- [x] 8.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-lostbook-verify/verification.md"]`
  DoD:
    - [x] 含 REQ-LOSTV-1~6 追溯矩阵
    - [x] 含第 1 梯队小结
    - [x] 含 Blast Radius 合规检查
