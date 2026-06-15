## ADDED Requirements

### Requirement: MMAP list 命令

list 命令 SHALL 列出 entrances.json 中的所有可去场景。

#### Scenario: 列出场景
- **GIVEN** 玩家处于 MMAP 状态
- **WHEN** 输入 `list`
- **THEN** 终端输出场景列表，每行 `编号. 场景名 (x, y)`
- **AND** 最后一行显示 `共 N 个场景`

### Requirement: MMAP go 命令

go 命令 SHALL 传送到指定场景。

#### Scenario: 精确匹配
- **GIVEN** entrances.json 包含 `{sceneId:70, name:"河洛客栈", x:364, y:284}`
- **WHEN** 输入 `go 河洛客栈`
- **THEN** JY.Base["人X1"] = 364, JY.Base["人Y1"] = 284
- **AND** JY.SubScene = 70
- **AND** JY.Status 切换为 GAME_SMAP

#### Scenario: 模糊匹配
- **WHEN** 输入 `go 河洛`
- **THEN** 匹配到 "河洛客栈"

#### Scenario: 未找到
- **WHEN** 输入 `go 不存在的场景`
- **THEN** 输出 "未找到场景: 不存在的场景"

### Requirement: MMAP look/where 命令

#### Scenario: look
- **GIVEN** 玩家坐标 (364, 284)
- **WHEN** 输入 `look`
- **THEN** 输出当前位置和附近场景列表

#### Scenario: where
- **WHEN** 输入 `where`
- **THEN** 输出坐标和方位

### Requirement: SMAP look 命令

#### Scenario: 场景描述
- **GIVEN** 玩家处于河洛客栈场景
- **WHEN** 输入 `look`
- **THEN** 输出场景名称、描述、NPC 列表、出口

### Requirement: SMAP exits 命令

#### Scenario: 出口列表
- **GIVEN** 河洛客栈有出口 {方向:"南", 目标场景:0（大地图）}
- **WHEN** 输入 `exits`
- **THEN** 输出 "南 → 大地图"（或类似格式）

### Requirement: SMAP go 命令

#### Scenario: 离开场景
- **GIVEN** 河洛客栈有出口 "南"
- **WHEN** 输入 `go 南`
- **THEN** 回到大地图 (JY.Status = GAME_MMAP)

#### Scenario: 无此出口
- **WHEN** 输入 `go 东`
- **THEN** 输出 "此方向没有出口: 东"
