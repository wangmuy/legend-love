## 为什么

当前 SMAP 状态下玩家只能 `look` 和 `exits`，无法与 NPC 互动。金庸群侠传的 1018 个 oldevent 脚本是游戏剧情驱动的核心，NPC 对话是触发这些脚本的主要方式。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice 4: `openspec/changes/slice4-smap-interaction/change-manifest.md`
- 依赖：Slice 3（MMAP/SMAP 基础、协程调度、菜单系统）
- 依赖 web-worker-engine（Worker 架构已就绪）

## What Changes

1. 新增 `talk <人名>` SMAP 命令
2. 通过场景数据（dataCache.scenes）查找 NPC → NPC 的 `事件编号` → 调用 EventExecutor
3. EventExecutor 加载并执行 oldevent_N.lua 脚本
4. 适配 instruct 函数以 Web MUD 方式输出：
   - `instruct_0()` → WebUI.separator（清屏替代）
   - `instruct_1(talkId, headId)` → 从 dataCache.dialogues 读取对话文本并输出
   - `WaitKey()` → 等待用户输入任意文字+回车
   - `ShowMenu()` → 显示选项菜单 → choose N 选择

## Scope Boundaries

### In Scope
- `talk <人名>` 命令解析和执行
- NPC → 事件 ID 查找
- EventExecutor.startEvent(id, flag) 的 Web MUD 适配
- oldevent 脚本中常用 instruct 函数的 Web MUD 兼容实现
- 对话文本从 JSON 数据读取并输出
- 事件中 WaitKey 的文本输入处理
- 事件中 ShowMenu 的菜单处理

### Out of Scope
- 物品交互（web-smap-item）
- 场景状态管理（web-scene-state）
- 战斗事件
- 事件脚本的完整兼容性（只覆盖常用 instruct）

## Impact

| 文件 | 改动 |
|------|------|
| `mmap_smap_handlers.lua` | 新增 `talk` 处理器 |
| `web_game_bridge.lua` | 新增 `instruct_0`, `instruct_1`, `WaitKey` 等 Web MUD 版 |
| `web_command_engine.lua` | SMAP 注册表添加 `talk` |
| `tests/` | 新增 talk 命令 E2E 测试 |

## Contract Adherence

新增 `talk` 命令注册到 SMAP 状态，遵循 CommandEngine 契约。新增 instruct 函数以 `rawset(_G, ...)` 方式安装，不修改原版脚本文件。
