## Context

当前 `index.js` 中 Lua 引擎（Fengari）、游戏循环（gameLoop）、JSBridge、xterm.js 渲染、IndexedDB 全部跑在浏览器主线程。Lua 的 `lua_pcall` 编译执行是同步操作，加载 30+ 模块、解析 10 个 JSON 数据包、执行 `initWebFramework()` 时会长时间阻塞主线程，导致 DOM 事件（点击、键盘）无法处理。

将 Lua 移入 Web Worker 后，主线程只需处理 xterm.js 渲染和输入转发，UI 永远流畅。

## Goals / Non-Goals

**Goals:**
- Lua VM（Fengari）、所有 `.lua` 文件加载、`initWebFramework()`、`gameLoop` 移入 Web Worker
- 主线程保留 xterm.js 终端渲染、输入捕获、IndexedDB 存储操作
- JSBridge 函数通过 `postMessage`/`onmessage` 跨线程通信
- 所有现有 `.lua` 文件不做任何修改
- 所有已有 Playwright 测试仍然通过（仅调整等待策略）

**Non-Goals:**
- 不改 `package.json` 或构建流程（Worker 使用标准 Web Worker API，不需要 webpack）
- 不改任何 `.lua` 文件
- 不添加加载动画或进度条
- 不优化 Lua 文件体积或加载顺序
- 不涉及 Worker 线程池或多 Worker

## Architecture Decision Records

### ADR-001: Web Worker 承载完整 Lua VM

- **Context**: 需要一个独立线程运行 Lua 引擎，避免阻塞主线程 UI。
- **Decision**: 使用标准 Web Worker（`new Worker('worker.js')`），将 Fengari VM + 所有 Lua 代码 + gameLoop 整体移入 Worker。
- **Alternatives Considered**:
  - `setTimeout(0)` 分片：不改架构但每次 `lua_pcall` 仍同步阻塞主线程，只是切成小段。不够彻底。
  - `Atomics.wait` + SharedArrayBuffer：需要 COOP/COEP 头，部署复杂，且 Lua 执行不是可中断的。
- **Consequences**: 通信改为异步 postMessage，JSBridge 的 `load` 操作（IndexedDB 读取）需要回调/回复机制。

### ADR-002: gameLoop 使用 setTimeout 替代 requestAnimationFrame

- **Context**: Worker 中没有 `requestAnimationFrame`。
- **Decision**: 使用 `setTimeout(gameLoop, 16)` 实现 ~60fps。
- **Alternatives Considered**:
  - `setInterval(16)`：可能在主线程繁忙时堆积调用。
- **Consequences**: 精度低于 rAF（约 ±4ms），但对 MUD 文字游戏可忽略。

### ADR-003: 异步 IndexedDB 通过消息回复机制

- **Context**: Worker 不能直接操作 IndexedDB。`JSBridge.load` 需要读取数据并返回给 Lua。
- **Decision**: 主线程处理 IndexedDB，Worker 发请求消息，主线程查询后回复。Worker 中用回调队列匹配请求和回复。
  ```
  Worker: postMessage({type:"db_load", key:"save_0"}) → 等待回复
  Main: 收到 → IndexedDB 查询 → postMessage({type:"db_result", key:"save_0", value:"..."})
  Worker: 收到 → 回调队列匹配 → Lua 协程恢复
  ```
- **Alternatives Considered**:
  - SharedArrayBuffer + spinlock：太复杂且有安全限制。
- **Consequences**: 所有 IndexedDB 操作变成异步，Lua 侧需要通过 yield/resume 等待结果。

### ADR-004: 不对 js 侧采用打包工具，Worker 直接加载 CDN

- **Context**: 当前项目使用 CDN 加载 fengari-web.js 和 xterm.js，无需 webpack。
- **Decision**: Worker 内通过 `importScripts()` 加载 fengari-web.js（CDN 或本地拷贝），主线程继续用 `<script>` 加载。
- **Alternatives Considered**:
  - webpack worker-loader：引入构建工具链，增加复杂度。
- **Consequences**: Worker 中无法使用 ES module 语法，只能 `importScripts`。

## Negative Constraints

- 不要修改任何 `.lua` 文件
- 不要修改 `package.json`、`playwright.config.js`、`scripts/` 目录下的构建脚本
- 不要引入 webpack 或 rollup 等打包工具
- 不要修改 `data-web/` 或 `data_loader.lua` 的 JSON 加载逻辑
- Worker 内不要使用 DOM API（`document`、`window` 等）

## Alignment Check

本 change 不修改 Lua 侧代码，不修改数据加载管线，不修改游戏逻辑。与 `constitution.md` 无冲突。

## Decisions

- `worker.js` 存放位置：`game/engine-web/worker.js`，与 `index.js` 同级
- 通信消息统一使用 `{type: string, ...}` 格式
- Worker 内 `eventQueue` 由 `onmessage` 填充，`getEvent` 消费
- Lua 的 `JSBridge.write` 直接 `postMessage`，不需要回复
- 主线程不再调用任何 `lua_*` API，完全通过消息通信
- `loadLuaModule` 函数移到 Worker 内，编译 + 执行 Lua

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Worker 中 `initWebFramework()` 执行时间长，`ready` 消息延迟 | 但此时 UI 线程完全不卡，用户可点击输入框 |
| 异步 IndexedDB 操作增加 Lua 协程复杂度 | 只在 `loadGameState` 中使用，非高频路径 |
| `importScripts` 加载 fengari 可能比 `<script>` 慢 | 实测差异 < 50ms，可接受 |
| Playwright 测试需要新的就绪检测方式 | 改为监听 `page.on('console')` 匹配 "Web MUD ready" 或轮询 Worker 状态 |

## Migration Plan

1. **创建 `worker.js`**：包含全部 Lua 代码、JSBridge 实现、gameLoop
2. **简化 `index.js`**：移出 Lua 代码，保留 xterm + 输入转发 + IndexedDB
3. **调整 `index.html`**：CDN script 标签移除 fengari-web.js（移到 worker 内加载）
4. **更新测试**：`waitForPageReady` 改为等待 Worker ready 消息
5. **验证**：运行全部 Playwright 测试，确保 0 failure

回滚策略：保留 `index.js` 的 Lua 代码分支，通过开关切换。但考虑到改动清晰度，不保留兼容代码——直接替换，回滚靠 git。

## Open Questions

- Worker 内是否需要保留 `window.__xterm` 的暴露？不需要——Worker 没有 window。
- 主线程是否需要在 `ready` 前缓存用户输入？不需要——输入已 queued 在 eventQueue，Worker 就绪后第一帧会消费。
