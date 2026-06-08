# 金庸群侠传 Web MUD — engine-web

基于 Fengari + xterm.js 的纯文字 MUD 版，在浏览器中运行金庸群侠传的游戏逻辑。

## 运行方式

### 1. 构建数据包

```bash
cd game && lua tools/extract_web_data.lua
```

将原版二进制数据提取为 JSON 精简包，输出到 `engine-web/data-web/`。

### 2. 启动静态服务器

在 `game/engine-web/` 目录启动任意静态文件服务器：

```bash
# Python
cd game/engine-web && python3 -m http.server 8080

# Node
cd game/engine-web && npx serve .

# 或复制到任意 web 服务器目录
```

### 3. 打开浏览器

访问 `http://localhost:8080` 即可看到终端界面。

## 数据更新

游戏脚本或二进制数据有变动时，重新运行第一步即可刷新数据包：

```bash
cd game && lua tools/extract_web_data.lua
```

## 文件结构

```
engine-web/
├── index.html          ← 页面入口
├── style.css           ← 暗色终端主题
├── index.js            ← Fengari 引导 + xterm.js + JS↔Lua 桥接
├── engine_web.lua      ← EngineAPI 的 Web 实现（37 个函数）
├── data_loader.lua     ← JSON 解析器 + 数据缓存
├── data-web/           ← 精简数据包（提取脚本生成）
└── lib/                ← 第三方库目录
```

## 技术栈

| 组件 | 用途 |
|------|------|
| Fengari | 浏览器内 Lua 5.3 VM |
| xterm.js | 终端模拟器 |
| Love2D EngineAPI | 游戏引擎抽象接口 |
| game/framework/* | 游戏框架（与 Love2D 版共用） |
| game/script/* | 游戏脚本（与 Love2D 版共用） |