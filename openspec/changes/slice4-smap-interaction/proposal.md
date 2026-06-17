## 为什么

Slice 3 实现了大地图漫游和场景的基础入口，但场景内交互——与 NPC 对话、触发事件、拾取物品——还是空白。玩家进入场景后只能 `look` 和 `exits`，无法推动游戏剧情。

Slice 4 补全场景内的核心交互：NPC 对话（驱动 oldevent 剧情）、物品操作（take/give）、场景状态管理（NPC 离场、物品拾取后 `look` 反映变化）。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- 位于 Slice 3 + Web Worker 架构重构之后
- 依赖：Slice 3（MMAP/SMAP 基础命令、协程调度器、菜单系统）

## What Changes

### NPC 对话（web-smap-talk）
- 新增 `talk <人名>` SMAP 命令
- 通过场景数据查找 NPC → 获取事件 ID → 调用 EventExecutor 执行 oldevent
- `instruct_1(talkId, headId)` 从 dataCache.dialogues 读取对话文本并输出
- 事件脚本中的 `WaitKey` → 等待用户输入任意文字+回车
- 事件脚本中的 `ShowMenu` → 显示选项菜单 → `choose N` 选择
- `instruct_0()` → 清屏（Web MUD 输出分隔线）
- 事件结束后回到场景

### 物品交互（web-smap-item）
- `take <物品名>` 从场景拾取物品到背包
- `give <物品名> <人名>` 将物品交给 NPC（触发事件或条件判断）
- `look <目标>` 查看场景中具体物品或 NPC 的描述
- 场景物品列表显示在 `look` 中

### 场景状态（web-scene-state）
- `_G.sceneState` 表跟踪每个场景的动态状态
- NPC 离队/离开后 `look` 不再显示
- 物品被拾取后 `look` 不再显示
- 状态变更由 oldevent 事件驱动（`instruct_32` 给物品、`instruct_54` NPC 加入等）

## Scope Boundaries

### In Scope
- `talk <人名>` 命令 + oldevent 事件执行
- `take <物品名>` / `give <物品名> <人名>` 命令
- `look <目标>` 查看具体对象
- 场景状态管理（`_G.sceneState`）
- 对话文本输出（`instruct_1` 适配）
- 事件中 WaitKey/ShowMenu 的 Web MUD 适配
- 事件脚本中常用 instruct 函数的 Web MUD 实现

### Out of Scope
- 战斗系统（Slice 5）
- 角色状态面板（Slice 6）
- 存档读档（Slice 6）
- 全局物品栏 UI（Slice 6 的 bag 命令）
- 大地图事件
- 场景间跳转事件

## Capabilities

### New Capabilities
- `web-smap-talk`: NPC 对话 + oldevent 事件执行
- `web-smap-item`: 场景物品交互 (take/give/look)
- `web-scene-state`: 场景动态状态管理

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/engine-web/mmap_smap_handlers.lua` | 新增 talk/take/give/look 处理器 |
| `game/engine-web/web_command_engine.lua` | SMAP 命令注册表扩展 |
| `game/engine-web/web_game_bridge.lua` | 新增 Web MUD 版的 instruct 函数 |
| `game/framework/event_executor.lua` | 可能需要微调 Web MUD 兼容 |
| `game/framework/async_globals.lua` | 安装替换函数 |
| `data-web/` | 已有数据可用 |

## Contract Adherence

本 change 遵循 Slice 3 的所有共享契约（processEventQueue、CommandEngine、WebUI），并在此基础上扩展 SMAP 命令集。不影响 MMAP 命令。
