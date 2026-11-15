## ADDED Requirements

### Requirement: REQ-SET-1 设置三层优先级

系统 SHALL 按 `user > mod > default` 三层解析设置值，优先级顺序必须在代码中显式且可测。

#### Scenario: 用户设置覆盖 MOD 默认
- **WHEN** 用户设置文件含 `[audio] music=30`，且 MOD ini 提供 `volume=22`
- **THEN** `Settings.get("audio.music")` 返回 `30`

#### Scenario: 无用户设置时用 MOD 默认（零换算）
- **WHEN** 用户设置文件无该键，MOD ini 提供 `[music] VOLUME=22`
- **THEN** `Settings.get("audio.music")` 返回 **`22`**（原样搬入，无换算）

#### Scenario: 两层都无时用代码默认
- **WHEN** 用户层与 MOD 层均无该键
- **THEN** `Settings.get("audio.music")` 返回 `define` 时的 `default`（`64`）

### Requirement: REQ-SET-2 schema 声明与校验

系统 SHALL 要求每个设置键先 `define`，并按其 `type`/`min`/`max` 做转换与钳制。
音量量程统一为 **0-128**（与原版 SDL_mixer 及 `kysmod.ini` 同量程）。

#### Scenario: 超出上界被钳制
- **WHEN** `Settings.define("audio.music", {default=64, type="int", min=0, max=128})`
  后调用 `Settings.set("audio.music", 999)`
- **THEN** `Settings.get("audio.music")` 返回 `128`

#### Scenario: 低于下界被钳制
- **WHEN** `Settings.set("audio.music", -5)`
- **THEN** `Settings.get("audio.music")` 返回 `0`

#### Scenario: 非数值字符串回落到默认
- **WHEN** INI 中该键的值为 `abc`（无法转成 number）
- **THEN** 返回 `default`，且**不抛错**

#### Scenario: 支持枚举
- **WHEN** 已 define 多个键
- **THEN** `Settings.keys()` 返回全部键，`Settings.spec("audio.music")` 返回含
  `default`/`type`/`min`/`max`/`label` 的表

### Requirement: REQ-SET-3 持久化

系统 SHALL 把用户设置持久化到 save 目录下的 `settings.ini`，
并在写入后回读校验（`EngineAPI.file` 无 rename 原语，无法做原子写）。

#### Scenario: 写入后跨会话保留
- **WHEN** 桌面环境下 `Settings.set("audio.music", 30)` 后 `Settings.save()`，
  然后新建实例并 `Settings.load()`
- **THEN** `Settings.get("audio.music")` 返回 `30`
- **AND** 文件含 `[audio]` 段、`music=30`、以及 `[meta] version=1`

#### Scenario: 无写能力时降级不崩
- **WHEN** `EngineAPI.file.write` 为空实现（web 引擎）
- **THEN** `Settings.save()` **不抛错**，设置仅在会话内有效

#### Scenario: 回读校验失败不崩
- **WHEN** 写入后回读内容与写入内容不一致
- **THEN** `Settings.save()` 返回 `false` 且保持内存中的值，**不抛错**

### Requirement: REQ-SET-4 变更通知

系统 SHALL 提供 `Settings.onChange(key, fn)` 订阅机制，且监听器之间相互隔离。

#### Scenario: 值变化触发一次
- **WHEN** 已注册 `onChange` 后 `Settings.set("audio.music", 70)`
- **THEN** 监听器被调用恰好 **1** 次，参数为 `(70, "audio.music")`

#### Scenario: 值未变化不触发
- **WHEN** 当前值已为 70，再次 `Settings.set("audio.music", 70)`
- **THEN** 监听器**不被**调用

#### Scenario: 监听器抛错不影响其他监听器
- **WHEN** 同一键注册了两个监听器，第一个抛错
- **THEN** 第二个仍被调用（`pcall` 隔离）

### Requirement: REQ-VOL-1 音乐/音效独立音量

系统 SHALL 为音乐与音效分别提供 **0-128** 的独立音量（与原版 SDL_mixer 同量程），
两者互不影响。

#### Scenario: 两路音量互不干扰
- **WHEN** `EngineAPI.audio.setMusicVolume(30)` 与 `setSFXVolume(90)`
- **THEN** `getMusicVolume()` 返回 `30`，`getSFXVolume()` 返回 `90`

#### Scenario: 音量 0 等价于关闭
- **WHEN** 某路音量设为 `0`
- **THEN** 对应 source 的增益为 `0`

#### Scenario: 满量程为 128
- **WHEN** 调用 `setMusicVolume(128)`
- **THEN** 应用到 source 的增益为 `1.0`

### Requirement: REQ-VOL-2 引擎接线（per-source 应用）

系统 SHALL 在**每个 source 创建时**应用音量，并额外对正在播放的音乐立即生效。
`love.audio.setVolume` 是全局音量，不得使用。

#### Scenario: 正在播放的音乐立即变化
- **WHEN** 已有 `currentMusic` 正在播放，调用 `setMusicVolume(64)`
- **THEN** 该 `currentMusic` 立即被 `:setVolume(0.5)`

#### Scenario: 之后创建的音乐也应用
- **WHEN** 设置音量后再次 `PlayMIDI` 创建新 source
- **THEN** 新 source 被应用到当前音乐音量（不只是已存在的那一个）

#### Scenario: 音效逐个应用
- **WHEN** `PlayWAV` 创建音效 source
- **THEN** 该 source 被应用到当前音效音量

#### Scenario: 增益为线性映射（必须精确等值）
- **WHEN** `setMusicVolume(64)`
- **THEN** 应用给 source 的增益为 `0.5`（`64/128`），**不是** `0.25`
- **AND** `setMusicVolume(32)` → 增益 `0.25`
- **AND** `setMusicVolume(5)` → 增益约 `0.0391`

> 依据：SDL_mixer 的 `Mix_Volume(ch, v)`（v∈[0,128]）与 LÖVE 的
> `Source:setVolume(g)`（g∈[0,1]）**都是线性振幅**，故 `g = v/128` 是精确等值映射。
> 若改用平方，MOD ini 的音量会失真 5-26 倍（见 design.md ADR-AS-003）。

#### Scenario: 无音频引擎为 no-op
- **WHEN** 在 `engine-mud` / `engine-web` 下调用 4 个音量函数
- **THEN** 全部为 no-op 且不抛错
- **AND** `tests/engine_test.lua` 记录调用，可断言框架确实调到了引擎

### Requirement: REQ-VOL-3 MOD ini 音量接入设置 mod 层

系统 SHALL 把 `kysmod.ini` 的 `[music] VOLUME` / `VOLUMEWAV` **原样**写入 Settings 的
**mod 层**（非 user 层），**不做任何量程换算**。

#### Scenario: mingdong 的音量原样搬入
- **WHEN** 激活 `kys-mingdong`（`VOLUME=22` / `VOLUMEWAV=26`）并加载设置
- **THEN** `audio.music` 的 mod 层为 **`22`**
- **AND** `audio.sfx` 的 mod 层为 **`26`**
- **AND** 全流程**没有** `scale` 换算、没有四舍五入

#### Scenario: 20 个 MOD 的音量均原样搬入
- **WHEN** 逐个解析 20 个 MOD 的 `kysmod.ini`
- **THEN** 每个 MOD 的 `VOLUME` / `VOLUMEWAV` 数值与写入 mod 层的值**完全相同**

#### Scenario: 用户设置优先于 MOD
- **WHEN** 用户设置文件已有 `audio.music=60`
- **THEN** `Settings.get("audio.music")` 返回 `60`

#### Scenario: 错名字段退役
- **WHEN** 应用 MOD ini
- **THEN** `CONFIG.MasterVolume` **不再**被创建

#### Scenario: 上游素材只读
- **WHEN** 实现完成后检查 `reference/allmods/*/kysmod.ini`
- **THEN** 20 个文件内容**未被修改**

### Requirement: REQ-MENU-1 值项描述符（上下键增减待定值，确认后提交）

系统 SHALL 支持「数字描述符」类型的菜单项：上下键只修改**待定值**，
必须按确认键才写入设置；按取消键放弃待定值。文本每帧按待定值重算，
显示为**原始值 `N/128`**（不换算成百分比）。

> 约束来源 1：调节过程必须可撤销。键盘误触 / 连续按键不得直接改变实际音量。
> 约束来源 2：显示原始值。内部 0-128 若显示百分比，22% 的按键会看不到数字变化。

#### Scenario: 进入界面时待定值等于当前值
- **WHEN** 当前 `audio.music` 为 `64`，打开值调节界面
- **THEN** 待定值初始化为 `64`，界面显示 `64/128`

#### Scenario: 上键加一（仅改待定值）
- **WHEN** 菜单项为 `{ "音乐音量  %d/128", {kind="number", key="audio.music", step=1}, 1 }`
  且按下 `VK_UP`
- **THEN** 待定值 `+1`，下一帧菜单文本显示 `65/128`
- **AND** `Settings.get("audio.music")` **仍为原值**（未提交）

#### Scenario: 下键减一（仅改待定值）
- **WHEN** 按下 `VK_DOWN`
- **THEN** 待定值 `-1`
- **AND** `Settings.get("audio.music")` **仍为原值**

#### Scenario: 确认键提交
- **WHEN** 待定值为 `90` 时按下 `VK_RETURN`（或 `VK_SPACE`）
- **THEN** `Settings.get("audio.music")` 变为 `90`
- **AND** 触发 `Settings.onChange`（引擎实际应用音量）
- **AND** 菜单关闭

#### Scenario: 取消键放弃
- **WHEN** 待定值被改为 `90`（原值 `64`）后按下 `VK_ESCAPE`
- **THEN** `Settings.get("audio.music")` **仍为 `64`**
- **AND** `Settings.onChange` **未被触发**
- **AND** 菜单关闭

#### Scenario: 连按不产生副作用
- **WHEN** 按住 `VK_UP` 使待定值从 `64` 连续升到 `128`
- **THEN** 整个过程中 `Settings.set` **调用 0 次**，实际音量不变

#### Scenario: 上界钳制不回绕
- **WHEN** 待定值已为 `128` 时按 `VK_UP`
- **THEN** 待定值保持 `128`（不回绕到 0）

#### Scenario: 下界钳制不回绕
- **WHEN** 待定值已为 `0` 时按 `VK_DOWN`
- **THEN** 待定值保持 `0`

#### Scenario: 上下键不触发菜单导航
- **WHEN** 光标位于值项上并按 `VK_UP` / `VK_DOWN`
- **THEN** 菜单光标**不移动**（不换行）

#### Scenario: 文本按待定值渲染而非当前值
- **WHEN** 待定值为 `90` 而 `Settings.get` 返回 `64`
- **THEN** 菜单显示 `90/128`

#### Scenario: 每按必有显示变化（无跳字）
- **WHEN** 从 `0` 逐次按 `VK_UP` 到 `128`（共 128 次按键）
- **THEN** **每一次**按键后菜单显示的数字都不同
- **AND** 不存在「按了但显示不变」的情况

#### Scenario: 每次构建返回新表
- **WHEN** 连续两次调用 `audio_menu.buildVolumeMenu()`
- **THEN** 返回的两个菜单项表**不是同一对象**（避免待定值残留）

#### Scenario: 值项框宽按显示宽度计算
- **WHEN** 值项文本为 `音乐音量  64/128`（中文与 ASCII 混排）
- **THEN** 框宽基于 `TextBoxLayout.textWidth` 的显示宽度
- **AND** 不得使用 UTF-8 字节数

#### Scenario: 既有菜单框宽不变
- **WHEN** 检查任意非值项的既有菜单框宽
- **THEN** 与改动前**完全一致**（仍用 `string.len` 语义）

### Requirement: REQ-MENU-2 onCursorChange 钩子

系统 SHALL 提供菜单级 `onCursorChange` 钩子（纯通知，不改变状态），
且不得影响未注册该钩子的既有菜单。本 change 中它**不用于**音量变更。

#### Scenario: 光标换行时触发
- **WHEN** 菜单注册了 `onCursorChange`，光标从第 1 行移到第 2 行
- **THEN** 钩子被调用，参数含新位置 `2` 与旧位置 `1`

#### Scenario: 钩子不改变状态
- **WHEN** `onCursorChange` 被触发
- **THEN** 菜单的 `current` / `pending` 均由组件自身决定，钩子无法修改
- **AND** 钩子内部调用 `Settings.set` **不会**由组件代为执行（组件不感知设置）

#### Scenario: 未注册时零影响
- **WHEN** 既有 20+ 个菜单（未注册钩子）正常运行
- **THEN** 行为与改动前完全一致，全量测试零回归

#### Scenario: 音量菜单不注册该钩子
- **WHEN** 检查 `audio_menu.buildVolumeMenu()` 产出的菜单
- **THEN** **不含** `onCursorChange`（音量变更只走 Enter 确认）

#### Scenario: 钩子抛错不中断主循环
- **WHEN** `onCursorChange` 内部 `error()`
- **THEN** 被 `pcall` 捕获，主循环继续运行

### Requirement: REQ-MENU-3 菜单入口位置

系统 SHALL 只在大地图「系统」子菜单与开始菜单提供音量入口，小场景不提供，
且层级为 3 层（无中间「音量设置」容器层）。

#### Scenario: 大地图可达
- **WHEN** `GAME_MMAP` 状态下按 ESC 并选择「系统」
- **THEN** 子菜单含「音乐音量」与「音效音量」，位于「保存进度」之后、「离开游戏」之前

#### Scenario: 开始菜单可达
- **WHEN** `GAME_START` 状态下查看菜单
- **THEN** 含「设置」项，其下含音乐音量与音效音量

#### Scenario: 小场景不可达
- **WHEN** `GAME_SMAP` 状态下按 ESC
- **THEN** **不出现**音量入口（系统菜单整项仍按既有逻辑隐藏）

#### Scenario: 层级为 3 层
- **WHEN** 从入口进入值调节界面
- **THEN** 路径为「入口 → 音乐/音效音量 → 值调节」，无中间容器层

### Requirement: REQ-CLEAN-1 删除死代码

系统 SHALL 删除 `script/jymodify.lua` 中已被事件驱动路径绕过的音效开关实现，
但保留该文件的其余功能。

#### Scenario: 死函数已删除
- **WHEN** 检查 `script/jymodify.lua`
- **THEN** `Menu_System_new` / `Menu_SetMusic` / `Menu_SetSound` **不存在**

#### Scenario: 相关赋值已删除
- **WHEN** 检查 `SetModify()`
- **THEN** `Menu_System_old = Menu_System` 与 `Menu_System = Menu_System_new` **不存在**

#### Scenario: 其余功能保持不变
- **WHEN** 检查 `SetModify()`
- **THEN** `JY.ThingUseFunction[182] = Show_Position`、
  `JY.ThingUseFunction[0] = newThing_0`、`JY.SceneNewEventFunction[1]` 仍在
- **AND** 全量测试零回归

### Requirement: REQ-COMPAT-1 跨版本与跨平台

系统 SHALL 在 Lua 5.1 / 5.3 / 5.4 / 5.5 与 Windows 干净 PATH 环境下保持全绿。

#### Scenario: 四版本全绿
- **WHEN** 在 Lua 5.1 / 5.3 / 5.4 / 5.5 下分别运行 `lua tests/test_runner.lua`
- **THEN** 四个版本都全绿

#### Scenario: 双版本语法检查
- **WHEN** 对全部新增/修改的 `.lua` 执行 `luac5.1 -p` 与 `luac5.5 -p`
- **THEN** 零失败

#### Scenario: 干净 PATH 一致
- **WHEN** 在干净 Windows PATH（无 msys2）下运行全量测试
- **THEN** 结果与完整 PATH 下一致

#### Scenario: 设置核心零引擎依赖
- **WHEN** 检查 `game/framework/settings.lua`
- **THEN** 不含 `EngineAPI` / `love.` / `CC.` / `JY.` 任一引用

#### Scenario: store 只走引擎文件接口
- **WHEN** 检查 `game/framework/settings_store.lua`
- **THEN** 只依赖 `EngineAPI.file`，不含 `io.open`
