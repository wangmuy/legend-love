# Change Proposal: port-blocking-delay — 消除事件驱动架构里的阻塞等待

> 父 slice: `engine-portability`
> 前置: `battle-extensibility` ✓ / `port-sprite-native-migration` ✓ / `port-battle-robustness` ✓

## Why

事件驱动架构的核心承诺是「**永不阻塞 `love.update`**」。实测发现有**两处**
违反这个承诺，而且它们互相掩盖 —— 修一个会让另一个的后果更明显。

### 缺陷 1：`CoroutineScheduler:waitForTime` 根本不等待

```lua
function CoroutineScheduler:waitForTime(seconds)
    local startTime = self.timeSource and self.timeSource() or 0
    self:yield("time")        -- yield 一次就返回
    -- startTime 记录了但**从未用于判断**
end
```

**实测**（我构造的最小用例）：

```
s:waitForTime(0.1)          -- 期望等 100ms（@60fps ≈ 6 帧）
→ 协程在帧 2 恢复            -- 只等了 1 帧
```

**根因**：`CoroutineScheduler:update(dt)` 每帧无条件恢复所有
`waitingFor ~= "key"` 且 `~= "action"` 的协程（`coroutine_scheduler.lua:278-284`）：

```lua
for _, id in ipairs(activeCoroutines) do       -- activeCoroutines = 所有非 key/action 的
    local info = coroutines[id]
    if info and info.status == "suspended" then
        self:resume(id)                        -- 下一帧立刻唤醒
    end
end
```

所以 `yield("time")` 的效果 = "等 1 帧"，不管参数是 0.05 还是 0.1。

**4 个调用点全部受影响**：

| 调用点 | 参数 | 期望 | 实际 |
|--------|------|------|------|
| `async_wrapper.lua:78` | 任意 ms | 等 ms | 等 1 帧（16.7ms） |
| `event_bridge.lua:248` | 任意秒 | 等 sec | 等 1 帧 |
| `item_async.lua:293` | 0.05 | 50ms | ~16.7ms |
| `person_status_async.lua:132` | 0.1 | 100ms | ~16.7ms |

**用户可见症状**：物品栏 / 人物状态的"翻页防连按"节流失效 —— 按键太快时
一按跳好几页。而且 `WaitKeyTimeoutBypass(0.05)` 本身已有 50ms 超时，
再叠加"只等 1 帧"的 `waitForTime`，实际节奏是 66.7ms/轮而不是设计的 100ms/轮。

### 缺陷 2：`lib.Delay` 是真空闲阻塞（26 处，全部在活代码）

```lua
-- lib_love.lua:79
function Delay(millis)
    love.timer.sleep(millis/1000.0)     -- 真 sleep，阻塞整个进程
end
```

**实测**：协程里调它，主线程被占 **0.101 秒**（构造 100ms 用例）。

**26 处分布**（实测，全部活代码）：

| 函数 | 处数 | 有 async 版？ |
|------|------|--------------|
| `instruct_30`（主角走动） | 4 | ❌ **无** |
| `instruct_25` | 2 | ❌ |
| `instruct_27/44/57/58/62` | 各 1 | ❌ |
| `ShowPersonStatus` | 1 | ❌ |
| `SelectThing` | 1 | ❌ |
| `WaitKey`（阻塞版） | 1 | ✅ 有替代（但原函数仍在） |
| `ShowMenu`（阻塞版） | 1 | ✅ 有替代 |
| `ShowMenu2`（阻塞版） | 1 | ✅ 有替代 |
| `Game_Cycle` | 1 | ❌ |

**爆炸半径**：`instruct_30` 被 **7 个 oldevent 脚本**调用
（`oldevent_206` 等），走 `EventExecuteCoroutine` 的协程路径，
但协程里调阻塞 sleep = **阻塞整个进程**。

**用户可见症状**：主角"走一格"就卡 100ms（`CC.PersonMoveFrame` = 100），
走 10 格卡 1 秒。这是原有行为（`git log -S` 追到初始提交 `7cb8a1a`），
不是本 slice 引入的。

### 为什么两个缺陷必须一起修

**只修缺陷 1**：`waitForTime` 开始真等 100ms → 但 26 处 `lib.Delay`
仍阻塞 → 阻塞更显眼，且无法用 `waitForTime` 替换（`instruct_*` 是同步函数，
没有协程环境）。

**只修缺陷 2**：把 26 处 `lib.Delay` 改成 `waitForTime` → 但 `waitForTime`
不等 → 走动动画变成"瞬间跳完"（更快但动画没了）。

**⇒ 必须成对修**。

---

## In Scope

### 1. 修 `waitForTime` 让它真等待（批 1，低风险）

给协程信息加 `deadline` 字段：

```lua
function CoroutineScheduler:waitForTime(seconds)
    local now = self.timeSource and self.timeSource() or 0
    local self_info = coroutines[currentCoroutine]
    self_info.deadline = now + seconds * 1000      -- 毫秒
    self:yield("time")
    self_info.deadline = nil                        -- 恢复后清空
end
```

`update(dt)` 的"恢复其他协程"段改为**检查 deadline**：

```lua
for _, id in ipairs(activeCoroutines) do
    local info = coroutines[id]
    if info and info.status == "suspended" then
        if info.deadline and now < info.deadline then
            -- 还没到时间，本帧跳过
        else
            info.deadline = nil
            self:resume(id)
        end
    end
end
```

### 2. 给 7 个 `instruct_*` 补协程版本（批 2，中等风险）

`instruct_30` 的阻塞在"每走一格等 100ms"。正确做法：

```lua
-- 新增（async_globals 注入）
instruct_30 = function(x1,y1,x2,y2)
    local scheduler = CoroutineScheduler.getInstance()
    scheduler:create(function()
        -- 逐格移动 + scheduler:waitForTime(PersonMoveFrame/1000)
    end, "instruct_30")
end
```

### 3. 26 处 `lib.Delay` 的处置

| 位置 | 处置 |
|------|------|
| `instruct_30` 等 7 个 | 移到新的 async 版本里，用 `waitForTime` |
| `WaitKey`/`ShowMenu`/`ShowMenu2`（已有 async 版） | 原函数保留（死代码），加注释说明 |
| `Game_Cycle` | 检查是否死代码 |

---

## Out of Scope

```
✗ 把 lib.Delay 从引擎里删掉 → 它是 ~130 处 lib.* 的高频成员，其他调用点合法
✗ 改 CC.Frame 的数值（50ms）→ 那是游戏设计参数
✗ 帧率无关的精确动画（用 dt 累加）→ 属 port-sprite-animation 的领域
```

## 关键度量

| 指标 | 基线（实测） | 目标 |
|------|-------------|------|
| `waitForTime(0.1)` 实际等待 | **1 帧（16.7ms）** | >= 6 帧（100ms） |
| `waitForTime(0.05)` 实际等待 | 1 帧 | >= 3 帧（50ms） |
| `lint.Delay` 阻塞调用 | 26 处（全部活代码） | 0 处（或加注释说明为何保留） |
| `instruct_30` 有 async 版 | ❌ | ✅ |
| 物品栏/人物状态翻页节流 | 66.7ms/轮 | 100ms/轮（设计值） |

## 风险

| 风险 | 缓解 |
|------|------|
| 修 waitForTime 会让所有动画**变慢**（从 1 帧变 N 帧） | 这是**修 bug**，不是回归；但需要实机确认动画不变得"太拖沓" |
| `deadline` 字段与其他协程状态冲突 | 只在 `waitForTime` 内设置，恢复后清空 |
| 给 7 个 `instruct_*` 补 async 版本，行为可能与阻塞版不一致 | 逐函数对照原实现；实机跑"主角走动 + 场景切换 + 战斗" |
| `EventBridge:waitForTime` 是公开 API，改语义可能影响别处 | 实测只有 1 个调用点（`async_wrapper:78`） |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-BD-1 | `waitForTime(seconds)` 必须真的等 seconds | specs/scheduler-wait/spec.md |
| REQ-BD-2 | `instruct_30` 等必须有 async 版本 | 同上 |
| REQ-BD-3 | `lib.Delay` 的阻塞不得出现在事件回调路径 | 同上 |
