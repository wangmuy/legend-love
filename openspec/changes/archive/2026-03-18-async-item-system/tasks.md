## 1. 基础模块搭建

- [x] 1.1 创建 `src/item_async.lua` 模块文件
- [x] 1.2 导入必要的依赖模块（CoroutineScheduler, MenuAsync, AsyncMessageBox 等）
- [x] 1.3 定义模块导出表 `ItemAsync = {}`

## 2. 异步物品选择菜单

- [x] 2.1 实现 `ItemAsync.SelectThingAsync` 函数框架
- [x] 2.2 实现物品分类菜单显示（全部物品、剧情物品、神兵宝甲等）
- [x] 2.3 实现物品列表分页显示逻辑
- [x] 2.4 实现物品信息显示（名称、数量、说明）
- [x] 2.5 处理空物品情况（显示"没有物品"提示）
- [x] 2.6 处理取消操作（ESC键返回-1）

## 3. 装备物品异步化

- [x] 3.1 实现 `ItemAsync.UseThing_Type1Async` 函数
- [x] 3.2 实现装备目标选择菜单（队友选择）
- [x] 3.3 实现装备条件检查（CanUseThing）
- [x] 3.4 实现装备分配逻辑（武器/防具）
- [x] 3.5 处理装备替换（解除原使用者装备）
- [x] 3.6 显示装备成功/失败信息

## 4. 药品物品异步化

- [x] 4.1 实现 `ItemAsync.UseThing_Type3Async` 函数
- [x] 4.2 实现药品使用目标选择菜单
- [x] 4.3 实现生命恢复逻辑
- [x] 4.4 实现内力恢复逻辑
- [x] 4.5 实现体力恢复逻辑
- [x] 4.6 处理无需使用的情况（生命/内力已满）
- [x] 4.7 显示恢复效果信息

## 5. 剧情物品异步化

- [x] 5.1 实现 `ItemAsync.UseThing_Type0Async` 函数
- [x] 5.2 实现剧情事件触发检查
- [x] 5.3 调用事件执行系统触发剧情
- [x] 5.4 处理无对应事件的情况

## 6. 秘籍物品异步化

- [x] 6.1 实现 `ItemAsync.UseThing_Type2Async` 函数
- [x] 6.2 实现修炼目标选择菜单
- [x] 6.3 实现修炼条件检查（内力性质、内力上限）
- [x] 6.4 实现武功等级增加逻辑
- [x] 6.5 显示修炼成功/失败信息

## 7. 暗器物品异步化

- [x] 7.1 实现 `ItemAsync.UseThing_Type4Async` 函数
- [x] 7.2 检查是否在战斗状态
- [x] 7.3 非战斗状态显示"只能在战斗中使用"

## 8. 物品使用入口重构

- [x] 8.1 实现 `ItemAsync.UseThingAsync` 函数
- [x] 8.2 根据物品类型分发到对应的使用函数
- [x] 8.3 处理物品使用失败情况
- [x] 8.4 添加错误处理和日志

## 9. 菜单系统集成

- [x] 9.1 更新 `JyMainAsync.Menu_Thing` 调用 `ItemAsync.SelectThingAsync`
- [x] 9.2 更新 `JyMainAsync.Menu_Thing` 调用 `ItemAsync.UseThingAsync`
- [x] 9.3 移除"物品功能正在开发中"的临时提示

## 10. AsyncGlobals 集成

- [x] 10.1 在 `AsyncGlobals` 中添加 `SelectThing` 替换
- [x] 10.2 在 `AsyncGlobals` 中添加 `UseThing` 替换
- [x] 10.3 确保事件脚本中调用的是异步版本

## 11. 物品数量管理

- [x] 11.1 实现 `ReduceThingCount` 辅助函数
- [x] 11.2 药品使用成功后减少物品数量
- [x] 11.3 秘籍修炼成功后减少物品数量
- [x] 11.4 装备物品不减少数量（可重复使用）

## 12. 文档和清理

- [x] 12.1 更新 `jymain_async.lua` 中的注释
- [x] 12.2 添加 `item_async.lua` 模块头注释
- [x] 12.3 清理调试代码和临时文件
- [x] 12.4 提交最终代码
