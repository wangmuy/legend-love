---
status: done
created: 2026-10-30
completed: 2026-10-30
parent_epic: 2026-10-allmods-compat
supersedes: allmods-slice15-music-ogg
---
# Proposal: allmods-midi-direct-play

## Why

581 条 `PENDING` 全是音频（`.mid 578` + `.mp3 2` + `.sf2 1`），是 allmods epic
最后一处未支持项。原计划（`allmods-slice15-music-ogg`）用 `timidity` + `ffmpeg`
把 41 个被引用的 `.mid` 转成 `.ogg`，成本为 **+36 MB 产物、5 分钟构建、两个外部二进制依赖**。

**用户提出关键质疑**：LÖVE 能否直接播 MIDI / MP3，不必转换？实测答案是**能**：

| 探测项 | 实测结果 |
|---|---|
| `love.audio.newSource("x.mid")` | ✅ 原生支持（LÖVE 内置 libmodplug） |
| `love.audio.newSource("x.mp3")` | ✅ 原生支持 |
| 抽样 40 `.mid` + 2 `.mp3` | **42/42 解码成功、42/42 真出声、0 静音** |
| MIDI 音量 | RMS 0.066–0.14、peak 0.4–0.48（现有 ogg RMS 0.19，同一量级） |

⇒ **改为直接播放，放弃转码方案**。成本降为 **+7.5 MB（578 个 mid 全部）、0 构建时间、0 外部依赖**。

## What Changes

| # | 改动 | 文件 |
|:-:|---|---|
| 1 | `PlayMIDI` / `PlayWAV` 路径解析修正 + 扩展名探测 + 内置回退 | `game/engine-love2d/lib_love.lua` |
| 2 | `music/` 重定向（新增 `MUSIC_DIR`） | `game/framework/mod_data.lua` |
| 3 | 构建期搬运 `music/` 并重命名 `game<id+1>.{mid,mp3}` | `game/tools/mod_build.lua` |
| 4 | 3 个单测 + 5 个构建测试（含 4 组负向对照） | `test_mod_data.lua` / `test_mod_build.lua` |

## 关键技术发现

### 发现 1：LÖVE 靠扩展名选解码器

| 实验 | 结果 |
|---|---|
| `fake.ogg`（内容是 MIDI） | ❌ `Could not read Ogg bitstream` |
| `fake2.mp3`（内容是 MIDI） | ❌ FAIL |
| `s2a.mid`（扩展名正确） | ✅ 出声 |

⇒ 不能「改名成 .ogg 混进去」。因 `CC.MIDIFile` 硬编码 `.ogg` 是禁改常量，
改为**去掉扩展名**交给引擎探测（`mod_data.lua` 里 strip `.ogg`）。

### 发现 2：既有的路径前缀 bug（本轮修掉）

`CONFIG.SoundPath = "sound/"`，而旧 `PlayMIDI` 只在不以 `sound/` 开头时加前缀。
MOD 重定向后的路径是 `mods/<slug>/sound/game27.ogg`，不以 `sound/` 开头 ⇒ 被错误拼成
`sound/mods/<slug>/sound/game27.ogg`（不存在），播放静默失败。

```
旧: mods/mingdong/sound/game27.ogg -> sound/mods/mingdong/sound/game27.ogg   ← 错
新: mods/mingdong/sound/game27.ogg -> mods/mingdong/sound/game27.ogg         ← 对
```

修正方式：只有**不含 `/` 的裸文件名**才加 `CONFIG.SoundPath` 前缀。

### 发现 3：`mid.sf2` 对 LÖVE 无效（推翻了转码方案的音色优势）

| cfg 写法 | 合成产物 |
|---|---|
| `bank 0` + 128 行 `%font "mid.sf2"` | md5 `bfeebf68…` |
| `bank 0` + 128 行 `%font "FluidR3_GM.sf2"` | md5 `bfeebf68…` ← **相同** |
| `soundfont "mid.sf2" order=0` | md5 `bfeebf68…` ← **相同** |

`MMPAT_PATH_TO_CFG` 确实被读取（`load_pat` 警告消失），但 LÖVE 的 libmodplug
**完全忽略自定义 SoundFont**，固定用内置精简 GM 音色。
⇒ 转码方案「用 MOD 自带音色库」的卖点在 LÖVE 上不成立，进一步支持直接播 MIDI。

### 发现 4：编号规则是 `music/<id>.mid`，非 `<id+1>`

引擎传 `id+1`（`jymain.lua:2162`）。哪个是文件名？证据：

| 证据 | 结论 |
|---|---|
| `<id>.mid` 命中 **348/368 = 94.6%**；`<id+1>.mid` 命中 **333/368 = 90.5%** | `<id>` 更优 |
| 多个 MOD 有 **`music/0.mid`** | 若按 `<id+1>`，id 会是 −1，**不可能** |
| 剩余 miss **全部**在 BookCalamity（引用 24–51，源只有 0–23） | 源数据缺陷，不是规则错 |

⇒ 构建期把 `music/<id>.mid` 重命名为 `game<id+1>.mid`，运行时零映射开销。

### 发现 5：单编号方案会让 BookCalamity 变差 → 必须内置回退

BookCalamity 引用 35 个 id，源侧只有 15 个能对应。若不处理，它的
`mods/BookCalamity/music/` 会**遮蔽**原本能播的 `sound/gameNN.ogg`，
从「16 首内置曲 + 19 首静音」退化为「35 首全静音」。

⇒ `lib_love.lua` 增加 `bundledFallback()`：MOD 路径解析失败时，
用**同一 basename** 回退到 `sound/`。实测 BookCalamity 变为
**15 MOD + 1 内置 + 19 静音**（静音数与改前一致，**未变差**）。

## 兼容性结果（用户核心要求）

### 原版（不激活 MOD）零回归

```
激活MOD = nil
CC.MIDIFile = sound/game%02d.ogg     ← 与改前逐字节相同
CC.ATKFile  = sound/atk%02d.wav      ← 相同
CC.EFile    = sound/e%02d.wav        ← 相同
展开 PlayMIDI(16) -> sound/game17.ogg
```

路径解析纯函数级验证：

| 对象 | 被改变的路径数 |
|---|---:|
| 25 个 `sound/gameNN.ogg` | **0** |
| 1093 个 wav 音效（`atkN` / `eN`） | **0** |

### 20 个 MOD 音乐覆盖

| 指标 | 结果 |
|---|---|
| 产物 `music/*.mid` 总数 | **578**（源 578，**100% 搬运，零丢失**） |
| 被引用 id 可解析 | **348 / 368 = 94.6%** |
| 19/20 MOD 完整覆盖 | **19 个 MOD 100%**（唯一例外 BookCalamity） |
| BookCalamity | 15 MOD + 1 内置回退 + 19 静音（源缺陷，非变差） |

### 8 门禁

| 门 | 结果 |
|---|---|
| G1 测试 | **1965 / 0 failed**（变更前 1957，+8） |
| G2 pascal baseline | `PASS` |
| G3 `mod_build --all` | `20 mods, 0 build failures`（5 个既有标注） |
| G4 `mod_check` | **20 / 20 通过** |
| G5 `mod_audit` | `11220 / 9285 / 1935 / unclassified=0 / bad_evidence=0`（**未变**） |
| G6 `format_spec` | `formats=14 checked=6838 gaps=0` |
| G7 存档 | 真实问题 0 |
| G8 禁改 | `jyconst` 的 `CC.*=` 赋值 **0**；`reference/allmods` 改动 **0** |

- 幂等性：二次全量构建 `diff -rq` = **0**
- 真实启动：pascal / mingdong / awaken / BookCalamity 全部 `RESULT: OK`

## ⚠ 需要批准的禁改路径

本变更**修改了 `game/engine-love2d/lib_love.lua`**（+90 / −2 行），属 AGENTS.md
四禁改路径之一。用户已在本轮明确授权（「可以修改为方案b」）。

其余三禁改**未触碰**：

| 禁改路径 | 改动 |
|---|---|
| `game/engine-mud/**` | **0** |
| `game/script/jyconst.lua` 常量（`CC.*=`） | **0** |
| `reference/allmods/**` | **0** |

## In Scope / Out of Scope

**In Scope**：上述 4 处代码改动 + 578 个 mid 进产物 + 本 change 文档。

**Out of Scope**：
- 不改 `CC.MIDIFile` 常量（`jyconst.lua:439` 区域）
- 不转码（放弃 `allmods-slice15-music-ogg`，标记 `abandoned`）
- `.mp3` **已支持**（用户追加要求）：LÖVE 原生解码，构建期与 `.mid` 一同搬运
- 不能补 BookCalamity 的 19 个缺失源文件（MOD 原始数据缺陷）
- 不追求 `mid.sf2` 音色（LÖVE 忽略自定义 SoundFont，实测无效）

## DoD — 全部达成

- [x] `love.audio.newSource` 可直接解 `.mid`，42/42 抽样出声
- [x] 原版 `CC.MIDIFile` 逐字节不变（零回归）
- [x] 20/20 MOD 构建成功，578/578 mid 进产物
- [x] 19/20 MOD 音乐 100% 覆盖；BookCalamity 未变差
- [x] 8 门禁全绿，测试 1965/0
- [x] 幂等 diff = 0
- [x] 真实启动 4 个代表 MOD 全 OK

## 追加：MP3 支持（第二轮）

用户追问「mp3 可以支持吗？mod 里有播放 mp3 的吗？」后补做。

### 实测结论

| 问题 | 答案 |
|---|---|
| LÖVE 能播 MP3 吗 | **能**，原生解（dream/24.mp3 266.72s RMS 0.1511 / pineapple/37.mp3 248.08s RMS 0.1656，均 audible） |
| MOD 里有引用 MP3 吗 | **没有**（5 条 id 来源全量扫描：`Scene.进门/出门音乐`、`WAR.Data.音乐`、`MmapMusic/CurrentMIDI`、`instruct_66`） |

**勘误上一轮的结论**：上一轮说「引擎无 MP3 音乐通道」只对**改动前**成立。
本轮新增的 `MUSIC_EXTS = {".ogg",".mid",".mp3"}` 已把 `.mp3` 纳入运行时探测，
所以通道**已存在**，缺的只是构建期不搬运。现已补上。

### 重要修正：第一轮扫描有漏洞

上一轮只查 `JY.Scene["进门音乐"]` + `WAR.Data["音乐"]` 两个字段。
但 `instruct_66(id)`（`jymain.lua:4376`）允许事件脚本播放任意 id ——
`awaken` 一个 MOD 就用了 **48 个不同 id（0–80）**。5 条来源全量重扫后：

```
dream      n=16 -> 0,1,2,4,8,9,10,11,12,13,15,16,17,19,20,22        ← 无 24
pineapple  n=19 -> 0,1,3,4,8,9,12,13,15,16,17,18,19,20,21,23,24,25,30 ← 无 37
```

两个 mp3 的编号确实未被引用。但两个 mp3 恰好落在该 MOD **`.mid` 缺失的编号**上
（dream 的 mid 到 23、pineapple 缺 26-28 和 37），说明是作者作为长曲补充放进来的。
按与 578 个 mid 相同的「完整性优先」口径，一并搬运。

### 踩到的坑：Lua pattern 没有 `|` 选择符

第一版写成 `name:match("^(%d+)%.(mid|mp3)$")`，**静默匹配 0 个文件**——
Lua pattern 里 `|` 是普通字符，不是 alternation（那是 PCRE 语法）。
后果：`mod_build --all` 报成功，但产物 `music/` **全空**（mid 也一起丢了）。

改为扩展名白名单：
```lua
local id, ext = name:match("^(%d+)%.([%a%d]+)$")
if id and (ext == "mid" or ext == "mp3") then
```
并加测试 `testMusicPatternHasNoLuaAlternation` 专门守这个陷阱（含负向对照：
往源码里塞回 `(mid|mp3)` 必须 FAIL）。

### 产物对账（字节级）

| 项 | 产物 | 源 | 一致 |
|---|---:|---:|---|
| `.mid` | **578** | 578 | ✅ |
| `.mp3` | **2** | 2 | ✅ |
| `.sf2` | **0** | 1 | ✅ 按设计排除（BUILD_INPUT） |

md5 逐字节：`dream/24.mp3` → `game25.mp3` = `39c4c26b…` ✅；`pineapple/37.mp3` → `game38.mp3` = `d02246c5…` ✅

### 无编号冲突（已实测）

两个 mp3 的同号 `.mid` 都不存在（`dream/24.mid` ✗、`pineapple/37.mid` ✗），
全库冲突扫描结果 **0**。所以 `.mid` 与 `.mp3` 共用 `game<NN>` 命名空间不会互相覆盖。

## 追加：`tools/run-mod.sh` 音频就绪（第三轮）

用户问「run-mod.sh 要不要对应修改，把音频文件也准备好？」——**要改，且有真实缺陷**。

### 缺陷：只看目录存在会永久跳过重建

原逻辑：
```bash
if [ ! -d "$MODS_OUT_DIR/$SELECTED" ]; then   # 只判断目录
```

`mods/<slug>/` 一旦构建过就永久存在。所以本轮**新增 `music/` 产物类型**后，
所有旧 MOD 目录都会被判「已就绪」而跳过重建 ⇒ **音频永远缺失**。

实测（删掉 `mods/pig/music` 后跑脚本）：
```
[info] MOD 数据包已存在: game/mods/pig
[ ok ] 已激活 MOD: pig
结果: music 仍缺失 ⇒ 缺陷确认
```

### 修复

| 函数 | 作用 |
|---|---|
| `mod_ready(slug)` | 目录存在 + `data/` 非空 + 源侧有音频时产物 `music/` 必须存在且数量 ≥ 源侧 |
| `report_audio(slug)` | 打印 `mid=N mp3=N ogg=N`；为空时 warn（音频不阻塞启动） |
| `list_mods()` 新增列 | 已构建 `mid/mp3`；缺 `music/` 显示 `缺`；未构建显示 `src:N` |

### 4 种场景实测

| 场景 | 输出 |
|---|---|
| music 缺失 | `MOD 产物不完整（缺 music/ 等新产物），正在重建` ⇒ 恢复 23 个 |
| 产物完整 | `MOD 数据包已存在且完整`（跳过重建）+ `音频就绪: mid=23 mp3=0 ogg=0` |
| 带 mp3 | `音频就绪: mid=34 mp3=1 ogg=0` |
| 全新 MOD | `MOD 数据包未构建，正在构建` + 构建后音频报告 |

兼容性：`--vanilla` 仍正确删 `active_mod.txt`；`--no-build` 仍正确跳过构建检查。

### `--list` 效果

```
  index  slug            名称                              music(mid/mp3)
      9  dream           笑梦游记                    24/1
     17  pineapple       再破菠萝                    34/1
      0  (vanilla)       原版（不激活 MOD）           sound/*.ogg
```

### 新增门禁 `game/tests/gate_run_mod.sh`（7 项）

守两个真实踩过的坑：①`run-mod.sh` 只看目录；②`flattenMusic` 用了 Lua 不支持的
`(mid|mp3)` alternation。负向对照实测：

| 植入缺陷 | 结果 |
|---|---|
| 删掉 `mods/pig/music` | `GATE_FAIL (1 项)` ✅ |
| `mod_ready` 改回旧判断 | `GATE_FAIL (1 项)` ✅ |

## 追加：libmodplug 警告治理（第四轮）

### 现象

运行 MOD 时 stderr 会刷两类警告（用户实测 `Dragon`）：

```
load_pat > can not open /usr/local/share/timidity/timidity.cfg, use environment variable MMPAT_PATH_TO_CFG for the directory
load_mid > Meta event not at end of track, 1 bytes left in track
load_mid > melody track ends with note on (channel 5, 37618 > 36337 note 45)
```

两者来自 **libmodplug**（LÖVE 的 MOD/MIDI 解码器）C 层，**直接写 stderr，Lua 无法捕获**。

### 全量诊断（578 首实测）

| 警告类型 | 触发曲目 | 成因 |
|---|---:|---|
| `load_pat can not open timidity.cfg` | **578**（每曲 1 条） | 找不到音色库配置 |
| `Meta event not at end of track` | **519** | MOD 作者的 MIDI 在 EOT 后还有字节（不合规但被广泛容忍） |
| `melody/drum track ends with note on` | **309 + 20** | 最后一音的 note-off 缺失 |

### 关键结论：两类警告都不影响听感

**`load_pat`：设 `MMPAT_PATH_TO_CFG` 可消除，且音质零变化。**
逐样本哈希对照（`Dragon/game01.mid`）：

| 条件 | n | RMS | hash |
|---|---:|---:|---:|
| 不设 | 3219456 | 0.153938 | **172447810** |
| `=/etc/timidity` | 3219456 | 0.153938 | **172447810** |
| `=/nonexistent` | 3219456 | 0.153938 | **172447810** |

换真音色库（`FluidR3_GM.sf2` / `TimGM6mb.sf2`）也**完全不变**（hash 相同）
⇒ **libmodplug 忽略 SF2，用内置波形合成**。所以这个警告纯属路径噪声，
**不代表音色缺失**。

**`load_mid`：不是内容缺失，只是末音衰减拖尾被截。**
拿 timidity 渲染 521 首逐首对账：

| 判定 | 首数 | 占比 |
|---|---:|---:|
| 衰减拖尾（超出段逐段递减） | **505** | 96.9% |
| 近乎静音 | **11** | 2.1% |
| LÖVE 不短 | **5** | 1.0% |
| 内容可能缺失 | **0** | **0%** |

典型证据（`m0403` 超出段 6 等分 RMS）：
```
0.3336 → 0.0581 → 0.0076 → 0.0006     ← 单调衰减，最后一音的混响/释音
```
即 LÖVE 短 4.48s 并非「少了一段旋律」，而是砍掉了尾音的自然衰减。
在游戏 BGM 循环场景中**不可察觉**。

> **勘误**：中途我曾把 245 首判为「真截断」，那只是因为只看「超出段 RMS>0.005」
> 而没有看**衰减曲线形状**。加入单调衰减判定后，真实缺失数降为 **0**。

### 处理方案（`tools/run-mod.sh`）

| 手段 | 做法 | 效果 |
|---|---|---|
| 消除 `load_pat` | 自动探测 `/etc/timidity` 等目录并 `export MMPAT_PATH_TO_CFG` | 578 条 → **0**，音质哈希不变 |
| 抑制 `load_mid` | 仅过滤 stderr 中以 `load_pat > ` / `load_mid > ` 开头的行 | 309 条 → **0**，不吞其它输出 |
| 可关闭 | `FUZZY_MIDI_WARN=0` | 保留原始 stderr 用于排查 |

过滤用进程替换 `2> >(grep -vE ... >&2)`，只屏蔽这两类前缀，其它 stderr
（LÖVE 真实报错）照常显示。

### 实测

| 启动方式 | `load_` 行数 |
|---|---:|
| `love .`（直连，`Dragon`） | **10** |
| `./tools/run-mod.sh Dragon` | **0** |

过滤后 `SIG` 等正常输出仍保留，逐样本 hash 仍为 `172447810`（音质未变）。

## 追加：音质问题与 OGG 预渲染（第五轮）

### 用户反馈

「在这个机器上播放 midi 感觉效果很差」。

### 根因：libmodplug 不读任何音色库

LÖVE AppImage **自带** `libmodplug.so.1`（**336 KB**），它与系统安装的音色库完全无关。
决定性证据（同一首 `Dragon/game01.mid`，前 2 秒 PCM 的 md5）：

| 配置 | 前 2 秒 md5 |
|---|---|
| 无音色库 | `df5a2b54…` |
| 装入 freepats（128 个 GUS `.pat`） | `df5a2b54…` **相同** |
| 装入 `FluidR3_GM.sf2`（148 MB） | `df5a2b54…` **相同** |
| **128 个音色全指向同一个低音鼓采样** | `df5a2b54…` **仍相同** |

连「所有音色都是低音鼓」都不改变输出，说明它的 MIDI 合成**根本不读外部音色**，
只用 336 KB 里内置的简易波表。这也解释了为何 `load_pat` 警告是误导：即使配上
音色库也不会被使用。

### 客观量化

| 渲染路径 | 过零率 | 差分/RMS | 判定 |
|---|---:|---:|---|
| libmodplug 直放 MIDI | **4749 Hz** | **0.338** | 刺耳、单薄 |
| 预渲染 OGG（timidity+FluidR3） | **2215 Hz** | **0.154** | 与无损基准一致 |
| timidity 无损 WAV（基准） | 2214 Hz | 0.154 | — |

高频能量差 **2.1 倍**，与主观「电子味重」吻合。

### 方案选择：OGG 预渲染

| 方案 | 可行性 |
|---|---|
| 给 libmodplug 配音色库 | ❌ 已证伪（逐字节相同） |
| 换 LÖVE 的 MIDI 后端 | ❌ 内置库，AppImage 不可换 |
| fluidsynth 实时回灌 | ❌ 需外部进程，架构侵入大 |
| **预渲染 OGG** | ✅ 音质达标，运行时代码零改动 |

### 格式对比：OGG 优于 MP3

同一 WAV 源、78 秒曲目实测：

| 格式 | 体积 | 过零率偏差 | 结论 |
|---|---:|---:|---|
| OGG q1 | 728 KB | +2.8% | 最省 |
| **OGG q3** | **1017 KB** | **+0.1%** | **推荐** |
| MP3 q:a 9 | 781 KB | **+10.7%** | 同体积下差 4 倍 |
| MP3 q:a 7 | 1014 KB | +2.0% | 同体积下差 20 倍精度 |

MP3 是旧心理声学模型，对谐波丰富的合成音色劣化明显。**全量 578 首**：
OGG q3 ≈ 560 MB，OGG q1 ≈ 400 MB。

### 实现

| 改动 | 内容 |
|---|---|
| `lib_love.lua` | `MUSIC_EXTS` 改为 `.ogg, .mp3, .mid`（用户指定：mid 排最后兜底） |
| `mod_build.lua` | `preservedOgg`：`rmdirp` 前暂存 `music/*.ogg`，`flattenMusic` 后写回 |
| `tools/render-music.sh` | 新增；`--all` / `--list` / `--force`，增量渲染 |
| `test_mod_data.lua` | 3 个测试守探测顺序（含「.mid 不得排第一」负向守门） |
| `gate_run_mod.sh` | 9 项新检查，含**真实重建行为验证** |

### 实测

| 项 | 结果 |
|---|---|
| Dragon 24 首渲染耗时 | **1 分 57 秒** |
| Dragon music/ 体积 | MIDI 288 KB → +OGG **18 MB** |
| LÖVE 实际播放选中 | `game01.ogg`（探测顺序生效） |
| 播放后过零率 | **2215 Hz**（对比直放 MIDI 4749 Hz） |
| 重建后 ogg 存活 | ✅（负向对照：清空恢复循环 ⇒ `GATE_FAIL`） |
| 全量测试 | **2002 / 0 失败**（+15） |

### 门禁的真实弱点（记录在案）

`gate_run_mod.sh` 大部分检查是**文本级**的。我曾把恢复循环改成空循环
（`pairs({})`），文本检查仍全部 PASS。因此补了一条**行为验证**：
植入标记 ogg → 真实跑 `mod_build` → 检查标记是否存活。
这条才能发现「代码存在但逻辑被架空」，负向对照 `GATE_FAIL (1 项)`。

### 全量渲染完成

用户试听 Dragon 后确认「OK」，随即渲染剩余 554 首。

| 项 | 实测 |
|---|---|
| MOD 数 | **20 / 20** |
| MIDI 数 | **578 / 578** |
| 失败 / 警告 | **0 / 0** |
| 渲染总耗时 | 约 **53 分钟**（Dragon 首轮另计） |
| OGG 总体积 | **476.3 MB**（中位 729 KB/首） |
| 最大文件 | `awaken/game81.ogg` 5.9 MB（时长 458 秒） |

逐 MOD 独立对账（不经脚本自报，直接 `find` 比对源与产物）：

```
MOD              源mid 产物ogg 状态
awaken               84     84 OK
BookCalamity         24     24 OK
...
zheng                23     23 OK
不一致 MOD 数: 0
```

抽检 9 个 MOD 的实际过零率全部落在真实音色区间（2079~2752 Hz），
远离 libmodplug 直放的 4749 Hz。

**重建保护实测**：对 Dragon 跑一次真实 `mod_build`，渲染前 578 个 OGG，
重建后仍是 **578** 个，无丢失。

> **磁盘说明**：`game/mods/` 合计约 2.0 GB，其中 OGG 仅 476 MB；
> 其余是既有产物（`save/` 718 MB、`data/` 633 MB、`script/` 46 MB、
> `sound/` 25 MB），与本次改动无关。`game/mods/` 已被 `.gitignore:45` 覆盖。
