## 为什么

当前 `slice-walkthrough-e2e-tests` 的 P1-P10 测试已验证了场景导航、NPC 招人、战斗、菜单操作等基础功能，但**缺少 14 天书收集和通关的完整 e2e 验证**。14 天书收集是金庸群侠传的核心主线，当前测试仅覆盖了 2 本天书（雪山飞狐、鸳鸯刀），其余 12 本天书的事件脚本有 11 本仍为注释状态，未在测试中验证。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/slice-walkthrough-e2e-tests/change-manifest.md`
- 参考攻略: `game/engine-web/quick_pass_game.md`
- 依赖: walkthrough-main-quest, walkthrough-save-state

## What Changes

### Phase 1: 解锁天书事件脚本
解锁 11 个被注释的天书相关 oldevent 脚本，使其可被 NPC 对话触发。

### Phase 2: 实现天书获取测试
为每个天书场景添加 NPC 对话→获取天书的 e2e 测试步骤，验证：
- 天书对应 NPC 对话可触发
- 事件执行后玩家获得对应天书物品
- 无 gameLoop error

### Phase 3: 圣堂通关测试
- 收集全部 14 天书后，进入圣堂放置天书
- 验证十大高手战斗触发（oldevent_1015）
- 验证通关对话（oldevent_1016→1017）

## Scope Boundaries

### In Scope
- 解锁 14 天书对应的 oldevent 脚本（取消 `--function` 注释）
- 为每个天书场景添加 NPC 对话和天书获取验证的 e2e 测试
- 圣堂放置天书事件验证
- 纯用户命令（`choose`/`list`/`leave`/`look`）
- 存档跳转模式（`saveTestState`/`loadTestState`）

### Out of Scope
- 像素级 UI 验证
- 任何非用户命令的操作（luaEval 注入等）

### 后续任务（已纳入 tasks.md 第5节）
- **飞狐外传条件触发**（5.1）：需实现队伍/物品条件检查逻辑（胡斐在队伍 + 屠龙刀 + 金丝背心）
- **光明顶倚天屠龙记数据修复**（5.2）：场景11 NPC 数据在提取时缺失，需修复数据提取管线

## Capabilities

### New Capabilities
- `walkthrough-14-books` [REQ-WT-003]: 14 天书收集和通关的 e2e 测试

## Impact

| 影响面 | 说明 |
|--------|------|
| `game/script/oldevent/oldevent_*.lua` | 解锁 11 个天书相关事件脚本 |
| `game/engine-web/tests/walkthrough-p*.spec.js` | 新增天书获取测试步骤 |
| `game/engine-web/quick_pass_game.md` | 更新天书获取操作说明 |

## Contract Adherence

测试通过纯用户命令驱动（`choose`/`list`/`leave`/`look`）。存档跳转使用 `saveTestState`/`loadTestState`，与玩家手动存档使用同一路径。无 luaEval 注入、无测试专用代码。