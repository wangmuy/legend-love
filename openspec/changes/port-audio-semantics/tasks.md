# Tasks: port-audio-semantics

> **策略**：先加契约（低风险、可独立验证），再改 script（`PlayMIDI` 变薄），
> 最后改 `EnableMusic` 行为。20 个 MOD 的音乐路径是最大回归面，
> 每个 Task 都跑 `gate_run_mod.sh`。

## Task 1：新增 `app.setMusicTemplate` 契约（4 引擎）

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`、`tests/engine_test.lua`、`tests/unit/test_engine_api.lua`

**DoD**：
- [x] `engine_api.lua` 声明 `M.app.setMusicTemplate(template, startOffset)`，
      注释写清「模板不含扩展名 / startOffset 是 id→模板参数的偏移」
- [x] LÖVE：保存到模块内变量，供 `playSequence` 用（+ `getMusicTemplate` 供测试回读）
- [x] MUD/Web/测试桩：保存并可在日志/字段里回读
- [x] 单测：4 引擎都存在（`testNewContractsExplicitlyImplemented` 扩项）
- [x] 契约数 89 → **90**
- [x] 一个 commit

## Task 2：`playSequence` 语义收窄到「只收编号」

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`

**DoD**：
- [x] 契约注释改写：只收 number；`{ogg, mid, mp3}` 候选顺序 + `sound/` 回落在注释里写明
- [x] LÖVE 实现：从 `playSequence(filenameOrId)` 改为 `playSequence(id)`：
      ① 取模板 ② `string.format(template, id + startOffset)` ③ 交 `lib.PlayMIDI`
      （它负责扩展名候选 + sound/ 回落 + 循环 + 音量 —— 这段语义本就在 lib，
       只是**现在被契约承认了**）
- [x] LÖVE：收字符串 / id<0 / 模板未注册时记日志 + 返回 false
- [x] MUD/Web：只记录调用
- [x] 单测：`test_audio_semantics.lua` 源码级断言（不得再有 `filenameOrId` 分支、
      必须校验 `type(id) ~= "number"`、必须用 `musicTemplate` + `musicStartOffset`）
- [x] 一个 commit

## Task 3：`playMusic` 收窄到「只收完整文件名」

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、
`game/script/jymain.lua`

**DoD**：
- [x] 契约注释改写：不做扩展名推测、不做路径回落
- [x] LÖVE 实现：`playMusic(filename)` 走新的 `lib.PlayMusicFile`（直接
      `love.audio.newSource(filepath)`），**不**经 `resolveMusicFile`
      （那条路径留给 `playSequence` → `lib.PlayMIDI`）
- [x] `jymain.lua` 的 `PlayMIDI(id)` 改为：记 id → 关音乐则 `stopMusic` →
      否则 `playSequence(id)`（不再 `string.format`）
- [x] `grep -n 'audio.playMusic' game/script/*.lua` = 0
- [x] 一个 commit

## Task 4：`CC.MIDIFile` 模板去扩展名 + 启动注册

**Blast Radius**：`game/script/jyconst.lua`、`game/framework/jymain_adapter.lua`、
`game/framework/mod_data.lua`

**DoD**：
- [x] `CC.MIDIFile = CONFIG.SoundPath .. "game%02d"`（去掉 `.ogg`）
- [x] `JYMainAdapter.init` 里注册：
      `EngineAPI.app.setMusicTemplate(CC.MIDIFile, 1)`（在 `PlayMIDI` 首次调用之前）
- [x] `mod_data.lua` 的 MOD 音乐重定向改为「前缀替换」（不再剥 `.ogg`，
      但保留对旧值的兼容剥离）
- [x] `gate_run_mod.sh`：**GATE_PASS**（20 MOD 音频零丢失 + active_mod 解析）
      注：需先给 PATH 提供 `lua` 与 `love`，否则脚本自身报 `--list 运行失败`
      （环境问题，与本次改动无关）
- [x] 实机：场景/战斗 md5 不变（`1efd2af3…` / `6c8eb322…`）
- [x] 一个 commit

## Task 5：`EnableMusic == 0` 停音乐

**Blast Radius**：`game/script/jymain.lua`、`game/tests/unit/test_audio_semantics.lua`（新）

**DoD**：
- [x] `PlayMIDI` 的 `EnableMusic == 0` 分支改为调 `audio.stopMusic()`
- [x] 新增单测 `test_audio_semantics.lua`（39 条断言）：
      ① 契约注释的职责边界（playSequence 只收 number / playMusic 收完整文件名）
      ② `CC.MIDIFile` 无扩展名
      ③ 启动注册模板
      ④ `PlayMIDI` 不再 `string.format`
      ⑤ `EnableMusic==0` 分支含 `stopMusic`
      ⑥ `playVideo` 不得无条件 return true + 必须先探测资源
      ⑦ `playSequence` 有 number 守卫、无 `filenameOrId` 兼容分支
      ⑧ 4 引擎都有 `app.setMusicTemplate`
- [x] 一个 commit

## Task 6：`playVideo` 返回真实结果

**Blast Radius**：`engine_api.lua`、`engine_love2d.lua`、`engine_mud.lua`、
`engine_web.lua`、`tests/engine_test.lua`

**DoD**：
- [x] 契约注释改写：视频优先 / 无能力回退音频 / 返回 boolean / 不抛错
- [x] LÖVE：先 `love.filesystem.getInfo` 探测 → 缺失记日志 + `return false`；
      存在 → 走音频路径，仍 `return false`（无视频能力）
- [x] MUD / Web / 测试桩：`return false`
- [x] 单测：`test_audio_semantics` 源码级断言（不得 `return true`、
      必须 `getInfo`、必须 `return false`）
- [x] 实机：启动无错误屏（场景 md5 不变；`start.mpg` 缺失仅日志）
- [x] 一个 commit

## Task 7：门禁 + 文档

**Blast Radius**：`game/tests/gate_run_mod.sh`、`openspec/project/TODO.md`、
`game/engine-love2d/engine_api.lua`

**DoD**：
- [x] `gate_run_mod.sh` 新增 2 条断言：① `CC.MIDIFile` 不含扩展名
      ② `JYMainAdapter.init` 注册了 `setMusicTemplate(CC.MIDIFile, 1)`
- [x] `TODO.md`：「audio 概念重设计」已标为定案并指向本 change
- [x] `engine_api.lua` 的 audio 段加「谁该用哪个」对照表（5 行）
- [x] `gate_run_mod.sh` **GATE_PASS**（需 PATH 里有 lua + love，见 Task 4 注）
- [x] 全量测试 **4111/0**（+39 条新断言）
- [x] 一个 commit

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
