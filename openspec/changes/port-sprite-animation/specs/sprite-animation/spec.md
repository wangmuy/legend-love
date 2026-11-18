# Sprite Animation

## ADDED Requirements

### Requirement: REQ-PORT3-1 动画逻辑必须引擎无关

`framework/sprite_anim.lua` SHALL：
- SHALL NOT require 任何 `engine-*` 模块
- SHALL NOT 调用 `love.*`
- 对 `EngineAPI` 的唯一引用 SHALL 是 `EngineAPI.sprite.draw`
- `JY` / `WAR` / `CC` 命中数 SHALL 为 0（游戏数据由调用方传入）

#### Scenario: 纯算法可单测

- **GIVEN** 测试环境无引擎（`EngineAPI` 为 nil 或残缺）
- **WHEN** 调 `sprite_anim.defineSequence(...)` / `update(dt)` / `getFrameId(...)`
- **THEN** 状态机正常推进，SHALL NOT 抛错

#### Scenario: 只在绘制时触碰引擎

- **GIVEN** 一个已播放的动画
- **WHEN** 调 `sprite_anim.draw(handle, x, y)`
- **THEN** 唯一被调用的 EngineAPI 函数是 `sprite.draw`

### Requirement: REQ-PORT3-2 时间驱动是唯一推进源

帧推进 SHALL 只由 `update(dt)` 发生。
SHALL NOT 存在"移动一格加一帧"的旁路。

#### Scenario: framework 里零 AddMyCurrentPic

- **GIVEN** 本 change 完成
- **WHEN** 执行 `grep -rhoE '\bAddMyCurrentPic\(' game/framework/*.lua`
- **THEN** 命中数 = 0

#### Scenario: 静止时动画仍按时间推进

- **GIVEN** 一个 `loop` 模式的行走动画，玩家静止不动
- **WHEN** 连续调 `update(dt)` 若干次
- **THEN** `getFrameId` 按 fps 推进（不因玩家静止而冻结）

### Requirement: REQ-PORT3-3 帧号是不透明整数

framework 代码 SHALL NOT 对 `frameId` 做算术。

#### Scenario: sprite_anim 里无帧号算术

- **GIVEN** `framework/sprite_anim.lua`
- **WHEN** 执行 `grep -c 'frameId [+-]' framework/sprite_anim.lua`
- **THEN** 命中数 = 0

#### Scenario: 帧号原样透传给引擎

- **GIVEN** 序列定义 `frames = {10, 11, 12}`（绝对编号）
- **WHEN** 播放到第 2 帧并调 `draw`
- **THEN** `EngineAPI.sprite.draw` 收到的 `frameId` 是 `11`（原样透传）

### Requirement: REQ-PORT3-4 行走手感零变化（默认参数）

`animation.walkFps = 15` 时，行走动画的节奏 SHALL 与改动前肉眼一致。
若实测有差异，SHALL 调整默认值直到视觉一致，SHALL NOT 要求用户改设置。

#### Scenario: 默认帧率可配置且可关闭

- **GIVEN** 本 change 完成
- **WHEN** 读设置 `animation.walkFps`
- **THEN** 存在且默认 15；设为 0 时动画冻结在当前帧

#### Scenario: 实机手感对照

- **GIVEN** 改动前录制的行走片段
- **WHEN** 用改动后版本录制同样操作
- **THEN** 帧切换节奏肉眼一致

### Requirement: REQ-PORT3-5 播放模式与结束回调

SHALL 支持 `loop` / `once` / `pingpong` 三种模式；
`once` 与 `pingpong` 播完 SHALL 触发 `onComplete` 回调（只触发一次）。

#### Scenario: once 模式播完即停并回调

- **GIVEN** 一个 3 帧 `once` 序列，fps=10
- **WHEN** 调 `update(dt)` 累计到 0.3 秒以上
- **THEN** `isPlaying` 返回 false，`onComplete` 被调用 1 次

#### Scenario: loop 模式无限循环且不回调

- **GIVEN** 一个 3 帧 `loop` 序列
- **WHEN** 推进 10 个周期
- **THEN** 帧号循环回绕，`onComplete` 从未被调用

#### Scenario: pingpong 模式往复

- **GIVEN** 一个 3 帧 `pingpong` 序列
- **WHEN** 推进两个周期
- **THEN** 帧序为 1→2→3→2→1→2…，`onComplete` 每个往返触发 1 次

### Requirement: REQ-PORT3-6 零回归

本 change SHALL NOT 引入任何既有功能的回归，SHALL NOT 改变玩家可见的
行走手感（默认参数下）。

#### Scenario: 四版本全量测试零失败

- **WHEN** 在 Lua 5.1 / 5.3 / 5.4 / 5.5 上跑全量测试
- **THEN** 失败数 = 0

#### Scenario: 行走相关既有测试通过

- **GIVEN** 既有测试里与行走/贴图相关的断言
- **WHEN** 全量测试
- **THEN** 全部通过
