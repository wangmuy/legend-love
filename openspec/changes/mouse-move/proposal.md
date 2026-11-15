---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: mouse-move — 点击地图自动寻路移动

## Why

鼠标 epic 的最后一块：**玩家点击地图上的格子，角色自动寻路走过去**，
以及鼠标悬停时的格子高亮。

当前状态：

```
全仓 grep "BFS|A*|pathfind|寻路"  → 0 处（无任何寻路算法）
主地图 480×480 = 230400 格
现有移动逻辑：一次按键走一格（Game_MMap / GAME_SMAP.update）
             无「走到某坐标」的驱动能力
```

## Parent Context

- Epic: `openspec/epics/2026-11-mouse-input/epic.md`
- Slice: `openspec/changes/mouse-slice3-mouse-move/slice-proposal.md`
- 依赖: `engine-capability`（slice 1）
- 不依赖: `mouse-menu`（slice 2，可并行）

## What Changes

1. **新建 `framework/pathfind.lua`**（纯算法，零引擎依赖，可完全单测）

```lua
Pathfind.find(startX, startY, goalX, goalY, isWalkable, opts)
  --> { {x=, y=}, {x=, y=}, ... }   路径（含起点与终点）
  --> nil                          不可达 / 超过 maxNodes

-- opts = { maxNodes = 5000 }      阻断搜索上限
```

实现：A* + 二叉堆 + 曼哈顿启发式（4 向移动下是一致的 admissible heuristic）。

2. **新建 `framework/mouse_hover.lua`**（坐标反解 + 悬停绘制 + 红闪）

```lua
MouseHover.screenToTile(sx, sy)          --> gx, gy    等距反解
MouseHover.draw(opts)                     -- 按条件绘制悬停菱形
MouseHover.flashDenied(tileX, tileY)      -- 红闪（200ms 节流）
MouseHover.update(dt)                     -- 红闪计时
```

3. **`game_states.lua`：MMAP / SMAP 加 AUTO_MOVING 分支**

```lua
-- 现有：IDLE 时读按键，一次走一格
-- 新增：AUTO_MOVING 时从路径队列取下一格，走一格
if JY.AutoMove and #JY.AutoMove.path > 0 then
    -- 消费一格（O(1)）
else
    -- 既有按键逻辑（零改动）
end
```

4. **`event_bridge.lua`：加悬停绘制钩子（位置 ①）**

```lua
StateMachine.getInstance():draw()
-- ← 新增：地图悬停高亮
if hoverOverlayCallback then hoverOverlayCallback() end
SceneNameAsync.draw()
```

5. **中断语义**

| 触发 | 行为 |
|------|------|
| 按键 | 中断 + **吃掉全部 repeat 直到 keyreleased** + 不响应为方向移动 |
| 路过事件 | 中断 + **不恢复剩余路径** |
| 进入子场景 | 中断 + **清空剩余路径** |

6. **寻路失败反馈**：红闪（`drawTinted` + `{1,0,0}`），200ms 节流

## Scope Boundaries

### In Scope

- A* + 二叉堆（含 `maxNodes` 阻断上限）
- 等距坐标反解（MMAP 与 SMAP 两套）
- 悬停菱形高亮（复用 picid 0）
- 红闪反馈 + 节流
- AUTO_MOVING 状态机（两套坐标系）
- 三种中断语义
- 单元测试 + 四 Lua 版本验证

### Out of Scope

- 菜单鼠标操作 → slice 2
- 路径预览（需求明确不要）
- 战斗内寻路（战斗已有自己的移动范围计算 `War_CalMoveStep`）
- 跨场景寻路（只能在同一张图内）
- 触摸 / 虚拟摇杆
- 寻路路径的平滑插值动画（沿用既有逐格走路贴图）

## Impact

| 区域 | 影响 |
|------|------|
| `game/framework/` | 新增 `pathfind.lua`、`mouse_hover.lua` |
| `game/framework/game_states.lua` | MMAP/SMAP 的 update 各加一个分支 |
| `game/framework/event_bridge.lua` | 加一个绘制钩子 |
| `game/script/jymain.lua` | **只读**（复用 `GetMMap` / `GetS` / `CanEnterScene`） |
| 既有行为 | IDLE 路径零改动；仅新增 AUTO_MOVING 分支 |
| 存档格式 | 无影响 |

## Risks

1. **A* 阻断搜索耗时** —— 「点击被墙隔离区域」要搜完整个连通区才确认不可达。
   可见范围约 2400 格（< 5ms），但连通区可能远超。
   **缓解**：`maxNodes` 上限（默认 5000），超限视为不可达；tasks 要求实测记录。
2. **等距反解的取整边界** —— `i1=(dx+dy)/2` 可能落在 x.5，floor 时机决定命中哪格。
   **缓解**：测试瓦片中心/四角/边界线的取整。
3. **两套坐标系统** —— MMAP 用 `人X/人Y` + `GetMMap`，SMAP 用 `人X1/人Y1` + `GetS`。
   **缓解**：分别实现，不抽公共层（两套语义差异大，抽象反而易错）。
4. **悬停高亮每帧重画** —— 地图每帧全屏重绘，菱形必须每帧画。
   **缓解**：单精灵 36×18，成本可忽略。

## Traceability

| REQ | 主题 |
|-----|------|
| REQ-MS3-1 | 悬停高亮 |
| REQ-MS3-2 | 点击寻路移动 |
| REQ-MS3-3 | 寻路不在 update 中 |
| REQ-MS3-4 | 中断语义 |
| REQ-MS3-5 | 鼠标开关联动 |
