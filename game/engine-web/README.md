# 金庸群侠传 Web MUD — engine-web

基于 Fengari + xterm.js 的纯文字 MUD 版，在浏览器中运行金庸群侠传的游戏逻辑。

## 快速开始

```bash
# 1. 提取数据包（从原版二进制→JSON）
cd game && lua tools/extract_web_data.lua

# 2. 安装前端依赖
cd game/engine-web && npm install

# 3. 构建（复制文件到 dist/）
npm run build

# 4. 启动本地服务器（提供 dist/ 目录）
npm start

# 5. 打开浏览器访问 http://localhost:8088
```

## 工作流

### 开发（CDN 模式，不需要 npm install）

```bash
cd game && lua tools/extract_web_data.lua
cd game/engine-web && npm run dev
```

`index.html` 默认引用 CDN 版本，无需 `node_modules`。`npm run dev` 启动当前目录的 HTTP 服务器（通过 `npx serve`）。

### 构建部署（本地 lib 模式）

```bash
cd game && lua tools/extract_web_data.lua
cd game/engine-web && npm install && npm run build
```

构建产物在 `dist/` 目录，所有第三方库从 `node_modules/` 复制到 `dist/lib/`，
`index.html` 自动切换为本地引用。

### 测试

```bash
# 运行所有测试（自动启动 HTTP 服务器，端口 8088）
npm test

# 运行单个测试文件（推荐用于调试）
npx playwright test tests/s3-integration.spec.js

# 运行单个用例（指定行号）
npx playwright test tests/s3-integration.spec.js:218
```

Playwright E2E 测试覆盖页面加载、Lua VM、API、数据完整性、状态持久化、交互流程。

**注意事项**：

- **Worker 数量**：默认 `workers=1`（`playwright.config.js` 中配置）。集成测试涉及 Lua 协程 + IndexedDB 状态，
  并行执行会导致 IndexedDB 共享冲突或协程交错，务必使用单 worker。
- **超时设置**：完整流程测试（开始→属性确认→MMAP→场景）需 30s 以上。单用例超时已设为 30s，本地慢时可临时调大：
  ```bash
  # 例：单用例超时 60s
  npx playwright test tests/s3-integration.spec.js --timeout=60000
  ```
- **顺序执行**：如果持续超时，可以逐个用例运行排查：
  ```bash
  # 按行号运行，一次一个
  npx playwright test tests/s3-integration.spec.js:46
  npx playwright test tests/s3-integration.spec.js:109
  npx playwright test tests/s3-integration.spec.js:242
  ```
- **端口冲突**：测试服务器使用 8088 端口，如果上次运行未正常退出，先释放端口：
  ```bash
  fuser -k 8088/tcp
  ```
- **构建前置**：运行测试前需确保 `npm run build` 已执行，否则服务器会回退到源码目录。`npm test` 不自动构建。|

## 数据流

```
提取管线 (extract_*.lua)
    │  原版二进制 → 中文 key JSON
    ▼
data-web/*.json             ← 只读初始数据（git 跟踪）
    │  index.js fetch
    ▼
dataCache（Lua 表）          ← 只读引用
    │  initGameState()
    ▼
JY.* 表（Lua 表）            ← 游戏状态唯一源头
    │  saveGameState()  ↓  ↑  loadGameState()
    ▼
JSBridge → IndexedDB       ← 持久化层
```

**关键原则**：Lua 的 `JY.*` 表是游戏状态的唯一持有者。JS 只提供 I/O 和存储管道，不碰游戏状态。

## 数据文件

data-web/ 目录由提取管线生成，全部为**只读初始数据/模板**，游戏运行时不改写：

| 文件 | 内容 | 说明 |
|------|------|------|
| `chars.json` | 人物初始属性（攻击力、武功、携带物品等） | 全部使用中文 key，匹配 CC.Person_S |
| `items.json` | 物品定义（名称、效果、需求、配方） | 中文 key，匹配 CC.Thing_S |
| `skills.json` | 武功定义（类型、伤害范围、消耗） | 中文 key，匹配 CC.Wugong_S |
| `scenes.json` | 场景配置（入口/出口坐标、NPC、事件） | 嵌套结构，`initGameState()` 展平 |
| `config.json` | 初始状态（主角位置、物品栏、队伍） | 嵌套结构，`initGameState()` 展平 |
| `shops.json` | 商店物品清单 | 中文 key |
| `events.json` | D* 场景事件（20000 条） | JS JSON.parse 加速加载 |
| `dialogues.json` | NPC 对话文本 | 原版格式 |
| `entrances.json` | 场景入口查找表 | 引擎内部使用 |
| `wmap.json` | 战斗事件配置 | 引擎内部使用 |

提取管线使用 CC.*_S（jyconst.lua）中定义的结构体偏移量解析二进制文件。
任何对原版游戏数据的修改，只需重新运行 `lua tools/extract_web_data.lua` 即可同步。

## 状态持久化

`state_manager.lua` 管理游戏存档：

- `initGameState()` — dataCache → JY.* 初始化（场景展平、结构转换）
- `saveGameState(slotId)` — 序列化 JY.* 到 JSON → JSBridge → IndexedDB
- `loadGameState(slotId)` — IndexedDB → JSON → JSBridge → JY.* 恢复
- `listSaveSlots()` / `deleteSaveSlot()` — 存档管理
- 4 个槽位：槽 0 自动存档 + 槽 1~3 手动存档

存档格式使用中文 key，与游戏脚本读写一致，无需映射。

## 文件结构

```
engine-web/
├── package.json              ← npm 依赖和脚本
├── playwright.config.js      ← E2E 测试配置
├── scripts/build.js          ← 构建脚本
├── scripts/start-test-server.js  ← 测试用 HTTP 服务器
├── index.html                ← 页面入口（默认 CDN 引用）
├── style.css                 ← 暗色终端主题
├── index.js                  ← Fengari 引导 + xterm.js + JSBridge + IndexedDB
├── engine_web.lua            ← EngineAPI Web 实现（45 个函数）
├── data_loader.lua           ← JSON 解析器 + 数据缓存
├── state_manager.lua         ← 状态持久化 + initGameState
├── data-web/                 ← 数据包（提取生成，git 跟踪）
├── dist/                     ← 构建产物（gitignored）
│   ├── lib/                  ← 第三方库拷贝
│   └── data-web/             ← data-web 的构建副本
├── tests/                    ← Playwright E2E 测试
│   ├── helpers/              ← 测试辅助（luaEval, waitForPageReady）
│   ├── page-load.spec.js     ← 页面加载基础
│   ├── lua-vm.spec.js        ← Lua VM 初始化
│   ├── engine-api.spec.js    ← API 表面 + 功能
│   ├── data-integrity.spec.js← 数据完整性校验
│   ├── interaction.spec.js   ← 交互流程
│   ├── error-handling.spec.js← 错误场景
│   └── state-persistence.spec.js ← 状态持久化
└── node_modules/             ← npm 依赖（gitignored）
```

## 命令参考

| 命令 | 说明 |
|------|------|
| `npm install` | 安装依赖（xterm、fengari-web、playwright 等） |
| `npm run dev` | 开发服务器（CDN 模式，提供当前目录） |
| `npm run build` | 构建到 `dist/` |
| `npm start` | 启动 `dist/` 目录的 HTTP 服务器 |
| `npm run deploy` | 发布 `dist/` 到 GitHub Pages |
| `npm test` | 启动测试服务器 + Playwright E2E 测试 |

## 技术栈

| 组件 | 用途 |
|------|------|
| Fengari | 浏览器内 Lua 5.3 VM |
| xterm.js | 终端模拟器 + FitAddon 自适应 |
| IndexedDB | 浏览器持久化存储 |
| Playwright | E2E 自动化测试 |
| Love2D EngineAPI | 游戏引擎抽象接口 |
| game/framework/* | 游戏框架（与 Love2D 版共用） |
| game/script/* | 游戏脚本（与 Love2D 版共用） |