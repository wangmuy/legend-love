## ADDED Requirements

### Requirement: 构建期复制 MOD 音效 [REQ-SOUND-1]

`tools/mod_build.lua` SHALL 把源 MOD 的 `sound/` 目录复制到 `game/mods/<mod>/sound/`（与 `data/`、`script/` 平级）。

复制 MUST 逐字节保留文件内容；文件名 SHALL 小写归一。所有文件（含非编号文件如 `tit.wav`）MUST 被忠实复制。

`sound/` 的内容 MUST NOT 被拍平进 `mods/<mod>/data/`。

#### Scenario: 单 MOD 音效复制

- **WHEN** 对 `reference/allmods/kys-mingdong/`（`sound/` 含 201 个 wav）运行 `lua tools/mod_build.lua kys-mingdong`
- **THEN** `game/mods/mingdong/sound/` 存在且含 201 个文件
- **AND** 文件名集合（小写）与源 MOD `sound/` 一致
- **AND** 每个文件内容与源逐字节相同
- **AND** `game/mods/mingdong/data/` 中不含任何 `.wav` 文件

#### Scenario: 全量 MOD 音效复制

- **WHEN** 运行 `lua tools/mod_build.lua --all`
- **THEN** 每个 MOD 的产物都含 `sound/` 目录，文件数等于对应源 MOD 的 `sound/` 文件数

#### Scenario: 非编号文件也被复制

- **WHEN** 对含 `sound/tit.wav` 的 MOD（如 `kys-BookCalamity`）运行构建
- **THEN** `game/mods/BookCalamity/sound/tit.wav` 存在（或对应 slug 目录下）

---

### Requirement: 音频常量 MOD 前缀改写 [REQ-SOUND-2]

`ModData.RewriteConstants` SHALL 把 `CC.ATKFile`、`CC.EFile`（及对称处理的 `CC.MIDIFile`）的前缀目录 `sound/` 改写为 `mods/<slug>/sound/`，当且仅当 `mods/<slug>/sound/` 目录存在。

改写 MUST 保持格式串部分（`%02d` 及扩展名）不变。

#### Scenario: 激活 MOD 时 ATKFile 指向 MOD

- **WHEN** 激活 mingdong 并加载 `CC` 常量
- **THEN** `CC.ATKFile == "mods/mingdong/sound/atk%02d.wav"`

#### Scenario: 激活 MOD 时 EFile 指向 MOD

- **WHEN** 激活 mingdong 并加载 `CC` 常量
- **THEN** `CC.EFile == "mods/mingdong/sound/e%02d.wav"`

#### Scenario: 3 位编号可格式化

- **WHEN** 用 `CC.EFile` 格式化编号 100（`string.format(CC.EFile, 100)`）
- **THEN** 结果为 `mods/mingdong/sound/e100.wav`（`%02d` 对 3 位数原样输出）

#### Scenario: MIDIFile 保持原版（MOD 无 ogg）

- **WHEN** 激活 mingdong 并加载 `CC` 常量
- **THEN** `CC.MIDIFile == "sound/game%02d.ogg"`（MOD `sound/` 无 `game*.ogg`，改写不命中）

---

### Requirement: 音效回退原版 [REQ-SOUND-3]

当未激活 MOD，或激活的 MOD 无 `sound/` 目录时，`CC.ATKFile`/`CC.EFile`/`CC.MIDIFile` SHALL 保持原版路径（`sound/...`）。

#### Scenario: 未激活 MOD

- **WHEN** 未激活任何 MOD 并加载 `CC` 常量
- **THEN** `CC.ATKFile == "sound/atk%02d.wav"`
- **AND** `CC.EFile == "sound/e%02d.wav"`
- **AND** `CC.MIDIFile == "sound/game%02d.ogg"`

#### Scenario: 激活的 MOD 无 sound 目录

- **WHEN** 激活某 MOD 且 `mods/<slug>/sound/` 不存在
- **THEN** 三个音频常量均保持原版路径

---

### Requirement: 零回归 [REQ-SOUND-4]

音效回退链的引入 MUST NOT 改变未激活 MOD 时的任何行为。

#### Scenario: 测试全绿

- **WHEN** 未激活 MOD 且运行 `cd game && lua tests/test_runner.lua`
- **THEN** 全部测试通过

#### Scenario: pascal 基线仍通过

- **WHEN** 运行 `cd game && lua tools/mod_build.lua --verify-pascal`
- **THEN** 输出 PASS

#### Scenario: 引擎音频代码未被修改

- **WHEN** 检查 `game/engine-love2d/lib_love.lua`
- **THEN** `PlayWAV`/`PlayMIDI`/`PlayMPEG` 实现与本 change 前逐字节相同
