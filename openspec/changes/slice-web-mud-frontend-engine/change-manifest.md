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

### 4. engine-web-tests

| 字段 | 值 |
|------|-----|
| Scope | Playwright E2E 测试 + Lua 单元测试覆盖 engine-web 全部行为 |
| Responsibility | 50 条测试用例，8 个层次：页面加载、Lua VM、API 表面/功能、数据完整性、跨文件引用、交互流程、错误场景 |
| Depends on | web-frontend-shell（需要完整页面环境运行测试） |
| Status | [x] Created |

### 5. engine-web-state-persistence

| 字段 | 值 |
|------|-----|
| Scope | 字段名映射 + 游戏状态持久化（IndexedDB） |
| Responsibility | 实现英文↔中文键名映射、loadGameState/saveGameState、JSBridge IndexedDB 存储接口 |
| Depends on | engine-web-core, web-data-loader, web-frontend-shell |
| Status | [ ] Draft |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| _G.EngineAPI | 全局 EngineAPI 表，engine_web.lua 写入 |
| _G.lib | 全局 lib 别名，指向 EngineAPI 的兼容包装 |
| _G.dataCache | 预加载 JSON 数据的全局表，格式同 JSON 结构 |
| _G.JY | 游戏状态表，中文键名，通过 loadGameState/saveGameState 管理 |
| _G.fieldMap | 英文↔中文键名映射表，按数据结构分组 |
| JSBridge.save(key, json) | 将 JSON 字符串存入 IndexedDB |
| JSBridge.load(key) | 从 IndexedDB 读取 JSON 字符串 |
| JSBridge.listSaves() | 列出所有存档槽位状态 |
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