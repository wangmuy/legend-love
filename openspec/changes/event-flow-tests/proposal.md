## 为什么

前三个 sub-change 实现了事件执行的基础设施。但只有通过真实游戏流程测试，才能验证 oldevent 脚本在 Web MUD 中的执行是否正确。

## Parent Context

- Epic: `openspec/epics/2026-06-web-mud-text-version/epic.md`
- Slice: `openspec/changes/event-system-integration/change-manifest.md`
- 依赖: event-executor-loader, instruct-stubs, event-data-access

## What Changes

创建 `tests/event-flow.spec.js`，包含以下游戏流程测试：

### TC-01: 软体娃娃对话（oldevent_691）
```
开始游戏 → 主角的家 → look
→ choose 1(软体娃娃) → 对话
→ instruct_1 输出对话文本
→ WaitKey → 继续
→ 事件结束 → 回到场景
```

### TC-02: 悦来客栈店小二
```
主角的家 → leave → MMAP → list
→ 悦来客栈 → look → 店小二 → 对话
→ 事件执行
```

### TC-03: 南贤对话
```
MMAP → list → 南贤居 → 进入 → 南贤 → 对话
```

### TC-04: 泛化 oldevent 执行
```
luaEval 加载 5 个随机 oldevent 脚本
验证 load + execute 不崩溃
```

## Impact

| 文件 | 改动 |
|------|------|
| `tests/event-flow.spec.js` | 新增 |
