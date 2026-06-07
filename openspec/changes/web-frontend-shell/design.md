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

## JS ↔ Lua 桥接

```javascript
// index.js

// 1. Fengari bootstrap
const fengari = window.fengari;
const lua = fengari.lua;
const lualib = fengari.lualib;
const lauxlib = fengari.lauxlib;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

// 2. xterm.js 初始化
const term = new Terminal({
    cols: 80, rows: 24,
    cursorBlink: true,
    fontSize: 14,
    fontFamily: '"Courier New", "Noto Sans SC", monospace',
    theme: { background: '#0a0a0a', foreground: '#c0c0c0' }
});
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
    lauxlib.lua_getglobal(L, 'processEventQueue');
    lauxlib.lua_pushnumber(L, timestamp);
    if (lua.lua_pcall(L, 1, 0, 0) !== 0) {
        const err = lauxlib.lua_tostring(L, -1);
        term.write('\r\nLua Error: ' + err);
        lua.lua_pop(L, 1);
    }
    requestAnimationFrame(gameLoop);
}

// 6. 加载 Lua 模块
function loadLuaFile(name, content) {
    const result = lauxlib.luaL_loadstring(L, content);
    if (result !== 0) {
        console.error('Failed to load', name);
        return;
    }
    if (lua.lua_pcall(L, 0, 0, 0) !== 0) {
        const err = lauxlib.lua_tostring(L, -1);
        console.error('Lua error in', name, err);
        lua.lua_pop(L, 1);
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
4. Fengari 不支持 `loadfile` — 使用 `lauxlib.luaL_loadstring` 加载 Lua 代码。

## 输出布局

```
┌─────────────────────────────────┐
│  xterm.js 终端                   │
│                                 │
│  金庸群侠传 Web MUD v0.1        │
│  Lua VM: ready                  │
│  Data: 7 files, 0.6 MB loaded   │
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
| xterm.js CJK 字符宽度 | 接受小偏差，不安装 addon-fit |
| 输入法中文字符 | input type="text" 原生支持 |