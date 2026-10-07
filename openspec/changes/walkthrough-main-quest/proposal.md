## 为什么

Web MUD 各功能层已实现，但缺乏端到端的游戏通关验证。攻略式 e2e 测试按 `quick_pass_game.md` 速通攻略顺序，用纯用户命令模拟从头到尾的游戏过程，在每一步验证游戏状态和输出正确性。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/slice-walkthrough-e2e-tests/change-manifest.md`
- 参考攻略: `quick_pass_game.md`
- 依赖: walkthrough-save-state

## What Changes

### Phase 1: 开局入门 (Steps 1-5)
- 南贤指引 → 田伯光加入 → 唐诗选集 → 闫基战斗（胡家刀法）

### Phase 2: 队友招募 (Steps 6-12)
- 铁掌帮 → 段誉加入 → 无量山洞 → 回族部落 → 胡斐加入 → 冰火岛 → 绝情谷

### Phase 3: 天书收集 (Steps 13-25)
- 昆仑仙境 → 神雕洞 → 古墓/《神雕侠侣》 → 燕子坞 → 泰山派 → 苗人凤 → 悦来客栈令狐冲 → 黑龙潭 → 一灯居 → 药王庄 → 衡山派 → 雪山派 → 金轮寺 → 明教分舵

### Phase 4-N: 后期至通关
- 光明顶 → 华山派 → ... → 华山论剑 → 圣堂（通关）

### 攻略步骤数据模型
- 每个步骤定义：`{ name, action, verify, saveSlot, loadSlot }`
- 攻略路径以数据表维护，严格按 `quick_pass_game.md` 顺序

## Scope Boundaries

### In Scope
- 按 `quick_pass_game.md` 顺序的完整攻略 e2e 测试
- `tests/walkthrough/main-quest.spec.js` 测试文件
- 纯用户命令（`list`、`choose N`、`leave`）

### Out of Scope
- 修改游戏引擎或事件系统
- 像素级 UI 验证
- 任何非用户命令的操作（luaEval 注入等）

## Capabilities

### New Capabilities
- `walkthrough-main-quest` [REQ-WT-002]: 按攻略顺序的 e2e 测试

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/engine-web/tests/walkthrough/main-quest.spec.js` | 新增 |
| `game/engine-web/tests/helpers/walkthrough.js` | 引用存档工具函数 |

## Contract Adherence

测试通过纯用户命令驱动（`list`、`choose N`、`leave`）。存档跳转使用 `saveTestState`/`loadTestState`，与玩家手动存档使用同一路径。无 luaEval 注入、无测试专用代码。
