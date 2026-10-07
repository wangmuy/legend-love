## 1. 页面搭建

- [x] 1.1 创建 `game/engine-web/index.html`：xterm.js 终端容器 + 输入行
- [x] 1.2 创建 `game/engine-web/style.css`：暗色终端风格，终端+输入行布局
- [x] 1.3 CDN 加载 xterm.js、xterm.css、@xterm/addon-fit
- [x] 1.4 CDN 加载 fengari-web.js

## 2. JS 桥接实现

- [x] 2.1 xterm.js 初始化（80×24 终端，暗色主题，中文字体，FitAddon）
- [x] 2.2 JS 桥接对象 `window.JSBridge` 注入 `_G.JSBridge`（write、save、load、listSaves、delete、onReady、onLuaOutput、onLuaPrompt、onLuaReady）
- [x] 2.3 事件队列（input 事件入队，Lua 侧通过 getEvent 消费）
- [x] 2.4 requestAnimationFrame 游戏循环（驱动 Lua event_poll 和 processEventQueue）
- [x] 2.5 输入处理（Enter 提交 → 写入 xterm → 入队事件）
- [x] 2.6 Lua 模块加载器：`fetch .lua → fengari.load()`（不使用 lauxlib.luaL_loadstring，其在 fengari-web 0.1.4 不可用）

## 3. npm 配置

- [x] 3.1 创建 `package.json`（xterm、fengari-web、@xterm/addon-fit 依赖 + playwright test）
- [x] 3.2 创建 `scripts/build.js`（复制→dist，CDN→本地路径替换）
- [x] 3.3 创建 `.gitignore`（node_modules、dist、data-web 但 force-add）
- [x] 3.4 验证 `npm install` 和 `npm run build` 正常工作

## 4. 加载顺序和验证

- [x] 4.1 加载 engine_web.lua → 设置 EngineAPI/_G.lib
- [x] 4.2 加载 data_loader.lua → 注册 loadJSONChunk/finalizeDataLoad
- [x] 4.3 加载 state_manager.lua → 注册 initGameState/saveGameState/loadGameState
- [x] 4.4 验证终端显示 "Lua VM ready" 和 EngineAPI 版本号
- [x] 4.5 验证 10 个数据文件加载完成
- [x] 4.6 验证输入框可用，输入内容显示到终端且 Lua 侧 getEvent 可消费