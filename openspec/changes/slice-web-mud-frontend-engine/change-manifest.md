# Change Manifest — 前端骨架 + engine_web

## 依赖顺序

```
engine-web-core  ──┐
web-data-loader  ──┤  (无依赖，可并行)
                   │
web-frontend-shell ─┘  (依赖 engine-web-core + web-data-loader)
                   │
engine-web-tests   ───  (依赖 web-frontend-shell)
```

engine-web-core 和 web-data-loader 可并行开发。
web-frontend-shell 需要等两者完成后再集成。
engine-web-tests 需要 web-frontend-shell 就绪后再编写（测试跑在完整页面上）。

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

### 4. engine-web-tests

| 字段 | 值 |
|------|-----|
| Scope | Playwright E2E 测试 + Lua 单元测试覆盖 engine-web 全部行为 |
| Responsibility | 44 条测试用例，8 个层次：页面加载、Lua VM、API 表面/功能、数据完整性、跨文件引用、交互流程、错误场景 |
| Depends on | web-frontend-shell（需要完整页面环境运行测试） |
| Status | [ ] Created |

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

1. 打开 `game/engine-web/index.html`
2. xterm.js 显示引擎初始化中...
3. Lua VM 加载完成，显示 "Lua VM ready"
4. JSON 数据加载完成，显示 "Data loaded: 7 files, 0.6 MB"
5. 终端显示 "金庸群侠传 Web MUD v0.1"
6. 输入框可用，输入 `help` 显示 "Available commands: none (game not loaded)"

### 自动化测试

1. Playwright 打开 Chromium → 页面加载完全
2. 44 条测试用例自动执行（8 个 spec 文件）
3. 覆盖页面加载、Lua VM、API 功能、数据完整性、交互流程、错误场景
4. `npm test` 一键运行