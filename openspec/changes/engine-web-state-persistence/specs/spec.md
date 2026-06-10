# Spec — engine-web-state-persistence

### Requirement: 字段名映射

系统 SHALL 提供英文→中文键名映射表，用于 dataCache 与 JY.* 之间的数据转换。

#### Scenario: 映射表自动生成

- **GIVEN** jyconst.lua 中的 CC.*_S 定义
- **WHEN** 运行状态管理器初始化
- **THEN** 生成 `.fieldMap` 包含 base/person/thing/scene/wugong/shop 的映射
- **AND** 每个映射表的中文键与 CC.*_S 一致
- **AND** 每个映射表的英文键与提取的 JSON 字段一致

#### Scenario: loadGameState 恢复数据

- **GIVEN** IndexedDB 中存储有存档 JSON
- **WHEN** 调用 `loadGameState(slotId)`
- **THEN** 恢复 `JY.Base`、`JY.Person[i]`、`JY.Thing[i]`、`JY.Scene[i]`、`JY.Wugong[i]`、`JY.Shop[i]` 表
- **AND** 所有键名为中文
- **AND** 所有键值与 CC.*_S 定义的类型一致

#### Scenario: saveGameState 持久化

- **GIVEN** 游戏脚本修改了 JY.* 表
- **WHEN** 调用 `saveGameState(slotId)`
- **THEN** 通过 JSBridge.save() 写入 IndexedDB
- **AND** 序列化为 JSON 字符串

#### Scenario: 存档槽独立

- **GIVEN** 3 个手动存档槽
- **WHEN** 保存到槽 1
- **THEN** 槽 2 和槽 3 不受影响
- **AND** 自动存档（槽 0）独立

### Requirement: JSBridge IndexedDB 存储

系统 SHALL 通过 JSBridge 提供基于 IndexedDB 的持久化存储。

#### Scenario: save/load 往返

- **GIVEN** Lua 侧调用 `JSBridge.save("test_key", '{"a":1}')`
- **WHEN** 调用 `JSBridge.load("test_key")`
- **THEN** 返回 `'{"a":1}'`
- **AND** 页面刷新后仍然可读取