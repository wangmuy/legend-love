---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

本 slice 是鼠标 epic 的**第一个可交付用户价值**：玩家可以用纯鼠标完成全部菜单操作
（右键呼出、点击选择、点击外部关闭、调节音量、开关鼠标）。

在 `audio-settings` 完成后，菜单系统已经支持「值项待定值 + 确认提交」和
「多行文本项」，但**所有输入路径都是键盘**。本 slice 补上鼠标路径。

**为什么独立成 slice**：它不需要坐标反解与寻路（那是 slice 3），
只依赖 slice 1 的鼠标坐标与事件队列。做完即可上线，玩家立刻受益。

## Parent Context

- Epic: `openspec/epics/2026-11-mouse-input/epic.md`
- Slice: 本文件即 slice 2
- 依赖: `mouse-slice1-engine-capability`（鼠标坐标、事件队列、平台查询、settings platform 层）
- 不依赖: `mouse-slice3-mouse-move`

## What Changes

1. **`menu_state_machine.lua` 加鼠标命中与点击分发**
   - 命中测试：点在哪一行/哪个箭头（含 `numShow` 滚动偏移 `menu.start`）
   - 点击菜单项 → 等价于「光标移过去 + 确认」
   - 点击值项的 ▲/▼ → 等价于上下键
   - 点击菜单外 → `closeMenu(0)`

2. **子菜单切换语义（需求明确）**
   - 子菜单打开时点击主菜单其他项 → **先关闭当前子菜单，再响应新项**

3. **右键呼出菜单**
   - 只在大地图 / 小场景生效
   - 继承既有屏蔽条件：`JY.CurrentD >= 0`（事件执行中）、`InputManager.disableInput`
   - 战斗中天然不生效（不在 MMAP/SMAP state）

4. **「鼠标操作」开关项**
   - 开始菜单「设置」与大地图「系统」各加 1 项
   - **普通菜单项 + 回调**（不需要新的 kind，实测已验证）
   - Enter/空格切换，上下键纯导航
   - 切换后菜单不关闭（回调 `return 0`），文本实时变化

5. **`main.lua` 注册鼠标回调**
   - `love.mousepressed` / `love.mousereleased` → 入鼠标事件队列

## Scope Boundaries

### In Scope

- 菜单的鼠标命中测试与点击分发（键盘路径完全不变）
- 右键呼出菜单（含屏蔽条件）
- 点击外部关闭
- 子菜单切换语义
- 「鼠标操作」toggle 项 + 两个菜单入口
- 鼠标开关 onChange 立即生效
- 测试 + 四 Lua 版本验证

### Out of Scope

- 地图悬停高亮 / 坐标反解 / 寻路 → slice 3
- 触摸输入 / 虚拟按键
- 隐藏系统光标 / 自绘指针
- 战斗内的鼠标操作
- 菜单的拖拽、滚轮、右键菜单（右键已用于呼出主菜单）
- `menu_state_machine.lua` 的重构拆分（记入 epic TODO）

## Requirements

### REQ-MS2-1 右键呼出菜单

右键只在大地图/小场景呼出菜单，事件执行中与阻塞输入期间不呼出。

### REQ-MS2-2 菜单项点击

点击菜单项等价于键盘选中；点击值项箭头等价于上下键；点击外部关闭菜单。

### REQ-MS2-3 子菜单切换

子菜单打开时点击主菜单其他项，必须先关闭子菜单再响应新项。

### REQ-MS2-4 鼠标开关

「鼠标操作」项在两个菜单入口可切换，切换立即生效且持久化。

### REQ-MS2-5 键盘零回归

所有既有键盘菜单操作行为完全不变。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（鼠标是并行输入路径）
- 回归风险：中（要改 `menu_state_machine` 的输入分发，必须证明键盘路径不变）

## 关键设计决策（详见 `mouse-menu/design.md`）

| ADR | 决策 |
|-----|------|
| ADR-MS2-001 | 鼠标点击**翻译成已有的键盘语义**，不另开一套选中逻辑 |
| ADR-MS2-002 | 命中测试用 `menu.x1/y1/w/h/start/num` 的几何字段，纯函数可单测 |
| ADR-MS2-003 | 「先关子菜单再响应新项」用 `menuStack` 深度比较实现 |
| ADR-MS2-004 | 鼠标开关用普通菜单项 + 回调 `return 0`（实测验证，无需新 kind） |
