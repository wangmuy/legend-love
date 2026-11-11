# Tasks — allmods-pig3dos-test

## Blast Radius

允许修改/新增的文件路径：

- `game/tests/unit/test_mod_encoding.lua`
- `game/tests/unit/test_mod_ini.lua`
- `game/tests/test_runner.lua`
- `openspec/changes/allmods-slice-pig3dos/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T3.1 `testConvertRangerSkipsNumericFields`：pig3dos skipped=607、Person.converted=607
- [x] T3.2 `testConvertRangerConvertsMixedAsciiBig5Fields`：mingdong `53，219` 入表
- [x] T3.3 `testConvertRangerNoReplacementCharsAllMods` / `testConvertRangerNoControlCharsAllMods`
- [x] T3.4 **新增**：`testConvertRangerSkipsNumericFields` 断言外号槽位为可解析 hint `N0000`、
      Person 段共享空条目恰好 1 个（本轮新发现的修复）
- [x] T3.5 **新增**：`testSkippedFieldNeutralisedForAllMods`（全 20 MOD，命中 7 个）
- [x] T3.6 **真实启动链路**（独立进程）：`boot_one_mod.lua pig3dos` → 607/242/133/202，
      主角「主角」，扫描 2275 字段，0 U+FFFD、0 控制符，10 帧无报错

## 测试报告

详见 [`reports/test.md`](reports/test.md)。

## Definition of Done

- [x] 修复已验证且无回归
