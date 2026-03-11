## ADDED Requirements

### Requirement: 键盘事件捕获
系统 SHALL 使用love.keypressed和love.keyreleased捕获键盘事件。

#### Scenario: 按键按下
- **WHEN** 玩家按下键盘按键
- **THEN** love.keypressed回调被触发
- **AND** 按键信息被记录到输入队列

#### Scenario: 按键释放
- **WHEN** 玩家释放键盘按键
- **THEN** love.keyreleased回调被触发
- **AND** 按键状态被更新

### Requirement: 输入事件队列
系统 SHALL 使用队列缓存输入事件，在update中处理。

#### Scenario: 事件入队
- **WHEN** 键盘事件触发
- **THEN** 事件被添加到输入队列
- **AND** 队列保持事件顺序

#### Scenario: 事件处理
- **WHEN** love.update执行
- **THEN** 处理输入队列中的所有事件
- **AND** 清空已处理的事件

### Requirement: 向后兼容的输入API
系统 SHALL 保持原有输入API(lib.GetKey)的行为，内部使用事件驱动实现。

#### Scenario: 获取按键
- **WHEN** 调用lib.GetKey()
- **THEN** 返回当前按键状态
- **AND** 行为与阻塞式实现一致

#### Scenario: 按键重复
- **WHEN** 启用按键重复
- **THEN** lib.EnableKeyRepeat正常工作
- **AND** 按键重复事件被正确处理
