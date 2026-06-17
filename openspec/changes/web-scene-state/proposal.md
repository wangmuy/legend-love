## 为什么

NPC 对话和物品拾取会改变场景状态——胡斐离开客栈后就不再出现了、酒被拿走后就没了。如果 `look` 不反映这些变化，玩家会看到已经不在的 NPC 和被拿走的物品，破坏沉浸感。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice 4: `openspec/changes/slice4-smap-interaction/change-manifest.md`
- 依赖：web-smap-talk, web-smap-item

## What Changes

1. `_G.sceneState` 表管理场景动态状态
2. NPC 状态：`present = true/false`（由 oldevent 的 instruct_54 等驱动）
3. 物品状态：`count = N`（由 take 和 instruct_32 等驱动）
4. `look` 命令输出时过滤已离场 NPC 和已拾取物品
5. 状态结构：
```lua
_G.sceneState = {
    [sceneId] = {
        npc = { [charId] = { present = true/false } },
        items = { [itemId] = { count = N } },
    }
}
```

## Scope Boundaries

### In Scope
- `_G.sceneState` 全局表的初始化和访问
- NPC 在场/离场状态跟踪
- 物品可用数量跟踪
- `look` 命令过滤不可见 NPC/物品
- 事件驱动状态更新（instruct_32 additem, instruct_54 join/leave）

### Out of Scope
- 永久存档（Slice 6，当前仅内存中保持）
- 全局 NPC 状态（仅场景内 NPC）

## Impact

| 文件 | 改动 |
|------|------|
| `mmap_smap_handlers.lua` | look 处理器增加状态过滤；新增场景状态辅助函数 |
| `web_game_bridge.lua` | 事件驱动的状态更新 hook |
| `tests/` | 新增场景状态 E2E 测试 |
