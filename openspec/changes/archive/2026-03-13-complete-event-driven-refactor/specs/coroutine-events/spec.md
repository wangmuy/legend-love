## ADDED Requirements

### Requirement: 事件脚本使用协程执行
系统 SHALL 使用Lua协程执行事件脚本，支持暂停和恢复。

#### Scenario: 启动事件脚本
- **WHEN** 调用事件脚本
- **THEN** 创建新协程执行脚本
- **AND** 脚本开始执行

#### Scenario: 脚本暂停等待输入
- **WHEN** 脚本调用等待函数（如WaitKey）
- **THEN** 协程挂起(yield)
- **AND** 游戏主循环继续运行

#### Scenario: 脚本恢复执行
- **WHEN** 等待条件满足（如按键按下）
- **THEN** 协程恢复(resume)
- **AND** 脚本从暂停处继续执行

#### Scenario: 脚本完成执行
- **WHEN** 脚本执行完毕
- **THEN** 协程结束
- **AND** 清理协程资源

### Requirement: 协程调度器管理所有协程
系统 SHALL 提供协程调度器管理所有运行中的协程。

#### Scenario: 调度器更新
- **WHEN** 每帧更新
- **THEN** 调度器检查所有协程状态
- **AND** 恢复可继续的协程

#### Scenario: 协程错误处理
- **WHEN** 协程执行出错
- **THEN** 调度器捕获错误
- **AND** 记录错误信息
- **AND** 终止出错协程

### Requirement: 协程支持嵌套调用
系统 SHALL 支持协程中调用其他协程。

#### Scenario: 嵌套协程调用
- **WHEN** 在协程A中调用协程B
- **THEN** 协程B作为子协程执行
- **AND** 协程A等待协程B完成

#### Scenario: 子协程完成
- **WHEN** 子协程B完成
- **THEN** 恢复父协程A
- **AND** 父协程继续执行
