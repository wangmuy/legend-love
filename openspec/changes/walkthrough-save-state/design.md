## Context

攻略测试的第一步是实现存档跳转。Web MUD 已有 `saveGameState(slot)` / `loadGameState(slot)` 基于 IndexedDB 的存档系统，但未暴露给测试框架。测试需要封装一层工具函数来管理测试间的状态传递。

## Goals / Non-Goals

**Goals:**
- `saveTestState(page, slot)` 保存功能可用
- `loadTestState(page, slot)` 读档功能可用
- 存档往返测试覆盖
- 存档槽隔离测试覆盖

**Non-Goals:**
- 修改现有存档系统
- IndexedDB 性能优化
- 加密/压缩存档数据

## Architecture Decision Records

### ADR-001: reload 方式加载存档

- **Context**: `loadGameState` 在 worker 的 Lua VM 中执行，恢复 `JY.*` 状态。直接在当前页面调用可以工作，但游戏可能处于非预期状态（菜单打开、协程挂起等）。
- **Decision**: `loadTestState` 先 `page.reload()` 重置所有状态，再等页面就绪后调用 `loadGameState(slot)`。
- **Consequences**: 执行时间更长（~3s reload + ~3s worker init），但状态更干净。适合攻略测试（每个步骤开始都是确定状态）。

### ADR-002: 存档槽位名为数字

- **Context**: `saveGameState` 和 `loadGameState` 使用数字槽位（1~20）。
- **Decision**: 测试存档使用槽位 11~20（避免与玩家存档冲突），每个攻略步骤一个槽位。
- **Consequences**: 玩家存档（槽位 1~3）不会被测试覆盖。攻略步骤最多 10 步使用一组槽位，超过可扩展。

## API 设计

```javascript
// tests/helpers/walkthrough.js

/**
 * 保存当前游戏状态到测试槽位
 * @param {object} page - Playwright page
 * @param {number} slot - 槽位号 (11~20)
 * @returns {Promise<boolean>} 是否成功
 */
async function saveTestState(page, slot) {
  return luaEval(page, `return saveGameState(${slot})`);
}

/**
 * 从测试槽位加载游戏状态
 * @param {object} page - Playwright page
 * @param {number} slot - 槽位号 (11~20)
 * @returns {Promise<boolean>} 是否成功
 */
async function loadTestState(page, slot) {
  await page.reload();
  await waitForPageReady(page);
  return luaEval(page, `return loadGameState(${slot})`);
}
```

## Review Checklist

1. `saveTestState(11)` 后 `loadTestState(11)` 返回 true
2. 加载存档后 JY.Base["金钱"] 匹配存档前的值
3. 加载存档后 JY.Person[0]["姓名"] 匹配存档前的值
4. 槽位 11 和槽位 12 的存档不互相影响
