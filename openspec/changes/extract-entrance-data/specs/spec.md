## ADDED Requirements

### Requirement: 大地图场景入口提取

系统 SHALL 从 `mmap.grp/.idx` 文件中提取大地图坐标到场景的映射关系。

#### Scenario: 提取场景入口
- **GIVEN** mmap.grp 和 mmap.idx 文件存在于 `data/` 目录
- **WHEN** 运行提取脚本
- **THEN** 扫描大地图所有瓦片
- **AND** 找到所有标记为"场景入口"的坐标
- **AND** 记录地图坐标 (mapX, mapY) 对应的场景 ID

#### Scenario: entrances.json 结构
- **WHEN** 读取 entrances.json
- **THEN** 每条入口记录包含 `mapX`、`mapY` 和 `sceneId`
- **AND** 所有入口按 mapX→mapY 排序便于查找

#### Scenario: 入口去重
- **WHEN** 提取入口数据时
- **THEN** 同一坐标有多个入口的只保留第一条（原版逻辑如此）