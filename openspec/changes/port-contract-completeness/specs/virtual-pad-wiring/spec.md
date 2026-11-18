# Virtual Pad Wiring

## ADDED Requirements

### Requirement: REQ-VP-1 虚拟手柄接线必须真实可用

`input-action-layer`（commit `33b89bc`）引入的虚拟手柄存在接线缺陷，
本 change SHALL 修复它：
`JYMainAdapter.pollVirtualPad` 依赖 `EngineAPI.render.getWidth` 与
`EngineAPI.render.getHeight`，但这两个函数**在契约与实现里都不存在**，
导致函数永远在 `return false` 提前返回。

实测证据：

```
EngineAPI.render.getWidth  = nil
EngineAPI.render.getHeight = nil
```

结果：**虚拟手柄在真机上永远不会激活**，而它 57 条逻辑层测试全绿。

#### Scenario: LÖVE 下虚拟手柄真实激活

- **Given** LÖVE 引擎，屏幕 1024×768，`input.virtualPad = true`
- **And** `VirtualPad` 已 `init()` 并使用默认布局
- **When** 计算 accept 按钮的圆心 `(cx, cy)` 并注入触摸点 `{id=1, x=cx, y=cy}`
- **Then** `JYMainAdapter.pollVirtualPad()` 返回 `true`
- **And** `InputManager.getActionEvent()` 返回 `{action="ui.accept", source="touch"}`

#### Scenario: 触摸点在空白区不产出动作

- **Given** 同上配置
- **When** 注入触摸点 `{id=1, x=10, y=10}`（远离所有按钮）
- **Then** `pollVirtualPad()` 返回 `true`（有触摸但无命中）
- **And** 动作队列为空

#### Scenario: 设置关闭时不激活

- **Given** `input.virtualPad = false`
- **When** 注入 accept 按钮圆心的触摸点
- **Then** `pollVirtualPad()` 返回 `false`
- **And** 动作队列为空

### Requirement: REQ-VP-2 尺寸查询必须来自契约

`render.getWidth` / `render.getHeight` SHALL 是 EngineAPI 契约的一部分，
SHALL NOT 依赖 `CC.ScreenW` / `CC.ScreenH` 这类编译期常量。

**理由**：Godot 的窗口尺寸可在运行时变化（窗口缩放、多显示器、
Android 旋转），编译期常量无法适配。

#### Scenario: 尺寸查询在四引擎都存在

- **Given** 4 个引擎实现
- **When** 调 `EngineAPI.render.getWidth()` / `.getHeight()`
- **Then** 都返回 number（LÖVE 返回真实尺寸；MUD/Web 返回哨兵 1024/768 或 0）

#### Scenario: 虚拟手柄用契约尺寸而非 CC 常量

- **Given** 窗口被 resize 到 800×600（模拟注入）
- **When** 调 `pollVirtualPad()`
- **Then** 按钮命中区按 800×600 计算，而非 `CC.ScreenW/H` 的 1024×768

### Requirement: REQ-VP-3 一个手指只归属一个按钮

（本需求在 `input-action-layer` 已实现，本 change SHALL 补端到端验证）

#### Scenario: 拖动不串键

- **Given** 虚拟手柄有 up 与 right 两个按钮
- **When** 手指按在 up 后滑到 right 的位置
- **Then** 不产出 `ui.right` 事件（手指已归属 up）
