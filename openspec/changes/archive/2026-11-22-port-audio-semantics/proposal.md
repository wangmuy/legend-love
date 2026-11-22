# Change Proposal: port-audio-semantics — 定下音频语义并补齐契约

> 父 slice: `engine-portability`（openspec/changes/engine-portability/）
> 前置: `port-native-api-completion` ✓（`script/` 已零 `lib.*`）

## Why

`engine-portability` 把 audio 概念重设计明确排除，`openspec/project/TODO.md` 记着：

> 现状：契约是 `playMusic(filename)`；实际用法是 `PlayMIDI(0)`（索引号）
> + `PlayMPEG(path, VK_ESCAPE)`（带中断键的视频）
> 后果：契约与实际用法完全不匹配，framework 绕开契约直接用 lib
> **必须先定语义**：音乐是「按名字选」还是「按编号选」？MPEG 算音频还是视频？

`port-native-api-completion` 迁移时把 `lib.PlayMIDI` 换成了
`EngineAPI.audio.playMusic(string.format(CC.MIDIFile, id+1))` ——
**把「索引 → 文件名拼接」这一步留在了 script 层**（`jymain.lua:2321`）。

### 本轮梳理出的真实问题（5 条，全部实测）

**① 「索引」其实不是索引，是文件名模板**

```lua
-- jyconst.lua:132
CC.MIDIFile = CONFIG.SoundPath .. "game%02d.ogg"      -- 注意扩展名写死 .ogg

-- jymain.lua:2315
function PlayMIDI(id)
    JY.CurrentMIDI = id
    if JY.EnableMusic == 0 then return end
    if id >= 0 then
        EngineAPI.audio.playMusic(string.format(CC.MIDIFile, id+1))   -- id+1！
    end
end
```

- `id+1`：MOD 源文件是 `music/<id>.mid`，构建期已重命名为 `game<id+1>.mid`
  （`mod_data.lua` 注释说明了这个约定），所以运行时 `id+1` 才对。**但契约层不知道这件事**。
- 扩展名写死 `.ogg`：而 `lib_love.PlayMIDI` 的 `resolveMusicFile` 会按
  `{ .ogg, .mp3, .mid }` 顺序补扩展名 + 找不到时回落 `sound/`。
  **这段「按扩展名候选 + MOD 回落」的语义 100% 在引擎里，契约完全没描述。**

**② `audio.playSequence(id, opts)` 契约是死契约**

```
grep 'audio.playSequence' → 0 处真实调用
```

它是 `port-contract-completeness` 时为「按索引播放」加的两个契约之一，
但 `port-native-api-completion` 最终没迁到它（改用了 `playMusic(filename)`）。
现在契约里同时有 `playMusic(filename)` 和 `playSequence(id)`，
**语义重叠且没人用后者** —— 这正是 TODO.md 说的「语义需先定」。

**③ `stopMusic` 零调用，但 `JY.CurrentMIDI` 有心智**

```
grep 'audio.stopMusic'（非 tests）→ 0
JY.CurrentMIDI 的唯一写入点是 PlayMIDI 的第一行
```

即「当前音乐 id」被记录，却没有任何路径用它恢复/停止音乐。
原本 `lib.PlayMIDI("")` 是「停止」的隐式约定（`EngineAPI.audio.stopMusic` 就是这么实现的），
但 script 层从不传空串。

**④ `playVideo` 名不副实**

```lua
-- lib_love.lua:897
function PlayMPEG(filename) PlayMIDI(filename) end
```

整个项目**从没真正播过 MPEG**：`game/data/start.mpg` 不存在（实测 `find` 零命中），
`playVideo` 只是把 `.mpg` 当音频载入（必然失败，`pcall` 静默吞掉）。
两个调用点（`jymain.lua:232` / `jymain_adapter.lua:403`）都在开场调用。

**⑤ 音量契约与「是否开音乐」是两套开关**

`audio.setMusicVolume(0..128)` 控制响度；`JY.EnableMusic` 控制「播不播」。
但 `JY.EnableMusic` 是**游戏状态**（存档字段），不在 Settings 里；
而音量在 Settings 里。玩家关掉音乐只能靠「设音量为 0」，音量 0 时引擎仍在解码流。

## In Scope

1. **定语义**（ADR 三条）：
   - `playSequence(id)` = 「按游戏的音乐编号播」——**引擎负责**把 id 映射到
     候选文件（`{ogg, mid, mp3}` 扩展名候选 + MOD 回落 `sound/`）
   - `playMusic(filename)` = 「按显式文件名播」——**不做**扩展名推测
   - `stopMusic()` = 停止 + 清 `JY.CurrentMIDI` 的协作（script 侧保持心智）
2. **把文件名拼接从 script 收回契约**：`CC.MIDIFile` 的「模板 + id+1」
   变成契约参数 `playSequence(id)`，`jymain.lua:2315` 的 `PlayMIDI` 变薄
3. **删 `audio.playSequence` 的重复语义** —— 不删契约，而是把它变成
   **唯一的索引入口**（`playMusic` 只收完整文件名，不再兼容 id）
4. **`playVideo` 更名语义**：明确它是「视频（现状：仅有音频能力）」
   还是「当作音频播」。本 change 定为：**保留名字，契约注释写清
   「引擎须尝试真视频播放，无能力时回退音频」**；LÖVE 实现写明确「无视频能力 → 音频」
5. **`JY.EnableMusic` 与音量统一**：`EnableMusic==0` 时调 `stopMusic()`
   而不是「不调播放入口」（当前是后者，导致已在播的音乐继续播）
6. **修 `CC.MIDIFile` 的 `.ogg` 硬编码**：模板里不再写扩展名

## Out of Scope

```
✗ 真的实现 MPEG/视频播放（需要 FFmpeg 或类似依赖）
✗ Android/iOS 音频后台行为
✗ BGM 淡入淡出
✗ 20 个 MOD 的 music/ 目录结构改造
✗ `EnableMusic` 从存档字段迁到 Settings（那是产品决策，需先定「关音乐是否跨存档」）
```

## Acceptance Criteria

### Scenario: 索引语义在契约层

- **GIVEN** `PlayMIDI(16)`
- **WHEN** 走到引擎
- **THEN** 引擎收到 `playSequence(16)`（不是拼好的 `"sound/game17.ogg"`）

### Scenario: 扩展名候选在引擎层

- **GIVEN** MOD 只提供 `music/game17.mid`（无 `.ogg`）
- **WHEN** `playSequence(16)`
- **THEN** 引擎按 `{ogg, mid, mp3}` 顺序找到 `.mid` 并播放

### Scenario: 关音乐真的停

- **GIVEN** 音乐正在播
- **WHEN** `JY.EnableMusic = 0` 后调 `PlayMIDI(16)`
- **THEN** 实际调 `audio.stopMusic()`（当前行为：什么都不做，音乐继续）

### Scenario: 开场视频不报错

- **GIVEN** `game/data/start.mpg` 不存在
- **WHEN** 启动流程走到 `playVideo`
- **THEN** 不抛错、不阻塞、日志记一条「no video capability / asset missing」

### Scenario: 契约无重叠

- **WHEN** 读 `engine_api.lua` 的 audio 段
- **THEN** `playMusic` 明确「完整文件名」、`playSequence` 明确「游戏音乐编号」，
      两者的适用场景各有消费方（`playMusic` → 测试/工具；`playSequence` → 游戏）

## 风险

| 风险 | 缓解 |
|------|------|
| 改 `CC.MIDIFile` 模板破 MOD 兼容 | 先跑 20 MOD 的 `gate_run_mod.sh`；模板不带扩展名时引擎必须自己补 |
| `playMusic` 语义收窄后测试桩失效 | 测试桩改成「两个都记录」，不断言调用哪个 |
| `EnableMusic=0` 改调 `stopMusic` 影响「存档后重播」 | 重播路径在 `PlayMIDI` 里本来就有（写 `CurrentMIDI` 再播）；加单测 |
