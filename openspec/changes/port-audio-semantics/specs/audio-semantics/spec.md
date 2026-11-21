# 音频语义定案

## ADDED Requirements

### Requirement: REQ-AUD-1 `playSequence` SHALL 只收音乐编号

`EngineAPI.audio.playSequence(id)` SHALL 收**数字编号**（不再接受字符串）。
编号 → 文件名的映射 SHALL 由引擎按 `app.setMusicTemplate` 注册的模板完成。

依据：`port-contract-completeness` 加的 `playSequence(id, opts)` 在
`port-native-api-completion` 里被绕过（改成 `playMusic(拼好的文件名)`），
导致「扩展名候选 + MOD 回落」这段语义滞留在引擎里、契约未描述。

#### Scenario: 编号语义

- **GIVEN** 已注册模板 `"sound/game%02d"`、`startOffset = 1`
- **WHEN** 调 `audio.playSequence(16)`
- **THEN** 引擎按 `sound/game17` + `{.ogg, .mid, .mp3}` 候选找到文件

#### Scenario: 收字符串时报错或忽略

- **WHEN** 调 `audio.playSequence("sound/game17.ogg")`
- **THEN** 记日志并返回 false（不静默当文件名用）

### Requirement: REQ-AUD-2 `playMusic` SHALL 只收完整文件名

`EngineAPI.audio.playMusic(filename)` SHALL NOT 做扩展名推测、SHALL NOT
做路径回落。游戏内 BGM SHALL 走 `playSequence`。

#### Scenario: 不做推测

- **GIVEN** `playMusic("sound/game17")`（无扩展名）
- **WHEN** 引擎处理
- **THEN** 按完整路径尝试播放（不补 `.ogg`/`.mid`），失败记日志

#### Scenario: 游戏 BGM 不再走 playMusic

- **WHEN** 执行 `grep -n 'audio.playMusic' game/script/*.lua`
- **THEN** 命中数 = 0

### Requirement: REQ-AUD-3 引擎 SHALL 提供音乐模板注册契约

新增 `EngineAPI.app.setMusicTemplate(template, startOffset)`，4 引擎实现。
`game/script/jyconst.lua` 的 `CC.MIDIFile` SHALL 去掉扩展名后缀。

依据（实测）：

```lua
CC.MIDIFile = CONFIG.SoundPath .. "game%02d.ogg"   -- 扩展名硬编码
```

而引擎实际按 `{ogg, mid, mp3}` 候选找 —— 模板带扩展名会让候选逻辑无从判断
「哪些部分是模板、哪些是候选」。

#### Scenario: 模板无扩展名

- **WHEN** 检查 `jyconst.lua`
- **THEN** `CC.MIDIFile` 的值不含 `.ogg` / `.mid` / `.mp3`

#### Scenario: 4 引擎都有

- **WHEN** 检查 `engine_api.lua` 与 4 个实现
- **THEN** 每个都有 `app.setMusicTemplate`

#### Scenario: 启动时注册

- **GIVEN** 正常启动
- **WHEN** `JYMainAdapter.init` 完成
- **THEN** 引擎已收到模板（用测试桩断言「收到 1 次」）

### Requirement: REQ-AUD-4 `EnableMusic == 0` SHALL 停止音乐

`PlayMIDI(id)` 在 `JY.EnableMusic == 0` 时 SHALL 调
`EngineAPI.audio.stopMusic()`（当前行为：直接 `return`，已在播的音乐继续）。

依据：`JY.EnableMusic` 是存档字段（`jymain.lua:167`），玩家关掉音乐后
重新进档不会停当前 BGM —— 活体缺陷。原版 Pascal 的 `PlayMIDI` 在
`EnableMusic=0` 时调 `StopMIDI`。

#### Scenario: 关音乐立即生效

- **GIVEN** 音乐正在播放
- **WHEN** 把 `JY.EnableMusic` 设为 0，然后调 `PlayMIDI(16)`
- **THEN** 引擎收到 `stopMusic()`（用测试桩断言）

#### Scenario: 开音乐能恢复

- **GIVEN** `JY.EnableMusic` 从 0 改回 1
- **WHEN** 调 `PlayMIDI(JY.CurrentMIDI)`
- **THEN** 引擎收到对应的 `playSequence`

### Requirement: REQ-AUD-5 `playVideo` SHALL 返回真实结果

`EngineAPI.audio.playVideo(filename, skipKey)` SHALL 返回 `boolean`：
真视频播完 = `true`；被跳过/无能力/文件缺失 = `false`（当前实现无条件 `true`）。

引擎 SHALL NOT 抛错（视频是可选能力）。

#### Scenario: 文件缺失返回 false

- **GIVEN** `game/data/start.mpg` 不存在（实测仓库现状）
- **WHEN** 启动流程调 `playVideo`
- **THEN** 返回 `false`，记一条日志，不阻塞、不抛错

#### Scenario: MUD/Web 无视频能力

- **WHEN** MUD 引擎收到 `playVideo`
- **THEN** 返回 `false`（不是 `true`）

## Out of Scope

- 真实 MPEG 解码（需要 FFmpeg 依赖）
- `EnableMusic` 迁到 Settings
- BGM 淡入淡出、跨场景无缝切换
