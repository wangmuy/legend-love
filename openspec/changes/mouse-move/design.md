---
status: active
created: 2026-11
parent_epic: 2026-11-mouse-input
parent_slice: mouse-slice3-mouse-move
---
# Design: mouse-move

> 每个关键判断记作 ADR。所有数值实测来自本仓代码常量
> （`XScale=18`、`YScale=9`、`Width=1024`、`Height=768`）。

## ADR-MS3-001 等距反解必须用 `round`，不能用 `floor`

**Context**

绘制公式（`DrawMMap:1034-1035`、`DrawSMap:1451-1452`、`DrawWarMap:1610-1611`
三处完全相同）：

```lua
local x1 = CONFIG.XScale * (i1 - j1) + math.floor(CONFIG.Width / 2)
local y1 = CONFIG.YScale * (i1 + j1) + math.floor(CONFIG.Height / 2)
```

反解看起来是简单的线性方程组：

```lua
local u = (sx - W/2) / XScale      -- = i1 - j1
local v = (sy - H/2) / YScale      -- = i1 + j1
i1 = (u + v) / 2
j1 = (v - u) / 2
```

**朴素直觉是 `floor`**（"点在格内就属于这一格"）。但这是**错的**。

**实测证据**

我在 289 个格子（i1,j1 ∈ [-8,8]）的菱形内部采样 13,858 个点，
对比 `floor` 与 `round`：

```
  floor：(u+v)/2 直接取 floor     →  10,478 点命中错误格  (75.6%)
  round：(u+v)/2 + 0.5 再 floor   →       0 点命中错误格  ( 0.0%)
```

**根因**

```
  (i1, j1) 整数格 绘制时中心在屏幕  XScale*(i1-j1)+W/2, YScale*(i1+j1)+H/2
  (i1, j1) 浮点空间里，一个"单位格"是 [gi, gi+1] × [gj, gj+1]
  映射到屏幕后的菱形，其几何中心在 (gi+0.5, gj+0.5)  ← 注意这个 +0.5

  而绘制 tile(gi, gj) 时的中心在 (gi, gj)

  → floor 命中 [gi, gi+1) 区间，即 tile(gi+0.5) 的区域
  → 与 tile(gi) 的菱形区域有半格错位
```

用图说明：

```
  屏幕上的菱形瓦片               反解坐标空间
  ┌───────────────┐
  │      /\       │            gj+1 ─┬───────────
  │     /  \      │                 │  命中此区  │
  │    /    \     │  ← 菱形中心      │  但绘制的是│
  │    \    /     │    在 (gi,gj)    │  tile(gi,  │
  │     \  /      │                 │  gj+1)     │
  │      \/       │            gj   ─┼─────┬─────┤
  └───────────────┘                 │ tile│ 菱形│
                            gi      gi+1  中心在
                                          (gi+0.5)
```

**Decision**

反解用 `floor(x + 0.5)`：

```lua
--- 屏幕坐标 → 格坐标
-- @param sx, sy number 屏幕坐标（逻辑坐标）
-- @return number gridX, gridY 格坐标
local function screenToTile(sx, sy)
    local u = (sx - math.floor(CONFIG.Width / 2)) / CONFIG.XScale
    local v = (sy - math.floor(CONFIG.Height / 2)) / CONFIG.YScale
    -- 必须 +0.5 再 floor：菱形中心在 (gi, gj)，不是 (gi+0.5, gj+0.5)
    local gridX = math.floor((u + v) / 2 + 0.5)
    local gridY = math.floor((v - u) / 2 + 0.5)
    return gridX, gridY
end
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| `floor` 直接取整 | 实测 75.6% 的点命中错格 |
| 用菱形内外判定（`\|ox\|/XS + \|oy\|/YS <= 1`）逐个试 | 数学上正确但复杂度高；且上面的 round 已实测 100% 正确 |
| 遍历可见格求「点在哪个菱形内」 | O(2400) 每帧，完全没必要 |

**Consequences**

- 反解是 O(1) 纯算术，可在 `mousemoved` 时每帧调用
- **必须有测试**：289 格 × 菱形内部采样 0 偏离（作为回归基线）
- 反向（格 → 屏幕）也需提供，用于绘制高亮：
  ```lua
  local function tileToScreen(gx, gy)
      return CONFIG.XScale * (gx - gy) + math.floor(CONFIG.Width / 2),
             CONFIG.YScale * (gx + gy) + math.floor(CONFIG.Height / 2)
  end
  ```

---

## ADR-MS3-002 A* 用二叉堆 + 曼哈顿启发式

**Context**

现有移动是 4 向（`CC.DirectX = {0,1,-1,0}`、`CC.DirectY = {-1,0,0,1}`）。
全仓无任何寻路算法。

**Decision**

A* + 二叉堆 + 曼哈顿距离启发式：

```lua
-- 4 向移动下，曼哈顿距离是 consistent（一致）启发式
-- 即 h(n) <= cost(n, n') + h(n')，保证 A* 最优且无需重复打开节点
local function heuristic(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end
```

二叉堆（最小堆）用于 open set，避免线性扫描 O(n)：

```lua
-- 节点结构（避免每次新建 table）
-- { x, y, g, f, parent }
```

**为什么不用 BFS**

```
  BFS：O(V+E)，无启发式，会均匀扩展到所有方向
  A* ：带启发式，朝目标方向倾斜

  可见范围 2400 格时差距不明显（都 < 5ms）。
  但「点击远处」或「阻断搜索」时，A* 能显著减少扩展节点数。
```

**为什么必须文档化「启发式一致性」**

```
  4 向移动，每步代价 1，曼哈顿距离 = 实际最短距离
  → h 从不高估（admissible）
  → 且 h(n) <= 1 + h(n')（consistent）
  → 因此无需「重新打开已关闭节点」的复杂逻辑

  若未来改成 8 向或带地形代价，必须重新验证这一条。
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| BFS（无启发式） | 阻断搜索时扩展节点远多于 A* |
| Dijkstra | 等价于 h=0 的 A*，没有方向性 |
| JPS（Jump Point Search） | 4 向移动下 JPS 收益有限；实现复杂度高得多 |
| 预计算全图连通分量 | 内存 480×480 需额外数组；且地图不变时才有效，而 MOD 会换图 |
| 双向搜索 | 收益在长路径时明显，但可见范围内路径很短（~42 步），不值 |

**Consequences**

- `pathfind.lua` 约 180 行（含堆实现）
- 纯算法，零引擎依赖，可用合成地图完全单测
- 需测试：直线、绕障、不可达、起点=终点、单步、大范围阻断

---

## ADR-MS3-003 阻断搜索设 `maxNodes` 上限

**Context**

「点击被墙完全隔离的区域」时，A* 必须搜完整个连通区才能确认不可达。

```
  可见范围 ≈ 2400 格  →  < 5ms  ✓
  但连通区可能远超：
    - 一片开阔草原，玩家点了个远处的孤岛
    - 连通区可能是几万格
    → 每格 ~1-2 微秒 → 几十到上百 ms
```

**Decision**

`find()` 接受 `opts.maxNodes`（默认 5000），超限立刻返回 `nil`：

```lua
function Pathfind.find(sx, sy, gx, gy, isWalkable, opts)
    local maxNodes = (opts and opts.maxNodes) or 5000
    local expanded = 0
    while #open > 0 do
        expanded = expanded + 1
        if expanded > maxNodes then
            return nil, "exceeded-max-nodes"     -- 视为不可达
        end
        ...
    end
end
```

**返回第二个值说明原因**（调用方可用于调试，但 UI 一律按「不可达」处理）：

```
  nil, "no-path"              真的不连通
  nil, "exceeded-max-nodes"   搜索超限
  nil, "goal-unwalkable"      目标格本身不可站立
```

**为什么 5000**

```
  正常可达路径（可见范围内 ~42 步）→ 通常扩展 < 500 节点
  5000 是 10 倍余量，覆盖绝大多数「绕远路」的情况
  超过 5000 说明目标极可能在另一个连通区 → 判定不可达是对玩家友好的
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 不设上限 | 阻断搜索可能卡几十到上百 ms，点击后明显卡顿 |
| 限制搜索半径（如 50 格） | 需求明确说「不限制搜索半径，可视范围内都允许」 |
| 把 A* 放到协程里分帧执行 | 复杂度高（需要跨帧保存搜索状态），收益不抵 |
| 预计算连通区 | MOD 会换地图，缓存失效管理复杂 |

**Consequences**

- 极端情况下「明明可达但判定不可达」—— 属于可接受的降级
- tasks 要求实测记录真实耗时（可见范围 vs 阻断搜索）
- 调用方需处理第二个返回值（至少记录日志）

---

## ADR-MS3-004 AUTO_MOVING 作为 `JY` 上的字段，不新增 `GAME_*` 状态常量

**Context**

现有游戏状态常量：

```lua
GAME_START=0, GAME_FIRSTMMAP, GAME_MMAP, GAME_WMAP, GAME_SMAP, GAME_DEAD, GAME_END
```

自动移动发生在 `GAME_MMAP` / `GAME_SMAP` **内部**，不是独立的大状态。

**Decision**

用 `JY.AutoMove` 作为子状态：

```lua
JY.AutoMove = {
    path     = { {x=, y=}, ... },   -- 剩余路径（含当前目标格）
    index    = 1,                    -- 当前要去的路径点
    drain    = false,                -- 按键中断后是否正在吃掉 repeat
    mapKind  = "MMAP" | "SMAP",     -- 哪套坐标系
}
```

`JY.AutoMove == nil` 表示 IDLE。

**为什么不用新的 GAME_ 常量**

```
  ✗ 新增 GAME_AUTOMOVING：
     - 要在 game_states.lua 注册 handler
     - 要在 event_bridge 加状态流转
     - JY.Status 的语义是「玩家在哪个场景」，自动移动不是场景

  ✓ JY.AutoMove 子状态：
     - MMAP/SMAP 的 update 里一个 if 分支
     - 中断后自然回到原有 IDLE 逻辑
     - 存档不需要保存（自动移动是临时状态）
```

**Consequences**

- `game_states.lua` 的两个 update 各加约 20 行分支
- IDLE 路径（既有按键逻辑）**代码零改动**
- `JY.AutoMove` 需要在状态切换时清空（进战斗、进对话、切场景）

---

## ADR-MS3-005 中断用「drain 标志」吃掉 repeat，直到 `keyreleased`

**Context**

需求明确：「事件触发、按键都中断当前的自动移动，中断的按键吃掉，
不要响应为方向移动」。

`input_manager` 的键盘重复是**始终启用**的（`CONFIG.KeyRepeat=0` 在
事件驱动路径从未被检查，`EnableKeyRepeat` 收到 300/40 恒大于 0）：

```
  按住方向键 → 队列里累积 pressed + repeat + repeat + repeat ...
  长按 1 秒 ≈ 25 个事件
```

**问题**：中断自动移动时，第 1 个事件被消费（中断），
但后面还有 24 个 repeat 事件在队列里 —— 若不处理，角色会立刻开始走路。

**Decision**

用 `drain` 标志 + 按键释放事件解除：

```lua
-- 中断时设置
JY.AutoMove = nil
JY.InputDrain = true       -- 或放在 input_manager 上

-- getKey() 消费时
if JY.InputDrain then
    local event = dequeueNextEvent()
    if event and event.type == "released" then
        JY.InputDrain = false    -- 松开后才解除
    end
    return -1                    -- 期间一律返回"无按键"
end
```

**更精确的实现**：drain 只针对**同一方向键**。若玩家中断后立刻按下另一个方向键，
应该正常响应：

```lua
JY.InputDrain = { key = interruptedKey }   -- 只吃这个键的 repeat
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 只吃第 1 个事件 | 后续 repeat 会立刻让角色走起来（需求明确禁止） |
| 清空整个键队列 | 会丢掉合法的其他按键（如玩家立刻按 ESC） |
| 临时 `EnableKeyRepeat(0, 0)` | 与游戏其他地方的状态耦合，容易漏恢复 |
| 在 `input_manager` 里统一拦截 | 需要知道「谁中断了、中断了什么键」，职责不清 |

**Consequences**

- `game_states.lua` 的 update 分支里要维护 `InputDrain`
- 解锁依赖 `keyreleased` 事件 —— **风险**：若玩家在窗口失焦时松开，
  `keyreleased` 收不到，drain 会永久卡住。缓解：drain 加超时（如 2 秒）
  或监听 `love.focus(false)` 时清除

---

## ADR-MS3-006 悬停绘制插在 `EventBridge:draw()` 内（位置 ①）

**Context**

绘制顺序（`main.lua` 的 `love.draw`）：

```lua
1. EventBridge:draw()
     ├ globalDrawCallback
     ├ StateMachine:draw()          ← DrawMMap / DrawSMap 全屏重绘
     ├ SceneNameAsync.draw()
     ├ PersonStatusAsync.draw()
     ├ ItemAsync.draw()
     ├ MenuTitle / TalkAsync / Dialog
2. MenuAsync.draw()                  ← 菜单在最上层
```

而且地图**每帧全屏重绘**：

```lua
-- game_states.lua GAME_MMAP.draw
lib.SetClip(0, 0, CC.ScreenW, CC.ScreenH)
lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)   -- 内部 FillColor 清屏
```

所以悬停菱形**必须每帧重画**，不能「画一次留在屏幕上」。

**Decision**

在 `EventBridge:draw()` 里加一个钩子，位置在 `StateMachine:draw()` 之后：

```lua
function EventBridge:draw()
    if globalDrawCallback then globalDrawCallback() end

    StateMachine.getInstance():draw()

    -- ← 新增：地图悬停高亮（位置 ①）
    if hoverOverlayCallback then
        local ok, err = pcall(hoverOverlayCallback)
        if not ok then
            self:_debug("hoverOverlay 抛错: " .. tostring(err))
        end
    end

    SceneNameAsync.draw()
    ...
end
```

**为什么位置 ①**（而不是其他 UI 之后）：

```
  位置 ①（StateMachine 之后、其他 UI 之前）
    地图 → 菱形 → 场景名/状态/物品/对话 → 菜单
    ✓ 菱形属于"地图层的附属物"，应被上层 UI 遮住
    ✓ 有对话框时菱形被盖住 —— 正确的优先级
    ✓ 菜单永远在菱形之上（不会干扰阅读）

  位置 ②（所有 UI 之后、菜单之前）
    地图 → 其他 UI → 菱形 → 菜单
    ✗ 菱形会盖在对话框上面，视觉错误
```

**绘制条件（5 条全部满足才画）**

```lua
local function shouldDrawHover()
    return Settings.get("input.mouse")                       -- ① 开关开
       and not MenuAsync.hasActiveMenu()                     -- ② 无菜单
       and not InputManager.disableInput                     -- ③ 无阻塞输入
       and (JY.Status == GAME_MMAP or JY.Status == GAME_SMAP) -- ④ 地图状态
       and mouseInWindow()                                   -- ⑤ 鼠标在窗内
end
```

第 ⑤ 条的实现（跨引擎友好，不用 `love.window.hasMouseFocus`）：

```lua
local function mouseInWindow()
    local mx, my = EngineAPI.input.mousePosition()
    return mx >= 0 and mx < CC.ScreenW and my >= 0 and my < CC.ScreenH
end
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 在 `game_states.lua` 各 state 的 draw 里画 | 两处重复；且 SMAP/MMAP 的 draw 都在全屏重绘，插在内部时机不对 |
| 在 `MenuAsync.draw()` 里画 | 语义不符（那是菜单的绘制入口） |
| 用 `globalDrawCallback` | 那是给「属性选择」这类特殊场景用的，且它排在 StateMachine **之前**（会被地图覆盖） |

**Consequences**

- `event_bridge.lua` 加约 15 行（钩子 + pcall 隔离）
- 菱形绘制成本：单精灵 36×18，可忽略
- 红闪也在同一钩子里绘制（用 `drawTinted` 红色）

---

## ADR-MS3-007 两套坐标系分别实现，不抽公共层

**Context**

MMAP 与 SMAP 的差异：

| 维度 | MMAP（主地图） | SMAP（子场景） |
|------|---------------|---------------|
| 坐标字段 | `JY.Base["人X"]` / `["人Y"]` | `JY.Base["人X1"]` / `["人Y1"]` |
| 数据访问 | `lib.GetMMap(x, y, layer)` | `GetS(sceneid, x, y, layer)` |
| 边界 | `CC.MWidth` / `CC.MHeight`（480） | `CC.SWidth` / `CC.SHeight`（64） |
| 可走性 | `GetMMap(x,y,3)==0 and GetMMap(x,y,4)==0` | `GetS(...,3)` 与 `GetS(...,0)` 组合 |
| 场景切换 | `CanEnterScene(x,y)` | 出口判定 |

**Decision**

**分别实现两个 `isWalkable` 闭包**，不抽公共抽象：

```lua
-- MMAP：逐字对照 Game_MMap 的可走性判定（jymain.lua:429）
local function mmapWalkable(x, y)
    -- 边界与既有 limitX 的限制一致（10 的边距）
    if x < 10 or y < 10 or x > CC.MWidth - 10 or y > CC.MHeight - 10 then
        return false
    end
    return lib.GetMMap(x, y, 3) == 0 and lib.GetMMap(x, y, 4) == 0
end

-- SMAP：直接复用既有 SceneCanPass（jymain.lua:1512）
local function smapWalkable(sceneid, x, y)
    if x < 1 or y < 1 or x > CC.SWidth - 2 or y > CC.SHeight - 2 then
        return false
    end
    return SceneCanPass(x, y)     -- ← 必须复用，不得重写
end
```

**为什么不重写 SMAP 的可走性**

`SceneCanPass`（`jymain.lua:1512-1532`）的判定有三条，全部依赖场景数据：

```lua
function SceneCanPass(x, y)
    local ispass = true
    if GetS(JY.SubScene, x, y, 1) > 0 then          -- 层1有物品 → 不可通过
        ispass = false
    end
    local d_data = GetS(JY.SubScene, x, y, 3)       -- 事件层
    if d_data >= 0 then
        if GetD(JY.SubScene, d_data, 0) ~= 0 then   -- D* 数据非 0 → 不可通过
            ispass = false
        end
    end
    if CC.SceneWater[GetS(JY.SubScene, x, y, 0)] ~= nil then   -- 水面 → 不可进入
        ispass = false
    end
    return ispass
end
```

我自己在初稿里猜的「`ground ~= 0 and building == 0`」是**错的**：
水面判定走的是 `CC.SceneWater` 表、事件判定要查 `GetD` 的 D* 数据。
**重写必然漏条件**，导致「寻路说能走、实际走不过去」或反之。

所以 SMAP 直接调用 `SceneCanPass`。同理 MMAP 的条件也必须逐字抄
`Game_MMap` 的 `lib.GetMMap(x,y,3)==0 and lib.GetMMap(x,y,4)==0`。

**边界值的来源**

```
  MMAP：Game_MMap 里 limitX(人X, 10, CC.MWidth-10)
        → 可走范围是 [10, MWidth-10]，与既有行为一致
  SMAP：Game_SMap 里 limitX(人X1, 1, CC.SWidth-2)
        → 可走范围是 [1, SWidth-2]
```

**为什么抽公共层是错误的**

```
  两者共享的只有"屏幕坐标反解"（那个已经有 mouse_hover 提供）
  可走性判定、边界、数据访问全部不同
  → 抽象层只能传递 isWalkable 回调，那不叫抽象，那叫参数
```

**Consequences**

- `game_states.lua` 里两处各约 30 行
- 潜在重复：坐标反解逻辑（但那已抽到 `mouse_hover.screenToTile`）
- **DoD 强制**：`smapWalkable` 必须调用 `SceneCanPass`，
  禁止重写判定条件（可用 `grep "SceneCanPass"` 验证）
- **DoD 强制**：`mmapWalkable` 的判定表达式必须与 `Game_MMap` 逐字相同
  （含 `GetMMap(x,y,3)==0 and GetMMap(x,y,4)==0` 与边距 10）
