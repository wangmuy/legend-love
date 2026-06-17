## 1. sceneState 实现
Traceability: [REQ-005]

- [ ] 1.1 创建 `_G.sceneState` 表 + 辅助函数
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] `getSceneState(sceneId)` 惰性初始化
    - [ ] `setNpcPresent(sceneId, charId, present)`
    - [ ] `isNpcPresent(sceneId, charId) → boolean`
    - [ ] `setItemCount(sceneId, itemId, count)`
    - [ ] `getItemCount(sceneId, itemId) → number`
    - [ ] `itemAvailable(sceneId, itemId) → boolean`

- [ ] 1.2 在 `look` 输出中集成状态过滤
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] `look` 只显示 `isNpcPresent` 为 true 的 NPC
    - [ ] `look` 只显示 `itemAvailable` 为 true 的物品
    - [ ] 输出提示如 "这里空无一人" 当所有 NPC 离场时

- [ ] 1.3 暴露状态更新接口供 talk/take 调用
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [ ] 辅助函数通过 `_G` 暴露（`rawset`），其它 change 可调用

## 2. 测试
Traceability: [REQ-005]

- [ ] 2.1 E2E 测试：NPC 离场后 look 不可见
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] 设置 NPC 状态为离场后，look 不再显示该 NPC

- [ ] 2.2 E2E 测试：物品拾取后 look 不可见
  Blast Radius: `["game/engine-web/tests/*"]`
  DoD:
    - [ ] 物品 count 设为 0 后，look 不再显示该物品
