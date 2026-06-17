## Context

NPC 离队和物品拾取后，`look` 需要过滤不可见对象。场景状态在游戏会话期间持续。

## Decisions

### `_G.sceneState` 结构
```lua
_G.sceneState = {
    [sceneId] = {
        npc = { [charId] = { present = true/false } },
        items = { [itemId] = { count = N } },
    },
}
```

### API
```lua
function getSceneState(sceneId)  -- 惰性初始化
function setNpcPresent(sceneId, charId, present)
function isNpcPresent(sceneId, charId) → boolean  -- 默认 true
function setItemCount(sceneId, itemId, count)
function getItemCount(sceneId, itemId) → number
function itemAvailable(sceneId, itemId) → boolean  -- count > 0
```

### 过滤逻辑
`SmapHandlers.look` 在构建编号列表时调用 `isNpcPresent` / `itemAvailable` 过滤。

### 初始化
`getSceneState(sceneId)` 在首次调用时创建 `{npc={}, items={}}`。

## Tests

- `isNpcPresent` 默认返回 true
- `setNpcPresent(id, false)` → `isNpcPresent` 返回 false
- `itemAvailable` 默认返回 true
- `setItemCount(id, 0)` → `itemAvailable` 返回 false

## Review Checklist

1. 所有单元测试通过
2. 无 gameLoop error
3. look 输出格式正确
4. choose N 不报错
