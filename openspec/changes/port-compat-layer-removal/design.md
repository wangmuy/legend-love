# Design: port-compat-layer-removal

## ADR-PORT-016：`_G.lib` 不是给事件脚本用的，是给引擎自引用用的

### Context

`engine-portability` slice 在 `port-native-api-completion` 的 proposal 里写：

> `_G.lib` 兼容层**保留**（Task 5 是可选，且默认不做）
> 理由：`oldevent` 脚本仍需 `lib.*`

本轮实测（2026-11-21）逐字节扫描了 **27808 个事件脚本**：

```
game/script/oldevent/*.lua        1018 个
game/mods/*/script/oldevent/*.lua 26790 个（20 个 MOD 各自的完整事件数据）
```

结论：

| 探测项 | 命中 |
|--------|------|
| 含子串 `lib` | 0 |
| 含 `lib.xxx(` 调用 | 0 |
| 含 `DrawString`/`Cls`/`ShowScreen`/`ShowMenu`/`WaitKey`/`TalkEx` | 0 |
| 含 `PlayMIDI`/`PlayMPEG`/`LoadPicture`/`PicLoad*` | 0 |
| **非** `instruct_*` 的全局调用 | **0** |
| `instruct_0..67`（缺 7）| 67 个，基础与 MOD 完全一致 |

事件数据层的调用面**恰好是 `instruct_0..67`**（`instruct_7` 被翻译成 `return`，
所以实际是 67 个），没有任何一个是 `lib.*` 或绘制全局。

### Decision

`_G.lib` 的性质是**引擎内部的自引用桥**，不是脚本兼容层：

1. `lib_love.lua` 用 `setfenv/_ENV = M`（`getmetatable(M).__index = _G`），
   所以文件里写 `lib.Debug(...)` 会经 `M` 落到 `_G.lib` —— 而 `_G.lib` 是
   `engine_love2d` 建的、`__index = lib_love` 的表。**循环依赖**。
2. `main.lua` 用全局 `lib`（其实拿的是 `engine_love2d` 的 EngineAPI 表）。
3. `async_globals` 用 `lib.Delay` 当补丁点（其实写的是 `EngineAPI.Delay`）。

### Alternatives considered

| 方案 | 否决理由 |
|------|---------|
| 保留 `_G.lib`，只加门禁禁止新代码用 | 循环依赖仍在；`lib.Delay` 补丁点错位仍在 |
| 把 `_G.lib` 换成 `_G.lib = lib_love` | 与「script 走 EngineAPI」方向冲突，且 lib_love 缺 30 个 EngineAPI 函数 |
| **删除 `_G.lib`，把 5 处消费者逐个改契约**（本决策） | 改动面 5 处，全部可枚举 |

### Consequences

**Positive**

- 「换引擎只需写 `engine-xxx`」不再被一条隐式回退掩盖
- `async_globals` 的 Delay 补丁点从「伪装成 `EngineAPI.Delay` 的新键」
  改为「覆盖 `EngineAPI.time.sleep`」，语义正确
- `lib_love` 的 8 处自引用必须先改掉 —— 顺带暴露了循环依赖

**Negative**

- MUD/Web 引擎若自身代码用全局 `lib`，会一起崩 → 本 change 要求先 `grep` 确认
- 测试桩 `engine_test.lua:621` 与 `test_helper.lua:274` 都建 `_G.lib`，
  需同步确认它们的用途是「测试桩模拟」而非被测代码依赖

## ADR-PORT-017：`SetDrawLoopFlag` 必须是契约，不能是引擎私有钩子

### Context

`lib_love.SetDrawLoopFlag` 控制 `ShowSurface/ShowSlow` 是否真的 `present()`：

```lua
local inDrawLoop = false
function SetDrawLoopFlag(flag) inDrawLoop = flag end
function ShowSurface(flag) if inDrawLoop then love.graphics.present() end end
```

`main.lua` 在 `love.draw()` 前后置位/复位它 —— 这是**入口程序的职责**。
但入口程序通过全局 `lib` 调它 → 换引擎时新入口要自己发明一个同名全局。

### Decision

新增契约 `render.setDrawLoopFlag(flag)`。语义：告诉引擎「当前在帧绘制回调内」，
引擎可据此决定 `present()` 是否立即生效。

- LÖVE：转发 `lib.SetDrawLoopFlag`
- MUD/Web：空实现（它们没有 `love.draw` 概念）
- 测试桩：记录调用

### Alternatives considered

| 方案 | 否决理由 |
|------|---------|
| 把 `SetDrawLoopFlag` 改成 `EngineAPI.SetDrawLoopFlag`（既有偷渡键） | `engine_love2d:1126` 已经这么干了，但没写进 `engine_api.lua` → 契约不完整（`port-contract-completeness` 的教训） |
| 让 `present()` 自己检测是否在 draw 回调内 | LÖVE 无此 API；Godot 也不需要这个概念 → 属引擎特性，不该框架猜 |

## Negative Constraints

- **不得**给 `engine_api.lua` 加「`Delay`」这种非契约表键（那是本 change 要消除的形态）；
  只加 `render.setDrawLoopFlag`
- **不得**删 `lib_love.lua` 本体（那是 `port-legacy-picture-removal`）
- **不得**改 `async_globals` 的另外 8 个替换（`ShowMenu`/`TalkEx`/`WaitKey`/… 换的是
  script 全局，与 `lib` 无关）

## Review Checklist

- [ ] `grep -rn '_G.lib' game/` 只剩 `engine-*` 与 `tests/`
- [ ] `grep -nE '\blib\.' game/engine-love2d/lib_love.lua`（非注释）= 0
- [ ] `async_globals` 的 Delay 补丁点在 `EngineAPI.time.sleep`，不在 `lib.Delay`
- [ ] `WaitFrame` 的 fallback 语义仍是「非协程才阻塞」，且有单测锁定
- [ ] 三界面截图 md5 与基线一致
- [ ] MUD 引擎冒烟（内存/延迟不适用，只需不崩）
