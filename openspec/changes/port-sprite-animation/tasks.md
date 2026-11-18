# Tasks: port-sprite-animation

> 父 slice: `engine-portability`
> 注意：本 change 与 `port-script-decoupling` 都要改 `game_states.lua`，
> **建议排在后者之后执行**。

## Task 1：`sprite_anim.lua` 核心状态机

**Blast Radius**：`game/framework/sprite_anim.lua`（新）

**DoD**：
- [ ] `defineSequence(id, spec)`：
      `spec = { archive=, frames={frameId...}, fps=, mode="loop"|"once"|"pingpong" }`
- [ ] `play(handle, sequenceId, opts)` / `stop(handle)` / `isPlaying(handle)`
- [ ] `update(dt)`：推进所有活跃动画（**唯一时间源**）
- [ ] `getFrameId(handle)`：返回当前帧号（原样来自 `frames` 表，不做算术）
- [ ] `draw(handle, x, y, opts)`：内部只调 `EngineAPI.sprite.draw`
- [ ] 模式 `loop` / `once` / `pingpong` + `onComplete` 回调（只触发一次）
- [ ] `frameId` 算术命中数 = 0（`frameId +` / `-` / `*` / `%`）
- [ ] `JY` / `WAR` / `CC` 命中数 = 0
- [ ] `luac5.1 -p` / `luac55 -p` 通过

---

## Task 2：`animation_defs.lua` 帧序列定义

**Blast Radius**：`game/framework/animation_defs.lua`（新）

**DoD**：
- [ ] 主角行走：4 方向 × 7 帧，帧号由 `CC.MyStartPic + 方向*7 + n` 生成
      （保留现有编号约定，**不改帧号编码**）
- [ ] 乘船：4 方向 × 4 帧（`CC.BoatStartPic + 方向*4 + n`）
- [ ] `definePersonWalk(basePic)` 等扩展点，便于 MOD 覆盖
- [ ] 文件内 `EngineAPI` 命中数 = 0（纯数据定义）

---

## Task 3：`game_states.lua` 接线

**Blast Radius**：`game/framework/game_states.lua`（4 处）

**DoD**：
- [ ] 4 处 `AddMyCurrentPic()` → `SpriteAnim.update(dt)`（`dt` 已在链上）
- [ ] 行走开始时 `SpriteAnim.play(walkHandle, "person.walk")`
- [ ] 行走结束时 `SpriteAnim.stop(walkHandle)`（或让 once 模式自然结束）
- [ ] framework 里 `AddMyCurrentPic(` 命中数 = 0
- [ ] `dt` 真的被用于推进（不是空参）
- [ ] 全量测试零失败

---

## Task 4：`GetMyPic` 改造

**Blast Radius**：`game/script/jymain.lua`（1 个函数体）

**DoD**：
- [ ] `GetMyPic()` 签名不变，内部改为 `SpriteAnim.getFrameId(walkHandle)`
- [ ] 乘船分支同样走序列（`boat.walk`）
- [ ] script 层 100+ 处 `GetMyPic()` 调用零改动
- [ ] 全量测试零失败
- [ ] **实机冒烟**：四方向行走、乘船行走、站立静止

---

## Task 5：设置项 `animation.walkFps`

**Blast Radius**：`game/framework/settings` 相关、`game/framework/audio_menu.lua`（或设置菜单）

**DoD**：
- [ ] `Settings.define("animation.walkFps", { default = 15, type = "number" })`
- [ ] 设为 0 时动画冻结在当前帧
- [ ] 设为 15 时行走节奏与改动前**肉眼一致**（实机对照）
- [ ] 进入设置菜单可调（可选，若菜单项太挤则只在配置文件可改）

---

## Task 6：单元测试

**Blast Radius**：`game/tests/unit/test_sprite_anim.lua`（新）、
`game/tests/test_runner.lua`

**DoD**：
- [ ] 纯算法测试（无引擎桩）：
      - `defineSequence` 参数校验
      - `loop` 模式帧序循环
      - `once` 模式播完停 + `onComplete` 触发 1 次
      - `pingpong` 模式往复 + 每往返回调 1 次
      - `update(dt)` 累计时间到帧切换
      - `getFrameId` 原样返回序列里的帧号（不做算术）
      - 未 `play` 时 `getFrameId` 返回 nil
      - 多 handle 独立推进（互不干扰）
- [ ] 引擎依赖断言：文件里 `love\.` = 0、`require("engine` = 0
- [ ] 注册到 `test_runner.lua`
- [ ] 全量测试零失败

---

## Task 7：全量验证

**DoD**：
- [ ] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（记录断言数）
- [ ] `luac5.1 -p` / `luac55 -p` 全仓零失败
- [ ] LÖVE 11.5 启动冒烟无报错
- [ ] 门禁 `gate_engine_contract.sh` 全 PASS（含新增的动画断言）
- [ ] 既有门禁全 PASS
- [ ] **实机手感对照**：改动前后录制行走片段，帧切换节奏肉眼一致
