## ADDED Requirements

### Requirement: 菜单驱动交互 [REQ-001]

系统 SHALL 在 SMAP 状态下输出 NPC/物品/出口的编号列表，`choose N` 做级联菜单。

#### 交互流程
- **GIVEN** 玩家处于 SMAP 状态
- **WHEN** 输入 `look`
- **THEN** 输出编号列表 + `"输入 choose <编号> 选择交互对象"`
- **WHEN** `choose N` 选择 NPC
- **THEN** 弹出子菜单（对话/查看/给予物品）
- **WHEN** `choose N` 选择物品
- **THEN** 弹出子菜单（拾取/查看）
- **WHEN** `choose N` 选择出口
- **THEN** 直接传送

### Requirement: 场景状态过滤 [REQ-003]

系统 SHALL 提供 `isNpcPresent` 和 `itemAvailable` 供 `look` 过滤。

#### 状态过滤
- **GIVEN** `setNpcPresent(id, false)`
- **WHEN** `isNpcPresent(id)` 
- **THEN** 返回 `false`
- **GIVEN** `setItemCount(id, 0)`
- **WHEN** `itemAvailable(id)`
- **THEN** 返回 `false`
