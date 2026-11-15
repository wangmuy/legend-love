---
status: active
created: 2026-11
parent_epic: 2026-11-mouse-input
parent_slice: mouse-slice1-engine-capability
---
# Design: engine-capability

> 每个关键判断记作 ADR。所有实测数据来自本机（Windows 150% 缩放，LÖVE 11.5）。

## ADR-MS-001 平台检测走 `EngineAPI.system.getOS()`，不散落在各处

**Context**

需求要求「桌面版鼠标默认开，Android 默认关」。而当前全仓：

```
grep "platform" / "getOS" / "love.system"  → 0 处
conf.lua: t.modules.system = true（模块已启用，但从未使用）
```

没有任何平台检测能力。如果为鼠标开关单独写一段 `love.system.getOS()` 判断，
它会落在 `framework/` 里 —— 违反「framework 只通过 EngineAPI 调引擎」的既有约定。

**Decision**

新增 `EngineAPI.system` 模块（EngineAPI 的第 15 个模块）：

```lua
EngineAPI.system.getOS()
    --> "Windows" | "Linux" | "macOS" | "Android" | "iOS" | "web" | "unknown"
```

三引擎实现：

| 引擎 | 实现 | 说明 |
|------|------|------|
| love2d | `love.system.getOS()` | `conf.lua` 已启用 `t.modules.system` |
| mud | `"unknown"` | 无平台概念 |
| web | `"web"` | **硬编码，不调 `love.system`** |
| test | 可注入（`EngineAPI.system._os`） | 便于测试各平台分支 |

**为什么 web 要硬编码**：LÖVE 的 web 构建（Emscripten）下
`love.system.getOS()` 理论上返回 `"Linux"`。若透传，`platformDefaults.Linux = true`
会让 web 端误以为有鼠标。硬编码返回 `"web"` 才能让 `platformDefaults` 正确
落到 `default = false`。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 各调用点直接 `love.system.getOS()` | framework 依赖具体引擎，违反既有分层 |
| 用 `package.config` 的路径分隔符推断 | 只能区分 Windows/POSIX，无法区分 Android/macOS/Linux |
| 用 `os.getenv("OSTYPE")` 等环境变量 | 不跨平台，Android/web 上不存在 |
| 不区分平台，一律默认 `true` | Android 上默认开鼠标会让虚拟按键与鼠标冲突 |

**Consequences**

- EngineAPI 模块数 14 → 15，函数数 51 → 54（本 ADR 贡献 1 个）
- `AGENTS.md` / `SRC_FILES.md` / `ENGINE_API_DESIGN.md` 需同步更新
- 未来任何「平台差异化默认值」都能复用这一个接口（如虚拟按键默认开）

---

## ADR-MS-002 鼠标坐标契约 = 「逻辑坐标」，DPI 在引擎内部消化

**Context**

`conf.lua` 同时开启了两个 DPI 相关选项：

```lua
t.window.highdpi = true
t.window.usedpiscale = true
```

LÖVE 11.x 的语义是：开启后 `love.graphics.*` 用逻辑（密度独立）坐标，
但 `love.mouse.getPosition()` 返回什么需要实测。

若两者不在同一空间，所有点击测试都会偏移 —— 且**很难从现象反推原因**
（表现是「点击偏了几个像素到几十个像素」）。

**Decision**

API 契约写死为「返回逻辑坐标」，与 `DrawString` / `DrawRect` 同一空间：

```lua
--- 获取鼠标位置
--- @return number x, y  【逻辑坐标】与 DrawString/DrawRect 同一坐标空间
---
--- 契约：引擎负责把物理/DPI 缩放坐标换算到该空间，调用方无需感知 DPI。
---   实测（Windows 150%，LÖVE 11.5）：love.mouse.getPosition() 已是逻辑坐标，
---   故 love2d 实现无需换算。
---   mud/web 返回 -1,-1（无鼠标）。
function M.input.mousePosition() end
```

**实测证据（Windows 150% 缩放）**

```
物理分辨率（Win32_VideoController）   = 3840 × 2160
LÖVE getDesktopDimensions()          = 2560 × 1440
                              3840/2560 = 1.5  → 确认系统 150%

窗口逻辑尺寸                          = 1024 × 768
love.graphics.getDimensions()        = 1024 × 768

setPosition(1023, 767) → getPosition 返回 (1023, 767)   比值 1.000
setPosition( 100,  80) → getPosition 返回 ( 100,  80)   比值 1.000
setPosition 后立即读取，1:1 精确对应
```

**结论**：love2d 的实现就是 `return love.mouse.getPosition()`，零换算。

**未验证**：macOS Retina、Android。若实测发现返回物理像素，
则在该引擎实现里加 `love.window.toDensity()` 换算 —— **契约不变**，
slice 2 / slice 3 完全不受影响。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 返回物理像素，让调用方自己换算 | framework 需要知道 DPI 概念，引擎依赖泄漏 |
| 额外提供 `input.getDPIScale()` | 多一个接口，且把换算责任推给每个调用方 |
| 关闭 `usedpiscale` 回避问题 | 会让高分屏下字体/图形变小，是既有体验退化 |
| 关闭 `highdpi` | 同上，且影响已发布的渲染行为 |

**Consequences**

- `EngineAPI.input` 加 1 个函数（51 → 52）
- slice 2 / slice 3 的坐标计算**完全不需要 DPI 概念**
- 若未来支持多显示器不同 DPI，契约仍然成立（引擎返回当前窗口的逻辑坐标）

---

## ADR-MS-003 `drawTinted` 支持任意 spriteId + `{r,g,b}`，而非扩展位域 flag

**Context**

现有绘制接口的「染色」能力只有两档，通过位域 `flag` 表达：

```lua
-- lib_love.lua:550-558  PicLoadCache
local hasAlpha = bit32.band(flag, 0x2) ~= 0  -- bit1: alpha 混合
local isBlack  = bit32.band(flag, 0x4) ~= 0  -- bit2: 全黑
local isWhite  = bit32.band(flag, 0x8) ~= 0  -- bit3: 全白
if isBlack then r,g,b = 0,0,0
elseif isWhite then r,g,b = 1,1,1 end
```

只有「原色 / 全黑 / 全白」。需求要求「寻路失败闪红色」，
**当前无法表达**。

**Decision**

新增 `EngineAPI.sprite.drawTinted`，用 `{r, g, b}` 而不是位域：

```lua
EngineAPI.sprite.drawTinted(archiveId, spriteId, x, y, color, alpha)
-- color = { r = 1, g = 0, b = 0 }   0-1 浮点
-- alpha = 0-255                     与既有 PicLoadCache 的 alpha 语义一致
```

**为什么是通用函数而不是「加一个红色 flag」**

一个函数覆盖多类用例：

| 用例 | 参数 |
|------|------|
| 鼠标悬停格高亮 | `(0, 0, x, y, {0,0,0}, 64)` |
| 寻路失败红闪 | `(0, 0, x, y, {1,0,0}, 180)` |
| 未来：物品金色高亮 | `(0, N, x, y, {1,0.84,0}, 128)` |
| 未来：敌人红色标记 | `(0, 0, x, y, {1,0,0}, 128)` |

`spriteId` 可变意味着**不只用于菱形** —— 任意精灵都能染色。

**为什么不用位域扩展**

```
  flag 是「原版 PAL 引擎的约定」，0x2/0x4/0x8 的语义与原版一致。
  加 0x10 = 红 会污染这个隐性契约（未来更多颜色要继续加位）。
  且位域无法表达任意 RGB —— 只有 8 种颜色组合可用。
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 扩展 flag 位（0x10 = 红） | 位域只能表达有限颜色；污染原版语义契约 |
| 新增 `render.tintRect` 画矩形 | 丢掉菱形形状（战斗的菱形是现成资源，见 epic 约束 3） |
| 用 shader 做染色 | 需 `love.graphics.newShader`，Android/老设备兼容性不确定；收益为负 |
| 让调用方自己组合 setColor + draw | framework 直接调 `love.*`，违反分层 |

**Consequences**

- `EngineAPI.sprite` 从 4 个函数变 5 个（52 → 53）
- love2d 的实现是 `PicLoadCache` 的一个变体（颜色不写死）
- **风险**：`love.graphics.setColor` 是乘算染色，对**纯白**精灵效果最准；
  若 picid 0 的菱形本身带颜色，染色结果会偏离预期。需实机确认。
  若效果不可接受，改用 shader（但那会推翻本条 ADR）

---

## ADR-MS-004 鼠标事件走独立队列，不与键盘混队

**Context**

`input_manager.lua` 现有单一环形队列，事件形状是：

```lua
{ type = "pressed" | "repeat", key = gameKey, time = ... }
```

`getKey()` 从队列取出并返回 `event.key`（数字键码）。

鼠标事件若混入同一队列，有两个问题：

```
① getKey() 会把鼠标事件当按键返回
   鼠标事件没有 key 字段 → 返回 nil 或 x 坐标
   → 所有 20+ 处 lib.GetKey() 调用点都可能被污染

② 鼠标按下是【状态】不是【事件】
   love.mouse.isDown(1) 按住期间每帧都 true
   必须在 love.mousepressed 回调里入队，否则会重复触发
```

**Decision**

两条独立队列：

```lua
enqueueKeyEvent(event)      -- 现有，语义不变
getKey()                    -- 现有，只消费键队列

enqueueMouseEvent(event)    -- 新增
getMouseEvent()             -- 新增，只消费鼠标队列
```

鼠标事件形状：

```lua
{ type = "pressed", x = 512, y = 384, button = 1, time = ... }
{ type = "released", x = 512, y = 384, button = 1, time = ... }
```

**明确不做跨队列的严格时序保证**：实际游戏中不会出现「同一帧内既按键又点击」
且顺序有意义的场景。若将来需要，再引入统一序列号。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 混入同一队列 + `getKey()` 跳过鼠标事件 | 要改所有 20+ 处调用点的语义判断；风险全在既有功能上 |
| 不做队列，直接轮询 `love.mouse.isDown` | 一次点击会触发几十次（状态不是事件） |
| 边沿检测（`down and not prevDown`） | 可行但散落在每个消费点；入队只需在回调里做一次 |

**Consequences**

- `input_manager.lua` 约 +50 行（队列结构与现有键队列对称）
- 现有键盘路径**零改动**
- slice 2 消费鼠标事件时用 `getMouseEvent()`，与键盘消费模式完全对称

---

## ADR-MS-005 `settings.lua` 的平台层用注入，不 require 引擎

**Context**

`audio-settings` 建立的 `settings.lua` 有硬性约束（写入其 DoD）：

```
grep -E "EngineAPI|love\.|CC\.|JY\." game/framework/settings.lua  → 必须为空
```

现在需要「桌面默认开、Android 默认关」。朴素做法是在 `settings.lua` 里
`require EngineAPI` 并在 `define` 时读 `EngineAPI.system.getOS()` —— 
**这会破坏上述约束**。

**Decision**

第四层用**注入**，与既有 `Settings.setStore()` 是同一套思路：

```lua
-- settings.lua 只认一个字符串平台名
Settings.setPlatform("Windows")

-- define 时声明各平台默认值
Settings.define("input.mouse", {
    default = false,           -- 未知平台的兜底
    type    = "bool",
    platformDefaults = {
        Windows = true, Linux = true, macOS = true,
        Android = false, iOS = false,
    },
})
```

解析顺序：

```
  user 层有？ → 用它
  否则 mod 层有？ → 用它
  否则 platformDefaults[当前平台] 有？ → 用它      ← 新增
  否则 default
```

宿主（`jymain_adapter.lua`）在初始化时注入：

```lua
Settings.setPlatform(EngineAPI.system.getOS())
```

**这样做保住了什么**

```
  settings.lua 仍然零引擎依赖（grep 为空）✓
  平台名是一个字符串，不是引擎对象        ✓
  测试可以注入任意平台名                  ✓
  将来 mud/web 引擎也能用同一套机制        ✓
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| `settings.lua` 直接 `require EngineAPI` | 破坏其零引擎依赖的 DoD |
| 平台默认值写在 `jymain_adapter` 里（读 platform 后手动 set user 层） | 会把「默认值」混进「用户选择」，`settings.ini` 里会凭空出现用户没设过的值 |
| 用 `Settings.define` 在宿主处按平台算 default | 可行但每次加设置都要在宿主写分支逻辑；platformDefaults 是数据驱动的 |

**Consequences**

- `settings.lua` 约 +40 行（platform 层解析 + setPlatform）
- `jymain_adapter.lua` 初始化时多一行 `Settings.setPlatform(...)`
- 测试可 `Settings.setPlatform("Android")` 验证默认值分支
- **副作用**：`Settings.save()` 只写 user 层，platform 层与 default 层不落盘 —— 
  这是正确的（platform 默认不是用户选择）

---

## ADR-MS-006 文档计数同步作为 DoD，而非「以后再说」

**Context**

EngineAPI 的模块/函数计数散落在三个文档里，且**已经过时**：

```
  AGENTS.md              "覆盖 12 个模块"          ← 实际 14 个
  ENGINE_API_DESIGN.md   "全部 51 个函数"
  SRC_FILES.md           "EngineAPI 计数 51 → 14 模块"  ← 这是上次修 Lua 5.5 时改的
```

本 change 会再加 1 模块 + 4 函数，若不改文档，偏差继续扩大。

**Decision**

把文档同步写进 DoD（可机器验证）：

```
  grep "12 个模块" AGENTS.md           → 应为空
  grep "51" ENGINE_API_DESIGN.md       → 应为空（或上下文不同）
  grep "55" SRC_FILES.md               → 应命中
```

**为什么值得单列**：这类「文档滞后」不影响功能，所以永远排不上优先级，
但会让后来者（人或 AI）按错误数字判断架构复杂度。上一轮修 Lua 5.5 时
已经踩过一次（发现 37→51 偏差）。**用 DoD 强制同步，成本几分钟。**

**Consequences**

- 三个文档各改 1-3 处数字
- tasks.md 里有一条 grep 可验证的 DoD
