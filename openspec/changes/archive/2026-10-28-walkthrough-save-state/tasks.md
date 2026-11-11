## 1. 存档工具函数
Traceability: [REQ-WT-001]

- [x] 1.1 创建 `tests/helpers/walkthrough.js`
  Blast Radius: `["game/engine-web/tests/helpers/walkthrough.js"]`
  DoD:
    - [x] 包含 `saveTestState(page, slot)` 函数
    - [x] 包含 `loadTestState(page, slot)` 函数
    - [x] 导出两个函数供其他测试使用

- [x] 1.2 saveTestState 功能验证
  Blast Radius: `["game/engine-web/tests/helpers/walkthrough.js"]`
  DoD:
    - [x] 保存后通过 `luaEval` 验证 `saveGameState(slot)` 返回 true
    - [x] 保存前后 JY 状态一致

- [x] 1.3 loadTestState 功能验证（独立测试）
  Blast Radius: `["game/engine-web/tests/helpers/walkthrough.js"]`
  DoD:
    - [x] 先 save 再 load → 游戏状态恢复
    - [x] 加载后金钱、物品、位置、属性与保存时一致
    - [x] 无 gameLoop error

- [x] 1.4 存档槽隔离测试
  Blast Radius: `["game/engine-web/tests/helpers/walkthrough.js"]`
  DoD:
    - [x] 保存到 slot 11 → 保存不同状态到 slot 12
    - [x] 加载 slot 11 → 状态为第一个存档的值
    - [x] 加载 slot 12 → 状态为第二个存档的值
