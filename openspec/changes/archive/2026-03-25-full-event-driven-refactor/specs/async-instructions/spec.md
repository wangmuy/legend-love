## ADDED Requirements

### Requirement: 事件指令协程执行
所有事件指令（instruct_XXX）SHALL 支持在协程中执行。

#### Scenario: 执行对话指令
- **WHEN** 执行 instruct_1 对话指令
- **THEN** 在协程中显示对话
- **AND** 等待对话完成后继续执行后续指令

#### Scenario: 执行战斗指令
- **WHEN** 执行 instruct_6 战斗指令
- **THEN** 启动战斗协程
- **AND** 战斗结束后继续执行后续指令

#### Scenario: 执行物品指令
- **WHEN** 执行 instruct_2 得到物品指令
- **THEN** 显示获得物品提示（异步）
- **AND** 提示关闭后继续执行

### Requirement: 指令阻塞调用替换
事件指令中的所有阻塞调用 SHALL 替换为异步版本。

#### Scenario: 指令中的消息框
- **WHEN** 指令调用 DrawStrBoxWaitKey
- **THEN** 使用 AsyncDialog.showMessageCoroutine 替代

#### Scenario: 指令中的确认框
- **WHEN** 指令调用 DrawStrBoxYesNo
- **THEN** 使用 AsyncDialog.showYesNoCoroutine 替代

### Requirement: 指令链顺序执行
多个指令 SHALL 按顺序执行，前一个完成后执行下一个。

#### Scenario: 连续对话
- **WHEN** 事件中有多条对话指令
- **THEN** 按顺序显示每条对话
- **AND** 每条对话等待玩家确认后显示下一条

#### Scenario: 对话后战斗
- **WHEN** 对话指令后紧跟战斗指令
- **THEN** 对话完成后开始战斗
- **AND** 战斗完成后继续后续指令