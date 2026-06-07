## ADDED Requirements

### Requirement: 人物数据导出

系统 SHALL 从 `jyconst.lua` 和二进制数据中导出人物初始数据。

#### Scenario: 提取人物基本信息
- **GIVEN** jyconst.lua 已加载（包含 CC.Person_S 等数据结构定义）
- **WHEN** 运行提取脚本
- **THEN** 遍历所有人物编号（0-999）
- **AND** 读取人物的姓名、头像编号、初始等级、初始血量/内力等属性
- **AND** 将数据写入 `engine-web/data-web/chars.json`

#### Scenario: chars.json 结构
- **WHEN** 读取 chars.json
- **THEN** 每条人物记录包含：id、name、level、hp、mp、attack、defence、speed、skill1~skill4 等核心字段

### Requirement: 物品数据导出

系统 SHALL 从 `jyconst.lua` 中导出物品数据。

#### Scenario: 提取物品信息
- **WHEN** 运行提取脚本
- **THEN** 遍历所有物品编号
- **AND** 读取物品的名称、类型（剧情/装备/秘籍/药品/暗器）、效果值、价格等
- **AND** 将数据写入 `engine-web/data-web/items.json`

### Requirement: 武功数据导出

系统 SHALL 从 `jyconst.lua` 中导出武功数据。

#### Scenario: 提取武功信息
- **WHEN** 运行提取脚本
- **THEN** 遍历所有武功编号
- **AND** 读取武功的名称、类型（拳掌/剑法/刀法/特殊/暗器）、威力、消耗内力、攻击范围等
- **AND** 将数据写入 `engine-web/data-web/skills.json`

#### Scenario: 攻击范围字段
- **WHEN** 导出武功数据时
- **THEN** 包含原版攻击范围参数，后续由文字版战斗系统转换为 1D 距离