---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: engine-capability — 鼠标/平台/染色绘制的引擎无关基础

## Why

桌面端鼠标支持需要三件当前**完全不存在**的引擎能力：

```
全仓 grep 结果：
  love.mouse.*          → 0 处
  love.system.getOS     → 0 处
  love.touch.*          → 0 处
  EngineAPI 里的鼠标接口 → 0 个
  EngineAPI 里的平台接口 → 0 个
  多边形/染色绘制原语    → 0 个
```

同时，`conf.lua` 开启了 `highdpi = true` 与 `usedpiscale = true`，
这意味着**鼠标坐标与绘图坐标可能不在同一空间** —— 这个风险必须先隔离验证，
否则 slice 2（点击菜单）与 slice 3（点击地图）都会受影响。

本 change 只做「把能力变成引擎无关的接口」，不做任何业务逻辑。

## Parent Context

- Epic: `openspec/epics/2026-11-mouse-input/epic.md`
- Slice: `openspec/changes/mouse-slice1-engine-capability/slice-proposal.md`
- 依赖: `audio-settings`（已完成，引入 `framework/settings.lua`）
- 被依赖: `mouse-slice2-mouse-menu`、`mouse-slice3-mouse-move`

## What Changes

1. **`EngineAPI.system` 新模块（第 15 个）**
   ```lua
   EngineAPI.system.getOS()  --> "Windows"|"Linux"|"macOS"|"Android"|"iOS"|"web"|"unknown"
   ```
   - love2d: `love.system.getOS()`（`conf.lua` 已启用 `t.modules.system`）
   - mud: `"unknown"`
   - web: `"web"`（LÖVE 的 OS 列表没有这个值，为本项目扩展）
   - test: 可注入

2. **`EngineAPI.input` 加 2 个函数**
   ```lua
   EngineAPI.input.mousePosition()      --> x, y    【逻辑坐标】
   EngineAPI.input.mouseButton(button)  --> boolean 1=左 2=右 3=中
   ```

3. **`EngineAPI.sprite` 加 1 个函数**
   ```lua
   EngineAPI.sprite.drawTinted(archiveId, spriteId, x, y, color, alpha)
   -- color = {r=1, g=0, b=0}，0-1 浮点
   -- alpha = 0-255
   ```

4. **`framework/settings.lua` 新增第四层 `platform`**
   ```lua
   -- 解析顺序变成 user > mod > platform > default
   Settings.setPlatform("Windows")                          -- 宿主注入
   Settings.define("input.mouse", {
       default = false, type = "bool", label = "鼠标操作",
       platformDefaults = { Windows = true, Linux = true, macOS = true,
                            Android = false, iOS = false },
   })
   ```

5. **`framework/input_manager.lua` 新增鼠标事件独立队列**
   ```lua
   enqueueMouseEvent({ type = "pressed", x = , y = , button = })
   InputManager.getInstance():getMouseEvent()  --> event|nil
   ```

6. **文档同步**：`SRC_FILES.md` / `AGENTS.md` / `ENGINE_API_DESIGN.md`
   的 EngineAPI 计数从 **51 函数 / 14 模块** 更新为 **55 函数 / 15 模块**

## Scope Boundaries

### In Scope

- 三个新引擎接口的定义与三引擎实现（love2d / mud / web）+ 测试引擎
- `settings.lua` 的 platformDefaults 层与 `setPlatform`
- 鼠标事件队列（只做队列，不做消费）
- DPI 契约文档 + Windows 150% 实测断言
- 文档计数同步
- 单元测试与四 Lua 版本验证

### Out of Scope

- **任何鼠标事件的业务消费**（右键呼菜单、点击命中、坐标反解、寻路）
  → slice 2 / slice 3
- 触摸输入（`love.touch`）
- 虚拟按键 / 屏幕摇杆 / 物理手柄
- 隐藏系统光标 / 自定义光标图片
- Web 端的实际鼠标支持（只加 `getOS()` 返回 `"web"`，不实现鼠标）
- `MENU` 相关的任何改动
- `conf.lua` 的 `highdpi` / `usedpiscale` 调整（实测无需调整）

## Impact

| 区域 | 影响 |
|------|------|
| `game/engine-*/` | 三个引擎各加 1 模块 + 3 函数 |
| `game/framework/settings.lua` | 加一层的解析逻辑（约 40 行） |
| `game/framework/input_manager.lua` | 加独立队列（约 50 行） |
| `game/tests/` | 新增/扩展 4 个测试模块 |
| 现有行为 | **零影响**（全部纯新增；键盘队列不动） |
| 文档 | 3 个文件的 EngineAPI 计数 |

## Risks

1. **macOS / Android 的 DPI 行为未验证** —— Windows 150% 已实测 1:1，
   但 macOS Retina 与 Android 需要实机验证。
   **缓解**：API 契约写死「返回逻辑坐标」，即使某平台需要换算也在引擎内部加；
   契约不变意味着 slice 2/3 不受影响。
2. **`love.system.getOS()` 在 web 构建下返回什么未验证** ——
   LÖVE 的 web 构建理论上返回 `"Linux"`（Emscripten）。若如此，
   `engine-web` 的 `"web"` 实现必须显式覆盖，否则平台判断会错。
   **缓解**：`engine_web.lua` 硬编码返回 `"web"`，不调用 `love.system`。
3. **`drawTinted` 的染色效果需要实机确认** —— `love.graphics.setColor`
   配合 `love.graphics.draw` 是乘算染色，对纯白/灰度精灵有效；
   若 picid 0 的菱形本身有色，染色结果可能偏离预期。
   **缓解**：先写测试断言 API 被调用，再实机看效果；必要时改用 shader。

## Traceability

| REQ | 主题 |
|-----|------|
| REQ-MS1-1 | 平台查询引擎无关 |
| REQ-MS1-2 | 鼠标坐标是逻辑坐标 |
| REQ-MS1-3 | 染色绘制通用化 |
| REQ-MS1-4 | 设置支持平台默认值 |
| REQ-MS1-5 | 鼠标事件队列与键盘隔离 |
| REQ-MS1-6 | 跨版本与跨平台 |
