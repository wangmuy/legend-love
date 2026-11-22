# Sprite Atlas PNG 与 script 层迁移

## ADDED Requirements

### Requirement: REQ-SNM-1 SpriteAtlas 的 PNG 路径必须返回真实尺寸

`SpriteAtlas.getMeta` 对 PNG 帧 SHALL 返回真实 `w`/`h`，SHALL NOT 返回 `nil`。
`SpriteAtlas.getHandle` 对 PNG 帧 SHALL 把引擎回读的真实 `w`/`h` 存入
`atlas.meta[slot]`，SHALL NOT 存入 0。

依据（实测）：`hdgrp.grp` 的 PNG 帧是 slot 59 / 111，而 `r1.grp` 里
**人物 59 的头像代号就是 59** → `picid=118` → `slot=59` 命中 PNG。
当前 `getMeta` 对该帧返回 nil，迁移后会让人物 59 的头像尺寸失效。

#### Scenario: PNG 帧的 getMeta 返回真实尺寸

- **GIVEN** 一个含 PNG 帧的档案（如 `hdgrp.grp` 的 slot 59）
- **WHEN** 调用 `SpriteAtlas.getMeta(atlasId, 59*2)`
- **THEN** 返回的 table 有 `w > 0` 和 `h > 0`，不是 nil

#### Scenario: PNG 帧的 getHandle 写入真实尺寸

- **GIVEN** 引擎的 `createFromEncoded` 返回带 `w`/`h` 的 handle
- **WHEN** 调用 `SpriteAtlas.getHandle(atlasId, pngFrameId)`
- **THEN** `atlas.meta[slot].w` 等于 handle 的 `w`（不是 0）

#### Scenario: 兼容不解码 PNG 的引擎

- **GIVEN** MUD/Web 引擎的 `createFromEncoded` 返回 `{w=0, h=0}`
- **WHEN** 调用 `getMeta` 取 PNG 帧
- **THEN** 不抛错，返回 `w=0`/`h=0`（容忍，不当错误）

### Requirement: REQ-SNM-2 script 层零 lib.Pic*

`game/script/` 下的所有文件 SHALL NOT 调用 `lib.PicInit` / `lib.PicLoadFile` /
`lib.PicGetXY` / `lib.PicLoadCache`。

迁移映射：
- `lib.PicInit()`（无参）→ 删除（实测是 no-op：`if paletteFile == nil then return end`）
- `lib.PicInit(paletteFile)` → 删除（`jymain_adapter.init` 已调 `initSprites`）
- `lib.PicLoadFile(a,b,id)` → `SpriteAtlas.loadArchive(a, b, id, {paletteFile=...})`
- `lib.PicGetXY(a,f)` → `SpriteAtlas.getMeta(a, f)`（返回 table，需改解构）
- `lib.PicLoadCache(a,f,x,y,flag)` → `SpriteAtlas.draw(a, f, x, y, flag)`

#### Scenario: grep 检不出任何 lib.Pic 调用

- **GIVEN** 迁移完成
- **WHEN** 执行 `grep -rn 'lib\.Pic' game/script/`（排除注释行）
- **THEN** 命中数 = 0

#### Scenario: 头像绘制仍然正确

- **GIVEN** 战斗中有头像显示（`WarShowHead`）
- **WHEN** 实机跑一场战斗
- **THEN** 头像位置与尺寸与迁移前一致（截图对比）

### Requirement: REQ-SNM-3 移除双轨贴图加载补丁

`framework/war_async.lua` 的 `WarMainCoroutine` SHALL NOT 同时调用
`SpriteAtlas.loadArchive` 与 `EngineAPI.sprite.loadArchive`。

该双轨是 `battle-extensibility` 阶段为绕开崩溃加的临时补丁
（commit `ebf81af`）。迁移完成后旧系统不再被 `script/` 使用，补丁可移除。

#### Scenario: 战斗初始化只加载一套

- **WHEN** 检查 `WarMainCoroutine` 的贴图加载段
- **THEN** 只有 `SpriteAtlas.loadArchive`，没有 `EngineAPI.sprite.loadArchive`

#### Scenario: 战斗画面不回归

- **GIVEN** 移除补丁后
- **WHEN** 实机跑一场战斗并截图
- **THEN** 战斗地图 / 人物 / 头像血条全部正常

### Requirement: REQ-SNM-4 gate STEP D 零豁免

`gate_engine_contract.sh` 的 STEP D SHALL 对 4 个引擎实现一视同仁，
SHALL NOT 保留 `engine-love2d` 豁免。

#### Scenario: 门禁不再有豁免项

- **WHEN** 运行 `gate_engine_contract.sh`
- **THEN** 输出里没有 `[INFO] engine-love2d 豁免理由` 这一行

#### Scenario: lib_love 的 LoadPic 可删

- **GIVEN** `lib.PicLoadFile` 不再被 script 层直接调用
- **WHEN** 检查 `lib_love.lua`
- **THEN** `LoadPic`（119 行 RLE 解码）的调用方只有 `PicLoadFile` 内部的
  兼容路径，或已可整体删除
