# Tasks: port-render-batching

> **策略**：契约先落地（Task 1），再补 4 引擎（Task 2），然后写 framework 薄层
> （Task 3）与调用点（Task 4），最后补测试与文档（Task 5/6）。
> Task 1 与 2 都撞 4 个引擎文件，合并成一条工作流；Task 3/4 只碰 framework。
>
> **本 change 的验收基线**：行为**零变化**。4 个引擎全部返回 `false`，
> 所以 `RenderBatch` 走降级路径，绘制序列与改造前逐条相同。

## Task 1：新增 2 个批处理契约（95 → 97）

**Blast Radius**：`game/engine-love2d/engine_api.lua`（**只碰 `M.render` 段
第 125-269 行区域**；不得动 `M.input` 段 610-724、`M.dialog` 段 993-1021）

**DoD**：
- [x] `M.render.beginBatch(kind)` 声明，`@return boolean`
- [x] `M.render.endBatch()` 声明
- [x] 注释写明 **① `false` = 引擎不支持 → 调用方照常逐次 `drawHandle`**
- [x] 注释写明 **② 批次内 `drawHandle` 语义不变**（引擎可攒可立即画，调用方无感知）
- [x] 注释写明 **③ 明确禁止嵌套**（内层 begin 返回 false，外层保持有效）
- [x] 注释含三引擎代价表（LÖVE 隐式批处理 / Godot 命令 / Unreal 独立 draw call）
- [x] 引用 `framework/render_batch.lua` 的 `wrap` 作为「finish 必被调」的实现保证
- [x] 头注释契约计数 90 → **97**（三处：清单第 1 条、`app.install` 文档两处）
- [x] `grep -cE '^function M\.'` = **97**
- [x] 未改 `M.input` / `M.dialog` 段任何一行（`git diff` 只显示 render 段）

## Task 2：4 引擎实现 `beginBatch` / `endBatch`

**Blast Radius**：`engine_love2d.lua` / `engine_mud.lua` / `engine_web.lua` /
`tests/engine_test.lua`

**DoD**：
- [x] **LÖVE**：`beginBatch` 返回 `false` + 注释写清三条取舍（隐式批处理已够 /
      真批处理要改 drawHandle 的 atlas 绑定 / SpriteBatch 生命周期风险）；
      `endBatch` 无害空操作
- [x] **MUD**：返回 `false` + 走 `logCall`（便于测试断言契约被调到）；
      `endBatch` 走 `logCall`
- [x] **Web**：返回 `false`（文本终端无 draw call 可合并）+ `endBatch` 空操作
- [x] **测试桩**：默认 `false`，但提供 `EngineAPI.render._batchSupported` 开关
      （`test_render_batch` 要验两条路径）；**默认必须是 false** ——
      否则 `map_render` 的既有断言会跨过 begin/end 语义
- [x] 4 引擎**显式**实现（不靠 `engine_api.lua` 空桩继承）→ 源码级 conformance 0 缺
- [x] `test_engine_api.lua` 加 2 条存在性断言

## Task 3：新增 `framework/render_batch.lua`

**Blast Radius**：`game/framework/render_batch.lua`（新）

**DoD**：
- [x] `RenderBatch.begin(kind)` → boolean；首次调用**兼任探测**并把结论写缓存
- [x] `RenderBatch.finish()` → 无害空操作（未开批次时直接返回）
- [x] `RenderBatch.wrap(kind, fn)` → `begin → pcall(fn) → finish`，
      **`finish` 无条件执行**，错误原样重抛（`error(result, 0)`）
- [x] `RenderBatch.isSupported()` → 首次探测后缓存
- [x] `RenderBatch.reset()` / `RenderBatch.isActive()`（测试/诊断）
- [x] **禁止嵌套**：`active` 时 `begin` 直接返回 false（不问引擎）
- [x] 引擎 `beginBatch` 抛错 → 记为不支持 + 降级（不崩渲染链）
- [x] `fn` 不是函数 → 返回 nil、不开批次、不抛错
- [x] **零 `love.*` / 零 `require("engine-*")` / 零 `lib.*`**（gate STEP A/B/C）
- [x] 中文注释说明每个决策的「为什么」

## Task 4：`map_render.drawMain` 接入

**Blast Radius**：`game/framework/map_render.lua`

**DoD**：
- [x] `require("framework.render_batch")` 放在模块顶部（**静态** require，
      与 `lib_bit` 同级；不用 draw 时 lazy require —— 它是正常依赖，
      缺失应当立刻炸，而不是被 `pcall` 吞成半坏状态）
- [x] 瓦片两层循环 + 建筑层循环包进 `RenderBatch.wrap("tile", function() ... end)`
- [x] 云层（`map.drawClouds`）**留在包裹之外**
- [x] 循环体**逐字未改**（缩进 + 包一层 function；无任何参数/顺序变化）
- [x] 注释说明「为什么只包这三段」「为什么不手写 begin/finish」
- [x] `drawScene` / `drawBattle` **不改**（本 change 只做实测数据来源的那一个）
- [x] 既有 `test_map_render` 断言全部继续 PASS

## Task 5：新增单测 `test_render_batch.lua`

**Blast Radius**：`game/tests/unit/test_render_batch.lua`（新）、
`game/tests/test_runner.lua`、`game/tests/test_helper.lua`

**DoD**：
- [x] 引擎支持时：`wrap` 内 3 次 `drawHandle` → `begin` 1 次、`end` 1 次、
      3 次 draw 全到、`kind` 透传、结束后 `active` 清零
- [x] 引擎不支持时：`fn` 仍执行、`drawHandle` 3 次全到、**`endBatch` 0 次**、
      返回 `fn` 的返回值、第二次 `wrap` 不再问引擎（缓存）
- [x] `fn` 抛错时 `finish` 仍被调用（`pcall` 验证）+ 错误重抛 + 之后能重新开批次
- [x] 嵌套拒绝：内层 `begin` 返回 false、内层 `fn` 仍执行、引擎只收到 1 对 begin/end
- [x] 引擎 `beginBatch` 抛错 → 降级、`fn` 执行、记为不支持
- [x] 缺契约（`render` 表里没有这两个函数）→ 降级、不抛错
- [x] `fn` 非函数 → 返回 nil、不开批次
- [x] `drawMain` 集成：begin 是第一个事件、end 是最后一个、每帧只 1 个批次、
      `kind == "tile"`
- [x] 在 `test_runner.lua` 注册（`T.render_batch` + `runAll` 调用块 + 可用模块列表）
- [x] `test_helper.lua` 的 mock 引擎补 2 个桩（返回 false）
- [x] 测试自己清理 `_G.EngineAPI` / `CONFIG` / `CC`（避免污染后续模块）

## Task 6：负向对照 + 全量验证

**Blast Radius**：无（只验证，不改生产代码）

**DoD**：
- [x] **负向对照**：把 `wrap` 的 `finish()` 改成「只在 ok 时调用」→
      真跑一遍，**4 条断言 FAIL**（含「即使 fn 抛错也必须调 endBatch」）；
      改回后 45/45 PASS
- [x] 全量测试 lua5.1 / 5.3 / 5.4 / 5.5 全部 **0 失败**（4370 断言）
- [x] `luac5.1/53/54/55 -p` 全仓（除 `mods/`）零语法错误
- [x] `bash game/tests/gate_engine_contract.sh` → `[ ok ] 全部通过`
- [x] `bash game/tests/gate_ascii.sh` → 全通过
- [x] **实机 md5**：`lovec game --shot=batch1 --frame=1400 --keys=...` →
      `1efd2af3a9ecfce48b89ef14b9a14338`（改造前一致）

## Task 7：openspec 产物 + slice manifest

**Blast Radius**：`openspec/changes/port-render-batching/`（新）、
`openspec/changes/archive/2026-11-22-engine-portability/change-manifest.md`

**DoD**：
- [x] `.openspec.yaml`（`schema: spec-driven-enhanced` + `created: 2026-11-22`）
- [x] `proposal.md`（Why 含实测数据 + 三引擎对比 / Parent Context 指向
      engine-portability 第四批 / What Changes / Out of Scope / Impact）
- [x] `design.md`（≥2 ADR：boolean 返回值取舍 / 不做 LÖVE 真批处理取舍；
      另加 ADR-RB-3 禁止嵌套 + Negative Constraints + Review Checklist）
- [x] `specs/render-batching/spec.md`（`## ADDED Requirements` 头 +
      7 个 `### Requirement: REQ-RB-XXX：...` + 每个都有 `#### Scenario:`）
- [x] `tasks.md`（本文件：Blast Radius + DoD，全部完成勾选）
- [x] `change-manifest.md` header「16 个」→「**17 个**」
      （第一批 10 + 第二批 4 + 第三批 2 + 第四批 1）
- [x] `change-manifest.md` 新增「## 第四批：绘制批处理契约（2026-11-22）」
      小节（change 说明 + 依赖图）
- [x] **未改** `slice-proposal.md`（并行 subagent 可能在改它）

## 依赖

- 无硬依赖（不改游戏逻辑）
- 承接：`port-map-render-native`（2900 次调用的来源）+ `port-engine-boot`
  （`beginFrame/endFrame` 边界，批次必须落在其内部）
- 被承接：未来的「LÖVE/Godot/Unreal 真批处理」change（本 change 只留口子）
