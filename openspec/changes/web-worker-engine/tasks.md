## 1. 创建 worker.js
Traceability: [REQ-001]

- [x] 1.1 创建 `game/engine-web/worker.js`，通过 `importScripts` 加载 fengari-web.js
  Blast Radius: `["game/engine-web/worker.js"]`
  DoD:
    - [x] Worker 文件存在且可通过 `new Worker('worker.js')` 加载
    - [x] Worker 内 `fengari` 全局对象可用

- [x] 1.2 将 `bootstrap()` 整体移入 Worker：加载 Lua 文件、framework 模块、游戏脚本、数据
  Blast Radius: `["game/engine-web/worker.js"]`
  DoD:
    - [x] Worker 启动后自动加载所有 Lua 模块和数据
    - [x] 加载完成后 `postMessage({type:"ready"})`

- [x] 1.3 Worker 中实现 JSBridge（write/getEvent/getEventCount/db_save/db_load/db_delete）
  Blast Radius: `["game/engine-web/worker.js"]`
  DoD:
    - [x] `JSBridge.write(text)` 调用 `postMessage({type:"output", text})`
    - [x] `getEvent()` 从 Worker 内 eventQueue 读取
    - [x] `save/load/delete` 通过 postMessage 转发给主线程

- [x] 1.4 Worker 中实现 gameLoop（setTimeout 替代 requestAnimationFrame）
  Blast Radius: `["game/engine-web/worker.js"]`
  DoD:
    - [x] Worker 就绪后启动 `setTimeout(gameLoop, 16)`
    - [x] gameLoop 调用 `processEventQueue(timestamp)`

## 2. 简化 index.js（主线程只留 UI）
Traceability: [REQ-004], [REQ-006]

- [x] 2.1 移除 index.js 中所有 Lua 相关代码（fengari、JSBridge 注入、loadLuaModule、bootstrap）
  Blast Radius: `["game/engine-web/index.js"]`
  DoD:
    - [x] index.js 中不存在 `lua_*` API 调用
    - [x] index.js 中不存在 `fengari` 引用

- [x] 2.2 实现 Worker 消息处理（onmessage）：output → term.write, ready → 显示欢迎辞
  Blast Radius: `["game/engine-web/index.js"]`
  DoD:
    - [x] 收到 `{type:"output", text}` → `term.write(text)`
    - [x] 收到 `{type:"ready"}` → 显示"欢迎来到..."和提示
    - [x] 设置 `window.__workerReady = true`

- [x] 2.3 输入捕获改为转发到 Worker（保留 > 回显）
  Blast Radius: `["game/engine-web/index.js"]`
  DoD:
    - [x] keydown Enter → `term.write('> ' + text)` → `worker.postMessage({type:"input", data:text})`

- [x] 2.4 实现 IndexedDB 存储处理（db_save/db_load/db_delete/db_list 的消息回复）
  Blast Radius: `["game/engine-web/index.js"]`
  DoD:
    - [x] 收到 `{type:"db_save"}` → IndexedDB 写入
    - [x] 收到 `{type:"db_load"}` → IndexedDB 读取 → `postMessage({type:"db_result", ...})`
    - [x] 收到 `{type:"db_delete"}` → IndexedDB 删除

## 3. 调整 index.html
Traceability: [REQ-001]

- [x] 3.1 更新 CDN script 标签，移除 fengari-web.js（移到 Worker 内加载）
  Blast Radius: `["game/engine-web/index.html"]`
  DoD:
    - [x] HTML 中不再有 `fengari-web.js` 的 `<script>` 引用
    - [x] 页面仍然能正常加载和运行

## 4. 更新测试
Traceability: [REQ-005]

- [x] 4.1 更新 `tests/helpers/setup.js` 中 `waitForPageReady` 改为等待 Worker ready
  Blast Radius: `["game/engine-web/tests/helpers/setup.js"]`
  DoD:
    - [x] `waitForPageReady` 轮询 `window.__workerReady` 而非 `dataCache._loaded`
    - [x] 所有 Playwright 测试文件不用逐个修改

- [x] 4.2 运行全部 Playwright 测试并修复 Worker 引入的问题
  Blast Radius: `["game/engine-web/tests/*.spec.js", "game/engine-web/tests/helpers/*", "game/engine-web/web_game_bridge.lua", "game/engine-web/worker.js", "game/framework/jymain_adapter.lua"]`
  DoD:
    - [x] 全部 88 个测试通过（14 个 spec 文件）
    - [x] 开始菜单、属性确认、MMAP→SMAP 完整流程
    - [x] 所有 window.fengari 依赖改为 __luaEval 桥接
    - [x] JSBridge.load 在 Worker 中异步处理
