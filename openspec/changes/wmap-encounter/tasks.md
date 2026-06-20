## 1. 遇敌系统

- [x] 1.1 从 data-web/wars.json 读取战斗配置（已实现 `selectRandomWar` 但未使用，保留供脚本参考）
- [x] 1.2 脚本触发战斗入口 `WmapHandlers.initWar()`（供 oldevent 脚本调用）
- [x] 1.3 战斗胜利：经验/金钱奖励
- [x] 1.4 战斗失败：回到 MMAP（无惩罚）

## 2. 测试

- [x] 2.1 脚本触发战斗 E2E 测试（`initWar → look → choose attack → 奖励验证`）
- [x] 2.2 战斗胜利奖励 E2E 测试

## 设计决策

- 金庸群侠传原版无随机遇敌，所有战斗由场景事件触发
- 文字版遵循原版设计，不添加随机遇敌
- MMAP 行走/探索命令已移除（无 2D 地图渲染）
- `wars.json` 保留完整数据供脚本查询使用
