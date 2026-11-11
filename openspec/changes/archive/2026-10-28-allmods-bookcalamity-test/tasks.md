# Tasks — allmods-bookcalamity-test

## Blast Radius

允许修改/新增的文件路径：

- `game/tests/unit/test_mod_encoding.lua`
- `game/tests/unit/test_mod_ini.lua`
- `game/tests/test_runner.lua`
- `openspec/changes/allmods-slice-bookcalamity/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T3.1 新增 `testTrimControlTrailingCrLf` / `testTrimControlInteriorCrLf` / `testTrimControlKeepsPlainText` / `testTrimControlStripsTrailingNulLikeControls`
- [x] T3.2 新增 `testTrimControlRealBookCalamityField`（真实字段 `大燕傳國玉璽`）
- [x] T3.3 新增 `testConvertRangerNoControlCharsAllMods`（全 20 MOD 零控制符）
- [x] T3.4 **真实启动链路**（独立进程）：`boot_one_mod.lua BookCalamity` → 800/550/139/398，
      主角「主角」，扫描 3787 字段，0 U+FFFD、0 控制符，10 帧无报错

## 测试报告

详见 [`reports/test.md`](reports/test.md)。

## Definition of Done

- [x] 修复已验证且无回归
