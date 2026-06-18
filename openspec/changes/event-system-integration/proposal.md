## 为什么

Slice 4 实现了 SMAP 菜单驱动交互，但 NPC 对话触发 `EventExecutor.startEvent()` 后显示"事件系统不可用"。原因是 `event_executor.lua` 模块未加载，且 `instruct_*` 函数在 Web MUD 中大量缺失。

金庸群侠传的 1018 个 oldevent 脚本是游戏剧情的核心。它们是原始 Lua 代码，不经修改即可在 Fengari VM 中运行——只需要 Web MUD 版的 `instruct_*` 桩函数。这是一个横向 slice，目标是让所有 oldevent 脚本在 Web MUD 中可执行。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- 位于 Slice 4 之后，Slice 5（战斗系统）之前
- 横向 slice，不阻塞后续垂直 slice

## What Changes

### 事件执行器加载
- 在 `initWebFramework` 中加载 `event_executor`、`async_globals`、`script_loader`
- 自动安装 `instruct_*` 替换函数到全局环境

### instruct stubs（67 个函数的 Web MUD 版）
- `instruct_0` ✅ 已有（分隔线）
- `instruct_1` ✅ 已有（对话文本）
- `instruct_27`/`instruct_67` 等 → no-op（动画/音效不需要）
- `instruct_3`/`instruct_2` → 修改 JY 数据（场景事件/出口表）
- `instruct_40` → 设置 `JY.Base["人方向"]`
- `instruct_32` → 背包操作

### D* 数据访问
- `GetD(sceneId, eventId, field)` → 从 `dataCache.events` 读取
- `SetD(sceneId, eventId, field, value)` → 写入 JY 运行时状态
- `GetS`/`SetS` → 场景格子数据（Web MUD 中简化）

### 测试（Game Flow Testing）
- TC-01: 主角的家 → 软体娃娃对话（oldevent_691）
- TC-02: 悦来客栈 → 店小二
- TC-03: 南贤居 → 南贤对话
- TC-04: 随机 5 个 oldevent 泛化执行测试

## Scope Boundaries

### In Scope
- `EventExecutor` 模块加载
- 全部 67 个 `instruct_*` 的 Web MUD 桩函数
- `GetD`/`SetD`/`GetS`/`SetS` 基于 dataCache 的实现
- Game Flow Testing（4 个测试用例）
- 旧事件系统（oldevent/*.lua）

### Out of Scope
- 新事件系统（newevent/，1 个文件，实际未使用）
- 战斗系统（Slice 5）
- 物品合成/使用
- 完整的 oldevent 1018 个脚本逐一测试

## Capabilities

### New Capabilities
- `event-executor-loader` [REQ-001]: 事件执行器模块加载
- `instruct-stubs` [REQ-002]: 全部 instruct 函数桩
- `event-data-access` [REQ-003]: D* 数据访问
- `event-flow-tests` [REQ-004]: 游戏流程测试

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/engine-web/web_game_bridge.lua` | 加载 EventExecutor + 注册 instruct 桩 |
| `game/engine-web/mmap_smap_handlers.lua` | smapNpcTalk 事件调用修复 |
| `game/framework/event_executor.lua` | 无需修改 |
| `game/script/oldevent/*.lua` | 无需修改 |
| `tests/` | 新增 event-flow-tests |

## Contract Adherence

所有 oldevent 脚本不经修改在 Fengari VM 中执行。`instruct_*` 函数通过 `rawset(_G, ...)` 注册，遵循 `async_globals.lua` 的安装模式。
