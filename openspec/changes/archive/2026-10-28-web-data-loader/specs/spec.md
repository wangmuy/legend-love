## ADDED Requirements

### Requirement:  JSON 解析器

系统 SHALL 提供纯 Lua JSON 解析器，用于解析 Slice 1 产出的数据文件。

#### Scenario: 解析对象
- **WHEN** 输入 `{"version":"1.0","total":100}`
- **THEN** 返回 Lua 表 {version="1.0", total=100}

#### Scenario: 解析数组
- **WHEN** 输入 `[1,2,3]`
- **THEN** 返回 Lua 表 {1, 2, 3}

#### Scenario: 解析嵌套结构
- **WHEN** 输入 scenes.json 的全部内容
- **THEN** 正确解析 84 个场景的所有嵌套结构（exits、npc、items、events）

### Requirement:  数据加载

系统 SHALL 将 7 个 JSON 数据文件加载到 `_G.dataCache` 全局表。

#### Scenario: 加载 dialogues
- **WHEN** data_loader 加载 dialogues.json
- **THEN** _G.dataCache.dialogues 包含 2977 条对话
- **AND** _G.dataCache.dialogues[1].text 是字符串

#### Scenario: 加载 scenes
- **WHEN** data_loader 加载 scenes.json
- **THEN** _G.dataCache.scenes 包含 84 个场景
- **AND** 每个场景有 id、idStr、name、exits 字段

#### Scenario: 加载完成标记
- **WHEN** 所有 7 个 JSON 文件加载完成
- **THEN** _G.dataCache._loaded 为 true
- **AND** _G.dataCache._fileCount 为 7

### Requirement:  错误处理

系统 SHALL 在 JSON 解析失败时返回错误信息。

#### Scenario: 无效 JSON
- **WHEN** 输入 `{invalid json}`
- **THEN** 返回 false 和错误信息
- **AND** _G.dataCache 不受影响