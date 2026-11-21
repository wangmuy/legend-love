# Tasks: port-legacy-picture-removal

> **策略**：自外向内拆。先删「没有消费者的契约」（可独立验证），
> 再搬云（有真实消费者，需要对拍），最后删 `picFileCache` 本体。
> 任一步失败都能独立回退。

## Task 0：前置核实（只读）

**DoD**：
- [x] `grep -rnE '(EngineAPI|EA)\.sprite\.(draw|drawTinted|loadArchive)\s*\(' game --include=*.lua`
      → 排除 tests 与 engine-* 后为 **0**（本轮已核，见 proposal）
- [x] `grep -rn 'lib\.PicGetXY\|lib\.PicLoadCache' game --include=*.lua` → 只剩
      `engine_love2d.lua` 的 dialog 逃逸舱
- [x] 27808 个事件脚本零 `lib.`（本轮已核）
- [x] 云 9 帧对拍 9/9 SAME（本轮已核）

## Task 1：删 3 个死契约

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`、`tests/engine_test.lua`、`tests/unit/test_engine_api.lua`

**DoD**：
- [x] 删 `M.sprite.draw` / `M.sprite.drawTinted` / `M.sprite.loadArchive` 声明（留 `@deprecated` 指向注释）
- [x] 删 4 引擎实现（LÖVE/MUD/Web/测试桩）
- [x] 删单测存在性断言（改为 `assertNil` + 旧的 `drawTinted` 用例改测 `drawHandleTinted`）；
      契约数 92 → **89**
- [x] 全量测试零失败（4007，比 4013 少 6 = 删掉的 3 个旧契约断言 + 合并的旧用例）
- [x] 一个 commit

## Task 2：dialog 头像逃逸舱改显式降级

**Blast Radius**：`game/engine-love2d/engine_love2d.lua`

**DoD**：
- [x] `dialog.draw` 的 `else` 分支删掉 `lib.PicGetXY` / `lib.PicLoadCache`，
      改为「记日志 + 不画头像」
- [x] `lib.PicGetXY` / `lib.PicLoadCache` 已清零（剩 `lib.PicInit` 两处，归 Task 6）
- [x] 实机：开场对话头像仍在右下框内（场景 md5 `1efd2af3…` 不变）
- [x] 一个 commit

## Task 3：新建 `framework/cloud_layer.lua` 并对拍

**Blast Radius**：`game/framework/cloud_layer.lua`（新）、`game/tests/unit/test_cloud.lua`

**DoD**：
- [ ] `CloudLayer.load(idxFile, grpFile)`：走 `SpriteDecoder.parseIdx` + `decodeRLE`
- [ ] `CloudLayer.bakeRGBA(frame, mixR, mixG, mixB, mixAlpha)` → `string`（w*h*4 字节）
      公式逐字：`(mixAlpha*mix + (100-mixAlpha)*pix)/100`
- [ ] `CloudLayer.create(count)`：60 朵，随机**顺序**逐字保留
      （`Picnum → Alpha → mixR → mixG → mixB → mixAlpha → Positiony → Speedx → Positionx`）
- [ ] `CloudLayer.tick(nowMs)`：40ms 窗口 + 越界重生
- [ ] `CloudLayer.draw(mx, my)`：屏幕坐标公式逐字搬 + `drawHandle` alpha =
      `(100-Alpha)/100 * 255`
- [ ] `CloudLayer.getList()`（替代 `lib.CloudGetList`，供测试）
- [ ] 单测：9 帧对拍（`{w, h, xoff, yoff, 非透明像素数}` 与旧值相同，硬编码期望值）
- [ ] 单测：固定 seed 下 60 朵云字段与旧实现逐字段相同
- [ ] 单测：40ms tick 节奏 + 越界重生
- [ ] 一个 commit

## Task 4：三契约改转发 + 删 `lib_love` 云实现

**Blast Radius**：`game/engine-love2d/engine_love2d.lua`、`game/engine-love2d/lib_love.lua`

**DoD**：
- [ ] `map.loadClouds` / `map.tickClouds` / `map.drawClouds` 改转发 `CloudLayer`
- [ ] 删 `lib_love.lua:1177-1387` 的云块（`CLOUD_AMOUNT`/`CLOUD_SLOT`/
      `CloudDecodeFrame`/`CloudBakeImage`/`CloudCreateOnSide`/`CloudCreate`/
      `CloudLoadAndInit`/`CloudTick`/`DrawClouds`/`CloudGetList`）
- [ ] `test_cloud.lua` 改走 `CloudLayer`（不再 `require lib_love`）
- [ ] 实机：主地图有云、漂移、`MMAPAMI=0` 时停（截图 + 目视）
- [ ] 一个 commit

## Task 5：删 3 个地图绘制逃生舱

**Blast Radius**：`game/engine-love2d/engine_love2d.lua`

**DoD**：
- [ ] `drawMain/drawScene/drawBattle` 的 fallback 分支改为
      `EngineAPI.debug.log(...)` + `error("framework.map_render missing: " .. tostring(err))`
- [ ] 删 `lib.DrawMMap/DrawSMap/DrawWarMap` 的调用
- [ ] 单测：把 `map_render` 改名后调用 `map.drawMain` → 抛错
- [ ] 实机三界面正常（无回归）
- [ ] 一个 commit

## Task 6：删 `lib_love` 旧贴图子系统（最大一步）

**Blast Radius**：`game/engine-love2d/lib_love.lua`、`game/engine-love2d/engine_love2d.lua`

**DoD**：
- [ ] 删 `lib_love.lua:233-683`（`LoadPallette`/`PicInit`/`picFileCache`/`PicCache`/
      `PicFile`/`LoadPic`/`PicLoadFile`/`PicGetXY`/`PicLoadCache`/`JY_LoadPic`/
      `DrawPicTinted`/`LoadPicture`/`pictureCache`/`ClearPictureCache`）
- [ ] 删 `lib_love.lua:1075-1193`（`DrawMMap`）
- [ ] 删 `lib_love.lua:1502-1584`（`DrawSMap`）
- [ ] 删 `lib_love.lua:1666-1790`（`DrawWarMap`）
- [ ] `engine_love2d.lua`：删旧 `EngineAPI.PicInit` / `EngineAPI.ShowSurface` /
      `EngineAPI.ShowSlow` / `EngineAPI.LoadPicture` 4 个偷渡键（非契约）
- [ ] `sprite.initSprites` 改走 `SpriteDecoder.loadPalette`（不再 `lib.PicInit`）
- [ ] `sprite.clearPictureCache` 改清 `_picCache`
- [ ] `grep -nE 'LoadPic|PicLoad|PicGetXY|PicInit|picFileCache|palletteIdx' lib_love.lua`（非注释）= 0
- [ ] 全量测试零失败；三界面截图；`luac5.1 -p` / `luac55 -p` 零失败
- [ ] 一个 commit

## Task 7：门禁 + 文档

**Blast Radius**：`game/tests/gate_engine_contract.sh`、`openspec/project/TODO.md`、
`openspec/changes/engine-portability/change-manifest.md`、`docs/screenshots/README.md`

**DoD**：
- [ ] STEP D 删除「`lib_love.LoadPic` 仍存在」的说明段；
      判据改为「4 引擎（含 engine-love2d）零 RLE 解码特征」
- [ ] 新增 STEP J：`lib_love.lua` 零 `LoadPic|PicLoad|PicGetXY|picFileCache`
- [ ] 负向对照：往 `lib_love.lua` 加一处 `PicLoadCache` → gate FAIL
- [ ] 更新 `TODO.md`：删「`lib_love.LoadPic` 119 行 + 兼容层用途」条目
- [ ] 更新 `change-manifest.md`：`port-native-api-completion` 的说明里
      「119 行删不掉」改为「已由 port-legacy-picture-removal 拆除」
- [ ] 更新 `docs/screenshots/README.md`：加 item-menu / item-grid / person-status 基线
- [ ] 五门禁 + 全量测试
- [ ] 一个 commit

## 依赖

```
Task 1 (删死契约) ──┐
Task 2 (dialog)    ──┼──▶ Task 5 (删逃生舱) ──▶ Task 6 (删子系统)
Task 3 (云搬)      ──┘                          │
Task 4 (云接线) ─────────────────────────────────┘
                                                ▼
                                          Task 7 (门禁+文档)
```

- Task 1/2/3 可并行（改不同文件）
- Task 6 **必须**在 1/2/5 之后：先摘掉所有入口，再删本体
- Task 4 依赖 Task 3
