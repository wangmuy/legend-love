# tools/

开发辅助脚本（不属于游戏运行时，不被 game/ 代码 require）。
解码逻辑均与 `game/engine-love2d/lib_love.lua` 的对应实现保持一致，调查期一次性脚本已清理。

## 通用工具

### smap_tool.lua — grp 贴图提取与排查（纯 Lua）

idx 条目为图结束偏移（小端 u32），显示 picid → 图序号 `slot = floor(picid/2)`，
帧头 `w,h(u16) xoff,yoff(i16)`，RLE 逐行（trans/solid/调色板索引），
调色板 `mmap.col`（256×3 字节，0..63 → ×4）。

```bash
# 提取帧为 P6 PPM（真实调色板 RGB；--gray 输出调色板索引灰度，便于 diff）
lua tools/smap_tool.lua extract game/data <outdir> 6890 6932 4988 [--gray]

# 在 grp 偏移附近寻找有效帧头（排查 idx 映射时）
lua tools/smap_tool.lua scan game/data 1228382 [半径=400]

# 按偏移十六进制 dump
lua tools/smap_tool.lua hexdump game/data 1 3009849 [--len 32]

# 打印 idx 条目与帧头（slot 为 0-based 图序号 = 显示 picid/2）
lua tools/smap_tool.lua entries game/data 3445 3466
```

### sdata_tool.lua — 子场景 S*/D* 数据排查（纯 Lua）

直接读 base 模板数据 `allsin.grp`/`alldef.grp`，与 `LoadSMap/GetS/GetD` 索引公式一致：
S 每格 i16（level 3 = 事件层，≥0 表示该格挂着 D* 实体）；D 每实体 11 个 i16 字段。

```bash
# 单格: 6 层数据 + 邻域 level3 网格（半径可调）
lua tools/sdata_tool.lua tile game/data 70 19 20 [半径=2]

# 打印某个 D* 的全部或指定字段
lua tools/sdata_tool.lua dentity game/data 70 0 [字段i...]

# 列出场景内 level 值 >= min 的所有 tile
lua tools/sdata_tool.lua find game/data 70 [level=3] [min=0]
```

### scene_tool.lua — 子场景 S*/D* 数据排查（纯 Lua）

直接读 base 模板数据 `allsin.grp`/`alldef.grp`，与 `LoadSMap/GetS/GetD` 索引公式一致：
S 每格 i16（level 3 = 事件层，≥0 表示该格挂着 D* 实体）；D 每实体 11 个 i16 字段
（2/3/4 = 空格/物品/路过触发事件号，9/10 = 实体坐标）。

```bash
# 单格: S 层 0-5 值 + 挂接实体的全部 D 字段
lua tools/scene_tool.lua tile game/data 70 19 20

# 打印场景(或区域)某层 S 数据网格
lua tools/scene_tool.lua dump game/data 70 3
lua tools/scene_tool.lua dump game/data 70 3 17 18 23 22

# 列出场景全部有效 D* 实体（坐标/不可通过/三类触发事件号/动画帧范围）
lua tools/scene_tool.lua ents game/data 70

# 打印 ranger.grp 新游戏 base 段基础字段（乘船/人X/人方向/队伍...）
lua tools/scene_tool.lua base game/data
```

### render_frames.py — grp 帧渲染为 PNG（Python + Pillow）

任意前缀的 grp/idx 都能渲染（smap/mmap/fightNNN/wmap/thing...），
输出透明 PNG + 白底 `_white.png`，并打印不透明像素 bbox。

```bash
python3 tools/render_frames.py game/data <outdir> 6890 6932 4988          # smap 贴图
python3 tools/render_frames.py game/data <outdir> 1000 --prefix mmap      # 主地图贴图
python3 tools/render_frames.py game/data <outdir> 6890 --scale 4          # 放大 4 倍
```

> 无 Pillow 时可用 `smap_tool.lua extract` 出 PPM 再自行转 PNG。

### trace_global.lua — 游戏内全局状态时序追踪

在 game/ 代码的写点插入一行 `TRACE.log("tag")`，按帧时序记录目标全局变量快照，
用于定位"谁在什么时候改了 X"。启用配方见 `examples/trace_mypic_demo.lua`
（以追踪 JY.MyPic 的开场卧姿调查为例，3 步照抄即可用）。
`demo/trace_mypic_demo.lua` 是独立可运行示例（模拟开场时序，无需 Love2D/游戏数据）：

```bash
lua tools/demo/trace_mypic_demo.lua   # 输出并打印 tools/trace_out.txt
```

```lua
-- 需在 package.path 含仓库根目录: package.path = ... ";/path/to/legend-love/?.lua"
local TRACE = require "tools.trace_global"
TRACE.fields = {  -- 惰性求值，log 时调用
    MyPic = function() return JY.MyPic end,
    dir   = function() return JY.Base["人方向"] end,
}
TRACE.log("startNewGame:348")  -- 调用点
```

输出 `tools/trace_out.txt`（每次加载清空重记）；不受 CONFIG.Debug 控制，
调查完成后请移除调用点。

#### demo/trace_mypic_demo.lua — 可运行 demo

`lua tools/demo/trace_mypic_demo.lua`（任意目录，无需 Love2D / 游戏数据），
模拟开场卧姿调查的写点时序并打印 `tools/trace_out.txt` 输出，
用于快速验证 trace_global 工作方式；真实用法仍见上方启用配方。

## 音频工具

### midiinfo.lua — MIDI 探针（纯 Lua，无外部依赖）

按 RFC 解析 `MThd`/`MTrk`、变长 delta-time、running status，
再用 tempo map 精确积分出时长（`Σ delta_tick × us_per_quarter ÷ division`）。

```bash
lua tools/midiinfo.lua game/sound/game01.mid                # 表格：fmt/trk/div/ticks/时长/音符数/音色
lua tools/midiinfo.lua --duration game/sound/game01.mid     # 只打印秒数（49.610）
lua tools/midiinfo.lua --json game/sound/*.mid              # JSON 数组
```

刻意不使用 Lua 5.3 位运算符，5.1 可直接跑。

### base-music-manifest.tsv — 母带清单（母带本身不入 git）

原版 25 首 BGM 的 **MIDI 母带不提交进 git**（避免仓库膨胀）。本清单记录每首的
`md5` / 首选来源路径 / MIDI 时长，`render-base-music.sh` 据此自动恢复母带：

1. `game/sound/gameNN.mid`（手工放的，优先级最高）
2. 清单里的 `reference/allmods/kys-*/music/*.mid`（该目录已 gitignore）
3. git 历史（`rev-list --full-history` 回溯，兼容 `bin/sound` 与 `src/sound`、`.mid`/`.MID`）

**实测**：在历史被重写（SHA 全变）的仓库里跑全量渲染，25/25 母带都能自动找回。

### render-base-music.sh — 原版 BGM 重渲染（FluidSynth + SoundFont）

**为什么需要**：`game/sound/game01..25.ogg` 原本是「渲染 → opus → ogg」两次有损
转码的产物，25 首里 15 首解码后真峰值 > 0 dBFS（最高 +3.20 dBFS），整轨响度跨度
18.2 dB，`game01` 有 77.6% 能量压在 200 Hz 以下。而原版 Pascal（kys-pascal）是
FluidSynth + 自带 `mid.sf2` 实时合成——它的 `music/1..23.mid` 与本仓库原版 MIDI
母带**逐字节相同**。所以要修的是**渲染链**，不是曲子。

```bash
./tools/render-base-music.sh                # 全量 25 首
./tools/render-base-music.sh game01 game07  # 指定曲目
./tools/render-base-music.sh --list         # 报告现状（OGG / 本地母带 / 恢复来源）
SF2=/path/to/x.sf2 SAMPLE_RATE=48000 ./tools/render-base-music.sh   # 换音色库/采样率
```

链路：`fluidsynth` → `silenceremove`（去 3~5 s 尾静音）→ 两遍 `loudnorm`
（-16 LUFS / ≤ -2.0 dBTP，`linear=true` 优先不压缩）→ `libvorbis -q:a 4` @ **32 kHz**。

**为什么是 32 kHz**：解析原版音色库 `mid.sf2` 的 `shdr` 样本头，**492/495 个样本
是 22050 Hz**，合成上限只有约 11 kHz；母带实测 >11 kHz 的能量在 -26..-68 dB（平均
-33 dB）。48 kHz 容器里 11~24 kHz 装的基本是重采样镜像与噪声。同一把尺子量：

```
48 kHz q5   频谱形状偏差 0.26 dB   25 首 26.3 MB
32 kHz q4   频谱形状偏差 0.57 dB   25 首 20.1 MB   ← 默认
32 kHz q3   频谱形状偏差 0.67 dB   25 首 17.2 MB   （SNR 掉 2.7 dB，不划算）
```

产物覆盖 `game/sound/gameNN.ogg`，**母带不保留**（下次从清单再取）。
运行时不需要 fluidsynth——游戏仍只播预渲染 OGG，`MUSIC_EXTS` 探测顺序不变。

回归门禁：`sh game/tests/gate_base_music.sh`（6 组断言，含负向对照）。

### purge-audio-history.sh — 把音乐资源从 git 历史彻底移除

⚠️ **破坏性操作**：重写所有提交 SHA，协作者必须重新 clone，远程要 force push。

```bash
./tools/purge-audio-history.sh --dry-run   # 在镜像克隆上试跑，只报告体积
./tools/purge-audio-history.sh --apply     # 真的重写当前仓库
```

规则：移除 `*.ogg` / `*.opus` / `*.mp3` 与整个 `bak/`；保留 `bin/sound/*.mid`、
`src/sound/*.MID`（母带）与 `game/sound/*.wav`（音效）。

**实测**（镜像上跑过）：`.git` **108 MB → 16 MB**，音频 blob **50 → 0**。
提交数 604 → 603（少的是 `5b8ca8e move unused sound files to bak/`，
改动 100% 是移动音频，清完变空提交被自动剪掉）。

## verify-cloud/ — 主地图飘云运行时取证

`probe` / `e2e` / `scroll` 三个独立 LÖVE 驱动 + 像素分析，证明云“真被画出来、
画在建筑与人物之上、与地形同步滚动、`MMAPAMI` 门控生效”。一键运行：

```bash
bash tools/verify-cloud/run.sh all
```

工作目录由脚本 `mktemp -d` 现场创建（**不在仓库里放 `data -> ../../data` 之类
的软链**：`7z a ./game/*` 会跟随软链，实测会把 `.love` 从 31M 顶到 809M）。
详见 [`verify-cloud/README.md`](verify-cloud/README.md)。

## 输出物

- `tools/trace_out.txt`（trace_global）— 已 gitignore
- 提取/渲染输出目录建议放仓库外（如 `/tmp/frames`）；历史调查输出
  `tools/frames/`、`tools/frames2/` 已 gitignore
