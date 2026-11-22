# Tasks: port-sprite-animation

> 父 slice: `engine-portability`
> 注意：本 change 与 `port-script-decoupling` 都要改 `game_states.lua`，
> **建议排在后者之后执行**。

## Task 1：`sprite_anim.lua` 核心状态机

**Blast Radius**：`game/framework/sprite_anim.lua`（新）

**DoD**：
- [x] `defineSequence(id, spec)`：
      `spec = { archive=, frames={frameId...}, fps=, mode="loop"|"once"|"pingpong" }`
- [x] `play(handle, sequenceId, opts)` / `stop(handle)` / `isPlaying(handle)`
- [x] `update(dt)`：推进所有活跃动画（**唯一时间源**）
- [x] `getFrameId(handle)`：返回当前帧号（原样来自 `frames` 表，不做算术）
- [x] `draw(handle, x, y, opts)`：内部只调 `EngineAPI.sprite.draw`
- [x] 模式 `loop` / `once` / `pingpong` + `onComplete` 回调（只触发一次）
- [x] `frameId` 算术命中数 = 0（`frameId +` / `-` / `*` / `%`）
- [x] `JY` / `WAR` / `CC` 命中数 = 0
- [x] `luac5.1 -p` / `luac55 -p` 通过

---

## Task 2：`animation_defs.lua` 帧序列定义

**Blast Radius**：`game/framework/animation_defs.lua`（新）

**DoD**：
- [x] 主角行走：4 方向 × 7 帧，帧号由 `CC.MyStartPic + 方向*7 + n` 生成
      （保留现有编号约定，**不改帧号编码**）
- [x] 乘船：4 方向 × 4 帧（`CC.BoatStartPic + 方向*4 + n`）
- [x] `definePersonWalk(basePic)` 等扩展点，便于 MOD 覆盖
- [x] 文件内 `EngineAPI` 命中数 = 0（纯数据定义）

---

## Task 3：`game_states.lua` 接线

**Blast Radius**：`game/framework/game_states.lua`（4 处）

**DoD**：
- [x] 4 处 `AddMyCurrentPic()` → `SpriteAnim.update(dt)`（`dt` 已在链上）
- [x] 行走开始时 `SpriteAnim.play(walkHandle, "person.walk")`
- [x] 行走结束时 `SpriteAnim.stop(walkHandle)`（或让 once 模式自然结束）
- [x] framework 里 `AddMyCurrentPic(` 命中数 = 0
- [x] `dt` 真的被用于推进（不是空参）
- [x] 全量测试零失败

---

## Task 4：`GetMyPic` 改造

**Blast Radius**：`game/script/jymain.lua`（1 个函数体）

**DoD**：
- [x] `GetMyPic()` 签名不变，内部改为 `SpriteAnim.getFrameId(walkHandle)`
- [x] 乘船分支同样走序列（`boat.walk`）
- [x] script 层 100+ 处 `GetMyPic()` 调用零改动
- [x] 全量测试零失败
- [x] **实机冒烟**：四方向行走、乘船行走、站立静止

---

## Task 5：设置项 `animation.walkFps`

**Blast Radius**：`game/framework/settings` 相关、`game/framework/audio_menu.lua`（或设置菜单）

**DoD**：
- [x] `Settings.define("animation.walkFps", { default = 15, type = "number" })`
- [x] 设为 0 时动画冻结在当前帧
- [x] 设为 15 时行走节奏与改动前**肉眼一致**（实机对照）
- [x] 进入设置菜单可调（可选，若菜单项太挤则只在配置文件可改）

---

## Task 6：单元测试

**Blast Radius**：`game/tests/unit/test_sprite_anim.lua`（新）、
`game/tests/test_runner.lua`

**DoD**：
- [x] 纯算法测试（无引擎桩）：
      - `defineSequence` 参数校验
      - `loop` 模式帧序循环
      - `once` 模式播完停 + `onComplete` 触发 1 次
      - `pingpong` 模式往复 + 每往返回调 1 次
      - `update(dt)` 累计时间到帧切换
      - `getFrameId` 原样返回序列里的帧号（不做算术）
      - 未 `play` 时 `getFrameId` 返回 nil
      - 多 handle 独立推进（互不干扰）
- [x] 引擎依赖断言：文件里 `love\.` = 0、`require("engine` = 0
- [x] 注册到 `test_runner.lua`
- [x] 全量测试零失败

---

## Task 7：全量验证

**DoD**：
- [x] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（记录断言数）
- [x] `luac5.1 -p` / `luac55 -p` 全仓零失败
- [x] LÖVE 11.5 启动冒烟无报错
- [x] 门禁 `gate_engine_contract.sh` 全 PASS（含新增的动画断言）
- [x] 既有门禁全 PASS
- [x] **实机手感对照**：改动前后录制行走片段，帧切换节奏肉眼一致
