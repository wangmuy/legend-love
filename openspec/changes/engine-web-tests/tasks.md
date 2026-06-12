## 1. 测试基础设施

- [x] 1.1 安装 `@playwright/test` 到 devDependencies
- [x] 1.2 创建 `playwright.config.js`（Chromium headless，端口 8088）
- [x] 1.3 创建 `helpers/setup.js`（waitForPageReady + luaEval + getLuaGlobal）
- [x] 1.4 封装 `luaEval(code)` 工具函数（使用 fengari.load() 自动类型转换）
- [x] 1.5 封装 `readTermLine(page, n)` / `readAllTermLines(page)` 工具（xterm buffer API）
- [x] 1.6 在 `index.js` 中暴露 `window.__xterm = term` 供测试读取
- [x] 1.7 更新 `package.json` 添加 `test` / `test:ui` 脚本

## 2. 页面加载基础测试 (page-load.spec.js)

- [x] 2.1 页面标题正确
- [x] 2.2 xterm 终端渲染
- [x] 2.3 输入框存在且可交互
- [x] 2.4 CDN 脚本加载无 404

## 3. Lua VM 初始化测试 (lua-vm.spec.js)

- [x] 3.1 fengari 全局对象存在
- [x] 3.2 JSBridge 表已注入（含 write/getEvent/getEventCount）
- [x] 3.3 EngineAPI 表存在（含 13 个子模块）
- [x] 3.4 lib 表存在（metatable 代理指向 EngineAPI）
- [x] 3.5 dataCache._loaded == true

## 4. EngineAPI 功能测试 (engine-api.spec.js)

- [x] 4.1 45 个函数签名全部存在
- [x] 4.2 color.pack/unpack 往返正确
- [x] 4.3 colorToAnsi 阈值映射（红/白/黑/黄）
- [x] 4.4 render.text 构造 ANSI 缓冲区
- [x] 4.5 render.present 清空缓冲区并调用 JSBridge
- [x] 4.6 render.drawBackground 输出清屏码
- [x] 4.7 time.getTime 返回数字
- [x] 4.8 time.sleep yield 后立即恢复
- [x] 4.9 debug.log 写入内容
- [x] 4.10 font.get 返回 stub
- [x] 4.11 app.quit no-op 不抛异常
- [x] 4.12 file.open 从 rawDataCache 读取 + read/seek/close
- [x] 4.13 file.exists 正确判断
- [x] 4.14 file.lines 逐行迭代
- [x] 4.15 file.getSize 返回字节数
- [x] 4.16 script.load 加载 Lua chunk / 不存在时返回 nil

## 5. 数据完整性测试 (data-integrity.spec.js)

- [x] 5.1 _fileCount == 10
- [x] 5.2-5.11 逐个检查 10 个 key 存在且非空
- [x] 5.9 dataCachePaths 兼容映射
- [x] 5.10 场景 NPC 引用在 chars 中存在
- [x] 5.11 D* 事件引用的场景 ID 在 scenes 中存在（events.json 引用校验）
- [x] 5.12 entrances 场景 ID 在 scenes 中存在

## 6. 交互流程测试 (interaction.spec.js)

- [x] 6.1 输入文字后终端显示回显
- [x] 6.2 Lua 侧 getEvent 能消费输入事件

## 7. 错误场景测试 (error-handling.spec.js)

- [x] 7.1 file.open 不存在文件返回 nil
- [x] 7.2 script.load 不存在脚本返回 nil, error
- [x] 7.3 parseJSON 非法 JSON 抛错误
- [x] 7.4 控制台无 error/warning
- [x] 7.5 网络请求无失败