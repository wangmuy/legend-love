## 为什么

NPC 对话是 oldevent 驱动的核心交互。玩家选择"对话"后，系统需要查找 NPC 的事件 ID，通过 EventExecutor 加载并执行 oldevent 脚本，在 Web MUD 环境中适配对话文本输出和等待输入。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice 4: `openspec/changes/slice4-smap-interaction/change-manifest.md`
- 依赖: `smap-menu-interaction`（子菜单触发对话）

## What Changes

1. `smapNpcTalk` 函数：从 `chooseInteraction` 子菜单"对话"触发
2. `instruct_1(talkId, headId)` 从 `dataCache.dialogues` 读取对话文本
3. `instruct_0()` 输出分隔线（清屏替代）
4. `WaitKey()` 显示 "按回车继续..." + 等待输入
5. `EventExecutor.startEvent(eventId, flag, callback)` 执行 oldevent

## Capabilities

- `smap-npc-talk`: NPC 对话事件执行
- `smap-instruct-1`: 对话文本输出
- `smap-instruct-0`: 清屏替代
- `smap-waitkey`: 等待用户输入
