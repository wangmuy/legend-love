# Tasks: allmods-stronger-verify

## 1. `diff.md` 逐条审计（REQ-STRV-1）

- [x] 1.1 审计 13 项 MOD 独有
  Blast Radius: `["openspec/changes/allmods-stronger-verify/reports/**"]`
  DoD:
    - [x] 12 项判定为预期资源
    - [x] `kysmod.ini` 判定为 `BUILD_INPUT`（在产物中）
    - [x] 需修复项 = 0
    - [x] 注明 stronger 无 `修改档说明.txt`

## 2. 「基准独有」逐项定性（REQ-STRV-2）

- [x] 2.1 用文件系统事实 + 运行时 `CC.*` 值定性 21 项
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 回退原版 17
    - [x] 在 save/ 3
    - [x] 死文件 1
    - [x] `17+3+1 = 21`，无未解释项

## 3. MOD 独有内容验证（REQ-STRV-3）

- [x] 3.1 用非基线值证明加载来自 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 主角姓名 = 韋大寶（pascal = 小蝦米）
    - [x] `JY.Person[1]` = 胡斐
    - [x] `JY.Person[2]` = 程靈素
    - [x] 对话条目数 = 3727（pascal 2977）

- [x] 3.2 核对资源路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 路径全部指向 `mods/stronger/`
    - [x] `CC.ThingPicFile[1]` = `data/thing.idx`（回退原版）

## 4. 缺陷 A：`kysmod.ini` `in_product` 误判（REQ-STRV-4）

- [x] 4.1 定位并确认误判
  Blast Radius: `[]`（只读调查）
  DoD:
    - [x] 现象：`in_product=false` 但文件在 `data/`
    - [x] 根因 1：`IN_PRODUCT_BY_CATEGORY[BUILD_INPUT]=false` 一刀切
    - [x] 根因 2：`productCandidates` 无 `topdir==""` 分支
    - [x] 验证：类别改 `true` 产生 4 个新矛盾（`cc/*.txt`）

- [x] 4.2 修复：per-rule `in_product` 覆盖 + 根级候选路径
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] `checkInProduct` 支持 `rule.in_product` 覆盖
    - [x] `productCandidates` 新增 `topdir==""` → `data/`
    - [x] `kysmod.ini` 规则显式 `in_product=true`

- [x] 4.3 修正证据文本（与代码一致）
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] ref 改为 `game/tools/mod_build.lua`
    - [x] cmd 改为 `grep -n 'kysmod' tools/mod_build.lua`
    - [x] text 改为「构建器复制到 data/（mod_build.lua:879-882）；引擎不读」

- [x] 4.4 验证修复
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 20/20 MOD 的 `kysmod.ini` `in_product=true`
    - [x] `cc/*.txt` 全部 `in_product=false`
    - [x] 矛盾数 = 0
    - [x] `mod_audit --all --evidence` `failed=0`

- [x] 4.5 新增回归测试 + 派生断言
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] `testKysmodIniIsBuildInputButShipped`
    - [x] `testCcDictsAreBuildInputAndNotShipped`
    - [x] 未进产物/REQUIRED/PENDING 断言改为派生
    - [x] `testNoRequiredFileMissingFromProduct` 读 per-rule 覆盖
    - [x] `mod_audit` 测试 249/249

## 5. 缺陷 B：`test_mod_boot` 销毁产物 `r1.grp`

- [x] 5.1 定位并确认
  Blast Radius: `[]`（只读调查）
  DoD:
    - [x] 现象：测试后 mingdong `r1.grp` = 223688 B（源 222888 B）+ 残留
    - [x] 根因：`test_mod_boot.lua:271` `os.execute("rm -f ...r1.grp")` + `SaveRecord(1)`
    - [x] 影响：mingdong 自带 `r1.grp`，每次全量测试都被销毁

- [x] 5.2 修复：备份 + 恢复
  Blast Radius: `["game/tests/unit/test_mod_boot.lua"]`
  DoD:
    - [x] 测试前备份 `r1.grp`/`r1.idx`/`r1.ovr`/`s1.grp`/`d1.grp`
    - [x] 测试后 `restoreSlots()` 字节级恢复
    - [x] 新增 `testProductSavesNotDestroyedByTests`（runAll 末位）

- [x] 5.3 验证修复
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_mod_boot` 85/85
    - [x] 测试后 mingdong `r1.grp` = 222888 B（= 源）
    - [x] 无 `r1.idx`/`r1.ovr` 残留
    - [x] 20/20 MOD 的 `save/r1.grp` 与源一致

## 6. 零引擎改动确认（REQ-STRV-5）

- [x] 6.1 检查改动路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `game/engine-love2d/**` 未改
    - [x] `game/engine-mud/**` 未改
    - [x] `game/script/jyconst.lua` 未改
    - [x] `reference/allmods/**` 未改

## 7. 验证报告（REQ-STRV-6）

- [x] 7.1 写 `reports/stronger-verify.md`
  Blast Radius: `["openspec/changes/allmods-stronger-verify/reports/stronger-verify.md"]`
  DoD:
    - [x] 结论摘要表
    - [x] `diff.md` 逐条审计表（13 + 21）
    - [x] MOD 独有内容非基线值证据
    - [x] 两个缺陷的修复前后对比
    - [x] 零回归实测输出

## 8. 零回归

- [x] 8.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 958/958
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `unclassified=0`
    - [x] `mod_audit --all --evidence` `failed=0`
    - [x] `format_spec --all` `gaps=0`

## 9. 验证

- [x] 9.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-stronger-verify/verification.md"]`
  DoD:
    - [x] 含 REQ-STRV-1~6 追溯矩阵
    - [x] 含两个缺陷的修复证据
    - [x] 含 Blast Radius 合规检查
