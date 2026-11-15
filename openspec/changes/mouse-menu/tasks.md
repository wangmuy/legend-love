# Tasks: mouse-menu

## Blast Radius

### 新增

- `game/framework/mouse_menu.lua`
- `game/tests/unit/test_mouse_menu.lua`
- `game/tests/unit/test_menu_hit_test.lua`

### 修改

- `game/framework/menu_state_machine.lua`
- `game/framework/jymain_async.lua`
- `game/framework/jymain_adapter.lua`
- `game/main.lua`
- `game/tests/test_runner.lua`

### 不得触碰

- `game/framework/settings.lua`（slice 1 已定型）
- `game/framework/input_manager.lua`（slice 1 已定型）
- `game/engine-*/`（slice 1 已定型）
- `game/framework/game_states.lua`（slice 3 才改）
- `game/script/jymain.lua`

---

## T1: 命中测试纯函数

- [x] 抽出 `local function rowY(menu, i)` 供 draw 与 hitTest 共用（避免两处公式不同步）
- [x] `hitMenu(menu, x, y)` → 点是否在菜单矩形内
- [x] `hitItem(menu, x, y)` → 命中项索引（含 `menu.start` 滚动偏移）
- [x] `hitValueLine(menu, i, x, y)` → 值项的第 1/2/3 行（▲ / 值 / ▼）
- [x] 边界：点在矩形内但 `i > newNumItem` → 返回 nil（空白区无动作）
- [x] **DoD**: `test_menu_hit_test.lua` 覆盖 8 种几何（含 start>1、num<total）

## T2: 点击分发

- [x] `MenuStateMachine:handleMouseClick(x, y)` 总入口
- [x] 命中当前菜单项 → `menu.current = i` + `selectMenuItem()`（复用既有）
- [x] 命中值项 ▲/▼ → 改 `desc.pending`（钳制，不回绕）
- [x] 命中值项中间行 → 无动作
- [x] 点在菜单外 → `closeMenu(0)`
- [x] 点在矩形内空白区 → 无动作（不关闭）
- [x] **DoD**: 键盘路径代码零改动（diff 只新增分支）

## T3: 子菜单切换语义

- [x] `MenuStateMachine:popToDepth(depth)`：逐层 `doCloseMenu()` 到指定深度
- [x] 点击落在父菜单上时：先 `popToDepth` 再 `clickRow`
- [x] 防重入：`popToDepth` 期间 `menu.state == EXECUTING` 时不重复触发
- [x] **DoD**: 三级菜单场景测试通过（主→子→孙，点主菜单其他项）

## T4: 右键呼出菜单

- [x] 右键事件识别（`button == 2`）
- [x] 条件判断：`GAME_MMAP` 或 `GAME_SMAP`
- [x] 条件判断：`not (JY.CurrentD >= 0)`
- [x] 条件判断：`not InputManager.disableInput`
- [x] 条件判断：`not MenuAsync.hasActiveMenu()`
- [x] 条件判断：`Settings.get("input.mouse") == true`
- [x] 全部满足 → 调用既有 `startMenuCoroutine()`
- [x] **DoD**: 6 个条件各有一条测试（含负向：条件不满足时不呼出）

## T5: 「鼠标操作」开关项

- [x] 新建 `game/framework/mouse_menu.lua`
- [x] `MouseMenu.KEY = "input.mouse"`
- [x] `MouseMenu.buildToggleItem()` → 普通菜单项 + 回调 `return 0`
- [x] 回调内更新 `menu[current][1]`（文本「开」/「关」）
- [x] `MouseMenu.define()` → `Settings.define` 含 `platformDefaults`
- [x] **DoD**: 上下键在 toggle 行上是导航（`Settings` 值不变）

## T6: 菜单接入

- [x] `jymain_adapter.lua` `showSettingsCoroutine`：加「鼠标操作」项
- [x] `jymain_async.lua` `Menu_System`：加「鼠标操作」项
- [x] 两处都调用 `MouseMenu.define()`（幂等）
- [x] **DoD**: 布局不溢出（开始菜单设置 3→4 项，余量 20px；大地图系统 5→6 项，余量 585px）

## T7: `main.lua` 注册鼠标回调

- [x] `love.mousepressed(x, y, button)` → `enqueueMouseEvent({type="pressed", ...})`
- [x] `love.mousereleased(x, y, button)` → `enqueueMouseEvent({type="released", ...})`
- [x] 鼠标开关关闭时**不入队**（减少无用事件）
- [x] **DoD**: 现有键盘回调未受影响

## T8: 鼠标消费接线

- [x] `menu_state_machine` 在 `update()` 里消费鼠标事件（仅菜单激活时）
- [x] 无菜单时**不消费**（留给 slice 3）
- [x] **DoD**: 菜单关闭后，鼠标事件仍留在队列（slice 3 可读到）

## T9: 测试

- [x] `test_menu_hit_test.lua`：几何命中（8 场景）
- [x] `test_mouse_menu.lua`：toggle 项、上下键导航、文本更新
- [x] `test_menu_value_item.lua` 扩展：鼠标点击值项箭头
- [x] `test_menu_state_machine` 扩展：点击分发、子菜单切换、点外部关闭
- [x] `test_runner.lua`：注册新模块
- [x] **DoD**: 全量测试四版本全绿
- [x] **DoD**: 负向对照：把 `rowY` 里的 `(i - menu.start)` 改成 `(i - 1)`
      → 滚动菜单命中测试必须失败

## DoD 汇总（change 级）

1. [x] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿
2. [x] `luac5.1 -p` 与 `luac5.5 -p` 全仓零失败
3. [x] 键盘菜单路径行为与改动前完全一致（既有测试零回归）
4. [x] 右键 6 个屏蔽条件各有测试
5. [x] 滚动菜单（start>1）命中正确
6. [x] 子菜单切换：先关子菜单再响应（无回调丢失、无协程挂起）
7. [x] 「鼠标操作」切换即时生效 + 持久化
8. [x] 菜单关闭时鼠标事件不被消费（留给 slice 3）
9. [x] LÖVE 11.5 实机：右键呼出、点击选中、点外部关闭、开关切换均正常
10. [x] 负向对照：`rowY` 去掉 start 偏移 → 命中测试失败
11. [x] 负向对照：toggle 项去掉 `return 0` → 菜单会关闭（违反需求）
