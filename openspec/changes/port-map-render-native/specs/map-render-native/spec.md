# 地图绘制契约透明化

## ADDED Requirements

### Requirement: REQ-MRN-1 地图绘制不得依赖引擎的档案缓存

`EngineAPI.map.drawMain` / `drawScene` / `drawBattle` SHALL NOT 通过
`picFileCache`（即 `lib.DrawMMap`/`DrawSMap`/`DrawWarMap` 的旧实现）取贴图。

依据（实测）：这 3 个契约的 LÖVE 实现只是转发 `lib.*`，而 `lib.*` 内部经
`JY_LoadPic` = `PicLoadCache` 读 `picFileCache` → 新引擎必须实现整套 RLE 解码。

#### Scenario: 绘制走 sprite.draw 而不是 picFileCache

- **WHEN** 检查 `framework/map_render.lua`
- **THEN** 贴图绘制只用 `EngineAPI.sprite.draw`，无 `PicLoadCache` / `picFileCache`

#### Scenario: 3 个契约的实现不再转发 lib.*

- **WHEN** 检查 `engine_love2d.lua` 的 `map.drawMain/drawScene/drawBattle`
- **THEN** 它们调 `MapRender`，不调 `lib.DrawMMap/DrawSMap/DrawWarMap`

### Requirement: REQ-MRN-2 framework/map_render.lua 零引擎依赖

`framework/map_render.lua` SHALL NOT `require("engine-*")`，SHALL NOT 直接
调 `love.*`，SHALL 只经 `EngineAPI`。

#### Scenario: 门禁检查

- **WHEN** 运行 `gate_engine_contract.sh` STEP E（同类判据）
- **THEN** `framework/map_render.lua` 零 `love.*` 调用

### Requirement: REQ-MRN-3 三个界面像素逐字节相同

迁移后主地图 / 场景 / 战斗三个界面的截图 SHALL 与迁移前逐字节相同。

#### Scenario: 主地图

- **GIVEN** 进入主地图停留固定帧
- **WHEN** 截图并与迁移前对比
- **THEN** md5 相同

#### Scenario: 场景（主角家开场）

- **GIVEN** 开场对话场景
- **WHEN** 截图并与迁移前对比
- **THEN** md5 相同

#### Scenario: 战斗

- **WHEN** `--battle=4` 截图与迁移前对比
- **THEN** md5 相同

### Requirement: REQ-MRN-4 双轨/双写可以摘除

迁移后 `war_async` 的 `EngineAPI.sprite.loadArchive` 双轨补丁与
`jymain` 的 `LoadArchiveBoth` 双写 SHALL 可以摘除而不导致地图全黑。

#### Scenario: 摘除双写后地图仍正常

- **WHEN** 把 `LoadArchiveBoth` 改回单写 `SpriteAtlas.loadArchive` 并实机截图
- **THEN** 主地图与场景仍正常（不再全黑）

### Requirement: REQ-MRN-5 新增 6 个契约

SHALL 新增 `render.getClip`、`map.setTile`、`map.getSceneTile`、
`map.setSceneTile`、`map.getBattleTile`、`map.setBattleTile`，
且 4 个引擎（LÖVE / MUD / Web / 测试桩）都实现。

#### Scenario: 契约数与实现

- **WHEN** 统计 `engine_api.lua` 的 `function M.*` 与 4 个引擎的实现
- **THEN** 每个新契约在 4 个引擎都能找到
