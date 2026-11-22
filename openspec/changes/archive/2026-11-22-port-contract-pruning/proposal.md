# Change Proposal: port-contract-pruning — 删除 3 个无用契约

> 父 slice: `engine-portability`

## Why

`engine_api.lua` 声明 **79 个**契约。实测其中 **22 个**在 `framework/` +
`script/` 里**零调用点**。但"零调用点"≠"可删" —— 我逐个核实了 4 个引擎实现，
发现：

| 契约 | framework/script 消费者 | 引擎内部引用 | 判定 |
|------|------------------------|-------------|------|
| `sprite.getSize` | 0 | 4 引擎都只有定义行（1/1/1/1） | ✅ 可删 |
| `coroutine.yieldPoint` | 0 | 同上 | ✅ 可删 |
| `coroutine.waitFor` | 0 | 同上 | ✅ 可删 |
| `file.open` | 0 | **web 的 `openFile` 内部转发它**（web 里出现 3 次） | ❌ 不能删 |
| `input.setKeyRepeat` | 0 | **web 的 lib 别名表引用它**（`if key == "EnableKeyRepeat" then return EngineAPI.input.setKeyRepeat end`） | ❌ 不能删 |

**⇒ 只有 3 个是真可删。**

### 为什么值得删

1. **`sprite.getSize` 与 `sprite.getMeta` 语义重复**：后者收 handle（格式透明），
   前者收 `(archiveId, spriteId)`（引擎要维护 archive 表 = ADR-PORT-013 要消除的形态）。
   留着它会误导新引擎实现者以为要支持两种。
2. **`coroutine.yieldPoint` / `waitFor` 与 `coroutine_scheduler` 重复**：
   framework 已有完整的协程调度器，引擎不需要提供协程原语。
3. **减少"新引擎最小实现集"的规模**：79 → 76。

---

## In Scope

### 1. 从契约文件删除 3 个声明（含注释块）

`game/engine-love2d/engine_api.lua`：
- `M.sprite.getSize(archiveId, spriteId)`
- `M.coroutine.yieldPoint()`
- `M.coroutine.waitFor(condition, timeout)`

### 2. 从 4 个引擎实现删除对应函数

- `engine_love2d.lua`
- `engine_mud.lua`
- `engine_web.lua`
- `tests/engine_test.lua`

### 3. 删除 `test_engine_api.lua` 的 3 条 `assertNotNil`

---

## Out of Scope

```
✗ file.open / input.setKeyRepeat → 引擎内部有引用，删了会破坏 web 实现
✗ 其余 17 个死契约 → 等前置 change（map 透明化 / audio 概念重设计）
✗ 任何行为改动 → 本 change 只删代码，不改逻辑
```

## 关键度量

| 指标 | 基线（实测） | 目标 |
|------|-------------|------|
| `engine_api.lua` 契约数 | **79** | **76** |
| 4 个引擎的 3 个函数 | 各 1 处 | **0** |
| 行为 | — | **零变化**（这 3 个本来就无人调用） |

## 风险

| 风险 | 缓解 |
|------|------|
| 某个外部调用点（不在本仓）用了这 3 个 | 本仓是唯一消费者；且它们本来就是死契约 |
| `test_engine_api.lua` 的契约覆盖断言漏删 | 逐条 grep 核实 |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-CP-1 | 3 个契约从契约文件与 4 引擎删除 | specs/contract-pruning/spec.md |
| REQ-CP-2 | 行为零变化 | 同上 |
