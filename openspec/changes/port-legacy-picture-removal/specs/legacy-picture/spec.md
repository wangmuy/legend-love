# 旧贴图子系统拆除

## ADDED Requirements

### Requirement: REQ-LPR-1 3 个死契约 SHALL 被删除

`EngineAPI.sprite.draw` / `sprite.drawTinted` / `sprite.loadArchive`
SHALL 从 `engine_api.lua` 及 4 个引擎实现中删除。

依据（实测 2026-11-21）：三者在 `game/framework`、`game/script`、`game/main.lua`
的**代码行调用数 = 0**（仅注释提及）。`script/` 已全走
`framework/sprite_atlas.lua`（`createFromRGBA` + `drawHandle`）。

#### Scenario: 声明消失

- **WHEN** 执行 `grep -nE 'M.sprite.(draw|drawTinted|loadArchive)' game/engine-love2d/engine_api.lua`
- **THEN** 命中数 = 0

#### Scenario: 实现消失

- **WHEN** 执行 `grep -nE 'EngineAPI.sprite.(draw|drawTinted|loadArchive)'` 于 3 个引擎实现
- **THEN** 命中数 = 0

#### Scenario: 单测同步

- **WHEN** 运行 `test_engine_api.lua`
- **THEN** 不再断言这 3 个契约存在；契约计数同步下调

### Requirement: REQ-LPR-2 dialog 头像 SHALL NOT 走旧 `lib.Pic*` 逃逸舱

`engine_love2d.lua` 的 `dialog.draw` 在 `SpriteAtlas` 不可用时
当前退回 `lib.PicGetXY` / `lib.PicLoadCache`。该分支 SHALL 改为「不画头像 + 记日志」。

依据：`SpriteAtlas` 不可用意味着 framework 模块缺失，退回旧链只会让
「换引擎仍要重写 RLE 解码」这件事看起来成立。

#### Scenario: 无 lib.Pic* 调用

- **WHEN** 执行 `grep -nE 'lib\.Pic(GetXY|LoadCache)' game/engine-love2d/engine_love2d.lua`
- **THEN** 命中数 = 0

#### Scenario: 头像仍能画

- **GIVEN** 正常启动
- **WHEN** 触发任意带头像的对话
- **THEN** 头像显示在右下角框内（实机截图）

### Requirement: REQ-LPR-3 云子系统 SHALL 搬入 framework

新建 `framework/cloud_layer.lua`，承载：帧解码、逐像素 mix 烘焙、
60 朵云随机字段、40ms 漂移、屏幕坐标公式。
引擎侧 `map.loadClouds` / `map.tickClouds` / `map.drawClouds` 只转发。

**解码 SHALL 复用 `SpriteDecoder.decodeRLE`**。依据：真实 `cloud.grp` 9 帧
与旧状态机解码逐帧对拍 9/9 完全一致（尺寸/xoff/yoff/非透明像素数）。

#### Scenario: 9 帧逐像素对拍

- **GIVEN** 真实 `game/data/cloud.idx` + `cloud.grp`
- **WHEN** 用 `framework/cloud_layer.lua` 解码全部帧
- **THEN** 每帧 `{w, h, xoff, yoff, 非透明像素数}` 与旧 `CloudDecodeFrame` 相同

#### Scenario: 随机顺序不变

- **GIVEN** 固定 `math.randomseed`
- **WHEN** 初始化 60 朵云
- **THEN** 每朵云的 `{Picnum, Alpha, mixR, mixG, mixB, mixAlpha, Positionx, Positiony, Speedx}`
      与旧实现逐字段相同

#### Scenario: 漂移节奏不变

- **WHEN** 以 40ms 为窗口推进 `tickClouds`
- **THEN** 每朵云每窗口右移 `Speedx`(1..3)，越界后 `Positionx=0` 重生

### Requirement: REQ-LPR-4 地图绘制逃生舱 SHALL 改为显式失败

`EngineAPI.map.drawMain/drawScene/drawBattle` 在 `framework/map_render` 不可用时
SHALL NOT 回退到 `lib.DrawMMap/DrawSMap/DrawWarMap`；SHALL 记日志并 `error`。

依据：旧实现的 `PicLoadCache` flag 位语义与新 `drawHandle` 不同
（`port-map-render-native` 为此专门修过 `drawHandle` 的互斥判断），
静默回退会产生「有点不对但不崩」的画面，比崩溃更难定位。

#### Scenario: 缺模块时显式报错

- **GIVEN** 把 `framework/map_render.lua` 改名
- **WHEN** 调用 `EngineAPI.map.drawMain(0, 0, 0)`
- **THEN** 抛错（不是静默画一张旧版地图）

### Requirement: REQ-LPR-5 `lib_love` 旧贴图子系统 SHALL 被删除

SHALL 删除：`LoadPallette`（若已被 `SpriteDecoder` 取代）、`PicInit`、
`picFileCache`、`PicCache`、`PicFile`、`LoadPic`、`PicLoadFile`、`PicGetXY`、
`PicLoadCache`、`JY_LoadPic`、`DrawPicTinted`、`LoadPicture`、`pictureCache`、
`ClearPictureCache`。

#### Scenario: 静态检查

- **WHEN** 执行
      `grep -nE 'LoadPic|PicLoad|PicGetXY|PicInit|picFileCache|palletteIdx|DrawPicTinted|ClearPictureCache' game/engine-love2d/lib_love.lua`
      （排除注释）
- **THEN** 命中数 = 0

#### Scenario: 行数下降

- **WHEN** 统计 `lib_love.lua`
- **THEN** 从 1795 行降到约 1370 行（±50）

### Requirement: REQ-LPR-6 调色板 SHALL 由 framework 加载

`sprite.initSprites(paletteFile)` SHALL 不再调 `lib.PicInit`；
调色板 SHALL 由 `SpriteDecoder.loadPalette`（`×4` 放大到 0..255）加载，
并在 `SpriteAtlas` 加载档案时传入。

#### Scenario: 逐字节等价

- **GIVEN** 真实 `mmap.col`
- **WHEN** 分别用旧 `LoadPallette` 与 `SpriteDecoder.loadPalette` 解析
- **THEN** 256 项的 `{r,g,b}` 完全一致

#### Scenario: 场景贴图不偏色

- **WHEN** 实机截图场景界面
- **THEN** md5 与基线 `1efd2af3…` 相同

### Requirement: REQ-LPR-7 `clearPictureCache` SHALL 清真正在用的缓存

`EngineAPI.sprite.clearPictureCache` 当前清的是 `lib_love` 的 `pictureCache`
（旧表，已无写入方），而 `drawPictureFile` 用的是 `EngineAPI.sprite._picCache`。
SHALL 改为清 `_picCache`，并把该缓存语义写进 `engine_api.lua` 注释。

#### Scenario: 清后重载

- **GIVEN** 已 `drawPictureFile("data/dead.png")`
- **WHEN** 调 `clearPictureCache()` 后再次 `drawPictureFile`
- **THEN** 重新从磁盘加载（用桩引擎断言 `newImage` 调用次数 = 2）

## Out of Scope

- `lib_love.lua` 的其它子系统（map 数据 / input / audio / font / DrawStr）
- Web/MUD 引擎的 sprite 空实现
- 云层的视觉参数调整
