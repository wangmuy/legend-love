## ADDED Requirements

### Requirement: 战斗地图和遇敌配置提取

系统 SHALL 从战斗地图文件（wmap*.grp/.idx）和遇敌配置数据中提取信息。

#### Scenario: 提取战斗地图列表
- **GIVEN** 战斗地图索引文件存在
- **WHEN** 运行提取脚本
- **THEN** 读取所有战斗地图的编号、名称、尺寸
- **AND** 将数据写入 `engine-web/data-web/wmap.json`

#### Scenario: 提取遇敌配置
- **WHEN** 处理场景/大地图遇敌数据时
- **THEN** 提取每个场景/区域可遇到的敌人列表
- **AND** 提取遇敌概率
- **AND** 将数据写入 `engine-web/data-web/wmap.json`

#### Scenario: wmap.json 结构
- **WHEN** 读取 wmap.json
- **THEN** 包含 `maps`（战斗地图列表）和 `encounters`（遇敌配置）两个顶层字段
- **AND** 每条遇敌记录包含场景 ID、敌人列表、遇敌概率