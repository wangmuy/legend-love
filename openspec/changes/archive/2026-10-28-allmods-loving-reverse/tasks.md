# Tasks — allmods-loving-reverse

## Blast Radius

允许修改/新增的文件路径：

- `openspec/changes/allmods-slice-loving/**`
- `/tmp/*.lua`（临时审计脚本）

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T1.1 确认 loving 字段级零缺陷（0 FFFD / 0 控制符 / 0 空值）
- [x] T1.2 读取 loving `kysmod.ini`，确认 `BEGIN_SCENE = -1` / `BEGIN_EVENT = -1`
- [x] T1.3 追踪引擎：`jymain_adapter.lua:346` 无条件 `JY.Scene[CC.NewGameSceneID]`
- [x] T1.4 确认原版 `base` 无 `kysmod.ini`（硬编码 70），`-1` 是启动器语义
- [x] T1.5 产出 `reports/reverse.md`

## Definition of Done

- [x] `reports/reverse.md` 已产出
