## 架构总览

```
game/engine-web/
├── index.html
│     └── xterm.js (终端渲染)
├── index.js
│     ├── 加载 fengari-web.js
│     ├── bootstrap Lua VM（使用 fengari.load()，lauxlib.luaL_loadstring 在 0.1.4 不可用）
│     ├── dofile("engine_web.lua")   ← EngineAPI 实现
│     ├── dofile("data_loader.lua")  ← 加载 JSON
│     └── requestAnimationFrame 循环
│           └── processEventQueue()
├── engine_web.lua
├── data_loader.lua
├── style.css
├── package.json
├── scripts/build.js
├── .gitignore
├── data-web/*.json          ← 提取数据 (gitignored 但 git add -f 追踪，构建关键产物)
├── node_modules/            ← npm 依赖 (gitignored)
├── lib/                     ← 运行时库 (CDN 引用)
└── dist/                    ← 构建产物 (gitignored)
      ├── index.html         ← CDN→本地路径改写
      ├── lib/
      ├── engine_web.lua
      ├── data_loader.lua
      ├── data-web/*.json
      └── style.css
```

## 事件循环

```
requestAnimationFrame(timestamp)
  │
  ├── Lua: processEventQueue()
  │     ├── drain JS event buffer
  │     │     ├── "input" 事件 → 恢复 waitForKey 协程
  │     │     ├── "timer" 事件 → CoroutineScheduler:update()
  │     │     └── "resume" 事件 → 恢复指定协程
  │     │
  │     └── render buffer 非空？
  │           └── write ANSI string → xterm.js
  │
  └── requestAnimationFrame(gameLoop)
```

## EngineAPI 映射总览

| EngineAPI 模块 | Web 实现策略 |
|---------------|-------------|
| render.text(x,y,str,color) | ANSI 转义码追加到输出缓冲区（忽略 x,y 像素坐标） |
| render.fillRect | ANSI 背景色或忽略 |
| render.drawBackground | ANSI 清屏 + 背景色 |
| render.present | 缓冲区 → xterm.write() |
| render.presentAndWait | present + yield |
| sprite.* | 全部 no-op |
| map.* | 全部 no-op |
| input.getKey | 从 JS 的事件队列取下一个键值 |
| input.waitForKey | yield，JS 输入事件入队后恢复 |
| audio.* | 全部 no-op |
| time.sleep | yield + return（无真实时间等待） |
| time.getTime | os.clock()（返回秒数） |
| file.* | 从预加载的 `_G.dataCache` / `_G.rawDataCache` 表读取 |
| script.load | 通过 fetch 加载 + `fengari.load()` 执行 |
| font.* | 返回存根（xterm.js 处理字体） |
| color.* | 正常实现（用于 ANSI 颜色映射 + colorToAnsi 函数） |
| debug.log | JSBridge.write 输出到 xterm 终端 |
| coroutine.* | Fengari 原生支持 |
| app.quit | 无操作 |

## ANSI 颜色映射

```lua
local colorToAnsi = {
    -- CC 颜色定义 → ANSI 颜色码
    -- 使用 C_WHITE/ORANGE/GOLD/BLACK 等
    [RGB(236,236,236)] = "\027[37m",  -- C_WHITE → 白
    [RGB(252,148,16)]  = "\027[33m",  -- C_ORANGE → 黄
    [RGB(236,200,40)]  = "\027[33m",  -- C_GOLD → 亮黄
    [RGB(216,20,24)]   = "\027[31m",  -- C_RED → 红
    [RGB(132,0,4)]     = "\027[91m",  -- C_STARTMENU → 亮红
    [RGB(0,0,0)]       = "\027[30m",  -- C_BLACK → 黑
}
```

默认映射：颜色接近 ANSI 16 色调色板。不匹配的颜色映射为最近色。

## xterm.js 配置

```javascript
const term = new Terminal({
    cols: 80,
    rows: 24,
    cursorBlink: true,
    cursorStyle: 'block',
    fontSize: 14,
    fontFamily: '"Courier New", "Noto Sans SC", monospace',
    allowTransparency: true,
    theme: { background: '#0a0a0a', foreground: '#c0c0c0' },
});
const fitAddon = new FitAddon();
term.loadAddon(fitAddon);
```

注意：CJK 字符宽度问题。使用 FitAddon 自适应终端尺寸。
作为 MUD 游戏终端，CJK 宽度的小偏差可接受。

## 输出文件结构

```
game/engine-web/
├── index.html                 ← 页面入口
├── index.js                   ← 前端逻辑
├── engine_web.lua             ← EngineAPI 45 函数实现
├── data_loader.lua            ← JSON → Lua 表加载
├── state_manager.lua          ← 游戏状态管理器（save/load）
├── data-web/                  ← 从提取脚本产出 (git add -f 追踪)
│   └── *.json (10 个文件)
├── lib/
│   ├── fengari-web.js         ← Fengari Lua VM
│   └── xterm.js               ← 终端模拟器
├── style.css                  ← 页面样式
├── tests/                     ← Playwright E2E 测试 (59 条)
├── package.json               ← npm 依赖
├── scripts/build.js           ← 构建脚本
├── playwright.config.js       ← 测试配置
└── .gitignore
```

## 风险

| 风险 | 缓解 |
|------|------|
| Fengari 与 Lua 5.3 兼容性问题 | 先用简单 Lua 脚本测试 Fengari 加载 |
| xterm.js CJK 宽度问题 | 使用 FitAddon 自适应，接受小偏差 |
| JSON 加载速度 | 3.5MB events.json 使用 JS JSON.parse（`injectParsedJson()`）绕过 Lua 解析器 |
| `lauxlib.luaL_loadstring` 在 fengari-web 0.1.4 不可用 | 使用 `fengari.load()` 替代 |
| JS ↔ Lua 大量数据传递 | `lua_tolstring()` + `to_jsstring()` 避免 WASM 指针问题 |