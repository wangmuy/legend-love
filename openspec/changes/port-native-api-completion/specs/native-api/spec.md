# script 层零 lib.*

## ADDED Requirements

### Requirement: REQ-NAC-1 script 层代码文件零 lib.* 调用

`game/script/jymain.lua`、`game/script/battle/*.lua`、
`game/script/newevent/*.lua` SHALL NOT 调用 `lib.*`，
唯一例外是 `WaitFrame` 内部的 `lib.Delay` fallback（非协程上下文的退路）。

依据（实测）：196 处里 165 处已有 EngineAPI 等价物；剩下 31 处需先验证语义。

#### Scenario: 门禁检查

- **WHEN** 运行 `gate_engine_contract.sh` 新增的 STEP D6
- **THEN** `script/` 的 `lib.*` 命中数 ≤ 1（只允许 WaitFrame 的 fallback）

#### Scenario: 负向对照

- **WHEN** 在 `script/battle/battle_flow.lua` 加一处 `lib.Debug(...)`
- **THEN** 门禁 FAIL

### Requirement: REQ-NAC-2 语义等价必须逐个验证

对 `lib.LoadPicture` / `lib.PlayWAV` / `lib.LoadMMap` / `lib.PlayMIDI` 等
参数形态不明朗的函数，SHALL NOT 机械替换，SHALL 先写对照测试。

#### Scenario: LoadPicture 与 sprite.drawPictureFile 等价

- **WHEN** 同一张图片、同一坐标，分别走两个路径
- **THEN** 实机截图像素相同

### Requirement: REQ-NAC-3 新增 map.loadClouds 契约

SHALL 新增 `map.loadClouds(idxFile, grpFile)`，4 引擎实现。
MUD/Web 可空实现（无图形），但契约不能缺。

#### Scenario: 契约存在

- **WHEN** 检查 4 个引擎
- **THEN** 每个都有 `EngineAPI.map.loadClouds`

### Requirement: REQ-NAC-4 三界面像素逐字节相同

迁移后主地图 / 场景 / 战斗三界面的截图 SHALL 与迁移前 md5 相同
（基线见 `docs/screenshots/README.md`）。

#### Scenario: 三界面 md5 不变

- **WHEN** 用 README 里的参数重新截图
- **THEN** 三个 md5 都与记录值相同
