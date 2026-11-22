---
status: active
created: 2026-11-22
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`engine-portability` slice 的 14 个 change 全部完成后，底层已经引擎无关：

```
framework 里 love.* 直接调用      0 处
framework 里 require engine-*     0 处
framework 里 lib.*                0 处
56 个 framework 模块在「无 love / 无 lib」下 require 成功
map_render / sprite_atlas / cloud_layer / status_page / MenuAsync 五条主链实跑通过
```

**但还差最后一公里：启动姿势没有契约化。**

`engine_api.lua` 声明了 90 个函数，其中**没有一个**是 `load / update / draw / quit`。
「引擎实现好契约之后怎么把游戏跑起来」这 147 行的知识只存在于
`game/main.lua` 的 `love.load()` 里，并且还依赖三条**没有写下来的隐式约定**：

1. 5 个裸名 `require` 别名（`require "lib_file"` 等），注册代码在
   `engine-love2d/engine_love2d.lua:9-22` —— 换引擎就要重新发现
2. 3 个初始化全局（`CONFIG` / `CC` / `Byte`）
3. `EngineAPI.init()` —— 4 个引擎里 3 个实现了，但契约里搜不到

实测证据：模拟一个「Godot 宿主」（只 `require framework.config` +
`EventBridge:init` + `require script.jymain`），**第一次就死在
`module 'lib_file' not found`**；补齐别名后才跑通。

另有两个具体坑：

- **dt 单位没写**：LÖVE / Godot / Unreal 都用秒，但契约里连一个 `dt` 都没有
- **绘制时机没写**：本抽象层是**立即模式**（每帧全量重画）。Godot 的
  `draw_string()` 在 `_draw()` 之外调用**不报错、不警告、只是什么都不画** ——
  若宿主忘了这对边界，表现是「逻辑在跑但屏幕全黑」，极难定位

## Parent Context

- Slice: `openspec/changes/archive/2026-11-22-engine-portability/`（14/14 已完成）
- 前序 change: `port-compat-layer-removal` / `port-legacy-picture-removal` /
  `port-audio-semantics` / `port-ui-screens-verification`（均已归档）
- 依赖: none（本 change 只加契约与装配，不改游戏逻辑）

## What Changes

1. **新增 4 个契约**（90 → 94）：
   - `app.install(runtime)` —— 唯一必须实现的「启动」契约
   - `app.requestQuit()` —— 宿主退出钩子
   - `render.beginFrame()` / `render.endFrame()` —— 成对的绘制边界
     （替代容易传反的 `setDrawLoopFlag(boolean)`，后者标 `@deprecated` 并保留转发）
2. **新增 `game/framework/boot.lua`**：把 147 行装配序列搬进 framework。
   `Boot.install / update / draw / quit / requestQuit` 五个入口。
   `Boot.draw` 用 `pcall` 保证「出错也一定 endFrame」（否则绘制状态跨帧泄漏）。
3. **`game/main.lua` 变薄**：从「自己装配」变成只转发 4 个 `Boot` 调用，
   保留截图（`--shot`）与自动按键（`--keys`）两个调试设施。
4. **`game/framework/require_aliases.lua`（新）**：5 个裸名别名的唯一来源，
   从 LÖVE 引擎实现里提出来（`engine_mud` 此前根本没有，等于跑不了 script 层）。
5. **`engine_api.lua` 头注释加「新引擎实现清单」**：4 件事 + 6 步启动 +
   每帧 3 个调用 + dt 单位 + 绘制时机约束。
6. **修 4 处主路径的 stdlib 依赖**（其余 25 处是「EngineAPI 优先 + io/os 兜底」）：
   - `mod_ini.lua` 的 `io.open`（MOD ini 解析）
   - `jymain_adapter.lua` 的 `os.time()`（randomseed）
   - `game_states.lua` 的 `os.date`（存档时间戳）
   - `lib_log.lua` 的 `os.date`（日志时间戳）

## Out of Scope

- **740 处 `JY` / `WAR` / `CC` 读写**：这是 frameowrk 与 script 的分层问题，
  与本 change 的「换引擎」目标无关（`JY` 等都是纯 Lua table，换引擎照样跑）。
  它是可维护性债，不是可移植性债。
- **保留模式（retained mode）适配**：本抽象层是立即模式。Godot 的
  `CanvasItem._draw()` 与 Unreal 的 `AHUD::DrawHUD()` 都是立即模式，
  可直接映射，无需节点树中间层。
- **真正的 Godot / Unreal 引擎实现**：本 change 只把「做这件事需要知道什么」
  写下来并验证「最小第三引擎宿主能跑」，不写具体引擎。

## Impact

- Affected specs: `engine-boot`（新建）
- Affected code:
  - `game/engine-love2d/engine_api.lua`（契约 + 头注释清单）
  - `game/engine-love2d/engine_love2d.lua`
  - `game/engine-mud/engine_mud.lua`
  - `game/engine-web/engine_web.lua`、`game/engine-web/web_game_bridge.lua`
  - `game/tests/engine_test.lua`
  - `game/framework/boot.lua`（新）
  - `game/framework/require_aliases.lua`（新）
  - `game/framework/mod_ini.lua`、`jymain_adapter.lua`、`game_states.lua`、`lib_log.lua`
  - `game/main.lua`
  - `game/tests/unit/test_boot.lua`（新）、`test_engine_api.lua`、`test_runner.lua`
  - `game/tests/gate_engine_contract.sh`
  - `docs/screenshots/README.md`（修正 save-menu 的判据分类）
