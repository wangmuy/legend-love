## ADDED Requirements

### Requirement: 输入处理

Web MUD SHALL 直接处理文本命令，不经过 key injection。

#### Scenario: choose N — 有关联菜单时关闭菜单
- **GIVEN** 有活动菜单（MenuAsync.hasActiveMenu() == true）
- **WHEN** processEventQueue 收到输入 "choose 1"
- **THEN** MenuAsync.closeMenu(1) 被调用
- **AND** 菜单回调返回 1

#### Scenario: choose N — 无菜单时忽略
- **GIVEN** 没有活动菜单
- **WHEN** processEventQueue 收到输入 "choose 1"
- **THEN** CommandEngine.dispatchCommand("choose", {"1"}) 被调用

#### Scenario: 游戏命令 — 通过 CommandEngine 分发
- **GIVEN** 用户处于 MMAP 状态
- **WHEN** processEventQueue 收到输入 "list"
- **THEN** CommandEngine.dispatchCommand("list", {}) 被调用
- **AND** 终端输出场景列表

### Requirement: processEventQueue 驱动协程

processEventQueue SHALL 每帧驱动 CoroutineScheduler 和 StateMachine。

#### Scenario: 协程调度
- **GIVEN** 一个挂起的协程等待恢复
- **WHEN** processEventQueue 被调用（无输入事件）
- **THEN** CoroutineScheduler:update 被调用
- **AND** StateMachine:update 被调用

### Requirement: framework 模块加载

所有 framework/*.lua SHALL 通过 require 在 Web 环境可用。

#### Scenario: 核心模块可加载
- **WHEN** require("framework.coroutine_scheduler")
- **THEN** 返回 CoroutineScheduler 表
- **WHEN** require("framework.state_machine")
- **THEN** 返回 StateMachine 表
- **WHEN** require("framework.event_bridge")
- **THEN** 返回 EventBridge 表

### Requirement: 开始菜单

GAME_START 状态 SHALL 显示文字版开始菜单。

#### Scenario: 开始菜单显示
- **GIVEN** 系统初始化完成
- **WHEN** 终端输出开始菜单
- **THEN** 包含 "1. 重新开始"、"2. 载入进度"、"3. 离开游戏"
- **WHEN** 用户输入 `choose 1`
- **THEN** 进入新游戏流程

#### Scenario: choose 2 载入进度 — 无存档提示
- **GIVEN** 系统初始化完成，开始菜单显示
- **WHEN** 用户输入 `choose 2`
- **THEN** 终端输出 "没有存档，请选择「重新开始」开始新游戏"
- **AND** 显示 "返回开始菜单" 菜单项
- **WHEN** 用户输入 `choose 1`
- **THEN** 回到开始菜单

### Requirement: 属性选择

GAME_START 新游戏流程 SHALL 显示文字版属性选择。

#### Scenario: 属性选择显示
- **GIVEN** 用户输入 `choose 1` 开始新游戏
- **WHEN** 终端输出属性
- **THEN** 包含 "生命"、"攻击"、"资质" 等属性值
- **AND** 包含 "choose 0 返回开始菜单" 提示

### Requirement: 游戏循环稳定性

processEventQueue 的 gameLoop 调用 SHALL 不因 game_states.lua 的 MMAP/SMAP 处理器而崩溃。

#### Scenario: game_states 兼容 — lib 桩函数
- **GIVEN** 用户处于 MMAP 状态
- **WHEN** game_states GAME_MMAP 处理器被调用
- **THEN** lib.LoadMMap/GetMMap/UnloadMMap/PicLoadFile 作为桩函数存在
- **AND** StateMachine 不抛出 nil 调用错误

#### Scenario: SMAP 状态稳定
- **GIVEN** 用户进入场景（GAME_SMAP）
- **WHEN** game_states GAME_SMAP 处理器在每帧 update 中被调用
- **THEN** lib.GetS 返回 -1（无事件），不触发 EventExecuteSync
- **AND** 不抛出 nil 调用错误