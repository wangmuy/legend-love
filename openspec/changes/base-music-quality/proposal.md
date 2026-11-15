---
status: active
created: 2026-11-15
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: base-music-quality — 原版 BGM 从 MIDI 母带重渲染（体积优化版）

## Why

用户报告：「原版的音乐（`game/sound/*.ogg`）听起来很糟糕，但是 allmods kys-pascal
版本的音乐（`reference/allmods/kys-pascal/music/*.mid`）听起来就很好。」

诊断结论：**两边的曲子其实是同一批 MIDI**，坏的只是渲染链。

| 事实 | 证据 |
|---|---|
| kys-pascal 的 `music/1..23.mid` 与本仓库原版 MIDI 母带**逐字节相同** | 23/25 精确 md5 命中（`game02..game24` ↔ `1..23.mid`） |
| 原版 Pascal 程序用 FluidSynth + 自带 `music/mid.sf2` 实时合成 | `kys.exe` 内嵌字符串 `music/mid.sf2` + `fluidsynth` |
| 本仓库 OGG 是「渲染 → opus → ogg」两次有损转码 | 提交 `8c3c3c9`（Lavf62/libopus）+ `e0d7a62`（Lavf60/libvorbis 112kbps） |
| 转码留下三类可测损伤 | 15/25 首真峰值 > 0 dBFS（最高 **+3.20 dBFS**）；响度跨度 **18.2 dB**；`game01` 有 **77.6%** 能量压在 200 Hz 以下 |

修复方向：**保留 MIDI 母带 + 从母带重渲染**，而不是再转一次码。

## 关键约束（用户提出）

1. **不把新音乐资源提交进 git**（避免仓库突然变大）
2. **OGG 要在保持音质的前提下用最省体积**
3. `game/sound` 播放优先级是 OGG 优先、MIDI 兜底 → **MIDI 不进 git**，可删除
4. `bak/sound` 的 opus 若也是坏音质 → 一并删除
5. **从 git 历史里彻底移除**已删除的音乐资源，避免仓库历史继续变大

## 体积与音质实测（本 change 的核心数据）

### 实测 1：原版音色库本身只有 22.05 kHz 采样率

解析 `mid.sf2` 的 `shdr` 样本头：**492/495 个样本是 22050 Hz，3 个是 24000 Hz**。
FluidSynth 合成上限就是约 11 kHz（22.05kHz 的 Nyquist）。母带实测印证：

```
25 首里 >11 kHz 的相对能量：-26.4 dB（最亮）.. -67.9 dB（game13 纯低频）
                             平均约 -33 dB
```

即：**母带本来就没有 11 kHz 以上的实质内容**。48 kHz 容器里 11~24 kHz 装的只是
重采样镜像与量化噪声（`-60 dB` 量级）。

### 实测 2：降采样到 32 kHz 不掉音质（同一把尺子量）

用 6 首代表曲（game01/08/10/19/23/25，覆盖最亮与最暗）逐频段比对：

| 编码参数 | 平均 SNR vs 母带 | 频谱形状偏差（平均/最差） | 25 首总体积 |
|---|---|---|---|
| 48 kHz q5（原方案） | 24.62 dB | 0.26 / 1.59 dB | 26.3 MB |
| **32 kHz q4** | 23.71 dB | 0.57 / 1.44 dB | **20.1 MB** |
| 32 kHz q3 | 21.96 dB | 0.67 / 1.35 dB | 17.2 MB |
| 48 kHz q3（旧档） | 21.23 dB | — | 19.4 MB |

**结论：32 kHz q4 与 48 kHz q5 客观指标同档**（频谱形状偏差甚至更小，因为
省下来的码率被用在了有内容的 0~16 kHz 上），体积从 26.3 MB 降到 20.1 MB。

### 实测 3：再往下压就真的掉音质

| 参数 | 平均 SNR | 相对 48k·q5 |
|---|---|---|
| 48 kHz q5 | 24.62 dB | — |
| 32 kHz q4 | 23.71 dB | **-0.91 dB** |
| 32 kHz q3 | 21.96 dB | -2.66 dB |
| 24 kHz q6 | 22.23 dB | -2.39 dB |
| 22.05 kHz q6 | 22.33 dB | -2.29 dB |

32 kHz q3 省 3 MB 但要付 2.7 dB SNR；24/22 kHz 更差（重采样把 11 kHz 附近的内容
也削掉了）。所以 **32 kHz q4 是拐点**。

## What Changes

1. **新增 `tools/render-base-music.sh`** — 从 MIDI 母带重渲染
   - FluidSynth + 原版 `mid.sf2` → WAV @ **32 kHz**（音色库样本只有 22.05 kHz，48k 是浪费）
   - `silenceremove` 去尾静音
   - 两遍 `loudnorm`（-16 LUFS / ≤ -2.0 dBTP，`linear` 优先）
   - `libvorbis -q:a 4`
   - `ensure_master()`：母带不在盘上时按清单从 reference / git 历史现取
2. **新增 `tools/midiinfo.lua`** — 纯 Lua MIDI 探针（供门禁算 MIDI 时长）
3. **新增 `tools/base-music-manifest.tsv`** — 25 首母带的 md5 / 来源 / 时长清单
   （母带不入 git，渲染时按此清单自动恢复）
4. **新增 `tools/purge-audio-history.sh`** — git 历史清理工具（`--dry-run` / `--apply`）
5. **替换 `game/sound/gameNN.ogg`** — 25 首，19.4 MB → **20.1 MB**（32 kHz q4）
   - 与旧档（48 kHz q3，19.4 MB）**几乎同体积**，但音质大幅改善
   - 与初版 48 kHz q5（26.3 MB）相比省 6.2 MB，客观指标同档
6. **删除 `bak/sound/`** — 26 MB 的坏 opus（见下方实测）+ 1 个 MIDI
7. **新增 `game/tests/gate_base_music.sh`** + `tests/unit/test_base_music.lua`
8. **`.gitignore` 增加 `game/sound/*.mid`**
9. **git 历史清理**（见 tasks.md Task 7）

## In Scope

- `game/sound/gameNN.ogg`（替换，25 首）
- `.gitignore`（+ `game/sound/*.mid`）
- `tools/render-base-music.sh`、`tools/midiinfo.lua`、
  `tools/base-music-manifest.tsv`、`tools/purge-audio-history.sh`（新增）
- `game/tests/gate_base_music.sh`、`game/tests/unit/test_base_music.lua`（新增）
- 删除 `bak/sound/`（26 MB）
- git 历史清理脚本/说明

## Out of Scope

- **MIDI 母带不入 git**：`game/sound/gameNN.mid` 已加入 `.gitignore`，是重渲染的
  临时输入。`render-base-music.sh` 的 `ensure_master()` 按清单从
  `reference/allmods/*/music/*.mid`（已 gitignore）或 git 历史现取。
  **实测 25/25 都能找回**，且在**历史被重写（SHA 全变）后依然可恢复**
- **不改运行时代码**：`MUSIC_EXTS` 仍是 `.ogg → .mp3 → .mid`，OGG 自动优先
- **不引入运行时 FluidSynth 依赖**

## 播放优先级的事实澄清

`CC.MIDIFile = CONFIG.SoundPath .. "game%02d.ogg"`（`jyconst.lua:129`）**已带扩展名**。
`lib_love.lua` 的 `resolveMusicFile` 对「已带扩展名」的路径原样返回，**不会回退到 `.mid`**。
实测（LÖVE 探针）：

```
CC.MIDIFile = sound/game01.ogg
hasExtension = true
audioFileExists = false      ← 删掉 ogg 后
=> resolveMusicFile 结果: sound/game01.ogg   ← 仍是 ogg，不回退
```

**所以原版曲目只有 OGG 一条路**；`.mid` 兜底只在 MOD 路径下生效（MOD 的
`CC.MIDIFile` 被 `mod_data.lua` 改写成**去扩展名**的 stem 才会探测 `.mid`）。
这正好符合用户预期：`game/sound` 只留 OGG。

## `bak/sound/` 的实测结论

25 个 opus 与 `game/sound/*.ogg` 的损伤几乎一致（同一批源）：

| 指标 | bak/sound/*.opus |
|---|---|
| 真峰值 > 0 dBFS | **15/25**（最高 +3.20 dBFS） |
| 响度范围 | -26.0 .. -7.8 LUFS（跨度 **18.2 dB**） |
| 与母带的频谱形状偏差 | 平均 **93.7 dB**（同上，因为时长/速度错位） |
| 唯一例外 | `game25.MID`（18 KB），是**唯一**与 `bin/sound` 历史重复的母带 |

结论：`bak/sound/` 除了 `game25.MID` 全是**与坏 OGG 同源的坏 opus**，且 `game25.MID`
在 `bin/sound` 历史里也有。**整个目录可删。**

## 风险与缓解

| 风险 | 缓解 |
|---|---|
| 32 kHz 是否真无损？ | 音色库样本只有 22.05 kHz，母带 >11k 内容在 -26..-68 dB；实测 32k q4 频谱形状偏差 0.57 dB（48k q5 是 0.26 dB），同档 |
| 音色库 `mid.sf2` 在 gitignore 的 `reference/` 里 | 脚本按 `mid.sf2 → FluidR3_GM → default-GM` 探测，缺失时给安装提示 |
| 删了 `bak/sound` 后 `game25.mid` 从哪来？ | `git show 8c3c3c9^:bin/sound/game25.mid`（历史保留，实测可恢复） |
| 历史重写影响协作者 | 本文档 Task 7 给出完整流程与「必须通知协作者重新 clone」的警告 |
