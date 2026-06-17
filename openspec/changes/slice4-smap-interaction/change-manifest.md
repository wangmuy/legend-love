# Change Manifest — 场景交互 (Slice 4)

## 依赖顺序

```
slice4-smap-interaction (场景交互总览: talk/take/give/look)
        │
        ├── web-smap-talk     (NPC对话: talk命令 + oldevent执行)
        │
        ├── web-smap-item     (物品交互: take/give/look <物品>)
        │
        └── web-scene-state   (场景状态: NPC状态、物品状态、look更新)
```

## Change Assignments

### 1. web-smap-talk

| 字段 | 值 |
|------|-----|
| Scope | NPC 对话功能 |
| Responsibility | `talk <人名>` 命令、查找 NPC 事件 ID、EventExecutor 执行 oldevent、`instruct_1` 对话文本输出、事件中 WaitKey/ShowMenu 处理 |
| Depends on | Slice 3 (web-game-bridge, web-command-engine, web-mmap-smap) |
| Status | [ ] Pending |

### 2. web-smap-item

| 字段 | 值 |
|------|-----|
| Scope | 场景物品交互 |
| Responsibility | `take <物品名>` 拾取、`give <物品名> <人名>` 给予、`look <目标>` 查看对象描述、场景物品列表 |
| Depends on | web-smap-talk |
| Status | [ ] Pending |

### 3. web-scene-state

| 字段 | 值 |
|------|-----|
| Scope | 场景动态状态管理 |
| Responsibility | NPC 在场/离场状态、物品可用/拾取状态、`look` 反映状态变化、事件驱动状态更新 |
| Depends on | web-smap-talk, web-smap-item |
| Status | [ ] Pending |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| `_G.EventExecutor` | 事件执行器，`startEvent(id, flag, callback)` 驱动 oldevent |
| `_G.sceneState` | 场景动态状态表，change 间共享 |
| `_G.SmapHandlers` | SMAP 命令处理器扩展 |
| `instruct_0()` | 清屏（Web MUD 用 WebUI.separator 替代） |
| `instruct_1(talkId, headId)` | 对话文本输出，从 dataCache.dialogues 读取 |
| `WaitKey()` | 等待用户输入任意文字 + 回车 |
| `ShowMenu(items, ...)` | 显示选项菜单，`choose N` 选择 |
