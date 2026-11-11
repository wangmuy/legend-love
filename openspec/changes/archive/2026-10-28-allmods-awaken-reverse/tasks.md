# Tasks — allmods-awaken-reverse

## Blast Radius

允许修改/新增的文件路径：

- `openspec/changes/allmods-slice-awaken/**`
- `/tmp/*.lua`（临时审计脚本）

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T1.1 复现 awaken Thing 的 6 个控制符字段
- [x] T1.2 区分尾部 CRLF（r88/r110/r187）与内部 CRLF（r89）
- [x] T1.3 产出 `reports/reverse.md`

## Definition of Done

- [x] `reports/reverse.md` 已产出
