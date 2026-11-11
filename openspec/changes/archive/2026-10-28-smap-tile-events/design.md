## Context

Web MUD 的场景交互 (`SmapHandlers.look`) 目前只列出场景 JSON 中显式定义的 NPC、物品和出口。但原版游戏中还有大量通过 `events.json` 定义的格子事件——玩家走过特定格子（`extra` 字段）或按空格键（`space` 字段）触发对应的 oldevent 脚本。这些事件在 MUD 中不可见、不可达，导致许多剧情和战斗无法触发。

## Goals / Non-Goals

**Goals:**
- 每进入场景时，列出所有未触发的格子事件
- 选择格子事件后执行对应的 oldevent 脚本
- 已触发的事件从列表中移除（`eventConsumed` 标记）

**Non-Goals:**
- 修改 EventExecutor 或 oldevent 执行机制
- 修改 events.json 数据格式
- 添加新交互类型（如"走格子"移动模式）

## Architecture Decision Records

### ADR-001: 格子事件合并到现有 entity 列表

- **Context**: `SmapHandlers` 已有一个 `smapEntityList` 数组 + `chooseInteraction` 路由系统。格子事件是另一种 entity 类型。
- **Decision**: 在 `SmapHandlers.look` 中，列举完 NPC/物品/出口后，再遍历 `events.json` 当前场景的条目，将有 `space>0` 或 `extra>0` 且未触发的加入 `smapEntityList`。
- **Consequences**: 与现有交互模式一致——用户用 `choose N` 选择。使用 `eventConsumed` 去重。

### ADR-002: 仅显示未触发的格子事件

- **Context**: 原版中格子事件触发后通常不会再触发（通过 D* 数据修改标记已触发）。
- **Decision**: 每次 `SmapHandlers.look` 时，检查 `eventConsumed[sceneId][eventId]`。已标记的不显示。NPC 对话也会标记事件，避免格子事件和 NPC 同时列出同一个 oldevent。
- **Consequences**: 玩家不会看到重复或已消失的事件。事件触发后需要显式执行 `eventConsumed` 标记才能彻底消失。

## 格子事件数据结构

```lua
-- events.json 条目结构
{
  sceneId: 1,       -- 场景 ID
  tileIndex: 0,     -- 格子索引
  passable: 1,      -- 是否可通行
  x: 24,            -- 场景 X 坐标
  y: 19,            -- 场景 Y 坐标
  space: 664,       -- 空格触发的事件 ID（-1 表示无）
  touch: -1,        -- 触摸触发（原版 unused）
  extra: -1,        -- 路过触发的事件 ID（-1 表示无）
}
```

## 交互流程

```
> look
  ... (NPC 列表)
  ... (物品列表)
  8. 搜索    ← tile event: space=668 (oldevent_668)
  9. 搜索    ← tile event: space=669 (oldevent_669)
  ...

> choose 8
  → 执行 oldevent_668
  → 标记 eventConsumed[sceneId][668] = true
  → 下次 look 不再显示
```

## Review Checklist

1. 进入河洛客栈后 look，能看到原 NPC 列表以外的"搜索"格子事件
2. 选择格子事件后执行 oldevent，无 gameLoop error
3. 已触发的事件不在后续 look 中重复显示
4. NPC 和格子事件引用同个 eventId 时不重复列出
