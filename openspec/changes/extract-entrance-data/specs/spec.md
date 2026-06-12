## ADDED Requirements

### Requirement: 大地图场景入口提取

系统 SHALL 从 `data/ranger.grp` 的场景段（Scene_S 结构）中提取外景入口坐标。

入口坐标来源为 Scene_S 结构体的字段：
- `外景入口X1`（偏移 30）/ `外景入口Y1`（偏移 32）
- `外景入口X2`（偏移 34）/ `外景入口Y2`（偏移 36）

不来自 `mmap.grp`——该文件只存储瓦片图形数据（RLE/PNG），不包含入口编码信息。

#### Scenario: 提取场景入口
- **GIVEN** ranger.grp 存在于 `data/` 目录
- **WHEN** 运行提取脚本
- **THEN** 读取 Scene_S 段每个场景的外景入口字段
- **AND** 记录 (sceneId, name, mapX, mapY)

#### Scenario: entrances.json 结构
- **WHEN** 读取 entrances.json
- **THEN** 每条入口记录包含 `mapX`、`mapY` 和 `sceneId`、`name`
- **AND** 所有入口按 mapY→mapX 排序便于查找

#### Scenario: 入口去重
- **WHEN** 提取入口数据时
- **THEN** 同一坐标有多个入口的只保留第一条