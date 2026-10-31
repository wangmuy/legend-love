# Tasks — allmods-zheng-test

## Blast Radius

允许修改/新增的文件路径：

- `game/tests/unit/test_mod_encoding.lua`
- `game/tests/test_runner.lua`
- `openspec/changes/allmods-slice-zheng/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T3.1 `testIdxIsConsistentRejectsOvershoot` / `ToleratesTrailingPadding` / `RejectsMisalignedSegment`
- [x] T3.2 `testRepairIdxDetectsZhengLayout`（精确等于标准布局）
- [x] T3.3 `testRepairIdxLeavesGoodIdxUntouched`（pascal reason=nil）
- [x] T3.4 `testDetectLayoutZhengExact`
- [x] T3.5 `testConvertRangerNoReplacementCharsAllMods` / `NoControlCharsAllMods`
- [x] T3.6 **真实启动链路**（独立进程）：`boot_one_mod.lua zheng` → 320/200/84/93，
      主角「小蝦米」，扫描 1417 字段，0 U+FFFD、0 控制符，10 帧无报错
- [x] T3.7 接入 `test_mod_boot.lua` 的 `testFullBootChainForProblematicMods`（子进程，85 断言）

## 测试报告

详见 [`reports/test.md`](reports/test.md)。

## Definition of Done

- [x] `lua tests/unit/test_mod_encoding.lua` → 45/45
- [x] `lua tests/unit/boot_one_mod.lua zheng ...` → RESULT OK
- [x] 全量测试全绿
