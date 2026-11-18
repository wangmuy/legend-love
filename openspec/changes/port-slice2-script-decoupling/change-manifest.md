---
status: active
parent_epic: 2026-11-engine-portability
---
# Change Manifest: port-slice2-script-decoupling — script 解耦

> 本 slice 只有一个子 change，位于 `openspec/changes/port-script-decoupling/`
> （与 slice 目录同级，符合既有 `mouse-slice2` 的组织方式）。

## Change Assignments

### Change: port-script-decoupling

- **Repository**: this repo
- **Scope**: fullstack（framework 新模块 + 140 处调用改写 + script 薄包装 + 测试）
- **Responsibility**:
  1. 新建 `framework/render_facade.lua`（绘制类转发，只调 `EngineAPI.render`）
  2. 新建 `framework/flow_facade.lua`（流程类转发，只调既有 framework 模块）
  3. 新建 `framework/game_hooks.lua`（游戏逻辑注入点，替代 framework 硬依赖 script）
  4. framework 里 140 处全局调用改写：
     - 绘制类（DrawString 28 / Cls 28 / ShowScreen 11 / DrawBox 8 / DrawStrBox 10
       / DrawStrBoxYesNo 1 / DrawStrBoxWaitKey 1）→ `render_facade`
     - 流程类（ShowMenu 8 / ShowMenu2 3 / WaitKey 11 / TalkEx 3）→ `flow_facade`
     - 游戏逻辑（GetMyPic 13 / AddMyCurrentPic 4 / SceneCanPass 2）→ `game_hooks`
     - 音频类（PlayMIDI 6 / PlayMPEG 1 / FillColor 1 / DrawRect 1）→ 契约或 facade
  5. `game/script/jymain.lua` 的 8 个全局函数改为 facade 薄包装
  6. 游戏逻辑回调注入接线（`jymain_adapter` 启动时注册）
  7. 全部既有测试零回归 + 实机冒烟
- **Depends On**: port-contract-completeness（slice 1）
- **Status**: [ ] Pending

---

## 依赖图

```
  port-slice1-contract-completeness
        │  （需要 render.getWidth/getHeight/setClip/measureText 等完整契约）
        ▼
  port-slice2-script-decoupling（本 slice）
```

## 与 slice 1 / slice 3 的接口关系

本 slice **不新增** EngineAPI 契约，只消费 slice 1 的成果。

本 slice 与 slice 3 **互不依赖**：
- slice 3 的 `sprite_anim.lua` 调 `EngineAPI.sprite.draw`（slice 1 已确认）
- 但若 slice 3 先完成，它的 `game_states.lua` 改动会与本 slice 冲突
  → **建议本 slice 先做**，避免 merge 冲突

## Slice 级验收

见 `slice-proposal.md` 的 Requirements（REQ-PORT2-1 ~ REQ-PORT2-5），
以及 `port-script-decoupling/tasks.md` 的 DoD。
