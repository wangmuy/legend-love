# Tasks — allmods-awaken-test

## Blast Radius

允许修改/新增的文件路径：

- `game/tests/unit/test_mod_encoding.lua`
- `game/tests/unit/test_mod_ini.lua`
- `game/tests/test_runner.lua`
- `openspec/changes/allmods-slice-awaken/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T3.1 `testTrimControlInteriorCrLf` 覆盖 `大剪刀\r\n刀法` → `大剪刀刀法`
- [x] T3.2 `testConvertRangerNoControlCharsAllMods` 覆盖 awaken
- [x] T3.3 **真实启动链路**（独立进程）：`boot_one_mod.lua awaken` → 720/237/153/163，
      主角「北辰月」，扫描 2467 字段，0 U+FFFD、0 控制符，10 帧无报错

## 测试报告

详见 [`reports/test.md`](reports/test.md)。

## Definition of Done

- [x] 修复已验证且无回归
