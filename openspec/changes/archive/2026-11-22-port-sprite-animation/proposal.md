# Change Proposal: port-sprite-animation — sprite 动画时间驱动

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）

## Why

当前「动画」的全部实现是**一个整数自增**，且由"走一格加一帧"驱动：

```lua
-- game/script/jymain.lua:624
function GetMyPic()
    if JY.MyCurrentPic > 6 then JY.MyCurrentPic = 1 end
    n = CC.MyStartPic + JY.Base["人方向"]*7 + JY.MyCurrentPic
    return n
end

-- game/script/jymain.lua:645
function AddMyCurrentPic() JY.MyCurrentPic = JY.MyCurrentPic + 1 end
```

调用点（`game/framework/game_states.lua` 4 处）：每移动一格调一次。

后果：

| 问题 | 表现 |
|------|------|
| 帧率与移速绑死 | 改移速动画就变速 |
| 不移动时完全静止 | 连待机摆动都没有 |
| 无播放模式 | 没有 loop / once / pingpong / 结束回调 |
| 新动画加不了 | 战斗特效、场景动画各自硬编码 |

`dt` 已经在 `love.update(dt)` → `EventBridge:update(dt)` → `StateMachine:update(dt)`
这条链上传到位，但**零处代码用它推进动画**。

## 核心设计（为什么动画必须住 framework）

实测三大外部引擎的动画 API 形态：

| 引擎 | 动画能力 | 绑定到什么 |
|------|---------|-----------|
| LÖVE 11.5 | `love.graphics.draw(quad)` | 纹理区域（**无资产格式**） |
| Godot 4 | `AnimatedSprite2D` + `SpriteFrames` | **`.tres` 资产** |
| Unreal 5 | `PaperFlipbookComponent` | **`.uasset` 资产** |
| SDL2 | `SDL_RenderCopy(srcRect)` | 无动画概念 |

**Godot 与 Unreal 的动画播放器都绑死各自资产管线。**
唯一公共子集是「给定 archiveId + 一个不透明整数帧号，画在 (x, y)」：

```
LÖVE   : quad = archive[frameId]; love.graphics.draw(quad, x, y)
Godot  : sprite2d.frame = frameId
Unreal : paperSprite.SetSpriteIndex(frameId)
SDL    : blit(texture, &archive[frameId], x, y)
```

所以正确形态：

```
framework/sprite_anim.lua        纯逻辑：帧序列 + update(dt) + 状态机
        │
        │  只调这一个既有契约（引擎侧零改动）
        ▼
EngineAPI.sprite.draw(archiveId, frameId, x, y, flags, alpha)
```

**两条硬约束**：

1. 动画播放器**绝不能**由引擎提供（否则陷入 Godot/Unreal/SDL 三方分裂）
2. `frameId` 是**永不解释的不透明整数**，framework 里不得出现
   `frameId + 1` / `* 2` / `% 7` 这类算术

## In Scope

1. 新建 `framework/sprite_anim.lua`（纯逻辑，零引擎依赖）
2. 新建 `framework/animation_defs.lua`（本游戏帧序列定义）
3. `game_states.lua` 的 4 处动画推进点改为 `sprite_anim.update(dt)`
4. `jymain.lua` 的 `GetMyPic` 改为查询序列（签名不变）
5. `Settings` 新增 `animation.walkFps`（默认 15）
6. 单元测试 `test_sprite_anim.lua`（纯算法）

## Out of Scope

- **不改** `EngineAPI.sprite` 契约（`draw` 已足够）
- **不改**引擎实现（引擎侧零改动）
- 资产格式转换（`.grp` → SpriteFrames/Flipbook）→ 独立 epic
- 战斗特效 / instruct_27 动画的**迁移**（只提供 API）
- 站立待机动画（提供能力，默认关闭以零回归）
- 骨骼动画 / 补间动画 / 缓动曲线 → 无消费方，不提前做

## 关键度量

| 指标 | 基线 | 目标 |
|------|------|------|
| `AddMyCurrentPic` 在 framework 的调用 | 4 处 | **0** |
| 帧推进的时间源 | 无 | **`update(dt)` 唯一** |
| `sprite_anim.lua` 的引擎依赖 | — | **0**（只调 sprite.draw） |
| `frameId` 算术出现次数 | — | **0** |
| 行走手感（默认 walkFps=15） | — | 与改动前肉眼一致 |
| 全量断言数 | — | 只增不减，失败 0 |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-PORT3-1 | 动画逻辑必须引擎无关 | specs/sprite-animation/spec.md |
| REQ-PORT3-2 | 时间驱动是唯一推进源 | specs/sprite-animation/spec.md |
| REQ-PORT3-3 | 帧号是不透明整数 | specs/sprite-animation/spec.md |
| REQ-PORT3-4 | 行走手感零变化 | specs/sprite-animation/spec.md |
| REQ-PORT3-5 | 播放模式与结束回调 | specs/sprite-animation/spec.md |
| REQ-PORT3-6 | 零回归 | specs/sprite-animation/spec.md |

## 风险

| 风险 | 缓解 |
|------|------|
| 行走动画是玩家每秒都看的东西 | 默认 walkFps 校准到肉眼一致；`animation.walkFps` 可关 |
| 与 `port-script-decoupling` 同改 `game_states.lua` | 本 change 排在后者之后执行 |
| 帧序列定义写死在 framework | 放 `animation_defs.lua` 独立文件，游戏层可覆盖 |
