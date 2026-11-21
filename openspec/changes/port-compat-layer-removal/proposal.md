# Change Proposal: port-compat-layer-removal — 摘掉 `_G.lib` 全局兼容层

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）
> 前置: `port-native-api-completion` ✓（`script/` 已零 `lib.*`）

## Why

`game/engine-love2d/engine_love2d.lua:1123`：

```lua
_G.lib = setmetatable(EngineAPI, { __index = lib })   -- 回退到 lib_love 的 1795 行
```

`engine-portability` slice 早先记录的理由是「oldevent 脚本依赖它（约 2000 个数据文件）」。

**本轮实测推翻了这个理由**：

| 检查 | 结果 |
|------|------|
| `game/script/oldevent/*.lua`（1018 个）含 `lib.` | **0** |
| `game/mods/*/script/oldevent/*.lua`（26790 个）含 `lib.` | **0** |
| 上述 27808 个脚本里**非** `instruct_*` 的全局函数调用 | **0**（只有 `instruct_0..67`，缺 7） |
| 上述脚本里 `DrawString`/`Cls`/`WaitKey`/`PlayMIDI`/`LoadPicture`/`PicLoad*` | **0** |

也就是说：事件数据层**从来不需要 `lib.*`**，它只需要 `instruct_*`。
`_G.lib` 今天的真实消费者总共 4 类、约 5 处（见下），全部在引擎侧与主循环。

### `_G.lib` 的实测消费者（全部）

| 位置 | 用法 | 处置 |
|------|------|------|
| `main.lua:201/213` | `lib.SetDrawLoopFlag(true/false)` | 新增契约 `render.setDrawLoopFlag` |
| `framework/async_globals.lua:115/127/249` | `lib.Delay` 换成协程版 / 还原 | 改为补丁 `EngineAPI.time.sleep` |
| `game/script/jymain.lua:51` | `WaitFrame` 的非协程 fallback `lib.Delay(m)` | 改 `EngineAPI.time.sleep(m)` |
| `game/engine-love2d/lib_love.lua`（8 处） | `lib.Debug(...)`（`SaveSMap` 7 处 + `DrawWarMap` 1 处） | 改 `Debug(...)` |
| `framework/interact.lua:185` | `local lib = rawget(_G, "lib")` **声明后从未使用** | 删（死变量） |
| `framework/settings_store.lua:45` | 同上（`debugLog` 里声明后未用） | 删（死变量） |

### 为什么这是**活体缺陷**，不只是洁癖

`_G.lib = setmetatable(EngineAPI, …)` 意味着 **`lib` 和 `EngineAPI` 是同一张表**。
`async_globals.install()` 里的 `lib.Delay = AsyncGlobals.lib_Delay_Async`
实际是**往 `EngineAPI` 表里写了一个新键 `Delay`**（契约里没有这个键），
而不是改 `EngineAPI.time.sleep`。

后果链：

```
WaitFrame(ms) → scheduler:waitFrame(ms, fallback)
                   fallback = function(m) lib.Delay(m) end
                              → EngineAPI.Delay  (= async_globals 装的协程版)
                                 → EngineAPI.time.sleep → lib_love.Delay → love.timer.sleep
```

即 fallback **本该是「阻塞退路」，却被换成了协程版**，
而协程版的第一行是 `if EngineAPI.coroutine.isRunning() then return EngineAPI.time.sleep(millis) end`
—— 在协程里又回到阻塞 `love.timer.sleep`。两个补丁互相抵消，
`port-blocking-delay` 的成果在 fallback 路径上被静默撤销。

另有 `lib_love.lua` 自己的 8 处 `lib.Debug`：`lib_love` 用 `_ENV = M`（`__index = _G`），
`lib.Debug` 经 `M` 落到 `_G` 的 `lib` —— **`lib_love` 反向依赖 `_G.lib`，而 `_G.lib` 又依赖 `lib_love`**。
删 `_G.lib` 会让这 8 处变成 `attempt to index nil`，必须在同一 change 内先改成 `Debug(...)`。

## In Scope

1. `lib_love.lua` 的 8 处 `lib.Debug` → 本地 `Debug(...)`
2. `main.lua` 的 `SetDrawLoopFlag` → 新契约 `render.setDrawLoopFlag(flag)`（4 引擎）
3. `async_globals.lua` 的 Delay 补丁点从 `lib.Delay` 改到 `EngineAPI.time.sleep`
4. `jymain.lua:51` 的 fallback → `EngineAPI.time.sleep`
5. 删 2 处死变量（`interact.lua:185` / `settings_store.lua:45`）
6. 4 引擎同步：`engine_love2d` 删 `_G.lib`；MUD/Web 的 `_G.lib` 一并删除或降级为「仅供引擎内部」
7. 新增门禁 STEP I：`framework/` `script/` `main.lua` 零 `rawget(_G,"lib")` / 零 `lib.*`；
   `_G.lib` 只允许出现在 `engine-*/`
8. 后台清理脚本级 trust：`lib_love` 的 8 处引用改为 `Debug` 后，
   gate 新增「`lib_love.lua` 零 `lib.` 自引用」断言

## Out of Scope

```
✗ 删除 lib_love.lua 本体（那是 port-legacy-picture-removal）
✗ 删除 lib_love 的 LoadPic / PicLoadFile / PicLoadCache（同上）
✗ 改动 async_globals 的其它替换（ShowMenu/TalkEx/WaitKey 等 8 个）—— 它们换的是 script 全局，与 lib 无关
✗ Web/MUD 的 lib 别名表整体重写（只要求「不再给 script 提供 lib」，引擎内部转发可留）
```

## Acceptance Criteria

### Scenario: `_G.lib` 只剩引擎内部

- **WHEN** 执行 `grep -rn 'rawget(_G, *"lib")' game/framework game/script game/main.lua`
- **THEN** 命中数 = 0

### Scenario: `lib_love` 不再自引用

- **WHEN** 执行 `grep -nE '\blib\.' game/engine-love2d/lib_love.lua`（排除注释）
- **THEN** 命中数 = 0

### Scenario: WaitFrame 的 fallback 是真阻塞退路

- **GIVEN** 非协程上下文调用 `WaitFrame(20)`
- **WHEN** 捕获实际调用
- **THEN** 落到 `EngineAPI.time.sleep`，且**不**经过 async_globals 的协程版

### Scenario: 虚拟手柄与既有三界面零回归

- **WHEN** 用 `docs/screenshots/README.md` 的参数重新截图
- **THEN** 战斗 `6c8eb322…` / 场景 `1efd2af3…` md5 不变；主地图目视正常

## 风险

| 风险 | 缓解 |
|------|------|
| 删 `_G.lib` 后某处漏改 → 运行时崩 | 先改 `lib_love` 自引用，再 `grep` 全仓清点，最后一次删；MUD 引擎单独冒烟 |
| `render.setDrawLoopFlag` 加错语义（present 门控失效 → 画面不刷新） | LÖVE 实现逐字转发 `lib.SetDrawLoopFlag`；实机截图对比 |
| MUD/Web 的 `_G.lib` 被自身代码依赖 | 先 `grep` 各引擎内部对 `lib.` 的引用，确认是 `local lib` 还是全局 |
