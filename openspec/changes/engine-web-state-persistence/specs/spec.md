# Spec — engine-web-state-persistence

### Requirement: initGameState

系统 SHALL 从 dataCache 初始化 JY.* 表，无需字段名映射。

#### Scenario: dataCache → JY.* 直接赋值

- **GIVEN** dataCache 包含 chars/items/skills/scenes/config/shops（全部使用中文键）
- **WHEN** 调用 `initGameState()`
- **THEN** `JY.Base`、`JY.Person`、`JY.Thing`、`JY.Scene`、`JY.Wugong`、`JY.Shop` 被创建
- **AND** 所有键值为中文
- **AND** 场景入口坐标从嵌套结构展平为平铺字段

### Requirement: 存档/读档

系统 SHALL 提供基于 IndexedDB 的存档和读档功能。

#### Scenario: saveGameState 持久化

- **GIVEN** 游戏脚本修改了 JY.* 表
- **WHEN** 调用 `saveGameState(slotId)`
- **THEN** 通过 JSBridge.save() 写入 IndexedDB
- **AND** 序列化为 JSON 字符串
- **AND** 键名为中文

#### Scenario: loadGameState 恢复数据

- **GIVEN** IndexedDB 中存储有存档 JSON
- **WHEN** 调用 `loadGameState(slotId)`
- **THEN** 恢复 `JY.Base`、`JY.Person`、`JY.Thing`、`JY.Scene`、`JY.Wugong`、`JY.Shop`
- **AND** 0-based 数值键正确恢复（如 `JY.Person[0]`）
- **AND** 所有键值与 CC.*_S 定义一致

#### Scenario: 存档槽独立

- **GIVEN** 3 个手动存档槽
- **WHEN** 保存到槽 1
- **THEN** 槽 2 和槽 3 不受影响
- **AND** 自动存档（槽 0）独立

#### Scenario: deleteSaveSlot

- **GIVEN** 槽 3 有存档
- **WHEN** 调用 `deleteSaveSlot(3)`
- **THEN** 槽 3 被删除
- **AND** `listSaveSlots()` 不再包含 `save_3`

### Requirement: JSBridge IndexedDB 存储

系统 SHALL 通过 JSBridge 提供基于 IndexedDB 的持久化存储。

#### Scenario: save/load 往返

- **GIVEN** Lua 侧调用 `JSBridge.save("test_key", '{"a":1}')`
- **WHEN** 调用 `JSBridge.load("test_key")`
- **THEN** 返回 `'{"a":1}'`

#### Scenario: 跨页面持久化

- **GIVEN** 页面 A 中调用 `JSBridge.save("k", "v")`
- **WHEN** 刷新页面（新页面加载）
- **THEN** `loadAllSavesToCache()` 从 IndexedDB 加载存档
- **AND** `JSBridge.load("k")` 返回 `"v"`