## ADDED Requirements

### Requirement: 等待按键消息框
DrawStrBoxWaitKey SHALL 改造为异步函数，显示消息后等待按键。

#### Scenario: 显示消息并等待
- **WHEN** 调用 AsyncDialog.showMessageCoroutine
- **THEN** 显示带框的消息文本
- **AND** 等待玩家按键（不阻塞游戏循环）
- **AND** 按键后关闭消息框并返回

#### Scenario: 多行消息
- **WHEN** 消息文本较长
- **THEN** 自动换行显示
- **AND** 框大小适应内容

### Requirement: 是/否确认框
DrawStrBoxYesNo SHALL 改造为异步函数，显示确认对话框。

#### Scenario: 选择是
- **WHEN** 调用 AsyncDialog.showYesNoCoroutine
- **THEN** 显示是/否选项
- **AND** 玩家选择"是"后返回 true

#### Scenario: 选择否
- **WHEN** 调用 AsyncDialog.showYesNoCoroutine
- **THEN** 显示是/否选项
- **AND** 玩家选择"否"后返回 false

#### Scenario: 按ESC取消
- **WHEN** 显示确认框时玩家按ESC
- **THEN** 返回 false（等同于选择否）

### Requirement: 消息框位置
消息框 SHALL 支持指定显示位置。

#### Scenario: 居中显示
- **WHEN** 位置参数为 (-1, -1)
- **THEN** 消息框居中显示

#### Scenario: 指定位置显示
- **WHEN** 位置参数为 (x, y)
- **THEN** 消息框显示在指定位置