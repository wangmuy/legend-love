## 为什么

当前 `engine-web` 的 Lua 引擎（Fengari）和游戏循环全部跑在浏览器主线程。初始化时加载 30+ 个 Lua 文件、解析 10 个 JSON 数据包、执行 `initWebFramework()`，这些同步 Lua 操作会长时间阻塞主线程。期间 xterm.js 无法渲染、输入框无法点击、DOM 事件无法处理——用户看到的"界面卡住"实际上是主线程被 Lua 占满。

将 Lua 引擎移入 Web Worker 后：
- Lua 执行在独立线程，主线程只负责 xterm 渲染和输入转发，UI 永远流畅
- 架构更接近非 Web 版（Love2D 渲染/逻辑分离），也更容易映射到真正 MUD server

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- 位于 Slice 3（大地图漫游）之后，Slice 4（场景交互）之前，作为独立架构重构 change
- 不依赖 Slice 4，不阻塞后续开发

## What Changes

将 Fengari Lua VM 从 `index.js` 主线程移到 `worker.js`（Web Worker），主线程和 Worker 之间通过 `postMessage`/`onmessage` 通信。

### 通信协议

| 方向 | type | 数据 | 说明 |
|------|------|------|------|
| Worker → Main | `output` | `{text:string}` | term.write 内容 |
| Worker → Main | `ready` | `{}` | bootstrap 完成，游戏就绪 |
| Worker → Main | `db_result` | `{key:string, value:string\|null}` | IndexedDB 读取结果 |
| Main → Worker | `input` | `{data:string}` | 用户输入 |
| Main → Worker | `db_save` | `{key:string, value:string}` | 持久化写入 |
| Main → Worker | `db_delete` | `{key:string}` | 删除存档 |

### JSBridge Worker 实现

原有的 `write`、`getEvent`、`getEventCount`、`save`、`load`、`delete`、`listSaves` 等 JSBridge 函数改为通过 `postMessage` 转发：
- `write` → 直接 `postMessage({type:"output", text})`
- `getEvent` / `getEventCount` → 从 Worker 内维护的 eventQueue 读取（由 `onmessage` 填充）
- `save` / `delete` → `postMessage({type:"db_save"/"db_delete", ...})`，由主线程操作 IndexedDB
- `load` → `postMessage({type:"db_load", key})`，主线程查询后 `postMessage({type:"db_result", ...})` 回复

### gameLoop

Worker 中没有 `requestAnimationFrame`，改用 `setTimeout(gameLoop, 16)` 实现 ~60fps。

### 测试

Playwright 测试的 `waitForPageReady` 需要改为等待 Worker 发出 `ready` 消息，而非轮询 `dataCache._loaded`。

## Scope Boundaries

### In Scope

- `game/engine-web/worker.js` 新建，包含全部 Lua 相关代码
- `game/engine-web/index.js` 剥离 Lua 代码，保留 xterm.js + 输入转发 + IndexedDB 处理
- `game/engine-web/index.html` 调整 CDN 脚本引用
- Playwright 测试辅助函数 `waitForPageReady` 适配 Worker 模式
- 通信协议设计与实现

### Out of Scope

- 不改任何 `.lua` 文件（Lua 侧代码不变，只是 JSBridge 实现方式变化）
- 不改 `package.json` 或构建流程（Worker 文件不需要 webpack，用标准 Worker API）
- 不改已有 Lua 模块的加载顺序或逻辑
- 不涉及性能优化（如 Lua 编译结果的缓存预加载）
- 不添加加载动画或进度条（只保证 UI 不卡）

## Capabilities

### New Capabilities
- `web-worker-lua-engine`: 将 Fengari Lua VM 移入 Web Worker，通过 postMessage 通信
- `main-thread-ui`: 主线程仅保留 xterm.js 渲染、输入捕获、IndexedDB 存储

### Modified Capabilities
- `page-load`（来自 engine-web-tests）: `waitForPageReady` 检测方式改为等待 Worker `ready` 消息

## Contract Adherence

本 change 不涉及 slice3 的共享契约，是独立的架构重构。不破坏任何 existing contract。

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/engine-web/index.js` | 大幅缩减，移除全部 Lua 代码和 JSBridge 注入逻辑 |
| `game/engine-web/worker.js` | **新增**，约 200-300 行 |
| `game/engine-web/index.html` | 调整 CDN script 引用（`fengari-web.js` 移到 Worker 内加载） |
| `game/engine-web/tests/helpers/setup.js` | `waitForPageReady` 适配 Worker |
| `game/engine-web/tests/*.spec.js` | 部分测试可能需微调（主要是等待策略） |
| 所有 `.lua` 文件 | **无改动** |
