---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

本 slice 修复 framework 的**层次倒置**：framework 目前反向依赖 `game/script/` 层。

### 现状证据（实测）

framework 里调用**游戏脚本层**定义的全局函数，共 **140 处**：

```
DrawString    28 处    ShowScreen   11 处    ShowMenu     8 处
Cls           28 处    DrawBox       8 处    WaitKey     11 处
DrawStrBox    10 处    TalkEx        3 处    GetMyPic    13 处
DrawStrBoxYesNo 1 处   ShowMenu2     3 处    SceneCanPass 2 处
DrawStrBoxWaitKey 1 处 PlayMIDI      6 处    AddMyCurrentPic 4 处
PlayMPEG      1 处    FillColor     1 处    DrawRect    1 处
```

这些函数定义在 `game/script/jymain.lua:2094-2994`。

依赖方向是 **framework → script → EngineAPI**，而设计意图是
**framework → EngineAPI**。

**后果**：接新引擎时不仅要实现 EngineAPI，还要把 `jymain.lua` 这 2000 行
一起搬过去 —— 那就等于移植整个游戏，不是移植引擎。

### 为什么必须独立成 slice

1. **140 处改动是最大回归风险点**。与 slice 1 的 237 处机械替换不同，
   这里涉及**语义**（`DrawStrBox` 是"画带框的字"、`ShowMenu` 是"开菜单"），
   需要逐个确认语义等价，不能机械替换。
2. **必须等 slice 1 完成**。facade 内部要调 `EngineAPI.render.*`，
   而 `render.getWidth/getHeight/setClip` 等契约是 slice 1 补的。

### 为什么是"facade"而不是"删除全局函数"

`game/script/jymain.lua` 的 `DrawString` 等函数**游戏脚本自己也在用**
（1000+ 处）。删掉会破坏 script 层。

正确做法是**双向适配**：

```
game/script/jymain.lua 的 DrawString  →  薄包装，转发给 render_facade
game/framework/*.lua 的调用           →  直接调 render_facade
```

这样 script 层行为零变化，framework 不再依赖 script 定义。

## Parent Context

- Epic: `openspec/epics/2026-11-engine-portability/epic.md`
- Slice: 本文件即 slice 2
- 依赖: `port-slice1-contract-completeness`（需要完整契约）
- 被依赖: 无

## What Changes

1. **新建 `framework/render_facade.lua`**：
   - `RenderFacade.text(x, y, str, color, size)` → `EngineAPI.render.text`
   - `RenderFacade.fillRect / rectOutline / setClip / present` → 直接转发
   - `RenderFacade.clearScreen(x1,y1,x2,y2)` → 替代 `Cls`
   - `RenderFacade.drawBox(x1,y1,x2,y2,color)` → 替代 `DrawBox`
   - `RenderFacade.drawString(x,y,str,color,size)` → 替代 `DrawString`
   - `RenderFacade.drawStrBox(x,y,str,color,size)` → 替代 `DrawStrBox`（带框）
   - `RenderFacade.drawBackground(...)` → `EngineAPI.render.drawBackground`
   - `RenderFacade.present()` → 替代 `ShowScreen`
2. **新建 `framework/flow_facade.lua`**（语义层转发，避免 framework 依赖 script）：
   - `FlowFacade.showMenu(...)` → `menu_async.ShowMenuCoroutine`（既有 framework 模块）
   - `FlowFacade.waitKey()` → `input_async.WaitKey`
   - `FlowFacade.talkEx(...)` → `talk_async.TalkEx`
   - `FlowFacade.drawStrBoxWaitKey(...)` → `async_message_box`
   - `FlowFacade.drawStrBoxYesNo(...)` → `async_message_box`
3. **framework 里 140 处调用改为 facade**
4. **`game/script/jymain.lua` 的 8 个全局函数改为 facade 薄包装**
   （script 层调用点零改动，行为零变化）
5. **`GetMyPic` / `AddMyCurrentPic` / `SceneCanPass` 的处理**：
   这 3 个是**纯游戏逻辑**（不是绘制/流程），不属于 facade 范畴。
   framework 不应调用它们 → 需要把调用点下沉到 script，或改由注入式回调。
   （这是本 slice 最需要设计判断的部分，见 ADR-PORT-010）

## Scope Boundaries

### In Scope

- 新建 `framework/render_facade.lua` 与 `framework/flow_facade.lua`
- framework 里 140 处调用改写
- `game/script/jymain.lua` 的 8 个全局函数改薄包装
- `GetMyPic` / `AddMyCurrentPic` / `SceneCanPass` 的 24 处调用的归宿设计
- 全部既有测试零回归

### Out of Scope

- EngineAPI 契约补齐 → slice 1
- sprite 动画 → slice 3
- 绘制性能优化（facade 是纯转发，无逻辑）
- 删除 script 层的全局函数（游戏脚本仍要用）

## Requirements

### REQ-PORT2-1 framework 不得调用 script 定义的全局

`game/framework/*.lua` 里不得出现对 `DrawString`/`Cls`/`ShowScreen`/`DrawBox`/
`DrawStrBox`/`ShowMenu`/`WaitKey`/`TalkEx` 等 script 全局函数的直接调用。

**验收**：`grep -rhoE '\b(DrawString|Cls|ShowScreen|...)\(' game/framework/*.lua` = 0。

### REQ-PORT2-2 facade 只转发，不含逻辑

`render_facade.lua` / `flow_facade.lua` 的每个函数必须是对 `EngineAPI.*`
或既有 framework 模块的**直接转发**，不得包含业务逻辑、不得读写 `JY`。

**验收**：facade 文件里 `JY\.` / `WAR\.` 命中数 = 0。

### REQ-PORT2-3 script 层行为零变化

`game/script/jymain.lua` 的 8 个全局函数签名不变、行为不变。
script 层 1000+ 处调用点零改动。

**验收**：全部既有测试零回归（基线 3310+slice1 的新增）。

### REQ-PORT2-4 游戏逻辑回调走注入而非硬依赖

`GetMyPic` / `AddMyCurrentPic` / `SceneCanPass` 属于游戏逻辑，framework 不应硬依赖。
改为**注入式**：由 `jymain_adapter` 在启动时把函数注册到
`framework/game_hooks.lua`，framework 通过 hooks 调用。

**验收**：framework 里 `GetMyPic(` / `AddMyCurrentPic(` / `SceneCanPass(` = 0。

### REQ-PORT2-5 零回归

**验收**：四版本全量测试，失败 0，断言数只增不减。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（script 层签名不变）
- 现有功能回归风险：**高**（140 处语义性改动，是本 epic 风险最高的一段）
- 缓解：
  - 按模块分批（绘制类 / 菜单类 / 对话类 / 钩子类），每批跑全量测试
  - 每批一个 commit，便于 bisect
  - 每批改动后实机冒烟（菜单、对话、地图、战斗各跑一次）

## 关键设计决策（详见子 change 的 design.md）

| ADR | 决策 |
|-----|------|
| ADR-PORT-008 | 用 facade 而非删除全局函数（script 层 1000+ 调用点零改动） |
| ADR-PORT-009 | `DrawStrBox` 等语义函数归 facade，但要保留 `TextBoxLayout` 的排版算法 |
| ADR-PORT-010 | 游戏逻辑（`GetMyPic`/`SceneCanPass`）走**注入式 hooks**，framework 不硬依赖 |
| ADR-PORT-011 | facade 拆两个文件：`render_facade`（绘制）/ `flow_facade`（流程），避免单文件膨胀 |
| ADR-PORT-012 | 分批改 + 每批全量测试 + 每批实机冒烟（140 处改动不允许一次性提交） |
