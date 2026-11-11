# Spec — extract-complete-binary

### Requirement: 全字段数据提取完整性

系统 SHALL 将所有二进制数据字段提取到 JSON 中，无遗漏。

#### Scenario: 场景字段完整性

- **GIVEN** ranger.grp 中的场景结构体（62 字节，21 个字段）
- **WHEN** 运行 extract_scenes()
- **THEN** scenes.json 包含所有 21 个字段
- **AND** 出口/跳转坐标正确映射（修复偏移 Bug）

#### Scenario: D* 事件提取

- **GIVEN** alldef.grp 中的地砖事件数据
- **WHEN** 运行 extract_events()
- **THEN** events.json 包含 84 场景 × 200 事件 = 16800 条记录
- **AND** 每条记录包含 11 个字段（通行标志、事件 ID、贴图、坐标等）

#### Scenario: 基础数据提取

- **WHEN** 运行 extract_base()
- **THEN** config.json 包含主角位置、队伍、物品栏、乘船状态

#### Scenario: 商店数据提取

- **WHEN** 运行 extract_shops()
- **THEN** shops.json 包含 5 个商店的商品列表

#### Scenario: 物品/技能全字段

- **WHEN** 运行 extract_runtime()
- **THEN** items.json 包含所有 54 个物品字段（属性加成、需求条件、合成配方）
- **AND** skills.json 包含所有 38 个技能字段（移动范围、杀伤范围、等级数据）

#### Scenario: 引用完整性

- **GIVEN** events 包含 D* 事件引用的事件 ID
- **WHEN** 事件 ID ≥ 0
- **THEN** verify_web_data.lua 验证引用的场景/人物/物品在相应 JSON 中存在