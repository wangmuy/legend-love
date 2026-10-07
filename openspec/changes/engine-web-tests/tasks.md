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

## 8. 测试基础设施优化

- [x] 8.1 修复 interaction.spec.js：改用全 buffer 读取，移除不存在的 enqueueEvent 调用
- [x] 8.2 新增 scripts/global-teardown.js：测试结束后 fuser -k 8088/tcp 清理端口
- [x] 8.3 playwright.config.js 添加 globalTeardown 配置
- [x] 8.4 scripts/start-test-server.js 添加 SIGINT/SIGTERM 信号处理
- [x] 8.5 package.json 简化 test/test:ui 脚本（由 playwright webServer 管理服务器生命周期）

## 9. Walkthrough 基础测试基础设施

- [x] 9.1 创建 `helpers/walkthrough.js`：saveTestState / loadTestState / gotoScene / flushSaveCache / loadSaveCache
- [x] 9.2 创建 `helpers/term.js`：cmd / getT / noE 终端操作助手
- [x] 9.3 `gotoScene` 实现：leave→choose0→list→search→navigate→verify
- [x] 9.4 `loadTestState` 纯 `loadGameState` 实现，无 hack
- [x] 9.5 bridge cache 链式传递机制（P1→bridge-p1.json→P2→...）

## 10. Walkthrough E2E 测试（P1-P7）

### P1：开局→南贤→田伯光→闫基→铁掌→段誉→无量山洞
- [x] 10.1 开局：choose 1 → 确认属性 → leave → MMAP → 存档
- [x] 10.2 南贤对话：gotoScene→对话→返回→存档
- [x] 10.3 田伯光加入：NPC对话→instruct_9→选"是"→返回→存档
- [x] 10.4 闫基战斗：tile event→战斗→胜利→返回→存档
- [x] 10.5 铁掌帮：导航→探索→返回→存档
- [x] 10.6 段誉加入：NPC对话→instruct_9→选"是"→存档
- [x] 10.7 无量山洞：导航→存档

### P2：回族部落→胡斐加入→冰火岛→绝情谷→大轮寺
- [x] 10.8 回族部落：导航→探索→返回
- [x] 10.9 胡斐加入：NPC对话→选"是"→存档
- [x] 10.10 冰火岛：导航→探索→返回
- [x] 10.11 绝情谷：导航→探索→存档
- [x] 10.12 大轮寺：导航→探索→返回

### P3：百花谷→绝情谷底→古墓→燕子坞→泰山派
- [x] 10.13 百花谷：导航→探索
- [x] 10.14 绝情谷底：导航→探索→存档
- [x] 10.15 古墓：导航→探索
- [x] 10.16 燕子坞：导航→探索→存档
- [x] 10.17 泰山派：导航→探索

### P4：苗人凤→蝴蝶谷→程瑛→黑龙潭→一灯居→闫基居
- [x] 10.18 苗人凤居：导航→探索
- [x] 10.19 蝴蝶谷：导航→探索
- [x] 10.20 程瑛居：导航→探索→存档
- [x] 10.21 黑龙潭：导航→探索
- [x] 10.22 一灯居：导航→探索
- [x] 10.23 闫基居：导航→探索→存档

### P5：药王庄→金轮寺→明教→光明顶→华山→金蛇洞→武当→嵩山
- [x] 10.24 药王庄：导航→探索→存档
- [x] 10.25 金轮寺：导航→探索
- [x] 10.26 明教分舵：导航→探索
- [x] 10.27 光明顶：导航→探索→存档
- [x] 10.28 华山派：导航→探索
- [x] 10.29 金蛇洞：导航→探索
- [x] 10.30 武当山：导航→探索
- [x] 10.31 嵩山派：导航→探索→存档（含战斗处理）

### P6：神龙教→破庙→成昆→沙漠→北丑→灵蛇→渤泥→侠客
- [x] 10.32 神龙教：导航→探索
- [x] 10.33 破庙：导航→探索→存档
- [x] 10.34 成昆居：导航→探索
- [x] 10.35 沙漠废墟：导航→探索
- [x] 10.36 北丑居：导航→探索→存档
- [x] 10.37 灵蛇岛：导航→探索
- [x] 10.38 渤泥岛：导航→探索
- [x] 10.39 侠客岛：导航→探索→存档

### P7：福威→天宁→梅庄→黑木崖→丐帮→桃花岛→主角居
- [x] 10.40 福威镖局：导航→探索
- [x] 10.41 天宁寺：导航→探索→存档
- [x] 10.42 梅庄：导航→探索
- [x] 10.43 黑木崖：导航→探索
- [x] 10.44 丐帮：导航→探索→存档
- [x] 10.45 桃花岛：导航→探索
- [x] 10.46 主角居：导航→探索

### 数据修复
- [x] 10.47 state_manager.lua：save/load 默认值处理
- [x] 10.48 wmap_handlers.lua：战斗系统3个bug修复（攻击距离、伤害公式、属性缺失）
- [x] 10.49 web_game_bridge.lua：HEAD_NAME_MAP 添加 [4]="阎基"
