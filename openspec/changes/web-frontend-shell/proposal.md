## 为什么

engine_web.lua 和 data_loader.lua 需要一个浏览器运行环境。需要搭建
HTML 页面、加载 Fengari Lua VM、配置 xterm.js 终端、建立 JS ↔ Lua 桥接。

## 变更内容

- `game/engine-web/index.html` — 页面骨架，xterm.js 终端容器
- `game/engine-web/style.css` — 暗色终端风格
- `game/engine-web/index.js` — Fengari bootstrap、xterm.js 配置（含 FitAddon）、事件队列、requestAnimationFrame 循环
- `game/engine-web/lib/` — fengari-web.js 和 xterm.js 库文件（开发用 CDN，构建时复制到 dist）
- `game/engine-web/package.json` — npm 依赖（xterm、fengari-web、@xterm/addon-fit）
- `game/engine-web/scripts/build.js` — 构建脚本（复制文件到 dist/，CDN→本地路径替换）
- `game/engine-web/.gitignore` — 忽略 node_modules、dist、data-web

## 能力

### 新增能力
- `web-frontend-shell`: 浏览器终端界面（xterm.js + Fengari + JS 桥接 + FitAddon + npm 构建流程）

### 修改的能力
- 无

## 影响

- 新增 `game/engine-web/index.html`
- 新增 `game/engine-web/style.css`
- 新增 `game/engine-web/index.js`
- 新增 `game/engine-web/lib/`（或使用 CDN）
- 新增 `game/engine-web/package.json` + `scripts/build.js` + `.gitignore`
- 依赖 fengari-web.js、xterm.js、@xterm/addon-fit
- `npm run build` → `dist/` 目录产出可部署静态文件