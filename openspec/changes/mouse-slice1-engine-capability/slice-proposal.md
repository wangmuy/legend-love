---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

鼠标支持的三个 slice 中，本 slice 是唯一**没有用户价值但不可省略**的设施层：
它把鼠标、平台、染色绘制这三件事变成**引擎无关的 EngineAPI 契约**，
让 slice 2 / slice 3 可以只依赖 framework 就能开发与测试。

如果不单独成 slice，而是把引擎扩展混进功能 slice，会有两个问题：

1. **三个引擎实现的同步扩展**（love2d 真实实现 / mud 记录 / web no-op）
   一旦某个引擎有问题，功能 slice 也会无法验收，故障定位变难。
2. **DPI 行为需要实测**。本机（Windows 150%）已验证为 1:1，
   但 macOS/Android 未验证。如果实测发现问题，API 契约不变（仍是「返回逻辑坐标」），
   但实现要加换算 —— 这个不确定性应该被隔离在一个 slice 里。

## Parent Context

- Epic: `openspec/epics/2026-11-mouse-input/epic.md`
- Slice: 本文件即 slice 1
- 依赖: 无（但复用 `audio-settings` 引入的 `framework/settings.lua`）
- 被依赖: `mouse-slice2-mouse-menu`、`mouse-slice3-mouse-move`

## What Changes

1. **新增 `EngineAPI.system` 模块（第 15 个）**
   - `system.getOS()` → `"Windows"|"Linux"|"macOS"|"Android"|"iOS"|"web"|"unknown"`
   - love2d: `love.system.getOS()`；mud: `"unknown"`；web: `"web"`；test: 可注入

2. **`EngineAPI.input` 加 2 个函数**
   - `input.mousePosition()` → `x, y`（**逻辑坐标**，与 `DrawString` 同一空间）
   - `input.mouseButton(button)` → `boolean`（1=左 2=右 3=中）

3. **`EngineAPI.sprite` 加 1 个函数**
   - `sprite.drawTinted(archiveId, spriteId, x, y, color, alpha)`
   - `color = {r, g, b}`（0-1 浮点，引擎无关）
   - love2d 用 `love.graphics.setColor` 实现真实染色；mud/web 记录调用

4. **`framework/settings.lua` 扩展第四个优先级层**
   - 解析顺序：`user > mod > platform > default`
   - `Settings.setPlatform(name)` 注入式（宿主调用，**非引擎 require**）
   - `Settings.define(key, { platformDefaults = { Windows = true, Android = false } })`

5. **`framework/input_manager.lua` 加鼠标事件独立队列**
   - `enqueueMouseEvent(event)` / `getMouseEvent()`
   - 与键盘队列分离，**现有 20+ 处 `lib.GetKey()` 调用零改动**

6. **文档同步**
   - `SRC_FILES.md` / `AGENTS.md` / `ENGINE_API_DESIGN.md`
     的 EngineAPI 计数：51 函数 / 14 模块 → **55 函数 / 15 模块**

## Scope Boundaries

### In Scope

- `EngineAPI.system` / `.input.mouse*` / `.sprite.drawTinted` 的接口定义与三引擎实现
- 鼠标事件队列
- `settings.lua` 的 platformDefaults 层
- DPI 行为的实测与契约文档
- 单元测试 + 四 Lua 版本验证

### Out of Scope

- 鼠标事件的**消费**逻辑（右键呼菜单、点击命中）→ slice 2
- 鼠标坐标的**业务使用**（坐标反解、寻路）→ slice 3
- 触摸输入 / 虚拟按键 / 物理手柄
- `love.mouse.setVisible` 与自定义光标（明确不做，系统光标始终保留）
- Web 端鼠标支持（engine-web 是 xterm 终端）

## Requirements

### REQ-MS1-1 平台查询引擎无关

`EngineAPI.system.getOS()` 在三个引擎下都必须存在且不抛错。
返回值必须是 `"Windows"|"Linux"|"macOS"|"Android"|"iOS"|"web"|"unknown"` 之一。

### REQ-MS1-2 鼠标坐标是逻辑坐标

`EngineAPI.input.mousePosition()` 返回的坐标必须与 `DrawString` / `DrawRect`
使用同一坐标空间。引擎负责把物理/DPI 缩放坐标换算到该空间，**调用方无需感知 DPI**。

### REQ-MS1-3 染色绘制通用化

`EngineAPI.sprite.drawTinted(archiveId, spriteId, x, y, color, alpha)` 必须：
- 接受任意 `spriteId`（不只是菱形 0 号）
- 接受 `color = {r, g, b}`（0-1 浮点）
- 在 love2d 下真实染色；mud/web 下记录调用不抛错

### REQ-MS1-4 设置支持平台默认值

`Settings.get(key)` 的解析顺序必须是 `user > mod > platform > default`。
`Settings.setPlatform(name)` 注入平台名。`settings.lua` **不得**引用
`EngineAPI` / `love.` / `CC.` / `JY.`。

### REQ-MS1-5 鼠标事件队列与键盘隔离

`getKey()` 只能返回键盘事件（不得返回鼠标事件）。
`getMouseEvent()` 只能返回鼠标事件。现有 `lib.GetKey()` 调用点行为完全不变。

### REQ-MS1-6 跨版本与跨平台

Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿；`luac5.1 -p` 与 `luac5.5 -p` 零失败；
干净 Windows PATH 下结果一致。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（全部为纯新增）
- 现有功能回归风险：低（只加不改；`input_manager` 的键盘队列不动）

## 关键设计决策（详见子 change 的 design.md）

| ADR | 决策 |
|-----|------|
| ADR-MS-001 | 平台检测走 `EngineAPI.system.getOS()`，不散落在各处 |
| ADR-MS-002 | 鼠标坐标契约 = 「逻辑坐标」，DPI 在引擎内部消化（Windows 150% 实测 1:1） |
| ADR-MS-003 | `drawTinted` 支持任意 spriteId + `{r,g,b}`，而非扩展位域 flag |
| ADR-MS-004 | 鼠标事件走**独立队列**，不与键盘混队 |
| ADR-MS-005 | `settings.lua` 的平台层用**注入**（`setPlatform`），不 require 引擎 |
