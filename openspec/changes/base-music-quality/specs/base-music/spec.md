## ADDED Requirements

### Requirement: REQ-BGM-1 母带清单必须完整且母带入 git 受禁

`tools/base-music-manifest.tsv` SHALL 记录 25 首原版 BGM 的母带信息，每行 4 列：
`<曲目>\t<md5>\t<来源路径>\t<MIDI时长秒>`。MIDI 母带本身 SHALL NOT 出现在
`game/sound/` 的 git 跟踪文件里（`.gitignore` 已含 `game/sound/*.mid`）。

#### Scenario: 清单完整
- **WHEN** 统计清单中非注释行
- **THEN** 恰好 25 行，且每行 4 列、md5 为 32 位十六进制、时长为 20~130 秒

#### Scenario: game/sound 无母带残留
- **WHEN** `find game/sound -name 'game*.mid'`
- **THEN** 输出为空

#### Scenario: 负向对照——残留母带必须被发现
- **WHEN** 往 `game/sound/` 放入一个 `game01.mid` 后运行门禁
- **THEN** 输出 `[FAIL] game/sound 残留 1 个 .mid（母带不应入 git）`，退出码非 0

### Requirement: REQ-BGM-2 清单来源必须可校验

对清单里来源路径不为 `-` 的行，若本地存在该文件，其 md5 SHALL 与清单一致。
该断言保证「母带没被换掉」——否则重渲染出来的就不是用户认可的那一版音色。

#### Scenario: 24 首 reference 来源全部校验通过
- **WHEN** 对清单里 `reference/allmods/...` 的 24 行逐一算 md5
- **THEN** 24/24 与清单一致（`game25` 的来源是 `-`，走 git 历史，不参与本断言）

#### Scenario: 本地没有 reference 时优雅跳过
- **WHEN** `reference/` 目录不存在（新 clone 的常见状态）
- **THEN** 断言输出 `[SKIP] 本地没有 reference/allmods`，不计为失败

### Requirement: REQ-BGM-3 OGG 时长必须贴近母带时长

每首 OGG 的时长 SHALL 落在清单记录的母带时长的 `[0.90, 1.15]` 倍区间内。
该区间用于捕获两类真实损伤：尾部静音（旧产物多出 3~5 s）与整轨速度偏移
（旧产物最长偏 21.2%）。

母带时长取自清单第 4 列（由 `tools/midiinfo.lua` 按 tempo map 预先算好），
因此该断言**不需要母带在盘上**，也不需要 lua 或 ffmpeg 之外的依赖。

#### Scenario: 重渲染产物全部在区间内
- **WHEN** 对 25 首逐一计算 `ogg 时长 / 清单母带时长`
- **THEN** 全部落在 `[0.90, 1.15]`，实测最大偏离 0.0774（game16）

#### Scenario: 负向对照——旧转码产物必须越界
- **WHEN** 把旧的转码 `game08.ogg` 装回
- **THEN** 该首判 `[FAIL] game08: ogg=33.793750s midi=27.882s ratio=1.2120`，
  门禁退出码非 0

### Requirement: REQ-BGM-4 真峰值不得超过 -1.0 dBTP

每首 OGG 的真峰值 SHALL ≤ -1.0 dBTP（EBU R128 真峰值）。旧产物有 15/25 首
> 0 dBFS，最高 +3.20 dBFS —— 硬削波，是「听起来糟糕」的首要原因。

#### Scenario: 重渲染产物全部达标
- **WHEN** 用 `ebur128=peak=true` 测量 25 首
- **THEN** 全部 ≤ -1.0 dBTP，实测最高 -1.3 dBTP

#### Scenario: 负向对照——旧产物必须超标
- **WHEN** 把旧的转码 `game08.ogg` 装回
- **THEN** 输出 `[FAIL] game/sound/game08.ogg 真峰值 2.7 dBTP > -1.0`

### Requirement: REQ-BGM-5 曲目间响度跨度不得超过 4 LU

25 首曲目的整轨响度（EBU R128 integrated）SHALL 落在跨度 ≤ 4 LU 的区间内。
旧产物跨度 18.2 dB（-26.1 .. -7.9 LUFS），导致「换场景时忽大忽小」。

#### Scenario: 重渲染产物响度一致
- **WHEN** 测量 25 首的 integrated loudness
- **THEN** 跨度 ≤ 4 LU，实测 **1.90 LU**（-16.4 .. -14.5 LUFS）

### Requirement: REQ-BGM-6 编码参数必须为 32 kHz / q4

所有 OGG SHALL 为 **32000 Hz** 立体声 Vorbis。理由（见 design.md ADR-5）：
原版音色库 `mid.sf2` 的 `shdr` 样本头里 **492/495 个是 22050 Hz**，合成上限
约 11 kHz；母带 >11 kHz 的能量在 -26..-68 dB（平均 -33 dB）。48 kHz 容器里
11~24 kHz 装的基本是重采样镜像与噪声，纯属浪费体积。

#### Scenario: 抽样检查采样率
- **WHEN** 读 `game/sound/game01.ogg` 的 vorbis 识别头
- **THEN** 采样率为 32000

#### Scenario: 单元测试守住采样率不回升
- **WHEN** 运行 `lua tests/test_runner.lua base_music`
- **THEN** `testOggIsVorbisStereo32k` 通过（若有人改回 48 kHz 会失败）

### Requirement: REQ-BGM-7 重渲染脚本必须保持关键参数

`tools/render-base-music.sh` SHALL 同时保留：去尾部静音（`silenceremove`）、
响度归一化（`loudnorm`）、默认音色库 `mid.sf2`、`libvorbis` 编码、显式的
`SAMPLE_RATE`、以及 `ensure_master`（母带自动恢复）。任何一项缺失都会让上述
性质退化。

#### Scenario: 脚本语法正确
- **WHEN** 执行 `bash -n tools/render-base-music.sh`
- **THEN** 退出码 0

#### Scenario: 六段关键参数都在
- **WHEN** grep 脚本内容
- **THEN** 同时含 `silenceremove`、`loudnorm`、`mid.sf2`、`libvorbis`、
  `SAMPLE_RATE=`、`ensure_master`

### Requirement: REQ-BGM-8 母带必须能从历史被重写后的仓库恢复

`render-base-music.sh` 的 `ensure_master()` SHALL 在 `game/sound/gameNN.mid`
不存在时，依次尝试清单来源与 git 历史。git 历史回溯 SHALL 使用
`git rev-list --all --full-history -- <path>`（不能用 `git log -1 -- <path>`，
见 design.md ADR-6），且路径需兼容 `bin/sound/` 与 `src/sound/`、`.mid` 与 `.MID`。

#### Scenario: 在已清理历史的镜像里全量渲染
- **WHEN** 在 filter-repo 重写过的仓库（所有 SHA 已变、`game/sound/*.ogg` 已清空）
  里执行 `./tools/render-base-music.sh`
- **THEN** 25/25 母带全部自动恢复，25 首 OGG 全部重渲染成功

#### Scenario: 母带确实取不到时给出可操作的报错
- **WHEN** 清单来源与 git 历史都没有某首母带
- **THEN** 输出 `[warn] <曲目>: 找不到母带（清单来源与 git 历史都没有）` +
  `[warn] 手工放置：cp <某个 .mid> game/sound/<曲目>.mid`，并以非 0 退出

### Requirement: REQ-BGM-9 运行时零改动即可生效

`lib_love.lua` 的 `MUSIC_EXTS` 探测顺序 SHALL 保持 `.ogg → .mp3 → .mid`，
重渲染后的 OGG 自动优先播放，不新增任何运行时代码分支、不引入运行时 FluidSynth
依赖。

附带事实：`CC.MIDIFile = CONFIG.SoundPath .. "game%02d.ogg"` **已带扩展名**，
`resolveMusicFile` 对带扩展名的路径原样返回，**不会回退到 `.mid`**。所以原版
曲目只有 OGG 一条路；`.mid` 兜底只在 MOD 路径（`mod_data.lua` 改写为去扩展名的
stem）下生效。这与「`game/sound` 只留 OGG」完全一致。

#### Scenario: 探测顺序未变
- **WHEN** 检查 `lib_love.lua` 的 `MUSIC_EXTS`
- **THEN** 仍为 `{ ".ogg", ".mp3", ".mid" }`

#### Scenario: LÖVE 能解码 32 kHz OGG
- **WHEN** 用 `love.sound.newSoundData` 加载 25 首
- **THEN** 25/25 成功，采样率 32000、声道 2；`love.audio.newSource(..., "stream")`
  也能创建并播放

### Requirement: REQ-BGM-10 历史清理必须保留 MIDI 母带与音效

`tools/purge-audio-history.sh` 的清理规则 SHALL 只移除压缩音频
（`*.ogg` / `*.opus` / `*.mp3`）与 `bak/` 目录，SHALL NOT 移除
`bin/sound/*.mid`、`src/sound/*.MID`（母带）与 `game/sound/*.wav`（音效）。

#### Scenario: dry-run 后母带仍在
- **WHEN** 在镜像克隆上执行 `--dry-run`
- **THEN** 清理后历史里仍有 24 个 `bin/sound/*.mid`，且 `src/sound/game25.MID`
  可按路径取回（md5 与清单一致）

#### Scenario: 体积与音频 blob 数
- **WHEN** 同上
- **THEN** 报告 `.git` 从 108 MB 降到 16 MB，音频 blob 从 50 降到 0
