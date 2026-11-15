---
status: active
parent_epic: 2026-11-mouse-input
---
# Change Manifest: mouse-slice3-mouse-move — 鼠标地图移动

> 本 slice 只有一个子 change，位于 `openspec/changes/mouse-move/`（与 slice 目录同级）。

## Change Assignments

### Change: mouse-move

- **Repository**: this repo
- **Scope**: fullstack（framework 新模块 + game_states 状态机 + 绘制钩子 + 测试）
- **Responsibility**:
  1. 新建 `framework/pathfind.lua`：A* + 二叉堆，纯算法零引擎依赖
     - `Pathfind.find(startX, startY, goalX, goalY, isWalkable, opts)`
     - 返回路径点数组或 nil；`opts.maxNodes` 限制（阻断搜索防卡顿）
  2. 新建 `framework/mouse_hover.lua`：坐标反解 + 悬停菱形 + 红闪
     - `screenToTile(sx, sy)` → `gx, gy`（等距反解，已验算可逆）
     - `draw(menuActive, inputBlocked)` → 按条件决定是否绘制
     - 红闪状态机（200ms 节流）
  3. `game_states.lua`：MMAP / SMAP 的 update 加 AUTO_MOVING 分支
     - 路径队列消费（O(1)/帧）
     - 中断：按键 drain / 事件 / 进子场景
  4. `event_bridge.lua`：加悬停绘制钩子（`StateMachine:draw()` 之后）
  5. 单元测试：A*（含阻断、不可达、起终点相同）、坐标反解、
     移动状态机、中断语义
- **Depends On**: `engine-capability`（slice 1）
- **Status**: [ ] Pending

---

## 依赖图

```
  engine-capability (slice 1)
        │  EngineAPI.input.mousePosition
        │  EngineAPI.sprite.drawTinted
        │  enqueueMouseEvent / getMouseEvent
        │  Settings.get("input.mouse")
        ▼
  mouse-move (本 slice)
```

## 与 slice 2 的关系

**互不依赖，可并行。** 唯一的共享资源是 slice 1 的鼠标事件队列：

```
  有菜单时   →  slice 2 消费鼠标事件
  无菜单时   →  slice 3 消费鼠标事件
  （slice 2 的 tasks T8 已明确「无菜单时不消费」）
```

## 本 slice 的关键风险

### 1. A* 阻断搜索的最坏耗时

「点击被墙完全隔离的区域」时，A* 要搜完整个连通区才能确认不可达。

```
  可见范围 ≈ 2400 格 → < 5ms
  但连通区可能远超 2400（如大块开放区域）
  → 必须设 maxNodes 上限
```

**缓解**：`opts.maxNodes`（建议默认 5000），超限即返回 nil（视为不可达）。
tasks 里要求实测记录真实耗时。

### 2. 等距反解的取整边界

```
  i1 = (dx + dy) / 2
  j1 = (dy - dx) / 2
  → 结果可能落在 x.5 边界上，floor 的时机决定命中哪一格
```

需测试「点在瓦片正中心 / 四个角 / 边界线上」的取整结果。

### 3. 两套坐标系统

```
  MMAP:  JY.Base["人X"] / ["人Y"]     范围 480×480
  SMAP:  JY.Base["人X1"] / ["人Y1"]   范围 64×64
```

且 SMAP 走的是 `GetS(sceneid, x, y, layer)`，MMAP 走 `GetMMap(x, y, layer)`。
**两套可走性判定必须分别实现**，不能混用。

### 4. 悬停高亮的绘制时机

位置 ① 意味着菱形在 `StateMachine:draw()` 之后、其他 UI 之前。
但地图每帧全屏重绘（`DrawMMap` 内部 `FillColor(0,0,0,0,0)`），
所以菱形必须**每帧重画**，不能依赖「画一次留在屏幕上」。
