## 1. JSON 解析器

- [ ] 1.1 实现 `parseJSON(str)` — 递归下降 JSON 解析器
- [ ] 1.2 支持 string（含转义字符）、number、boolean、null
- [ ] 1.3 支持 object（`{key: value}`）和 array（`[elem, ...]`）
- [ ] 1.4 支持嵌套结构（object 内嵌 array、object 等）
- [ ] 1.5 测试：解析 dialogues.json 的正确性

## 2. 数据加载逻辑

- [ ] 2.1 实现 `loadFromJSON(cacheKey, jsonStr)` 函数
- [ ] 2.2 实现批量加载：按顺序加载 7 个 JSON 文件
- [ ] 2.3 加载完成后设置 `_G.dataCache._loaded = true`
- [ ] 2.4 错误处理：JSON 解析失败时输出错误信息

## 3. 验证

- [ ] 3.1 在纯 Lua 环境测试：加载 dialogues.json，验证 2977 条
- [ ] 3.2 在纯 Lua 环境测试：加载 scenes.json，验证 84 个场景
- [ ] 3.3 在纯 Lua 环境测试：跨文件引用（NPC ID → chars）