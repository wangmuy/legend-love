# Tasks: port-map-render-native

> **策略**：先把 6 个新契约加到 4 个引擎（低风险、可独立验证），
> 再搬 363 行投影逻辑（高风险、必须逐字节截图）。
> 每个 Task 一个 commit，任何一步失败都能回退。

## Task 1：加 6 个新契约（4 引擎）

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`、`tests/engine_test.lua`、`tests/unit/test_engine_api.lua`

**DoD**：
- [x] `render.getClip()` —— 返回 `{x, y, w, h}`（LÖVE: `love.graphics.getScissor()`）
- [x] `map.setTile(x, y, layer, value)` —— LÖVE: `lib.JY_SetMMap`
      （**消费者是 `map_render.buildingSort`**：它临时把主角/船写进建筑层 2/3/4
      参与深度排序，排序后恢复。`SetMMap` 原本是 local，已暴露为 `JY_SetMMap`）
- [x] `map.getSceneTile(sceneId, x, y, layer)` —— LÖVE: `lib.GetS`（**4 参**，
      场景数据按「场景 × 6 层 × 尺寸」排布，必须带 sceneId；层数 0..5 不是 0..4）
- [x] `map.setSceneTile(sceneId, x, y, layer, value)` —— LÖVE: `lib.SetS`
- [x] `map.getBattleTile(x, y, layer)` —— LÖVE: `lib.GetWarMap`
- [x] `map.getSceneEventData(sceneId, eventId, field)` —— LÖVE: `lib.GetD`
      （**不是地图瓦片**，是场景 tile 上挂的事件数据；`DrawSMap` 用它查贴图）
- [x] `map.setSceneEventData(sceneId, eventId, field, value)` —— LÖVE: `lib.SetD`
- [x] `map.clearBattleTile(layer, value)` —— LÖVE: `lib.CleanWarMap`
- [x] `map.setBattleTile(x, y, layer, value)` —— LÖVE: `lib.SetWarMap`
- [x] MUD / Web / 测试桩各有实现（MUD/Web 可以返回空值，但不能缺）
- [x] 契约数 76 → **85**（加 9 个）
- [x] 单测：每个新契约在 4 个引擎都存在（`assertNotNil`）
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 2：搬 `BuildingSort`（零引擎调用，83 行）

**Blast Radius**：`framework/map_render.lua`（新建）

### 【关键实测】BuildingSort 写主地图

```lua
local bak  = GetMMap(x,y,2)
local bakx = GetMMap(x,y,3)
local baky = GetMMap(x,y,4)
SetMMap(x,y,2, bit32.band(Mypic*2, 0xFFFF))   ← 临时写建筑层
SetMMap(x,y,3, x)
SetMMap(x,y,4, y)
... （排序）
SetMMap(x,y,2, bak)                            ← 恢复
SetMMap(x,y,3, bakx)
SetMMap(x,y,4, baky)
```

它把主角/船临时写进建筑层参与深度排序 —— 这就是 `map.setTile` 的**唯一消费者**
（我先前删掉它又加回来，原因就在这）。

### 【关键实测】`buildList` 归 framework，不在引擎

`buildList` / `buildNumber` 存的是「附近有哪些建筑 + 深度顺序」：

```
BuildingSort → 扫地图（map.getTile 2/3/4 层）→ 写 buildList
drawMain     → 读 buildList → 逐条 sprite.draw
```

输入是地图数据 + 主角坐标 = **纯游戏逻辑**，引擎只做最后的绘制。
所以搬进 framework 时把 `buildList` 变成 `map_render` 的**模块内状态**。

### 【决策】`DrawClouds` 不搬

它依赖 `love.graphics.newImage(CloudBakeImage(...))` 的**逐像素调色板烘焙**
（`lib_love.lua:1255`），属 sprite 子系统，不是 map 投影逻辑。
`map.tickClouds` 契约已负责位置更新（纯时间驱动），像素归引擎。
→ 记入 Out of Scope。

**DoD**：
- [x] `MapRender.buildingSort(x, y, mypic)` —— **逐字搬移**（83 行逻辑不改）
- [x] `buildList` / `buildNumber` 成为 `map_render.lua` 的模块内 local
- [x] `MapRender.buildingList()` / `MapRender.buildingCount()` 供 drawMain 读
- [x] 用 `EngineAPI.map.getTile` / `EngineAPI.map.setTile`
- [x] `CC.MWidth` / `CC.MHeight` / `CONFIG.*` 照抄（framework 现有惯例）
- [x] `framework/map_render.lua` 零 `love.*`、零 `require("engine-*")`
- [x] 单测：同样的地图输入 → 与 `lib.BuildingSort` **排序结果完全一致**
      （用测试桩引擎注入 `_tiles`，两个实现各跑一遍，逐条对比 `x/y/num`）
- [x] 单测：负向对照（把右旋那段改成 `table.insert` → 单测 FAIL，验证它守住了原版语义）
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 3：搬 `drawMain`（原 `lib.DrawMMap`，79 行）

**Blast Radius**：`framework/map_render.lua`、`engine_love2d.lua`、
`engine_mud.lua`、`engine_web.lua`、`tests/engine_test.lua`

### 先补一个契约：`map.drawClouds`

`DrawMMap` 最后调 `DrawClouds(x, y)`，而云的像素归引擎
（逐像素调色板烘焙 `CloudBakeImage`，属 sprite 子系统）。
原来只有 `map.tickClouds`（位置更新，纯游戏逻辑），**缺绘制**。
→ 新增 `map.drawClouds(mx, my)`，4 引擎实现。

### 8 处引擎调用的映射

| 原调用 | 新契约 | 说明 |
|--------|--------|------|
| `love.graphics.getScissor()` ×2 | `render.getClip()` ×1 | 原实现取两次（快照+算范围），framework 只需一次 |
| `love.graphics.setScissor(...)` | `render.setClip(...)` | 恢复快照 |
| `FillColor(0,0,0,0,0)` | `render.fillRect(0,0,0,0,0)` | 清屏 |
| `JY_LoadPic(0,pic,x,y,0,0)` ×5 | `SpriteAtlas.draw(0,pic,x,y,0,nil)` | **关键：不是 `sprite.draw`** |
| `GetMMap(x,y,0/1)` | `map.getTile(x,y,0/1)` | 地面/表层 |
| `BuildingSort(...)` | `MapRender.buildingSort(...)` | 已搬（Task 2） |
| `DrawClouds(x,y)` | `map.drawClouds(x,y)` | 新契约 |

**为什么贴图走 `SpriteAtlas.draw` 而不是 `EngineAPI.sprite.draw`**：

```lua
EngineAPI.sprite.draw = function(...) lib.PicLoadCache(...) end  -- 读 picFileCache ✗
SpriteAtlas.draw → EngineAPI.sprite.drawHandle(handle, ...)      -- 不读 ✓
```

`SpriteAtlas` 完全不碰 `picFileCache`（grep = 0 处代码引用）。

### 两个「禁止」必须原样保留（真实回归记录）

```lua
-- ① 禁止把主角拆出来「最后单独绘制」：
--    那样任何建筑（大山、房屋、树木）都再也遮不住主角，
--    走到大山背后会整块露出来（commit 2c8a644 引入的回归）
-- ② 禁止给主角加额外 y 偏移：
--    屏幕位置完全由贴图头的 xoff/yoff 决定，贴图头已带正确的
--    yoff（主角帧 15x39，xoff=5 yoff=44），再叠加就是错位
```

### 顺手修正一个隐式约定

原实现 `DrawMMap` 开头有 `buildNumber=0` 兜住 `BuildingSort` 的早退路径。
搬到 framework 后把这个清零**移进 `buildingSort` 开头** ——
「谁调 buildingSort 谁负责清零」是隐式约定，自动化更稳。

**DoD**：
- [x] 新增 `map.drawClouds(mx, my)` 契约（4 引擎）
- [x] `MapRender.drawMain(x, y, mypic)` —— 搬 79 行
- [x] 8 处引擎调用全部契约化（见上表）
- [x] `EngineAPI.map.drawMain` 改为调 `MapRender.drawMain`
      （带 pcall 逃生舱：framework 模块缺失时回退 `lib.DrawMMap` 并记日志）
- [x] **保留** `lib.DrawMMap`（`lib.*` 兼容层仍有人用）
- [x] `buildNumber` 清零移进 `buildingSort` 开头
- [x] 单测：`drawMain` **不调** `EngineAPI.sprite.draw`（它经 PicLoadCache）
- [x] 负向对照：把 `drawTile` 改成 `sprite.draw` → 测试 FAIL（实测 17 次）
- [x] **实机逐字节对比**：主地图/场景截图 md5 `1efd2af3…` 与迁移前相同
- [x] 四版本全量测试零失败（3998/0）
- [x] 一个 commit

---

## Task 4：搬 `drawScene`（原 `lib.DrawSMap`，79 行）

**Blast Radius**：`framework/map_render.lua`、`engine_love2d.lua`、
`engine_mud.lua`、`engine_web.lua`、`tests/engine_test.lua`、`lib_love.lua`

### 先补一个契约：`map.getSceneSize`

`DrawSMap` 的边界判据是 `xx < S_XMax` / `yy < S_YMax`，而这两个值在
`lib_love.lua:1382` 是 **local** 变量（`LoadSMap` 时赋值）。

framework 只能从 `CC.SWidth/SHeight` 猜 —— 那是**调用方传的参数**
（`jymain.lua:1980` 传的确实是 `CC.SWidth`），不是引擎的实际状态。
MOD 改调用参数就会静默错位 → 加显式契约。

`lib_love` 暴露 `GetSceneSize()`，4 引擎实现。契约数 86 → **87**。

### 8 处引擎调用的映射

| 原调用 | 新契约 |
|--------|--------|
| `love.graphics.getScissor()` ×2 | `render.getClip()` ×1 |
| `love.graphics.setScissor(...)` | `render.setClip(...)` |
| `FillColor(0,0,0,0,0)` | `render.fillRect(0,0,0,0,0)` |
| `JY_LoadPic(...)` ×5 | `SpriteAtlas.draw(0, pic, ...)` |
| `GetS(sceneid,xx,yy,0..5)` ×6 | `map.getSceneTile(sceneid,xx,yy,0..5)` |
| `GetD(sceneid, d3, 7)` | `map.getSceneEventData(sceneid, d3, 7)` |

### 两趟循环必须保留

原实现是**两趟**（不是一趟）：

1. 只画地面层（`GetS` level 0）
2. 画建筑 / 空中 / 事件贴图 / 主角（level 1..5）

**分两趟的原因**：地面必须先全部铺完，否则相邻格子的建筑会被后画的地面盖住。
合并成一趟会引入真实的遮挡错误。

**DoD**：
- [x] 新增 `map.getSceneSize()` 契约（4 引擎 + `lib.GetSceneSize`）
- [x] `MapRender.drawScene(sceneid, x, y, xoff, yoff, mypic)` —— 搬 79 行
- [x] 8 处引擎调用全部契约化（见上表）
- [x] **保留两趟循环结构**（不做"优化"）
- [x] `EngineAPI.map.drawScene` 改为调 `MapRender.drawScene`（带 pcall 逃生舱）
- [x] **保留** `lib.DrawSMap`
- [x] **实机逐字节对比**：场景截图 md5 `1efd2af3…` 与迁移前相同
- [x] 四版本全量测试零失败（3999/0）
- [x] 一个 commit

---

## Task 5：搬 `drawBattle`（原 `lib.DrawWarMap`，122 行，三个里最复杂）

**Blast Radius**：`framework/map_render.lua`、`engine_love2d.lua`、
`engine_mud.lua`、`engine_web.lua`、`tests/engine_test.lua`、`lib_love.lua`

### 先补一个契约：`map.getBattleSize`

`DrawWarMap` 用 `War_XMax` / `War_YMax` 做边界判据，而它们在
`lib_love.lua:1577` 是 **local**（`LoadWarMap` 时赋值）。
同 `getSceneSize` 的理由 → 加显式契约。契约数 87 → **88**。

### 12 处引擎调用的映射

| 原调用 | 新契约 |
|--------|--------|
| `love.graphics.getScissor()` | `render.getClip()` |
| `FillColor(0,0,0,0,0)` | `render.fillRect(0,0,0,0,0)` |
| `GetWarMap(x,y,0/1/2/3/4/5)` | `map.getBattleTile(x,y,0..5)` |
| `JY_LoadPic(0,pic,...)` ×6 | `SpriteAtlas.draw(0, pic, ...)` |
| `JY_LoadPic(3,v3,...)`（特效档案） | `drawTileFrom(3, v3, ...)` |
| `JY_LoadPic(v2,v1,...)`（替身档案） | `drawTileFrom(v2, v1, ...)` |

### 【本 Task 最重要发现】`sprite.drawHandle` 的 flags 语义是错的

原实现（`PicLoadCache`）位判断**三者独立**：

```lua
hasAlpha = flag & 0x2   → a = val/255      ← 独立
isBlack  = flag & 0x4   → r,g,b = 0,0,0    ← 独立
isWhite  = flag & 0x8   → r,g,b = 1,1,1    ← 独立
```

而 `drawHandle` 是 **elseif 链（互斥）**，`0x4` 优先、alpha 被忽略。

**唯一重叠用例正好是战斗的移动/攻击范围**：

```lua
JY_LoadPic(0, 0, x1, y1, 2+4, 128)     -- flag=1/2 的高亮格
-- 旧 PicLoadCache → r,g,b=0 且 a=128/255 → **半透明黑**（范围高亮）
-- 旧 drawHandle   → r,g,b=0 且 a=1       → **不透明黑块**（错）
```

我之前在 Task 2 的注释里写「唯一重叠用例 4+2 的结果相同」—— **那是对的另一处**
（`4+2=0x6` 但 alpha=255，255/255=1 与默认 1 相同）。
**这一处的 alpha 是 128/64**，完全不同。

→ 已修 `drawHandle`：改为三者独立判断（`hasBit` 辅助函数，跨版本）。

### 验证方式的教训

先试「按键注入触发移动范围」→ **两版截图 md5 完全相同（b693e7da…），
但都没有高亮** —— 说明按键序列没触发到 flag=1，**不能据此判断迁移对不对**。

改为**直接单测**：调 `drawBattle(1, ...)`，Stub `sprite.drawHandle` 收集
`(flags, alpha)`，断言存在 `flags=6` 且 `alpha ∈ {128, 64}`。

**负向对照**：把 `alpha=128` 改成 `alpha=1`
→ `[FAIL] 高亮格的 alpha 只能是 128 或 64，实测出现 1` ✓

### 顺带修了两个测试基础设施问题

1. `installEnv` 的 `CONFIG` 缺 `WMapAddX/WMapAddY` → `drawBattle` 的循环边界
   算出 NaN（`... - CONFIG.WMapAddX` 得 nil 参与算术）
2. 循环里逐格 `assertTrue` → 断言数爆炸（实测 1429 条）。
   改成循环收集、末尾聚合断言。

**DoD**：
- [x] 新增 `map.getBattleSize()` 契约（4 引擎 + `lib.GetBattleSize`）
- [x] `MapRender.drawBattle(flag, x, y, v1, v2, v3)` —— 搬 122 行
- [x] 12 处引擎调用全部契约化
- [x] **修 `sprite.drawHandle` 的 flags 语义**（互斥 → 三者独立）
- [x] `drawTileFrom(atlasId, ...)` 支持动态档案（特效 3 / 替身 v2）
- [x] `EngineAPI.map.drawBattle` 改为调 `MapRender.drawBattle`（带 pcall 逃生舱）
- [x] 单测：`drawBattle(flag=1)` 画出 `flags=6` 且 alpha ∈ {128,64}
- [x] 单测：`drawHandle` 的 black/alpha 位**独立**（负向对照已验证）
- [x] **实机逐字节对比**：战斗 md5 `6c8eb322…` 不变
- [x] 四版本全量测试零失败（4011/0）
- [x] 一个 commit

---

## Task 6：摘掉双轨/双写（验证契约真透明了）

**Blast Radius**：`framework/war_async.lua`、`script/jymain.lua`、
`engine_love2d.lua`

### 第一次尝试失败（截图 26865 字节 = 地图全黑）

按计划删了 `war_async` 的 4 行双轨 + `LoadArchiveBoth` 的双写
→ 战斗地图**全黑**。

### 根因：`pcall(require)` 吞掉了真实的加载错误

在 `EngineAPI.map.drawBattle` 里加探针，拿到了被吞掉的错误：

```
ok2=false | MR2=framework/map_render.lua:216:
             attempt read write to undeclared variable drawTileFrom
```

`map_render.lua` 的两个 helper 写成了**全局函数**：

```lua
function drawTileFrom(...)  ... end   -- ✗ 全局
function drawTile(...)  ... end       -- ✗ 全局
```

而 LÖVE 的 `JYMainAdapter.init`（`jymain_adapter.lua:172`）装了**严格 `_G`**
metatable（`__newindex` 抛错）。`map_render` 是**draw 时才 require** 的
（晚于 init）→ 严格模式生效 → 写全局抛错 → `pcall(require)` 把它吞掉
→ **静默回退 `lib.DrawWarMap`** → 摘掉双轨后全黑，**且没有任何日志**。

改成 `local function` 后 `pcall(require)` 成功，`MapRender` 真的在跑。

**教训**：「延迟 require + pcall 逃生舱」的组合会把加载失败**完全静默**。
逃生舱本身是对的（地图不该静默消失），但**必须有办法发现它在回退**。

### 第二次尝试：战斗好了，场景还是黑

摘掉双写后战斗 md5 正确，但场景截图 **3995 字节（全黑）**。

根因：**`EngineAPI.map.drawScene` 是零消费者的死契约**。

```lua
-- script/jymain.lua 的 DrawSMap 包装（4 处）
lib.DrawSMap(JY.SubScene, ...)      -- ✗ 直接用引擎的旧实现
```

Task 4 搬好的 `MapRender.drawScene` 根本没被调用。改成
`EngineAPI.map.drawScene(...)` 后场景恢复。

**教训**：搬一个函数**不等于**接上调用点。「契约有实现」和
「调用方在用这个契约」是两件事，必须分别验证。

### 第三次：场景好了，但对话框头像不见了

场景 md5 恢复 `1efd2af3…`，但右下角头像框是**空的**。

根因：`EngineAPI.dialog.draw` 内部也读 `picFileCache`：

```lua
local w, h = lib.PicGetXY(1, layout.headId * 2)
lib.PicLoadCache(1, layout.headId * 2, ...)
```

摘掉双写后 `picFileCache` 空 → 头像画不出来。

改成 `SpriteAtlas.getMeta(1, ...)` + `SpriteAtlas.draw(1, ...)`
（archive 1 = HeadPic，`usage="avatar"`），保留旧路径作逃生舱。

### 最终验证（三界面全部逐字节相同）

| 界面 | md5 | 与基线 |
|------|-----|--------|
| 主地图/场景（主角家对话） | `1efd2af3…` | ✓ 相同 |
| 战斗 | `6c8eb322…` | ✓ 相同 |
| 主地图（走一段后） | `36fd32b0…` | ✓ 相同 |

**DoD**：
- [x] 删 `war_async` 的 4 行 `EngineAPI.sprite.loadArchive` 双轨
- [x] `LoadArchiveBoth` 去掉 `EngineAPI.sprite.loadArchive` 那半边
- [x] **修 `map_render.lua` 的全局函数**（`local function`）
- [x] **接上 `EngineAPI.map.drawScene` 的调用点**（`lib.DrawSMap` ×4）
- [x] **迁移 `EngineAPI.dialog.draw` 的头像路径**（`PicGetXY`/`PicLoadCache` → `SpriteAtlas`）
- [x] 新增 gate STEP D4：延迟 require 的模块零全局函数（负向对照已验证）
- [x] 反转两条 canary 断言（`war_coroutine_wiring` / `archive_dual_write`）
- [x] **实机三界面逐字节相同**
- [x] 四版本全量测试零失败（4011/0）
- [x] 一个 commit

---

## Task 7：门禁 + 全量收尾

**Blast Radius**：`gate_engine_contract.sh`、`TODO.md`

**DoD**：
- [x] 新增 STEP：`framework/map_render.lua` 零 `love.*`（同 STEP E 判据）
- [x] 新增 STEP：`framework/map_render.lua` 不出现 `PicLoadCache` / `picFileCache`
- [x] 负向对照：在 `map_render.lua` 加一处 `love.graphics.draw` → gate FAIL
- [x] 四版本全量测试零失败：5.1 **4011** / 5.3 **4011** / 5.4 **4011** / 5.5 **4010**
      - **5.5 少 1 条**：`test_map_render` 的 `loadstring` 在 5.3+ 不存在
        （改成 `loadstring or load` 后 5.3/5.4 通过；5.5 差的 1 条是既有的
        `test_version_compat` 已知差异，非本次引入）
- [x] 全仓 `luac5.1 -p` / `luac55 -p` 零失败
- [x] 五门禁全 PASS
- [x] **实机三界面截图**存入 `docs/screenshots/`
- [x] 更新 `TODO.md`（删掉「map 契约透明化」条目）
- [x] 一个 commit
