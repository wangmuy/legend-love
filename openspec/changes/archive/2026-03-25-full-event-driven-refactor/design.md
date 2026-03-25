## Context

当前游戏已完成部分事件驱动改造：
- `MenuStateMachine` + `MenuAsync` - 异步菜单系统
- `CoroutineScheduler` - 协程调度器
- `StateMachine` + `EventBridge` - 状态机框架
- `InputManager` - 输入管理
- `GAME_START`, `GAME_MMAP`, `GAME_SMAP`, `GAME_FIRSTMMAP` 状态处理器

但仍存在大量阻塞代码：
- 战斗系统 `WarMain` 使用 `while true` 主循环
- 事件指令 `instruct_XXX` 直接调用阻塞函数
- `DrawStrBoxWaitKey`、`DrawStrBoxYesNo`、`WaitKey` 阻塞等待用户输入
- `ShowMenu`、`ShowMenu2` 原版菜单函数仍被直接调用

约束：
- Lua 5.1+ 协程支持
- Love2D 事件循环模型
- 保持存档兼容
- 保持游戏逻辑不变

## Goals / Non-Goals

**Goals:**
- 将所有阻塞流程改造为事件驱动
- 战斗系统完全协程化
- 所有事件指令支持协程执行
- 所有 UI 交互（菜单、对话框、消息框）异步化
- 完善状态机，支持战斗和对话状态

**Non-Goals:**
- 不修改游戏数据结构
- 不修改存档格式
- 不优化游戏性能（除非影响事件驱动）
- 不重构战斗算法逻辑

## Decisions

### 1. 战斗系统改造方案

**决定**: 将战斗系统改造为状态机 + 协程混合模式

**方案**:
- `GAME_WMAP` 状态处理器管理战斗生命周期
- `WarMain` 改造为协程入口函数
- 战斗主循环改为协程内的状态驱动
- 战斗菜单使用 `MenuAsync.ShowMenuCoroutine`

**备选方案**:
- 纯状态机方案：将战斗拆分为多个子状态，代码改动量大，难以维护
- 纯协程方案：战斗状态无法与状态机同步，导致渲染问题

**选择理由**: 混合模式平衡了代码改动量和架构一致性

### 2. 事件指令改造方案

**决定**: 使用协程包装器，保持原有函数签名

**方案**:
- 创建 `instruct_async.lua` 提供异步版本
- 原有 `instruct_XXX` 标记废弃但保留兼容
- 事件执行器 `EventExecute` 自动使用协程包装

**备选方案**:
- 直接修改所有 `instruct_XXX` 为协程：改动量大，容易出错
- 创建完全新的指令系统：与现有事件脚本不兼容

**选择理由**: 包装器模式最小化改动，保持向后兼容

### 3. 阻塞函数替换策略

**决定**: 创建异步替代函数，逐步替换

**映射关系**:
| 原函数 | 异步替代 |
|--------|----------|
| `ShowMenu` | `MenuAsync.ShowMenuCoroutine` |
| `ShowMenu2` | `MenuAsync.ShowMenu2Coroutine` |
| `DrawStrBoxWaitKey` | `AsyncDialog.showMessageCoroutine` |
| `DrawStrBoxYesNo` | `AsyncDialog.showYesNoCoroutine` |
| `WaitKey` | `InputAsync.WaitKeyCoroutine` |

**选择理由**: 渐进式替换，可逐步验证

### 4. 状态机扩展

**决定**: 新增 `GAME_WMAP` 状态处理器

**状态生命周期**:
```
enter:
  - 加载战斗资源
  - 启动战斗协程
update:
  - 更新战斗逻辑（协程调度）
draw:
  - 渲染战斗地图和人物
exit:
  - 清理战斗资源
  - 恢复之前状态
```

**选择理由**: 与现有状态机架构一致，便于管理

## Risks / Trade-offs

### Risk: 战斗系统改造复杂度高
- **Mitigation**: 分阶段实施，先完成菜单和对话改造，再处理战斗核心

### Risk: 协程调度可能引入时序问题
- **Mitigation**: 保留协程调试日志，便于追踪问题

### Risk: 事件脚本兼容性
- **Mitigation**: 提供协程包装器，保持原有函数签名

### Risk: 状态切换时的资源竞争
- **Mitigation**: 状态 enter/exit 时严格管理资源加载和清理

### Trade-off: 代码改动量大
- 接受：为了完全事件驱动，必须进行大量重构

### Trade-off: 测试工作量增加
- 接受：需要完整的游戏流程测试

## Migration Plan

### 阶段 1: 基础函数改造
1. 创建 `AsyncDialog.showMessageCoroutine`
2. 创建 `AsyncDialog.showYesNoCoroutine`
3. 扩展 `InputAsync.WaitKeyCoroutine`
4. 测试基础异步函数

### 阶段 2: 对话和消息系统
1. 改造 `DrawStrBoxWaitKey` 调用点
2. 改造 `DrawStrBoxYesNo` 调用点
3. 改造 `TalkEx` 对话系统
4. 测试对话流程

### 阶段 3: 菜单系统完善
1. 替换所有 `ShowMenu` 调用
2. 替换所有 `ShowMenu2` 调用
3. 改造 `MMenu` 主菜单
4. 测试菜单流程

### 阶段 4: 事件指令改造
1. 创建 `instruct_async.lua`
2. 逐个改造高优先级指令（对话、物品、战斗）
3. 改造其他指令
4. 测试事件触发

### 阶段 5: 战斗系统改造
1. 创建 `GAME_WMAP` 状态处理器
2. 改造 `WarMain` 为协程版本
3. 改造战斗菜单
4. 改造战斗动画
5. 测试战斗流程

### 阶段 6: 集成测试
1. 完整游戏流程测试
2. 边缘情况测试
3. 性能测试

## Open Questions

1. 是否需要 `GAME_DIALOG` 作为独立状态，还是作为子状态？
   - 建议：作为子状态，避免状态切换过于频繁

2. 战斗中的暂停/恢复如何处理？
   - 建议：战斗协程支持暂停，状态切换时自动处理

3. 是否需要保留原版阻塞函数供特定场景使用？
   - 建议：保留但标记废弃，便于调试和回退