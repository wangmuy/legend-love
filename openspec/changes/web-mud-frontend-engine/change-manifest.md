# Change Manifest — 前端骨架 + engine_web

## 依赖顺序

```
engine-web-core  ──┐
web-data-loader  ──┤  (无依赖，可并行)
                   │
web-frontend-shell ─┘  (依赖 engine-web-core + web-data-loader)
```

engine-web-core 和 web-data-loader 可并行开发。
web-frontend-shell 需要等两者完成后再集成。

## Change Assignments

### 1. engine-web-core

| 字段 | 值 |
|------|-----|
| Scope | 实现 37 个 EngineAPI 函数的 Web 版本 |
| Responsibility | 所有 render.*、input.*、sprite.*、map.*、audio.*、time.*、file.*、script.*、font.*、color.*、debug.*、coroutine.*、app.* |
| Depends on | 无（独立实现，不依赖其他 change） |
| Status | [x] Created |

### 2. web-data-loader

| 字段 | 值 |
|------|-----|
| Scope | JSON 数据包加载到 Lua 运行环境 |
| Responsibility | 实现数据加载逻辑：fetch JSON → 解析 → 存入 Lua 全局表 |
| Depends on | 无 |
| Status | [x] Created |

### 3. web-frontend-shell

| 字段 | 值 |
|------|-----|
| Scope | HTML 页面 + xterm.js + Fengari bootstrap + JS-Lua 桥接 |
| Responsibility | index.html、index.js、style.css、xterm.js 配置、Fengari 加载、事件队列、requestAnimationFrame 循环 |
| Depends on | engine-web-core, web-data-loader（需要在 Lua VM 中加载两者的实现） |
| Status | [x] Created |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| _G.EngineAPI | 全局 EngineAPI 表，engine_web.lua 写入 |
| _G.lib | 全局 lib 别名，指向 EngineAPI 的兼容包装 |
| _G.dataCache | 预加载 JSON 数据的全局表，格式同 JSON 结构 |
| JSBridge.onLuaOutput(ansiStr) | JS 侧函数，engine_web 输出 ANSI 到 xterm |
| JSBridge.onLuaPrompt() | JS 侧函数，聚焦输入框等待用户输入 |
| JSBridge.onLuaReady() | JS 侧函数，Lua VM 初始化完成通知 |

## Integration Test Plan

1. 打开 `www/index.html`
2. xterm.js 显示引擎初始化中...
3. Lua VM 加载完成，显示 "Lua VM ready"
4. JSON 数据加载完成，显示 "Data loaded: 7 files, 0.6 MB"
5. 终端显示 "金庸群侠传 Web MUD v0.1"
6. 输入框可用，输入 `help` 显示 "Available commands: none (game not loaded)"