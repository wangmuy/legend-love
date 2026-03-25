## ADDED Requirements

### Requirement: 对话显示异步
对话系统 SHALL 使用协程显示对话内容，不阻塞游戏循环。

#### Scenario: 显示对话
- **WHEN** 调用 instruct_1 触发对话
- **THEN** 显示对话文本和头像
- **AND** 等待玩家按键继续（不阻塞）

#### Scenario: 分页对话
- **WHEN** 对话内容超过一屏
- **THEN** 自动分页显示
- **AND** 等待玩家按键翻页（不阻塞）

### Requirement: 对话头像显示
对话系统 SHALL 正确显示说话人的头像。

#### Scenario: 显示NPC头像
- **WHEN** NPC对话时
- **THEN** 在指定位置显示NPC头像
- **AND** 头像与对话内容同步

#### Scenario: 显示主角头像
- **WHEN** 主角说话时
- **THEN** 显示主角头像
- **AND** 头像位置与NPC对话相反

### Requirement: 对话框样式
对话系统 SHALL 支持多种对话框样式。

#### Scenario: 普通对话框
- **WHEN** flag=0
- **THEN** 显示标准对话框样式

#### Scenario: 屏幕下方对话框
- **WHEN** flag=5
- **THEN** 对话框显示在屏幕下方
- **AND** 头像在左侧，对话在右侧