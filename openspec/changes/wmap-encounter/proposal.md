## Why

提供战斗系统入口供事件脚本调用：
- `WmapHandlers.initWar()` — 从任何 Lua 脚本调用即可进入战斗
- `wars.json` — 战斗配置数据（提取自 war.sta）
- 战斗流程：initWar → choose N 操作 → 胜利/失败 → MMAP

金庸群侠传原版无随机遇敌，所有战斗由场景事件触发。
文字版遵循原版设计，不添加随机遇敌。
