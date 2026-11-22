# Change Proposal: port-sprite-native-migration — 消除 script 层的 lib.Pic* 双轨

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）
> 前置: `port-script-decoupling` ✓ / `battle-extensibility` ✓

## Why

`framework/` 侧已经完全走 `SpriteAtlas`（引擎只见 handle，不见 `.idx/.grp`）。
但 **`script/` 层仍有 27 处 `lib.Pic*`**，它们走旧系统直接读引擎的
`picFileCache`。这造成两个具体问题：

### 1. 两套贴图系统必须同时加载（双轨）

`framework/war_async.lua` 的 `WarMainCoroutine` 里现在有：

```lua
SpriteAtlas.loadArchive(...)              -- 新：framework 侧绘制用
EngineAPI.sprite.loadArchive(...)         -- 旧：写 picFileCache，供 lib.Pic* 用
```

这是我在 `battle-extensibility` 阶段为了绕开崩溃加的**补丁**
（commit `ebf81af`）。它不是设计，是两个系统不互通的妥协。

### 2. 换引擎时必须再造一份 `lib_love.lua`

`game/script/` 用了 **258 处 `lib.*` 调用 / 35 个函数**。其中
`PicGetXY` / `PicLoadCache` / `PicLoadFile` / `PicInit` 共 **24 处**。

新引擎（MUD/Web/测试桩）只实现 EngineAPI 契约，**不提供 `lib.*`** →
它们跑不了 script 层。`lib.*` 兼容层只存在于 `engine_love2d.lua:985`：

```lua
_G.lib = setmetatable(EngineAPI, { __index = lib })   -- lib = lib_love.lua
```

### 3. gate 的 `engine-love2d` 豁免永远摘不掉

`gate_engine_contract.sh` STEP D 至今留着：

```
[INFO] engine-love2d 豁免理由已变更：script 层 33 处 lib.Pic* 未迁移
```

只要 `lib.Pic*` 还在，`lib_love.lua` 的 `LoadPic`（119 行 RLE 解码）
就删不掉——它是 framework 已搬走的解码逻辑的最后一份副本。

---

## In Scope

### 1. 先修 `SpriteAtlas` 的 PNG 路径（**前置，不可跳过**）

实测发现两个缺陷，会让迁移在人物 59 的头像上崩：

| 缺陷 | 位置 | 后果 |
|------|------|------|
| `getMeta` 对 PNG 帧返回 `nil` | `sprite_atlas.lua:238-241` | 头像尺寸拿到 nil |
| `getHandle` 对 PNG 存 `atlas.meta[slot]` 的 `w/h` 是 **0** | `sprite_atlas.lua:220-224` | 头像位置按 0×0 算 → 错位 |

**为什么这是真问题（实测数据）**：

```
hdgrp.grp 的 PNG 帧: slot 59 / 111        （parseIdx 扫描确认）
r1.grp 里人物 59 的头像代号 = 59
  → picid = 59*2 = 118 → slot = 118/2 = 59  ← 命中 PNG
```

修法：
- `getHandle` PNG 分支：handle 创建后从 `EngineAPI.sprite.getMeta(handle)`
  回读真实 `w/h`，写进 `atlas.meta[slot]`
- `getMeta` PNG 分支：兜底调 `getHandle`（它会缓存 meta），再取值

**注意**：MUD/Web 的 `createFromEncoded` 返回 `{w=0, h=0}`（测试桩不解码真图），
兜底逻辑必须**容忍 w=0**，不能当错误。

### 2. `battle_render.lua` 迁移（7 处）

| 现状 | 迁移到 |
|------|--------|
| `lib.PicGetXY(1, 头像代号*2)`（`WarShowHead`） | `SpriteAtlas.getMeta(1, frameId)` |
| `lib.PicLoadCache(1, ..., 1)` | `SpriteAtlas.draw(1, frameId, x, y, 0x1)` |
| `lib.DrawWarMap(...)` × 5 | `EngineAPI.map.drawBattle(...)` |

### 3. `jymain.lua` 迁移（27 处）

| 类型 | 数量 | 处置 |
|------|------|------|
| `lib.PicInit()`（**无参 = no-op**） | 6 | **直接删** |
| `lib.PicInit(CC.PaletteFile)` | 1 | 删（`jymain_adapter.init` 已调 `initSprites(paletteFile)`） |
| `lib.PicLoadFile(a,b,id)` | 14 | `SpriteAtlas.loadArchive(a, b, id, {paletteFile=...})` |
| `lib.PicGetXY` | 3 | `SpriteAtlas.getMeta` |
| `lib.PicLoadCache` | 3 | `SpriteAtlas.draw` |

### 4. 移除 `war_async.lua` 的双轨补丁

`WarMainCoroutine` 里那两行（`SpriteAtlas.loadArchive` + `EngineAPI.sprite.loadArchive`）
只需保留新系统那一半。

### 5. gate STEP D 取消 `engine-love2d` 豁免 + 删 `lib_love.LoadPic`

迁移完成后：
- `gate_engine_contract.sh` 的 STEP D 对 4 个引擎一视同仁
- `lib_love.lua` 的 `LoadPic`（119 行）可删（`lib.PicLoadFile` 不再被调用）
- **但 `lib.PicGetXY` / `PicLoadCache` 若仍有死代码路径引用**，需先确认

---

## Out of Scope

```
✗ 其余 24 个 lib.* 函数（GetKey/Delay/SetClip/DrawMMap...）→ 归 port-native-api-*（未立项）
✗ 27 个死契约的清理   → 同上
✗ 地图数据 API（GetD/SetD/GetS/SetS）→ 同上
✗ 实际写 Godot/Unreal 引擎 → 本 change 只消除 Pic* 双轨
```

**重要**：本 change **不解决**「换引擎只需写 engine-xxx」。那个目标需要
消除全部 258 处 `lib.*`，是另一个量级的工程。本 change 只消灭其中最集中的
一类（Pic* 24 处 + 双轨补丁），并为 gate 摘掉一个长期豁免。

## 关键度量

| 指标 | 基线（实测） | 目标 |
|------|-------------|------|
| `script/` 的 `lib.Pic*` | **27 处** | **0** |
| `war_async.lua` 的双轨加载 | 2 套 | 1 套（只 SpriteAtlas） |
| `SpriteAtlas.getMeta` 对 PNG | 返回 nil | 返回真实 w/h |
| `gate` STEP D 豁免 | 1 个（engine-love2d） | **0 个** |
| `lib_love.LoadPic` | 119 行（仍在用） | 可删 |
| 人物 59 的头像 | 迁移后会崩 | 正常 |

## 风险

| 风险 | 缓解 |
|------|------|
| PNG 帧迁移后尺寸错（0×0） | 先修 getMeta/getHandle，用 `hdgrp` slot 59 做专项测试 |
| `SpriteAtlas` 需要 atlas 已加载 | 调用点都在 init/enter 之后（`Init_MMap`/`Init_SMap`/`WarMainCoroutine` 都先 loadArchive） |
| 死代码路径（`WarMain` 阻塞版 10 处） | 也要迁（不能留半套），否则 gate 豁免摘不掉 |
| `lib_love.LoadPic` 删了之后 `PicLoadFile` 还能用吗 | **不能删 PicLoadFile 本身**（`sprite.loadArchive` 契约仍调它）；只删 `LoadPic`（内部解码路径）需先核实 |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-SNM-1 | `SpriteAtlas` 的 PNG 路径必须返回真实尺寸 | specs/sprite-atlas-png/spec.md |
| REQ-SNM-2 | `script/` 零 `lib.Pic*` | specs/sprite-atlas-png/spec.md |
| REQ-SNM-3 | 移除双轨加载补丁 | 同上 |
| REQ-SNM-4 | gate STEP D 零豁免 | 同上 |
