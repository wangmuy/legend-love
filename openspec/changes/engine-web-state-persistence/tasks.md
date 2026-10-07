# tasks — engine-web-state-persistence

## 1. 字段名映射表

- [x] 1.1 实现字段名映射模块（根据 CC.*_S 自动生成 fieldMap）
- [x] 1.2 实现 `toChineseKeys(record, structMap)` — 英文键→中文键
- [x] 1.3 实现 `toEnglishKeys(record, structMap)` — 中文键→英文键
- [x] 1.4 实现 `loadGameState(slotId)` — 从 IndexedDB 恢复完整游戏状态
- [x] 1.5 实现 `saveGameState(slotId)` — 将游戏状态序列化到 IndexedDB

## 2. JSBridge IndexedDB 存储

- [x] 2.1 在 index.js 中实现 IndexedDB 初始化（createObjectStore）
- [x] 2.2 实现 JSBridge.save(key, jsonStr) — 写入 IndexedDB + 内存缓存
- [x] 2.3 实现 JSBridge.load(key) — 从内存缓存读取（同步）
- [x] 2.4 实现 JSBridge.listSaves() / delete() — 列表和删除

## 3. 测试

- [x] 3.1 测试字段名映射双向正确性（toChineseKeys / toEnglishKeys）
- [x] 3.2 测试 save/load 往返（Lua → JSBridge → IndexedDB → Lua）
- [x] 3.3 测试存档槽隔离
- [x] 3.4 全量 14 测试通过