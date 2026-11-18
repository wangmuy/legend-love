---
status: active
created: 2026-11-17
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: input-action-layer — 从 VK 整数到语义动作 + 双通道（事件/状态）

## Why

用户提问：现在的键鼠支持是否符合事件驱动？framework 里的输入 API 能否适配
Godot/Unreal？怎么同时支持键盘/鼠标/手柄/VR，并**优先使用各引擎原生的输入设施**？

调查后确认四个真问题（都有代码/实测依据）：

### 问题 1：引擎无关性泄漏了两次，而且方向相反

`game/framework/input_manager.lua:52-61`：

```lua
local baseKeyMap = {
    ["escape"] = 27,          -- 左边是 LÖVE 键名
    [" "] = 32,
    ["return"] = 13,
    ["up"] = 1073741906,      -- 右边是 Windows VK 码
    ["down"] = 1073741905,
    ["left"] = 1073741904,
    ["right"] = 1073741903,
}
```

这不是「引擎无关」，是**同时绑定了两个引擎**：换 Godot 要重写左边（键名体系不同），
换 Linux/无窗口环境要重写右边（VK 是 Windows 概念）。而 36 处业务代码直接比较
这些整数。

### 问题 2：事件队列住错了层，引擎实现不知道有「事件」这回事

EngineAPI.input 只有 5 个函数（全仓 59 个 EngineAPI 函数中的 5 个）：

```lua
getKey() / waitForKey() / setKeyRepeat(delay, interval)
mousePosition() / mouseButton(button)
```

后两个都是**状态查询**，不是事件。而真正的鼠标事件队列
（`enqueueMouseEvent` / `getMouseEvent`，`input_manager.lua:283-347`）
住在 framework 里——**任何新引擎都要自己再造一套队列语义**。

### 问题 3：手柄/触摸完全没接

```
game/conf.lua:70       t.modules.joystick = false
game/conf.lua:34       t.accelerometerjoystick = false
game/conf.lua:79       t.modules.touch = true   ← 开了但全仓 0 处使用

全仓（非测试）:  love.touch 0 处、love.joystick 0 处、gamepad 0 处
framework/ + engine_api.lua:  getAxis|analog|deadzone 0 处
```

而 `mouse_menu.lua:31` 的注释已经写明「Android 的主要输入方式是**后续要加的虚拟按键**」，
且 `product.env` 里 `TARGET_ANDROID="true"`。Android 是活跃构建目标，虚拟手柄是明确需求。

### 问题 4：事件队列装不下连续量

`maxQueueSize = 64`。若把摇杆位置当事件每帧入队：

```
60 fps × 64 槽 = 1.07 秒
→ 队列长期处于快满状态 → 玩家真按键时事件被挤掉
```

**连续量本质上不属于事件队列。** 这不是我们的特殊困难，三个目标引擎都把
「事件」与「状态」分成两套：

| | 离散输入 | 连续输入 |
|---|---|---|
| Godot 4 | `_input(event)` 回调 | `Input.get_vector()` **每帧轮询** |
| Unreal 5 | InputAction Trigger 事件 | `GetInputActionValue()` **每帧轮询** |
| SDL/LÖVE | `love.keypressed` 回调 | `getGamepadAxis()` **每帧读** |

### 附带发现：`async_dialog` 的输入框实际打不出字

`async_dialog.lua:266` 期待收到任意可打印字符：

```lua
elseif key >= 32 and key <= 126 then
    currentDialog.input = currentDialog.input .. string.char(key)
```

但 `baseKeyMap` 只映射了 9 个键，其他键在 `onKeyPressed` 里被
`if not gameKey then return end` 直接丢弃。**字母永远进不了队列。**

查调用方：`EventBridge:showInput` 有定义，但全仓没有任何业务代码调用它，
所以这个缺陷从未被用户遇到。

**再加一条**：该分支期望的 `VK_BACKSPACE` **根本没有定义**。

```
$ grep -rn 'VK_BACKSPACE' game/ --include=*.lua
game/framework/async_dialog.lua:262:        elseif key == VK_BACKSPACE then
```

`jyconst.lua:28-37` 只定义了 `VK_ESCAPE/Y/N/SPACE/RETURN` 与 4 个方向键。
Lua 里比较未定义全局变量得到 `nil`，`key == nil` **恒为 false** ——
所以退格是**静默失效**，连报错都没有。

即 `showInput` 输入框有**三重失效**：
1. 字母被 `onKeyPressed` 的 `if not gameKey then return end` 丢弃
2. `VK_BACKSPACE` 未定义 → 退格恒不生效
3. 唯一能走通的只有 RETURN（提交空串）

这是 `baseKeyMap` 与业务期望脱节的直接证据，也是本 change 必须治理它的理由。

## 目标

1. framework 的输入契约改为**语义动作**，不再比较 VK 整数
2. **两层命名空间**：framework 拥有通用动作（`ui.*`），游戏拥有私有动作（`<game>.*`）
3. 事件与状态**双通道**，连续量不进事件队列
4. EngineAPI 补齐**能力声明 + 物理轴读取**，让 Godot/Unreal/VR 都有对应落点
5. Android 虚拟手柄（当前需求）+ 物理手柄 + 触摸，共用同一层动作映射
6. framework 可复用到仙剑、白金英雄坛说等任意游戏——**不内置任何玩法语义**

## What Changes

| # | 改动 | 文件 |
|:-:|---|---|
| 1 | 新增动作常量与事件结构 | `framework/input_actions.lua`（新） |
| 2 | 动作事件队列 + 带 provenance | `framework/input_manager.lua`（改） |
| 3 | 绑定表（物理事件 → 动作） | `framework/input_bindings.lua`（新） |
| 4 | 向量机制（游戏自声明） | `framework/input_bindings.lua` 内 |
| 5 | EngineAPI.input 扩 4 函数 | `engine-love2d/engine_api.lua`（改） |
| 6 | LÖVE 侧实现（轴/触摸/手柄） | `engine-love2d/engine_love2d.lua`（改） |
| 7 | 虚拟手柄（逻辑+绘制分离） | `framework/virtual_pad.lua`（新） |
| 8 | 开 joystick 模块 | `game/conf.lua`（改） |
| 9 | 游戏私有动作注册 | `script/input_actions.lua`（新） |
| 10 | 36 处 VK 比较 → 动作名 | `framework/` + `script/`（改） |

## In Scope

- `framework/input_actions.lua`、`framework/input_bindings.lua`、
  `framework/virtual_pad.lua`（新增）
- `framework/input_manager.lua`、`framework/input_async.lua`（改造）
- `engine-love2d/engine_api.lua`、`engine-love2d/engine_love2d.lua`（扩接口+实现）
- `engine-mud/engine_mud.lua`（capabilities 声明为全 false）
- `game/conf.lua`（`joystick = true`）
- `script/input_actions.lua`（游戏私有动作 `jy.y` / `jy.n`）
- 36 处业务代码的动作名迁移
- 虚拟手柄设置项（`Settings` + 菜单接线）
- 单元测试（新增 3 套）、门禁脚本

## Out of Scope

- **不改现有玩法**：地图仍「一次一格」，战斗仍回合制。所有 36 处判断在迁移后
  **逐帧行为等价**（见 design ADR-8）
- **不内置 `move` / `aim`**：那是 Hades 类玩法惯例，不是输入语义（见 design ADR-4）
- **不实现 VR**：只在 `source` / `ray` 字段留槽（见 design ADR-7）
- **不实现物理手柄的热插拔与设备枚举**：本 slice 只保证映射表与 capability 就位
- **不改 MOD 侧渲染/音频**（与上一个 change 无关）

## 关键设计结论（详见 design.md）

| ADR | 结论 |
|---|---|
| ADR-1 | 动作分两层：`ui.*` 框架拥有，`<game>.*` 游戏拥有 |
| ADR-2 | 映射住 **framework 侧**，不住引擎侧 |
| ADR-3 | 事件携带 **provenance**（`source`），废弃 `synthetic` 脏标记 |
| ADR-4 | 物理轴 `getAxis(6 个闭集名)` + 游戏自声明 `defineVector`；**不内置 move/aim**；**内置 `cursor`** |
| ADR-5 | 双通道：事件排队、状态每帧读 |
| ADR-6 | 摇杆过阈值用**迟滞**（按下 0.35 / 释放 0.25） |
| ADR-7 | VR 只留槽（`source="vr"` + `ray`） |
| ADR-8 | 迁移期**两套并存**，VK 常量保留，逐项迁移 |
| ADR-9 | 虚拟手柄逻辑在 framework、绘制走 EngineAPI；布局用**锚点+边距** |

## 为什么动作名是 `ui.accept` 而不是 `ui.confirm`

金庸里 `Y` 表达的是**语义上的「是」**（对「要不要当帮主」答是），而
`SPACE`/`RETURN` 表达的是**「推进/确认当前选中」**。框架层若叫 `confirm`，
两者会被混淆。叫 `accept` 保持中立，且对齐 Godot 内建的 `ui_accept` / `ui_cancel`。

`Y` / `N` 因此**不属于 framework**，而是游戏私有动作 `jy.y` / `jy.n`。
这正是「framework 可复用于仙剑」的前提——通用层不能有金庸词汇。

## 风险

| 风险 | 缓解 |
|---|---|
| 36 处调用点 + 117 处测试引用，改错会让输入行为悄悄变化 | 两套并存 + 逐项迁移 + 每步跑全量测试（ADR-8） |
| `getVector` 这次没有消费方 | 标 `SPECULATIVE`，3 个月内无实现则重估（见 design） |
| 虚拟手柄在小屏上遮挡视野 | 透明度可配 + 只在 Android 默认开（`platformDefaults`） |
| 动作名一旦定下就是对外契约 | 两层命名空间 + 游戏层可自由增删，框架层只 9 个 |
