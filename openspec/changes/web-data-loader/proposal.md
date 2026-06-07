## 为什么

Slice 1 产出了 7 个 JSON 数据包，但 Web MUD 需要在浏览器中将这些 JSON
加载到 Lua 运行环境。Fengari 无法直接读取文件系统，需要 JS fetch 加载
JSON 字符串 → 传入 Lua → 解析为 Lua 表。

## 变更内容

- `www/engine/data_loader.lua` — JSON 加载、解析、存入全局表
- HTML/JS 中的 fetch 逻辑（作为 index.js 的一部分）

## 能力

### 新增能力
- `web-data-loader`: 从 JSON 文件加载数据到 Lua 表空间

### 修改的能力
- 无

## 影响

- 新增 `www/engine/data_loader.lua`
- 数据存入 `_G.dataCache` 全局表