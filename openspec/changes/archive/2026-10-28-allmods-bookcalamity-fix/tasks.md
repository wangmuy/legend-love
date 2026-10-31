# Tasks — allmods-bookcalamity-fix

## Blast Radius

允许修改/新增的文件路径：

- `game/tools/mod_encoding.lua`（`M.TrimControl`）
- `game/tools/mod_build.lua`（若需）
- `openspec/changes/allmods-slice-bookcalamity/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T2.1 实现 `M.TrimControl(raw)`（尾部 C0 + 折叠内部 CR/LF）
- [x] T2.2 在 `ConvertRanger` 的字符串分支解码前调用
- [x] T2.3 重建全部 MOD，确认无新溢出

## 修改报告

详见 [`reports/fix.md`](reports/fix.md)。

## Definition of Done

- [x] 修复已验证且无回归
