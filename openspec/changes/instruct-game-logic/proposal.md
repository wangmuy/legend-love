## 为什么

当前 `instruct-stubs` change 为全部 67 个 `instruct_*` 注册了桩函数（no-op 或 debug.log），但几个关键的**功能性** instruct 函数留空了：

- `instruct_11`（住宿询问）— jymain.lua 的版本会调用 nil 函数导致崩溃
- `instruct_12`（恢复体力）— rest 命令应该复用它
- `instruct_14`（重绘场景）— 事件脚本需要
- `instruct_19`（移动主角）— 事件脚本需要
- `instruct_31`（物品/金钱检查）— 客栈扣费、条件判断需要

这些函数在 oldevent 脚本中被高频使用，需要真正的 Web MUD 实现而非 no-op。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/slice-event-system-integration/change-manifest.md`
- 依赖: `instruct-stubs`（基础桩函数）
- 约束: 通过 `rawset` 注册，使用 `rawget/rawset` 访问 `_G`

## What Changes

5 个功能性 instruct 函数的 Web MUD 实现：

| 函数 | 功能 | Web MUD 实现 |
|------|------|-------------|
| `instruct_11()` | 住宿询问 | `MenuAsync.ShowMenu2Coroutine({是,否})` → 是则调用 instruct_12 |
| `instruct_12()` | 恢复体力 | `JY.Person[0]["生命"]=最大值; 体力=100; 内力=最大值` |
| `instruct_14()` | 重绘场景 | `SmapHandlers.look({})` |
| `instruct_19(x, y)` | 移动主角 | `JY.Base["人X1"]=x; ["人Y1"]=y` |
| `instruct_31(id, count, flag)` | 检查/扣除物品 | 检查背包 + 金钱/物品操作 |

## Traceability

- [REQ-001]: 功能性 instruct 函数实现
