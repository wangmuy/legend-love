## 页面结构

```html
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="lib/xterm.css">
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div id="terminal"></div>
    <div id="input-line">
        <span class="prompt">></span>
        <input type="text" id="command-input" autofocus>
    </div>

    <script src="lib/xterm.js"></script>
    <script src="lib/xterm-addon-fit.js"></script>
    <script src="lib/fengari-web.js"></script>
    <script src="index.js"></script>
</body>
</html>
```

> 开发模式通过 CDN 加载；`npm run build` 将 CDN 引用替换为本地 `lib/` 路径，产出到 `dist/`。

## JS ↔ Lua 桥接

```javascript
// index.js

// 1. Fengari bootstrap
const fengari = window.fengari;
const lua = fengari.lua;
const lualib = fengari.lualib;

const L = fengari.L;  // 预创建的 Lua 状态
lualib.luaL_openlibs(L);

// 2. xterm.js 初始化（使用 FitAddon）
const term = new Terminal({
    cols: 80, rows: 24,
    cursorBlink: true,
    fontSize: 14,
    fontFamily: '"Courier New", "Noto Sans SC", monospace',
    theme: { background: '#0a0a0a', foreground: '#c0c0c0' }
});
const fitAddon = new FitAddon();
term.loadAddon(fitAddon);
term.open(document.getElementById('terminal'));

// 3. JS 桥接函数（注入到 Lua 全局）
const bridge = {
    write: (ansiStr) => term.write(ansiStr),
    onReady: () => { document.getElementById('command-input').focus(); },
};

// 4. 事件队列
const eventQueue = [];
function pushEvent(ev) { eventQueue.push(ev); }
function getEvent() { return eventQueue.shift() || null; }
function getEventCount() { return eventQueue.length; }

// 5. requestAnimationFrame 循环
function gameLoop(timestamp) {
    // 调用 Lua 的 processEventQueue
    lua.lua_getglobal(L, 'processEventQueue');
    lua.lua_pushnumber(L, timestamp);
    if (lua.lua_pcall(L, 1, 0, 0) !== 0) {
        const err = lua.lua_tostring(L, -1);
        term.write('\r\nLua Error: ' + err);
        lua.lua_pop(L, 1);
    }
    requestAnimationFrame(gameLoop);
}

// 6. 加载 Lua 模块（使用 fengari.load()，lauxlib.luaL_loadstring 在 0.1.4 不可用）
function loadLuaCode(name, content) {
    try {
        const fn = fengari.load(content, name);
        fn(L);
    } catch (e) {
        console.error('Failed to load', name, e);
    }
}

// 7. 输入处理
document.getElementById('command-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
        const input = e.target.value.trim();
        e.target.value = '';
        term.write('\r\n> ' + input + '\r\n');
        pushEvent({ type: 'input', data: input });
    }
});
```

## Fengari 注意事项

1. Fengari 是 Lua 5.3，不是 5.1。`bit32` 库内置，`string.*` API 基本兼容。
2. Fengari 没有 `io.open` — 文件 I/O 必须通过 JS 桥接实现。
3. Fengari 支持完整的 coroutine API，async wrapper 应正常工作。
4. Fengari 不支持 `loadfile` — 使用 `fengari.load()` 加载 Lua 代码（`lauxlib.luaL_loadstring` 在 fengari-web 0.1.4 不可用）。
5. `lua_tostring()` 返回 WASM 指针数据（JS Uint8Array），必须使用 `lua_tolstring()` + `to_jsstring()` 获取正确的 JS 字符串。

## 输出布局

```
┌─────────────────────────────────┐
│  xterm.js 终端                   │
│                                 │
│  金庸群侠传 Web MUD v0.1        │
│  Lua VM: ready                  │
│  Data: 10 files, ~3.0 MB loaded │
│  ────────────────────────────   │
│  Available commands: none       │
│  (game not loaded)              │
│                                 │
├─────────────────────────────────┤
│ > _                             │  ← 输入行
└─────────────────────────────────┘
```

## 风险

| 风险 | 缓解 |
|------|------|
| Fengari 加载大量 Lua 代码的性能 | 先加载 engine_web.lua，游戏脚本按需加载 |
| xterm.js CJK 字符宽度 | 使用 FitAddon 自适应，小偏差仍可接受 |
| 输入法中文字符 | input type="text" 原生支持 |
| `lauxlib.luaL_loadstring` 不可用 | 使用 `fengari.load()` 替代 |
| `lua_tostring` 返回指针数据 | 使用 `lua_tolstring()` + `to_jsstring()` |
| data-web/*.json 在 .gitignore 中 | git add -f 强制追踪（构建关键产物） |