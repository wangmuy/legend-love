## ADDED Requirements

### Requirement: 输入管理器集中处理所有输入
系统 SHALL 使用统一的输入管理器处理所有键盘输入。

#### Scenario: 按键按下
- **WHEN** 玩家按下键盘按键
- **THEN** love.keypressed回调被触发
- **AND** 输入管理器记录按键状态

#### Scenario: 按键释放
- **WHEN** 玩家释放键盘按键
- **THEN** love.keyreleased回调被触发
- **AND** 输入管理器更新按键状态

#### Scenario: 查询按键状态
- **WHEN** 游戏逻辑查询按键状态
- **THEN** 返回当前按键状态
- **AND** 状态查询不消费按键

#### Scenario: 消费按键
- **WHEN** 游戏逻辑消费按键
- **THEN** 按键被标记为已消费
- **AND** 同帧后续查询返回-1

### Requirement: 输入支持缓冲
系统 SHALL 支持输入缓冲，处理快速按键。

#### Scenario: 快速按键
- **WHEN** 玩家快速按下多个按键
- **THEN** 所有按键被记录到缓冲队列
- **AND** 按键按顺序被处理

#### Scenario: 缓冲溢出
- **WHEN** 输入缓冲满
- **THEN** 丢弃最早的按键
- **AND** 记录溢出警告

### Requirement: 输入支持重复
系统 SHALL 支持按键重复功能。

#### Scenario: 长按按键
- **WHEN** 玩家长按按键
- **THEN** 首次响应后延迟
- **AND** 之后按间隔重复触发

#### Scenario: 配置重复参数
- **WHEN** 配置重复延迟和间隔
- **THEN** 按键重复按配置执行
