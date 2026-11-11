## 1. 格子事件列表
Traceability: [REQ-STE-001]

- [x] 1.1 `SmapHandlers.look` 列出格子事件
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] 遍历当前场景的 events.json 条目
    - [x] 只显示 `space>0` 或 `extra>0` 的事件
    - [x] 跳过已触发（eventConsumed）的事件
    - [x] 显示为 "N. 搜索" 格式

- [x] 1.2 与现有 NPC/物品列表协调
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] 格子事件列表排在 NPC 和物品列表之后
    - [x] NPC 触发后标记 eventConsumed，格子事件不再重复显示
    - [x] 无重复或遗漏

## 2. 格子事件选择与执行
Traceability: [REQ-STE-001]

- [x] 2.1 `SmapHandlers.chooseInteraction` 处理 tile_event 类型
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `type == "tile_event"` 时执行 `EventExecutor.oldCallEventCoroutine(eventId)`
    - [x] 执行后标记 `eventConsumed[sceneId][eventId] = true`
    - [x] 执行后重新调 `SmapHandlers.look({})` 刷新场景
    - [x] 无 gameLoop error
