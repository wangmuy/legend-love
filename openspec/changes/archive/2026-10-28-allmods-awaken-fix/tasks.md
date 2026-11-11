# Tasks — allmods-awaken-fix

## Blast Radius

允许修改/新增的文件路径：

- `game/tools/mod_encoding.lua`（`M.TrimControl`）
- `game/tools/mod_build.lua`（若需）
- `openspec/changes/allmods-slice-awaken/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T2.1 确认 `M.TrimControl` 同时处理尾部与内部 CR/LF
- [x] T2.2 重建 awaken，确认旁路表零控制符

## 修改报告

详见 [`reports/fix.md`](reports/fix.md)。

## Definition of Done

- [x] 修复已验证且无回归
