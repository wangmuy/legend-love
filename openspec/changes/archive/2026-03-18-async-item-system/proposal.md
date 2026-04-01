## Why

当前游戏的物品系统使用同步阻塞调用（如 `SelectThing`、`UseThing` 等），在事件驱动架构下无法正常工作。当玩家在小场景打开菜单选择"物品"时，系统无法正确显示物品栏或响应按键。需要将物品系统全面异步化，使其能在协程中正常运行。

## What Changes

- 创建异步版本的物品选择菜单 `SelectThingAsync`，替代原有的同步 `SelectThing`
- 重构 `UseThing` 及其子函数（`UseThing_Type0` 到 `UseThing_Type4`）为协程版本
- 实现异步版本的装备、秘籍、药品、暗器使用逻辑
- 添加物品使用确认对话框的异步支持
- 更新 `Menu_Thing` 以使用新的异步物品系统

## Capabilities

### New Capabilities
- `async-item-selection`: 异步物品选择菜单，支持分页浏览和选择
- `async-item-usage`: 异步物品使用系统，支持装备、秘籍、药品、暗器等各类物品
- `async-equip-system`: 异步装备系统，处理武器和防具的装备逻辑
- `async-scroll-system`: 异步秘籍系统，处理武功秘籍的修炼逻辑
- `async-potion-system`: 异步药品系统，处理生命、内力、体力恢复
- `async-throwing-system`: 异步暗器系统，处理暗器使用逻辑

### Modified Capabilities
- `game-menu-system`: 更新物品菜单以使用异步物品系统

## Impact

- 修改文件：`src/jymain_async.lua`、`src/script/jymain.lua`
- 新增文件：`src/item_async.lua`（物品系统异步模块）
- 依赖：需要 `MenuAsync`、`AsyncMessageBox`、`TalkAsync` 等异步模块
- 影响功能：小场景菜单中的"物品"选项、战斗中的物品使用
