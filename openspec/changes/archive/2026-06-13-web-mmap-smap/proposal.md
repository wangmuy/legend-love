## 为什么

Slice 2 的 EngineAPI 提供了渲染和输入能力，web-game-bridge 让框架能运行，web-command-engine 提供了命令解析。但还缺少游戏逻辑本身——大地图和场景的文字交互。

## 变更内容

- 新增 `game/engine-web/web_mmap_smap.lua` — MMAP 和 SMAP 状态渲染与命令处理器
- 注册 MMAP 命令（list/go/look/where）到 CommandEngine
- 注册 SMAP 命令（look/exits/go）到 CommandEngine

## 能力

### 新增能力
- `web-mmap-smap`: 大地图和场景的文字交互游戏逻辑

### 修改的能力
- 无

## 影响

- 新增 1 个 Lua 文件
- 在 processEventQueue 启动后注册命令处理器
- 依赖 web-game-bridge（框架可用，JY.Status 正常切换）
- 依赖 web-command-engine（注册命令和分发）