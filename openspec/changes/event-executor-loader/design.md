## Context

EventExecutor 依赖链：`event_executor.lua` → `async_globals.lua` → `script_loader.lua` → `async_wrapper.lua`。这些模块通过 `require` 加载，使用 `package.preload` 中注册的 framework 模块。

同时需要将 `_G.dataCache` 重命名为 `_G.initDataSource`，因为 `dataCache` 暗示可写入，实际角色是只读初始数据源。

## Decisions

### 加载时机

在 `initWebFramework` 末尾、`JYMainAdapter.init()` 之前添加：

```lua
_G.EventExecutor = require("framework.event_executor")
```

### dataCache → initDataSource 重命名

`dataCache` 在 70+ 处引用，分布在 `data_loader.lua`、`state_manager.lua`、`engine_web.lua`、`web_game_bridge.lua`、`mmap_smap_handlers.lua`、`worker.js`、`index.js` 及测试文件。重命名为纯文本替换，无功能变化。

```lua
-- data_loader.lua
_G.initDataSource = {}  -- 原 _G.dataCache = {}
```

### 与 Web MUD instruct 的兼容性

`async_globals.lua` 的 `installReplacementFunctions()` 会通过 `rawset(_G, name, func)` 安装 `instruct_*` 替换函数。Web MUD 的版本也在 `initWebFramework` 中通过 `rawset` 安装。

**策略**：Web MUD 版本先安装，`async_globals` 后安装。`async_globals` 会覆盖 Web MUD 版本。如果 Web MUD 版本需要保留差异，在 `async_globals` 加载后重新 `rawset`。

### ScriptLoader

`script_loader.lua` 需要在 Worker 环境中找到 oldevent 脚本。由于 Worker 中脚本通过 `FrameworkSources` 加载，`script_loader` 需要支持从 `FrameworkSources` 读取：

```lua
-- script_loader 检查 FrameworkSources + 文件系统
local source = _G.FrameworkSources and _G.FrameworkSources["script/oldevent/oldevent_" .. id .. ".lua"]
```

目前 `init_all` 中已加载 `script/jymain.lua` 等，但未加载 oldevent 文件。需要将 oldevent 文件也通过 `FrameworkSources` 注册。

## Review Checklist

1. `_G.EventExecutor` 不为 nil
2. `EventExecutor.startEvent(691, 0, callback)` 正常调用
3. `async_globals` 安装的 `instruct_*` 不引起 gameLoop error
