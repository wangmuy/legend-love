---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
  impact: []
---
# Epic: 桌面端鼠标操作支持

## 愿景

让桌面版玩家可以用鼠标完成全部游戏操作：呼出菜单、点击菜单项、开关设置、
点击地图自动寻路移动。Android 端保留能力（可接 USB/蓝牙鼠标），但**默认关闭**，
因为其主要输入方式是后续要实现的虚拟按键。

这是一个**输入方式的补充**，不是替代：键盘操作完全不变，鼠标是并行的第二套输入。

---

## 为什么需要 epic 而不是单个 change

本 epic 涉及**引擎抽象层的三处能力扩展**（平台查询、鼠标坐标、染色绘制），
且可交付价值天然分成三个独立阶段：

```
  阶段 1 完成后：什么都没有（纯设施）
  阶段 2 完成后：纯鼠标可以玩菜单          ← 独立价值
  阶段 3 完成后：纯鼠标可以玩地图          ← 独立价值
```

如果把三个阶段塞进一个 change（约 335 任务，是 `audio-settings` 的 3.3 倍），
会有两个后果：
- 中间任何一点卡住（比如寻路性能），整个 change 无法 archive
- 「鼠标玩菜单」这个已经可用的价值被锁在未完成的 change 里

---

## 已通过代码/实测确认的约束

以下事实来自对本仓当前代码的阅读与实机探测，是本 epic 的设计基础。

### 1. 战斗中「右键呼出菜单」天然安全

```
ESC → 呼出菜单 的入口只有 2 处：
  game_states.lua:90   GAME_MMAP.update
  game_states.lua:340  GAME_SMAP.update

战斗中 ESC 是【取消】而不是呼出菜单：
  war_async.lua:638   取消移动光标
  war_async.lua:998   取消移动
  war_async.lua:1433  取消选择目标
```

所以「战斗中敌方行动时不呼出」**自动成立** —— 战斗不在那两个 state 里。

### 2. 真正需要显式屏蔽的只有两处

```
① game_states.lua:339
   if keypress ~= -1 and not (JY and JY.CurrentD >= 0) then
       if keypress == VK_ESCAPE then startMenuCoroutine() ...

   事件执行期间（含开场强制对话）ESC 被明确屏蔽。
   鼠标右键必须继承这个判断，否则对话中能呼出菜单 → 破坏强制流程。

② framework/input_manager.lua
   InputManager.disableInput == true 期间（动画、物品选择等）不处理输入。
   鼠标右键同样必须遵守。
```

### 3. 菱形高亮可完全复用战斗的现成实现

战斗的移动范围光标用的是：

```lua
-- lib_love.lua:1643-1647
JY_LoadPic(0, 0, x1, y1, showflag, 128)   -- 当前光标
JY_LoadPic(0, 0, x1, y1, showflag,  64)   -- 其他可选格
```

`JY_LoadPic(0, 0, ...)` = 第 0 号图片文件的第 0 号精灵。实测其数据：

```
  wmap.grp picid 0:  36x18  xoff=18 yoff=17
  mmap.grp picid 0:  36x18  xoff=18 yoff=17
  smap.grp picid 0:  36x18  xoff=18 yoff=17

  对比瓦片尺寸: 2*XScale=36 宽, 2*YScale=18 高
  → picid 0 就是恰好覆盖一格瓦片的菱形遮罩精灵
```

**三张地图文件都自带这个菱形。** 所以悬停高亮**不需要新资源、不需要多边形绘制**。

### 4. 现有渲染能力只有「原色 / 全黑 / 全白」

```lua
-- lib_love.lua:550-558  PicLoadCache 的 showflag 位域
local hasAlpha = bit32.band(flag, 0x2) ~= 0  -- bit1: alpha
local isBlack  = bit32.band(flag, 0x4) ~= 0  -- bit2: 全黑
local isWhite  = bit32.band(flag, 0x8) ~= 0  -- bit3: 全白
```

**没有染色能力。** 需求要求「寻路失败闪红色」，所以必须新增
`EngineAPI.sprite.drawTinted(...)`（`color` 为 `{r,g,b}`，引擎无关）。

### 5. DPI：Windows 150% 缩放实测为 1:1，无需换算

本机实测（Windows，系统 150% 缩放）：

```
物理分辨率（Win32_VideoController）   = 3840 × 2160
LÖVE getDesktopDimensions()          = 2560 × 1440      3840/2560 = 1.5  ✓ 确认 150%

窗口逻辑尺寸                          = 1024 × 768
love.graphics.getDimensions()        = 1024 × 768

setPosition(1023, 767) → getPosition 返回 (1023, 767)   比值 1.000
setPosition( 100,  80) → getPosition 返回 ( 100,  80)   比值 1.000
```

**结论**：`love.mouse.getPosition()` 已是逻辑坐标，与 `love.graphics` 同一空间。
`EngineAPI.input.mousePosition()` 在 love2d 下就是一行 `return love.mouse.getPosition()`。

> **未验证**：macOS Retina、Android。理论上 LÖVE 统一处理，但需实测。
> API 契约写死为「返回逻辑坐标」，即使某平台需要换算也由引擎内部消化。

### 6. 等距坐标反解可逆（已验证）

```lua
-- DrawMMap / DrawSMap / DrawWarMap 用的是同一套投影
screenX = XScale * (i1 - j1) + W/2
screenY = YScale * (i1 + j1) + H/2

-- 反解
dx = (screenX - W/2) / XScale = i1 - j1
dy = (screenY - H/2) / YScale = i1 + j1
i1 = (dx + dy) / 2
j1 = (dy - dx) / 2
```

实测 4 个采样点全部精确往返：

```
  (  0,  0) -> screen( 512, 384) -> back( 0.00, 0.00)  ✓
  (  3,  5) -> screen( 476, 456) -> back( 3.00, 5.00)  ✓
  ( -2,  7) -> screen( 350, 429) -> back(-2.00, 7.00)  ✓
  ( 10, -3) -> screen( 746, 447) -> back(10.00,-3.00)  ✓
```

### 7. 可见格数约 2400，A* 毫无压力

```
  屏幕 1024×768，瓦片 36×18
  (i1-j1) ∈ ±28.4    (i1+j1) ∈ ±42.7
  → 可见菱形区域 ≈ 2 × 28.4 × 42.7 ≈ 2427 格

  A* 最坏（点击可见区边缘，路径 ~42 步）：展开数百~2000 节点 → < 5ms
```

但「点击被墙完全隔离的区域」时 A* 要搜完整个连通区才能确认不可达
（可能数万节点 → 几十毫秒）。**因此寻路只在点击瞬间跑一次，绝不进 `update`。**

### 8. 鼠标按下是「状态」不是「事件」，必须做边沿检测或入队

```lua
love.mouse.isDown(1)   -- 按住期间每帧都返回 true
```

若直接在 `update` 里判定「点击了」，一次点击会触发几十次。
解决方案：**鼠标事件走独立队列**（与键盘队列分离，见 ADR-MS-004）。

### 9. `menu_state_machine` 是事件驱动的

```lua
-- update(dt) → handleInput() → lib.GetKey() 非阻塞取队列
-- 没有 while wait 阻塞循环
```

符合事件驱动架构定义，鼠标相关逻辑放这里**符合架构**。

### 10. 「鼠标操作」开关不需要新增 menu kind

实测（用真实 `menu_state_machine`）：普通菜单项 + 回调即可。

```lua
{ "鼠标操作    开",
  function(menu, current)
      Settings.set("input.mouse", not Settings.get("input.mouse"))
      menu[current][1] = "鼠标操作    " .. (Settings.get("input.mouse") and "开" or "关")
      return 0        -- 不关闭菜单，重绘
  end, 1 }
```

依赖四个现成机制：
- 回调拿到 `newMenu` 引用（`menu_state_machine.lua:464`）
- 返回 0 → 菜单不关闭（`pollCallback` 只在 `result == 1` 时 close）
- `draw` 每帧重读 `newMenu[i][1]` → 文本自动更新
- 上下键在非值项上天然是导航（零改动）

实测输出：

```
初始:     设置=true   文本=鼠标操作    开
Enter 后: 设置=false  文本=鼠标操作    关     菜单仍打开 ✓
再 Enter: 设置=true   文本=鼠标操作    开
按上键后: 设置=true（不变，纯导航）✓
```

---

## Vertical Slices

### Slice 1: `mouse-slice1-engine-capability`（Infrastructure）

**业务价值**：无（纯设施）。让上层的鼠标功能可以**不依赖具体引擎**地开发与测试。

**为什么必须独立成 slice**：本 slice 触及三个引擎实现的同步扩展，
如果混在功能 slice 里，一旦某个引擎实现有问题，功能 slice 也无法验收。

**Acceptance Criteria (DoD)**

```
1. EngineAPI.system.getOS() 三引擎实现齐全，返回
   "Windows"|"Linux"|"macOS"|"Android"|"iOS"|"web"|"unknown"
2. EngineAPI.input.mousePosition() / mouseButton() 三引擎实现齐全
3. EngineAPI.sprite.drawTinted(archiveId, spriteId, x, y, color, alpha)
   在 love2d 下真实染色；mud/web 为记录/no-op
4. DPI 契约写入 engine_api.lua 注释：
   「返回逻辑坐标，与 DrawString/DrawRect 同一空间；引擎内部消化 DPI」
5. Windows 150% 缩放下，mousePosition 与绘图坐标 1:1（实测断言）
6. Settings 支持 platformDefaults（第四层：user > mod > platform > default）
7. Settings.setPlatform() 注入式，settings.lua 仍零引擎依赖
8. 鼠标事件独立队列（enqueueMouseEvent / getMouseEvent），
   现有 20+ 处 lib.GetKey() 调用零影响
9. Lua 5.1/5.3/5.4/5.5 全量测试全绿
10. SRC_FILES.md / AGENTS.md / ENGINE_API_DESIGN.md 的 EngineAPI
    计数更新为 55 函数 / 15 模块
11. luac5.1 -p 与 luac5.5 -p 全仓零失败
```

**Affected Domains**：`game/engine-love2d/`、`game/engine-mud/`、
`game/engine-web/`、`game/framework/settings.lua`、
`game/framework/input_manager.lua`、`game/tests/`

**Implementation Changes**：
- 新增 `EngineAPI.system` 模块（第 15 个）
- `EngineAPI.input` 加 2 个函数
- `EngineAPI.sprite` 加 1 个函数
- `settings.lua` 加 platformDefaults 层 + setPlatform
- `input_manager.lua` 加鼠标事件队列

**Status**：`pending`

---

### Slice 2: `mouse-slice2-mouse-menu`（Feature）

**业务价值**：**玩家可以用纯鼠标完成全部菜单操作** —— 右键呼出、点击选择、
点击外部关闭、调节音量、开关鼠标。这是本 epic 第一个可交付的用户价值。

**Acceptance Criteria (DoD)**

```
1. 大地图 / 小场景下右键呼出主菜单；战斗中、事件执行中、
   对话中、有动画时【不】呼出
2. 点击菜单项触发对应动作；点击值项的 ▲/▼ 调节数值
3. 点击菜单外空白区域关闭菜单
4. 子菜单打开时点击主菜单其他项 → 先关闭当前子菜单，再响应新项
5. 「设置」（开始菜单）与「系统」（大地图）各新增「鼠标操作」项，
   Enter/空格切换，文本在「开/关」间变化，切换后菜单不关闭
6. 鼠标开关 onChange 立即生效：关闭后右键不再呼出菜单、点击不再选菜单项
7. 鼠标开关的默认值：桌面 true、Android false（platformDefaults）
8. 鼠标开关的设置持久化到 settings.ini
9. Lua 四版本全量测试全绿
```

**Affected Domains**：`game/framework/menu_state_machine.lua`、
`game/framework/jymain_async.lua`、`game/framework/jymain_adapter.lua`、
`game/main.lua`、`game/tests/`

**Implementation Changes**：
- `menu_state_machine.lua` 加鼠标命中测试与点击分发
- `jymain_async.lua` / `jymain_adapter.lua` 菜单加「鼠标操作」项
- `main.lua` 注册 `love.mousepressed` 等回调
- 新建 `framework/mouse_menu.lua`（或扩展 `audio_menu.lua`）

**Status**：`pending`

---

### Slice 3: `mouse-slice3-mouse-move`（Feature）

**业务价值**：**玩家可以点击地图让角色自动寻路走过去。** 配合 slice 2，
桌面端实现完整鼠标操作闭环。

**Acceptance Criteria (DoD)**

```
1. 鼠标在大地图/小场景内移动时，在所指格子绘制菱形高亮
   （复用 picid 0，黑色 alpha 64，位置在 StateMachine:draw() 之后）
2. 有菜单打开 / 有阻塞输入 / 不在 MAP 状态 / 鼠标出屏 → 不绘制高亮
3. 点击可达格 → A* 求路径 → 角色沿路径自动移动
4. 点击不可达格 → 红闪反馈（drawTinted 红色，200ms 节流），不移动
5. 寻路只在点击瞬间执行一次，update 循环中只有 O(1) 的路径队列消费
6. 自动移动中断语义：
   - 按键 → 中断，吃掉全部 repeat 事件直到松开，不响应为方向移动
   - 事件触发（路过事件）→ 中断，事件结束后【不】恢复剩余路径
   - 进入子场景 → 中断，清空剩余路径
7. 到达终点 → 回到 IDLE
8. 鼠标开关关闭时，slice 3 的全部行为不生效
9. Lua 四版本全量测试全绿
10. 480×480 地图上「点击被墙隔离区域」的最坏阻断搜索耗时实测记录
```

**Affected Domains**：`game/framework/game_states.lua`、
`game/framework/event_bridge.lua`、`game/framework/pathfind.lua`（新）、
`game/framework/mouse_hover.lua`（新）、`game/script/jymain.lua`（只读参考）、
`game/tests/`

**Implementation Changes**：
- 新建 `framework/pathfind.lua`（A* + 二叉堆，纯算法，零引擎依赖）
- 新建 `framework/mouse_hover.lua`（坐标反解 + 高亮 + 红闪）
- `game_states.lua` 的 MMAP/SMAP update 加 AUTO_MOVING 分支
- `event_bridge.lua` 加悬停绘制钩子

**Status**：`pending`

---

## Slice Dependency Graph

```
              ┌─────────────────────────────┐
              │ slice 1: engine-capability  │
              │  (getOS/mouse/tinted/设置)  │
              └──────────┬──────────────────┘
                         │
            ┌────────────┴────────────┐
            ▼                         ▼
   ┌────────────────────┐   ┌────────────────────┐
   │ slice 2: mouse-menu│   │ slice 3: mouse-move│
   │  右键/点击/开关     │   │  悬停/A*/自动移动   │
   └────────────────────┘   └────────────────────┘
            │                         │
            └────────────┬────────────┘
                         ▼
              完整桌面鼠标操作闭环
```

- slice 2 与 slice 3 **互不依赖**（可并行）
- 但 slice 3 的「点击不可达红闪」需要 slice 1 的 `drawTinted`
- slice 2 的「点击值项箭头」与 slice 3 的「点击地图」共用 slice 1 的鼠标坐标

---

## Global Acceptance Criteria（Epic 级 DoD）

```
1. 全部 3 个 slice 的 DoD 各自通过
2. 桌面（Windows）纯鼠标可玩：右键菜单 → 点击选项 → 调设置 → 点地图走路
3. 键盘操作完全不受影响（所有既有测试零回归）
4. Android 默认关闭鼠标功能，行为与改动前完全一致
5. Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（每版记录断言数）
6. luac5.1 -p 与 luac5.5 -p 全仓零失败
7. 干净 Windows PATH 下测试结果与完整 PATH 一致
8. LÖVE 11.5 启动冒烟无报错
9. framework 新增模块的引擎依赖边界：
   - pathfind.lua 零引擎依赖（可纯算法单测）
   - mouse_hover.lua 只依赖 EngineAPI
   - settings.lua 仍零引擎依赖（DoD 的 grep 保持为空）
```

---

## 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| macOS/Android 的 DPI 行为与 Windows 不同 | 点击位置偏移 | slice 1 实测；API 契约写「返回逻辑坐标」，换算在引擎内部 |
| 「点击被墙隔离区域」A* 阻断搜索慢 | 点击后卡顿数十 ms | 实测记录耗时；若 >100ms 则考虑限制搜索半径（可后续优化） |
| 菜单命中测试与 `numShow` 滚动偏移算错 | 点错项 | 单独测试 `menu.start` 偏移；用 `createMenu` 的几何字段断言 |
| 鼠标事件与键盘事件时序错乱 | 罕见但难查 | 采用双队列（ADR-MS-004），不做跨队列严格时序保证 |
| 自绘高亮每帧绘制影响性能 | 掉帧 | 菱形是 36×18 单精灵，绘制成本可忽略；且只在地图状态绘制 |
| `framework/menu_state_machine.lua` 继续变大（已 700+ 行） | 维护性 | epic 内接受；记入 TODO.md 作为后续重构议题 |

---

## 明确不做（Out of Scope）

```
✗ 触摸输入（love.touch）—— 与鼠标是不同的输入通道，单独 epic
✗ 虚拟按键 / 屏幕摇杆 —— 后续独立 epic
✗ 物理手柄（conf.lua 的 t.modules.joystick = false 不动）
✗ 隐藏系统光标 / 自绘指针图标 —— 系统光标在所有模式下保留
✗ 路径预览（鼠标悬停时淡淡画出会走的路线）—— 需求明确不需要
✗ Web 端鼠标支持 —— engine-web 是 xterm 终端，形态不兼容
✗ 战斗内的鼠标操作 —— 本 epic 只覆盖菜单与地图移动
✗ 屏幕缩放/分辨率适配
```
