## 为什么

Slice 1 产出了 JSON 数据，但现在这些数据只能在 Love2D 环境中查看。Slice 2 搭建 Web MUD 的运行时环境：
浏览器里加载 Fengari → 实现 EngineAPI 的 Web 版本 → 加载 JSON 数据包 → Lua VM 就绪。

## 变更内容

- `game/engine-web/index.html` — 页面骨架，xterm.js 终端 + 输入区
- `game/engine-web/index.js` — Fengari bootstrap、JS ↔ Lua 桥接、事件队列、requestAnimationFrame 驱动
- `game/engine-web/engine_web.lua` — 37 个 EngineAPI 函数的 Web 实现
- `game/engine-web/data_loader.lua` — JSON 数据包加载到 Lua 表
- `game/engine-web/package.json` — npm 依赖管理（xterm、fengari-web、@xterm/addon-fit）
- `game/engine-web/scripts/build.js` — 构建脚本，产出 `dist/` 目录
- `game/engine-web/.gitignore` — 忽略 node_modules、dist、data-web
- 数据依赖：`game/engine-web/data-web/`（从提取脚本产出）

## 能力

### 新增能力
- `engine-web-core`: 37 个 EngineAPI 函数的 Web 实现
- `web-frontend-shell`: 浏览器终端界面（xterm.js + Fengari + FitAddon + npm 构建流程）
- `web-data-loader`: JSON 数据包加载到 Lua 运行环境
- `engine-web-tests`: 44 条 Playwright E2E 测试用例覆盖 8 个层次

### 修改的能力
- 无（纯新增）

## 影响

- 新增 `game/engine-web/` 目录（静态网站）
- 新增 `game/engine-web/engine_web.lua`（EngineAPI 实现）
- 新增 `game/engine-web/index.html` + `game/engine-web/index.js`（前端入口）
- 新增 `game/engine-web/package.json` + `scripts/build.js`（npm 构建流程）
- 依赖 fengari-web.js、xterm.js、@xterm/addon-fit（CDN 或 npm 包）
- `npm run build` 产出 `dist/`，`npm run deploy` 发布 GitHub Pages