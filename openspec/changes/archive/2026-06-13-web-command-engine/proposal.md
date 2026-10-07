## 为什么

Web MUD 需要通过文本命令而不是按键来操作。需要一个命令解析引擎将 "go 河洛客栈" 这样的文本转换为游戏动作。

## 变更内容

- 新增 `game/engine-web/web_command_engine.lua` — 命令解析和分发引擎
- 包含 parseCommand、命令注册表、dispatchCommand、help/choose 命令

## 能力

### 新增能力
- `web-command-engine`: 文本命令解析 + 上下文感知分发

### 修改的能力
- 无（CommandEngine 被 web-game-bridge 的 processEventQueue 调用）

## 影响

- 新增 1 个 Lua 文件
- 依赖 web-game-bridge 已加载完成（JY.Status 可用）