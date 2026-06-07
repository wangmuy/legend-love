## 1. 页面搭建

- [ ] 1.1 创建 `www/index.html`：xterm.js 终端容器 + 输入行
- [ ] 1.2 创建 `www/style.css`：暗色终端风格，终端+输入行布局
- [ ] 1.3 下载/链接 xterm.js 和 xterm.css（CDN 或本地文件）
- [ ] 1.4 下载/链接 fengari-web.js（CDN 或本地文件）

## 2. JS 桥接实现

- [ ] 2.1 xterm.js 初始化（80×24 终端，暗色主题，中文字体）
- [ ] 2.2 JS 桥接对象 `_G.JSBridge`（write、onReady、pushEvent、getEvent）
- [ ] 2.3 事件队列（input 事件入队，Lua 侧消费）
- [ ] 2.4 requestAnimationFrame 循环（调用 Lua 的 processEventQueue）
- [ ] 2.5 输入处理（Enter 提交 → 写入 xterm → 入队事件）
- [ ] 2.6 Lua 模块加载器（fetch .lua 文件 → lauxlib.luaL_loadstring）

## 3. 加载顺序和验证

- [ ] 3.1 加载 engine_web.lua
- [ ] 3.2 加载 data_loader.lua
- [ ] 3.3 加载 web_bridge.lua
- [ ] 3.4 验证终端显示 "Lua VM ready"
- [ ] 3.5 验证终端显示数据加载完成
- [ ] 3.6 验证输入框可用，输入内容显示到终端