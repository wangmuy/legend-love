## ADDED Requirements

### Requirement: REQ-IAL-1 动作分两层命名空间

输入动作 SHALL 分为两层：
- **framework 通用层**：命名空间 `ui.`，由框架拥有并负责映射，SHALL 只包含
  `ui.up / ui.down / ui.left / ui.right / ui.accept / ui.cancel / ui.menu /
  ui.text / ui.backspace / ui.cursor` 这 10 个。
- **游戏私有层**：命名空间 `<game>.`，由游戏注册，框架只透传、SHALL NOT 理解其语义。

framework 通用层 SHALL NOT 出现任何特定游戏的词汇。

#### Scenario: 金庸的 Y/N 住在游戏层
- **WHEN** 检查 `framework/` 下所有文件的字符串
- **THEN** 不出现 `jy.y` / `jy.n`；这两个动作定义在 `script/input_actions.lua`

#### Scenario: 通用层只有 10 个动作
- **WHEN** 枚举 `framework/input_actions.lua` 导出的 `ui.*` 常量
- **THEN** 恰好 10 个（9 个离散 + 1 个向量 `ui.cursor`）

#### Scenario: 负向对照——框架层出现游戏词汇必须被发现
- **WHEN** 在 `framework/input_actions.lua` 里临时加入 `ACTION_JY_Y = "jy.y"`
- **THEN** 门禁报 `[FAIL] framework 通用层不得出现游戏词汇`

### Requirement: REQ-IAL-2 动作名用 `accept` 不用 `confirm`

确认/推进动作 SHALL 命名为 `ui.accept`，SHALL NOT 命名为 `ui.confirm`。

理由：金庸里 `Y` 表达的是「语义上的是」（对「要不要当帮主」答是），而
`SPACE`/`RETURN` 表达的是「推进/确认当前选中」。若框架层叫 `confirm`，两者会
混淆；`accept` 保持中立，且对齐 Godot 内建的 `ui_accept` / `ui_cancel`。

#### Scenario: 常量名正确
- **WHEN** 读 `framework/input_actions.lua`
- **THEN** 存在 `ACTION_ACCEPT = "ui.accept"`，不存在 `"confirm"`

### Requirement: REQ-IAL-3 事件结构统一且携带 provenance

所有输入事件 SHALL 使用同一张表结构：

```lua
{ action, source, value, char, position, index, ray, time }
```

其中 `source` SHALL 取 `"key" | "mouse" | "pad" | "touch" | "vr"` 之一。
`synthetic` 字段 SHALL 被删除。

#### Scenario: 鼠标点击推进对话的事件带 source
- **WHEN** 鼠标左键点击期间有对话在等推进
- **THEN** 产生的事件为 `{action="ui.accept", source="mouse", position={x,y}}`，
  而不是 `{key=32, synthetic=true}`

#### Scenario: 消费方可按 source 过滤
- **WHEN** 地图主循环收到 `source="mouse"` 的 `ui.accept`
- **THEN** 可以拒绝它（这正是修复「悬停注入 SPACE 冒出店小二对话」的机制）

#### Scenario: 负向对照——`synthetic` 不得残留
- **WHEN** grep `synthetic` 在 `framework/input_manager.lua`
- **THEN** 结果为 0 处

### Requirement: REQ-IAL-3b 文本输入与退格必须真正可达

`ui.text` 动作 SHALL 携带 `char` 字段，且任意可打印字符 SHALL 能进入动作队列。
`ui.backspace` SHALL 有明确定义的常量与绑定，SHALL NOT 依赖未定义的全局变量。

背景（实测）：现状下 `async_dialog` 的输入框有三重失效——
字母被 `baseKeyMap` 之外键名丢弃、`VK_BACKSPACE` 未定义（比较恒 false）、
唯一出口是 RETURN 提交空串。

#### Scenario: 字母能进入队列
- **WHEN** 按键 `a`（`baseKeyMap` 里没有）
- **THEN** 产生 `{action="ui.text", char="a", source="key"}` 事件

#### Scenario: 退格有定义
- **WHEN** 按键 `backspace`
- **THEN** 产生 `{action="ui.backspace", source="key"}` 事件

#### Scenario: 输入框能打出字并退格
- **WHEN** 打开 `showInput` 输入框，依次按 `a`、`b`、退格
- **THEN** 输入内容为 `"a"`（`"ab"` 减 1 字符）

#### Scenario: 负向对照——未定义常量必须被发现
- **WHEN** grep 业务代码里引用了但 `jyconst.lua` 未定义的 `VK_*`
- **THEN** 结果为 0 处

### Requirement: REQ-IAL-4 EngineAPI.input 补齐物理轴与能力声明

EngineAPI.input SHALL 新增 4 个函数（现有 5 个保持不变）：

```lua
getAxis(name)              -- name ∈ {leftx,lefty,rightx,righty,triggerleft,triggerright}
getCapabilities()          -- { pointer, touch, gamepad, vr }
getPointerPosition()       -- 包装 mousePosition()，明确为每帧状态查询
pollAction()               -- 返回动作名，nil 表示无
```

**四个引擎实现都必须补齐这 4 个函数**（实测共 4 个实现）：

| 实现 | 路径 |
|---|---|
| LÖVE | `game/engine-love2d/engine_love2d.lua` |
| MUD | `game/engine-mud/engine_mud.lua` |
| Web | `game/engine-web/engine_web.lua` |
| 测试桩 | `game/tests/engine_test.lua` |

轴名 SHALL 与 SDL / Godot / Unreal 的闭集一致（这 6 个名字三家共用）。

#### Scenario: 轴名闭集正确
- **WHEN** 对非法轴名调用 `getAxis("foo")`
- **THEN** 返回 0 且不抛错（宽容失败，便于跨引擎降级）

#### Scenario: MUD 引擎如实声明无输入设备
- **WHEN** `engine-mud` 的 `getCapabilities()` 被调用
- **THEN** 返回 `{pointer=false, touch=false, gamepad=false, vr=false}`

#### Scenario: LÖVE 引擎声明真实能力
- **WHEN** `engine-love2d` 的 `getCapabilities()` 被调用
- **THEN** 返回 `{pointer=true, touch=true, gamepad=true, vr=false}`
  （`vr=false` 是留槽，见 REQ-IAL-9）

#### Scenario: Web 引擎如实声明
- **WHEN** `engine-web` 的 `getCapabilities()` 被调用
- **THEN** 返回 `{pointer=true, touch=false, gamepad=false, vr=false}`
  （Web 有鼠标但当前未接触摸/手柄）

#### Scenario: 测试桩记录调用
- **WHEN** 测试中调用 `EngineAPI.input.getCapabilities()`
- **THEN** `engine_test.lua` 的 `logCall("input.getCapabilities")` 被记录

#### Scenario: 四个实现都齐全
- **WHEN** 遍历 4 个引擎实现，检查 input 的 9 个函数
- **THEN** 每个实现都有全部 9 个，无 nil

### Requirement: REQ-IAL-5 双通道：事件排队、状态每帧读

连续量 SHALL NOT 进入事件队列。两通道：

- **通道 A（事件）**：`getAction()` / `pollAction()`，队列容量 64 保持不变
- **通道 B（状态）**：`getVector(id)` / `getAxis(name)`，每帧读，不排队

#### Scenario: 模拟量不挤占事件队列
- **WHEN** 连续 100 帧每帧读取 `getVector("ui.cursor")`，同时按下 1 个键
- **THEN** 按键事件仍能被消费（不因向量读取而丢失）

#### Scenario: 事件队列容量不因模拟量而改变
- **WHEN** 检查 `maxQueueSize`
- **THEN** 仍为 64

### Requirement: REQ-IAL-6 向量由游戏自声明，框架只内置 `ui.cursor`

`framework/input_bindings.lua` SHALL 提供：

```lua
defineVector(id, { x = {"leftx"}, y = {"lefty"} })   -- y 可省略（单轴）
getVector(id) -> { x, y, magnitude, angle } | nil
```

框架 SHALL 只内置 `ui.cursor` 一个向量（菜单光标，跨游戏通用）。
框架 SHALL NOT 内置 `move` / `aim` 等玩法语义向量。

#### Scenario: 内置 cursor 可用
- **WHEN** 调用 `getVector("ui.cursor")`
- **THEN** 返回 `{x, y, magnitude, angle}` 四字段

#### Scenario: 游戏可声明自定义向量
- **WHEN** `script/input_actions.lua` 调用
  `defineVector("move", {x={"leftx"}, y={"lefty"}})`
- **THEN** `getVector("move")` 可用，且框架代码里无任何 `"move"` 字面量

#### Scenario: 单轴向量
- **WHEN** `defineVector("steer", {x={"leftx"}})`
- **THEN** `getVector("steer").y` 恒为 0，`magnitude` 反映单轴幅度

#### Scenario: 负向对照——框架内置 move 必须被发现
- **WHEN** 在 `framework/input_bindings.lua` 里临时加入
  `defineVector("move", ...)`
- **THEN** 门禁报 `[FAIL] framework 不得内置 move/aim 等玩法向量`

### Requirement: REQ-IAL-7 摇杆派生离散事件用迟滞

摇杆推动派生的离散动作事件 SHALL 使用迟滞：

- 按下阈值默认 **0.35**
- 释放阈值默认 **0.25**
- 死区可配置（`Settings` 键 `input.deadzone`，范围 0..1，默认 0.35）

摇杆派生的**重复** SHALL 独立于 `keyRepeatEnabled`：
延迟 0.3 s、间隔 0.04 s（与键盘同值，手感统一）。

#### Scenario: 摇杆 0.30 抖动不产生事件
- **WHEN** 摇杆 X 轴在 0.28..0.32 之间抖动 10 帧
- **THEN** 产生 0 个 `ui.left` / `ui.right` 事件（死区内）

#### Scenario: 推过按下阈值产生一次事件
- **WHEN** 摇杆 X 轴从 0 推到 0.40
- **THEN** 产生 1 个 `ui.right` 事件

#### Scenario: 迟滞带内不重复产生
- **WHEN** 摇杆从 0.40 回到 0.30（仍在释放阈值 0.25 以上）
- **THEN** 不产生新的 `ui.right`

#### Scenario: 键盘重复不受摇杆重复影响
- **WHEN** `keyRepeatEnabled` 为 false（默认）
- **THEN** 按住方向键仍只产生 1 个事件（手感不变）

### Requirement: REQ-IAL-8 虚拟手柄：逻辑与绘制分离、布局用锚点

`framework/virtual_pad.lua` SHALL：

- 只做「触摸点 → 按钮命中 → 产出动作事件」的**逻辑**
- **SHALL NOT** 直接调用任何 `love.*` 函数（绘制走 `EngineAPI.render`）
- 布局 SHALL 使用锚点 + 边距（`{anchor=, ox=, oy=, r=}`），SHALL NOT 使用绝对像素
- 触摸读取 SHALL 使用 LÖVE 11.5 的正确 API：
  `love.touch.getTouches()` + `love.touch.getPosition(id)`
  （SHALL NOT 使用 0.10.x 的 `getTouchCount()` / `getTouch(i)`）

#### Scenario: 虚拟手柄不直连 LÖVE
- **WHEN** grep `love\.` 在 `framework/virtual_pad.lua`
- **THEN** 结果为 0 处

#### Scenario: 触摸 API 用 11.5 形态
- **WHEN** grep `in engine-love2d/` 的实现
- **THEN** 使用 `getTouches()`，不使用 `getTouchCount()`

#### Scenario: 布局是相对量
- **WHEN** 检查默认布局表
- **THEN** 字段为 `anchor` / `ox` / `oy` / `r`，无硬编码屏幕坐标

### Requirement: REQ-IAL-9 VR 只留槽不实现

事件结构 SHALL 允许 `source="vr"` 与 `ray={origin,dir}`，
但 `getCapabilities().vr` SHALL 为 `false`，SHALL NOT 存在任何 VR 输入实现分支。

#### Scenario: VR 字段存在但能力为假
- **WHEN** 检查事件文档与 `getCapabilities()`
- **THEN** `ray` 字段在结构定义中出现，`vr` 能力为 false

#### Scenario: 负向对照——不得有 VR 实现分支
- **WHEN** grep `vr` 相关实现代码
- **THEN** 只有常量与字段定义，无 `if source == "vr"` 之外的逻辑

### Requirement: REQ-IAL-10 平台默认值与手动开关

虚拟手柄 SHALL 按平台设默认值：
`Android=true, iOS=true, Windows/Linux/macOS=false`。

虚拟手柄与鼠标操作 SHALL 都能在设置菜单里手动开关（Android 接蓝牙鼠标/手柄的
情况真实存在）。

#### Scenario: Android 默认开
- **WHEN** 在 Android 平台首次运行（无用户设置）
- **THEN** `Settings.get("input.virtualPad")` 返回 `true`

#### Scenario: 桌面默认关
- **WHEN** 在 Windows 平台首次运行
- **THEN** 返回 `false`

#### Scenario: 手动开关生效
- **WHEN** 玩家在设置菜单关闭虚拟手柄
- **THEN** 虚拟手柄不再绘制，也不再产出动作事件

### Requirement: REQ-IAL-11 迁移期行为逐帧等价

迁移完成后，同一份输入序列产生的事件序列 SHALL 与迁移前**逐帧等价**：

| 输入 | 迁移前 | 迁移后 |
|---|---|---|
| 按 SPACE | `getKey() == VK_SPACE` | `getAction() == "ui.accept"` |
| 按 ESC | `VK_ESCAPE` | `"ui.cancel"` |
| 按 UP | `VK_UP` | `"ui.up"` |
| 按 Y | `VK_Y` | `"jy.y"` |
| 鼠标左键（对话期） | `{key=32, synthetic=true}` | `{action="ui.accept", source="mouse"}` |

`getKey()` 与 VK 常量 SHALL 在迁移期保留（36 处调用点逐项迁移）。

#### Scenario: 迁移后 36 处调用点行为不变
- **WHEN** 运行全量测试
- **THEN** 3022 条（5.1）/ 3021 条（5.5）全部通过，无行为回归

#### Scenario: 同一输入产生相同语义
- **WHEN** 分别用迁移前/迁移后的接口喂入「SPACE → ESC → UP → SPACE」
- **THEN** 两次得到的动作序列都是 `ui.accept, ui.cancel, ui.up, ui.accept`

### Requirement: REQ-IAL-12 引擎实现的最小责任边界

每个引擎实现 SHALL 只负责：

1. 产生**物理事件**（键、鼠、触摸、手柄）
2. 回答 `getAxis(name)` / `getCapabilities()` / `getPointerPosition()`
3. 绘制虚拟手柄（经 `EngineAPI.render`）

SHALL NOT 负责动作映射（映射住 framework 侧，见 ADR-2）。

#### Scenario: 新引擎只需实现 4 个新函数
- **WHEN** 检查 `engine-capability` 的接口清单
- **THEN** input 模块函数数从 5 增至 9，且每个新函数的语义有明确文档

#### Scenario: MUD 引擎可零成本接入
- **WHEN** `engine-mud` 实现 4 个新函数
- **THEN** `getAxis` 恒返回 0、`getCapabilities` 全 false、`pollAction` 走预设队列，
  游戏逻辑仍能运行（无鼠标/手柄也不崩）
