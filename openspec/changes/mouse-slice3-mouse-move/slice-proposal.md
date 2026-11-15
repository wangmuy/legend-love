---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

本 slice 补上鼠标 epic 的最后一块：**点击地图让角色自动寻路走过去**，
以及鼠标悬停时的格子高亮。

与 slice 2（菜单点击）不同，本 slice 涉及的是**游戏世界坐标**，需要：

```
  ① 屏幕坐标 → 等距格坐标（可逆，已验算）
  ② A* 寻路（当前全仓无寻路算法）
  ③ 自动移动状态机（现有逻辑是"一次按键走一格"，无"走到某处"的驱动）
```

**为什么独立成 slice**：它不与 slice 2 共享代码路径（slice 2 是菜单几何，
本 slice 是地图几何），且它有自己的技术风险（A* 性能、坐标精度、中断语义）。
与 slice 2 可并行开发。

## Parent Context

- Epic: `openspec/epics/2026-11-mouse-input/epic.md`
- Slice: 本文件即 slice 3
- 依赖: `mouse-slice1-engine-capability`（鼠标坐标、`drawTinted`、事件队列）
- 不依赖: `mouse-slice2-mouse-menu`（两者可并行）

## What Changes

1. **新建 `framework/pathfind.lua`**（纯算法，零引擎依赖）
   - A* + 二叉堆
   - 输入：`isWalkable(x, y)` 回调、起点、终点、可选 `maxNodes`
   - 输出：路径点数组，或 `nil`（不可达）

2. **新建 `framework/mouse_hover.lua`**（坐标反解 + 高亮绘制）
   - `screenToTile(sx, sy, camX, camY)` → `gx, gy`
   - `drawHover(tileX, tileY)` 用 `EngineAPI.sprite.drawTinted(0, 0, ...)`
   - 红闪状态（200ms 节流）

3. **`game_states.lua` 加 AUTO_MOVING 状态**
   - `GAME_MMAP.update` 与 `GAME_SMAP.update` 各加一个分支
   - 路径队列消费（O(1) 每帧）
   - 中断语义（按键吃 repeat / 事件 / 进子场景）

4. **`event_bridge.lua` 加悬停绘制钩子**
   - 位置：`StateMachine:draw()` 之后、`SceneNameAsync.draw()` 之前（位置 ①）

5. **`jymain.lua` 只读参考**：复用 `GetMMap` / `GetS` / `CanEnterScene` 等判可走性

## Scope Boundaries

### In Scope

- A* 寻路（含二叉堆、最大节点限制用于阻断搜索）
- 等距坐标反解（MMAP + SMAP 两套坐标）
- 悬停菱形高亮（复用 picid 0）
- 红闪反馈（`drawTinted` + 200ms 节流）
- AUTO_MOVING 状态机与中断语义
- 测试 + 四 Lua 版本验证

### Out of Scope

- 菜单鼠标操作 → slice 2
- 路径预览（需求明确不要）
- 战斗内寻路
- 触摸 / 虚拟摇杆
- 跨场景寻路（只能在同一张图内）
- 寻路结果的平滑动画（逐格移动，沿用既有走路贴图切换）

## Requirements

### REQ-MS3-1 悬停高亮

鼠标在地图内移动时，在所指格子绘制菱形；有菜单/阻塞输入/非地图状态时不绘制。

### REQ-MS3-2 点击寻路移动

点击可达格 → 计算路径 → 沿路径逐格移动；点击不可达格 → 红闪，不移动。

### REQ-MS3-3 寻路不在 update 中

A* 只在点击瞬间执行一次；`update` 每帧只做 O(1) 的路径队列消费。

### REQ-MS3-4 中断语义

按键（吃全部 repeat）/ 事件触发（不恢复）/ 进入子场景（清空路径）三种中断。

### REQ-MS3-5 鼠标开关联动

鼠标开关关闭时，悬停高亮、点击寻路全部不生效。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（新增状态分支，既有 IDLE 路径不变）
- 回归风险：中（要改 `game_states.lua` 的两个 update 分支）

## 关键设计决策（详见 `mouse-move/design.md`）

| ADR | 决策 |
|-----|------|
| ADR-MS3-001 | 等距反解就地实现，不引入相机抽象（当前相机恒为屏幕中心） |
| ADR-MS3-002 | A* 用二叉堆 + 曼哈顿启发式（4 向移动，启发式必须一致） |
| ADR-MS3-003 | 阻断搜索设 `maxNodes` 上限，超限视为不可达（防卡顿） |
| ADR-MS3-004 | AUTO_MOVING 作为 `JY` 上的独立字段，不新增 `GAME_*` 状态常量 |
| ADR-MS3-005 | 中断用「drain 标志」吃掉 repeat，直到 `keyreleased` |
| ADR-MS3-006 | 悬停绘制插在 `EventBridge:draw()` 内（位置 ①），不改各 state 的 draw |
