# Tasks — allmods-pig3dos-dod

## Blast Radius

允许修改/新增的文件路径：

- `openspec/changes/allmods-slice-pig3dos/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T4.1 `lua tools/mod_check.lua` → 20/20
- [x] T4.2 `lua tools/mod_build.lua --verify-pascal` → PASS
- [x] T4.3 `MOD_SLUG=pig3dos lua tools/mod_check_one.lua` → PERSON=607 THING=242 SCENE=133 WUGONG=202 STRINGS=OK
- [x] T4.4 `lua tests/test_runner.lua` → 全绿
- [x] T4.5 产出 `reports/dod.md`

## Definition of Done

- [x] `reports/dod.md` 已产出
