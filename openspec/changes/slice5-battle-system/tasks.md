## 1. wmap-engine
Traceability: [REQ-001]

- [x] 1.1 注册 GAME_WMAP 状态 + 命令表（look + choose）
- [x] 1.2 JY.War 运行时战斗状态表
- [x] 1.3 1D 距离模型（位置/移动/攻击范围计算）
- [x] 1.4 回合交替系统（我方行动→敌方AI→我方）
- [x] 1.5 伤害计算公式

## 2. wmap-commands
Traceability: [REQ-002]

- [x] 2.1 look — 战场态势 + 队友列表
- [x] 2.2 choose N — 队友/行动/目标路由
- [x] 2.3 攻击（含范围检查）
- [x] 2.4 武功子菜单（列出武功 + 范围检查）
- [x] 2.5 物品子菜单（药品/暗器）
- [x] 2.6 查看状态

## 3. 测试

- [x] 3.1 WMAP E2E 测试（initWar → look → attack → 胜利 → 奖励）
- [x] 3.2 武功菜单 E2E 测试
- [x] 3.3 战斗胜利奖励 E2E 测试

## 设计决策

- 金庸群侠传原版无随机遇敌，所有战斗由事件脚本触发
- MMAP 在文字版中仅作中转状态（look + list + choose N）
- wmap-encounter change 已删除（基于随机遇敌错误假设）
