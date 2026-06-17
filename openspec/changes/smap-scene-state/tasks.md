## 1. sceneState 实现
Traceability: [REQ-003]

- [x] 1.1 `_G.sceneState` 表 + 惰性初始化
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `getSceneState(sceneId)` 首次访问创建状态

- [x] 1.2 NPC 状态 API
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `setNpcPresent(sceneId, charId, present)`
    - [x] `isNpcPresent(sceneId, charId)` 默认 true

- [x] 1.3 物品状态 API
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `setItemCount(sceneId, itemId, count)`
    - [x] `getItemCount(sceneId, itemId)`
    - [x] `itemAvailable(sceneId, itemId)`

## 2. look 过滤
Traceability: [REQ-003]

- [x] 2.1 `SmapHandlers.look` 过滤 NPC/物品
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `isNpcPresent` 为 false 的 NPC 不显示
    - [x] `itemAvailable` 为 false 的物品不显示
    - [x] 全部不可见时输出 "这里什么都没有。"

## 3. 测试
Traceability: [REQ-003]

- [x] 3.1 isNpcPresent 默认 true
- [x] 3.2 setNpcPresent 后状态正确
- [x] 3.3 itemAvailable 默认 true
- [x] 3.4 setItemCount 后状态正确
