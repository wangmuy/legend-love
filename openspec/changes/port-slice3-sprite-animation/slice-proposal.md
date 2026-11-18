---
status: active
created: 2026-11
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

本 slice 是三个 slice 里**唯一有用户价值**的一个：让动画可按时间驱动。

### 现状证据（实测）

**证据 1：「动画」当前全部实现就是一个整数自增**

```lua
-- game/script/jymain.lua:624
function GetMyPic()
    if JY.MyCurrentPic > 6 then JY.MyCurrentPic = 1 end
    if JY.Base["乘船"] == 0 then
        n = CC.MyStartPic + JY.Base["人方向"]*7 + JY.MyCurrentPic
    else
        n = CC.BoatStartPic + JY.Base["人方向"]*4 + JY.MyCurrentPic
    end
    return n
end

-- game/script/jymain.lua:645
function AddMyCurrentPic() JY.MyCurrentPic = JY.MyCurrentPic + 1 end
```

**证据 2：帧号由「走一格加一帧」驱动，不是时间**

```lua
-- game/framework/game_states.lua:248, 300, 457, 790（4 处调用）
AddMyCurrentPic()      -- 每移动一格调用一次
```

后果：
- **帧率与移动速度绑死**：改移速动画就变速
- **不移动时动画完全静止**：连待机摆动都没有
- **没有播放模式**：无 loop / once / pingpong / 结束回调
- **新动画加不了**：战斗特效、场景动画各自硬编码

**证据 3：`dt` 已经在位，但没人用它驱动动画**

```
love.update(dt)
  → JYMainAdapter.update(dt)
  → EventBridge:update(dt)
      → InputManager.update(dt) / CoroutineScheduler.update(dt)
      → AsyncDialog.update(dt)
      → StateMachine.update(dt)
```

整条链上 `dt` 畅通，但**零处代码用它推进动画**。

**证据 4：sprite 契约只有 5 个函数，零动画概念**

```lua
sprite.initSprites()      sprite.draw(...)
sprite.loadArchive()      sprite.drawTinted(...)
sprite.getSize()
```

---

## 核心设计：为什么动画必须住在 framework，不能借引擎的动画播放器

这是本 slice 最关键的判断，依据是**实测三大外部引擎的官方 API 形态**：

| 引擎 | 动画能力 | 绑定到什么 |
|------|---------|-----------|
| LÖVE 11.5 | `love.graphics.draw(quad, ...)` | Quad（自定义纹理区域，**无资产格式**） |
| Godot 4 | `AnimatedSprite2D` + `SpriteFrames` | **资产格式**（`.tres` 资源） |
| Unreal 5 | `PaperFlipbookComponent` + `PaperFlipbook` | **资产格式**（`.uasset`） |
| SDL2 | `SDL_RenderCopy(srcRect)` | 无动画概念 |

**Godot 与 Unreal 的动画播放器都绑死各自的资产管线。**
要把本项目自研的 `.idx`/`.grp` 格式喂给它们，需要做**资产格式转换**
（`.grp` → `SpriteFrames` / `Flipbook`），那是数据迁移 + 工具链建设，
不是 API 适配，工作量远大于本 epic。

**三者的唯一公共子集是：**

```
"给定 archiveId 和一个不透明整数帧号，把这一帧画在 (x, y)"
```

四种实现都能满足同一个签名：

```
LÖVE   : quad = archive[frameId]; love.graphics.draw(quad, x, y)
Godot  : sprite2d.texture = archive; sprite2d.frame = frameId
Unreal : paperSprite.SetSpriteIndex(frameId)
SDL    : blit(texture, &archive[frameId], x, y)
```

所以正确形态是：

```
        framework/sprite_anim.lua          ← 纯逻辑：帧序列 + 时间推进 + 状态机
                │
                │  只调这一个契约（已存在，无需新增）
                ▼
        EngineAPI.sprite.draw(archiveId, frameId, x, y, flags, alpha)
```

**动画播放器绝不能由引擎提供。** 一旦把动画交给引擎，就会陷入
"Godot 有 SpriteFrames、Unreal 有 Flipbook、SDL 什么都没有"的三方分裂。

---

## 关键决策：帧号是「不透明整数」，framework 永不解释其内部含义

**依据：现有帧号语义就是绝对索引。**

```lua
-- GetMyPic：帧的"身份"是 archive 内的**绝对编号**
n = CC.MyStartPic + JY.Base["人方向"] * 7 + JY.MyCurrentPic
```

这与 Godot/Unreal 的"区域性子索引"模型（`hframes/vframes` 分割后的序号）不同，
但**恰好是最容易跨引擎对齐的形态**：

```
LÖVE  : frameId = .grp 里的绝对索引（现有实现）
Godot  : frameId = loadArchive 建立的索引映射（可能是 hframes/vframes 组合）
Unreal : frameId = PaperSprite 在 atlas 内的序号
SDL    : frameId = 纹理数组下标
```

`loadArchive` 负责建立该引擎下 `frameId → 实际纹理区域` 的映射。
**framework 只把它当不透明句柄传递，永不做数学运算。**

约束：framework 代码里**不得出现** `frameId + 1`、`frameId * 2`、
`frameId % 7` 这类运算。当前 `AddMyCurrentPic` 的 `+1` 与 `GetMyPic`
的 `+ 方向*7` 都要移进序列定义（属于游戏层数据，不属于动画逻辑）。

---

## Parent Context

- Epic: `openspec/epics/2026-11-engine-portability/epic.md`
- Slice: 本文件即 slice 3
- 依赖: 无（只依赖既有 `EngineAPI.sprite.draw` 契约，slice 1 已确认它可用）
- 被依赖: 无
- **注意**：与 slice 2 有文件级冲突风险（都要改 `game_states.lua`），
  建议 slice 2 先做

## What Changes

1. **新建 `framework/sprite_anim.lua`**（**零引擎依赖**，可纯算法单测）：
   - `defineSequence(id, spec)` — 帧序列定义
   - `play(handle, sequenceId, opts)` / `stop(handle)` / `isPlaying(handle)`
   - `update(dt)` — **唯一的时间源**
   - `getFrameId(handle)` — 当前帧号（不透明整数）
   - 播放模式：`loop` / `once` / `pingpong`
   - `onComplete` 回调（`once`/`pingpong` 播完触发）
2. **新建 `framework/animation_defs.lua`**（本游戏的帧序列定义，游戏层可覆盖）：
   - 主角行走（4 方向 × 7 帧，替代 `GetMyPic` 的手算）
   - 乘船（4 方向 × 4 帧）
   - 提供 `definePersonWalk(defs)` 等，便于 MOD 覆盖
3. **`game_states.lua` 的 4 处 `AddMyCurrentPic()` 改为 `sprite_anim.update(dt)`**
4. **`jymain.lua` 的 `GetMyPic` 改为查询 `sprite_anim.getFrameId()`**
5. **行速与帧率解耦**：新增设置 `animation.walkFps`（默认 15）
6. **保持现有手感**：默认参数下行走节奏与改动前肉眼一致（见 DoD #3）

## Scope Boundaries

### In Scope

- `framework/sprite_anim.lua`（纯逻辑，零引擎依赖）
- `framework/animation_defs.lua`（游戏帧序列定义）
- `game_states.lua` 的 4 处动画推进点
- `jymain.lua` 的 `GetMyPic` 改造
- `Settings` 的 `animation.walkFps`
- 单元测试（纯算法，不依赖引擎）

### Out of Scope

- **不改** `EngineAPI.sprite` 契约（`draw` 已足够，无需 `drawFrame`）
- **不改**引擎实现（本 slice 引擎侧零改动）
- 资产格式转换（`.grp` → SpriteFrames/Flipbook）→ 独立 epic
- 战斗特效 / instruct_27 动画的**迁移**（只提供 API，不改既有逻辑）
- 站立待机动画（**提供能力**，默认关闭以零回归）
- 骨骼动画 / 补间动画 / 缓动曲线 → 无消费方，不提前做

## Requirements

### REQ-PORT3-1 动画逻辑必须引擎无关

`framework/sprite_anim.lua` 必须：
- 不 require 任何 `engine-*`
- 不调 `love.*`
- 对 `EngineAPI` 的唯一引用是 `EngineAPI.sprite.draw`
- `JY` / `WAR` / `CC` 命中数 = 0（游戏数据由调用方传入）

**验收**：源码断言 + 纯算法单测（无引擎桩也能测 `update(dt)` 的状态机）。

### REQ-PORT3-2 时间驱动是唯一推进源

帧推进只能由 `update(dt)` 发生。不得存在"移动一格加一帧"的旁路。

**验收**：`game_states.lua` 里 `AddMyCurrentPic` 命中数 = 0。

### REQ-PORT3-3 帧号是不透明整数

framework 代码里不得对 `frameId` 做算术。

**验收**：`sprite_anim.lua` 里 `frameId +` / `frameId -` / `frameId *` / `frameId %` = 0。

### REQ-PORT3-4 行走手感零变化（默认参数）

`animation.walkFps=15` 时，行走动画的节奏与改动前肉眼一致。
若实测有差异，调整默认值直到视觉一致，而非要求用户改设置。

**验收**：实机对照 + `animation.walkFps` 可配置、可关闭。

### REQ-PORT3-5 播放模式与结束回调

必须支持 `loop` / `once` / `pingpong`，且 `once`/`pingpong` 播完触发
`onComplete`（只触发一次）。

**验收**：纯算法单测覆盖三种模式 + 回调触发次数。

### REQ-PORT3-6 零回归

**验收**：四版本全量测试，失败 0。行走相关既有测试全部通过。

## Impact

- 受影响文件：见 `tasks.md` 的 Blast Radius
- 破坏性变更：无（`GetMyPic` 签名不变，只是内部改为查序列）
- 现有功能回归风险：**中**（行走动画是玩家每秒都看的东西）
- 缓解：默认参数校准到肉眼一致；`animation.walkFps` 可关；实机对照录制

## 关键设计决策（详见子 change 的 design.md）

| ADR | 决策 |
|-----|------|
| ADR-PORT-013 | 动画逻辑住 framework，**不借任何引擎的动画播放器**（Godot/Unreal 的都绑死资产格式，见上文） |
| ADR-PORT-014 | 引擎侧零改动：只用既有 `sprite.draw(archiveId, frameId, x, y)` |
| ADR-PORT-015 | `frameId` 是**不透明整数**，framework 永不做算术；语义由 `loadArchive` 定义 |
| ADR-PORT-016 | 帧序列定义放 `animation_defs.lua`（游戏层数据），sprite_anim 不含任何具体帧号 |
| ADR-PORT-017 | `update(dt)` 是唯一时间源；`dt` 由既有 `StateMachine:update(dt)` 传入 |
| ADR-PORT-018 | 默认 `walkFps=15` 校准到改动前手感；可配置、可关闭 |
