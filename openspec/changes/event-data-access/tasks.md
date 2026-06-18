## 1. GetD/SetD 实现
Traceability: [REQ-003]

- [ ] 1.1 `GetD` 从 dataCache.events 查找
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `GetD(sceneId, layer, x, y, field)` 返回对应字段值
    - [ ] 未找到时返回 0
    - [ ] 不崩溃

- [ ] 1.2 `SetD` 写入运行时状态
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [ ] `SetD(...)` 不崩溃

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
