# Tasks: allmods-sweeOan-verify

## 1. `diff.md` 逐条审计（REQ-SWEEV-1）

- [x] 1.1 审计 14 项 MOD 独有
  Blast Radius: `["openspec/changes/allmods-sweeOan-verify/reports/**"]`
  DoD:
    - [x] 12 项判定为「预期资源」
    - [x] `kysmod.ini` 判定为 `BUILD_INPUT`
    - [x] `修改档说明.txt` 判定为死文件
    - [x] 需修复项 = 0

- [x] 1.2 记录 `diff.md` 的盲区（`kysmod.ini`/`修改档说明.txt` 在 diff 中但不在产物）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 报告注明「穷举审计才是权威」

## 2. 「基准独有」逐项定性（REQ-SWEEV-2）

- [x] 2.1 用文件系统事实定性 23 项
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 逐项检查 `data/` 与 `save/` 的实际位置
    - [x] 23 项全部有判定

- [x] 2.2 用运行时 `CC.*` 值交叉验证
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `CC.R_GRPFilename[1]` = `mods/SweeOan/save/r1.grp`
    - [x] `CC.D_Filename[1]` = `mods/SweeOan/save/d1.grp`
    - [x] `CC.S_Filename[1]` = `mods/SweeOan/save/s1.grp`
    - [x] `CC.TempS_Filename` = `data/allsinbk.grp`（死文件）
    - [x] `CC.ThingPicFile[1]` = `data/thing.idx`（回退原版）

- [x] 2.3 三类性质分类：回退原版 16 / 在 save/ 4 / 死文件 3
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `16 + 4 + 3 = 23`
    - [x] 无未解释项

## 3. MOD 独有内容验证（REQ-SWEEV-3）

- [x] 3.1 用非基线值证明加载来自 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 主角姓名 = 王小石（pascal = 小蝦米）
    - [x] `JY.Person[1]` = 衛悲回
    - [x] `JY.Person[2]` = 伊小深
    - [x] 注明「对话/事件条目数与基线相同，不作证据」

- [x] 3.2 核对资源路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `CC.MMAPPicFile[1]` = `mods/SweeOan/data/mmap.idx`
    - [x] `CC.SMAPPicFile[1]` = `mods/SweeOan/data/smap.idx`
    - [x] `CC.WMAPPicFile[1]` = `mods/SweeOan/data/wmap.idx`
    - [x] `CC.TalkGrpFile` = `mods/SweeOan/script/oldtalk.grp`
    - [x] `CC.WarFile` = `mods/SweeOan/data/war.sta`

## 4. 缺陷修复（REQ-SWEEV-6）

- [x] 4.1 定位并确认 `mod_check_one.lua` 数据销毁缺陷
  Blast Radius: `[]`（只读调查）
  DoD:
    - [x] 复现：`mod_check_one` 运行后产物 `r1.grp` 消失
    - [x] 根因：`os.remove(dir.."r1.grp")` 操作真实产物目录
    - [x] 影响面：`mod_check.lua` 对全部 20 MOD 调用 → 全部受影响
    - [x] 证据：mingdong 产物 223688 B vs 源 222888 B + `r1.idx`/`r1.ovr` 残留

- [x] 4.2 修复：自检前备份、自检后字节级恢复
  Blast Radius: `["game/tools/mod_check_one.lua"]`
  DoD:
    - [x] 备份 `r1.grp`/`r1.idx`/`r1.ovr`
    - [x] 自检后恢复（无论成败）
    - [x] 移除无条件的最终 `os.remove`

- [x] 4.3 验证修复
  Blast Radius: `[]`（只读）
  DoD:
    - [x] SweeOan：`r1.grp` md5 `3240110332f1f663a9828bbcd473a9bb` 前后不变
    - [x] mingdong：`r1.grp` = 222888 B（与源一致）
    - [x] 无 `r1.idx`/`r1.ovr` 残留
    - [x] `mod_check` 20/20 仍通过

- [x] 4.4 新增回归测试
  Blast Radius: `["game/tests/unit/test_mod_resources.lua"]`
  DoD:
    - [x] `testCheckOneDoesNotDeleteProductSaves`（断言备份+恢复逻辑）
    - [x] `testProductSaveSlotMatchesSource`（全部 MOD 的 `r1.grp` 逐字节一致）
    - [x] 实测检查 17 个 MOD，全部通过

## 5. 零引擎改动确认（REQ-SWEEV-4）

- [x] 5.1 检查改动路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `game/engine-love2d/**` 未改
    - [x] `game/engine-mud/**` 未改
    - [x] `game/script/jyconst.lua` 未改
    - [x] `reference/allmods/**` 未改

## 6. 验证报告（REQ-SWEEV-5）

- [x] 6.1 写 `reports/sweeOan-verify.md`
  Blast Radius: `["openspec/changes/allmods-sweeOan-verify/reports/sweeOan-verify.md"]`
  DoD:
    - [x] 结论摘要表
    - [x] `diff.md` 逐条审计表（14 + 23）
    - [x] MOD 独有内容非基线值证据
    - [x] 穷举审计输出
    - [x] 缺陷修复前后对比
    - [x] 零回归实测输出

## 7. 零回归

- [x] 7.1 全量测试与基线
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 867/867
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `unclassified=0`
    - [x] `format_spec --all` `gaps=0`

## 8. 验证

- [x] 8.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-sweeOan-verify/verification.md"]`
  DoD:
    - [x] 含 REQ-SWEEV-1~6 追溯矩阵
    - [x] 含缺陷修复证据
    - [x] 含 Blast Radius 合规检查
