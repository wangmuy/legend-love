# Change Manifest — 场景交互 (Slice 4)

## 交互模式

与 Slice 3 MMAP 一致，采用菜单驱动：`look` 显示编号列表，`choose N` 做二级操作选择。

```
> look          → 显示 NPC/物品/出口编号列表
  > choose N    → NPC: 对话/查看/给予物品  |  物品: 拾取/查看  |  出口: 前往
```

## 依赖顺序

```
slice4-smap-interaction (场景交互总览: 菜单驱动交互)
        │
        ├── smap-menu-interaction  (look菜单 + choose级联)
        │
        ├── smap-npc-dialog       (NPC对话 + oldevent执行)
        │
        └── smap-scene-state      (场景状态: NPC/物品状态管理)
```

## Change Assignments

### 1. smap-menu-interaction

| 字段 | 值 |
|------|-----|
| Scope | 菜单驱动的场景交互 |
| Responsibility | `look` 输出编号列表、`choose N` 级联菜单处理、NPC/物品/出口统一交互 |
| Depends on | Slice 3 (web-game-bridge, web-command-engine, web-mmap-smap) |
| Status | [ ] Pending |

### 2. smap-npc-dialog

| 字段 | 值 |
|------|-----|
| Scope | NPC 对话 + oldevent 事件执行 |
| Responsibility | 子菜单中选择"对话"后执行 oldevent、`instruct_1` 对话文本输出、WaitKey/ShowMenu 处理 |
| Depends on | smap-menu-interaction |
| Status | [ ] Pending |

### 3. smap-scene-state

| 字段 | 值 |
|------|-----|
| Scope | 场景动态状态管理 |
| Responsibility | NPC 在场/离场状态、物品可用状态、`look`/`choose` 反映状态变化 |
| Depends on | smap-menu-interaction, smap-npc-dialog |
| Status | [ ] Pending |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| `_G.EventExecutor` | 事件执行器，`startEvent(id, flag, callback)` 驱动 oldevent |
| `_G.sceneState` | 场景动态状态表，change 间共享 |
| `_G.SmapHandlers` | SMAP 命令处理器扩展 |
| `instruct_0()` | 清屏替代（WebUI.separator） |
| `instruct_1(talkId, headId)` | 对话文本输出 |
| `WaitKey()` | 等待用户输入任意文字 + 回车 |
