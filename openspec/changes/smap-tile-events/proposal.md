## 为什么

原版金庸群侠传的场景事件由格子触发——走过特定格子（extra字段）或按空格键（space字段）触发对应 oldevent 脚本。Web MUD 当前只列出了场景 JSON 中定义的 NPC/物品/出口，大量通过 events.json 定义的格子事件不可达。这导致许多游戏剧情和战斗无法触发。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/slice4-smap-interaction/change-manifest.md`
- 依赖: smap-menu-interaction, event-data-access

## What Changes

### 格子事件发现与列表
- `SmapHandlers.look` 新增列出当前场景中所有有触发器的格子事件（`events.json` 中 `space>0` 或 `extra>0` 的条目）
- 格子事件显示为 `N. 搜索`，与现有 "搜索" NPC 风格一致
- 已经通过 NPC 子菜单触发的格子事件不重复列出（`eventConsumed` 标记）

### 格子事件选择与执行
- `SmapHandlers.chooseInteraction` 新增 `tile_event` 类型处理
- 选择格子事件后，通过 `EventExecutor.oldCallEventCoroutine(eventId)` 执行 oldevent 脚本
- 执行后标记为已触发

### 与现有交互的协调
- NPC 和格子事件可能引用同一个 oldevent 脚本——通过 `eventConsumed` 避免重复列出
- 部分格子事件是战斗（`instruct_6`）——oldevent 脚本直接调 `instruct_6`，原版 jymain.lua 的实现在 MUD 中可用

## Scope Boundaries

### In Scope
- `SmapHandlers.look` 显示格子事件列表
- `SmapHandlers.chooseInteraction` 处理格子事件选择
- `events.json` 的 `space`/`extra` 字段解析
- 已触发事件的 `eventConsumed` 标记

### Out of Scope
- 修改 events.json 数据提取逻辑
- 修改 EventExecutor/oldevent 执行机制
- NPC 对话子菜单的修改

## Capabilities

### New Capabilities
- `smap-tile-events` [REQ-STE-001]: 格子事件发现、列出、选择、执行

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/engine-web/mmap_smap_handlers.lua` | SmapHandlers.look + chooseInteraction 扩展 |
| `game/engine-web/web_game_bridge.lua` | 无需修改 |
