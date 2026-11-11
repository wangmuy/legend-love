## Context

NPC 对话和物品拾取会改变场景状态。NPC 可能离队、物品可能被拿走。如果不跟踪这些状态，`look` 会显示已经不存在的 NPC 和物品，破坏沉浸感。场景状态需要在游戏会话期间持续有效（不需要跨存档持久化——Slice 6 处理）。

## Goals / Non-Goals

**Goals:**
- `_G.sceneState` 表的结构和初始化
- NPC 在场/离场状态跟踪
- 物品可用数量跟踪
- `look` 命令过滤不可见 NPC/物品
- 事件驱动状态更新接口

**Non-Goals:**
- 存档/读档（Slice 6）
- 全局变量管理

## Architecture Decision Records

### ADR-001: sceneState 作为 Lua 全局表

- **Context**: 需要多个 change（talk, take, look）都能访问场景状态。
- **Decision**: `_G.sceneState = {}` 作为全局表，各 change 通过 `rawget(_G, "sceneState")` 访问。
- **Consequences**: 使用 `rawget/rawset` 访问（Worker 的 `__index` 元表）。

### ADR-002: 惰性初始化

- **Context**: 不是所有场景都有状态变化，提前初始化所有场景浪费内存。
- **Decision**: `getSceneState(sceneId)` 函数在首次访问时初始化该场景的状态。
```lua
function getSceneState(sceneId)
    local ss = rawget(_G, "sceneState")
    if not ss then ss = {}; rawset(_G, "sceneState", ss) end
    if not ss[sceneId] then ss[sceneId] = { npc = {}, items = {} } end
    return ss[sceneId]
end
```

## Data Structures

```lua
_G.sceneState = {
    [sceneId] = {
        npc = {
            [charId] = { present = true },  -- false 表示已离场
        },
        items = {
            [itemId] = { count = 1 },  -- 0 表示已拾取
        },
    },
}
```

## API

```lua
-- NPC 状态
function setNpcPresent(sceneId, charId, present)
function isNpcPresent(sceneId, charId)  -> boolean

-- 物品状态
function setItemCount(sceneId, itemId, count)
function getItemCount(sceneId, itemId)  -> number
function itemAvailable(sceneId, itemId) -> boolean (count > 0)
```

## Integration

- `web-smap-talk`: 对话完成后通过事件或显式调用 `setNpcPresent(sceneId, charId, false)` 标记离场
- `web-smap-item`: 拾取后调用 `setItemCount(sceneId, itemId, 0)` 标记不可用
- `mmap_smap_handlers.lua` 的 `look`: 调用 `isNpcPresent` / `itemAvailable` 过滤输出
