## Context

遇敌系统从 MMAP 行走时随机触发战斗，从 wars.json 读取战斗配置。
胜利后获得经验/金钱，失败则返回 MMAP。

## Decisions

```
MMAP 行走 → 随机遇敌判定 → initWar → GAME_WMAP
战斗胜利 → 经验/金钱奖励 → GAME_MMAP
战斗失败 → GAME_MMAP（无惩罚）
```
