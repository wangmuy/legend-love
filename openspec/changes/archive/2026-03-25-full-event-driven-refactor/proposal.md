## Why

当前游戏虽然部分模块已改造为事件驱动架构，但核心流程仍存在大量阻塞调用：
- **战斗系统**使用 `while true` 主循环阻塞整个游戏
- **事件指令系统**大量调用 `DrawStrBoxWaitKey`、`DrawStrBoxYesNo` 等阻塞函数
- **菜单系统**原版 `ShowMenu`/`ShowMenu2` 仍被多处直接调用
- **对话系统**`TalkEx` 函数阻塞等待用户输入

这些阻塞调用导致游戏无法正确响应 Love2D 的事件循环，造成渲染异常、状态不同步等问题。必须将所有阻塞流程改造为事件驱动架构，才能确保游戏稳定运行。

## What Changes

### 战斗系统重构
- **BREAKING** 将 `WarMain` 战斗主循环改造为状态机驱动
- 将 `War_Manual`、`War_Auto` 改造为协程版本
- 将战斗菜单（攻击、移动、物品、等待等）改造为异步菜单

### 事件指令系统重构
- **BREAKING** 将所有 `instruct_XXX` 函数改造为协程版本
- 将 `DrawStrBoxWaitKey` 改造为异步等待
- 将 `DrawStrBoxYesNo` 改造为异步确认对话框
- 将 `TalkEx` 对话系统改造为异步对话

### 菜单系统完善
- 将所有 `ShowMenu` 调用替换为 `MenuAsync.ShowMenuCoroutine`
- 将所有 `ShowMenu2` 调用替换为 `MenuAsync.ShowMenu2Coroutine`
- 将 `MMenu` 主菜单改造为协程版本

### 状态机完善
- 新增 `GAME_WMAP` 战斗状态处理器
- 新增 `GAME_DIALOG` 对话状态处理器（可选子状态）
- 完善状态切换时的资源加载和清理

## Capabilities

### New Capabilities

- `async-battle`: 战斗系统异步改造，包括战斗主循环、战斗菜单、战斗动画
- `async-dialog`: 对话系统异步改造，包括对话显示、分页、头像显示
- `async-instructions`: 事件指令异步改造，所有 instruct_XXX 函数改为协程版本
- `async-message-box`: 消息框异步改造，包括 DrawStrBoxWaitKey、DrawStrBoxYesNo
- `game-state-wmap`: 战斗状态处理器，管理战斗状态的生命周期

### Modified Capabilities

- `event-driven-menu`: 扩展菜单系统，确保所有菜单调用都使用异步版本
- `unified-state-machine`: 扩展状态机，支持战斗状态和对话子状态

## Impact

### 核心文件修改
- `src/script/jymain.lua` - 大量函数需要重构
  - `WarMain` 及所有战斗相关函数
  - `instruct_XXX` 系列函数（约70个）
  - `DrawStrBoxWaitKey`、`DrawStrBoxYesNo`
  - `TalkEx` 对话函数
  - `MMenu` 主菜单
  - `ShowMenu`、`ShowMenu2`（标记废弃）

- `src/game_states.lua` - 新增战斗状态处理器
- `src/event_bridge.lua` - 支持战斗状态
- `src/script/jymodify.lua` - 修改函数中的阻塞调用
- `src/script/newevent/*.lua` - 所有事件脚本的阻塞调用

### 代码量估计
- 战斗系统重构：约2000行
- 事件指令重构：约500行
- 对话系统重构：约200行
- 菜单调用替换：约50处
- 测试和调试：大量

### 兼容性
- 存档格式不变
- 游戏逻辑不变
- 仅改变执行方式（阻塞→事件驱动）