# Tasks: port-audio-semantics

> **策略**：先加契约（低风险、可独立验证），再改 script（`PlayMIDI` 变薄），
> 最后改 `EnableMusic` 行为。20 个 MOD 的音乐路径是最大回归面，
> 每个 Task 都跑 `gate_run_mod.sh`。

## Task 1：新增 `app.setMusicTemplate` 契约（4 引擎）

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`、`tests/engine_test.lua`、`tests/unit/test_engine_api.lua`

**DoD**：
- [ ] `engine_api.lua` 声明 `M.app.setMusicTemplate(template, startOffset)`，
      注释写清「模板不含扩展名 / startOffset 是 id→模板参数的偏移」
- [ ] LÖVE：保存到模块内变量，供 `playSequence` 用
- [ ] MUD/Web：保存（MUD 也要能在日志里回读）
- [ ] 测试桩：记录调用
- [ ] 单测：4 引擎都存在；契约数 89 → **90**（承接前两个 change 的结果）
- [ ] 一个 commit

## Task 2：`playSequence` 语义收窄到「只收编号」

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`

**DoD**：
- [ ] 契约注释改写：只收 number；`{ogg, mid, mp3}` 候选顺序 + `sound/` 回落在注释里写明
- [ ] LÖVE 实现：从 `playSequence(filenameOrId)` 改为 `playSequence(id)`：
      ① 取模板 ② `string.format(template, id + startOffset)` ③ `resolveMusicFile`
      ④ 复用既有 `PlayMIDI(filename)` 的播放逻辑（循环 + 音量）
- [ ] LÖVE：收字符串时记日志 + 返回 false
- [ ] MUD/Web：只记录调用，返回 true
- [ ] 单测：`playSequence(16)` + 模板 → 实际传给 `love.audio.newSource` 的路径
      （在 `test_mod_boot.lua` 的桩里断言）
- [ ] 一个 commit

## Task 3：`playMusic` 收窄到「只收完整文件名」

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、
`game/script/jymain.lua`

**DoD**：
- [ ] 契约注释改写：不做扩展名推测、不做路径回落
- [ ] LÖVE 实现：`playMusic(filename)` 直接用 `love.audio.newSource(filename)`，
      **不**经 `resolveMusicFile`（那条路径留给 `playSequence`）
- [ ] `jymain.lua:2315` 的 `PlayMIDI(id)` 改为：
      ```lua
      function PlayMIDI(id)
          JY.CurrentMIDI = id
          if JY.EnableMusic == 0 then
              EngineAPI.audio.stopMusic()
              return
          end
          if id >= 0 then
              EngineAPI.audio.playSequence(id)
          end
      end
      ```
- [ ] `grep -n 'audio.playMusic' game/script/*.lua` = 0
- [ ] 一个 commit

## Task 4：`CC.MIDIFile` 模板去扩展名 + 启动注册

**Blast Radius**：`game/script/jyconst.lua`、`game/framework/jymain_adapter.lua`、
`game/framework/mod_data.lua`

**DoD**：
- [ ] `CC.MIDIFile = CONFIG.SoundPath .. "game%02d"`（去掉 `.ogg`）
- [ ] `JYMainAdapter.init` 里注册：
      `EngineAPI.app.setMusicTemplate(CC.MIDIFile, 1)`（在 `PlayMIDI` 首次调用之前）
- [ ] `mod_data.lua` 的注释同步（它解释的「去掉扩展名」现在是模板本来的形态）
- [ ] `gate_run_mod.sh`：20 MOD 全 PASS（这是模板变更的核心回归门）
- [ ] 实机：进入主地图有 BGM（`sound/game17.ogg`）
- [ ] 一个 commit

## Task 5：`EnableMusic == 0` 停音乐

**Blast Radius**：`game/script/jymain.lua`、`game/tests/unit/test_audio_semantics.lua`（新）

**DoD**：
- [ ] `PlayMIDI` 的 `EnableMusic == 0` 分支改为调 `audio.stopMusic()`
- [ ] 新增单测 `test_audio_semantics.lua`：
      ① 关音乐 → 收到 `stopMusic`
      ② 开音乐 → 收到 `playSequence(CurrentMIDI)`
      ③ 负数 id → 不调 `playSequence`（保持现状语义）
- [ ] 一个 commit

## Task 6：`playVideo` 返回真实结果

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`、`tests/engine_test.lua`

**DoD**：
- [ ] 契约注释改写：视频优先 / 无能力回退音频 / 返回 boolean / 不抛错
- [ ] LÖVE：文件不存在 → 记日志 + `return false`；
      存在 → 尝试音频（现状：`PlayMPEG` = `PlayMIDI` 别名）
- [ ] MUD/Web：`return false`
- [ ] 测试桩：返回 false
- [ ] 单测：`game/data/start.mpg` 缺失时返回 false
- [ ] 实机：启动时日志有一条「video asset missing」，无错误屏
- [ ] 一个 commit

## Task 7：门禁 + 文档

**Blast Radius**：`game/tests/gate_run_mod.sh`、`openspec/project/TODO.md`、
`game/engine-love2d/engine_api.lua`

**DoD**：
- [ ] `gate_run_mod.sh` 新增断言：`CC.MIDIFile` 不含 `%.ogg$`（模板不得带扩展名）
- [ ] `TODO.md`：删掉「audio 概念重设计」条目（本 change 定案）
- [ ] `engine_api.lua` 的 audio 段加「谁该用哪个」的对照表
- [ ] 20 MOD + 全量测试 + 五门禁
- [ ] 一个 commit

## 依赖

```
Task 1 (setMusicTemplate) ──▶ Task 2 (playSequence 收窄) ──▶ Task 4 (模板/注册)
                                    │                            │
                                    ▼                            ▼
                              Task 3 (playMusic 收窄) ──▶ Task 5 (EnableMusic 停)
                                                                 │
                             Task 6 (playVideo 返回值) ◀─────────┘
                                    │
                                    ▼
                              Task 7 (门禁+文档)
```

- Task 2 必须等 Task 1（`playSequence` 要用模板）
- Task 6 独立，可与 2/3/5 并行
