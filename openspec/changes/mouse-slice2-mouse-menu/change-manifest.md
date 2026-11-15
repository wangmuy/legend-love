---
status: active
parent_epic: 2026-11-mouse-input
---
# Change Manifest: mouse-slice2-mouse-menu — 鼠标菜单操作

> 本 slice 只有一个子 change，位于 `openspec/changes/mouse-menu/`（与 slice 目录同级）。

## Change Assignments

### Change: mouse-menu

- **Repository**: this repo
- **Scope**: fullstack（framework 菜单组件 + 游戏菜单接入 + main.lua 回调 + 测试）
- **Responsibility**:
  1. `menu_state_machine.lua` 加鼠标命中测试（纯几何计算，可单测）与点击分发
  2. 点击语义**翻译成已有键盘语义**（点菜单项 = 光标移过去 + 确认；
     点值项箭头 = 上下键；点外部 = ESC）
  3. 右键呼出菜单：仅 MMAP/SMAP，继承 `JY.CurrentD >= 0` 与
     `InputManager.disableInput` 屏蔽
  4. 子菜单打开时点主菜单其他项 → 先关子菜单再响应新项
  5. 「鼠标操作」toggle 项（普通菜单项 + 回调 `return 0`，无需新 kind）
     - 开始菜单「设置」加 1 项
     - 大地图「系统」加 1 项
  6. `main.lua` 注册 `love.mousepressed` / `love.mousereleased`
  7. 鼠标开关 onChange 立即生效（关闭后不再处理鼠标事件）
  8. 单元测试：命中测试（含 `numShow` 滚动偏移）、点击分发、子菜单切换、
     toggle 项、右键屏蔽条件
- **Depends On**: `engine-capability`（slice 1）
- **Status**: [ ] Pending

---

## 依赖图

```
  engine-capability (slice 1)
        │  EngineAPI.input.mousePosition / mouseButton
        │  EngineAPI.system.getOS
        │  Settings.setPlatform / platformDefaults
        │  enqueueMouseEvent / getMouseEvent
        ▼
  mouse-menu (本 slice)
```

## 本 slice 向后暴露的契约

slice 3 不依赖本 slice，但两者共用 slice 1 的鼠标事件队列。
若本 slice 把鼠标事件「消费掉」后 slice 3 读不到，需要协调 —— 
**解决方案**：本 slice 只在**菜单激活时**消费鼠标事件；
无菜单时事件留在队列里由 slice 3 处理。
