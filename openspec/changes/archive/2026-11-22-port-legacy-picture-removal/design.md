# Design: port-legacy-picture-removal

## ADR-PORT-018：事件脚本的调用面**恰好**是 `instruct_0..67`，故「删旧贴图」无脚本风险

### Context

`engine-portability` 从 `port-contract-completeness` 开始就记着一条「删不掉」的理由：

> `lib_love.lua` 的 `LoadPic` 119 行 RLE 解码删不掉 —— 因为 `PicLoadFile`
> 还被 `lib.*` 调用方依赖，而 `lib.*` 又被 2000 个 oldevent 数据文件依赖。

本轮（2026-11-21）对**全部 27808 个事件脚本**（1018 基础 + 20 MOD 的 26790）
做了 4 组独立扫描：

```lua
-- 扫描 1：子串 "lib"      → 0
-- 扫描 2：lib.xxx( 调用    → 0
-- 扫描 3：绘制/音频全局    → 0（DrawString/Cls/ShowScreen/WaitKey/TalkEx/PlayMIDI/…）
-- 扫描 4：所有 ( 调用名    → 只有 instruct_0..67（67 个，无 7）
```

基础与 20 个 MOD 的 instruct 集合**完全相同**（都是那 67 个 id）。
事件数据层是**纯指令序列**，不含任何引擎 API。

### Decision

「事件脚本依赖 `lib.*`」这个前提**不成立**。旧贴图子系统的删除不需要
先改任何事件脚本。它不是「2000 个数据文件要改」，而是**零文件要改**。

### Consequences

**Positive**

- `port-legacy-picture-removal` 不再被一个不存在的前置阻塞
- 后续任何「脚本兼容层」的判断都应以实测调用面为准，不以文档陈述为准

**Negative**

- 需要重写 4 份 openspec 文档里的错误前提（本 change 的 Task 6）

## ADR-PORT-019：`sprite.draw` / `drawTinted` / `loadArchive` 是死契约，删而非留

### Context

`grep` 实测（2026-11-21，排除注释与 tests）：

```
EngineAPI.sprite.draw           → 0 处调用
EngineAPI.sprite.drawTinted     → 0 处调用
EngineAPI.sprite.loadArchive    → 0 处调用
```

`port-native-api-completion` 把 `script/` 的 `lib.Pic*` 全迁到 `SpriteAtlas`
（`framework/sprite_atlas.lua`，走 `createFromRGBA` / `drawHandle`），
所以这 3 个「按 archiveId + picid 画」的旧契约彻底没人用了。

### Decision

删除这 3 个契约（含 4 引擎实现与单测存在性断言）。

**理由**：它们不是「暂时没人用」，而是**新链路已经完全替代**：

| 维度 | `sprite.draw(archiveId, picid, …)` | `SpriteAtlas.draw(atlasId, frameId, …)` |
|------|-----------------------------------|-----------------------------------------|
| 引擎需要什么 | 解析 `.idx/.grp` + 维护 `picFileCache` + RLE 解码 | 只收 handle |
| 谁解析容器 | 引擎 | framework |
| 谁解码 RLE | 引擎 | framework |
| 新引擎实现成本 | 重写 425 行 | 实现 `createFromRGBA`（5 行） |

留着它们是 ADR-PORT-013 要消除的形态。删掉后 `PicLoadFile`/`PicLoadCache`
的唯一入口消失 → 整条 `picFileCache` 链可以拆。

### Alternatives considered

| 方案 | 否决理由 |
|------|---------|
| 保留为 `@deprecated` | 死契约会误导新引擎实现者「必须支持两种贴图 API」（`port-contract-pruning` 已记录同类教训） |
| 保留但实现改为转 `SpriteAtlas` | 契约语义是「引擎持有 archive 表」，转接后引擎仍要知道 frameId→slot 映射，等于把容器约定塞回引擎 |

## ADR-PORT-020：云层归 framework，引擎只收 RGBA 字节

### Context

云子系统（`lib_love.lua:1194-1382`，约 190 行）当前全在引擎里：

| 逻辑 | 性质 |
|------|------|
| `CloudDecodeFrame`（行内状态机 RLE 解码） | **纯数据处理** |
| `CloudBakeImage`（逐像素 mix 烘焙） | **纯数据处理**（只最后 1 行 `newImage` 碰引擎） |
| `CloudCreateOnSide` / `CloudCreate`（60 朵随机字段） | **纯逻辑**（`math.random`） |
| `CloudTick`（40ms 右移 + 越界重生） | **纯逻辑** |
| `DrawClouds`（屏幕坐标公式 + setColor alpha） | **纯数学**（最后 1 行 `love.graphics.draw` 碰引擎） |

190 行里只有 2 行碰引擎（`newImage` / `draw`）。

**关键实测**：`CloudDecodeFrame` 的注释声称「与 `LoadPic` 的成对解码不同，
状态机能正确处理行尾 trailing skip」，暗示两种解码在云数据上会不同。
本轮用真实 `cloud.grp`（9 帧）逐帧对拍：

```
slot 1: 126x22 state=1619 pair=1619 SAME
slot 2: 142x44 state=3441 pair=3441 SAME
slot 3: 135x37 state=3080 pair=3080 SAME
slot 4:  58x22 state= 790 pair= 790 SAME
slot 5..8: 同 1..4 的重复            SAME
slot 9: 250x250 state=17864 pair=17864 SAME
```

9/9 一致（尺寸/xoff/yoff/非透明像素数）。⇒ `SpriteDecoder.decodeRLE` 可直接用。

### Decision

新建 `framework/cloud_layer.lua`，把 190 行搬进 framework：
解码走 `SpriteDecoder.decodeRLE`，烘焙用 `string.char` 拼 RGBA 字节，
绘制走 `EngineAPI.sprite.drawHandle`（`createFromRGBA` 造 handle）。

引擎侧 `map.loadClouds/tickClouds/drawClouds` 只做转发到 framework。

**随机调用顺序必须逐字保留**（否则云位置与旧版不同）：

```
CloudCreateOnSide: Picnum → Alpha → mixR → mixG → mixB → mixAlpha → Positiony → Speedx
CloudCreate:       再 Positionx
```

### Alternatives considered

| 方案 | 否决理由 |
|------|---------|
| 保留云在引擎里（它是「引擎子系统」） | 换引擎要重写 190 行 = slice 的目标未达成 |
| 云走 `SpriteAtlas`（同贴图路径） | 云是「每帧一张图 + 逐像素混色」，与静态帧语义不同；`SpriteAtlas` 的 `usage`/锚点约定不适用 |

### Consequences

**Positive**

- 引擎侧只剩「上传 RGBA」+「画 handle」两个已有契约
- 云帧解码复用 `sprite_decoder`，减少一套 RLE 实现

**Negative**

- 每朵云要 `createFromRGBA` 一次（60 次/加载时，旧版也是 60 次 `newImage`）
- 云的 `setColor(1,1,1,(100-Alpha)/100)` 语义必须搬对（`drawHandle` 的 alpha 参数是 0-255，不是 0-1）

## ADR-PORT-021：`DrawMMap/DrawSMap/DrawWarMap` 逃生舱改 `error`

### Context

`engine_love2d.lua:390-438` 三个契约都有这样的 fallback：

```lua
local ok, MR = pcall(require, "framework.map_render")
if ok and MR and MR.drawMain then MR.drawMain(...); return end
EngineAPI.debug.log("map.drawMain: framework.map_render unavailable, falling back to lib.DrawMMap")
lib.DrawMMap(...)
```

### Decision

改为显式失败：写日志 + `error`。

**理由**：这个 fallback 掩盖的是「`.love` 打包漏了 `map_render.lua`」，
而旧实现的输出与新版**并不逐像素相同**（`port-map-render-native` 记录过
`drawHandle` 与 `PicLoadCache` 的 flag 位语义差异，所以专门修了 `drawHandle`）。
静默回退会让玩家看到「有点不对但没崩」的画面，比崩溃更难查。

## Negative Constraints

- **不得**删除 `lib_love.lua` 里的 map 数据读写（`GetMMap/SetMMap/JY_SetMMap`）
- **不得**改动云的常量（`CLOUD_AMOUNT=60` / `40ms` / `mixAlpha=10..59` / `CLOUD_WORLD_X/Y`）
- **不得**让 `sprite.initSprites` 变成 no-op —— 调色板必须真的加载
- **不得**保留 `picFileCache` 作为「兼容残留」；要删干净

## Review Checklist

- [ ] `grep -nE 'LoadPic|PicLoad|PicGetXY|picFileCache|palletteIdx' lib_love.lua`（非注释）= 0
- [ ] `lib_love.lua` 行数从 1795 降到约 1370
- [ ] 云 9 帧对拍测试进单测（`test_cloud.lua` 改走 framework）
- [ ] `clearPictureCache` 真的清 `_picCache`（写单测锁定）
- [ ] 三界面截图：场景/战斗 md5 不变；主地图目视正常
- [ ] 门禁 STEP D 的 `engine-love2d` 豁免注释可以删掉
