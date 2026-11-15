# Tasks: mouse-move

## Blast Radius

### 新增

- `game/framework/pathfind.lua`
- `game/framework/mouse_hover.lua`
- `game/tests/unit/test_pathfind.lua`
- `game/tests/unit/test_mouse_hover.lua`
- `game/tests/unit/test_auto_move.lua`

### 修改

- `game/framework/game_states.lua`
- `game/framework/event_bridge.lua`
- `game/framework/jymain_adapter.lua`（初始化时注册悬停钩子）
- `game/tests/test_runner.lua`

### 只读参考（不改）

- `game/script/jymain.lua`（`GetMMap` / `GetS` / `GetD` / `CanEnterScene` / `SceneCanPass`）
- `game/framework/menu_state_machine.lua`（slice 2 已定型）
- `game/framework/settings.lua`、`input_manager.lua`、`engine-*/`（slice 1 已定型）

---

## T1: `framework/pathfind.lua` — 二叉堆 + A*

- [x] 二叉堆：`push(heap, node, priority)` / `pop(heap)`，按 `f` 值最小优先
- [x] `Pathfind.find(sx, sy, gx, gy, isWalkable, opts)` → `path, err`
- [x] 起终点相同 → 返回仅含起点的路径（不是空）
- [x] 目标不可站立 → `nil, "goal-unwalkable"`
- [x] 不可连通 → `nil, "no-path"`
- [x] 超 `maxNodes`（默认 5000）→ `nil, "exceeded-max-nodes"`
- [x] 4 向移动 + 曼哈顿启发式（ADR-MS3-002）
- [x] 用 `visited` 表去重（key 用 `x * 10000 + y` 或字符串）
- [x] **DoD**: `grep -E "EngineAPI|love\.|CC\.[A-Za-z]|JY\.[A-Za-z]"` 为空（纯算法）
- [x] **DoD**: `test_pathfind.lua` 覆盖 6 种场景（直线/绕障/不可达/同点/单步/超限）

## T2: `framework/mouse_hover.lua` — 反解 + 悬停 + 红闪

- [x] `screenToTile(sx, sy)` → `gx, gy`（**必须 +0.5 再 floor**，ADR-MS3-001）
- [x] `tileToScreen(gx, gy)` → `sx, sy`（反向，供绘制）
- [x] `MouseHover.update(dt)`：红闪计时（200ms 节流 + 持续时长）
- [x] `MouseHover.flashDenied(gx, gy)`：触发红闪
- [x] `MouseHover.draw()`：按 5 条条件决定是否绘制悬停 / 红闪
- [x] 悬停用 `drawTinted(0, 0, x, y, {0,0,0}, 64)`
- [x] 红闪用 `drawTinted(0, 0, x, y, {1,0,0}, 180)`
- [x] **DoD**: `test_mouse_hover.lua` 断言 289 格中心往返 100% 精确
- [x] **DoD**: 菱形内部 13858 点采样，0 偏离

## T3: `event_bridge.lua` 悬停绘制钩子

- [x] 新增 `EventBridge.setHoverOverlay(callback)` / `clearHoverOverlay()`
- [x] 在 `EventBridge:draw()` 里 `StateMachine:draw()` **之后**调用
- [x] 用 `pcall` 隔离（钩子抛错不中断渲染）
- [x] **DoD**: 顺序断言 —— 钩子被调用时 `StateMachine:draw()` 已完成

## T4: `game_states.lua` AUTO_MOVING 分支（MMAP）

- [x] `JY.AutoMove` 字段定义（`path` / `index` / `drain` / `mapKind`）
- [x] `mmapWalkable(x, y)`：边界 `[10, MWidth-10]` + `GetMMap(x,y,3)==0 and (x,y,4)==0`
- [x] `GAME_MMAP.update`：`JY.AutoMove` 存在时走自动移动分支（否则既有逻辑）
- [x] 自动移动每帧：从 `path[index]` 取下一格 → 移动一格 → `index + 1`
- [x] 到达终点 → `JY.AutoMove = nil`
- [x] 鼠标点击处理：`screenToTile` → `isWalkable` → `Pathfind.find` → 设置 `JY.AutoMove`
- [x] 不可达 → `MouseHover.flashDenied`
- [x] **DoD**: 既有键盘走路路径代码零改动（diff 只新增分支）

## T5: `game_states.lua` AUTO_MOVING 分支（SMAP）

- [x] `smapWalkable(sceneid, x, y)`：边界 `[1, SWidth-2]` + **调用 `SceneCanPass`**
- [x] `GAME_SMAP.update`：同 T4 的分支结构
- [x] 坐标系用 `人X1/人Y1`（不是 `人X/人Y`）
- [x] **DoD**: `grep "SceneCanPass" framework/game_states.lua` 必须命中（证明复用）
- [x] **DoD**: 不得出现自行重写的水面/物品/事件判定

## T6: 中断语义

- [x] 按键中断：设 `JY.AutoMove.drain = { key = k }`，清空 `JY.AutoMove.path`
- [x] drain 期间 `getKey()` 返回 -1（只吃被中断的那个键的 repeat）
- [x] `keyreleased` 时解除 drain
- [x] drain 超时保护（2 秒）
- [x] 事件触发中断：路过事件时清空 `JY.AutoMove`（不设 drain）
- [x] 进子场景：清空 `JY.AutoMove`
- [x] 进战斗：`GAME_WMAP.enter` 时清空
- [x] 自动移动中再次点击 → 重新计算路径（覆盖旧路径）
- [x] **DoD**: 三种中断各有测试（含「吃 repeat 不响应为方向移动」）

## T7: 走法判定复用验证

- [x] 逐行对照 `Game_MMap`（`jymain.lua:429`）确认 MMAP 判定一致
- [x] 逐行对照 `SceneCanPass`（`jymain.lua:1512`）确认 SMAP 直接调用
- [x] **DoD**: 测试断言「A* 路径上每格都满足 isWalkable」
- [x] **DoD**: 测试断言「键盘沿同一路径可走完」（交叉验证）

## T8: 测试

- [x] `test_pathfind.lua`：6 场景 + 性能（2400 格可见范围 < 50ms）
- [x] `test_mouse_hover.lua`：反解精度（289 格中心 + 菱形内部采样）+ 红闪节流
- [x] `test_auto_move.lua`：状态机 + 三种中断 + drain 语义
- [x] `test_runner.lua`：注册 3 个新模块
- [x] **DoD**: 全量测试四版本全绿
- [x] **DoD**: 负向对照：`screenToTile` 去掉 `+0.5` → 反解测试必须失败
- [x] **DoD**: 负向对照：`smapWalkable` 改为自行判定 → 水面测试必须失败

## T9: 性能实测记录

- [x] 可见范围（~2400 格）内正常寻路的耗时
- [x] 阻断搜索（点被墙隔离区域）到 `maxNodes` 上限的耗时
- [x] 记录到 `design.md` 或独立 report
- [x] **DoD**: 阻断搜索耗时 < 100ms（否则调小 maxNodes）

## DoD 汇总（change 级）

1. [x] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿
2. [x] `luac5.1 -p` 与 `luac5.5 -p` 全仓零失败
3. [x] `pathfind.lua` 零引擎依赖（grep 为空）
4. [x] 反解精度：289 格中心 100%，菱形内部 0 偏离
5. [x] A* 只在点击时调用，update 中只消费队列
6. [x] 三种中断语义各有测试
7. [x] SMAP 复用 `SceneCanPass`，MMAP 与 `Game_MMap` 逐字一致
8. [x] 悬停绘制位置在 `StateMachine:draw()` 之后
9. [x] 可见范围寻路 < 50ms，阻断搜索 < 100ms（实测记录）
10. [x] LÖVE 实机：悬停高亮、点击走路、红闪、三种中断均正常
11. [x] 负向对照：反解去掉 `+0.5` → 测试失败
12. [x] 负向对照：重写 SMAP 判定 → 水面测试失败
