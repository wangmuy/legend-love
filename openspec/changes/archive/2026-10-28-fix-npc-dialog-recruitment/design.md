# fix-npc-dialog-recruitment — 设计文档

## 问题分析

### 调用链

```
oldevent 中调用 instruct_9(0, personId)
  → AsyncMessageBox.ShowYesNoCoroutine(-1, -1, "是否要求加入？")
    → AsyncDialog.getInstance():showYesNoCoroutine(message, {...})
      → dialog:showYesNo(...) 创建对话框 → hasDialog=true
      → while not done do scheduler:yield("dialog") end
        → coroutine.yield("dialog")  → 协程挂起，等待对话框关闭
```

### 根因

`processEventQueue` 中事件消费顺序问题：

```
1. 处理输入事件（hasDialog=true → 跳过）
2. AsyncDialog.update(0) ← 调用 handleInput() → lib.GetKey() → JSBridge.getEvent()
3. CoroutineScheduler.update(0) ← 强行恢复所有挂起协程
```

**问题：`AsyncDialog.handleInput` 使用 `lib.GetKey()` 读取 `JSBridge.getEvent()`**，与 `processEventQueue` 步骤 1 使用同一事件队列。当用户在对话框输入 `choose 1` 时：

- `processEventQueue` 步骤 1：`hasDialog=true` → 跳过，事件留在队列
- 步骤 2：`AsyncDialog.update` → `handleInput` → `lib.GetKey()` → `GetKey()` → `JSBridge.getEvent()` → 消费 `choose 1` → 关闭对话框 → 回调 `coroutine.resume(co, 1)` → `instruct_9` 返回 `true` ✅

但如果事件被 `processEventQueue` 步骤 1 错误消费（`hasDialog` 未及时设为 true），则步骤 2 的 `handleInput` 无事件可读，对话框永远关闭不了。

### 修复方案

**方案 A**（推荐）：`AsyncDialog.handleInput` 不再依赖 `lib.GetKey()`，改为从 `processEventQueue` 转发的事件读取。

1. 在 `processEventQueue` 中，当 `hasDialog=true` 时，将输入事件直接转发给 `AsyncDialog.handleInput`
2. `AsyncDialog.handleInput` 从独立缓冲区读取，不直接从 `JSBridge.getEvent()` 消费

**方案 B**：确保 `hasDialog` 在 `processEventQueue` 步骤 1 检查时始终正确，步骤 1 跳过事件，步骤 2 通过 `GetKey` 消费。

## 验证

1. 田伯光加入：高升客栈段誉加入已验证返回 `true`，修复后田伯光居 `choose 2` → `choose 1`(对话) → `choose 1`(是) 应加入队伍
2. 回归测试：P1-P9 全部通过