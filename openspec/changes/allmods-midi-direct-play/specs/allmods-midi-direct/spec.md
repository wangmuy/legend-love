---
status: done
created: 2026-10-30
---
# Spec: allmods-midi-direct

MOD 自带 MIDI 音乐直放（不转码）。所有断言均由实测命令验证。

---

## REQ-MIDI-1：引擎按扩展名探测音乐文件

**Motivation**：MOD 产物的音乐文件是 `.mid`，而 `CC.MIDIFile` 原值是
`sound/game%02d.ogg`（禁改常量）。若把 `.mid` 内容改名为 `.ogg`，LÖVE 会按扩展名
选 Ogg 解码器并失败 —— 实测报 `Could not read Ogg bitstream`。因此路径必须以
**无扩展名**形式交给引擎，由引擎逐个探测。

### Scenario 1.1：无扩展名路径按 `.ogg → .mid → .mp3` 探测

- **Given** `MUSIC_EXTS = {".ogg", ".mid", ".mp3"}` 且三种文件都存在
- **When** 调用 `resolveMusicFile("mods/x/music/game27")`
- **Then** 返回 `mods/x/music/game27.ogg`（`.ogg` 优先，保证原版 25 首逐字节不变）

实测：
```
mods/mingdong/music/game27         ->	mods/mingdong/music/game27.mid
mods/pascal/music/game24           ->	mods/pascal/music/game24.mid
```

### Scenario 1.2：带扩展名路径原样返回（原版零回归）

- **Given** 路径 `sound/game17.ogg`
- **When** 调用 `resolveMusicFile`
- **Then** 原样返回 `sound/game17.ogg`，**不做任何探测**

实测（纯函数级）：

| 对象 | 被改变的路径数 |
|---|---:|
| 25 个 `sound/gameNN.ogg` | **0** |
| 1093 个 wav 音效（`atkN` / `eN`） | **0** |

### Scenario 1.3：编号格式化是最小宽度，不是定宽

- **Given** `string.format("game%02d.mid", 82)`
- **When** 展开
- **Then** 得 `game82.mid`，**不是** `game082.mid`

实测：
```
TestHelper.assertEquals("mods/mingdong/music/game82",
    string.format(CC.MIDIFile, 82), "id 81 formats to game82")
```
✅ PASS

---

## REQ-MIDI-2：MOD `music/` 重定向

### Scenario 2.1：MOD 有 `.mid` ⇒ 重定向并剥掉扩展名

- **Given** 激活 `mingdong`，`mods/mingdong/music/` 含 `game02.mid`、`game27.mid`
- **And** `CC.MIDIFile = "sound/game%02d.ogg"`
- **When** 调用 `RewriteConstants`
- **Then** `CC.MIDIFile` 变为 `"mods/mingdong/music/game%02d"`（**无扩展名**）
- **And** `ATKFile` / `EFile` 不受影响（该 MOD 无对应文件）

实测：✅ `testRewriteAudioMidiRedirect` PASS

### Scenario 2.2：MOD 无 `.mid` ⇒ 不改写（负向对照）

- **Given** 激活 `pascal`，`music/` 目录存在但**没有** `game*.mid`
- **When** 调用 `RewriteConstants`
- **Then** `CC.MIDIFile` 保持 `"sound/game%02d.ogg"`

实测：✅ `testRewriteAudioMidiNoMidNoRedirect` PASS

这次对照有鉴别力：与 2.1 只差「目录里有没有文件」，若实现只看
`dirExists` 而忘了 `listDir`，本测试会 FAIL。

### Scenario 2.3：未激活 MOD ⇒ 即使检测到 mid 也不改写（零回归对照）

- **Given** `SetActive(nil)`，且 `dirExists` 恒 true、`listDir` 恒返回 `{"game02.mid"}`
- **When** 调用 `RewriteConstants`
- **Then** `MIDIFile` / `ATKFile` / `EFile` 三者**全部不变**

实测：✅ `testRewriteAudioMidiNoActiveIsNoop` PASS

---

## REQ-MIDI-3：MOD 缺曲时回退内置资源

**Motivation**：BookCalamity 引用 id 24–51，但源侧只有 `music/0..23`。
若无回退，MOD 目录会**遮蔽**原本能播的 `sound/gameNN.ogg`，结果比改前更差。

### Scenario 3.1：MOD 缺文件时回退同 basename 的内置曲

- **Given** `mods/BookCalamity/music/game25.mid` 不存在，但 `sound/game25.ogg` 存在
- **When** 调用 `resolveMusicFile("mods/BookCalamity/music/game25")`
- **Then** 返回 `sound/game25.ogg`

实测：
```
mods/BookCalamity/music/game25 (源缺) ->	sound/game25.ogg
```

### Scenario 3.2：不递归回退

- **Given** 路径已在 `sound/` 下且不存在
- **When** 调用 `bundledFallback`
- **Then** 返回 nil（不无限自指）

### Scenario 3.3：BookCalamity 整体未变差

- **Given** BookCalamity 引用 35 个 id
- **When** 逐 id 解析
- **Then** 15 来自 MOD、1 来自内置回退、**19 静音**

实测：
```
BookCalamity: refs=35 fromMOD=15 fromBundled=1 silent=19
  fromBundled ids: 24
  silent ids: 25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,41,42,50,51
```

改前静音数也是 **19** ⇒ 静音数不变，且 15 首从内置曲换成了 MOD 原曲，**净收益**。

---

## REQ-MIDI-4：构建期搬运并重命名

### Scenario 4.1：`<id>.mid` → `game<id+1>.mid`

- **Given** 源文件 `music/26.mid`
- **When** 构建
- **Then** 产物为 `mods/<slug>/music/game27.mid`

理由：引擎 `PlayMIDI(id)` 传 `id+1`（`jymain.lua:2162`），而文件名语义是 `<id>`
（实测 `<id>` 命中 94.6% vs `<id+1>` 90.5%；且多个 MOD 有 `music/0.mid`，
按 `<id+1>` 会取 `-1.mid`，不可能）。

### Scenario 4.2：`0.mid` 正确映射

- **Given** 源 `music/0.mid`
- **When** 构建
- **Then** 产物 `game01.mid`

实测：`mods/mingdong/music/game02.mid` 存在 ⇒ `0.mid` 映射为 `game01.mid` ✅

### Scenario 4.3：`.sf2` 不复制，`.mp3` 复制

- **Given** `music/mid.sf2`
- **When** 构建
- **Then** 产物中**无** `.sf2`（它是转换输入，`BUILD_INPUT`）

- **Given** `music/24.mp3`
- **When** 构建
- **Then** 产物为 `mods/<slug>/music/game25.mp3`（LÖVE 原生解码，见 REQ-MIDI-7）

实测：`产物 sf2: 0`、`产物 mp3: 2`

### Scenario 4.4：全量零丢失

- **Given** 20 个 MOD
- **When** `mod_build --all`
- **Then** 产物 `music/*.mid` 总数 **等于**源侧总数

实测：
```
源 .mid 总数: 578
产物总计:     578
```
✅ **100% 搬运，零丢失**

### Scenario 4.5：构建幂等

- **Given** 已构建一次
- **When** 再次全量构建并 `diff -rq`
- **Then** 差异数 = **0**

实测：`差异数: 0`

> 注意：做幂等检查必须在**测试套件之前** —— 测试会删除 MOD 产物 `save/` 模板，
> 导致 110 处假差异（已验证：`grep -vc "save"` = 0，即差异全在 `save/`）。

---

## REQ-MIDI-5：真实播放出声

**Motivation**：「能解码」不等于「有声音」。必须实测 RMS。

### Scenario 5.1：MOD MIDI 真实出声

- **Given** LÖVE 11.5 实跑
- **When** `love.audio.newSource("game27.mid", "stream")` 并采样 RMS
- **Then** RMS > 0.01

实测：

| 文件 | 时长 | RMS | 判定 |
|---|---:|---:|---|
| mingdong `game27.mid` | 122.00s | 0.1022 | 出声 ✅ |
| awaken `game82.mid` | 89.00s | 0.1075 | 出声 ✅ |
| 内置 `game25.ogg`（对照） | 119.55s | 0.0960 | 出声 ✅ |

### Scenario 5.2：抽样全量无静音

- **Given** 40 个 MOD `.mid`（每 MOD 首尾各一）+ 2 个 `.mp3`
- **When** 逐个解码并测 RMS
- **Then** 全部出声

实测：`TOTAL=42 decoded=42 decode_fail=0 silent=0`

---

## REQ-MIDI-6：20 MOD + 原版全兼容

### Scenario 6.1：原版路径逐字节不变

- **Given** 不激活 MOD
- **When** 加载 `jymain.lua`
- **Then** `CC.MIDIFile == "sound/game%02d.ogg"`

实测：
```
激活MOD =	nil
CC.MIDIFile =	sound/game%02d.ogg
CC.ATKFile  =	sound/atk%02d.wav
CC.EFile    =	sound/e%02d.wav
展开 PlayMIDI(16) ->	sound/game17.ogg
```

### Scenario 6.2：20 MOD 逐个可解析

实测：

| MOD | 引用 | 可解析 | 缺失 |
|---|---:|---:|---:|
| awaken | 31 | 31 | 0 |
| BookCalamity | 35 | 15 | 20 |
| books | 15 | 15 | 0 |
| Dragon | 15 | 15 | 0 |
| dream | 14 | 14 | 0 |
| GodsDevils | 17 | 17 | 0 |
| HeavenSword | 16 | 16 | 0 |
| lostbook | 16 | 16 | 0 |
| loving | 15 | 15 | 0 |
| lyff | 18 | 18 | 0 |
| mingdong | 43 | 43 | 0 |
| pascal | 16 | 16 | 0 |
| pig | 18 | 18 | 0 |
| pig3dos | 4 | 4 | 0 |
| pineapple | 15 | 15 | 0 |
| ptt | 16 | 16 | 0 |
| RiverLake | 16 | 16 | 0 |
| stronger | 16 | 16 | 0 |
| SweeOan | 16 | 16 | 0 |
| zheng | 16 | 16 | 0 |
| **合计** | **368** | **348** | **20** |

**19/20 MOD 100% 覆盖**；可解析率 **348/368 = 94.6%**。

### Scenario 6.3：真实启动无崩溃

- **Given** `boot_one_mod.lua`
- **When** 启动 pascal / mingdong / awaken / BookCalamity
- **Then** 全部 `RESULT: OK`

实测：`RESULT pascal: OK` / `RESULT mingdong: OK` / `RESULT awaken: OK` / `RESULT BookCalamity: OK`

---

## 负向对照汇总（鉴别力证明）

| 对照 | 若实现有误则 |
|---|---|
| 2.2 目录存在但无 `.mid` | 只看 `dirExists` 的实现会误改写 ⇒ FAIL |
| 2.3 未激活 MOD 但检测到 mid | 忘判 `active` 的实现会污染原版 ⇒ FAIL |
| 3.2 已在 `sound/` 下 | 忘判前缀的实现会无限自指 ⇒ FAIL |
| 1.2 带扩展名原样返回 | 无条件探测的实现会改变原版路径 ⇒ FAIL |
| 4.5 幂等 diff | 非确定性排序会每次输出不同 ⇒ FAIL |

---

## 已知限制（非缺陷）

| # | 限制 | 性质 |
|:-:|---|---|
| 1 | BookCalamity 19 个 id 静音 | **MOD 原始数据缺陷**（引用 24–51，仅有 0–23） |
| 2 | `.mp3` 未被引用（但**已支持播放**） | 源数据无引用；通道已通（见 REQ-MIDI-7） |
| 3 | `mid.sf2` 音色不生效 | libmodplug 忽略自定义 SoundFont（3 种 cfg 写法合成 md5 全同 `bfeebf68…`） |
| 4 | 578 个 mid 全进产物（含未引用 537 个） | 仅 7.5 MB，完整性优先于精简 |

---

## REQ-MIDI-7：MP3 支持（第二轮追加）

**Motivation**：用户追问「mp3 可以支持吗？mod 里有播放 mp3 的吗？」。
第一轮曾断言「引擎无 MP3 音乐通道」——那**只对改动前**成立：新增的
`MUSIC_EXTS = {".ogg",".mid",".mp3"}` 已把 `.mp3` 纳入运行时探测。

### Scenario 7.1：LÖVE 原生解码 MP3

- **Given** LÖVE 11.5
- **When** `love.audio.newSource("x.mp3","stream")`
- **Then** 正常加载并出声

实测：

| 文件 | 时长 | 声道 | 采样率 | RMS | peak |
|---|---:|---:|---:|---:|---:|
| `dream/music/24.mp3` | 266.72s | 2 | 32000 | 0.1511 | 0.960 |
| `pineapple/music/37.mp3` | 248.08s | 2 | 44100 | 0.1656 | 0.999 |

### Scenario 7.2：构建期搬运 `.mp3`

- **Given** 源 `music/37.mp3`
- **When** 构建
- **Then** 产物 `mods/<slug>/music/game38.mp3`（`<id+1>`，同 `.mid` 规则）

实测字节级：

| 源 | 产物 | md5 |
|---|---|---|
| `dream/music/24.mp3` | `game25.mp3` | `39c4c26b…` ✅ |
| `pineapple/music/37.mp3` | `game38.mp3` | `d02246c5…` ✅ |

### Scenario 7.3：`.mid` 与 `.mp3` 共用命名空间无冲突

- **Given** 全库 578 个 `.mid` + 2 个 `.mp3`
- **When** 扫描「同 MOD 内 `<id>.mp3` 是否与 `<id>.mid` 共存」
- **Then** 冲突数 = **0**

实测：`冲突数: 0`（`dream/24.mid` 不存在、`pineapple/37.mid` 不存在）

### Scenario 7.4：MP3 同样走内置回退

- **Given** MOD 引用了 id 但 MOD 只有 `.mp3`
- **When** `resolveMusicFile` 探测
- **Then** `.ogg` ✗ → `.mid` ✗ → `.mp3` ✓

实测：
```
dream      id=24  mods/dream/music/game25 -> mods/dream/music/game25.mp3
pineapple  id=37  mods/pineapple/music/game38 -> mods/pineapple/music/game38.mp3
```

### Scenario 7.5：Lua pattern 不得使用 `|` 选择符（防回归）

- **Given** `flattenMusic` 的文件名匹配
- **When** 源码中出现 `"^(%d+)%.(mid|mp3)$"`
- **Then** 测试 FAIL

**背景（真实踩坑）**：Lua pattern 没有 alternation，`|` 是**字面字符**（PCRE 才有 `|`）。
第一版这样写导致**静默匹配 0 个文件**，`mod_build --all` 仍报成功，
但产物 `music/` 全空（连 `.mid` 一起丢了）。改为扩展名白名单：

```lua
local id, ext = name:match("^(%d+)%.([%a%d]+)$")
if id and (ext == "mid" or ext == "mp3") then
```

### Scenario 7.6：音乐 id 来源必须含 `instruct_66`

- **Given** MOD 事件脚本可调 `instruct_66(id)` 播放任意 id
- **When** 统计「被引用的音乐 id」
- **Then** 必须计入该来源

**背景（第一轮漏洞）**：第一轮只查 `JY.Scene["进门音乐"]` 与 `WAR.Data["音乐"]`，
完全漏掉 `instruct_66`。实测 `awaken` 用它播了 **48 个不同 id（0–80）**。
补全后 5 条来源：`Scene.进门`、`Scene.出门`、`WAR.Data.音乐`、
`MmapMusic/CurrentMIDI`、`instruct_66`。且 `instruct_66` 参数全为字面量
（`grep -v "instruct_66([0-9]*)"` 为空）⇒ 无漏扫。

### Scenario 7.7：MP3 构建测试的鉴别力

| 植入缺陷 | 期望 | 实测 |
|---|---|---|
| 把正则改回 `(mid|mp3)` | 测试 FAIL | **2 failed** ✅ |
| 删除 `game25.mp3` | 测试 FAIL | **2 failed** ✅ |
