## ADDED Requirements

### Requirement: Playwright 测试框架

系统 SHALL 为 engine-web 提供自动化 E2E 测试套件。

#### Scenario: 测试基础设施
- **GIVEN** `npm install` 已执行
- **AND** `npx playwright install chromium` 已执行
- **WHEN** 运行 `npm test`
- **THEN** HTTP 服务器启动（端口 8088，无缓存）
- **AND** Playwright 打开 Chromium 浏览器
- **AND** 所有 44 条测试用例执行完毕
- **AND** 测试结果输出到终端

#### Scenario: 页面加载基础
- **WHEN** 浏览器打开 `http://localhost:8088/`
- **THEN** 页面标题为 "金庸群侠传 Web MUD"
- **AND** `.xterm` DOM 元素存在
- **AND** `#command-input` 输入框存在
- **AND** 所有 4 个 `<script>` 标签加载无网络错误

#### Scenario: Lua VM 初始化
- **WHEN** 页面加载完成
- **THEN** `typeof window.fengari` 为 `"object"`
- **AND** Lua 全局 `JSBridge` 是 table，含 `write`、`getEvent`、`getEventCount`
- **AND** Lua 全局 `EngineAPI` 是 table，含 13 个子模块
- **AND** Lua 全局 `lib` 是 table
- **AND** Lua 全局 `dataCache._loaded` 为 true

#### Scenario: EngineAPI 函数签名
- **WHEN** 遍历 `EngineAPI` 所有子模块
- **THEN** render 模块含 7 个函数
- **AND** input 模块含 3 个函数
- **AND** time 模块含 3 个函数
- **AND** file 模块含 9 个函数
- **AND** script 模块含 1 个函数
- **AND** font 模块含 1 个函数
- **AND** color 模块含 2 个函数
- **AND** debug 模块含 1 个函数
- **AND** coroutine 模块含 3 个函数
- **AND** sprite 模块含 4 个函数
- **AND** map 模块含 7 个函数
- **AND** audio 模块含 3 个函数
- **AND** app 模块含 1 个函数
- **AND** 合计 **45** 个函数

#### Scenario: EngineAPI 功能正确性
- **WHEN** 调用 `EngineAPI.color.pack(255, 0, 0)`
- **AND** 调用 `EngineAPI.color.unpack(结果)`
- **THEN** 返回 `r ≈ 1, g ≈ 0, b ≈ 0`
- **WHEN** 调用 `EngineAPI.render.text(0, 0, "test", 0xFF0000)`
- **AND** 调用 `EngineAPI.render.present()`
- **THEN** JSBridge.write 收到含 ANSI 转义码的字符串
- **WHEN** 调用 `EngineAPI.render.drawBackground(0, 0, 100, 100, 0)`
- **THEN** 缓冲区含清屏码 `\027[2J`
- **WHEN** 调用 `EngineAPI.time.getTime()`
- **THEN** 返回 number
- **WHEN** 调用 `EngineAPI.time.sleep(100)`
- **THEN** 立即返回（不阻塞）
- **WHEN** 调用 `EngineAPI.debug.log("msg")`
- **THEN** 输出 "[DEBUG] msg"
- **WHEN** 调用 `EngineAPI.font.get("monospace", 14)`
- **THEN** 返回 `{name="monospace", size=14}`
- **WHEN** 调用 `EngineAPI.app.quit()`
- **THEN** 无异常
- **WHEN** dataCache 有数据时调用 `EngineAPI.file.open("test.txt", "r")`
- **THEN** 返回可读文件 handle
- **WHEN** 调用 `EngineAPI.file.exists("non_existent")`
- **THEN** 返回 false
- **WHEN** 调用 `EngineAPI.file.lines("test.txt")`
- **THEN** 返回逐行迭代器
- **WHEN** 调用 `EngineAPI.file.getSize("test.txt")`
- **THEN** 返回字节数

#### Scenario: 数据加载完整性
- **WHEN** 检查 `dataCache._fileCount`
- **THEN** 值为 7
- **WHEN** 遍历 7 个 key：dialogues、scenes、chars、items、skills、entrances、wmap
- **THEN** 每个 key 在 dataCache 中存在且为 table
- **WHEN** 检查 `dataCachePaths` 映射
- **THEN** `data-web/name.json` 可正确映射到 `name`

#### Scenario: 跨文件引用正确性
- **WHEN** 遍历所有场景的 NPC 列表
- **THEN** 每个 `npc[i].id` 在 `chars` 表中存在对应人物
- **WHEN** 遍历所有场景的物品列表
- **THEN** 每个 `item[i].id` 在 `items` 表中存在对应物品
- **WHEN** 遍历所有入口数据
- **THEN** 每个 `sceneId` 在 `scenes` 表中存在对应场景

#### Scenario: 交互流程
- **WHEN** 在输入框中输入 "hello" 并回车
- **THEN** xterm 终端显示 "> hello"
- **WHEN** Lua 侧调用 `JSBridge.getEvent()`
- **THEN** 返回包含 `{type="input", data="hello"}` 的事件表

#### Scenario: 错误场景
- **WHEN** 调用 `EngineAPI.file.open("non_existent.txt", "r")`
- **THEN** 返回 nil
- **WHEN** 调用 `EngineAPI.script.load("non_existent.lua")`
- **THEN** 返回 nil, "Script not found: ..."
- **WHEN** 运行 `npm test`
- **THEN** 浏览器控制台无 error 级别消息
- **AND** 网络请求无失败记录