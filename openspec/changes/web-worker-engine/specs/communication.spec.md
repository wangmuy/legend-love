## ADDED Requirements

### Requirement: Worker 承载 Lua VM [REQ-001]

系统 SHALL 将 Fengari Lua VM 移至 Web Worker（`worker.js`），主线程通过 `new Worker('worker.js')` 创建。

#### Scenario: Worker 文件存在
- **WHEN** 浏览器加载 `index.html`
- **THEN** `worker.js` 被成功加载为 Web Worker

#### Scenario: Worker 中加载 fengari
- **WHEN** Worker 启动
- **THEN** Worker 通过 `importScripts` 加载 `fengari-web.js`
- **AND** `fengari` 全局对象在 Worker 中可用

### Requirement: 主线程 - Worker 通信协议 [REQ-002]

系统 SHALL 定义统一的 `postMessage` 消息格式用于主线程和 Worker 之间的通信。

#### Scenario: Worker 发送 output 消息
- **WHEN** Lua 侧调用 `JSBridge.write(text)`
- **THEN** Worker 执行 `postMessage({type:"output", text:text})`
- **AND** 主线程收到后调用 `term.write(text)`

#### Scenario: Worker 发送 ready 消息
- **WHEN** Worker 内 `bootstrap()` 完成（`initWebFramework()` 返回）
- **THEN** Worker 执行 `postMessage({type:"ready"})`
- **AND** 主线程收到后显示欢迎辞

#### Scenario: 主线程发送 input 消息
- **WHEN** 用户在输入框按 Enter
- **THEN** 主线程执行 `worker.postMessage({type:"input", data:text})`
- **AND** Worker 收到后将事件推入 `eventQueue`

#### Scenario: Worker 请求 IndexedDB 读取
- **WHEN** Lua 侧调用 `JSBridge.load(key)`
- **THEN** Worker 执行 `postMessage({type:"db_load", key:key})`
- **AND** 主线程查询 IndexedDB 后回复 `postMessage({type:"db_result", key:key, value:value})`
- **AND** Worker 收到回复后通过回调队列将结果返回给 Lua

### Requirement: Worker 内 gameLoop [REQ-003]

系统 SHALL 在 Worker 内实现游戏循环，使用 `setTimeout` 替代 `requestAnimationFrame`。

#### Scenario: gameLoop 启动
- **WHEN** Worker 就绪
- **THEN** 调用 `setTimeout(gameLoop, 16)`
- **AND** gameLoop 内调用 `processEventQueue(timestamp)`
- **AND** gameLoop 结束后再次调用 `setTimeout(gameLoop, 16)` 形成循环

### Requirement: 主线程仅处理 UI 和存储 [REQ-004]

系统 SHALL 确保主线程不执行任何 Lua 代码，仅处理 xterm.js 渲染、输入捕获、IndexedDB 操作。

#### Scenario: 主线程无 Lua 调用
- **WHEN** 页面加载完成
- **THEN** `index.js` 中不存在任何 `lua_*` API 调用
- **AND** 不存在 `fengari` 全局对象

## MODIFIED Requirements

### Requirement: 页面加载就绪检测 [REQ-005]

`waitForPageReady` SHALL 改为等待 Worker 发出 `ready` 消息，而非轮询 `dataCache._loaded`。

#### Scenario: 测试等待游戏就绪
- **WHEN** Playwright 测试调用 `waitForPageReady(page)`
- **THEN** 等待 Worker `postMessage({type:"ready"})` 被主线程接收
- **AND** 主线程在页面中设置标志（如 `window.__workerReady = true`）
- **AND** `waitForPageReady` 轮询该标志

### Requirement: 输入回显 [REQ-006]

`index.js` SHALL 在发送 input 给 Worker 前在终端显示 `> 命令名` 回显。

#### Scenario: 输入命令后回显
- **WHEN** 用户在输入框按 Enter
- **THEN** 终端显示 `> 命令内容`
- **AND** 内容通过 `postMessage` 发送给 Worker
