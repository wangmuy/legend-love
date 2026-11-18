---
status: active
created: 2026-11-17
---
# Design: input-action-layer

## Context

输入层当前的形状（全部来自实际代码，非推测）：

```
                    ┌─ love.keypressed ────┐
                    │                      ▼
                    │        ┌──────────────────────────────┐
                    └───────▶│ InputManager.baseKeyMap      │  "space"→32
                             │ (LÖVE 键名 → Windows VK 整数) │  "up"→1073741906
                             └──────────────┬───────────────┘
                                            ▼
                    ┌────────────────────────────────────────┐
   love.mousepressed│  eventQueue（键盘环形缓冲, 64）         │ 存整数 VK
        ───────────▶│  mouseQueue（鼠标环形缓冲, 64）         │ 存 {x,y,button}
                    └────────────────────────────────────────┘
                              │                    │
              getKey() ◀──────┘                    └──────▶ getMouseEvent()
                 │                                            │
                 ▼                                            ▼
    ┌─────────────────────────┐              ┌──────────────────────────┐
    │ 36 处业务代码比较 VK_*  │              │ jymain_adapter.pollMouse │
    │ VK_SPACE ×29  VK_ESC ×26│              │ jymain_adapter.pollHover │
    │ VK_RETURN ×23 ...       │              │ （每帧轮询 mousePosition）│
    └─────────────────────────┘              └──────────────────────────┘
                 ▲                                            │
                 └──── enqueueKeyEvent(VK_SPACE) ◀────────────┘
                       （点击"变成"空格，synthetic=true 脏标记）
```

规模数据（实测）：

| 项目 | 数量 |
|---|---|
| EngineAPI 总函数 | 59（其中 input 只占 5） |
| `lib.GetKey` 调用点（非测试） | **36** |
| 唯一 VK 常量 | 9（`VK_UP/DOWN/LEFT/RIGHT/SPACE/RETURN/ESCAPE/Y/N` + `VK_BACKSPACE`=10） |
| 测试里 VK/注入引用 | **117** |
| framework 内模拟量概念 | **0** |
| touch / joystick 使用（非测试） | **0 / 0** |

## Decisions

### ADR-1：动作分两层命名空间

**Context**：framework 要能复用到仙剑、白金英雄坛说等任意游戏。若把金庸的
`Y`/`N`（原版的「是/否」快捷键，4 处使用）放进通用层，通用层就有了金庸词汇。

**Decision**：

```
第一层 framework 通用  命名空间 "ui."   （框架拥有，负责映射）
  ui.up  ui.down  ui.left  ui.right      ← 导航
  ui.accept                              ← 推进/确认当前选中
  ui.cancel                              ← 取消/返回一层
  ui.menu                                ← 呼出系统菜单
  ui.text                                ← 携 char 字段
  ui.backspace                           ← 退格
  ui.cursor                              ← 内置向量（见 ADR-4）

第二层 游戏私有        命名空间 "<game>." （游戏注册，框架只透传）
  金庸: "jy.y" / "jy.n"
  仙剑: "pal.use" / "pal.flee"（将来）
```

**为什么是 `ui.accept` 不是 `ui.confirm`**：

| 键 | 语义 | 动作 |
|---|---|---|
| `SPACE` / `RETURN` | 推进 / 确认当前选中 | `ui.accept` |
| `Y` | 「对『要不要当帮主』答是」 | `jy.y`（游戏层） |

`Y` 表达的是**语义上的「是」**，`SPACE` 表达的是**「推进」**。框架层叫 `confirm`
会让两者混淆。`accept` 保持中立，且对齐 Godot 内建的 `ui_accept` / `ui_cancel`。

**Consequences**：
- framework 零金庸词汇 → 可复用
- 游戏可自由增删私有动作，不影响框架
- 动作名一旦定下是**对外契约**，框架层只有 9 个，稳定可控

### ADR-2：映射住 framework 侧，不住引擎侧

**Context**：两个选项。
- (a) 引擎侧：EngineAPI 暴露 `pollActions() → {ACTION, value}`，各引擎用原生绑定系统
- (b) framework 侧：EngineAPI 只吐原始物理事件，framework 做映射

**Decision**：**(b)**，理由：

1. 映射是**产品行为**（「上 = W 键」），不该散落在 20 个引擎实现里
2. 引擎侧做不了跨设备语义降级（「鼠标左键 = ui.accept」这种判断是框架知识）
3. Godot 的 InputMap / Unreal 的 MappingContext 确实更强，但**它们的配置文件
   格式互不兼容**——framework 若依赖它们，反而失去可移植性

**代价与缓解**：framework 必须认识物理 scancode。用**平台无关 scancode**
（LÖVE 的 `scancode` 字符串、Godot 的物理键位常量）而非 VK 整数，可接受。

### ADR-3：事件携带 provenance，废弃 `synthetic` 脏标记

**Context**：现有 `enqueueKeyEvent(VK_SPACE)` 把「鼠标点击」伪装成「空格键」，
用 `synthetic=true` 标记，`getKey()` 跳过它、`_peekKeyInternal` 不跳过。
这套机制已踩过真实 bug（用户报告）：

```
河洛客栈站在店小二旁 → 鼠标悬停物品格
→ 悬停注入 VK_SPACE 唤醒物品协程
→ 同一帧 GAME_SMAP.update 的 getKey() 也读到这个 SPACE
→ 走进 SPACE 分支「触发面向 tile 的事件」→ 冒出店小二对话
```

`synthetic` 的本质是「我不告诉你来源，只打个脏标记」。但消费方需要的恰恰是
**知道来源**才能决策。

**Decision**：事件统一结构，带 `source`：

```lua
{
  action   = "ui.accept",        -- 语义动作名
  source   = "key"|"mouse"|"pad"|"touch"|"vr",
  value    = 0..1 | nil,         -- 模拟量（摇杆派生事件带力度）
  char     = "a" | nil,          -- 仅 action == "ui.text"
  position = {x=, y=} | nil,     -- 指针类（鼠标/触摸/VR 射线命中点）
  index    = 1|2|nil,            -- 手柄编号 / 触摸 ID / 左右手
  ray      = {origin, dir} | nil,-- 仅 source == "vr"（留槽，不实现）
  time     = number,
}
```

**Consequences**：
- `synthetic` 字段删除；`getKey()` 的「跳过 synthetic」逻辑改为
  「按 source 过滤」
- 「手柄 A 键 = ui.accept」与「鼠标左键 = ui.accept」成为**同一种东西**，
  而不是两种 hack
- 消费方可以写 `if ev.source == "mouse" then return end` 拒绝对话期鼠标推进

### ADR-4：物理轴 + 游戏自声明向量；不内置 move/aim，内置 cursor

**Context**：用户在 Q21 追问「`getMoveVector`/`getAimVector` 这样的语义通用吗？」
核对 Godot/Unreal/SDL 三个外部引擎的原生轴命名与向量接口：

| 引擎 | 物理轴闭集 | 向量接口 | 有 move/aim? |
|---|---|---|---|
| SDL / LÖVE | `leftx lefty rightx righty triggerleft triggerright`（实测 `love.dll` 内字符串恰好 6 个） | 无 | ❌ |
| Godot 4 | `JOY_AXIS_LEFT_X` 等同名 6 个 | `Input.get_vector(neg_x, pos_x, neg_y, pos_y)`——**参数是 action 名** | ❌ |
| Unreal 5 | `Gamepad_LeftX` 等同名 6 个 | `GetInputActionValue(InputAction)`——**参数是设计师建的资产** | ❌ |

**这 3 个外部引擎都不提供 `getMoveVector`/`getAimVector`。** 它们都刻意不替玩家规定
「左摇杆是移动」——Godot 让你从自己命名的 4 个动作组合向量，Unreal 让你从自己
建的 InputAction 取值。

`move`/`aim` 是 **Hades 类双摇杆玩法的惯例**，不是输入语义。若内置，等于把
Hades 的玩法强加给仙剑。

**Decision**（三层）：

```
第 0 层  EngineAPI.input.getAxis(name)              框架中立，物理
  name ∈ { leftx, lefty, rightx, righty, triggerleft, triggerright }
  返回 -1..1（扳机 0..1）；不含任何 gameplay 语义

第 1 层  framework/input_bindings.lua               框架拥有，机制
  defineVector(id, { x = {"leftx"}, y = {"lefty"} })   ← 游戏调用
  getVector(id) -> { x=, y=, magnitude=, angle= }
  内置唯一向量: "ui.cursor"（菜单光标，跨游戏通用）
  框架**不内置任何其他向量名**，也不知道 move 是什么

第 2 层  script/input_actions.lua                   游戏拥有，私有语义
  Hades 分支: defineVector("move", …) / defineVector("aim", …)
  赛车分支:   defineVector("steer", { x = {"leftx"} })     ← y 省略即单轴
  金庸当前:   无向量声明
```

**为什么内置 `ui.cursor`**：菜单光标是**跨游戏通用**的（仙剑、白金英雄坛说都有
菜单），不像 move/aim 属于特定玩法类型。它的定义与 `ui.up/down/left/right`
一致——都是「两对轴 → 一个二维量」。

**`getVector` 返回 `magnitude` 与 `angle` 的理由**：

| 玩法 | 需要的量 | 用得上 |
|---|---|---|
| Hades（方向性移动） | 方向 | `angle` |
| 飞行（分量控制） | 分量 | `x, y` |
| 赛车（单轴转向） | 带符号幅度 | `magnitude` |
| 菜单光标 | 方向 + 力度 | `angle` + `magnitude` |

三个量足以覆盖整张表，且**不预设任何玩法**。

### ADR-5：双通道——事件排队、状态每帧读

**Context**：`maxQueueSize = 64`。若把摇杆位置当事件每帧入队：

```
60 fps × 64 槽 = 1.07 秒
→ 队列长期处于快满状态 → 玩家真按键时事件被挤掉
```

而且这不是我们的特殊困难——这 3 个外部引擎都是这个形态：

| | 离散 | 连续 |
|---|---|---|
| Godot 4 | `_input(event)` | `Input.get_vector()` 每帧 |
| Unreal 5 | Trigger 事件 | `GetInputActionValue()` 每帧 |
| SDL/LÖVE | `love.keypressed` | `getGamepadAxis()` 每帧 |

**Decision**：

```
通道 A（事件，离散）       通道 B（状态，连续）
  ↓ 进队列                    ↓ 每帧读，不排队
getAction() / pollAction()   getVector(id) / getAxis(name)
  ↓                          ↓
菜单导航 / 对话 / 36 处判断    【当前无消费方，留给 Hades 式实时移动】
```

**Consequences**：两通道独立，互不挤占。事件队列容量仍是 64，不因模拟量而失效。

### ADR-6：摇杆派生离散事件用迟滞（hysteresis）

**Context**：单阈值（如 0.3）在摇杆停在 0.29 附近抖动时会反复产生/撤销
`ui.up`，菜单表现为选中项疯狂跳。

**Decision**：迟滞带。

| 参数 | 默认值 | 理由 |
|---|---|---|
| 按下阈值 | **0.35** | 太低误触发，太高要推到底 |
| 释放阈值 | **0.25** | 比按下低 0.1，压住机械抖动 |
| 重复延迟 / 间隔 | **0.3 s / 0.04 s** | 与键盘 `keyRepeatDelay/Interval` 同值，手感统一 |

**只把死区做成设置项**（`input.deadzone` 0..1 默认 0.35）：死区大小因人而异
（有人手抖、有人喜欢轻推），值得玩家调；而重复间隔是手感参数，不该让玩家改坏
（原版键盘重复也是写死的）。

**摇杆派生的重复独立于 `keyRepeatEnabled`**：后者当前是 `false`（键盘按住只走一格，
玩家已习惯）。若打开全局重复会**改变键盘既有手感**，是回归风险。摇杆在菜单里
本来就该像 D-pad 一样连发，所以用一个独立重复器，只服务模拟量派生的离散事件。

### ADR-7：VR 只留槽，不实现

**Context**：用户最初问了键盘/鼠标/手柄/VR。VR 的输入本质是 3D 射线 + 6DoF 姿态，
与 2D 坐标不同构。

**Decision**：契约留槽，不实现。

- `source` 允许取值 `"vr"`
- 事件允许携带 `ray = {origin, dir}`
- `capabilities.vr = false`

**理由**：留槽成本只是几行文档 + 一个 nil 字段；实现 VR 需要立体渲染、双手 6DoF
姿态、可瞬移交互模型，**与输入抽象层是两个问题**。留槽保证「将来接 VR 时不用改
事件形状」，这就够了。

**Negative Constraint**：不得在没有 VR 渲染管线前实现 VR 输入分支。

### ADR-8：迁移期两套并存，逐项迁移

**Context**：36 处调用点 + 117 处测试引用。一次性大改的风险是「所有输入行为悄悄
变化」，而输入 bug 表现为「某个菜单突然点不动」，极难定位。

**Decision**：保留兼容层，双轨并行。

```lua
-- 仍然存在（保 36 处调用点与 117 处测试）
VK_SPACE = 32, VK_ESCAPE = 27, ...          -- 全局常量不动
EngineAPI.input.getKey() → 整数               -- 41 处兼容

-- 新增
EngineAPI.input.pollAction() → 动作字符串
InputManager:getAction()   → 动作字符串
```

迁移顺序（每条跑全量测试）：

1. 加动作层，`getKey()` 保持不变（零行为变化）
2. 把 36 处逐文件迁移到 `getAction()`
3. 迁移完且测试全绿后，才考虑是否废弃 `getKey()`

**DoD**：迁移前后，同一份输入序列产生的事件序列**逐帧等价**（见 tasks 的回归断言）。

### ADR-9：虚拟手柄逻辑在 framework、绘制走 EngineAPI、布局用锚点+边距

**Context**：`reference/MobileControlsLibrary` 是唯一参考实现，但实测有两个问题：

**问题 1：它在 LÖVE 11.5 上跑不起来**（我实测过）：

```
=== 复刻 README 的循环 ===
  结果: 失败: main.lua:5: attempt to call field 'getTouchCount' (a nil value)

=== 11.5 正确写法 ===
  love.touch.getTouches()  存在   → 返回 id 列表
  love.touch.getPosition(id) 存在
  love.touch.getTouchCount() 缺失   ← README 用的老 API（0.10.x）
  love.touch.getTouch(i)     缺失
```

**问题 2：坐标硬编码**（`mobilecontrols.lua:5-12`）：

```lua
MobileControls.joystick = { x = 100, y = love.graphics.getHeight() - 150, radius = 50, ... }
MobileControls.buttons  = { {x = love.graphics.getWidth() - 100, y = ... } }
```

换分辨率、换竖屏即失效。

**Decision**：

1. **逻辑与绘制分离**：`framework/virtual_pad.lua` 只做「触摸点 → 按钮命中 →
   产出动作事件」；绘制走 `EngineAPI.render`
   - 理由：「哪块区域算 UP」是**布局与玩法逻辑**，不是引擎特性；
     「怎么画半透明圆」才是引擎特性
2. **布局用锚点 + 边距**：`{ anchor="bottom-left", ox=100, oy=-150, r=50 }`
   - 不用屏幕比例：超宽屏会把按钮拉到手指够不到的地方
   - 不用引擎原生 UI（Godot 的 `TouchScreenButton`）：那会把框架绑死到具体引擎
   - 锚点 + 边距只用 4 个数字，框架无需知道屏幕尺寸就能校验布局合法性
3. **触摸 API 用 11.5 的正确形态**：`getTouches()` + `getPosition(id)`

**平台默认值**（照 `mouse_menu.lua` 的 `platformDefaults` 模式，`settings.lua:173` 已支持）：

```lua
VirtualPad.PLATFORM_DEFAULTS = {
    Android = true,     -- 无物理键盘，虚拟手柄是唯一可行输入
    iOS     = true,
    Windows = false,    -- 有键鼠，玩家不想屏幕上多两个半透明圆
    Linux   = false,
    macOS   = false,
}
```

但**两者都要能在设置菜单里手动开关**——Android 接蓝牙鼠标/手柄的情况真实存在
（`mouse_menu.lua:31` 的注释已写明的理由）。

## Negative Constraints

1. **不得**在 framework 通用层出现任何游戏词汇（`jy.y` 必须住 `script/`）。
2. **不得**内置 `move` / `aim` 等玩法语义向量（见 ADR-4）。
3. **不得**把连续量塞进事件队列（见 ADR-5）。
4. **不得**改动现有玩法：地图仍一次一格，战斗仍回合制。
5. **不得**在迁移期同时删除 VK 常量与 `getKey()`（见 ADR-8）。
6. **不得**在没有 VR 渲染管线前实现 VR 输入分支（见 ADR-7）。
7. **不得**让 `framework/virtual_pad.lua` 直接调用 `love.*`
   （绘制必须经 `EngineAPI.render`）。
8. **不得**照抄 `MobileControlsLibrary` 的触摸 API（它在 11.5 上是坏的）。

## SPECULATIVE 标记

`getVector` / `getAxis` / `ui.cursor` 当前的消费方情况：

| 接口 | 当前消费方 | 标记 |
|---|---|---|
| `getAxis(name)` | 摇杆派生离散事件（需要读轴） | ✅ 有消费方 |
| `getVector("ui.cursor")` | 菜单光标（**尚不存在**，菜单仍用 `ui.up` 等） | ⚠️ SPECULATIVE |
| `getVector(游戏自定义)` | 无（金庸无 Hades 式战斗） | ⚠️ SPECULATIVE |

**若 3 个月内没有 Hades 式实时移动或摇杆菜单光标的实现**，应重新评估是否保留
`defineVector` / `getVector`，或至少把 `ui.cursor` 的实现延后。理由：没有验证路径
的抽象会悄悄腐烂——它会通过所有测试，却从未被真实使用过。

## Review Checklist

- [ ] framework 通用层零游戏词汇（grep `jy\.` 只在 `script/`）
- [ ] 9 个 `ui.*` 动作常量集中在单一文件
- [ ] 事件结构统一（一张表，不是一个形状 per source）
- [ ] `getAxis` 的 6 个轴名与 SDL/Godot/Unreal 闭集一致
- [ ] `defineVector` 支持单轴（y 省略）
- [ ] 事件队列与向量读取互不影响（压测：模拟量每帧读、队列不溢出）
- [ ] 迟滞（0.35/0.25）可测：摇杆 0.30 抖动不产生事件
- [ ] `synthetic` 字段已删除，`getKey()` 按 source 过滤
- [ ] 虚拟手柄不直接调用 `love.*`
- [ ] 虚拟手柄触摸用 `getTouches()`/`getPosition(id)`（11.5 正确 API）
- [ ] 迁移前后行为逐帧等价（36 处调用点）
- [ ] Android 默认开、桌面默认关，且可手动开关
- [ ] Lua 5.1 / 5.3 / 5.4 / 5.5 全绿
- [ ] LÖVE 11.5 启动正常
