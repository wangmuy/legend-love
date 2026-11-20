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

## Task 2：给 `instruct_30` 补 async 版本（批 2 起）

**Blast Radius**：`game/framework/async_globals.lua`、`game/framework/async_wrapper.lua`

**DoD**：
- [x] 新增 `instruct_30` 的包装：起协程 + 逐格 `waitForTime(CC.PersonMoveFrame/1000)`
- [x] **行为对照**：原实现是「每格：移动 + 等 (PersonMoveFrame - 耗时)」→ 新实现等价
- [x] 保留原 `instruct_30`（script 层仍有同步调用点？先核实）
- [x] 单测：`instruct_30` 包装器存在且返回协程
- [x] 单测：协程内**不调用** `lib.Delay`
- [x] 四版本全量测试零失败
- [x] 实机：主角走动流畅（不卡 100ms/格）
- [x] 一个 commit

---

## Task 3：其余 6 个 `instruct_*` 的处置

**Blast Radius**：`game/framework/async_globals.lua`

**DoD**：
- [x] `instruct_25`（2 处 Delay）：核实是否可达 → 处置
- [x] `instruct_27/44/57/58/62`（各 1 处）：同上
- [x] `ShowPersonStatus` / `SelectThing`（各 1 处）：同上
- [x] `Game_Cycle`（1 处）：核实是否死代码
- [x] `WaitKey`/`ShowMenu`/`ShowMenu2`（各 1 处）：**已有 async 版** →
      原函数加注释「阻塞版，仅非协程上下文兜底用」
- [x] 每处都有明确结论（改 / 保留+注释 / 确认死代码）
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 4：门禁 + 全量验证

**Blast Radius**：`game/tests/gate_engine_contract.sh`、`openspec/project/TODO.md`

**DoD**：
- [x] 新增断言：`instruct_30` 有 async 版本（`async_globals` 里有对应包装）
- [x] 新增断言：协程路径里无 `lib.Delay`（静态检查 `async_globals`/`async_wrapper`）
- [x] 负向对照：在 `async_globals` 加 `lib.Delay(` → gate FAIL
- [x] 四版本全量测试零失败（记录断言数）
- [x] 全仓 `luac5.1 -p` / `luac55 -p` 零失败
- [x] 五门禁全 PASS
- [x] **实机验证**：主角走动 / 场景切换 / 物品栏翻页 / 人物状态翻页
- [x] 更新 `TODO.md`
- [x] 一个 commit
