---
status: active
created: 2026-11-22
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

`engine-portability` slice 的前三批（16 个 change）已经把**可移植性**做到位了：

```
framework 里 love.* 直接调用      0 处
framework 里 require engine-*     0 处
framework 里 lib.*                0 处
契约总数                          95 个 / 15 个模块
4 引擎源码级完整度                全部 0 缺
```

但**可移植 ≠ 可运行速度**。换引擎之后暴露的下一个问题是**每帧绘制调用次数**：

### 实测数据：主地图一帧 **约 2900 次 `EngineAPI.sprite.drawHandle`**

`game/framework/map_render.lua` 的 `drawMain` 是**立即模式全量重画**：
480×480 等距地图，按当前裁剪区反算可见瓦片范围，视野内每格画 0/1 两层，
再画一层建筑（`buildingSort` 排序后的 depth 序）。

实测（864×648 视口 / `XScale=18` `YScale=9`，裁剪区 = 全屏）：

| 量 | 值 | 来源 |
|---|---|---|
| 循环格数（`drawMain` 的 j×i 双重循环） | **2912**（91 行 × 32 列） | 由 clip 反算的 `istart..iend / jstart..jend` 实算 |
| 若每格两层都非空 → 上限 | 5824 | 2912 × 2 |
| **`drawMain` 内 `drawTile` 调用数（实测）** | **2926** | LÖVE 实机计数打点（第 1400 帧） |
| 该帧整幅画面的 `sprite.drawHandle` 总数 | **2927** | 同上（差 1 = 云层/其它） |

即：**一个 `drawMain` = 约 2900 次独立绘制调用**，且**几乎全部来自这里**
（画家整幅画面只多 1 次），这是本 change 要处理的数量级。

> 测量方法：临时在 `map_render.drawTile` 与 `sprite.drawHandle` 入口各插一个计数器，
> `love.draw` 里按帧读出并写到 save 目录（LÖVE 的 `_G` 有严格 metatable，
> 必须 `rawset`）。计数代码**已回退**，不留在提交里。

### 三目标引擎的代价差异（这是本 change 的真正动机）

| 引擎 | 约 2900 次 `drawHandle` 的实际代价 | 结论 |
|---|---|---|
| **LÖVE (OpenGL)** | 同纹理连续 `draw` 有**隐式批处理** → 实测流畅 | 现状可接受 |
| **Godot 4** (`draw_texture_rect`) | 每帧重建约 2900 个绘制命令发布到 `CanvasItem` | 可行（命令是引擎侧数据） |
| **Unreal (HUD `DrawTile`)** | **每次是独立 draw call** | **很可能掉帧** |

也就是说：同一份 framework 代码，在 LÖVE 上是 60fps，在 Unreal 上可能只有
个位数帧率 —— 而这个差异**完全不体现在契约里**，因为当前**没有任何批处理机制**。

### 缺的是什么

不是「批处理实现」（那是引擎内部的事），而是**「调用方能否把这堆同类绘制
一次性告诉引擎」的通路**。缺了它：

- 想做批处理的引擎**没有入口**（只能靠引擎自己猜连续调用模式，而这在
  立即模式 + 逐格循环下不可靠：同一格的两层、建筑层与瓦片层交错）
- 调用方**无法表达意图**（"这约 2900 次是同一类绘制，可以任意重排"）

## Parent Context

- Slice: `openspec/changes/archive/2026-11-22-engine-portability/`
  （**slice 第三批之后的第四批**，前三批 16 个 change 全部归档）
- 前序 change（均已归档）：
  - `port-map-render-native`：`drawMain/drawScene/drawBattle` 搬进 framework，
    坐标投影与循环范围在这里定型（**本 change 的约 2900 次调用就来自这里**）
  - `port-legacy-picture-removal`：删掉 `lib_love` 的旧贴图子系统，
    地图绘制统一走 `SpriteAtlas.draw` → `sprite.drawHandle`
  - `port-engine-boot`：新增 `render.beginFrame/endFrame` 绘制边界契约
    （**本 change 的 `beginBatch/endBatch` 就挂在同一对边界内部**）
  - `port-conformance-hardening`：4 引擎源码级契约完整性判据
    （本 change 新增 2 个契约后必须继续 0 缺）
- 依赖: 无硬依赖（本 change 不改游戏逻辑、不改渲染结果）

## What Changes

1. **新增 2 个契约**（95 → 97），挂在 `M.render` 段：
   - `M.render.beginBatch(kind)` → **boolean**（是否真的进入了批处理）
   - `M.render.endBatch()`
   - 关键语义写进契约注释：**false = 引擎不支持 → 调用方照旧逐次 draw**；
     批次内 `drawHandle` 语义不变；**明确禁止嵌套**（内层 begin 返回 false）

2. **新增 `game/framework/render_batch.lua`**（零 `love.*`，只调 EngineAPI）：
   - `RenderBatch.begin(kind)` —— 转调 `beginBatch`，**首次调用兼任探测**并缓存结论
   - `RenderBatch.finish()` —— 转调 `endBatch`（无害空操作语义）
   - `RenderBatch.wrap(kind, fn)` —— `begin → pcall(fn) → finish`，
     **保证 finish 一定执行**（fn 抛错时也执行），再把错误原样重抛
   - `RenderBatch.isSupported()` —— 引擎是否支持（首次探测后缓存）
   - `RenderBatch.reset()` / `isActive()` —— 测试与诊断用

3. **`framework/map_render.lua` 的 `drawMain` 用它**：
   把「瓦片两层 + 建筑层」三段循环包进 `RenderBatch.wrap("tile", ...)`。
   **云层不包**（它走 `map.drawClouds`，是引擎侧独立子系统）。

4. **4 个引擎实现 `beginBatch`/`endBatch`**：
   - **LÖVE 返回 `false`**（不做真批处理 —— 隐式批处理已够好，见 design.md ADR-2）
   - **MUD / Web / 测试桩返回 `false`**（无 GPU / 无绘制命令可合并）
   - 四者都必须实现这两个函数并返回 boolean（契约完整性）

5. **新增单测 `game/tests/unit/test_render_batch.lua`**（45 断言）：
   支持/不支持两条路径、抛错时 finish 必调、嵌套拒绝、探测缓存、
   `drawMain` 集成（begin 是第一个事件、end 是最后一个事件）

6. **更新 slice manifest**：`change-manifest.md` 的「16 个」→「17 个」+
   新增「第四批：绘制批处理契约（2026-11-22）」小节（含依赖图）。

## Out of Scope

- **LÖVE 的真批处理（`love.graphics.newSpriteBatch`）**：本 change **只加口子**。
  理由见 design.md ADR-2：① LÖVE 已经有隐式批处理，换不来可感知收益；
  ② 真批处理要改 `drawHandle` 的整个实现（atlas 纹理绑定 + flags/alpha 的
  每条组合一个 SpriteBatch 或换 shader）；③ SpriteBatch 生命周期要跟
  atlas 的加载/卸载/MOD 切换同步 —— **画错的风险大于画慢的收益**。
- **`drawScene` / `drawBattle` 的接入**：它们的结构相同（同样是三层循环），
  但本 change 只改 `drawMain`（**实测数据的来源**），另两个留作后续
  —— 接入前要先量各自的调用次数，避免「用优化解决不存在的问题」。
- **文字批处理（`kind = "text"`）**：`render.text` 目前每帧几百次，
  量级比瓦片小一个数量级，且文字有字形缓存这个更有效的优化方向。
- **跨 `beginFrame/endFrame` 的批次**：批次必须落在帧绘制回调内部
  （契约已写），不提供跨帧累积。
- **真正的 Godot / Unreal 引擎实现**：本 change 只提供契约 + framework 薄层 +
  4 引擎的 boolean 决策，不写具体引擎的批处理。

## Impact

- Affected specs: `render-batching`（新建）
- Affected code:
  - `game/engine-love2d/engine_api.lua`（+2 契约 + 语义注释 + 计数 95→97）
  - `game/engine-love2d/engine_love2d.lua`（+2 实现，均返回 false）
  - `game/engine-mud/engine_mud.lua`（+2，返回 false，走 logCall）
  - `game/engine-web/engine_web.lua`（+2，返回 false）
  - `game/tests/engine_test.lua`（+2，默认 false + `_batchSupported` 开关）
  - `game/framework/render_batch.lua`（**新**）
  - `game/framework/map_render.lua`（`drawMain` 包 wrap）
  - `game/tests/unit/test_render_batch.lua`（**新**，45 断言）
  - `game/tests/unit/test_engine_api.lua`（+2 存在性断言）
  - `game/tests/test_helper.lua`（mock 引擎补 2 个桩，返回 false）
  - `game/tests/test_runner.lua`（注册新模块）
  - `openspec/changes/archive/2026-11-22-engine-portability/change-manifest.md`
- **行为影响：零**。4 个引擎全部返回 `false` → `RenderBatch` 走降级路径 →
  绘制调用序列与改造前逐条相同 → 实机截图 md5 不变
  （`1efd2af3a9ecfce48b89ef14b9a14338`，已在 main 地图 1400 帧验证）。
