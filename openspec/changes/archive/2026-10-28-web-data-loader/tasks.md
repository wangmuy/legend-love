## 1. JSON 解析器

- [x] 1.1 实现 `parseJSON(str)` — 递归下降 JSON 解析器
- [x] 1.2 支持 string（含转义字符）、number、boolean、null
- [x] 1.3 支持 object（`{key: value}`）和 array（`[elem, ...]`）
- [x] 1.4 支持嵌套结构（object 内嵌 array、object 等）
- [x] 1.5 E2E 测试：data-integrity.spec.js 验证 dialogues.json 等全部 10 个文件

## 2. 数据加载逻辑

- [x] 2.1 实现 `loadJSONChunk(cacheKey, jsonStr)` — 解析后写入 dataCache[cacheKey]
- [x] 2.2 实现批量加载：10 个 JSON 文件（data-web/*.json），JS 侧 fetch 后逐个注入（events.json 使用 JS JSON.parse 绕过 Lua 速度瓶颈）
- [x] 2.3 加载完成后 `finalizeDataLoad()` 设置 `_G.dataCache._loaded = true`
- [x] 2.4 错误处理：每个 loadJSONChunk 用 lua_pcall 保护，失败时跳警告并清空该 key

## 3. 验证

- [x] 3.1 E2E 测试：所有 10 个 key 存在且非空（data-integrity.spec.js）
- [x] 3.2 E2E 测试：场景 NPC 引用在 chars 中存在
- [x] 3.3 E2E 测试：D* 事件引用的场景 ID 在 scenes 中存在
- [x] 3.4 E2E 测试：entrances 场景 ID 在 scenes 中存在