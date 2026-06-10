# tasks — engine-web-state-persistence

## 1. 字段名映射表

- [ ] 1.1 实现字段名映射模块（根据 CC.*_S 自动生成 fieldMap）
- [ ] 1.2 实现 `toChineseKeys(record, structMap)` — 英文键→中文键
- [ ] 1.3 实现 `toEnglishKeys(record, structMap)` — 中文键→英文键
- [ ] 1.4 实现 `loadGameState(slotId)` — 从 IndexedDB 恢复完整游戏状态
- [ ] 1.5 实现 `saveGameState(slotId)` — 将游戏状态序列化到 IndexedDB

## 2. JSBridge IndexedDB 存储

- [ ] 2.1 在 index.js 中实现 IndexedDB 初始化（createObjectStore）
- [ ] 2.2 实现 JSBridge.save(key, jsonStr) — 异步写入 IndexedDB
- [ ] 2.3 实现 JSBridge.load(key) — 从 IndexedDB 读取（通过 coroutine 异步转同步）
- [ ] 2.4 实现 JSBridge.listSaves() — 列出所有存档槽位

## 3. 测试

- [ ] 3.1 测试字段名映射双向正确性
- [ ] 3.2 测试 save/load 往返（Lua → JSBridge → IndexedDB → Lua）
- [ ] 3.3 测试存档槽隔离
- [ ] 3.4 全量测试通过