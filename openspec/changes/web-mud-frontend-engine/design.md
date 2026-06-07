## 架构总览

```
game/engine-web/
├── index.html
│     └── xterm.js (终端渲染)
├── index.js
│     ├── 加载 fengari-web.js
│     ├── bootstrap Lua VM
│     ├── dofile("engine_web.lua")   ← EngineAPI 实现
│     ├── dofile("data_loader.lua")  ← 加载 JSON
│     └── requestAnimationFrame 循环
│           └── processEventQueue()
├── engine_web.lua
├── data_loader.lua
├── data-web/*.json
├── lib/
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
| time.getTime | os.clock() * 1000 |
| file.* | 从预加载的 `_G.dataCache` 表读取 |
| script.load | 从预加载的 `_G.scriptCache` 加载，或 fetch |
| font.* | 返回存根（xterm.js 处理字体） |
| color.* | 正常实现（用于 ANSI 颜色映射） |
| debug.log | JS console.log |
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
```

注意：CJK 字符宽度问题。xterm.js 默认对中文字符宽度处理不完美，
但作为 MUD 游戏终端，可接受宽度偏差。不安装 xterm-addon-fit，
固定 80×24 尺寸。

## 输出文件结构

```
game/engine-web/
├── index.html                 ← 页面入口
├── index.js                   ← 前端逻辑
├── engine_web.lua             ← EngineAPI 37 函数实现
├── data_loader.lua            ← JSON → Lua 表加载
├── data-web/                  ← 从提取脚本产出
│   └── *.json
├── lib/
│   ├── fengari-web.js         ← Fengari Lua VM
│   └── xterm.js               ← 终端模拟器
└── style.css                  ← 页面样式
```

## 风险

| 风险 | 缓解 |
|------|------|
| Fengari 与 Lua 5.1 兼容性问题 | 先用简单 Lua 脚本测试 Fengari 加载 |
| xterm.js CJK 宽度问题 | 固定 80×24，接受小偏差 |
| JSON 加载顺序 | data_loader.lua 用同步 fetch 顺序加载 |
| JS ↔ Lua 大量数据传递 | 一次加载到 Lua 内存，之后 Lua 内部访问 |