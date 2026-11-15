---
status: active
created: 2026-11-14
parent_epic:
parent_slice:
---
# Design: audio-settings

> 每个关键判断记作 ADR（Context / Decision / Alternatives rejected / Consequences）。
> 调研结论均来自本仓当前代码，可在 `game/` 下复跑验证。

## ADR-AS-001 设置采用「三层优先级 + 点分命名空间」，而非各模块自带配置变量

**Context**

当前配置来源有三处，且互不知情：

| 来源 | 载体 | 谁写 | 谁读 |
|------|------|------|------|
| 代码默认 | `config.lua` (`CONFIG.*`) | 开发者 | 到处 |
| 游戏常量 | `jyconst.lua` (`CC.*`) | 开发者 | 到处 |
| MOD 默认 | `kysmod.ini` | MOD 作者 | `mod_ini.lua` |
| **用户偏好** | **不存在** | — | — |

第四层完全缺失。如果只为音量加一个 `local musicVolume = 50`，
下一个设置项（亮度、走路速度、手柄）会各自再造一份：

```
  musicVolume   在 lib_love.lua
  brightness    在 engine_love2d.lua
  walkSpeed     在某个 *_async.lua
  ...           每个都自带默认值、自带持久化、自带取值范围
```

**Decision**

建立 `framework/settings.lua`，单一 API + 三层解析 + 点分命名空间键：

```
  优先级（高→低）
  ┌────────────────────────────────────────────┐
  │ user      settings.ini（save 目录）  可写   │
  │   ▼ 覆盖                                    │
  │ mod       kysmod.ini [music] volume=22      │
  │   ▼ 覆盖                                    │
  │ default   Settings.define{default=50}       │
  └────────────────────────────────────────────┘
```

键名用 `audio.music` / `audio.sfx` / `video.scale` 形式，**不用嵌套表**。理由：`audio.music` 天然映射到 INI 的 `[audio] music=`，
同一个键名可同时出现在用户文件与 MOD 文件里，两边写法一致。

**API 形状**

```lua
Settings.define("audio.music", {
    default = 50, type = "int", min = 0, max = 100, label = "音乐音量",
})
Settings.get("audio.music")            --> 50（已按 schema 转换与钳制）
Settings.set("audio.music", 30)        --> 写 user 层 + 触发 onChange
Settings.onChange("audio.music", fn)   --> 订阅变更
Settings.keys()                        --> 枚举（供通用设置界面）
Settings.spec("audio.music")           --> {default=50,...}
Settings.load() / Settings.save()
```

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 每个设置项各自 `local` 变量 | 无枚举能力 → 无法做通用设置界面；默认值/校验/持久化重复 N 份 |
| 直接读写全局 `CONFIG.*` | 无法表达「user 覆盖 mod」；`CONFIG` 是编译期常量区，语义污染 |
| 只做音量专用模块 | 与 `framework` 的「适配任意引擎」目标冲突；下个设置项要从零再来 |
| 键名用嵌套表 `{{audio={music=50}}}` | INI 映射需要额外转换层；点分字符串更平 |

**Consequences**

- `settings.lua` 约 150 行纯逻辑（零 IO、零引擎依赖），可完全单测
- `settings_store.lua` 约 100 行 IO，只依赖 `EngineAPI.file`
- 未来加设置项 = 一行 `define` + 一行 `onChange`，无需改 UI 框架
- `framework` 里少数名实相符的真正引擎无关模块（对齐 `dialog_layout` / `text_box_layout`）

---

## ADR-AS-002 值调节用「数字描述符」驱动通用菜单，而非专用绘制代码

**Context**

需求形态是单行数字、上下箭头、上下键 ±1：

```
        ┌──────────────────┐
        │        ▲         │   ← 装饰
        │   音乐音量 50%    │   ← 值行
        │        ▼         │   ← 装饰
        └──────────────────┘
```

现有 `MenuStateMachine:handleInput` 的上下键语义是**换行**：

```lua
elseif key == VK_DOWN then
    menu.current = menu.current + 1
    if menu.current > menu.newNumItem then
        menu.current = 1          -- 单行菜单原地转圈
    end
```

单行菜单里上/下键 = 原地循环，**不可能表达「+1」**。这是组件的能力缺口。

同时，现有菜单项是 `{文本, 回调, 可见性}`，文本是静态字符串，
`draw()` 直接 `DrawString(..., item[1], ...)` —— 无法随值变化。

**Decision**

给菜单项的第 2 项增加一种「数字描述符」类型，与原有的「回调函数」并存：

```lua
{ "音乐音量 %d/128", {
      kind   = "number",
      key    = "audio.music",        -- Settings 键（量程 0-128）
      step   = 1,
      format = "音乐音量  %d/128",   -- 每帧按【待定值】重算文本
  }, 1 }
```

> **显示原始值 `64/128`，不换算成百分比。** 理由见 ADR-AS-003：
> 内部 0-128 + 显示百分比 + 步进 1 会导致 22% 的按键看不到数字变化（跳字）。
> 显示原始值时每按必有变化，且 `settings.ini` 里的 `music=22` 可与
> `kysmod.ini` 的 `VOLUME=22` 直接对照。

#### 「待定值」与「确认后提交」——本 ADR 的核心约束

**需求明确要求：上下键只改一个「待定值」，必须按确认键才真正写入设置。**

理由（用户原话归纳）：键盘误触、连续按键过多都可能把音量推到意料之外的极端值。
**调节过程必须是可撤销的**，只有明确的确认动作才产生副作用。

于是值项有三态：

```
   ┌──────────────────────────────────────────────────────────┐
   │  进入界面   pending = Settings.get(key)      ← 从当前真实值起步
   │                                                          │
   │  按 ▲/▼    pending = clamp(pending ± step)   ← 只改待定值  │
   │             不调用 Settings.set，不影响播放                 │
   │                                                          │
   │  按 Enter  Settings.set(key, pending)  → 关闭菜单（提交）   │
   │  按 ESC    pending 丢弃                → 关闭菜单（取消）   │
   └──────────────────────────────────────────────────────────┘
```

`pending` 存放在描述符表上（`desc.pending`），由 `createMenu` 在菜单创建时
从 `Settings.get` 初始化。因此：

- `audio_menu.buildVolumeMenu()` **每次调用都返回新表**（不得缓存复用），
  否则上一次的 `pending` 会残留
- 菜单项计数只有 1 项（一个值项），所以上下键**不存在与「换行」的歧义**
- 提交后菜单关闭（`closeMenu(item[4])`），与既有菜单「选中即关闭」语义一致

菜单组件改三处（约 25 行）：

```lua
-- ① createMenu：为值项初始化 pending
if type(item[2]) == "table" and item[2].kind == "number" then
    item[2].pending = Settings.get(item[2].key)
end

-- ② handleInput：值项的上下键改待定值，Enter 提交，ESC 取消
local desc = item[2]
if type(desc) == "table" and desc.kind == "number" then
    if key == VK_UP   then desc.pending = clamp(desc.pending + desc.step); return end
    if key == VK_DOWN then desc.pending = clamp(desc.pending - desc.step); return end
    if key == VK_RETURN or key == VK_SPACE then
        Settings.set(desc.key, desc.pending)     -- 唯一的副作用点
        self:closeMenu(item[4])
        return
    end
    -- ESC 走既有的 isEsc 分支：closeMenu(0)，pending 自然丢弃
end

-- ③ draw：值项文本按 pending 重算（不是按 Settings.get）
if type(item[2]) == "table" and item[2].format then
    text = string.format(item[2].format, item[2].pending)
end
```

**注意 `draw` 里读的是 `pending` 而不是 `Settings.get`。** 若读 `Settings.get`，
待定值就无从显示 —— 这是本设计最容易写错的一处。

**边界用钳制（clamp），不用环绕。** 到达 100 后按 ▲ 无变化，不回绕到 0。
理由：环绕对鼠标点击反直觉，且按住 ▲ 会无限转圈。

**键盘重复的影响因此被消除**

`jymain_adapter.lua:114` 无条件调
`lib.EnableKeyRepeat(CONFIG.KeyRepeatDelay, CONFIG.KeyRepeatInterval)`，
`CONFIG.KeyRepeat=0` 这个开关在事件驱动路径**从未被检查**，重复始终启用：

```
轻按（<300ms 松开）→ 精确 ±1
按住不放          → 300ms 后每 40ms 一次 ≈ 25/秒
0 → 100           → 约 4 秒
```

在「待定值」设计下，误触或连按**不会产生任何副作用** —— 只要不按 Enter，
设置值不变、播放不变。反向键可随时修正待定值，ESC 可整体放弃。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 11 档百分比列表（光标位置=当前值） | 320×240 下 11×20=220px，贴边；且鼠标适配要变成点击某一行，不如点击箭头 |
| 上下键**直接**写设置（边调边听） | 误触/连按会立即改变音量，且无法整体撤销 —— 与本 ADR 的核心约束冲突 |
| 每次 adjust 调 `Settings.set` 但另存一份「进入前的值」用于 ESC 回滚 | 音量在调节过程中已经真实变化（会听到），回滚只是事后补救；且 `set` 会触发引擎推送，噪声明显 |
| 专用 `while true` 绘制循环 | 需自行处理输入等待、退出、协程调度配合，与 `MenuAsync` 生态割裂 |
| 全局快捷键（F1/F2） | 手机无 F1；web 终端要另做；违反可发现性 |
| 左右箭头调值 | **字体不支持**：`simsun.ttf` 的 cmap 中 `▶ U+25B6` / `◀ U+25C0` 缺失（实测），会显示成方块 |

**Consequences**

- 值项成为通用能力：未来「画面亮度」「走路速度」「战斗速度」免费用同一套，
  且天然具备「预览 → 确认」语义
- 体积：`menu_state_machine.lua` 约 +25 行（值项）+ +10 行（多行文本）
- 形态 2 的三行布局需要多行文本项支持：`\n` 分隔逐行 `DrawString`，
  行高 `size + CC.RowPixel`
- **代价：没有实时试听。** 选到 50% 按 Enter 之后才听得到。这是为「可撤销」
  付出的代价，需求方已明确接受
- **框宽只对值项按显示宽度算，不动既有菜单**（见 ADR-AS-009）

---

## ADR-AS-003 音量为 per-source 设置，而非全局 `love.audio.setVolume`

**Context**

LÖVE 的 `love.audio.setVolume(v)` 是**全局**的，无法区分音乐与音效。
而需求要求两者独立调节。

全部创建音频 source 的位置只有两处（`lib_love.lua`）：

```lua
716:  currentMusic = love.audio.newSource(filepath, "stream")   -- 音乐，保留引用
747:  source_or_err = love.audio.newSource(filepath, "static")  -- 音效，即用即弃
```

**Decision**

在 `EngineAPI.audio` 增加 4 个函数，由引擎自己管理音量并应用到每个 source。
**量程采用 0-128，增益采用线性**（理由见下）：

```lua
EngineAPI.audio.setMusicVolume(value)   -- 0-128，与原版 SDL_mixer 同量程
EngineAPI.audio.getMusicVolume()        --> number 0-128
EngineAPI.audio.setSFXVolume(value)
EngineAPI.audio.getSFXVolume()
```

love2d 实现：

```
  音乐（推 + 拉）
    setMusicVolume(v):
        musicVolume = v
        if currentMusic then currentMusic:setVolume(v / 128) end   -- 推：立即生效
    PlayMIDI: newSource 后 → currentMusic:setVolume(musicVolume / 128)  -- 拉

  音效（仅拉）
    setSFXVolume(v): sfxVolume = v
    PlayWAV: newSource 后 → source:setVolume(sfxVolume / 128)
```

已在播放的短音效不受事后调节影响 —— 音效时长都很短（实测 wav 2-33KB），可接受。

#### 增益必须用线性 `v/128`，不能用平方

这是本 ADR 最关键的判断，也是对一份早期错误设计的修正。

原版与本引擎的振幅语义**完全一致**：

```
  SDL_mixer:  Mix_Volume(ch, v)     v ∈ [0,128]   线性振幅
  LÖVE 11.x:  Source:setVolume(g)   g ∈ [0,1]     线性振幅

  →  g = v / 128  是【精确等值映射】，零失真
```

如果把增益改成平方 `(v/128)^2`，20 个 MOD 的音量会严重失真：

| mod.ini | 原版真实振幅 | 线性 `v/128` | 平方 `(v/128)^2` | 偏差 |
|---------|-------------|-------------|-----------------|------|
| `VOLUME=5` | 0.0391 | 0.0391 | 0.0015 | **0.04x** |
| `VOLUME=10` | 0.0781 | 0.0781 | 0.0061 | **0.08x** |
| `VOLUME=17` | 0.1328 | 0.1328 | 0.0176 | **0.13x** |
| `VOLUME=22` | 0.1719 | 0.1719 | 0.0295 | **0.17x** |
| `VOLUME=26` | 0.2031 | 0.2031 | 0.0413 | **0.20x** |
| `VOLUME=32` | 0.2500 | 0.2500 | 0.0625 | **0.25x** |

即：MOD 作者按线性调出的音量会被压到原来的 **1/5 ~ 1/25**，
「保留 mod.ini 音量值」这个核心目标完全落空。

「人耳感知接近对数，所以该用平方」这个说法本身没错，但它与
**「保真原版 MOD 调音意图」是直接冲突的**，而后者是本 change 的明确需求。
线性也并非「听感差」—— 原版就是这样，20 个 MOD 作者都是在这个量程上调的音。

#### 为什么量程取 0-128 而不是 0-100

既然增益必须是线性，两个量程在**实际响度上几乎等价**：

```
   mod raw    原版振幅    0-100+线性（四舍五入后）   偏差
   VOLUME=5    0.0391     4  → 0.0400              +2.4%
   VOLUME=22   0.1719    17  → 0.1700              -1.1%
   VOLUME=32   0.2500    25  → 0.2500               0.0%
   VOLUME=33   0.2578    26  → 0.2600              +0.8%
```

最大偏差 2.4%（约 0.2 dB），人耳不可辨。所以量程选择**不关乎响度**，
只关乎以下三件工程事：

| 维度 | 0-128 内部（采用） | 0-100 内部 |
|------|------------------|-----------|
| MOD 换算 | **零转换**（22 就是 22） | 需 `floor(raw*100/128+0.5)` |
| `settings.ini` 可读性 | `music=22` 与 `kysmod.ini` 的 `VOLUME=22` 直接可比 | `music=17`，与 MOD 原值不一致 |
| 按 ±1 + 显示百分比 | **22% 的按键看不到显示变化** | 每按必变 |

第三条是决定性的：

```
  内部 0-128、显示换算成百分比、步进 1：
      第 1~10 次按键 → 1, 2, 2, 3, 4, 5, 5, 6, 7, 8
                            ↑        ↑
                       按了没反应  按了没反应
      128 次按键中 28 次显示不变（22%）
```

需求方明确要「一次一次按」，跳字是每天都会遇到的使用体验问题。

**因此显示保留原始值 `64/128`，不换算成百分比。**
代价是玩家看到的不是「50%」，收益是：零换算、零舍入、MOD 值可直接对照、
每按必有变化。这个游戏本身是原版复刻，显示原始量程与整体调性也一致。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 增益用平方 `(v/128)^2` | 让 20 个 MOD 的音量失真 5-26 倍，「保留 mod.ini 音量」需求落空 |
| 内部 0-100 + 显示百分比 | 需要一个换算函数 + 1-2% 舍入；`settings.ini` 里的值与 `kysmod.ini` 对不上 |
| 内部 0-128 + 显示换算成百分比 | 22% 的按键看不到显示变化（跳字） |
| `love.audio.setVolume` 全局设 | 无法分离音乐/音效 |
| 用 LÖVE 的 audio filter / effect | 需 `t.modules.audio` 高级特性，Android/老设备兼容性不确定；收益为零 |
| 在 `framework` 层直接调 `love.audio` | 违反「`framework` 不依赖具体引擎」的既有约定 |

**Consequences**

- `engine-mud` / `engine-web` 4 个函数为 no-op（两者本就无音频实现）
- `tests/engine_test.lua` 记录调用，可断言「框架真的调到了引擎」
- 音量为 per-source 后，未来做「音乐淡出」等效果也在同一处扩展
- **ModIni 侧不需要任何 `scale` 换算**（见 ADR-AS-005），少一个概念
- 显示为 `音乐音量  64/128`；`Settings.define` 的 `min=0, max=128`
- 默认值：`audio.music=64`（50%）、`audio.sfx=90`（70%）

---

## ADR-AS-004 设置持久化用 INI + 写后回读校验，不做原子写

**Context**

`EngineAPI.file` 提供 `read` / `write` / `exists` / `getSize` /
`remove` / `createDirectory` / `directoryExists` / `listDirectory`，
但**没有 rename**。LÖVE 的 `love.filesystem` 同样没有 rename 原语。

因此「写 `.tmp` → rename 覆盖」这一标准原子写模式不可用。

**Decision**

沿用 `ModData.writeFileRaw` 已验证的形态：

1. 写入后**回读校验**（内容完全一致才算成功）
2. 校验失败 → 保持内存中的值，不阻塞启动，输出 `lib.Debug` 警告
3. 文件格式为 INI，带 `[meta] version=1`

```ini
; 自动生成，可手工编辑
[meta]
version=1

[audio]
music=64
sfx=90
```

> 量程 0-128，与 `kysmod.ini` 的 `VOLUME` / `VOLUMEWAV` 同一把尺子，
> 可直接对照（例如 MOD 写 `VOLUME=22`，用户覆盖写 `music=40`）。

**为什么必须有 version**：键改名/改语义时，没有版本号就无法安全迁移。
成本一行，收益是未来所有设置迁移的抓手。

**为什么选 INI 而非 JSON / 二进制**：

| 考量 | INI | JSON | 二进制 |
|------|-----|------|--------|
| 仓库已有解析器 | ✓ `mod_ini.lua` | ✗ 需新写 | ✗ |
| 人可读可手动改 | ✓ | ✓ | ✗ |
| 支持注释 | ✓ | ✗ | ✗ |
| 写入代码量 | ~40 行 | ~60 行 | ~20 行 |

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 写进存档文件 | 违反「设置是全局的、不随存档走」的明确要求；换 MOD 会丢设置 |
| 写进 `config.lua`（代码文件） | 打包后 `.love` 内只读；Android 更不可写 |
| 用 `os.remove` + 重写模拟原子 | 删除与重写之间有窗口期，比直接写更糟 |
| 不持久化（仅会话有效） | 玩家每次启动都要重调，等于没做 |

**Consequences**

- 桌面 + Android：设置跨会话保留
- Web：`EngineAPI.file.write` 是空函数 → 自动降级为「仅本次会话有效」，不崩
- 测试：注入内存 store 即可，无需真实文件

---

## ADR-AS-005 `kysmod.ini` 的音量改为注入 Settings 的 mod 层，保留文件不动

**Context**

20 个 MOD 的 `kysmod.ini` 里都有认真调过的音量值：

```
VOLUME / VOLUMEWAV 的取值分布（实测全部 20 个 MOD）
      5 / 10    → 11 个 MOD
     10 / 30    →  6 个 MOD
     17 / 33    →  1 个 MOD（awaken）
     17 / 30    →  1 个 MOD（pineapple）
     22 / 26    →  1 个 MOD（mingdong）
```

`mod_ini.lua` 当前把 `[music] volume` 映射到 `CONFIG.MasterVolume`，
`volumewav` 映射到 `CONFIG.SoundVolume`。

**关键事实（纠正一处早期误判）**：这些值**并没有丢失**。
`ModIni.Apply` 确实执行了 `gCONFIG[k] = v`，字段被真实创建；
问题只是**没有任何代码读取它们**。所以是「孤儿数据」而非「解析失败」。

**Decision**

映射表增加第三种目标类型 `settings`，且**不做任何量程换算**：

```lua
-- mod_ini.lua SECTION_MAP.music
volume    = { settings = "audio.music" },
volumewav = { settings = "audio.sfx"   },
```

- `Map()` 产出 `result.settings["audio.music"] = 22`
- `Apply()` 写入 Settings 的 **mod 层**（不是 user 层）
- `CONFIG.MasterVolume` 这个错名不再产生

**为什么写 mod 层而不是 user 层**：MOD 作者设的是「推荐默认值」，
玩家自己的选择必须能覆盖它。写 user 层等于把 MOD 的意图冒充玩家的意图。

#### 为什么没有 `scale` 换算

因为音量量程已统一为 **0-128**（ADR-AS-003），与 `kysmod.ini` 的
`VOLUME` / `VOLUMEWAV` **同一把尺子**：

```
  kysmod.ini:  VOLUME = 22
  Settings:    audio.music 的 mod 层 = 22        ← 原样搬过来
  settings.ini 里:  music = 22                   ← 也是 22，可直接对照
```

`config.lua:62` 的注释「(0-128)」与 SDL_mixer 的 `MIX_MAX_VOLUME=128` 一致，
本设计按此采用该量程。

> **早先设计的 `scale=128` + `floor(raw*100/128+0.5)` 换算已废弃。**
> 换算的必要性只存在于「内部用 0-100 而 mod 用 0-128」这种混用场景；
> 现已统一量程，换算与舍入一并消除。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 内部 0-100 + `scale=128` 换算 | 引入换算函数与 1-2% 舍入；`settings.ini` 的值与 `kysmod.ini` 对不上 |
| `settings.lua` 里写 `modSource = "CONFIG.MasterVolume"` | 键名字符串同时存在于两处，未来改名要同步；正是 `MasterVolume` 错名的成因 |
| 删除 `mod_ini` 的音量映射 | 丢弃 20 个 MOD 作者的调音意图 |
| 修改 20 个 MOD 的 ini 文件 | 改动外部数据，且 `reference/allmods/` 是 gitignored 的上游素材 |
| MOD 音量直接写 user 层 | 语义错误：MOD 默认会冒充玩家选择，玩家改不了 |

**Consequences**

- 20 个 MOD 的音量意图**首次真正生效**，且**零失真、零舍入**
- `CONFIG.MasterVolume` / `CONFIG.MusicVolume` / `CONFIG.SoundVolume` 三个字段退役
- `mod_ini` 的 `volume` 映射从「写入无人读的字段」变为「写入 Settings mod 层」，
  顺带修复了一处既有缺陷
- 代码里**没有 `scale` 概念**，映射表条目从三字段变两字段

---

## ADR-AS-006 菜单入口：大地图「系统」子菜单 + 开始菜单新增「设置」，小场景不提供

**Context**

现存的菜单结构：

```
开始菜单（3 项）            大地图 ESC 主菜单（6 项）      小场景 ESC 主菜单
├ 重新开始                  ├ 医疗                       ├ 医疗
├ 载入进度                  ├ 解毒                       ├ 解毒
└ 离开游戏                  ├ 物品                       ├ 物品
                            ├ 状态                       ├ 状态
                            ├ 离队                       └ ~~离队~~  隐藏
                            └ 系统 ★                     └ ~~系统~~  隐藏 ★
                                ├ 读取进度
                                ├ 保存进度
                                └ 离开游戏
```

`jymain_async.lua:35-38` 明确在小场景隐藏第 5、6 项（离队、系统）。
**开始菜单没有「系统」子菜单**，要放音量需新建一个二级菜单。

**Decision**

```
大地图                          开始菜单
系统                            （新增）设置 ★
├ 读取进度                      ├ 音乐音量 → 值调节
├ 保存进度                      └ 音效音量 → 值调节
├ 音乐音量 → 值调节
├ 音效音量 → 值调节
└ 离开游戏

层级：系统/设置 → 音乐音量 → 值调节    = 3 层
```

- 大地图：在「系统」子菜单插入 2 项（不新增容器层）
- 开始菜单：新增 1 项「设置」，其下直接挂 2 项
- 小场景：**不提供**。与「离队/系统」在企业设置上一致 —— 小场景本就没有系统菜单

**为什么不要中间「音量设置」容器层**：

```
  4 层：系统 → 音量设置 → 音乐音量 → 值调节
  3 层：系统 → 音乐音量 → 值调节          ← 采用
```

「音乐音量」「音效音量」本身就是足够清楚的一级；中间容器层零信息量，
而 640×480 下 4 层嵌套的横向空间已经很紧（`CC.MainSubMenuX2` 已算到第 3 层）。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 主菜单顶层加「设置」 | 主菜单已 6 项（小场景 4 项），变 7 项在 320×240 下占屏过大 |
| 每个菜单都插音量项 | 重复；且主菜单本就分「游戏功能」与「系统功能」两层 |
| 解除小场景的系统菜单隐藏 | 改变既有行为，且原作者隐藏意图不明（`git log -S` 只追到目录重构，无说明） |
| 全局快捷键（F1/F2） | 手机无 F1；web 终端要另做；违反可发现性 |

**Consequences**

- 需在 `menu_state_machine` 的布局常量外再确认第 3 层的 x 坐标
  （`CC.MainSubMenuX2` 之后需新增一个或复用）
- 小场景玩家无法调音量 —— 这是明确接受的设计
- 「设置」只在开始菜单出现，与大地图「系统」并列，两处入口不重复

---

## ADR-AS-007 音量菜单与引擎零耦合：经 `Settings.onChange` 订阅，菜单不碰 `EngineAPI`

**Context**

若让菜单回调直接调 `EngineAPI.audio.setMusicVolume(v)`，则：

```
  audio_menu.lua  ──需要──>  EngineAPI  ──需要──>  love.audio
```

菜单模块因此无法脱离引擎测试，也违背 `framework` 只通过 `EngineAPI` 调用引擎的既有分层
（虽然很多 `*_async` 模块已经妥协，但新增模块不应继续）。

**Decision**

分层为：

```
  audio_menu.lua       只调 Settings.set / Settings.get
        │
        ▼
  Settings             纯逻辑，无引擎
        │
        ▼  onChange 通知
  audio_settings.lua   在初始化时订阅：
                       Settings.onChange("audio.music", function(v)
                           EngineAPI.audio.setMusicVolume(v)
                       end)
        │
        ▼
  EngineAPI.audio      per-source 应用
```

菜单完全不知道音量最终怎么作用到音频上。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 菜单描述符里带 `onChange` 回调 | 菜单模块需要 `require EngineAPI`；无法脱离引擎测试 |
| 菜单里直接 `love.audio.setVolume` | 违反引擎抽象，且全局音量无法分离音乐/音效 |
| 轮询（每帧读值比较） | 无谓开销；且丢失「变更时机」信息 |

**Consequences**

- `audio_menu.lua` 只依赖 `MenuAsync` + `Settings`
- 引擎接线集中在 `audio_settings.lua` 一个文件，换引擎只改这一处
- 测试可用假 `EngineAPI` 验证「框架真的调到了引擎」

---

## ADR-AS-008 `onCursorChange` 与值项描述符是两个独立能力，都需要

**Context**

两者容易被误认为同一件事：

```
onCursorChange      光标从第 i 行移到第 j 行时触发
                    在单行数字控件里【永不触发】（单行没有"换行"）

值项描述符          上下键调整数值时触发
                    但本身【不产生副作用】—— 只改待定值（见 ADR-AS-002）
```

**Decision**

两者都实现，但**职责分离**：

```lua
-- ① 菜单级钩子（通用，纯通知，不改变任何状态）
menu.onCursorChange = function(menu, newCurrent, oldCurrent) end

-- ② 值项（不携带 onChange；副作用只在 Enter 确认时由 Settings.set 产生）
{ "音乐音量  %d/128", { kind="number", key="audio.music", step=1 }, 1 }
```

`onCursorChange` 用 `pcall` 包裹（与既有 `globalDrawCallback` 的处理一致），
钩子抛错不得影响主循环。

**明确约束：`onCursorChange` 不得用于「音量立即修改」**

需求方明确指出：把 `onCursorChange` 接到音量变更上会导致
键盘误触 / 连续按键时音量瞬间跳到极端值，且无法撤销。

因此本 change 中 **`onCursorChange` 不注册到任何音量菜单上**。
它只作为通用能力存在（未来「选项列表式」UI 或「换行时播放预览」会用）。

音量的唯一副作用点是值项的 Enter 确认分支（ADR-AS-002）。

**Consequences**

- `onCursorChange` 对既有的 20+ 个菜单零影响（未注册即不调用）
- 值项是纯数据描述，可序列化、可枚举
- 未来若做「选项列表式」UI（11 档那种），`onCursorChange` 立刻可用
- 本 change 交付的 `onCursorChange` **没有调用者**（这是刻意的，不是遗漏）；
  测试须覆盖它本身的行为，而非它的业务效果

---

## ADR-AS-009 框宽按显示宽度计算：只应用于值项，不动既有菜单

**Context**

`createMenu` 的自动定宽用 `string.len`，即 **UTF-8 字节数**：

```lua
w = size * maxlength / 2 + 2 * CC.MenuBorderPixel
```

中文 3 字节 → 框宽被算成约 4.5 倍字号，远大于实际。同样的问题
`DrawStrBox` 已经修过（`jymain.lua:2148` 的注释记录了实测：
`梅庄` 真实 48px、旧公式 82px，多 29px）。

音量值项必然含中文（`音乐音量 50%`），若不修，框会明显偏宽。

但 `ShowMenu` 的框宽**影响全游戏所有菜单**（20+ 处调用）。
全局改动会改变所有菜单的视觉尺寸与文字折行，风险远超本 change 边界。

**Decision**

新增一个**仅值项生效**的宽度计算分支：

```lua
-- createMenu 里
local maxwidth = 0
for i = 1, newNumItem do
    local text = newMenu[i][1]
    if isNumberItem(newMenu[i]) then
        -- 值项：用显示宽度（TextBoxLayout.textWidth，汉字 1.0em / ASCII 0.5em）
        maxwidth = math.max(maxwidth, TextBoxLayout.textWidth(text, size))
    else
        -- 既有菜单：保持 string.len 行为不变
        maxwidth = math.max(maxwidth, string.len(text) * size * 0.5)
    end
end
w = maxwidth + 2 * CC.MenuBorderPixel
```

`TextBoxLayout` 已存在且**已验证与 `simsun.ttf` 的 `font:getWidth` 完全一致**
（见其文件头注释），是现成的正确度量。

**Alternatives rejected**

| 方案 | 否决理由 |
|------|----------|
| 全局改为显示宽度 | 改变所有 20+ 菜单的框宽，需实机逐个核对是否挤压/折行；超出本 change 边界 |
| 值项手写固定宽度（如 200px） | 不做度量，遇到字号/字体变化就错；不解决问题只规避 |
| 不修 | 值项框宽偏宽约 4.5 倍，视觉上明显失衡 |

**Consequences**

- 音量菜单框宽正确，既有菜单维持现状（已知偏宽但可用）
- 需要 `menu_state_machine.lua` 引入 `TextBoxLayout` 依赖（纯 framework 模块，可接受）
- 「全局统一为显示宽度」记为独立议题，未来单独评估
