## 为什么

战斗系统的核心引擎——状态管理、距离模型、回合交替 AI。其他命令子 change 依赖于此。

## What Changes

1. GAME_WMAP(3) 状态注册
2. JY.War 运行时战斗表
3. 1D 距离模型和伤害公式
4. 回合交替和 AI 决策

## Traceability

- [REQ-001]: 战斗核心引擎
