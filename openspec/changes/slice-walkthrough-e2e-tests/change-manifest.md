# Change Manifest — 攻略 e2e 测试

## 定位
横向 slice，验证 Web MUD 完整游戏流程可通关。
基于存档跳转的攻略式 e2e 测试，覆盖从开局到通关的核心路径。

## 依赖顺序

```
slice-walkthrough-e2e-tests (攻略 e2e 测试)
        │
        ├── walkthrough-save-state    (测试存档/读档机制)
        │
        └── walkthrough-main-quest    (快速通关主线 + 完整攻略)
```

## Change Assignments

### 1. walkthrough-save-state

| 字段 | 值 |
|------|-----|
| Scope | 测试框架中的存档/读档工具函数 |
| Responsibility | 封装 `saveTestState`/`loadTestState`，基于现有 `saveGameState`/`loadGameState` 实现 |
| Depends on | slice-event-system-integration, state-persistence |

### 2. walkthrough-main-quest

| 字段 | 值 |
|------|-----|
| Scope | 快速通关主线测试 + 完整攻略测试 |
| Responsibility | 定义黄金路径，编写逐步骤的 e2e 测试用例 |
| Depends on | walkthrough-save-state |

### 3. walkthrough-14-books

| 字段 | 值 |
|------|-----|
| Scope | 14 天书收集和通关的 e2e 测试 |
| Responsibility | 解锁天书事件脚本，为每本天书添加 NPC 对话→获取验证，圣堂放置天书验证 |
| Depends on | walkthrough-main-quest |

## Shared Contracts

| 约定 | 规则 |
|------|------|
| `saveTestState(slot)` | 保存当前游戏状态到指定槽位 |
| `loadTestState(slot)` | 从指定槽位恢复游戏状态 |
| 存档槽位 | 每个攻略步骤使用独立的槽位序号 |
