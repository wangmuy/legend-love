# 存档跳转机制 — 规格说明

## [REQ-WT-001-01] saveTestState

| 字段 | 值 |
|------|-----|
| 名称 | 测试存档保存 |
| 优先级 | P0 |
| 验证方式 | 自动化测试 |

**Given** 游戏已在运行状态（任一 JY.Status）
**When** 调用 `saveTestState(page, slot)`
**Then** 存档应成功保存到 IndexedDB

## [REQ-WT-001-02] loadTestState

| 字段 | 值 |
|------|-----|
| 名称 | 测试存档加载 |
| 优先级 | P0 |
| 验证方式 | 自动化测试 |

**Given** 已有保存的测试存档
**When** 调用 `loadTestState(page, slot)`
**Then** 游戏状态应恢复到保存时的状态

## [REQ-WT-001-03] 存档槽隔离

| 字段 | 值 |
|------|-----|
| 名称 | 存档槽隔离 |
| 优先级 | P1 |
| 验证方式 | 自动化测试 |

**Given** slot 11 和 slot 12 保存了不同状态
**When** 加载 slot 11
**Then** 游戏状态为 slot 11 的内容
**When** 加载 slot 12
**Then** 游戏状态为 slot 12 的内容
