# Design: port-contract-completeness — 契约粒度设计

> 父 slice: `port-slice1-contract-completeness`

## Context

本 change 要把 16 种 `lib.*` 提升为 EngineAPI 契约。难点不在"搬函数"，
而在**粒度设计**：现有契约里 `map` 与 `sprite` 子系统 12 个函数
**零调用**（dead contract），根因就是粒度错了。

### 现有错误粒度实例

```lua
-- 契约（7 个函数）
map.loadMain(earthFile, surfaceFile, buildingFile, buildXFile, buildYFile,
             width, height, x, y)
map.drawMain(playerX, playerY, playerPic)          -- 1 个签名盖 79 行实现
map.drawScene(sceneId, x, y, offX, offY, playerPic)
map.drawBattle(flag, x, y, v1, v2, v3)

-- 实际调用（framework 全走 lib）
lib.DrawMMap(JY.Base["人X"], JY.Base["人Y"], pic)   -- 4 处
lib.DrawSMap(...)                                    -- 2 处
```

`lib_love.lua:1054` 的 `DrawMMap` 有 **79 行**，包含：
等距投影换算、屏幕裁剪、云层动画、建筑遮罩排序、玩家精灵绘制。

**没有任何引擎能靠 `drawMain(px, py, pic)` 这个签名还原相同画面** ——
它把"怎么投影、怎么裁剪、云怎么动、建筑怎么遮"全部藏进了引擎实现。
所以框架作者（我）绕过了契约，直接用 `lib.DrawMMap`。

**这是契约设计的根本错误：语义级抽象掩盖了必须由 framework 决定的逻辑。**

---

## ADR-PORT-001：16 种 `lib.*` 逐个设计契约，不批量套模板

### Context

46 处调用分属 4 类子系统（地图 / 精灵 / 渲染 / 音频）。
如果批量套用"原样搬函数签名"的思路，会重复现有错误。

### Decision

每个函数单独决策粒度，判据是：

```
这个函数里，哪些逻辑是「引擎特性」，哪些是「游戏/框架决策」？
  → 引擎特性的部分放进契约
  → 框架决策的部分留在 framework
```

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| A. 原样搬 16 个签名进契约 | 重复 `map.drawMain` 的错误，契约继续是死的 |
| B. 全部拆到最细原语（每像素级） | 过度抽象，framework 要自己实现等距投影，换引擎时反而要改 framework |
| C. 折中：按上面判据逐个决策 | **采纳** |

### Consequences

- 契约函数数从 64 增到 83（+19），而非 +16
- 地图子系统会**重设计**（见 ADR-PORT-004），不是原样搬
- 需要为每个函数写「为什么是这个粒度」的注释（成本）

---

## ADR-PORT-002：`lib.Debug` → `EngineAPI.debug.log`

### Decision

180 处 `lib.Debug(...)` 全部改为 `EngineAPI.debug.log(...)`。

契约 `debug.log` **已存在**（`engine_api.lua:476`），只是 framework 没用它。
这是纯机械替换，风险最低，可作为第一批改动验证"分批策略"。

### Consequences

- `EngineAPI.debug.log` 从 dead contract 变为高频使用
- MUD/Web 引擎的 `debug.log` 已实现（无需改动）
- 保持 `lib.Debug` 全局存在（script 层仍有 100+ 调用点）

---

## ADR-PORT-003：`lib.GetKey` → `EngineAPI.input.getKey`（保留 VK 语义）

### Decision

15 处 `lib.GetKey()` 改为 `EngineAPI.input.getKey()`。
**返回值的 VK 整数语义保持不变**（迁移到动作层是 `input-action-layer`
已开始的独立工作，本 change 不碰）。

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| 顺带改成 `getAction()` | 那是 `input-action-layer` 的范围，混进来会让本 change 变成两个主题 |
| 不改（保留 lib.GetKey） | 违反 REQ-PORT1-1 |

### Consequences

- 36 处 `lib.GetKey` 业务调用点行为完全不变
- VK 常量与 `baseKeyMap` 保留（`input-action-layer` ADR-8 已确认）

---

## ADR-PORT-004：地图契约按**原语**拆分，不沿用 `drawMain` 语义级

### Context

这是本 design 最关键的决策。现有 `map.drawMain(px, py, pic)` 是死契约。
必须判断：等距投影该由 framework 还是引擎负责？

### 分析

`DrawMMap` 的 79 行实现拆解（读 `lib_love.lua:1054-1133`）：

| 逻辑 | 性质 | 归属 |
|------|------|------|
| 等距投影 `screenX = XScale*(i-j) + W/2` | **数学变换，纯计算** | framework |
| 视野裁剪（哪些格可见） | **数学变换** | framework |
| 逐格调用精灵绘制 | 引擎特性 | 引擎 |
| 云层动画位置（`CloudTick`） | **游戏逻辑（时间驱动）** | framework |
| 建筑遮罩排序（y 坐标排序） | **数学（排序）** | framework |
| 精灵纹理采样 | 引擎特性 | 引擎 |

**结论**：79 行里只有"采样一个精灵画到屏幕"是引擎特性，
其余全是可移植的数学与逻辑。

### Decision

```lua
-- 引擎契约（只保留真正需要引擎的）
EngineAPI.map.getTile(x, y, layer)      --> number  读地图数据
EngineAPI.map.setTile(x, y, layer, val) --> 写（存档用）
EngineAPI.map.loadMain(...)             --> 加载（保留原签名）
EngineAPI.map.loadScene(...)            --> 加载（保留原签名）

-- framework 新模块
framework/map_render.lua
  MapRender.drawMain(playerX, playerY, frameId)
    -- 内部：算投影 → 裁剪 → 排序 → 逐格调 EngineAPI.sprite.draw
  MapRender.drawScene(sceneId, ...)
```

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| A. 保留 `map.drawMain` 语义级 | 死契约继续死，换引擎时仍需 79 行等距投影实现 |
| B. 完全由 framework 绘制（引擎只给 getTile + sprite.draw） | **采纳**：等距投影是游戏决策，不该每个引擎重写 |
| C. 引擎绘制但暴露中间件钩子 | 过度设计，当前无消费方 |

### Consequences

- **framework 新增 `map_render.lua`**（约 150 行，纯计算 + 调 sprite.draw）
- 引擎侧只需 `getTile` / `setTile` / `load*` + `sprite.draw`（已存在）
- 4 处 `lib.DrawMMap` 调用改为 `MapRender.drawMain`
- **风险**：这是本 change 最大改动，需实机对照逐格像素

---

## ADR-PORT-005：精灵加载契约分四级

### Context

现有 `sprite` 5 个函数（`initSprites` / `loadArchive` / `getSize` / `draw` / `drawTinted`）
零调用。而实际用的是 `lib.PicInit` / `lib.PicLoadFile` / `lib.PicLoadCache` / `lib.LoadPicture`。

### Decision

```lua
-- 保留（已存在，本 change 确认可用）
sprite.initSprites()
sprite.loadArchive(idxFile, grpFile, archiveId)
sprite.getSize(archiveId, frameId)       --> w, h, offsetX, offsetY
sprite.draw(archiveId, frameId, x, y, flags, alpha)
sprite.drawTinted(archiveId, frameId, x, y, color, alpha)

-- 新增（覆盖 lib.Pic* 的用法）
sprite.initPalette(paletteFile)          ← lib.PicInit
sprite.loadPicture(filename, x, y)       ← lib.LoadPicture（独立图片，非档案）
sprite.invalidateCache(archiveId)        ← lib.PicLoadCache 的缓存失效语义
```

**`PicLoadCache` 的语义澄清**：它内部做了 `picid / 2` 与 `flag` 位域解析，
这些是**引擎内的编号约定**，不是 framework 该关心的。所以契约层面
`sprite.draw` 直接接受 `frameId`（不透明整数），由引擎的 `loadArchive`
定义编号语义。

### Consequences

- `sprite.draw` 从 dead contract 变为唯一高频绘制入口
- framework 里 8 处 `lib.PicLoadFile` 改为 `sprite.loadArchive` / `sprite.draw`
- `flags` 的 0x1/0x2/0x4/0x8 位域**保留**（4 引擎都能实现），
  但文档写清「0x4/0x8 是调色板技巧，新引擎可用 drawTinted 替代」

---

## ADR-PORT-006：dead contract 不删「有明确未来消费者」的

### Decision

38 个 dead contract 分三类处置：

| 类别 | 数量 | 处置 |
|------|------|------|
| 有明确未来消费者（被 TODO.md 记录的 slice 引用） | 12 | 保留 + 注释说明 |
| 完全无意义（如 `color.pack` 无任何跨引擎价值） | 8 | 删除 |
| 粒度错但需重设计（map/sprite 的语义级函数） | 18 | 保留但标注 `@deprecated`，指向新契约 |

### Consequences

- 删除 8 个后契约数 83 - 8 = 75
- 18 个标 `@deprecated` 的函数在门禁里不计入 dead contract 统计
- 需要 `decisions.md` 逐项留痕（REQ-PORT1-7）

---

## ADR-PORT-007：跨引擎一致性测试用哨兵值而非 skip

### Context

现有 `test_engine_api.lua` 只断言"函数存在"，MUD/Web 上根本没有行为验证。
若用 `skip`，缺陷会隐身。

### Decision

```lua
-- test_engine_conformance.lua 的断言风格
local w = EngineAPI.render.getWidth()
-- MUD 引擎返回哨兵 1024（而非 nil 或抛错）
TestHelper.assertTrue(type(w) == "number", "getWidth 必须返回 number")
TestHelper.assertTrue(w > 0, "getWidth 必须 > 0（即使是哨兵值）")
```

每个引擎明确声明自己的哨兵值约定，测试断言该约定成立。

### Consequences

- MUD/Web 引擎需要"假实现"（返回合理哨兵），成本略增
- 但换引擎时不会有"函数存在但行为不可预期"的情况

---

## Negative Constraints

```
✗ 不得在本 change 里引入动作层改造（那是 input-action-layer 的完成态）
✗ 不得删除 lib.Debug / lib.GetKey 的全局存在（script 层仍在用）
✗ 不得为了"契约完整性"新增无消费者的函数（dead contract 就是这么来的）
✗ 不得把等距投影留给引擎实现（见 ADR-PORT-004）
✗ 不得一次性提交 237 处改动（必须分批）
✗ 不得用 skip 掩盖跨引擎行为缺失
✗ 不得在本 change 里改 sprite 动画（那是 slice 3）
```

## Review Checklist

```
[ ] 19 个新契约每个都写了「为什么是这个粒度」
[ ] 46 处 lib.* 调用全部改为契约（无遗漏）
[ ] 191 处 Debug/GetKey/Delay/GetTime 全部改（无遗漏）
[ ] map_render.lua 的等距投影实机对照逐格像素一致
[ ] 虚拟手柄在 LÖVE 下真实激活（端到端测试可证）
[ ] 4 引擎一致性测试真实执行（不是 skip）
[ ] decisions.md 覆盖 38 项
[ ] 四版本全量测试零失败
[ ] luac5.1 -p / luac55 -p 零失败
[ ] LÖVE 11.5 启动冒烟无报错
```
