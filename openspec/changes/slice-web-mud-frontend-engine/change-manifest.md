# Change Manifest — 前端骨架 + engine_web

## 依赖顺序

```
engine-web-core  ──┐
web-data-loader  ──┤  (无依赖，可并行)
                    │
web-frontend-shell ─┘  (依赖 engine-web-core + web-data-loader)
                    │
engine-web-tests   ───  (依赖 web-frontend-shell)
                    │
engine-web-state-persistence ─── (依赖 engine-web-core + web-data-loader + web-frontend-shell)
```

## Change Assignments

### 1. engine-web-core

| 字段 | 值 |
|------|-----|
| Scope | EngineAPI 45 个函数的 Web 实现（13 个模块） |
| Responsibility | 实现全部 render/input/time/file/script/font/color/debug/coroutine/sprite/map/audio/app 模块 + ANSI 颜色映射 |
| Depends on | 无 |
| Status | [x] Created |

### 2. web-data-loader

| 字段 | 值 |
|------|-----|
| Scope | parseJSON + dataCache 加载管线 |
| Responsibility | 递归下降 JSON 解析器、loadJSONChunk/finalizeDataLoad、10 个 JSON 文件批量加载 |
| Depends on | 无 |
| Status | [x] Created |

### 3. web-frontend-shell

| 字段 | 值 |
|------|-----|
| Scope | index.html + index.js + xterm.js + Fengari bootstrap |
| Responsibility | 页面骨架、JSBridge 桥接、事件队列、requestAnimationFrame 循环、Lua 模块加载器 |
| Depends on | 无 |
| Status | [x] Created |

### 4. engine-web-tests

| 字段 | 值 |
|------|-----|
| Scope | Playwright E2E 测试覆盖 engine-web 全部行为 |
| Responsibility | 59 条测试用例，7 个 spec：页面加载、Lua VM、API 表面/功能、数据完整性、交互流程、错误场景、状态持久化 |
| Depends on | web-frontend-shell（需要完整页面环境运行测试） |
| Status | [x] Created |

### 5. engine-web-state-persistence

| 字段 | 值 |
|------|-----|
| Scope | 游戏状态持久化（IndexedDB） |
| Responsibility | initGameState/saveGameState/loadGameState、JSBridge IndexedDB 存储接口、encodeSimpleJSON |
| Depends on | engine-web-core, web-data-loader, web-frontend-shell |
| Status | [x] Created |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| _G.EngineAPI | 全局 EngineAPI 表，engine_web.lua 写入 |
| _G.lib | 全局 lib 别名，指向 EngineAPI 的兼容包装 |
| _G.dataCache | 预加载 JSON 数据的全局表，中文键名，格式同 JSON 结构（只读模板） |
| _G.JY | 游戏状态表，中文键名，initGameState 从 dataCache 拷贝，saveGameState 序列化到 IndexedDB |
| JSBridge.save(key, json) | 将 JSON 字符串存入 IndexedDB + 内存缓存 |
| JSBridge.load(key) | 从内存缓存读取（同步） |
| JSBridge.listSaves() | 列出所有存档槽位状态 |
| JSBridge.onLuaOutput(ansiStr) | JS 侧函数，engine_web 输出 ANSI 到 xterm |
| JSBridge.onLuaPrompt() | JS 侧函数，聚焦输入框等待用户输入 |
| JSBridge.onLuaReady() | JS 侧函数，Lua VM 初始化完成通知 |

## Integration Test Plan

1. 打开 `game/engine-web/index.html`
2. xterm.js 显示引擎初始化中...
3. Lua VM 加载完成，显示 "Lua VM ready"
4. JSON 数据加载完成，显示 "Data loaded: 10 files"
5. 终端显示 "金庸群侠传 Web MUD v0.1"
6. 输入框可用，输入文字后终端显示回显

### 自动化测试

1. Playwright 打开 Chromium → 页面加载完全
2. 59 条测试用例自动执行（7 个 spec 文件）
3. 覆盖页面加载、Lua VM、API 功能、数据完整性、交互流程、错误场景、状态持久化
4. `npm test` 一键运行