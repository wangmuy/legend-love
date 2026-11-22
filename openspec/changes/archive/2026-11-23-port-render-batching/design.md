---
status: active
created: 2026-11-22
---
# Design: port-render-batching

> 本 change 引入**两个契约 + 一个 framework 薄层 + 一个调用点**。
> 两个关键决策记作 ADR：① 契约为什么返回 boolean；② 为什么本 change
> 不做 LÖVE 的真批处理。

## 背景：为什么「批处理」需要出现在契约里

`drawMain` 一帧约 **2900 次** `sprite.drawHandle`（实测 2896 / 复测 2926）。
三个目标引擎的代价：

| 引擎 | 单次 `drawHandle` 的实质 | 2900 次的代价 |
|---|---|---|
| LÖVE (OpenGL) | `love.graphics.draw(image)`；同纹理连续 draw **隐式合批** | 流畅 |
| Godot 4 | `CanvasItem.draw_texture_rect()` → 追加一条绘制命令 | 可行（命令是引擎侧数据） |
| Unreal (HUD `DrawTile`) | `UCanvas::DrawTile` → **每个 tile 独立 draw call** | 很可能掉帧 |

同一份 framework 代码在 LÖVE 与 Unreal 上差一到两个数量级的帧率，
而这个差异**在契约里完全不可见** —— 因为当前没有任何「这些绘制是同一类、
可以任意合并」的表达方式。

---

## ADR-RB-1：`beginBatch` 必须返回 boolean，而不是「假设引擎一定支持」

### Context

最省事的契约设计是「无返回值、纯提示」：

```lua
function M.render.beginBatch(kind) end   -- 调用方：beginBatch("tile") ... endBatch()
```

语义上「批处理是优化，引擎自己决定要不要做」听起来很合理。但它**不成立**，
因为调用方必须知道一件事：**这批绘制能不能假设「顺序无关」**。

具体到 `drawMain`：如果引擎支持批处理，调用方可以放心把三层循环的绘制
**任意重排/合并**（按纹理分组、跳过被完全遮挡的格子）。如果不支持，
**绘制顺序就是视觉正确性本身** —— 建筑层压在地面层之上、`buildingSort`
的 depth 序决定谁遮谁（`map_render.lua` 的注释里明确记着 commit `2c8a644`
的回归：「把主角拆出来单独绘制 → 走到大山背后整块露出来」）。

于是「支持 / 不支持」是**行为分叉点**，不是一个可忽略的提示。
调用方必须能查询它。

### Decision

`beginBatch(kind)` **返回 boolean**：

```lua
--- @return boolean 是否真的进入了批处理模式（false = 引擎不支持，调用方照常逐次 draw）
function M.render.beginBatch(kind) end
```

调用方据此分支：

```lua
if RenderBatch.begin("tile") then
    -- 可以重排 / 合并（当前没做，但口子在这里）
else
    -- 逐次绘制，顺序即正确性
end
```

### Alternatives

**（A）无返回值 + 引擎侧全局开关。**

```lua
EngineAPI.render.setBatching(true)   -- 启动时设一次
```

问题：引擎能力不是「一个全局开关」能表达的。同一引擎可能对 `tile` 支持、
对 `text` 不支持（文字要走字形缓存，批处理反而更慢）。而且「调用方读到
true 但引擎其实没实现」的失败是完全静默的 —— 与本项目最痛的那类缺陷
（`test_engine_conformance` 靠空桩 PASS）同构。

**（B）返回 `handle` 对象（批处理上下文）。**

```lua
local ctx = EngineAPI.render.beginBatch("tile")
EngineAPI.render.endBatch(ctx)
```

更灵活（支持多批次并存），但需要引擎侧的对象生命周期管理，而**本 change
的四个引擎全部返回「不支持」** —— 引入一个只有 nil 的对象协议纯属过度设计。
真需要时可以把 `beginBatch` 升级成返回 ctx（`true` → ctx 表），
调用方 `if entered then` 的判断**不需要改**。这就是选 boolean 的额外好处：
它是未来 ctx 协议的**真值子集**。

**（C，选中）返回 boolean。**

### Consequences

- ✅ 「引擎能力」变成运行时可查询的值，调用方无需猜
- ✅ 降级路径严格可验：4 引擎都返回 false → 绘制序列逐条不变 → 截图 md5 不变
- ✅ 负向对照可做：桩改成返回 true 但引擎记录不到 begin/end 配对 → 断言 FAIL
- ⚠️ 多一次函数调用的开销：`RenderBatch` 把结论**缓存**在 framework 层，
  所以「不支持的引擎」每帧只会被问一次（而不是 2900 次）。实测该缓存
  由 `testUnsupportedStillRunsFn` 的最后一条断言锁定。
- ⚠️ 布尔无法表达「部分支持」（如只有 tile 支持）。当前不需要 —— `kind`
  已经是提示而非约定，真出现部分支持时引擎可以按 kind 返回 true/false。

---

## ADR-RB-2：本 change **不做** LÖVE 的真批处理（`newSpriteBatch`）

### Context

LÖVE 完全有能力做真批处理：`love.graphics.newSpriteBatch(image, maxsprites)`
把几千个 quad 攒进一个顶点缓冲，一次 `spriteBatch:draw()` 提交。理论上能把
2900 次 draw call 压到个位数。

### Decision

**本 change 的 LÖVE 实现返回 `false`**，不做真批处理。只把契约与调用点建好。

### Why（三条，按重要性）

**① LÖVE 已经有隐式批处理 —— 真批处理换不来可感知收益。**

`love.graphics.draw` 在内部按「当前纹理 + 混合模式 + shader」合批。
本游戏的瓦片全部来自同一个 `SpriteAtlas` 的同一张纹理，连续 draw 天然合批。
实测本游戏主地图在 LÖVE 下**是流畅的**（这正是任务描述里的对照基线）。
在一个已经不掉帧的引擎上做批处理，收益是 0，风险不是。

**② 真批处理要改 `drawHandle` 的整个实现。**

`newSpriteBatch` 的硬约束是「**同一张纹理** + 固定顶点格式」。而当前
`drawHandle` 支持：

| 变体 | 来源 | 对 SpriteBatch 的影响 |
|---|---|---|
| RLE 帧 | `createFromRGBA` → 每帧一个 `Image` | **每帧纹理不同** → 每帧一个 SpriteBatch |
| PNG 帧 | `createFromEncoded` | 同上 |
| `flags` 黑化/白化 | `setColor` 实现 | 顶点颜色可以，但每个 flag 组合要单独的 batch |
| `flags` alpha | `setColor` alpha | 同上 |
| `drawHandleTinted` | 任意青色 | 同上 |
| 缩放/旋转（未来） | — | 超出 SpriteBatch 默认顶点格式 |

注意第一行是最致命的：**`createFromRGBA` 是每帧一张独立 `Image`**，
不是一张打包的大 atlas。要让 SpriteBatch 有意义，必须先在 framework 侧
做**纹理打包**（把 2926 帧的图塞进一张大图并重算 UV）—— 那是另一个 change
（本质上是「运行时 atlas 生成器」），远超出「加个批处理契约」的范围。

**③ SpriteBatch 生命周期与 atlas 生命周期耦合，画错的风险大于画慢的收益。**

SpriteBatch 持有纹理引用与顶点数据，必须与以下事件同步：

- `SpriteAtlas.clear()` / `unload()`（场景切换、战斗进入/退出）
- MOD 切换（`ModData` 换掉整个 data 目录）
- `sprite.clearPictureCache()`
- 窗口 resize / DPI 变化（顶点缓冲要不要重建）

漏掉任何一条的表现都是「**画面错位或残留旧图**」而不是崩溃 —— 属于本项目
最难查的一类缺陷（见 `port-legacy-picture-removal` 的记录：旧贴图子系统的
flag 位语义差异导致「有点不对但不崩」的画面）。

### Alternatives

**（A）本 change 就把 LÖVE 的 SpriteBatch 做了。**

收益：LÖVE 上 2900 → 个位数 draw call。但 LÖVE 上本来就流畅，
**这个收益用户感受不到**；成本是 ADR ② ③ 的全部风险 + 纹理打包。

**（B）连契约都不加，等真做的时候再说。**

问题是「等真做的时候」意味着同时改契约 + 4 引擎 + 调用方 + 测试。
而现在加契约的成本极低（4 个引擎各 5 行、framework 1 个文件、1 个调用点），
且**行为零变化**。先把口子留出来，未来的 Unreal 实现者只需填 `beginBatch`。

**（C，选中）加契约 + framework 薄层 + 调用点，4 引擎全部返回 false。**

### Consequences

- ✅ 现在：行为逐字节不变（实机 md5 `1efd2af3…` 已验证），零回归风险
- ✅ 未来：Unreal/Godot 实现者只需在自己的引擎里返回 `true` 并在 `endBatch`
  里提交 —— **framework 与 script 一行都不用改**
- ⚠️ 「有契约但没人用」的状态可能长期存在。缓解：契约注释里写明取舍，
  且 `engine_api.lua` 的注释直接指向本 ADR，避免下一任实现者以为漏了实现。
- ⚠️ 将来若真做，`wrap` 的语义保持不变，但**调用方需要复核**：
  支持批处理之后「顺序无关」才成立，`drawMain` 里的三层循环才有重排空间。

---

## ADR-RB-3：批次**禁止嵌套**（而不是支持成栈）

### Context

`RenderBatch.wrap` 可以被任意嵌套调用（比如将来给 `drawBattle` 也包一层，
而 `drawBattle` 内部若再调 `drawMain` 就会嵌套）。两种选择：

- **支持嵌套**（栈语义）：`begin`/`end` 维护深度计数，只有最外层真正提交
- **禁止嵌套**：内层 `begin` 直接返回 `false`，内层退化为「直接执行」

### Decision

**禁止嵌套。** 契约与 framework 层都明确写死：

- `EngineAPI.render.beginBatch` 在批次内调用 → 返回 `false`，不抛错，
  不改变外层批次状态
- `RenderBatch.begin` 在 `active` 时 → 返回 `false`（**根本不问引擎**）
- 内层 `wrap` 因此直接执行 `fn`（不进批次），外层批次保持有效

### Why

批处理的收益来自「同状态连续提交」。嵌套的语义是「内层改变状态 → 外层
必须重新提交」 —— 收益归零，复杂度翻倍（栈 + 每层的提交时机 + 每层的
状态快照）。

而本项目的绘制结构本身就是**并列三段**（地图 / 文字 / 形状），
没有嵌套需求。真出现需求时，把 `beginBatch` 改成栈并返回 true 即可 ——
调用方**不用动**（它本来就要容错 false）。

### Consequences

- ✅ 实现简单：一个 `active` 布尔，零栈管理
- ✅ 语义可测：`testNestedRejected` 断言「引擎只收到一次 begin/end」
- ⚠️ 若将来真需要嵌套，必须同时改契约注释（现在写着「禁止」）

---

## Negative Constraints（本 change **不得**违反）

| # | 约束 | 怎么验 |
|---|---|---|
| N1 | 引擎不支持批处理时，渲染输出**逐字节一致** | 实机 md5 `1efd2af3a9ecfce48b89ef14b9a14338`（1400 帧主地图） |
| N2 | framework 层零 `love.*` / 零 `require("engine-*")` / 零 `lib.*` | `gate_engine_contract.sh` STEP A/B/C |
| N3 | 四个引擎都必须**显式实现**两个契约（不能靠 `engine_api.lua` 空桩继承） | `test_engine_conformance` 源码级判据 |
| N4 | 批处理失败**绝不能让渲染链崩**（引擎抛错 → 降级逐次画） | `testBeginThrowDegrades` |
| N5 | `finish()` **无条件执行**（fn 抛错也要关批次） | `testFinishOnError` + 负向对照 |
| N6 | 不得改 `drawMain` 的绘制**顺序与参数**（只加外层包裹） | `test_map_render` 既有断言 + md5 |
| N7 | 契约注释必须写清三条语义（false 语义 / 批次内不变 / 禁止嵌套） | 人工 review + 本文件 |

## Review Checklist

- [ ] `beginBatch` 的注释里有「false = 不支持，调用方照常逐次 draw」
- [ ] `beginBatch` 的注释里有「批次内 `drawHandle` 语义不变」
- [ ] `beginBatch` 的注释里有「禁止嵌套」+ 理由
- [ ] 4 个引擎的 `beginBatch` 都 `return false`（不是 nil、不是隐式返回）
- [ ] `RenderBatch.wrap` 的 `finish()` 在 `pcall` **之后无条件**调用
- [ ] `map_render.drawMain` 只包了「瓦片两层 + 建筑层」，云层在外面
- [ ] 测试覆盖「支持 / 不支持 / 抛错 / 嵌套 / 缺契约」五条路径
- [ ] 负向对照真跑过（去掉 finish 保证 → 4 条断言 FAIL）
- [ ] 4 个 Lua 版本全量测试 0 失败
- [ ] 实机 md5 不变
