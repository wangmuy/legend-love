## 为什么

`EventExecutor.startEvent()` 调用时显示"事件系统不可用"。原因为 `event_executor.lua` 及其依赖模块（`async_globals`、`script_loader`、`async_wrapper`）未在 `initWebFramework` 中加载。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/event-system-integration/change-manifest.md`
- 依赖: Slice 3、Slice 4、web-worker-engine

## What Changes

1. 在 `initWebFramework` 末尾添加以下 require：
```lua
_G.EventExecutor = require("framework.event_executor")
require("framework.async_globals")  -- 安装 instruct 替换函数
require("framework.script_loader")
```
2. 确保 `async_globals` 安装的 `instruct_*` 函数与 Web MUD 版本不冲突

## Impact

| 文件 | 改动 |
|------|------|
| `web_game_bridge.lua` | 添加 require 语句 |
