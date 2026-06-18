# Change Manifest — 事件系统集成

## 定位
横向 slice，介于 Slice 4（场景交互）和 Slice 5（战斗系统）之间。
目标是让 1018 个 oldevent 原始游戏脚本在 Web MUD 中不经修改即可执行。

## 依赖顺序

```
event-system-integration (事件系统集成)
        │
        ├── event-executor-loader   (加载 EventExecutor + 依赖模块)
        │
        ├── instruct-stubs          (Web MUD 版 instruct_* 桩函数)
        │
        ├── event-data-access       (D* 事件数据访问: GetD/SetD/GetS/SetS)
        │
        └── event-flow-tests        (游戏流程测试: 软体娃娃/店小二/南贤)
```

## Change Assignments

### 1. event-executor-loader

| 字段 | 值 |
|------|-----|
| Scope | 加载事件执行器及其依赖模块 |
| Responsibility | `require("framework.event_executor")`、`async_globals`、`script_loader`、`async_wrapper` |
| Depends on | Slice 3, Slice 4, web-worker-engine |

### 2. instruct-stubs

| 字段 | 值 |
|------|-----|
| Scope | 所有 `instruct_*` 函数的 Web MUD 版实现 |
| Responsibility | 覆盖全部 67 个 `instruct_*` 函数，no-op 或最小必要实现 |
| Depends on | event-executor-loader |

### 3. event-data-access

| 字段 | 值 |
|------|-----|
| Scope | D* 事件数据访问函数 (GetD/SetD/GetS/SetS) |
| Responsibility | 从 `dataCache.events` 读取 D* 数据，支持 oldevent 脚本的 `GetD()`/`SetD()` 调用 |
| Depends on | event-executor-loader |

### 4. event-flow-tests

| 字段 | 值 |
|------|-----|
| Scope | 基于游戏流程的端到端测试 |
| Responsibility | TC-01~TC-04 测试用例，覆盖典型 oldevent 执行路径 |
| Depends on | 以上全部 |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| `_G.instruct_N` | 通过 `rawset` 注册，在 `setmetatable(_G)` 之前 |
| `_G.EventExecutor` | 事件执行器全局表 |
| `_G.dataCache.events` | D* 事件数据源（20000 条） |
| `oldevent_N.lua` | 不经修改在 Web MUD 中执行 |
