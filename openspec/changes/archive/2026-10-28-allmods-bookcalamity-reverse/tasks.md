# Tasks — allmods-bookcalamity-reverse

## Blast Radius

允许修改/新增的文件路径：

- `openspec/changes/allmods-slice-bookcalamity/**`
- `/tmp/*.lua`（临时审计脚本）

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T1.1 复现 BookCalamity Thing 的 3 个控制符字段
- [x] T1.2 打印原始字节，确认是 `0d 0a`（CRLF）
- [x] T1.3 全 20 MOD 扫描：仅 BookCalamity/awaken/Dragon 命中，共 5 个内部 CRLF + 若干尾部 CRLF
- [x] T1.4 产出 `reports/reverse.md`

## Definition of Done

- [x] `reports/reverse.md` 已产出
