## 0. dataCache → initDataSource 重命名
Traceability: [REQ-003]

- [x] 0.1 全局重命名 `_G.dataCache` → `_G.initDataSource`
  Blast Radius: `["game/engine-web/*.lua", "game/engine-web/*.js", "game/engine-web/tests/*"]`
  DoD:
    - [x] `data_loader.lua` 中 `_G.dataCache` 改为 `_G.initDataSource`
    - [x] `state_manager.lua` 中 `dataCache` 引用全部更新
    - [x] `mmap_smap_handlers.lua` 中 `dataCache` 引用更新
    - [x] `web_game_bridge.lua` 中 `dataCache` 引用更新
    - [x] `engine_web.lua` 中 `dataCache` 引用更新
    - [x] `worker.js`/`index.js` 中 `dataCache` 引用更新
    - [x] 测试文件中 `dataCache` 引用更新
    - [x] 重命名后所有测试通过

## 1. GetD/SetD 实现（基于 JY.D）
Traceability: [REQ-003]

- [x] 1.1 `GetD` 从 `JY.D{sceneId}` Lua 表读取
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] 首次访问场景时，从 `initDataSource.events` 将事件拷贝到 `JY.D{sceneId}`
    - [x] `GetD(sceneId, eventId, field)` 返回 `JY.D{sceneId}[eventId][field]`
    - [x] `JY.D{sceneId}` 不存在时自动创建
    - [x] 未找到时返回 0（不崩溃）

- [x] 1.2 `SetD` 写入 `JY.D{sceneId}`
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `SetD(sceneId, eventId, field, value)` 写入 `JY.D{sceneId}[eventId][field]`
    - [x] 不崩溃

## 2. GetS/SetS 简化

- [x] 2.1 `GetS`/`SetS` 实现
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `GetS(...)` 返回 0（场景格子数据在 MUD 中简化）
    - [x] `SetS(...)` 不崩溃

## 3. 测试

- [ ] 3.1 GetD 测试
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] `GetD(70, 0, 19, 20, 5)` 返回有效值或 0
    - [ ] 不崩溃

- [ ] 3.2 dataCache 重命名后无遗留引用
  Blast Radius: `["game/engine-web/*"]`
  DoD:
    - [ ] `grep "dataCache" game/engine-web/*.lua` 无输出
