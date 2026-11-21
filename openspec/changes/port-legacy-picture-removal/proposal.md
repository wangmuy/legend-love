# Change Proposal: port-legacy-picture-removal — 拆除 `lib_love` 旧贴图子系统

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）
> 前置: `port-map-render-native` ✓ / `port-sprite-native-migration` ✓ /
> `port-native-api-completion` ✓ / `port-compat-layer-removal`（需先做，否则 `_G.lib` 删除会崩）

## Why

`engine-portability` slice 的最后一块遗留：`lib_love.lua` 里 425 行旧贴图子系统
（`LoadPic` 119 行 RLE 解码 + `PicInit/PicLoadFile/PicGetXY/PicLoadCache/DrawPicTinted`
+ `LoadPicture/ClearPictureCache`），以及依赖它的 3 个地图绘制函数
（`DrawMMap/DrawSMap/DrawWarMap`，共 363 行）。

slice 早就记录了「删不掉」的理由：**oldevent 脚本需要 `lib.*`**。

**本轮实测推翻了它**：

| 探测 | 结果 |
|------|------|
| `game/script/oldevent/*.lua`（1018）含 `lib.` | **0** |
| `game/mods/*/script/oldevent/*.lua`（26790）含 `lib.` | **0** |
| 事件脚本里的全局调用面 | **只有 `instruct_0..67`**（67 个，缺 7） |

事件数据层**从不调 `Pic*`/`LoadPicture`/`lib.*`**。它只调 `instruct_*`。

### 那今天还有谁在用旧贴图子系统？

`grep` 逐项实测（排除注释）：

| 旧函数 | 现在的调用点 | 性质 |
|--------|-------------|------|
| `LoadPic` | 只被 `PicFile:getPic` 调 | 子系统内部 |
| `PicInit` | `engine_love2d:102`（`sprite.initSprites`）+ `:1133`（旧 `EngineAPI.PicInit`） | 引擎内部 |
| `PicLoadFile` | `engine_love2d:107`（`sprite.loadArchive`） | **契约仍在，但零消费者**（见下） |
| `PicGetXY` / `PicLoadCache` | `engine_love2d:110`（`sprite.draw`）+ `:1066/1069`（dialog 头像逃逸舱） | 契约零消费者 + 逃逸舱 |
| `DrawPicTinted` | `engine_love2d:115`（`sprite.drawTinted`） | 契约零消费者 |
| `LoadPicture` / `ClearPictureCache` | `engine_love2d:1145`（旧 `EngineAPI.LoadPicture`）/ `:218`（`clearPictureCache`） | 前者零消费者；后者 `jymain.lua:296` 在调 |
| `DrawMMap/DrawSMap/DrawWarMap` | `engine_love2d:390-438` 的**三处逃生舱 fallback** | 只在 `framework/map_render` 加载失败时用 |
| 云子系统（`CloudDecodeFrame`/`BakeImage` 等） | `map.loadClouds/tickClouds/drawClouds` | **活的，必须保留**（但可搬 framework） |

### 关键实测一：契约层的贴图旧接口**已经没有消费者**

```bash
$ grep -rnE '(EngineAPI|EA)\.sprite\.(draw|drawTinted|loadArchive)\s*\(' \
    game --include=*.lua | grep -v /tests/ | grep -v engine-
game/framework/sprite_anim.lua:9:  --   EngineAPI.sprite.draw(...)      ← 注释
game/framework/sprite_atlas.lua:42: --   现有代码里 EngineAPI.sprite.draw(...) ← 注释
```

**0 处真实调用**。`script/` 已全走 `SpriteAtlas`（`framework/sprite_atlas.lua`
→ `sprite.createFromRGBA` / `drawHandle`，引擎不再解析 `.idx/.grp`）。
所以 `sprite.draw` / `sprite.drawTinted` / `sprite.loadArchive` 是
**`port-native-api-completion` 留下的死契约**，它们是 `loadArchive`→`PicLoadFile`
→`LoadPic` 这条链**唯一的还活着的入口**。

### 关键实测二：云帧用 framework 解码器得到**完全相同**的结果

`lib_love` 的 `CloudDecodeFrame` 用的是「行内状态机」解码（注释声称
「与 `LoadPic` 的成对解码不同，状态机能正确处理 trailing skip」）。
本轮用真实 `cloud.grp`（9 帧）逐帧对比两种解码：

```
slot 1: 126x22 state=1619 pair=1619 SAME
slot 2: 142x44 state=3441 pair=3441 SAME
...
slot 9: 250x250 state=17864 pair=17864 SAME
```

**9/9 完全一致**（尺寸、xoff/yoff、非透明像素数全部相同）。
所以云解码可以搬 `framework/sprite_decoder.lua`，不需要保留一份引擎侧状态机。

### 关键实测三：`clearPictureCache` 清错了缓存

```lua
EngineAPI.sprite.clearPictureCache = function()
    lib.ClearPictureCache()      -- 清 lib_love 的 pictureCache（local 表）
end
```

而 `drawPictureFile`（真正在用的整图绘制）用的是
`EngineAPI.sprite._picCache`（`engine_love2d.lua:188-191`）——
**两张不同的表**。`jymain.lua:296` 调 `clearPictureCache()` 想清整图缓存，
实际清的是另一张表，`_picCache` 纹丝不动。这是活体缺陷。

## In Scope

1. **删 `sprite.draw` / `sprite.drawTinted` / `sprite.loadArchive` 3 个死契约**
   （`engine_api.lua` 声明 + 4 引擎实现 + 单测存在性断言）
2. **dialog 头像逃逸舱改为唯一路径**（`SpriteAtlas` 不可用时**不画**而不是走旧链），
   删掉 `engine_love2d:1066/1069` 的两处 `lib.PicGetXY/PicLoadCache`
3. **云子系统搬 framework**：
   - `framework/cloud_layer.lua`（新）：解码（用 `sprite_decoder`）+ 烘焙 + 60 朵漂移 + 绘制位置算法
   - 引擎只保留 `cloud.bakeTexture(w, h, rgbaBytes)`（= `sprite.createFromRGBA` 复用）
   - `map.loadClouds/tickClouds/drawClouds` 三契约保留但改实现
4. **删 `DrawMMap/DrawSMap/DrawWarMap` 三个逃生舱**（改 `error` 而不是静默回退到
   引擎内部的旧实现 —— 静默回退掩盖的是「framework 文件漏打包」，应显式报错）
5. **删 `lib_love` 的旧贴图子系统**（425 行）：
   `LoadPallette` / `PicInit` / `picFileCache` / `PicCache` / `PicFile` / `LoadPic` /
   `PicLoadFile` / `PicGetXY` / `PicLoadCache` / `JY_LoadPic` / `DrawPicTinted` /
   `LoadPicture` / `pictureCache` / `ClearPictureCache`
6. **`sprite.initSprites(paletteFile)` 自给自足**：不再 `lib.PicInit`，
   调色板改走 `SpriteDecoder.loadPalette`（`SpriteAtlas` 已有该路径）
7. **修 `clearPictureCache` 的目标表**（清 `_picCache`）
8. **补齐 `sprite.drawPictureFile` 的缓存语义**：把 `_picCache` 变成正式契约的一部分
   （写进 `engine_api.lua` 注释），`clearPictureCache` 明确清它

## Out of Scope

```
✗ 删除 lib_love.lua 整文件（它还有 map 数据读写 / input / audio / 字体度量 / DrawStr 等）
✗ 云层的随机数语义改动（60 朵 / 40ms / mix 公式全部不动）
✗ `sprite.createFromRGBA` / `drawHandle` 的任何改动（那是新链路，已验证）
✗ Web/MUD 引擎的 sprite 实现（它们本来就空实现）
```

## Acceptance Criteria

### Scenario: 3 个死契约消失

- **WHEN** 执行 `grep -n 'sprite.draw\b\|sprite.drawTinted\|sprite.loadArchive' game/engine-love2d/engine_api.lua`
- **THEN** 命中数 = 0

### Scenario: `lib_love` 不再有贴图解码

- **WHEN** 执行 `grep -nE 'LoadPic|PicLoadCache|PicLoadFile|PicGetXY|picFileCache|palletteIdx' game/engine-love2d/lib_love.lua`
- **THEN** 命中数 = 0（注释除外）

### Scenario: 门禁 STEP D 的豁免注释可以删

- **WHEN** 运行 `gate_engine_contract.sh`
- **THEN** STEP D 不再需要「`LoadPic` 仍存在」的说明段；D 判据对 `engine-love2d` 也生效

### Scenario: 云层零回归（9 帧逐像素）

- **GIVEN** 真实 `cloud.grp`
- **WHEN** 用新 `framework/cloud_layer.lua` 解码 9 帧
- **THEN** 与旧 `CloudDecodeFrame` 的 `{w, h, xoff, yoff, 非透明像素数}` 完全一致

### Scenario: 主地图截图

- **WHEN** 用 `docs/screenshots/README.md` 的 `main-map-after-walk` 参数截图
- **THEN** 目视与基线一致（云随机，md5 不可比）；场景/战斗 md5 不变

## 风险

| 风险 | 缓解 |
|------|------|
| 删 `picFileCache` 后某处漏改 → 运行时 `attempt to index nil` | 分两批：先删契约与消费者，再删 `picFileCache`；每批跑全量测试 |
| 云搬 framework 后随机数顺序变化 → 云位置不同 | 随机调用**顺序**逐字保留（`Picnum`→`Alpha`→`mixR/G/B`→`mixAlpha`→`Positiony`→`Speedx`） |
| `DrawMMap` 逃生舱改 error 后，打包漏 `map_render.lua` 会直接崩 | 这正是目的；门禁新增「`.love` 必须含 `map_render.lua`」检查 |
| 调色板路径改动（`lib.PicInit`→`SpriteDecoder.loadPalette`）导致颜色偏 | 两者都是 `×4` 放大；单测逐字节对比 256 项 |
