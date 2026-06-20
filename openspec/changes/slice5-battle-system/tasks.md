## 1. wmap-engine
Traceability: [REQ-001]

- [ ] 1.1 注册 GAME_WMAP 状态 + 命令表
- [ ] 1.2 JY.War 运行时战斗状态表
- [ ] 1.3 1D 距离模型（位置/移动/攻击范围计算）
- [ ] 1.4 回合交替系统（我方行动→敌方AI→我方）
- [ ] 1.5 伤害计算公式

## 2. wmap-commands
Traceability: [REQ-002]

- [ ] 2.1 look — 显示战场态势（敌我位置/HP/距离）
- [ ] 2.2 move — 走近/远离目标
- [ ] 2.3 attack — 普通攻击（距离检查）
- [ ] 2.4 wugong — 列出/使用武功（范围检查）
- [ ] 2.5 defend — 防御
- [ ] 2.6 item — 战斗中使用物品

## 3. wmap-encounter
Traceability: [REQ-003]

- [ ] 3.1 从 war.sta 读取战斗配置
- [ ] 3.2 随机遇敌触发
- [ ] 3.3 战斗胜利/失败处理
