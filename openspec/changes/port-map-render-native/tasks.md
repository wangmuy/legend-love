# Tasks: port-map-render-native

> **策略**：先把 6 个新契约加到 4 个引擎（低风险、可独立验证），
> 再搬 363 行投影逻辑（高风险、必须逐字节截图）。
> 每个 Task 一个 commit，任何一步失败都能回退。

## Task 1：加 6 个新契约（4 引擎）

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`、`tests/engine_test.lua`、`tests/unit/test_engine_api.lua`

**DoD**：
- [x] `render.getClip()` —— 返回 `{x, y, w, h}`（LÖVE: `love.graphics.getScissor()`）
- [x] ~~`map.setTile(x, y, layer, value)`~~ —— **删掉了**：主地图是只读静态资源
      （`SetMMap` 是 `lib_love.lua` 的 local 函数，外部调不到），
      `DrawMMap` 只读。加它就是"加了没有消费者的契约"，违反约束
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
- [x] 契约数 76 → **84**（加了 8 个，删掉 1 个 setTile）
- [x] 单测：每个新契约在 4 个引擎都存在（`assertNotNil`）
- [x] 四版本全量测试零失败
- [x] 一个 commit

---

## Task 2：搬 `BuildingSort` + `DrawClouds`（零/低引擎调用）

**Blast Radius**：`framework/map_render.lua`（新建）

**DoD**：
- [ ] `MapRender.buildingSort(x, y, mypic)` —— **逐字搬移** `lib.BuildingSort`（83 行）
- [ ] `MapRender.drawClouds(x, y)` —— 搬 `lib.DrawClouds`，时间源改 `EngineAPI.time.getTime`
- [ ] 两者都用 `EngineAPI.map.getTile` 取地图数据
- [ ] `framework/map_render.lua` 零 `love.*`、零 `require("engine-*")`
- [ ] 单测：`buildingSort` 的排序结果与 `lib.BuildingSort` 一致（同样的输入 → 同样的顺序）
- [ ] 四版本全量测试零失败
- [ ] 一个 commit

---

## Task 3：搬 `drawMain`（原 `lib.DrawMMap`）

**Blast Radius**：`framework/map_render.lua`、`engine_love2d.lua`

**DoD**：
- [ ] `MapRender.drawMain(x, y, mypic)` —— 搬 79 行
- [ ] 8 处引擎调用全部契约化：
      `love.graphics.getScissor` → `EngineAPI.render.getClip`
      `love.graphics.setScissor` → `EngineAPI.render.setClip`
      `FillColor` → `EngineAPI.render.fillRect`
      `JY_LoadPic` → `EngineAPI.sprite.draw`
      `GetMMap` → `EngineAPI.map.getTile`
- [ ] `EngineAPI.map.drawMain` 改为调 `MapRender.drawMain`
- [ ] **保留** `lib.DrawMMap`（`lib.*` 兼容层仍有人用）
- [ ] 单测：`MapRender.drawMain` 不调 `love.*`、不读 `picFileCache`
- [ ] **实机逐字节对比**：主地图截图与迁移前 md5 相同
- [ ] 四版本全量测试零失败
- [ ] 一个 commit

---

## Task 4：搬 `drawScene`（原 `lib.DrawSMap`）

**Blast Radius**：同上

**DoD**：
- [ ] `MapRender.drawScene(sceneId, x, y, offX, offY, mypic)` —— 搬 79 行
- [ ] 8 处引擎调用契约化（同上）
- [ ] `EngineAPI.map.drawScene` 改为调 `MapRender.drawScene`
- [ ] 单测：不调 `love.*`、不读 `picFileCache`
- [ ] **实机逐字节对比**：主角家开场场景截图与迁移前 md5 相同
- [ ] 四版本全量测试零失败
- [ ] 一个 commit

---

## Task 5：搬 `drawBattle`（原 `lib.DrawWarMap`，122 行，最复杂）

**Blast Radius**：同上

**DoD**：
- [ ] `MapRender.drawBattle(flag, x, y, v1, v2, v3)` —— 搬 122 行
- [ ] 12 处引擎调用契约化（含 `JY_LoadPic(v2,v1,...)` 这种动态 archive）
- [ ] `EngineAPI.map.drawBattle` 改为调 `MapRender.drawBattle`
- [ ] 单测：不调 `love.*`、不读 `picFileCache`
- [ ] **实机逐字节对比**：战斗画面截图与迁移前 md5 相同
- [ ] 四版本全量测试零失败
- [ ] 一个 commit

---

## Task 6：摘掉双轨/双写（验证 Task 1-5 的成果）

**Blast Radius**：`framework/war_async.lua`、`script/jymain.lua`

**DoD**：
- [ ] 删 `war_async` 的 `EngineAPI.sprite.loadArchive` 那 4 行
- [ ] `LoadArchiveBoth` 改回单写（或直接删 helper，用 `SpriteAtlas.loadArchive`）
- [ ] **实机验证**：主地图 / 场景 / 战斗三个界面**都不黑**
      （这是"契约真的透明了"的唯一判据）
- [ ] 若任一界面黑 → 说明 Task 3/4/5 有遗漏，**回退**这个 Task
- [ ] 四版本全量测试零失败
- [ ] 一个 commit

---

## Task 7：门禁 + 全量收尾

**Blast Radius**：`gate_engine_contract.sh`、`TODO.md`

**DoD**：
- [ ] 新增 STEP：`framework/map_render.lua` 零 `love.*`（同 STEP E 判据）
- [ ] 新增 STEP：`framework/map_render.lua` 不出现 `PicLoadCache` / `picFileCache`
- [ ] 负向对照：在 `map_render.lua` 加一处 `love.graphics.draw` → gate FAIL
- [ ] 四版本全量测试零失败（记录断言数）
- [ ] 全仓 `luac5.1 -p` / `luac55 -p` 零失败
- [ ] 五门禁全 PASS
- [ ] **实机三界面截图**存入 `docs/screenshots/`
- [ ] 更新 `TODO.md`（删掉「map 契约透明化」条目）
- [ ] 一个 commit
