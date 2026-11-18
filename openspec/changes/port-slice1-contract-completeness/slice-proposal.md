---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

本 slice 是引擎可移植性硬化的**第一步且不可省略**的基础设施层：
把 framework 通过两条隐式通道对 LÖVE 实现的依赖，变成 **EngineAPI 契约**。

### 现状证据（全部来自实测）

**证据 1：framework 里 46 处调用落在契约之外**

```
lib.DrawMMap     4 处    lib.ShowSlow      9 处
lib.GetMMap      5 处    lib.PicLoadFile   8 处
lib.PicInit      4 处    lib.SetClip       3 处
lib.DrawSMap     2 处    lib.PicLoadCache  2 处
lib.LoadPicture  2 处    lib.PlayMIDI      1 处
lib.UnloadMMap   1 处    lib.PlayMPEG      1 处
lib.CloudTick    1 处    lib.FillColor     1 处
lib.DrawRect     1 处    lib.EnableKeyRepeat 1 处
```

这 16 种函数在 EngineAPI 的 64 个声明里**一个都没有**。LÖVE 能跑是因为
`engine_love2d.lua:735` 的元表回退：

```lua
_G.lib = setmetatable(EngineAPI, { __index = lib })
```

**证据 2：在 MUD 引擎上这些都直接崩溃**

```
lib.DrawMMap        崩溃: attempt to call field 'DrawMMap' (a nil value)
lib.PicLoadCache    崩溃: attempt to call field 'PicLoadCache' (a nil value)
lib.GetMMap         崩溃: attempt to call field 'GetMMap' (a nil value)
lib.SetClip         崩溃: attempt to call field 'SetClip' (a nil value)
lib.CloudTick       崩溃: attempt to call field 'CloudTick' (a nil value)
lib.EnableKeyRepeat 崩溃: attempt to call field 'EnableKeyRepeat' (a nil value)
```

**证据 3：这是活体缺陷，不是"未来风险"**

`input-action-layer`（commit `33b89bc`）引入的虚拟手柄接线断了：

```lua
-- game/framework/jymain_adapter.lua:589-590
local okW, sw = pcall(EngineAPI.render.getWidth)    -- 契约里没有
local okH, sh = pcall(EngineAPI.render.getHeight)   -- 契约里没有
if not okW or not okH ... then return false end      -- 永远走这里
```

实测：`EngineAPI.render.getWidth = nil`。
**虚拟手柄在真机上永远不会激活**，而它 57 条逻辑测试全绿。
根因就是"契约缺函数 → 实现静默失效"。

**证据 4：契约里 38 个函数是死的**

```
契约声明 64 个，被实际调用 26 个，从未调用 38 个
sprite 子系统：5 个函数，0 个被调用（0%）
map    子系统：7 个函数，0 个被调用（0%）
render 子系统：7 个函数，1 个被调用（14%，且是 input-action-layer 新加的）
```

这说明契约**粒度设计错了**：`map.drawMain(playerX, playerY, playerPic)` 一个函数
要盖住 `lib_love` 里 79 行的等距投影 + 裁剪 + 云动画 + 建筑遮罩 + 玩家绘制，
没有任何引擎能靠这个签名还原相同画面，所以大家只好绕过它。

### 为什么必须独立成 slice

1. **4 个引擎实现同步扩展**（LÖVE / MUD / Web / 测试桩）。一旦某个引擎有问题，
   功能 slice 也会无法验收，故障定位变难。
2. **Slice 2 是本 slice 的下游**。没有完整契约就谈"解耦 140 处全局调用"是空转。
3. **契约签名设计本身有风险**（证据 4 显示现有粒度错）。签名一旦定下不能随意改，
   值得单独一段专注期。

## Parent Context

- Epic: `openspec/epics/2026-11-engine-portability/epic.md`
- Slice: 本文件即 slice 1
- 依赖: 无
- 被依赖: `port-slice2-script-decoupling`

## What Changes

1. **16 种 `lib.*` 提升为 EngineAPI 契约**（约 16 个新函数，粒度逐个论证）
2. **补齐 3 个缺失契约**：`render.getWidth` / `render.getHeight` / `font.measureText`
3. **191 处 `lib.Debug/GetKey/Delay/GetTime` 改为 `EngineAPI.*`**
   （这 4 个契约已存在，只是 framework 没用它们）
4. **修复虚拟手柄接线 bug**（`pollVirtualPad` 依赖 `render.getWidth/getHeight`）
5. **38 个 dead contract 逐个决策**（保留加说明 / 删除 / 降级为可选能力）
6. **4 引擎实现补齐**
7. **新建跨引擎契约一致性测试**（行为断言，不只是"能加载"）
8. **文档同步**：AGENTS.md 写"59 个函数"（实际 64，本 slice 后为 80+）

## Scope Boundaries

### In Scope

- `game/engine-love2d/engine_api.lua` 约 19 个新契约函数的定义与注释
- 4 个引擎实现（LOVE / MUD / Web / 测试桩）同步补齐
- `game/framework/` 24 个文件里 237 处调用改写（46 + 191）
- 虚拟手柄接线修复 + 端到端测试（注入触摸点，不依赖真实设备）
- 跨引擎契约一致性测试
- 文档计数同步

### Out of Scope

- script 全局函数解耦（140 处）→ slice 2
- sprite 动画 → slice 3
- resize 事件 / IME / audio 概念重设计 / 绘制原语扩展 → TODO.md
- 资产格式转换（.grp → SpriteFrames/Flipbook）→ 独立 epic
- 实际写 Godot/Unreal 引擎实现 → 本 epic 不写新引擎

## Requirements

### REQ-PORT1-1 引擎调用零绕过

`game/framework/*.lua` 里不得出现 `lib.*` 形式的引擎调用。
所有引擎操作必须通过 `EngineAPI.<module>.<function>` 或经 facade（slice 2 建立）。

**验收**：`grep -rn 'lib\.' game/framework/*.lua | grep -v 注释行` 命中数 = 0。

### REQ-PORT1-2 契约必须覆盖实际用法

每个新增契约函数的签名必须能覆盖 framework 现有的全部调用形式。
不得出现"契约为理想形态、实现却绕过它"的情况（即证据 4 的死契约问题）。

**验收**：新增契约后，`EngineAPI` 的 dead contract 比例从 38/64 降到 < 10 个。

### REQ-PORT1-3 四引擎实现齐全

`engine_api.lua` 声明的每个函数，在 LÖVE / MUD / Web / 测试桩 4 个实现里都必须存在。

**验收**：`test_engine_conformance` 遍历全部 4 个实现，逐个函数断言非 nil。

### REQ-PORT1-4 跨引擎行为一致性

同一套行为断言必须在 MUD 与 Web 上**真实执行**（不是"能加载就行"）。
对于无对应概念的引擎（如 MUD 无图形），断言其返回**哨兵值**且不抛错。

**验收**：`test_engine_conformance.lua` 在 MUD/Web 上跑真实调用，不 skip。

### REQ-PORT1-5 虚拟手柄必须真实激活

`JYMainAdapter.pollVirtualPad` 在 LÖVE 下必须能真实返回 true 并产出动作事件。

**验收**：端到端测试注入触摸点（`EngineAPI.input._touches`），断言：
- `pollVirtualPad()` 返回 true
- 动作队列里出现 `ui.accept` 且 `source == "touch"`

### REQ-PORT1-6 缺失契约的影响必须可观测

`font.measureText` 缺失时 `TextBoxLayout` 走 em 估算（已有 fallback，不崩）。
新增契约后必须保留 fallback，且在有 measureText 时优先使用。

**验收**：`TextBoxLayout.textWidth` 在两种情况下行为不同，且都有测试覆盖。

### REQ-PORT1-7 dead contract 决策留痕

38 个 dead contract 每个都必须有明确处置，记录在 `decisions.md`：
- **保留**：有明确未来消费者，写进注释说明
- **删除**：无意义或不可能是跨引擎概念
- **降级**：移入 `EngineAPI._optional` 命名空间

**验收**：`decisions.md` 覆盖 38 项，无遗漏。

### REQ-PORT1-8 零回归

全部既有测试零回归。基线 **3310 断言**（Lua 5.1）。

**验收**：四版本全量测试，断言数只增不减，失败数 0。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（契约是纯新增；`lib.*` 调用改写后行为不变）
- 现有功能回归风险：**中**（237 处调用改写，虽都是机械替换，但数量大）
- 缓解：按文件分批改，每批跑全量测试，每批一个 commit

## 关键设计决策（详见子 change 的 design.md）

| ADR | 决策 |
|-----|------|
| ADR-PORT-001 | 16 种 `lib.*` 逐个设计契约，不批量套模板（粒度决定可用性） |
| ADR-PORT-002 | `lib.Debug` → `EngineAPI.debug.log`（180 处批量替换） |
| ADR-PORT-003 | `lib.GetKey` → `EngineAPI.input.getKey`（但保留 VK 整数语义，迁移期不动） |
| ADR-PORT-004 | 地图绘制契约按**原语**而非语义拆分（现有 `drawMain` 太粗，是死契约根因） |
| ADR-PORT-005 | 精灵加载契约拆为 `initSprites` / `loadArchive` / `getSize` / `draw` 四级 |
| ADR-PORT-006 | dead contract 不删「有明确未来消费者」的，改为注释说明 + TODO 引用 |
| ADR-PORT-007 | 跨引擎一致性测试用**哨兵值**而非 skip，保证测试真实执行 |
