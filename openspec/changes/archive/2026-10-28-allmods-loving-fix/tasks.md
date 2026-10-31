# Tasks — allmods-loving-fix

## Blast Radius

允许修改/新增的文件路径：

- `game/framework/mod_ini.lua`
- `game/tools/mod_build.lua`（若需）
- `openspec/changes/allmods-slice-loving/**`

**不允许**修改：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`（只读源数据）。

## 任务

- [x] T2.1 定义 `NON_NEGATIVE_KEYS`（NewGameSceneID/NewGameEvent/SoftStarBeginTalk/BeginLeaveEvent）
- [x] T2.2 在 `ModIni.Map` 的 `setTarget` 前判定：负值跳过
- [x] T2.3 确认正数仍正常覆盖

## 修改报告

详见 [`reports/fix.md`](reports/fix.md)。

## Definition of Done

- [x] 修复已验证且无回归
