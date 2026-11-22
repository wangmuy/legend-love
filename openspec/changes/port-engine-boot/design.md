---
status: active
created: 2026-11-22
---
# Design: port-engine-boot

## ADR-PORT-030：启动装配必须是契约，而不是入口程序的私有知识

### Context

`engine_api.lua` 有 90 个函数，覆盖 15 个模块，但**没有一个**描述
「怎么启动」。启动序列（147 行）住 `game/main.lua` 的 `love.load()` 里：

```lua
require "framework.config"
Byte = require "framework.lib_Byte"
require "engine-love2d.lib_love"
local engineAPI = require "engine-love2d.engine_love2d"
engineAPI.init()
EventBridge.getInstance():init()
require(CONFIG.ScriptPath .. "jymain")
JYMainAdapter.init()
```

外加三条隐式约定（别名 / 全局 / `init`）。实测：模拟 Godot 宿主时
第一次就死在 `module 'lib_file' not found`。

### Decision

**把装配序列搬进 `framework/boot.lua`，并用 `EngineAPI.app.install(runtime)`
作为唯一启动契约。**

`runtime` 参数装的是**宿主能力**（退出、错误上报、全屏、资源根），
不是引擎契约的一部分 —— 因为「怎么退出一个应用」在 LÖVE 是
`love.event.quit()`、Godot 是 `get_tree().quit()`、Unreal 是
`UKismetSystemLibrary::QuitGame`。这些差异不该变成 90 个契约里的新条目。

未提供的钩子一律降级（记日志、不抛错），于是最小宿主（MUD / 测试桩）
传一个空表就能跑。

### Alternatives

**（A）把启动序列写进文档，不改代码。**
成本最低（半小时），但「文档和代码会漂移」——本项目已经有过多次
「注释说 X，实际是 Y」的回归。且新引擎作者仍要手抄 147 行。

**（B）新增 6 个生命周期契约**（`app.load` / `app.update` / `app.draw` /
`app.keypressed` / `app.mousepressed` / `app.quit`）。
更"正统"，但会让「引擎实现 90 个函数」变成「还要实现一套事件回调」，
且 framework 侧的 `EventBridge` 已经是这层了 —— 重复。

**（C，选中）一个 `app.install(runtime)` + 一个 `framework/boot.lua`。**
契约面只加 4 个（install / requestQuit / beginFrame / endFrame），
装配逻辑集中在一个可测试的模块里。

### Consequences

- ✅ 新引擎入口只需 4 行（install / update / draw / quit）
- ✅ 装配逻辑可单测（`test_boot.lua` 61 条断言）
- ⚠️ `Boot` 是允许调 script 全局的**唯一** framework 模块（它是缝合层）。
  gate STEP F 需要为它开一个**显式**白名单，而不是让它意外漏过
  （这与 `port-ui-screens-verification` 发现的「DoD 靠漏判成立」是同一类风险）。
- ⚠️ `EngineAPI.init()` 仍是隐式契约（4 引擎里 3 个实现）。本 change
  只在清单里注明，不把它升为正式契约 —— 因为那样 4 个引擎都要改，
  收益小于成本，且 `app.install` 已经替调用方调它了。

## ADR-PORT-031：绘制边界用成对契约，不用 boolean 开关

### Context

原来入口这样写：

```lua
EngineAPI.render.setDrawLoopFlag(true)
EventBridge.getInstance():draw()
MenuAsync.draw()
EngineAPI.render.setDrawLoopFlag(false)
```

### Decision

新增 `render.beginFrame()` / `render.endFrame()` 成对契约；
`setDrawLoopFlag` 标 `@deprecated` 并保留（转发到新的两个）。

`Boot.draw` 用 `pcall` 包住中间的绘制，**保证 `endFrame()` 一定被调用**，
但错误不吞 —— 记日志后重新抛出（宿主若提供 `runtime.onError` 则交给它）。

### Alternatives

- 保留 boolean：一个 `false`/`true` 写反就是跨帧的绘制状态泄漏（LÖVE 会
  一直往同一个 Canvas 上画），且不报错。成对 API 让这种错写不出来。
- 不保留 `setDrawLoopFlag`：会破坏 `test_engine_api.lua` 与
  `test_engine_system.lua` 里已有的断言，且外部 MOD 可能用到。

### Consequences

- ✅ 语义自解释（进入/离开）
- ✅ 出错时绘制状态不会泄漏
- ⚠️ 4 个引擎都要实现 2 个新函数（已全部完成）

## ADR-PORT-032：裸名 require 别名的唯一来源在 framework

### Context

`game/script/jymain.lua:15-16` 用 `require "lib_file"` / `require "script_loader"`。
这些裸名靠 `engine_love2d.lua:9-22` 注册的 `package.preload` 别名解析。

### Decision

新建 `game/framework/require_aliases.lua` 作为**唯一来源**，
require 时自动 install（幂等）。4 个引擎（LÖVE / MUD / Web / 测试桩）
都 require 它。

### Alternatives

- **改 script 层用全名**（`require "framework.lib_file"`）：最干净，但要动
  `script/jymain.lua`，且 MOD 可能覆盖 script 文件 —— 风险大于收益。
- **每个引擎抄一份**：就是现状，已经被证明会漏（MUD 根本没有任何别名注册）。

### Consequences

- ✅ 换引擎不用重新发现这条约定
- ✅ web 的 `web_game_bridge.lua` 也统一到同一份清单
- ⚠️ gate 需要断言「`engine_api.lua` 里有新引擎清单字样」，防止文档被误删

## ADR-PORT-033：4 处主路径 stdlib 依赖的处置

### Context

`framework` 里 29 处 `io.*` / `os.*`，但**只有 4 处是主路径**
（其余 25 处都是「EngineAPI 优先 + stdlib 兜底」，契约实现后兜底分支永不执行）。

### Decision

| 位置 | 处置 |
|---|---|
| `mod_ini.lua:23` `io.open` | 优先 `EngineAPI.file.read`，兜底 io.open |
| `jymain_adapter.lua:183` `os.time()` | 优先 `EngineAPI.time.getTimeSeconds`，兜底 os.time |
| `game_states.lua:1006` `os.date` | 走 `framework/clock.lua` 封装（不自算） |
| `lib_log.lua:22` `os.date` | 同上，且**降级为无时间戳**而不是崩 |

**不新增 `time.formatNow` 契约**：本项目刚做完一轮 dead contract 清理
（`port-contract-pruning` 删了 3 个），加契约要谨慎。存档/日志的时间戳
不是引擎特性。

### Consequences

- ✅ Godot/Unreal 的 Lua 沙箱（通常禁 `io`）也能跑
- ✅ 兜底保留 → 纯 Lua 测试环境不受影响
- ⚠️ `fs_compat.lua` 的 18 处 io.popen **不在此列**（它自己声明「仅测试/工具用」）
