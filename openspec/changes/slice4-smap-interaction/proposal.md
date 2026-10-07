## 为什么

Slice 3 实现了大地图漫游和场景的基础入口，但场景内交互——与 NPC 对话、触发事件、拾取物品——还是空白。玩家进入场景后只能 `look` 和 `exits`，无法推动游戏剧情。

Slice 4 补全场景内的核心交互。与 Slice 3 的 MMAP 一致，采用 **菜单驱动模式**：`look` 显示可交互对象的编号列表，`choose N` 做二级操作选择。用户不需要记忆 `talk`/`take`/`give` 等命令名，也不需要精确输入中文名。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- 位于 Slice 3 + Web Worker 架构重构之后
- 依赖：Slice 3（MMAP/SMAP 基础命令、协程调度器、菜单系统）

## What Changes

### 交互模式
```
> look
明教分舵
════════
这是一间客栈...
────────────────────────
NPC: 1. 胡斐  2. 田伯光
物品: 3. 白酒
出口: 4. 明教地道  5. 客房
输入 choose N 选择交互对象

> choose 1
胡斐:
  1. 对话
  2. 查看
  3. 给予物品
输入 choose N 选择操作

> choose 1
你与 胡斐 交谈...
```

### 场景交互（web-smap-talk + web-smap-item 合并）
- `look` 增强：输出编号列表（NPC/物品/出口），不再需要 `talk`/`take`/`give` 独立命令
- `choose N` 在 SMAP 状态下做级联菜单：
  - 选择 NPC → 子菜单（对话/查看/给予物品）
  - 选择物品 → 子菜单（拾取/查看）
  - 选择出口 → 直接传送（同 `go <编号>`）
- NPC 对话执行 oldevent 事件
- 对话中 `instruct_1` 输出文本 + `WaitKey` 等待继续
- `instruct_0` 输出分隔线

### 场景状态（web-scene-state）
- `_G.sceneState` 表跟踪 NPC/物品动态状态
- NPC 离场后 `choose` 列表中不再显示
- 物品被拾取后 `choose` 列表中不再显示
- 状态变更由 oldevent 事件驱动

## Scope Boundaries

### In Scope
- `look` 增强为交互式编号列表（代替独立 talk/take/give 命令）
- `choose N` 级联菜单（NPC 子菜单/物品子菜单/出口传送）
- NPC 对话 → oldevent 事件执行
- 场景状态管理（`_G.sceneState`）
- 对话文本输出（`instruct_1` 适配）
- 事件中 WaitKey/ShowMenu 的 Web MUD 适配

### Out of Scope
- 战斗系统（Slice 5）
- 角色状态面板（Slice 6）
- 存档读档（Slice 6）
- 全局物品栏 UI（Slice 6 的 bag 命令）

## Capabilities

### New Capabilities
- `smap-menu-interaction` [REQ-001]: `look` 输出编号列表 + `choose N` 级联菜单交互
- `smap-npc-dialog` [REQ-002]: NPC 对话 + oldevent 事件执行
- `smap-scene-state` [REQ-003]: 场景动态状态管理

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/engine-web/mmap_smap_handlers.lua` | 增强 `look` 为菜单模式；新增 SMAP 级联 `choose` 处理 |
| `game/engine-web/web_game_bridge.lua` | SMAP 命令表调整；新增 Web MUD 版 instruct 函数 |
| `game/engine-web/web_command_engine.lua` | 无变化（choose 命令已在所有状态注册） |
| `tests/` | 新增菜单交互 E2E 测试 |

## Contract Adherence

遵循 Slice 3 的所有共享契约（processEventQueue、CommandEngine、WebUI）。`choose` 命令已在所有状态注册，SMAP 级联菜单通过 `MenuAsync.ShowMenu2Coroutine` 实现。
