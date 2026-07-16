## 为什么

现有 e2e 测试覆盖了引擎功能和独立交互流程（如 NPC 对话），但缺少**完整的游戏流程验证**。攻略式 e2e 测试模拟真实玩家操作，按 `quick_pass_game.md` 的速通攻略顺序逐步推进游戏，在每个关键节点验证输出。这是 Web MUD 从"功能可用"到"游戏可玩通"的验证关卡。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- 依赖: slice4-smap-interaction, slice5-battle-system, slice6-character-management, slice-event-system-integration
- 横向 slice，验证所有功能层的集成

## What Changes

### 攻略式 e2e 测试架构
- 基于存档跳转的测试状态管理：每个测试步骤加载前一步的存档，执行操作，保存到下一步
- 测试间无状态耦合：失败不级联，可单独重跑任一测试
- 攻略路径参考 `quick_pass_game.md` 速通攻略顺序

### 存档跳转机制
- 在测试框架中封装 save/load 工具函数
- 基于 Web MUD 现有的 IndexedDB 存档系统（`saveGameState`/`loadGameState`）
- 每个攻略步骤对应一个存档槽位：`slot_1`、`slot_2`、…

### 攻略路线（按 `quick_pass_game.md` 顺序分阶段）

**Phase 1: 开局入门（Steps 1-5）**
南贤 → 田伯光加入 → 唐诗选集 → 闫基战斗（胡家刀法）

**Phase 2: 队友招募（Steps 6-12）**
铁掌帮 → 段誉加入 → 无量山洞 → 回族部落 → 胡斐加入 → 冰火岛 → 绝情谷

**Phase 3: 天书收集（Steps 13-25）**
昆仑仙境 → 神雕洞 → 古墓 → 燕子坞 → 泰山派 → 苗人凤 → 悦来客栈令狐冲 → 黑龙潭 → 一灯居 → 药王庄 → 衡山派 → 雪山派 → 金轮寺 → 明教分舵

**Phase 4: 后期完善（Steps 26-40）**
光明顶 → 华山派 → 金蛇洞 → 武当山 → 嵩山 → 神龙教 → 冰火岛 → 闯王山洞 → 破庙 → 成昆居 → 沙漠废墟 → 北丑居 → 冰火岛屠龙刀 → 光明顶龙王 → 回族部落天书

**Phase N: 通关（Steps 40+）**
剩余天书 → 侠客岛 → 天宁寺 → 梅庄 → 黑木崖 → 丐帮 → 苗人凤 → 桃花岛 → 华山论剑 → 圣堂

## Scope Boundaries

### In Scope
- 测试存档/读档工具函数（基于现有 `saveGameState`/`loadGameState`）
- 按 `quick_pass_game.md` 顺序的完整攻略 e2e 测试
- `game/engine-web/tests/walkthrough/` 目录下的测试文件

### Out of Scope
- 修改游戏引擎、事件系统、战斗系统等核心逻辑
- 邪派路线、全收集路线
- 修改现有测试文件
- Love2D 版本的攻略测试

## Capabilities

### New Capabilities
- `walkthrough-save-state` [REQ-WT-001]: 测试存档跳转机制
- `walkthrough-main-quest` [REQ-WT-002]: 按 `quick_pass_game.md` 顺序的攻略测试

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/engine-web/tests/walkthrough/` | 新增攻略测试目录 |
| `game/engine-web/tests/helpers/setup.js` | 新增存档工具函数 |
| 游戏引擎代码 | 无需修改 |

## Contract Adherence

所有攻略测试通过纯用户命令驱动（`list`、`choose N`、`leave`），不修改游戏运行时状态。存档/读档通过 `saveGameState`/`loadGameState` 函数，与玩家手动存档使用同一路径。
