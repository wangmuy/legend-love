## 1. EngineAPI Web 实现（engine-web-core）

- [x] 1.1 实现 45 个 EngineAPI 函数，13 个模块
- [x] 1.2 render 模块输出 ANSI 转义码
- [x] 1.3 input 模块通过 JSBridge 事件队列读取输入
- [x] 1.4 file 模块从 rawDataCache 读取
- [x] 1.5 设置 `_G.EngineAPI` 和 `_G.lib`
- [x] 1.6 45 函数签名全部通过 E2E 测试

## 2. 数据加载器（web-data-loader）

- [x] 2.1 实现 Lua 递归下降 JSON 解析器 parseJSON
- [x] 2.2 实现 loadJSONChunk / finalizeDataLoad
- [x] 2.3 JS 侧注入 events.json（JS JSON.parse 加速）
- [x] 2.4 10 个 JSON 文件全部加载到 dataCache
- [x] 2.5 错误处理：pcall 保护 + 失败时清空该 key

## 3. 前端骨架（web-frontend-shell）

- [x] 3.1 创建 index.html + style.css
- [x] 3.2 xterm.js + FitAddon + Fengari bootstrap
- [x] 3.3 JSBridge 桥接（write/save/load/getEvent）
- [x] 3.4 requestAnimationFrame 游戏循环
- [x] 3.5 npm 配置 + build 脚本
- [x] 3.6 使用 fengari.load()（非 lauxlib.luaL_loadstring）

## 4. E2E 测试（engine-web-tests）

- [x] 4.1 Playwright 配置（Chromium, 1 worker, 端口 8088）
- [x] 4.2 测试基础设施（waitForPageReady, luaEval, getLuaGlobal）
- [x] 4.3 59 条测试覆盖 7 个 spec 文件

## 5. 状态持久化（engine-web-state-persistence）

- [x] 5.1 initGameState / saveGameState / loadGameState
- [x] 5.2 encodeSimpleJSON + restoreNumericKeys
- [x] 5.3 JSBridge IndexedDB 存储（saveCache 同步缓存）
- [x] 5.4 4 个存档槽（槽 0 自动 + 槽 1~3 手动）
- [x] 5.5 使用 lua_tolstring + to_jsstring 避免 WASM 指针问题