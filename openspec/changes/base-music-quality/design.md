---
status: active
created: 2026-11-15
---
# Design: base-music-quality

## Context

原版 BGM（`game/sound/game01..25.ogg`）音质差的根因有三层，且**互相叠加**。
把它们分开量化，才能证明「重渲染」是唯一正确解，而不是又一次凭感觉换文件。

## 诊断证据链

### 1. 曲子本身是好的——两边是同一批 MIDI

从 git 历史恢复转码前的母带（`git show 8c3c3c9^:bin/sound/gameNN.mid`），
与用户认可的 `reference/allmods/kys-pascal/music/*.mid` 做 md5 比对：

```
game02..game24  ↔  kys-pascal/1..23.mid   逐字节相同（23 首命中）
game01, game25  不在 kys-pascal 内（该 MOD 只带 23 首）
```

所以「kys-pascal 好听 / 原版难听」**不可能**是曲子差异。

### 2. 差异来自渲染方式

`reference/allmods/kys-pascal/kys.exe` 内嵌字符串：

```
music/mid.sf2       ← 自带 SoundFont 路径
fluidsynth          ← 合成器
```

同目录还有 `libfluidsynth-3.dll`、`SDL3_mixer.dll`、`mpg123.dll`。
即：原版 Pascal 程序**运行时用 FluidSynth + 真实音色库合成 MIDI**。

本移植版则播放预先转码的 OGG。

### 3. 转码链确实损了两道

| 提交 | 动作 | 证据 |
|---|---|---|
| `8c3c3c9` | 删 `bin/sound/gameNN.mid`，加 `bin/sound/gameNN.opus` | `src/sdlfun.c` 从 `MIX_INIT_MID` 改 `MIX_INIT_OPUS`，并删掉整段 SoundFont 探测代码 |
| `e0d7a62` | opus → ogg（Lavf60 / libvorbis 112 kbps） | `ffprobe` 显示 `encoder=Lavc60.31.102 libvorbis`；时长与 opus 完全一致（53.5975 s） |

### 4. 转码留下了三类可测损伤

用 `ffmpeg -af ebur128/astats` 测 25 首：

| 指标 | 旧 OGG | 说明 |
|---|---|---|
| 真峰值 > 0 dBFS | **15/25**，最高 **+3.20 dBFS** | 硬削波，最刺耳的主因 |
| 整轨响度 | **-26.1 .. -7.9 LUFS**（跨度 **18.2 dB**） | 换场景忽大忽小 |
| OGG/MIDI 时长比 | 1.034 .. **1.212** | 尾部静音 3~5 s + 速度偏移 |
| `game01` <200 Hz 能量占比 | **77.6%**（真实渲染 40.6%） | 发闷、糊 |

## Decisions

### ADR-1：从 MIDI 母带重渲染，而不是从 opus 重新编码

**Context**：三条候选路径。

| 方案 | 成本 | 结果 |
|---|---|---|
| A. 从 `bak/sound/*.opus` 重新编码 | 最低 | 保留 opus 阶段的损伤（峰值已 +3.2 dBFS），只换容器 |
| B. 从 MIDI 母带重渲染 | 需 fluidsynth+SoundFont（仅构建期） | 回到无损源，可同时修削波/响度/尾静音 |
| C. 运行时直放 MIDI | 零构建 | LÖVE 的 libmodplug **忽略 SoundFont**（已实测：换 `mid.sf2`/`FluidR3` 输出 md5 不变），音色更差 |

**Decision**：选 B。MIDI 母带无损、且与用户认可的版本逐字节相同，是唯一能回到
「原版听感」的源。

**Consequences**：
- 仓库 +7 MB（20 MB → 27 MB）
- 构建期需要 fluidsynth（但产物已提交，**运行时不需要**）
- 音色库 `mid.sf2` 在 gitignore 的 `reference/` 里，脚本需给出清晰报错

### ADR-2：默认音色库用原版 `mid.sf2`，不用 FluidR3_GM

**Context**：手头有两个 SoundFont，A/B 实测差异明显。

| 音色库 | 体积 | game01 <200 Hz | game01 1~4 kHz | 主观 |
|---|---|---|---|---|
| `mid.sf2`（Roland GS 16-bit） | 3.26 MB | 40.6% | 26.1% | 与 kys-pascal 一致 |
| `FluidR3_GM.sf2` | 148 MB | 22.1% | 24.8% | 更亮更「干净」，但音色不同 |

**Decision**：默认 `mid.sf2`。用户认可的参照系就是它；换 FluidR3 属于**改风格**
而不是**修 bug**。`SF2=` 环境变量保留替换能力。

**Negative Constraint**：不得为了「听起来更现代」而改默认音色库——那是产品决策，
不是缺陷修复。

### ADR-3：两遍 loudnorm，目标 -16 LUFS / -2.0 dBTP

**Context**：旧产物的响度差是**逐曲不同**的（-26.1 到 -7.9），统一增益解决不了。
而单遍 `loudnorm` 会做动态压缩，可能改变音乐动态。

**Decision**：两遍法（先 `print_format=json` 测量，再 `linear=true` 应用）。
`linear=true` 让 ffmpeg 在可能时只做线性增益，不做动态处理。

目标真峰值取 **-2.0 dBTP** 而非 -1.0：实测 libvorbis 编码会再抬 0.3~0.6 dB。
设 -2.0 后成品稳定 ≤ -1.5 dBTP，门禁阈值 -1.0 才有余量。

**Consequences**：实测响度跨度 **1.90 LU**（-16.4..-14.5 LUFS），真峰值最高 **-1.3 dBTP**。

### ADR-4：OGG 质量档从 3 提到 4（配合 32 kHz）

**Context**：旧产物 112 kbps（q3 附近）。重渲染时 `libvorbis -q:a` 直接控制码率。

**Decision**：32 kHz 下用 **q4**（实测 25 首合计 20.1 MB，约 110-160 kbps，
视曲目复杂度）。这是**刻意的体积/质量取舍**：本次目标就是修音质，继续用
「能省则省」的档位是自相矛盾；但也不必用 q5（26.3 MB，与 q4 客观同档，
见 ADR-5）。

**Consequences**：若后续需要更省体积，`OGG_QUALITY=3` 可到 17.2 MB
（代价：SNR 掉 2.7 dB）；若要更高保真，`SAMPLE_RATE=48000 OGG_QUALITY=5`。

### ADR-5：采样率降到 32 kHz（不是 48 kHz）

**Context**：48 kHz q5 是「保险」选择，但代价是 26.3 MB。真实需求是多少？

解析原版音色库 `reference/allmods/kys-pascal/music/mid.sf2` 的 `shdr` 样本头：

```
492/495 个样本 = 22050 Hz
  3/495 个样本 = 24000 Hz
```

FluidSynth 合成的上限因此只有约 11 kHz。母带实测印证（25 首，`highpass=11k` 后
相对全带 RMS）：**-26.4 dB（最亮）.. -67.9 dB（game13 纯低频），平均约 -33 dB**。
即 48 kHz 容器里 11~24 kHz 装的基本是重采样镜像与量化噪声。

**Decision**：渲染与编码都用 32 kHz（Nyquist 16 kHz，远高于内容上限 11 kHz）。

**实测对比**（6 首代表曲，逐频段比 + 逐样本 SNR）：

| 参数 | 平均 SNR | 频谱形状偏差（平均/最差） | 25 首合计 |
|---|---|---|---|
| 48 kHz q5 | 24.62 dB | 0.26 / 1.59 dB | 26.3 MB |
| **32 kHz q4** | 23.71 dB | **0.57 / 1.44 dB** | **20.1 MB** |
| 32 kHz q3 | 21.96 dB | 0.67 / 1.35 dB | 17.2 MB |
| 24 kHz q6 | 22.23 dB | — | 15.5 MB |
| 22.05 kHz q6 | 22.33 dB | — | 16.0 MB |

**Consequences**：
- 体积比 48 kHz q5 少 23%（26.3 → 20.1 MB），比旧档（19.4 MB）只多 0.7 MB
- 频谱形状偏差与 48 kHz 同档；32k q3 省 3 MB 但要付 2.7 dB SNR，不划算
- 24/22 kHz 更差（重采样把 11 kHz 附近内容也削掉了）

### ADR-6：母带不入 git，用清单 + 多路回溯恢复

**Context**：用户要求「不要把音乐资源提交，避免仓库变大」。但母带是重渲染的唯一
真源，删了就再也修不了音质。25 个母带只有 304 KB，但既然有 `reference/` 与 git
历史两条现成来源，就不必入库。

**Decision**：
1. `.gitignore` 加 `game/sound/*.mid`
2. `tools/base-music-manifest.tsv` 记录 25 首的 `md5 / 来源路径 / MIDI 时长`
3. `render-base-music.sh` 的 `ensure_master()` 三级现取：
   `game/sound/gameNN.mid` → 清单里的 `reference/allmods/...` → git 历史

**关键实现细节**：git 历史回溯**不能**用 `git log -1 -- <path>`——它会做历史简化，
把「删除该文件」的那次提交当作终点返回，而那次提交里文件已不存在，`cat-file`
必然失败。必须用：

```bash
git rev-list --all --full-history -- "$path"   # 列出所有触及该路径的提交
# 然后逐个 cat-file -e / show，取第一个成功的
```

路径要兼容历史布局：`bin/sound/` 与 `src/sound/`、`.mid` 与 `.MID`。

**Consequences**：在**历史被重写（SHA 全变）**的仓库里实测全量渲染，25/25 母带
全部自动恢复。

### ADR-7：历史清理用 filter-repo，且必须保留 MIDI

**Context**：旧提交里躺着 50 个压缩音频 blob（`game/sound/*.ogg` 19.4 MB、
`bak/sound/*.opus` 25.0 MB、更早的 `src/sound/*.ogg` 19.4 MB），`.git` 88 MB。

**Decision**：`tools/purge-audio-history.sh` 用 `git-filter-repo` 按
`--path-glob=*.ogg --path-glob=*.opus --path-glob=*.mp3 --path=bak` 清理。
**刻意不碰 `.mid` / `.MID` / `.wav`**——那是母带与音效，体积小且是重渲染的依据。

**Consequences**（镜像实测）：`.git` **108 MB → 16 MB**，音频 blob **50 → 0**，
提交数 604 → 603（少的是 `5b8ca8e move unused sound files to bak/`，
改动 100% 是移动音频，清完变空提交被 filter-repo 自动剪掉）。

代价：所有 SHA 改变，协作者必须重新 clone，远程要 force push。

## Negative Constraints

1. **不得**把 `game/sound/*.mid` 提交进 git（用户明确要求，避免仓库膨胀）。
2. **不得**为了体积把质量降到 32k q3 以下（实测 SNR 掉 2.7 dB，得不偿失）。
3. **不得**改动 `MUSIC_EXTS` 探测顺序：`.ogg` 优先是既有正确行为。
4. **不得**引入运行时 FluidSynth 依赖：仍然是「播放预渲染文件」。
5. **不得**在 `framework/` 里加任何音频特判：`framework/` 必须引擎无关。
6. **不得**在历史清理时一并删掉 `bin/sound/*.mid` / `src/sound/*.MID`——那是母带。
7. **不得**用 `git log -- <path>` 做母带历史回溯（见 ADR-6 的坑）。

## Review Checklist

- [x] 清单 25 行、每行 4 列、md5 32 位
- [x] `game/sound` 无 `.mid` 残留
- [x] 清单来源 md5 校验通过 24/24（game25 走 git 历史）
- [x] OGG 采样率 25/25 = 32000 Hz
- [x] OGG/母带时长比全部 ∈ [0.90, 1.15]，最大偏离 0.0774（game16）
- [x] 真峰值 25/25 ≤ -1.0 dBTP（最高 -1.3）
- [x] 响度跨度 1.90 LU（-16.4..-14.5 LUFS）
- [x] 负向对照：旧 OGG → 3 项 FAIL；残留 .mid → 1 项 FAIL
- [x] 在历史被重写的仓库里全量渲染成功（25/25 母带自动恢复）
- [x] Lua 5.1 3022/0、5.3 3022/0、5.4 3022/0、5.5 3021/0
- [x] LÖVE 11.5 能解码 32 kHz OGG（`newSoundData` + `newSource stream`）
