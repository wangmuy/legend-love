## ADDED Requirements

### Requirement:  xterm.js 终端

系统 SHALL 在浏览器中显示 xterm.js 终端。

#### Scenario: 终端初始化
- **WHEN** 页面加载完成
- **THEN** 80×24 字符的终端可见
- **AND** 背景色为深色 (#0a0a0a)
- **AND** 前景色为浅灰色 (#c0c0c0)

### Requirement:  Fengari Lua VM

系统 SHALL 在浏览器中加载并初始化 Fengari Lua VM。

#### Scenario: Lua VM 初始化
- **WHEN** 页面加载完成
- **THEN** Fengari Lua VM 已初始化
- **AND** 可以执行 Lua 代码

### Requirement:  JS ↔ Lua 桥接

系统 SHALL 提供 JS 和 Lua 之间的双向调用桥接。

#### Scenario: Lua 调用 JS
- **WHEN** Lua 代码调用 JSBridge.write("text")
- **THEN** xterm.js 显示 "text"

#### Scenario: JS 调用 Lua
- **WHEN** JS 调用 pushLuaEvent({type="input", data="hello"})
- **THEN** Lua 的 processEventQueue 处理该事件

### Requirement:  事件队列

系统 SHALL 实现 FIFO 事件队列驱动游戏循环。

#### Scenario: 输入事件入队
- **WHEN** 用户在输入框输入 "help" 并回车
- **THEN** 输入文本显示在终端上
- **AND** 事件入队 {type="input", data="help"}
- **AND** 输入框清空

#### Scenario: 帧循环
- **WHEN** 页面加载完成
- **THEN** requestAnimationFrame 开始驱动 gameLoop
- **AND** 每帧调用 Lua: processEventQueue(timestamp)

### Requirement:  Lua 模块加载

系统 SHALL 支持从 JS 加载 Lua 源代码文件到 Fengari VM。

#### Scenario: 加载 Lua 文件
- **WHEN** JS fetch 获取 engine_web.lua 的源码
- **AND** 调用 lauxlib.luaL_loadstring(L, source)
- **THEN** Lua 代码在 VM 中执行
- **AND** EngineAPI 全局变量可用