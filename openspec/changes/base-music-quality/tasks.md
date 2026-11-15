---
status: active
created: 2026-11-15
---
# Tasks: base-music-quality

## Blast Radius

**代码/文档（入库）**
```
tools/render-base-music.sh        新增
tools/midiinfo.lua                新增
tools/base-music-manifest.tsv     新增（母带 md5/来源/时长清单）
tools/purge-audio-history.sh      新增（历史清理工具）
game/tests/gate_base_music.sh     新增
game/tests/unit/test_base_music.lua  新增
game/tests/test_runner.lua        仅注册新套件
tools/README.md                   增补两个音频工具说明
openspec/changes/base-music-quality/  本 change
.gitignore                        + game/sound/*.mid
```

**资源（入库，但受体积约束）**
```
game/sound/game01..25.ogg         替换为 32 kHz q4（20.1 MB，+0.7 MB）
```

**删除**
```
bak/sound/                        26 MB（25 个坏 opus + 1 个重复 MIDI）
```

**禁止触碰**：`game/engine-love2d/*`、`game/framework/*`、`game/script/*`、
`tools/render-music.sh`（MOD 侧）、`.github/workflows/*`。

## Task 1 — 诊断（已完成，证据见 proposal.md）✅

- [x] 证明两边是同一批 MIDI（23/25 精确 md5 命中）
- [x] 证明原版用 FluidSynth + `mid.sf2`（kys.exe 内嵌字符串）
- [x] 量化旧 OGG 的三类损伤（15/25 削波、18.2 dB 响度差、77.6% 低频堆积）
- [x] 证明 `bak/sound/*.opus` 与坏 OGG 同源（同样 15/25 削波、18.2 dB 跨度）

## Task 2 — 体积最优化（本次新增，用户要求 2）✅

**发现**：解析 `mid.sf2` 的 `shdr` 样本头 —— **492/495 个样本是 22050 Hz**，
3 个是 24000 Hz。FluidSynth 合成上限因此只有约 11 kHz。母带实测印证：
25 首里 >11 kHz 的相对能量在 -26 dB..-68 dB，平均约 -33 dB。即 48 kHz 容器里
11~24 kHz 装的基本是重采样镜像与量化噪声。

**同一把尺子量**（6 首代表曲逐频段比对 + 逐样本 SNR）：

| 参数 | 平均 SNR | 频谱形状偏差（平均/最差） | 25 首合计 |
|---|---|---|---|
| 48 kHz q5 | 24.62 dB | 0.26 / 1.59 dB | 26.3 MB |
| **32 kHz q4** | 23.71 dB | **0.57 / 1.44 dB** | **20.1 MB** |
| 32 kHz q3 | 21.96 dB | 0.67 / 1.35 dB | 17.2 MB |
| 24 kHz q6 | 22.23 dB | — | 15.5 MB |
| 22.05 kHz q6 | 22.33 dB | — | 16.0 MB |
| 旧 48 kHz q3（已提交） | 21.23 dB | — | 19.4 MB |

**结论**：32 kHz q4 的频谱形状偏差与 48 kHz q5 同档（甚至更小，因为省下的
码率被用在了有内容的 0~16 kHz），体积少 23%。再往下（q3 / 24k / 22k）开始
实质掉音质。**选 32 kHz q4：20.1 MB（比原来只多 0.7 MB）。**

**DoD**：`ffprobe` 显示 25/25 首为 `32000 Hz`；母带 11~14 kHz 频段偏差 < 1 dB。

## Task 3 — 母带不入 git（用户要求 1、3）✅

- [x] `.gitignore` 增加 `game/sound/*.mid`
- [x] `tools/base-music-manifest.tsv` 记录 25 首的 md5 / 首选来源 / MIDI 时长
- [x] `render-base-music.sh` 的 `ensure_master()` 按以下顺序现取母带：
  1. `game/sound/gameNN.mid`（手工放的，优先级最高）
  2. 清单里的 `reference/allmods/kys-*/music/*.mid`（已 gitignore）
  3. git 历史（`rev-list --full-history` 回溯，路径兼容 `bin/sound` 与 `src/sound`、
     大小写 `.mid`/`.MID`）

**实测**：在**已清理历史**的镜像（SHA 全变）里跑 `./render-base-music.sh`（全量），
25/25 母带全部自动恢复，25 首 OGG 全部重渲染成功。

**关键坑**：`git log -1 -- <path>` 会做历史简化，把「删除该文件」的提交当作终点
返回，而那次提交里文件已不存在 → `cat-file` 必然失败。必须用
`git rev-list --all --full-history -- <path>` 列出所有触及该路径的提交再逐个试。

## Task 4 — 删除 bak/sound（用户要求 4）✅

- [x] 实测 25 个 opus：真峰值 > 0 dBFS 的有 **15/25**（最高 +3.20），响度跨度
      **18.2 dB** —— 与坏 OGG 同源同损
- [x] 唯一的非 opus 文件 `game25.MID` 在 git 历史里也有（md5 完全一致，
      可从 `bin/sound/game25.MID` 与 `src/sound/game25.MID` 两处取回）
- [x] 删除整个 `bak/sound/`（26 MB）

**DoD**：`ls bak` 不存在；`git status` 显示 26 个 D。

## Task 5 — 脚本与门禁 ✅

- [x] `tools/render-base-music.sh`：FluidSynth → silenceremove → 两遍 loudnorm
      → libvorbis q4 @ 32 kHz；支持全量 / 指定曲目 / `--list`
- [x] `tools/midiinfo.lua`：纯 Lua MIDI 探针（tempo map 积分算时长）
- [x] `game/tests/gate_base_music.sh`：6 组断言
  - 清单完整性（25 行、每行 4 列、`game/sound` 无 `.mid` 残留）
  - 清单来源 md5 校验（本地有 reference 时）
  - OGG/母带时长比 ∈ [0.90, 1.15]（母带时长取自清单，不需要母带在盘上）
  - 真峰值 ≤ -1.0 dBTP
  - 整轨响度跨度 ≤ 4 LU
  - 渲染脚本参数在位（silenceremove / loudnorm / mid.sf2 / libvorbis /
    SAMPLE_RATE / ensure_master）
- [x] `game/tests/unit/test_base_music.lua`：87 条纯 Lua 断言，四版本都能跑

**DoD**：门禁 `[ ok ] 全部通过（跳过 0 项）`；单测 87/87。

## Task 6 — 负向对照 ✅

- [x] 装回旧 `game08.ogg` → 门禁报 3 项失败：
      时长比 1.2120 越界、真峰值 +2.7 dBTP、响度跨度 8.50 LU
- [x] 往 `game/sound` 里塞一个 `.mid` → 门禁报
      `[FAIL] game/sound 残留 1 个 .mid（母带不应入 git）`
- [x] 恢复后重新全绿

## Task 7 — git 历史清理（用户要求 5）✅ 工具就绪，待用户执行

- [x] `tools/purge-audio-history.sh`（`--dry-run` / `--apply`）
- [x] **dry-run 实测**（镜像克隆上跑）：
      **108 MB → 16 MB**，音频 blob **50 → 0**，提交数 603（原 604，
      少的那一个是 `5b8ca8e move unused sound files to bak/`，
      它的改动 100% 是移动音频，清完变空提交被自动剪掉）
- [x] 清理规则：`--path-glob=*.ogg --path-glob=*.opus --path-glob=*.mp3 --path=bak`
      （按扩展名与目录，覆盖历史每一代产物）
- [x] 保留：`bin/sound/*.mid`（24 首母带）、`src/sound/*.MID`（含 game25）、
      `game/sound/*.wav`（1.1 MB 音效）
- [x] 脚本内置安全检查：工作树必须干净、默认先做 `--mirror` 备份、给出
      force-push 与「协作者必须重新 clone」的完整提示

**这一步需要用户手动执行**（会重写历史、覆盖远程）：
```bash
./tools/purge-audio-history.sh --dry-run    # 先看体积
./tools/purge-audio-history.sh --apply      # 真执行
./tools/render-base-music.sh                # 重新生成 32k q4 ogg
git add game/sound/*.ogg && git commit -m "audio: 32k q4 重渲染"
git push --force --all && git push --force --tags
```

## Task 8 — 四版本 Lua + LÖVE 回归 ✅

- [x] Lua 5.1：**3022** 通过 / 0 失败
- [x] Lua 5.3：**3022** 通过 / 0 失败
- [x] Lua 5.4：**3022** 通过 / 0 失败
- [x] Lua 5.5：**3021** 通过 / 0 失败
- [x] `luac5.1 -p` / `luac55 -p` 全部 0 错误
- [x] LÖVE 11.5 能解码 32 kHz OGG（`newSoundData` + `newSource stream` 都正常）
- [x] `gate_ascii.sh` 通过

## 后续（不在本 change 范围）

- [ ] 用户执行 Task 7 的 `--apply` 并 force push
- [ ] 归档：`/openspec-archive-change base-music-quality`
- [ ] 可选：CI 接入 `render-base-music.sh`（runner 需装 fluidsynth + mid.sf2）
