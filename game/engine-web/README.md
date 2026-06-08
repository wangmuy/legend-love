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

# 4. 启动本地服务器
npm start

# 5. 打开浏览器访问 http://localhost:8080
```

## 工作流

### 开发（CDN 模式，不需要 npm install）

```bash
cd game && lua tools/extract_web_data.lua
cd game/engine-web && python3 -m http.server 8080
```

`index.html` 默认引用 CDN 版本，无需 `node_modules`。

### 构建部署（本地 lib 模式）

```bash
cd game && lua tools/extract_web_data.lua
cd game/engine-web && npm install && npm run build
```

构建产物在 `dist/` 目录，所有第三方库从 `node_modules/` 复制到 `dist/lib/`，
`index.html` 自动切换为本地引用。

### 部署到 GitHub Pages

```bash
npm run build
npm run deploy
```

`dist/` 目录内容发布到 `gh-pages` 分支。

## 文件结构

```
engine-web/
├── package.json         ← npm 依赖和脚本
├── scripts/build.js     ← 构建脚本
├── index.html           ← 页面入口（默认 CDN 引用）
├── style.css            ← 暗色终端主题
├── index.js             ← Fengari 引导 + xterm.js + JS↔Lua 桥接
├── engine_web.lua       ← EngineAPI 的 Web 实现（37 个函数）
├── data_loader.lua      ← JSON 解析器 + 数据缓存
├── data-web/            ← 精简数据包（提取脚本生成，gitignored）
├── dist/                ← 构建产物（gitignored）
├── node_modules/        ← npm 依赖（gitignored）
└── lib/                 ← 第三方库（构建时复制）
```

## 命令参考

| 命令 | 说明 |
|------|------|
| `npm install` | 安装 xterm、fengari-web 等依赖 |
| `npm run build` | 构建到 `dist/` |
| `npm start` | 启动 `dist/` 目录的 HTTP 服务器 |
| `npm run deploy` | 发布 `dist/` 到 GitHub Pages |

## 技术栈

| 组件 | 用途 |
|------|------|
| Fengari | 浏览器内 Lua 5.3 VM |
| xterm.js | 终端模拟器 + FitAddon 自适应 |
| Love2D EngineAPI | 游戏引擎抽象接口 |
| game/framework/* | 游戏框架（与 Love2D 版共用） |
| game/script/* | 游戏脚本（与 Love2D 版共用） |