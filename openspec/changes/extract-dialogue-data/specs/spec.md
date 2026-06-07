## ADDED Requirements

### Requirement: 对话文本提取

系统 SHALL 从 `game/data/oldtalk.grp` 和 `game/data/oldtalk.idx` 中提取所有对话文本。

#### Scenario: 提取对话数据
- **GIVEN** oldtalk.grp 和 oldtalk.idx 文件存在于 `data/` 目录
- **WHEN** 运行提取脚本
- **THEN** 系统读取 idx 文件获取每条对话的偏移量
- **AND** 按偏移量从 grp 文件中读取每条对话文本
- **AND** 将对话数据写入 `engine-web/data-web/dialogues.json`

#### Scenario: 对话计数正确
- **GIVEN** 对话数据提取完成
- **WHEN** 统计 dialogues.json 中的条目数
- **THEN** 总数与原版 oldtalk.idx 中的记录数一致（约 5000+ 条）

### Requirement: JSON 输出格式

系统 SHALL 输出符合统一格式的 JSON 文件。

#### Scenario: JSON 包含元信息
- **WHEN** 任何 JSON 文件被输出
- **THEN** 顶层包含 `version` 字段
- **AND** 顶层包含 `extracted` 字段记录提取日期
- **AND** 顶层包含数据对应的 `total` 字段

#### Scenario: dialogues.json 结构
- **WHEN** 读取 dialogues.json
- **THEN** 每条记录包含 `id`（数字编号）和 `text`（对话字符串）

#### Scenario: JSON 可直接被 Lua require
- **WHEN** 在 Lua 中执行 `local d = require("data-web.dialogues")`
- **THEN** 返回的表结构正确，无解析错误