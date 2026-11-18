---
status: active
parent_epic: 2026-11-engine-portability
---
# Change Manifest: port-slice3-sprite-animation — 精灵动画

> 本 slice 只有一个子 change，位于 `openspec/changes/port-sprite-animation/`
> （与 slice 目录同级，符合既有 `mouse-slice3` 的组织方式）。

## Change Assignments

### Change: port-sprite-animation

- **Repository**: this repo
- **Scope**: fullstack（framework 新模块 + game_states 接线 + 测试）
  **引擎实现零改动**
- **Responsibility**:
  1. 新建 `framework/sprite_anim.lua`：纯逻辑动画播放器
     - `defineSequence(id, spec)`：`{archive=, frames={}, fps=, loop=|mode=}`
     - `play(handle, sequenceId, opts)` / `stop(handle)` / `isPlaying(handle)`
     - `update(dt)`：唯一时间源，推进所有活跃动画
     - `getFrameId(handle)`：返回不透明整数帧号
     - 模式 `loop` / `once` / `pingpong` + `onComplete` 回调
  2. 新建 `framework/animation_defs.lua`：本游戏的帧序列定义
     - 主角行走（4 方向 × 7 帧，替代 `GetMyPic` 手算）
     - 乘船（4 方向 × 4 帧）
     - 其他动画的扩展点（战斗特效等，只留 API 不迁移）
  3. `game/framework/game_states.lua` 的 4 处 `AddMyCurrentPic()` 改为
     `sprite_anim.update(dt)`（`dt` 由既有 `StateMachine:update(dt)` 传入）
  4. `game/script/jymain.lua` 的 `GetMyPic` 改为查询 `sprite_anim.getFrameId()`
     （签名不变，script 层 100+ 处调用零改动）
  5. `Settings` 新增 `animation.walkFps`（默认 15，可调，可关闭）
  6. 单元测试 `test_sprite_anim.lua`（纯算法，无引擎桩）
- **Depends On**: —
- **Status**: [ ] Pending

---

## 依赖图

```
（无前置依赖）
  │
  │ 只消费既有契约（slice 1 已确认它可用）：
  │   EngineAPI.sprite.draw(archiveId, frameId, x, y, flags, alpha)
  │
  ▼
port-slice3-sprite-animation（本 slice）
```

**引擎侧零改动** —— 本 slice 不新增任何 EngineAPI 函数。

## 与 slice 2 的冲突风险

slice 2 与 slice 3 都要改 `game/framework/game_states.lua`：

```
slice 2: 绘制类调用改写（game_states.lua 里 16 处 Cls/DrawString/ShowScreen/lib.DrawMMap）
slice 3: 动画推进点改写（game_states.lua 里 4 处 AddMyCurrentPic）
```

两者改的是不同行，但同文件 → 建议 **slice 2 先做**，slice 3 基于其成果 rebase。

## Slice 级验收

见 `slice-proposal.md` 的 Requirements（REQ-PORT3-1 ~ REQ-PORT3-6），
以及 `port-sprite-animation/tasks.md` 的 DoD。
