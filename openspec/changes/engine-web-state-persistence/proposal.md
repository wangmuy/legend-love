## 为什么

游戏脚本（jymain.lua 等）是游戏逻辑的唯一实现，使用中文键名操作游戏状态（如 `JY.Person[0]["攻击力"]=100`）。但提取的 JSON 数据使用英文键名（如 `attack`）。两者之间需要一个翻译层。

同时，Web MUD 需要能在浏览器中持久化游戏状态（存档/读档），但 Lua 侧没有文件系统能力，需要通过 JSBridge 访问浏览器的存储引擎。

## 变更内容

1. **字段名映射表** — 根据 CC.*_S 定义自动生成英文→中文键名映射，在 Lua 侧实现。
2. **loadGameState()** — 将 dataCache（英文键）转换为 JY.* 表（中文键），供游戏脚本直接读写。
3. **saveGameState()** — 将 JY.* 表（中文键）反向转换为英文键 JSON，传给 JSBridge 存储。
4. **JSBridge 存储接口** — 新增 `JSBridge.save(key, jsonStr)` 和 `JSBridge.load(key)`，底层使用 IndexedDB。
5. **存档槽管理** — 支持 3 个存档槽 + 自动存档。

## 能力

### 新增能力
- `fieldMap` Lua 表：每个结构体的英文→中文键名映射
- `loadGameState(slotId)` → 从 IndexedDB 恢复 JY.* 表
- `saveGameState(slotId)` → 序列化 JY.* 表到 IndexedDB
- `JSBridge.save(key, json)` / `JSBridge.load(key)` → IndexedDB 异步存储
- 3 个存档槽 + 1 个自动存档槽

### 修改的能力
- index.js：增加 JSBridge.save/load 的 IndexedDB 实现
- data_loader.lua：增加状态管理模块

## 影响

- engine-web/index.js — 新增 IndexedDB 存储逻辑
- engine-web/state_manager.lua — 新增状态管理器（映射 + 序列化）
- engine-web/tests/ — 新增状态持久化测试