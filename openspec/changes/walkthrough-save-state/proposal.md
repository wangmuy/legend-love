## 为什么

攻略 e2e 测试需要状态在测试步骤之间传递。最接近真实游玩的方式是存档跳转——每个测试步骤加载前一存档，执行操作，保存到下一槽位。这需要封装备 save/load 工具函数，作为攻略测试的基础设施。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/slice-walkthrough-e2e-tests/change-manifest.md`
- 依赖: slice-event-system-integration, state-persistence

## What Changes

### 测试存档工具函数
- `saveTestState(page, slot)`: 调用 `saveGameState(slot)` 保存当前游戏状态到 IndexedDB
- `loadTestState(page, slot)`: reload 页面 → 等待 worker 就绪 → `loadGameState(slot)` 恢复状态
- 封装在 `tests/helpers/walkthrough.js` 中

### 存档往返验证
- 验证 save → load 后游戏状态一致：金钱、物品、人物位置、角色属性
- 验证存档槽隔离：slot 1 和 slot 2 互不干扰

## Scope Boundaries

### In Scope
- `saveTestState` / `loadTestState` 工具函数
- 存档往返正确性测试
- `tests/helpers/walkthrough.js` 工具文件

### Out of Scope
- 修改现有 `saveGameState` / `loadGameState` 实现
- 修改 IndexedDB 存取逻辑
- 具体的攻略测试用例（由 walkthrough-main-quest 负责）

## Capabilities

### New Capabilities
- `tests/helpers/walkthrough.js` [REQ-WT-001]: 测试存档工具函数

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/engine-web/tests/helpers/walkthrough.js` | 新增 |
| `game/engine-web/tests/helpers/setup.js` | 引用 walkthrough.js |

## Contract Adherence

存档工具函数通过 `luaEval` 调用 `saveGameState` / `loadGameState`，不修改现有存档系统的内部实现。校验存档正确性通过读取存档后检查 JY 关键字段（金钱、物品、位置）完成。
