## 0. dataCache → initDataSource 重命名
Traceability: [REQ-003]

- [ ] 0.1 全局重命名 `_G.dataCache` → `_G.initDataSource`
  Blast Radius: `["game/engine-web/*.lua", "game/engine-web/*.js", "game/engine-web/tests/*"]`
  DoD:
    - [ ] `data_loader.lua` 中 `_G.dataCache` 改为 `_G.initDataSource`
    - [ ] `state_manager.lua` 中 `dataCache` 引用全部更新
    - [ ] `mmap_smap_handlers.lua` 中 `dataCache` 引用更新
    - [ ] `web_game_bridge.lua` 中 `dataCache` 引用更新
    - [ ] `engine_web.lua` 中 `dataCache` 引用更新
    - [ ] `worker.js`/`index.js` 中 `dataCache` 引用更新
    - [ ] 测试文件中 `dataCache` 引用更新
    - [ ] 重命名后所有测试通过

## 1. GetD/SetD 实现（基于 JY.D）
Traceability: [REQ-003]

- [ ] 1.1 `GetD` 从 `JY.D{sceneId}` Lua 表读取
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] 首次访问场景时，从 `initDataSource.events` 将事件拷贝到 `JY.D{sceneId}`
    - [ ] `GetD(sceneId, eventId, field)` 返回 `JY.D{sceneId}[eventId][field]`
    - [ ] `JY.D{sceneId}` 不存在时自动创建
    - [ ] 未找到时返回 0（不崩溃）

- [ ] 1.2 `SetD` 写入 `JY.D{sceneId}`
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `SetD(sceneId, eventId, field, value)` 写入 `JY.D{sceneId}[eventId][field]`
    - [ ] 不崩溃

## 2. GetS/SetS 简化

- [ ] 2.1 `GetS`/`SetS` 实现
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `GetS(...)` 返回 0（场景格子数据在 MUD 中简化）
    - [ ] `SetS(...)` 不崩溃

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
