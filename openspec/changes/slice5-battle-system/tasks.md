## 1. wmap-engine
Traceability: [REQ-001]

- [ ] 1.1 注册 GAME_WMAP 状态 + 命令表（look + choose）
- [ ] 1.2 JY.War 运行时战斗状态表
- [ ] 1.3 1D 距离模型（位置/移动/攻击范围计算）
- [ ] 1.4 回合交替系统（我方行动→敌方AI→我方）
- [ ] 1.5 伤害计算公式

## 2. wmap-commands
Traceability: [REQ-002]

- [ ] 2.1 look — 战场态势 + 行动菜单（编号列表）
- [ ] 2.2 choose N — 行动路由（攻击/武功/物品/防御/移动/查看）
- [ ] 2.3 攻击/武功子菜单（含范围检查）
- [ ] 2.4 物品子菜单（药品/暗器）
- [ ] 2.5 移动子菜单（走近/远离）

## 3. wmap-encounter
Traceability: [REQ-003]

- [ ] 3.1 从 data-web/wars.json 读取战斗配置（由 slice1 提取管线生成）
- [ ] 3.2 随机遇敌触发（MMAP 行走时）
- [ ] 3.3 战斗胜利/失败处理（经验/金钱奖励）
