## Context

Slice 3 实现了从开始菜单到大地图再到场景入口的完整流程。玩家可以进入场景、`look`/`exits`/`go`/`leave`。但场景内交互——与 NPC 对话、拾取物品、查看对象——仍是空白。Slice 3 的 `go`/`where` 已合并简化，SMAP 使用与 MMAP 一致的菜单驱动模式。

## Goals / Non-Goals

**Goals:**
- `look` 输出编号列表（NPC/物品/出口），替代独立 `talk`/`take`/`give` 命令
- `choose N` 在 SMAP 中做级联菜单交互（NPC→子菜单、物品→子菜单、出口→传送）
- NPC 对话通过 `EventExecutor.startEvent` 触发 oldevent 脚本
- 场景状态管理（`_G.sceneState`）：NPC 离场、物品拾取后 `look` 中不可见
- `instruct_0`/`instruct_1`/`WaitKey` 等 oldevent 兼容函数

**Non-Goals:**
- 战斗系统（Slice 5）
- 角色状态面板（Slice 6）
- 存档读档（Slice 6）
- 全局物品栏 UI（Slice 6）

## Architecture Decision Records

### ADR-001: 菜单驱动交互替代独立命令

- **Context**: 原始的 `talk`/`take`/`give` 命令要求用户记忆命令名和精确输入中文名。与 MMAP 的 `list` → `choose N` 模式不一致。
- **Decision**: 删除独立 `talk`/`take`/`give` 命令。`look` 输出编号列表，`choose N` 做级联菜单选择。交互统一走 `choose N`。
- **Consequences**: 用户不需要记忆命令。新增 `smapEntityList` 本地表跟踪当前场景的交互对象。

### ADR-002: 场景状态惰性初始化

- **Context**: 不是所有场景都有状态变化。提前初始化所有场景浪费内存。
- **Decision**: `getSceneState(sceneId)` 在首次访问时创建场景状态。`isNpcPresent` 默认返回 `true`（未设置时 NPC 存在）。
- **Consequences**: 零额外内存开销。DP 检查默认存在。通过 `setNpcPresent(id, false)` 标记离场。

### ADR-003: oldevent 兼容函数通过 rawset 注册

- **Context**: `jymain.lua` 的 `SetGlobal()` 会设置 `setmetatable(_G, {__index=error})`。此后通过 `_G.xxx` 写新全局变量会触发 `__newindex=error`。
- **Decision**: 使用 `rawset(_G, "instruct_0", ...)` 在 `initWebFramework` 之前注册全局函数。
- **Consequences**: 函数在 `setmetatable` 之前存在于 `_G` 中，后续 `_G.instruct_0()` 直接查找已存在的键，不触发 `__index`。

## Negative Constraints

- 不修改 `game/framework/` 下的任何文件
- 不修改 `game/script/` 下的任何文件
- 不修改 `game/engine-web/index.js` 或 `worker.js`
- 不引入新的第三方依赖

## Alignment Check

无冲突。本 change 新增 SMAP 交互逻辑都在 `mmap_smap_handlers.lua` 和 `web_game_bridge.lua` 中，不干扰框架核心流程。

## Decisions

### SMAP 交互数据流

```
look → 读取 scene["NPC"]/["物品"]/["出口"]
     → 过滤（isNpcPresent/itemAvailable）
     → 填充 smapEntityList[{type, name, ...}]
     → 输出编号列表

choose N → smapEntityList[N]
  type=npc  → CE.showMenu({对话,查看})
               对话 → smapNpcTalk → EventExecutor.startEvent
               查看 → getCharsIndex → 输出描述
  type=item → CE.showMenu({拾取,查看})
               拾取 → smapTakeItem → 背包写入 + setItemCount
               查看 → items.json → 输出描述
  type=exit → SmapHandlers.go({N})
```

### sceneState API

```lua
_G.sceneState = { [sceneId] = { npc = {}, items = {} } }
getSceneState(sceneId) → 惰性初始化
setNpcPresent(sceneId, charId, present)
isNpcPresent(sceneId, charId) → boolean (默认 true)
setItemCount(sceneId, itemId, count)
getItemCount(sceneId, itemId) → number
itemAvailable(sceneId, itemId) → boolean (count > 0)
```

### instruct 函数

```lua
instruct_0()       → WebUI.separator()
instruct_1(tid,h)  → dataCache.dialogues[tid][h] → WebUI.write()
WaitKey()          → "按回车继续..." → scheduler:waitForKey()
```

## Risks / Trade-offs

- NPC 对话依赖 `EventExecutor.startEvent`，需要 oldevent 脚本在 Worker 环境中可运行。当前未测试完整 oldevent 执行路径。
- `scheduler:waitForKey()` 需要在协程中调用，如果事件脚本不是通过 `EventExecutor` 启动的协程，`WaitKey` 会阻塞。

## Review Checklist

1. `look` 在 SMAP 状态输出编号列表（NPC/物品/出口），末尾有 `"输入 choose <编号> 选择交互对象"` 提示
2. `choose N` → NPC → 子菜单包含对话/查看/给予物品
3. `choose N` → 物品 → 子菜单包含拾取/查看
4. `choose N` → 出口 → 直接传送，无 gameLoop error
5. 场景状态：`setNpcPresent(id, false)` 后 `look` 不再显示该 NPC

## Migration Plan

本 change 不涉及数据迁移。新增代码在 `mmap_smap_handlers.lua` 和 `web_game_bridge.lua` 中，不影响现有功能。SMAP 命令表已移除 `talk`/`take`/`give` 条目，`help` 中不再显示。

## Open Questions

- `waitForKey()` 在 `luaEval` 测试中无法实际等待，通过存在性测试验证。
- 完整 NPC 对话 oldevent 执行需要场景中有具体 NPC 数据才能 E2E 测试。
