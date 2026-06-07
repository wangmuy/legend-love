## ADDED Requirements

### Requirement: 场景结构提取

系统 SHALL 从 `allsin.grp/.idx` 和 `s*.grp/.idx` 文件中提取场景结构数据。

#### Scenario: 提取场景列表
- **GIVEN** allsin.grp 和 allsin.idx 文件存在
- **WHEN** 运行提取脚本
- **THEN** 读取所有场景的基础信息（名称、尺寸、类型）

#### Scenario: 提取场景出口
- **WHEN** 处理每个场景时
- **THEN** 从场景数据中解析出口位置和对应的目标场景 ID
- **AND** 每个出口包含方向描述、目标场景 ID、目标坐标

#### Scenario: 提取 NPC 坐标
- **WHEN** 处理每个场景时
- **THEN** 从场景数据中解析 NPC 位置（人物编号、x、y 坐标）

#### Scenario: 提取物品坐标
- **WHEN** 处理每个场景时
- **THEN** 从场景数据中解析物品位置（物品编号、x、y 坐标、数量）

#### Scenario: 提取事件触发点
- **WHEN** 处理每个场景时
- **THEN** 从 `d*.grp/.idx` 中解析事件触发坐标
- **AND** 每条事件包含 x、y 坐标、事件编号、事件标志

### Requirement: 场景 JSON 输出

#### Scenario: scenes.json 结构
- **WHEN** 读取 scenes.json
- **THEN** 每条场景记录包含：
  - `id`: 场景编号
  - `idStr`: `<场景名>_<ID>` 格式的唯一标识
  - `name`: 场景名称
  - `exits`: 出口数组（可为空）
  - `npc`: NPC 数组（可为空）
  - `items`: 物品数组（可为空）
  - `events`: 事件触发点数组（可为空）

#### Scenario: 场景类型标记
- **WHEN** 处理场景时
- **THEN** 根据场景名称自动推断场景类型（inn/shop/cave/temple/...）
- **AND** 无法推断的类型标记为 `unknown`