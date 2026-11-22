# render-batching Delta

## ADDED Requirements

### Requirement: REQ-RB-001：批处理契约必须返回 boolean 能力声明

`EngineAPI.render` SHALL 提供成对的两个契约：

- `beginBatch(kind)` → `boolean`（是否**真的**进入了批处理模式）
- `endBatch()`

`beginBatch` SHALL NOT 假设引擎支持批处理；它 SHALL 把「引擎能力」作为
**运行时可查询的值**返回给调用方。

四个引擎实现（LÖVE / MUD / Web / 测试桩）SHALL 都**显式**实现这两个函数
（SHALL NOT 依赖 `engine_api.lua` 的空桩继承 —— 空桩返回 nil，会让
「真假不明」通过 `if entered then` 的判断）。

#### Scenario: 引擎不支持批处理

- **GIVEN** 引擎的 `beginBatch` 实现返回 `false`
- **WHEN** 调用方执行 `RenderBatch.wrap("tile", fn)`
- **THEN** `fn` SHALL 仍然被执行（降级，不是跳过）
- **AND** 引擎 SHALL NOT 收到 `endBatch` 调用（没开过批次，不该去关）
- **AND** 批次内每一次 `drawHandle` 的参数与顺序 SHALL 与不带批处理时**逐条相同**
- **AND** 渲染输出 SHALL 逐字节一致（实机截图 md5 `1efd2af3a9ecfce48b89ef14b9a14338`）

#### Scenario: 引擎支持批处理

- **GIVEN** 引擎的 `beginBatch` 实现返回 `true`
- **WHEN** 调用方在 `wrap` 内执行 3 次 `drawHandle`
- **THEN** 引擎 SHALL 收到 **1 次** `beginBatch` 与 **1 次** `endBatch`
  （SHALL NOT 是「每次绘制一次」）
- **AND** 3 次 `drawHandle` SHALL **全部**照常到达引擎（语义不变）
- **AND** `kind` 参数 SHALL 透传给引擎（便于其选策略）

#### Scenario: 引擎完全没有批处理契约（老引擎）

- **GIVEN** `EngineAPI.render` 里没有 `beginBatch` / `endBatch` 字段
- **WHEN** 走 `RenderBatch.wrap`
- **THEN** SHALL NOT 抛错
- **AND** `fn` SHALL 被执行
- **AND** `RenderBatch.isSupported()` SHALL 返回 `false`

### Requirement: REQ-RB-002：`RenderBatch.wrap` 必须保证 `finish` 无条件执行

`framework/render_batch.lua` 的 `wrap(kind, fn)` SHALL 以
`begin → pcall(fn) → finish` 执行，且 `finish` SHALL 在 `fn` **抛错时也执行**
（批次状态属于引擎，跨帧泄漏会让下一帧的绘制落进上一帧的批次）。

`fn` 抛出的错误 SHALL **原样重抛**（SHALL NOT 吞掉 —— 吞掉会让「黑屏但无报错」
更难查）。

#### Scenario: `fn` 抛错

- **GIVEN** 引擎支持批处理
- **WHEN** `wrap` 内的 `fn` 抛错
- **THEN** `endBatch` SHALL 仍然被调用**恰好 1 次**
- **AND** 错误 SHALL 被重抛（`pcall(wrap, ...)` 返回 `false` 且信息含原错误）
- **AND** 之后再次 `wrap` SHALL 能正常开新批次（状态已恢复）

#### Scenario: 负向对照 —— 去掉无条件保证

- **GIVEN** 把 `finish()` 改成「只在 `ok` 时调用」
- **WHEN** 运行 `test_render_batch`
- **THEN** 至少 4 条断言 SHALL FAIL，包括
  「即使 fn 抛错也必须调 endBatch」与「抛错后 active 必须已清」

### Requirement: REQ-RB-003：批次禁止嵌套

`beginBatch` 在已处于批次内时 SHALL 返回 `false`，SHALL NOT 抛错，
SHALL NOT 改变当前批次状态。`endBatch` SHALL 在「没开过批次」时是
**无害空操作**（不抛错、不改状态）。

#### Scenario: 嵌套 wrap

- **GIVEN** 外层 `wrap("tile", ...)` 已进入批次
- **WHEN** 内层调用 `wrap("text", ...)` 或 `begin("text")`
- **THEN** 内层的 begin SHALL 返回 `false`
- **AND** 内层 `fn` SHALL 仍被执行（只是不进批次）
- **AND** 引擎 SHALL 只收到 **1 次** `beginBatch` 与 **1 次** `endBatch`
- **AND** 内层结束后外层批次 SHALL 仍然有效

#### Scenario: 未开批次就 end

- **GIVEN** 从未调用 `begin`（或 begin 返回了 false）
- **WHEN** 调用 `finish()`
- **THEN** SHALL NOT 抛错
- **AND** 引擎 SHALL NOT 收到 `endBatch`

### Requirement: REQ-RB-004：能力探测结论必须缓存

`RenderBatch.isSupported()` / `begin()` SHALL 缓存探测结论，
使**明确不支持**的引擎每帧只被询问一次。

理由：`drawMain` 每帧都会调用 `wrap`。若每帧都去问一个明确不支持的引擎，
在约 2900 次绘制之外还要多付几千次无意义的契约调用。

#### Scenario: 不支持的引擎被问一次

- **GIVEN** 引擎 `beginBatch` 返回 `false`
- **WHEN** 连续执行 2 次 `wrap`（或 6 次 `isSupported`）
- **THEN** 引擎的 `beginBatch` SHALL 只被调用 **1 次**

#### Scenario: 测试切换引擎能力

- **GIVEN** 测试改了桩的 `_batchSupported` 开关
- **WHEN** 未调用 `RenderBatch.reset()`
- **THEN** 断言会看到**旧缓存**（这是刻意的：缓存失效是调用方的责任）
- **AND** 调用 `reset()` 后结论 SHALL 重新探测

### Requirement: REQ-RB-005：`drawMain` 必须只包裹瓦片与建筑层

`framework/map_render.lua` 的 `drawMain` SHALL 用
`RenderBatch.wrap("tile", ...)` 包住「瓦片两层循环 + 建筑层循环」。
`kind` SHALL 为 `"tile"`。

云层（`EngineAPI.map.drawClouds`）SHALL NOT 被包裹 —— 它是引擎侧独立子系统
（自己管烘焙与漂移），包进来会把批次边界交给另一个模块决定。

#### Scenario: drawMain 的批次边界

- **GIVEN** 引擎支持批处理
- **WHEN** 调用一次 `drawMain`
- **THEN** `beginBatch("tile")` SHALL 是该帧**第一个**绘制相关事件
- **AND** `endBatch` SHALL 是**最后一个**绘制相关事件
- **AND** 所有 `drawHandle` SHALL 落在两者之间
- **AND** 每帧 SHALL 只有 **1 个**批次（不是每格一个）

#### Scenario: 引擎不支持时的绘制序列

- **GIVEN** 引擎不支持批处理
- **WHEN** 调用 `drawMain`
- **THEN** `beginBatch` / `endBatch` SHALL NOT 出现在引擎调用日志里
- **AND** 既有 `test_map_render` 的全部断言 SHALL 继续 PASS

### Requirement: REQ-RB-006：batch 契约必须落在 `render` 段且不越界改其它段

两个新契约 SHALL 声明在 `engine_api.lua` 的 `M.render` 段（`render.endFrame`
之后、`sprite` 段之前），SHALL NOT 修改 `M.input` 段或 `M.dialog` 段的任何内容
（有并行工作改那两段）。

#### Scenario: 段边界

- **GIVEN** `engine_api.lua` 的 `M.render` 段
- **WHEN** 检查新增契约的位置
- **THEN** `beginBatch` / `endBatch` SHALL 位于 `render.endFrame` 与 `M.sprite = {}` 之间
- **AND** `M.input` 段与 `M.dialog` 段的 diff SHALL 为空

### Requirement: REQ-RB-007：契约数计数必须同步

新增 2 个契约后，`engine_api.lua` 头注释里的契约数 SHALL 从 95 更新为 97
（`grep -cE '^function M\.'` 应返回 97），且 SHALL NOT 出现其它过期计数。

#### Scenario: 计数一致

- **GIVEN** `engine_api.lua` 头注释写「当前 97 个」
- **WHEN** 执行 `grep -cE '^function M\.' game/engine-love2d/engine_api.lua`
- **THEN** 输出 SHALL 为 `97`
- **AND** 源码级 conformance 检查（4 引擎）SHALL 仍然 0 缺
