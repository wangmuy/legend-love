# Tasks: port-ui-screens-verification

> **策略**：先把「已经能拍到」的两张归档进基线（零代码改动），
> 再补存档界面（需要走出屋子），最后做状态页绘制解耦（有代码改动）。

## Task 1：归档三张实机截图（零代码改动）

**Blast Radius**：`docs/screenshots/`、`docs/screenshots/README.md`

**DoD**：
- [x] `item-menu.png`（物品 6 项分类菜单）—— 本轮已捕获
- [x] `item-grid.png`（名称/说明/3×N 格/页码）—— 本轮已捕获
- [x] `person-status.png`（两列属性 + 头像）—— 本轮已捕获
- [ ] `README.md` 加三行 + 截图参数（**本轮实测命令**，可复现）
- [ ] 标注三类判据（逐字节稳定 / 依赖存档 / 不稳定）
- [ ] 一个 commit

**本轮实测命令**（存档到 `%APPDATA%/LOVE/wangmuy.love2d.jygame/`）：

```bash
# 物品菜单
lovec game --shot=probe_item_menu2 --frame=5500 \
  --keys=return,down,return,return,<space×120>,escape,down,down,return

# 物品格
lovec game --shot=probe_item_grid --frame=5500 \
  --keys=<上>+return

# 人物状态
lovec game --shot=probe_status --frame=5600 \
  --keys=<上>+escape,down,down,down,return,return
```

## Task 2：补存档界面基线（需 `GAME_MMAP`）

**Blast Radius**：`docs/screenshots/save-menu.png`、`docs/screenshots/README.md`

**DoD**：
- [ ] 先走出开场屋子回主地图（`--keys` 固定路径）
- [ ] ESC → 系统（第 6 项）→ 保存进度（第 2 项）
- [ ] 截图归档 `save-menu.png`（三个进度槽）
- [ ] `README.md` 记录「必须主地图」的前置 + 完整按键序列
- [ ] 若走出屋子路径不稳定（遇敌/卡住）：改用「直接 `LoadRecord` 进主地图」的调试入口，
      并把限制记进 `TODO.md`
- [ ] 一个 commit

## Task 3：新建 `framework/status_page.lua`

**Blast Radius**：`game/framework/status_page.lua`（新）、
`game/framework/person_status_async.lua`、`game/script/jymain.lua`

**DoD**：
- [ ] `StatusPage.layout()`：几何公式逐字搬（`w=18*size+15` / `h=13*(size+RowPixel)+10`）
- [ ] `StatusPage.draw(id, page)`：26 处 `DrawString` + 1 处 `DrawBox` 改为
      `RenderFacade.text` / `RenderFacade.drawBox`，逐行对应
- [ ] `PersonStatusAsync.layout()` 改为转调 `StatusPage.layout()`
- [ ] `PersonStatusAsync.draw()` 改调 `StatusPage.draw(id, page)`
- [ ] `script/jymain.lua` 的 `ShowPersonStatus_sub` 改薄包装
      （`function ShowPersonStatus_sub(id,page) StatusPage.draw(id,page) end`）
- [ ] `status_page.lua` 零 `love.*` / 零 `require("engine` / 零 `JY.*`
- [ ] 一个 commit

## Task 4：战斗内状态页同源

**Blast Radius**：`game/script/battle/battle_flow_coroutines.lua`

**DoD**：
- [ ] `War_StatusMenuCoroutine` 走 `PersonStatusAsync.ShowStatusCoroutine`
      （已如此）；确认其绘制经 `PersonStatusAsync.draw` → `StatusPage.draw`
- [ ] 实机：战斗中选「状态」，截图与 `person-status.png` 同源数据可比
- [ ] 一个 commit

## Task 5：门禁补判据

**Blast Radius**：`game/tests/gate_engine_contract.sh`

**DoD**：
- [ ] STEP F 的 `script_globals` 变量追加：
      `ShowPersonStatus_sub|ShowPersonStatus|SelectTeamMenu|Menu_Thing`
- [ ] **负向对照**：往 `framework/person_status_async.lua` 加一处直接调
      `ShowPersonStatus_sub` → gate FAIL
- [ ] 新增 STEP K：`framework/status_page.lua` 零 `love.*` / 零 `require("engine`
- [ ] 五门禁 + 全量测试
- [ ] 一个 commit

## Task 6：更正 slice 收尾陈述

**Blast Radius**：`openspec/changes/engine-portability/change-manifest.md`、
`openspec/changes/engine-portability/slice-proposal.md`、`openspec/project/TODO.md`

**DoD**：
- [ ] 把「`Menu_Thing` / `ShowPersonStatus` 在事件驱动下不可达」改为
      「物品/状态可达（本轮已捕获基线）；存档需在主地图」
- [ ] `TODO.md`：删掉「实机未覆盖的界面」条目（或被本 change 取代）
- [ ] 一个 commit

## 依赖

```
Task 1 (归档三张) ──▶ Task 2 (补存档) ──▶ Task 6 (更正陈述)
        │
        └──▶ Task 3 (status_page) ──▶ Task 4 (战斗同源) ──▶ Task 5 (门禁)
```

- Task 1/2 与 3/4/5 可并行（前者只改 docs，后者改代码）
- Task 5 的负向对照**必须**在 Task 3 之后
