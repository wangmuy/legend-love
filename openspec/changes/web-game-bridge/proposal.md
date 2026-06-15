## 为什么

Love2D 的游戏框架（framework/*.lua）依赖 keyboard-scan 的 InputManager 和每帧 love.update/love.draw 回调。Web MUD 需要把这些转换到基于文本命令的事件循环。

## 变更内容

- 新增 `game/engine-web/web_game_bridge.lua` — 游戏框架 Web 集成层（initWebFramework 加载 framework 模块和脚本模块、processEventQueue 驱动框架 + choose N → MenuAsync.closeMenu(N) + 命令分发、兼容函数映射、WebUI 输出、覆写 startNewGame/loadGame/showStartMenuCoroutine、覆写 Init_MMap/Init_SMap/CleanMemory、覆写 game_states 处理器为 no-op）
- 修改 `game/engine-web/engine_web.lua` — lib 添加桩函数（LoadMMap, GetMMap, UnloadMMap, PicLoadFile, GetS, SetS, GetD, SetD）
- 修改 `game/engine-web/index.js` — 调用 initWebFramework 和 processEventQueue

## 能力

### 新增能力
- `web-game-bridge`: 游戏框架的 Web 运行环境

### 修改的能力
- `engine_web.lua`: 添加 lib 桩函数（LoadMMap, GetMMap, UnloadMMap, PicLoadFile, GetS, SetS, GetD, SetD）

## 影响

- 新增 2-3 个 Lua 文件
- 修改 engine_web.lua 和 index.js
- 需要将所有 framework/*.lua 模块加载到 Fengari
- 需要加载 jymain.lua, jyconst.lua, jymodify.lua 等脚本
- choose N → MenuAsync.closeMenu(N) 处理菜单选择
- 其他命令通过 CommandEngine 按 JY.Status 分发
- 开始菜单和属性选择通过文本命令完成