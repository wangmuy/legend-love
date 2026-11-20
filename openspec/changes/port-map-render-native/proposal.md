# Change Proposal: port-map-render-native — 地图绘制契约透明化

> 父 slice: `engine-portability`
> 前置: `port-contract-pruning` ✓ / `port-blocking-delay` ✓

## Why

`engine_api.lua` 里有 3 个地图绘制契约，但它们的 LÖVE 实现**只是转发**：

```lua
EngineAPI.map.drawMain   = function(...) lib.DrawMMap(...)   end
EngineAPI.map.drawScene  = function(...) lib.DrawSMap(...)   end
EngineAPI.map.drawBattle = function(...) lib.DrawWarMap(...) end
```

而 `lib.DrawMMap` / `DrawSMap` / `DrawWarMap` **内部读 `picFileCache`**
（经 `JY_LoadPic` = `PicLoadCache`）：

```
EngineAPI.map.drawBattle
  → lib.DrawWarMap                        (engine_love2d.lua:302 转发)
     → JY_LoadPic                         (lib_love.lua:582)
        = PicLoadCache                    ← 读 picFileCache
           → picFileCache[fileid]         ← 必须由 PicLoadFile 写入
```

**⇒ 这 3 个契约不是 `.idx/.grp` 透明的**：新引擎要实现它们，必须先实现
`PicLoadFile` / `PicLoadCache` 那套 RLE 解码 + 档案缓存。

这是**当前 slice 最后一个"换引擎必须重写游戏逻辑"的缺口**，也是：

- `war_async` 双轨补丁删不掉的原因（实测：删了战斗地图全黑）
- `LoadArchiveBoth` 双写删不掉的原因（实测：删了开场/主地图全黑）
- 「换引擎只需写 engine-xxx」这个 slice DoD 不成立的最后一块

### 实测规模（这决定这个 change 是可行还是不可行）

| 函数 | 总行数 | 引擎调用行数 | 可移植比例 |
|------|--------|-------------|-----------|
| `DrawMMap` | 79 | 8 | 90% |
| `DrawSMap` | 79 | 8 | 90% |
| `DrawWarMap` | 122 | 12 | 90% |
| `BuildingSort` | 83 | 0 | **100%** |
| `DrawClouds` | ~30 | 2 | 93% |

**363 行里只有 30 行真碰引擎** —— 和 `LoadPic`（124 行里 5 行碰引擎）
是同一个模式。所以搬进 framework 是正确决策，不是硬拆。

### 引擎调用面的完整清单（这 30 行是什么）

| 调用 | 次数 | 可迁移到 |
|------|------|---------|
| `JY_LoadPic(archive, picid, x, y, flag, val)` | 18 | `EngineAPI.sprite.draw`（**签名完全一致**，实测见下） |
| `love.graphics.getScissor()` | 3 | **需要新契约** `render.getClip()` |
| `love.graphics.setScissor(...)` | 3 | `EngineAPI.render.setClip`（已有） |
| `FillColor(0,0,0,0,0)` | 3 | `EngineAPI.render.fillRect`（已有） |
| `GetMMap` / `GetWarMap` | 2 | `EngineAPI.map.getTile`（已有）+ **新契约** |

**`JY_LoadPic` 与 `EngineAPI.sprite.draw` 签名实测一致**：

```lua
function PicLoadCache(fileid, picid, x, y, flag, value)   -- lib_love.lua:528
EngineAPI.sprite.draw = function(archiveId, spriteId, x, y, flags, alpha)
    lib.PicLoadCache(archiveId, spriteId, x, y, flags, alpha)   -- 直接转发
end
```

⇒ 18 处 `JY_LoadPic` 可以**机械替换**成 `EngineAPI.sprite.draw`，零语义风险。

---

## In Scope

### 1. 新增 6 个契约

| 契约 | 替代 | 为什么需要 |
|------|------|-----------|
| `render.getClip()` | `love.graphics.getScissor()` | 3 个绘制函数都用它算循环范围 |
| `map.setTile(x,y,layer,value)` | `lib.SetWarMap` / `SetD` | 战斗移动范围绘制要写地图 |
| `map.getSceneTile(x,y,layer)` | `lib.GetSMap` | `DrawSMap` 读场景 tile |
| `map.setSceneTile(x,y,layer,value)` | 同上 | 动画改 tile（`instruct_27`） |
| `map.getBattleTile(x,y,layer)` | `lib.GetWarMap` | `DrawWarMap` 读战斗 tile |
| `map.setBattleTile(x,y,layer,value)` | `lib.SetWarMap` | 同上 |

### 2. 新建 `framework/map_render.lua`

搬入 363 行投影逻辑，把 30 行引擎调用换成契约：

```
MapRender.drawMain(playerX, playerY, playerPic)      ← 原 lib.DrawMMap
MapRender.drawScene(sceneId, x, y, offX, offY, pic)  ← 原 lib.DrawSMap
MapRender.drawBattle(flag, x, y, v1, v2, v3)         ← 原 lib.DrawWarMap
MapRender.buildingSort(...)                          ← 原 BuildingSort
MapRender.drawClouds(...)                            ← 原 DrawClouds
```

### 3. 切换 3 个绘制契约的实现

```lua
EngineAPI.map.drawMain   = function(...) MapRender.drawMain(...)   end
EngineAPI.map.drawScene  = function(...) MapRender.drawScene(...)  end
EngineAPI.map.drawBattle = function(...) MapRender.drawBattle(...) end
```

**注意**：`engine_love2d.lua` 也不能 `require("framework.map_render")` 吗？
—— **可以**。约束是「framework 不 require engine-*」，反向（engine require
framework）在现有代码里已有先例（`engine_love2d.lua` 用到 `framework` 的
`mod_data` / `input_manager`）。但更干净的做法是**由 framework 侧注入**：
`EventBridge`/`game_states` 调 `MapRender`，`EngineAPI.map.drawMain` 保留为
"引擎可选的加速实现"。

**这一步需要实测确认**（见 Task 3 的验证方式）。

### 4. 摘掉两处双轨/双写

- `war_async` 的 `EngineAPI.sprite.loadArchive` 双轨补丁
- `jymain` 的 `LoadArchiveBoth` 双写

因为 `MapRender` 不再读 `picFileCache`。

---

## Out of Scope

```
✗ lib_love.lua 的 DrawMMap/DrawSMap/DrawWarMap 删除 → 保留（lib.* 兼容层仍在）
✗ PicLoadFile / PicLoadCache 删除 → D（port-native-api-completion）才删
✗ map.loadMain/loadScene/loadBattle 的透明化 → 属 D（加载层，独立）
✗ 地图数据的磁盘格式改造 → 不涉及
```

## 关键度量

| 指标 | 基线（实测） | 目标 |
|------|-------------|------|
| 3 个地图绘制契约是否读 `picFileCache` | **是**（`JY_LoadPic`） | **否** |
| `framework/map_render.lua` 引擎调用数 | 0（新建） | 0 |
| 3 个界面像素 | 正常 | **逐字节相同** |
| `war_async` 双轨补丁 | 2 套 | **1 套** |
| `LoadArchiveBoth` 双写 | 2 套 | **1 套** |

## 风险

| 风险 | 缓解 |
|------|------|
| 投影数学（等距 isometric）搬错一位 → 整张地图错位 | 逐字节截图对比 3 个界面 |
| `BuildingSort` 的深度排序是视觉正确性的关键 | 它的注释里有 2 次回归记录（`2c8a644` 等），**一字不能改** |
| 循环边界的 `CONFIG.MMapAddX/Y` 等常量 | 全部照抄，不改 |
| `DrawClouds` 的时间驱动（云飘动） | 依赖 `EngineAPI.time.getTime`，可迁移 |

## Tracking

| REQ ID | 需求 | 落点 |
|--------|------|------|
| REQ-MRN-1 | 3 个地图绘制契约不读 `picFileCache` | specs/map-render-native/spec.md |
| REQ-MRN-2 | `framework/map_render.lua` 零引擎依赖 | 同上 |
| REQ-MRN-3 | 3 个界面像素逐字节相同 | 同上 |
| REQ-MRN-4 | 双轨/双写可以摘除 | 同上 |
