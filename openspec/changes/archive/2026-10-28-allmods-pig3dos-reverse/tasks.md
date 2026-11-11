# Tasks — allmods-pig3dos-reverse

## Blast Radius

允许修改/新增的文件路径：

- `openspec/changes/allmods-slice-pig3dos/**`
- `/tmp/*.lua`（临时审计脚本）

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T1.1 复现 pig3dos Person 565 控制符 + 42 空值
- [x] T1.2 打印 r0..r9 的 @18 槽位字节，确认是 int16 数值（`0700070007000a00`）
- [x] T1.3 全 607 条统计：@18 含高位字节 = 0
- [x] T1.4 全 20 MOD 扫描「含高位字节但不以 Big5 pair 开头」字段：23 个（Dragon/pig/books/BookCalamity/mingdong）
- [x] T1.5 产出 `reports/reverse.md`

## Definition of Done

- [x] `reports/reverse.md` 已产出
