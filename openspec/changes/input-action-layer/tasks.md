---
status: active
created: 2026-11-17
---
# Tasks: input-action-layer

## Blast Radius

**新增**
```
game/framework/input_actions.lua       动作常量（10 个 ui.*）
game/framework/input_bindings.lua      绑定表 + defineVector/getVector
game/framework/virtual_pad.lua         虚拟手柄（逻辑/绘制分离）
game/script/input_actions.lua          游戏私有动作（jy.y / jy.n）
game/tests/unit/test_input_actions.lua      动作常量 + 事件结构
game/tests/unit/test_input_bindings.lua     绑定 + 向量 + 迟滞
game/tests/unit/test_virtual_pad.lua        虚拟手柄（无 love.*）
game/tests/gate_input_actions.sh             门禁（7 组断言 + 负向对照）
```

**修改**
```
game/framework/input_manager.lua       动作队列 + provenance + 删除 synthetic
game/framework/input_async.lua         WaitAction 等
game/engine-love2d/engine_api.lua      input 模块 5 → 9 函数（接口定义）
game/engine-love2d/engine_love2d.lua   4 个新函数实现（LÖVE）
game/engine-mud/engine_mud.lua         capabilities 全 false（MUD）
game/engine-web/engine_web.lua         capabilities 全 false（Web）
game/tests/engine_test.lua             测试引擎：4 个新函数 + logCall
game/conf.lua                          t.modules.joystick = true
game/framework/jymain_adapter.lua      pollMouse/pollHover 改用动作
game/framework/battle_mouse.lua        enqueueKeyEvent → enqueueAction
game/framework/mouse_menu.lua          （不变，仅确认平台默认值模式可复用）
game/framework/settings.lua            （不变，platformDefaults 已支持）
game/tests/test_runner.lua             注册 3 个新套件
```

**36 处 VK 比较逐个迁移**（按文件分批，见 Task 5）

**禁止触碰**
```
game/script/oldevent/          （1018 个事件脚本，与输入无关）
game/tools/mod_build.lua       （MOD 构建）
game/sound/、game/mods/        （上一个 change 的产物）
tools/render-base-music.sh     （音频）
```

## Task 1 — 动作常量与事件结构（零行为变化）

- [x] 新建 `framework/input_actions.lua`：
  - 10 个 `ui.*` 常量（`up down left right accept cancel menu text backspace cursor`）
  - `InputActions.normalizeName(s)`：宽松匹配（`"SPACE"` → `"ui.accept"`）
  - `InputActions.isFrameworkAction(name)`：判断是否 `ui.` 前缀
- [x] `input_manager.lua` 加 `actionQueue`：
  - 事件结构 `{action, source, value, char, position, index, ray, time}`
  - `getAction()` / `peekAction()` / `enqueueAction(ev)`
  - 容量仍 64，与键队列同策略
- [x] **不删** `getKey()` / VK 常量 / `baseKeyMap`

**DoD**：全量测试 3022/3021 通过，`getAction()` 与 `getKey()` 并存。

## Task 2 — EngineAPI 扩 4 函数

- [x] `engine_api.lua`：input 从 5 → 9 函数（带完整文档注释）
  - `getAxis(name)` — 6 个闭集轴名，非法名返回 0
  - `getCapabilities()` — `{pointer, touch, gamepad, vr}`
  - `getPointerPosition()` — 明确「每帧状态查询」，MUD 返回 -1,-1
  - `pollAction()` — 返回动作名或 nil
- [x] `engine_love2d.lua` 实现四者：
  - `getAxis`：`love.joystick.getJoysticks()[1]:getGamepadAxis(name)`
  - `getCapabilities`：`{pointer=true, touch=true, gamepad=true, vr=false}`
  - `getPointerPosition`：委托 `lib.mousePosition()`
  - `pollAction`：委托 `InputManager.getAction()`
- [x] 补齐**全部 4 个实现**（实测共 4 个，缺一个就会有 nil 函数）：

  | 实现 | 文件 | 这里要做到 |
  |---|---|---|
  | LÖVE | `engine_love2d.lua` | 全部真实现 |
  | MUD  | `engine_mud.lua` | 全 false / 全 0 / 预设队列 |
  | Web  | `engine_web.lua` | pointer=true，其余 false |
  | 测试桩 | `tests/engine_test.lua` | 4 个函数 + `logCall` |

**DoD**：`test_engine_api.lua` 增断言；三引擎都能回答全部 9 个函数。

## Task 3 — 绑定表与向量机制

- [x] 新建 `framework/input_bindings.lua`：
  - `defaultBindings`：key/mouse/pad/touch → 9 个 `ui.*` 动作
    ```
    key:   space,return → ui.accept   escape → ui.cancel
           up,down,left,right → ui.up/down/left/right
           backspace → ui.backspace   任意可打印字符 → ui.text (char)
    mouse: 左键 → ui.accept  右键 → ui.cancel
    pad:   a → ui.accept  b → ui.cancel  start → ui.menu
           dpup/dpdown/dpleft/dpright → ui.up/down/left/right
    touch: 由 virtual_pad 产出（见 Task 6）
    ```
  - `bindAction(source, event, action)` / `unbind`
  - `defineVector(id, spec)` / `getVector(id)` / `listVectors()`
  - 内置唯一向量 `ui.cursor`（左摇杆 → x/y）
  - 迟滞逻辑：`axisToDiscrete(value, pressedThreshold, releasedThreshold)`
  - 模拟量派生的独立重复器（0.3s / 0.04s）
- [x] `script/input_actions.lua`：注册 `jy.y` / `jy.n`（游戏层）

**DoD**：
- `getVector("ui.cursor")` 返回 4 字段
- 框架代码内 grep 不到 `"move"` / `"aim"`
- 迟滞测试：0.30 抖动 10 帧产生 0 事件

## Task 4 — 删除 synthetic，改用 provenance

- [x] `input_manager.lua`：
  - 删 `synthetic` 字段与「跳过 synthetic」逻辑
  - `getKey()` 改为「按 source 过滤」（`source=="mouse"` 的事件不进 `getKey()`）
  - `enqueueKeyEvent(key)` 保留为**兼容 wrapper**，内部转成
    `{action=<从 key 反推>, source="compat"}`
- [x] `jymain_adapter.lua` / `battle_mouse.lua`：`enqueueKeyEvent(VK_SPACE)` →
  `enqueueAction({action="ui.accept", source="mouse"})`

**DoD**：
- grep `synthetic` 在 `framework/` = 0 处
- 「悬停注入 SPACE 冒出店小二对话」的回归测试仍通过

### 附带修复：文本输入三重失效

现状实测（见 proposal 的「问题 4 附带发现」）：

| # | 失效点 | 后果 |
|:-:|---|---|
| 1 | `baseKeyMap` 只映射 9 个键，字母在 `onKeyPressed` 被丢弃 | 打不出字 |
| 2 | `VK_BACKSPACE` **未定义**（`jyconst.lua` 里没有），比较恒 false | 退格静默失效 |
| 3 | 唯一能走通的只有 RETURN | 只能提交空串 |

- [x] 绑定表补 `任意可打印字符 → ui.text`（不经 `baseKeyMap` 白名单）
- [x] 定义 `ACTION_BACKSPACE = "ui.backspace"` 与 `backspace → ui.backspace` 绑定
- [x] `async_dialog.lua:262-268` 改读 `event.char` / 动作名，不再用 `>=32 and <=126`
- [x] 加回归测试：`a`、`b`、退格 → 输入框内容为 `"a"`

## Task 5 — 36 处 VK 迁移（分批，每批跑全量）

按文件分批，**每批完成后跑全量测试**：

| 批 | 文件 | VK 引用数 |
|:-:|---|---|
| 1 | `framework/game_states.lua` | ~8 |
| 2 | `framework/menu_state_machine.lua` | ~6 |
| 3 | `framework/async_dialog.lua` | ~12（含 `>=32 and <=126` 改 `ui.text`） |
| 4 | `framework/talk_async.lua`、`scene_name_async.lua` | ~4 |
| 5 | `framework/item_async.lua`、`person_status_async.lua` | ~3 |
| 6 | `framework/war_async.lua`、`input_async.lua` | ~3 |
| 7 | `script/jymain.lua` | ~2 |

每批 DoD：该批文件内 VK 引用归零，全量测试通过。

**最终 DoD**：`grep -c 'VK_'` 在 `framework/` + `script/`（除 `jyconst.lua` 定义处）
= 0。

**⚠️ 2026-11-22 复核：本 Task 实际一行未做。**

上面那 7 批**一个 checkbox 都没有** —— 所以它在进度统计里完全不可见
（27/31 全是 Task 1/2/3/6/7/8/9 的）。实测：

```
$ grep -rn 'VK_' game/framework/*.lua game/script/*.lua game/script/battle/*.lua     | grep -v jyconst.lua | wc -l
114
```

分布：`script/jymain.lua` 32、`battle_flow_coroutines.lua` 18、
`game_states.lua` 11、`menu_state_machine.lua` 11、`async_dialog.lua` 11、
`item_async.lua` 6、`battle_flow.lua` 6、`person_status_async.lua` 5、
`jymain_adapter.lua` 5、`battle_action.lua` 4、`input_manager.lua` 2、
`battle_mouse.lua` 2、其余各 1。

按 `VK_*` 常量分类：`VK_ESCAPE` 19、`VK_DOWN` 19、`VK_UP` 18、`VK_RETURN` 18、
`VK_SPACE` 16、`VK_RIGHT` 15、`VK_LEFT` 15、`VK_Y`/`VK_N`/`VK_BACKSPACE` 各 1。
**每个都有对应的语义动作**（`VK_Y→jy.y`、`VK_N→jy.n`、其余 `ui.*`），
所以迁移在技术上没有障碍，纯粹是没做。

- [ ] 批 1 `framework/game_states.lua`（11 处）
- [ ] 批 2 `framework/menu_state_machine.lua`（11 处）
- [ ] 批 3 `framework/async_dialog.lua`（11 处，含 `>=32 and <=126` 改 `ui.text`）
- [ ] 批 4 `framework/talk_async.lua` / `scene_name_async.lua`
- [ ] 批 5 `framework/item_async.lua` / `person_status_async.lua`（11 处）
- [ ] 批 6 `framework/war_async.lua` / `input_async.lua` / `battle_mouse.lua`
- [ ] 批 7 `script/jymain.lua`（32 处）+ `script/battle/`（28 处）
- [ ] 最终 DoD：上述 `grep` 归零
- [ ] `gate_input_actions.sh` 补断言：`framework/`+`script/` 的 VK 引用 = 0
      （**现在只查「VK 是否已定义」，不查「是否已迁移」** —— 所以 114 处不影响门禁）

## Task 6 — 虚拟手柄

- [x] 新建 `framework/virtual_pad.lua`：
  - 布局用锚点 + 边距：`{anchor="bottom-left", ox=100, oy=-150, r=50}`
  - 触摸 ID 归属：一个手指一个按钮（避免拖动串键）
  - `update(touches)` → 产出动作事件（经 `InputBindings`）
  - `draw(EngineAPI)` → 经 `EngineAPI.render` 绘制
  - 平台默认值 `{Android=true, iOS=true, Windows=false, ...}`
- [x] `engine_love2d` 侧：`love.touch.getTouches()` + `getPosition(id)`
  - **不得**用 `getTouchCount()` / `getTouch(i)`（11.5 上不存在）
- [x] 设置项 `input.virtualPad` + 菜单接线（照 `mouse_menu.buildToggleItem()`）
- [x] `conf.lua`：`t.modules.joystick = true`

**DoD**：
- grep `love\.` 在 `framework/virtual_pad.lua` = 0 处
- Android 默认 true、桌面默认 false
- 负向对照：塞入硬编码坐标 → 门禁 FAIL

## Task 7 — 测试套件

- [x] `test_input_actions.lua`：10 个常量、`normalizeName`、`isFrameworkAction`
- [x] `test_input_bindings.lua`：默认绑定、`defineVector` 单轴/双轴、
  迟滞（0.30 抖动 0 事件）、独立重复器、`ui.cursor`
- [x] `test_virtual_pad.lua`：锚点布局、触摸归属、无 `love.*`、
  平台默认值（用 mock 的 `EngineAPI`）
- [x] `test_runner.lua` 注册 3 个套件

**DoD**：三套件全绿；总测试数 ≥ 3022 + 新增。

## Task 8 — 门禁脚本

- [x] `game/tests/gate_input_actions.sh`，7 组断言：
  1. framework 通用层零游戏词汇
  2. framework 不得内置 move/aim
  3. `synthetic` 已清除
  4. `framework/` + `script/` 的 VK 引用已归零
  5. 虚拟手柄不直连 `love.*`
  6. 触摸 API 用 11.5 形态
  7. **业务代码不得引用未定义的 `VK_*`**（遍历 `VK_[A-Z0-9_]*` 与 `jyconst.lua` 比对）

每组都要有负向对照（临时改坏 → 必须 FAIL）。

**DoD**：`sh game/tests/gate_input_actions.sh` 退出码 0。

## Task 9 — 四版本 Lua + LÖVE 回归

- [x] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试
- [x] `luac5.1 -p` / `luac55 -p`
- [x] LÖVE 11.5 启动冒烟
- [x] 用 LÖVE 探针验证 `getTouches()` / `getGamepadAxis()` 真能调用

**DoD**：全部通过，无 SKIP。

## 后续（不在本 change 范围）

- [ ] 物理手柄热插拔与设备枚举（下一 slice）
- [ ] `getVector` 的真实消费方（Hades 式战斗或摇杆菜单光标）
  —— 若 3 个月内无实现，按 design 的 SPECULATIVE 条款重估
- [ ] VR 输入实现（需先有 VR 渲染管线）
- [ ] 归档：`/openspec-archive-change input-action-layer`
