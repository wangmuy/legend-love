# Change Proposal: port-script-decoupling — framework 与 script 解耦

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）

## Why

framework 目前**反向依赖** `game/script/`：它调用了 8 个定义在
`game/script/jymain.lua:2094-2994` 的全局函数，共 **140 处**。

```
DrawString    28 处    ShowScreen   11 处    ShowMenu     8 处
Cls           28 处    DrawBox       8 处    WaitKey     11 处
DrawStrBox    10 处    TalkEx        3 处    GetMyPic    13 处
DrawStrBoxYesNo 1 处   ShowMenu2     3 处    SceneCanPass 2 处
DrawStrBoxWaitKey 1 处 PlayMIDI      6 处    AddMyCurrentPic 4 处
PlayMPEG      1 处    FillColor     1 处    DrawRect    1 处
```

依赖方向是 **framework → script → EngineAPI**，而设计意图是
**framework → EngineAPI**。

**后果**：接新引擎时不仅要实现 EngineAPI，还要把 `jymain.lua` 这 2000 行
一起搬过去 —— 那就等于移植整个游戏，不是移植引擎。

## In Scope

1. 新建 `framework/render_facade.lua`（绘制类转发，只调 `EngineAPI.render`）
2. 新建 `framework/flow_facade.lua`（流程类转发，只调既有 framework 模块）
3. 新建 `framework/game_hooks.lua`（游戏逻辑注入点）
4. framework 里 140 处 script 全局调用改写
5. `game/script/jymain.lua` 的 8 个全局函数改为 facade 薄包装
6. 游戏逻辑回调注入接线
7. 全部既有测试零回归 + 实机冒烟

## Out of Scope

- EngineAPI 契约补齐 → `port-contract-completeness`（前置）
- sprite 动画 → `port-sprite-animation`
- 删除 script 层的全局函数（游戏脚本仍要用，1000+ 调用点）
- 绘制性能优化（facade 是纯转发，无逻辑）

## 关键度量

| 指标 | 基线 | 目标 |
|------|------|------|
| framework 里 script 全局调用 | 140 处 | **0** |
| framework 里 `lib.*` 绕过 | 0（由前置 change 达成） | 保持 0 |
| 既有测试断言数 | 3310+（前置 change 后更高） | 只增不减，失败 0 |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-PORT2-1 | framework 不得调用 script 定义的全局 | specs/script-decoupling/spec.md |
| REQ-PORT2-2 | facade 只转发，不含逻辑 | specs/script-decoupling/spec.md |
| REQ-PORT2-3 | script 层行为零变化 | specs/script-decoupling/spec.md |
| REQ-PORT2-4 | 游戏逻辑回调走注入而非硬依赖 | specs/script-decoupling/spec.md |
| REQ-PORT2-5 | 零回归 | specs/script-decoupling/spec.md |

## 风险

| 风险 | 缓解 |
|------|------|
| 140 处**语义性**改动（不是机械替换） | 按模块分为 4 批：绘制类 / 流程类 / 钩子类 / 音频类；每批全量测试 + 实机冒烟 |
| `DrawStrBox` 等函数内含排版逻辑 | facade 保留 `TextBoxLayout` 算法，只改"谁调谁" |
| 中途引入循环 require | facade 只依赖 `EngineAPI` 与既有 framework 模块，不 require script |
| 实机回归难发现（测试覆盖不到的绘制） | 每批改动后跑一次菜单/对话/地图/战斗冒烟 |
