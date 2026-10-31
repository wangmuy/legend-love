# Tasks — allmods-zheng-reverse

## Blast Radius

允许修改/新增的文件路径：

- `openspec/changes/allmods-slice-zheng/**`
- `/tmp/*.lua`（临时审计脚本）

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T1.1 复现 zheng 的 Thing/Scene/Wugong 缺陷
- [x] T1.2 比对 zheng 与 pascal 的 `ranger.grp` 头 16 字节
- [x] T1.3 用标准 idx 全量解码 zheng，确认零 U+FFFD
- [x] T1.4 全 20 MOD idx 一致性扫描，确认只有 zheng/pineapple 异常
- [x] T1.5 产出 `reports/reverse.md`

## Definition of Done

- [x] `reports/reverse.md` 已产出
