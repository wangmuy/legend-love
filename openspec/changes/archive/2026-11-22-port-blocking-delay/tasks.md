# Tasks: port-blocking-delay

> 分两批：**批 1**（修 waitForTime，低风险）→ **批 2**（26 处 lib.Delay，中等风险）
> 两个缺陷互相掩盖，必须成对修（见 proposal「为什么必须一起修」）

## Task 1：修 `CoroutineScheduler:waitForTime`（批 1）

**Blast Radius**：`game/framework/coroutine_scheduler.lua`

**DoD**：
- [x] `waitForTime(seconds)` 把 deadline 写进当前协程的 info（毫秒）
- [x] `update(dt)` 的"恢复其他协程"段检查 deadline：未到期则**跳过本帧**
- [x] 到期恢复后清空 `deadline`（不留残留）
- [x] `seconds <= 0` 时不设 deadline（下一帧就恢复）
- [x] 单测：`waitForTime(0.1)` 在 60fps 下 >= 6 帧才恢复（当前是帧 2）
- [x] 单测：`waitForTime(0.05)` >= 3 帧
- [x] 单测：`waitForTime(0)` 下一帧恢复
- [x] 单测：恢复后 `deadline == nil`
- [x] 负向对照：把 deadline 检查去掉 → 测试 FAIL
- [x] 四版本全量测试零失败
- [x] 实机：物品栏/人物状态翻页节流变正常（不再一次跳几页）
- [x] 一个 commit

---

## Task 2：`instruct_30` 等 7 个函数的阻塞处置（批 2）

**Blast Radius**：`game/script/jymain.lua`、`game/script/battle/*.lua`、
`game/framework/coroutine_scheduler.lua`

### 【方案修正】不需要 async 包装，改用 WaitFrame

原计划「给 `instruct_30` 补协程版本」。实测发现**不需要** —— 因为这些函数
**本来就在事件协程里跑**：

```
EventExecuteCoroutine → oldCallEventCoroutine → instruct_30
```

所以它们内部可以**直接**用 `scheduler:waitForTime` 的协作式等待，
`yield` 会自动冒泡到调度器。加一层 async 包装是多余的。

### 实测证据

```
模拟 instruct_30 式同步函数（4 次 WaitFrame(100)）：
  启动后立即返回: steps=1  lib.Delay=0    ← 不阻塞
  推进 40 帧后:   steps=4  lib.Delay=0    ← 全部走协作等待
```

### 实际改动

新增 3 个 API：

| API | 位置 | 作用 |
|-----|------|------|
| `CoroutineScheduler:isInCoroutine()` | `framework/coroutine_scheduler.lua` | 是否在**本调度器**的协程里（不是 `coroutine.running()`） |
| `CoroutineScheduler:waitFrame(ms, fallback)` | 同上 | 协程里 `waitForTime(ms/1000)`；非协程退回 fallback |
| `WaitFrame(ms)` | `script/jymain.lua`（**global**） | 供 `script/` 各处调用 |

**为什么 `WaitFrame` 是全局**：`script/battle/*.lua` 是全局函数定义
（不是 `return { ... }` 表），看不到 `jymain` 的 local。

### 26 处替换

| 文件 | 处数 |
|------|------|
| `script/jymain.lua` | 17（含 `instruct_25/27/30/44/57/58/62` 的帧率控制） |
| `script/battle/battle_flow.lua` | 4 |
| `script/battle/battle_action.lua` | 2 |
| `script/battle/battle_ai.lua` | 2 |
| `script/newevent/scene_1_event_19.lua` | 1 |

**DoD**：
- [x] `scheduler:isInCoroutine()` / `scheduler:waitFrame()` 实现
- [x] `WaitFrame(ms)`（global）实现，带 fallback
- [x] 26 处 `lib.Delay` → `WaitFrame`（实测只剩 helper 内的 fallback 1 处）
- [x] 单测：`test_wait_frame.lua`（14 条）——协程里不阻塞 / 非协程回退 / 边界值
- [x] 单测：负向对照（把 WaitFrame 改回 `lib.Delay` → FAIL）
- [x] **实测**：`instruct_30` 式循环不调 `lib.Delay`（`lib.Delay=0`）
- [x] 搬移保真白名单加 4 个函数（`War_MovePerson`/`War_ShowFight`/`War_Auto`/`War_AutoEatDrug`）
- [x] 四版本全量测试零失败
- [x] 实机：主角家对话场景正常（地图不再全黑）

---

## Task 3：其余函数的处置结论

**Blast Radius**：同 Task 2

**DoD**：
- [x] `instruct_25`（2 处）：帧率控制 → `WaitFrame`
- [x] `instruct_27`（1 处）：动画帧控制 → `WaitFrame`
- [x] `instruct_30`（4 处）：主角走动帧控制 → `WaitFrame`
- [x] `instruct_44/57`（各 1 处）：动画帧控制 → `WaitFrame`
- [x] `instruct_58`（1 处 `Delay(300)`）：固定等待 → `WaitFrame`
- [x] `instruct_62`（1 处 `Delay(5000)`）：固定等待 → `WaitFrame`
- [x] `ShowPersonStatus` / `SelectThing`（各 1 处）→ `WaitFrame`
- [x] `Game_Cycle`（1 处）→ `WaitFrame`
- [x] `WaitKey`（1 处 `Delay(20)`）→ `WaitFrame`（阻塞版仍在，但有 async 替代）
- [x] `ShowMenu` / `ShowMenu2`（各 1 处）→ `WaitFrame`
- [x] `battle_flow` 4 处、`battle_action` 2 处、`battle_ai` 2 处 → `WaitFrame`
- [x] `scene_1_event_19` 1 处 → `WaitFrame`
- [x] 四版本全量测试零失败

---

## Task 4：门禁 + 全量验证

**Blast Radius**：`game/tests/gate_engine_contract.sh`、`openspec/project/TODO.md`

**DoD**：
- [x] 新增断言：`script/` 的 `lib.Delay` 只在 `WaitFrame` 的 fallback 里（其余为 0）
      → gate STEP D3（awk 实现）
- [x] 负向对照：把某处 `WaitFrame(` 改回 `lib.Delay(` → gate FAIL（实测）
      → `[FAIL] script/ 仍有 1 处裸 lib.Delay`
- [x] 四版本全量测试零失败（记录断言数）
- [x] 全仓 `luac5.1 -p` / `luac55 -p` 零失败
- [x] 五门禁全 PASS
- [x] **实机验证**：主角走动 / 场景切换 / 物品栏翻页 / 人物状态翻页
- [x] 更新 `TODO.md`
- [x] 一个 commit
