---
status: active
created: 2026-11-22
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`engine-portability` slice 的 14 个 change 全部归档后，做了一次**独立复审计**
（不读 tasks 的 DoD，只看「现在换引擎真的能跑吗」）。结果挖出 **3 个
「断言存在、但检查不到目标」**的既有缺陷：

| # | 缺陷 | 实测证据 |
|---|---|---|
| 1 | `playSequence` 的 number 语义只改了 LÖVE | MUD/Web/测试桩仍是 `playSequence(filenameOrId) → return true` |
| 2 | `mod_data` 还有 2 处真主路径 `io.open` | `readActiveFile` / `WarRecordCount` 无契约兜底 |
| 3 | `test_engine_conformance` 的「引擎完整性」检查**是空转的** | MUD 实缺 7 个契约，该断言照样 PASS |

三者是**同一个模式**：表面上都有检查和文档，但没有一个真正检查到目标。
这不是功能缺陷，是**验证缺陷** —— 比功能缺陷更危险，因为它会让
「看起来完成了」的东西在换引擎时成批暴露。

### 缺陷 1 的细节

`port-audio-semantics` 把契约改成「`playSequence` 只收 number」，
但只改了 LÖVE 一个引擎。另外三个仍是旧形态，且**测试没查**。

危险点：**新引擎作者会抄最简参考实现**，也就是 `engine_mud.lua`（它只有
548 行，是"最小可用引擎"的样板）。于是错误语义会直接传染给 Godot/Unreal。

### 缺陷 2 的细节

`port-engine-boot` Task 6 的 DoD 写「4 处主路径 io/os 收进契约」，但
`mod_data` 里还有 2 处**不是兜底、而是唯一通道**：

- `readActiveFile()` —— 每次启动都调（判断激活哪个 MOD）。
  `.love` 打包 / Android 下 APK 内资源只有 `love.filesystem` 认路径，
  `io.open` **静默失败** → MOD 永远不激活，且不报错。
- `WarRecordCount()` —— 只问文件大小，用 `file.getSize` 根本不需要打开文件。

### 缺陷 3 的细节（最严重）

`testAllEnginesImplementAllContracts` 这样写：

```lua
local ok, mod = pcall(require, e.path)
if mod[d.mod][d.fn] == nil then missing[...] = ... end
```

看起来对。但 `engine_mud.lua` / `tests/engine_test.lua` /
`engine_love2d.lua` 都做 `local EngineAPI = require("engine-love2d.engine_api")`
—— 拿到的是**同一张表**，而 `engine_api.lua` 已为每个契约声明空桩
（`function M.file.read(...) end`）。于是 `mod[d.mod][d.fn]` **永远不是 nil**。

更糟的是空桩返回 nil，等于「调用成功但什么也没干」—— 比报错更难查。

## Parent Context

- Slice: `openspec/changes/archive/2026-11-22-engine-portability/`
  （14/14 已完成并归档）
- 相关 change（均已归档）：
  - `port-audio-semantics`（缺陷 1 的来源）
  - `port-engine-boot`（缺陷 2 的来源）
  - `engine-portability` slice 本身（缺陷 3 的来源）
- 前序 change: 无硬依赖（三个修复都已实测落地，本 change 是**补文档与门禁**）

## What Changes

本 change 把已经落地的三项修复**正式立项归档**，并补上"以后怎么防"：

1. **`playSequence` 语义补到 4 引擎**
   - MUD / Web / 测试桩统一为 `playSequence(id)`：`type(id) ~= "number"` → false；
     `id < 0` → false
   - conformance 改为**源码级**断言（require 后调用抓不到，因为共享表）

2. **`mod_data` 的 2 处主路径 io 收进契约**
   - `readActiveFile` → 优先 `EngineAPI.file.read`
   - `WarRecordCount` → 优先 `EngineAPI.file.getSize`
   - 两处 `io.open` 兜底**保留**（纯 Lua 测试环境）
   - 新增 4 条测试（各一对：契约可用时 io.open 计数为 0 / 无契约时兜底仍工作）

3. **conformance 完整性检查改源码级 + 补齐缺口**
   - 判据从「查 `mod[mod][fn] == nil`」改为「读源码找
     `EngineAPI.x.y = function` 或 `function EngineAPI.x.y(`」
   - 检查范围从 3 引擎扩到 4 引擎（原来漏了 LÖVE）
   - 补 MUD 缺的 7 个契约：`file.read` / `file.write` / `file.lines` /
     `file.openFile` / `file.createDirectory` / `app.quit` / `time.getTimeSeconds`
   - 补测试桩缺的 3 个：`dialog.measure` / `dialog.draw` / `dialog.clear`

4. **同时归档上一轮的两项修复**（同属「复审计发现」）：
   - `GameHooks.getMyPicOr(fallback)`：注入点返回 nil 是合法语义，但直接
     赋给 `JY.MyPic` 会让下游 `mypic * 2` 崩（实测 `test_auto_move:475`）
   - `JY.CurrentD >= 0` 的 nil 守卫补齐（既有代码 2 处写错、只修了 1 处）

## Out of Scope

- **4 引擎共享同一张 `EngineAPI` 表**：这是架构问题（三个引擎都
  `require("engine-love2d.engine_api")`）。生产运行时只加载一个引擎 → 无影响；
  测试环境已通过「源码级断言」规避。改它需要 4 个引擎各自 `{}` 起表，
  收益（测试隔离）小于风险（4 引擎 + 95 契约全改），**明确不做**。
- **`os.clock` 的 9 处**：全是耗时日志 / flush 节流。即使宿主没有 `os.clock`
  也只影响日志，不影响游戏逻辑。不为此扩契约。
- **真正的 Godot / Unreal 引擎实现**：那是下一个 slice 的事。

## Impact

- Affected specs: `engine-conformance`（新建）
- Affected code:
  - `game/engine-mud/engine_mud.lua`（+7 契约、playSequence 语义）
  - `game/engine-web/engine_web.lua`（playSequence 语义）
  - `game/tests/engine_test.lua`（+3 dialog 契约、playSequence 语义）
  - `game/framework/mod_data.lua`（2 处 io 收进契约）
  - `game/framework/game_hooks.lua`（`getMyPicOr`）
  - `game/framework/game_states.lua` / `jymain_adapter.lua` / `interact.lua`（8 处 nil 安全）
  - `game/tests/unit/test_engine_conformance.lua`（完整性改源码级 + playSequence 源码级）
  - `game/tests/unit/test_engine_io_portability.lua`（+4 用例）
  - `game/tests/unit/test_nil_safety.lua`（新，25 断言）
  - `game/tests/unit/test_auto_move.lua`（setupMoveEnv 注册 GameHooks）
