---
status: active
created: 2026-11-14
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: audio settings — 统一设置系统与音量调节

## Why

游戏从移植至今**没有任何用户可写设置**：

- `CONFIG.MusicVolume=16` / `CONFIG.SoundVolume=32`（`config.lua:62-63`）自建立以来**零读取点**；
- 全仓 `love.audio.setVolume` 出现 0 次 —— 音乐/音效永远以 LÖVE 默认音量播放；
- 全仓无 `settings/options/preferences` 概念 —— 玩家改不了任何东西并保存。

同时，20 个 MOD 的 `kysmod.ini` 里**都有**认真调过的音量值（`VOLUME` 5/10/17/22，
`VOLUMEWAV` 10/26/30/33），`mod_ini` 也确实把它们写进了
`CONFIG.MasterVolume` / `CONFIG.SoundVolume` —— 但**没有任何代码读这两个字段**。
MOD 作者的调音意图从未生效过。

`script/jymodify.lua:40-92` 曾实现过「关闭音乐 / 关闭音效」开关，但事件驱动改造后，
运行路径走 `JyMainAsync.Menu_System`，**不再调用被覆盖的全局 `Menu_System`**，
那套开关已成死代码，玩家从未见过。

本 change 补上「用户设置」这一层，并让它成为**引擎无关的通用设施**，
而不是只为音量写一次性代码。

## Parent Context

- Epic: 无（独立基础设施 change）
- 依赖: `allmods-ini-parser`（已 done，提供 `mod_ini.lua` 与 `CONFIG.MasterVolume` 映射）
- 关联: `game/framework/` 目标为「一套适配任意引擎的框架」，本 change 是其中第一个
  真正的**通用设置子系统**

## What Changes

1. **新增 `game/framework/settings.lua`** — 设置核心（纯逻辑，零引擎依赖）
   - schema 声明：`Settings.define(key, {default, type, min, max, label, ...})`
   - 三层优先级解析：user > mod > default
   - 类型转换与范围钳制（INI 读出来全是字符串）
   - 变更通知：`Settings.onChange(key, fn)`
   - 枚举能力：`Settings.keys()` / `Settings.spec(key)`（供通用设置界面使用）
2. **新增 `game/framework/settings_store.lua`** — INI 读写
   - 只依赖 `EngineAPI.file`（可注入替换，便于测试）
   - 无 rename 原语 → 写后回读校验（复用 `ModData.writeFileRaw` 已验证的形态）
   - 文件带 `[meta] version=1`，为未来键迁移留抓手
3. **新增 `game/framework/audio_settings.lua`** — 音量定义与引擎接线
   - `Settings.define("audio.music")` / `Settings.define("audio.sfx")`
   - 通过 `Settings.onChange` 订阅并调用 `EngineAPI.audio.setMusicVolume` 等
4. **新增 `game/framework/audio_menu.lua`** — 音量菜单构建
   - 产出菜单项数组（供 `jymain_async` / `jymain_adapter` 插入）
   - 值项使用「数字描述符」，上下键增减
5. **`EngineAPI.audio` 增加 4 个函数**
   - `setMusicVolume(value)` / `getMusicVolume()` / `setSFXVolume(value)` / `getSFXVolume()`
   - **量程 0-128，增益线性 `value/128`**（与原版 SDL_mixer 的 `Mix_Volume` 精确等值）
   - love2d 真实实现（音乐推送 + 下拉、音效下拉）；mud/web no-op；engine_test 记录调用
6. **`framework/menu_state_machine.lua` 增加三项通用能力**
   - `menu.onCursorChange` 钩子（光标换行时触发；**本 change 不用于音量**）
   - 值项描述符：上/下键只改「待定值」，**确认键才提交**，取消键放弃
   - 多行文本项支持（形态 2 的三行箭头布局需要）
   - 值项的框宽按显示宽度计算（既有菜单的框宽**不变**）
7. **菜单接入（3 层，无中间容器层）**
   - 大地图：`系统` → `音乐音量` / `音效音量` → 值调节界面
   - 开始菜单：新增 `设置` 项 → 同上两项 → 值调节界面
   - 小场景：**不提供**（系统菜单在小场景本就被隐藏，与企业设置一致）
   - 值调节界面显示**原始值 `64/128`**，不换算百分比（避免跳字）
8. **`mod_ini.lua` 的 `volume` / `volumewav` 改为注入 Settings 的 mod 层**
   - 映射表支持第三种目标类型 `{ settings = "audio.music" }`（**无 `scale`，零换算**）
   - `Config.MasterVolume` 字段不再产生（错名退役）
9. **删除死代码** `script/jymodify.lua` 的 `Menu_System_new` / `Menu_SetMusic` /
   `Menu_SetSound` 及 `SetModify` 中对应的 3 行赋值

## Scope Boundaries

### In Scope

- `framework/settings.lua` + `settings_store.lua`（通用设置子系统）
- 音量模型（音乐/音效分开）、引擎接线、菜单 UI
- 设置持久化（桌面 + Android 走 `EngineAPI.file`；web 降级为会话内有效）
- `mod_ini` 音量映射接入 Settings mod 层
- 菜单组件的两项通用增强（`onCursorChange` + 值项描述符）
- 删除 `jymodify` 的音效开关死代码
- 单元测试 + 回归（四 Lua 版本）

### Out of Scope

- **触摸输入 / 虚拟手柄按键** — 后续独立 change。本 change 完成后：
  - 桌面（Windows/Linux/macOS）完整可用
  - Android 接**物理键盘**（蓝牙/USB）完整可用
  - Android 触摸屏**不响应**（整个游戏现状即如此，非本 change 引入）
- **Web 端音频与设置界面** — `engine_web.lua` 的 `audio.*` 与 `file.write` 均为空实现，
  且 web 版是 xterm.js 终端 MUD（非图形界面），形态与本设计的菜单不兼容
- 屏幕缩放/分辨率适配（手机全屏比例问题）
- 物理手柄（`conf.lua` 的 `t.modules.joystick=false` 不动）
- 除音量外的其他设置项（画面亮度、走路速度等）—— 但 `settings.lua` 的 schema
  已为它们留好位置
- `JY.EnableMusic` / `JY.EnableSound` 布尔开关的移除（语义上已被音量 0% 取代，
  但保留无害，本 change 只在注释中标注）
- `config.lua` 中 `CONFIG.KeyRepeat` 在事件驱动路径未被检查的既有缺陷

## Impact

| 区域 | 影响 |
|------|------|
| `game/framework/` | 新增 4 个模块，修改 4 个（menu_state_machine / jymain_async / jymain_adapter / mod_ini） |
| `game/engine-*/` | 三个引擎各加 4 个 audio 函数实现 |
| `game/script/` | 仅 `jymodify.lua` 删死代码 |
| 存档格式 | **无影响**（设置与存档解耦，独立文件） |
| MOD 资源 | **无影响**（不修改任何 `kysmod.ini`） |
| 既有行为 | 音量从"固定默认"变为"可调"，`mod.ini` 的音量从"孤儿"变为"MOD 默认值" |

## Risks

1. **20 个 MOD 的默认音量偏轻** —— `kysmod.ini` 的 `VOLUME` 实测分布为
   5/10/17/22（占 0-128 的 4%-17%），本 change **原样采用、不做换算**，
   所以 MOD 默认音乐确实较轻。**这是保真原版意图的代价，不是缺陷**。
   若实机觉得过轻，正确做法是调 `Settings.define` 的 `default`（仅影响无 MOD 时），
   而不是给 MOD 值加换算 —— 那会破坏与 `kysmod.ini` 的可对照性。
2. **`Settings` 与 `ModIni.Apply` 的时序** —— ini 在 `SetGlobalConst()` 之后、
   `SetGlobal()` 之前应用；`Settings.load()` 必须在此之前完成，否则 user 层会被
   mod 层覆盖（优先级颠倒）。
3. **无原子写** —— `EngineAPI.file` 无 rename，写设置文件时若进程中断可能留下截断文件。
   **缓解**：读失败时回落到 default，不阻塞启动。
4. **显示为 `64/128` 而非 `50%`** —— 玩家需要适应这个量程。选择它的原因是
   内部 0-128 显示百分比会产生跳字（22% 的按键看不到变化）。若未来要做
   「0-100 + 百分比」的体验，需要同时改量程、增益换算与 MOD 映射，属独立议题。

## Traceability

| REQ | 主题 |
|-----|------|
| REQ-SET-1 | 设置三层优先级 |
| REQ-SET-2 | schema 声明与校验 |
| REQ-SET-3 | 持久化 |
| REQ-SET-4 | 变更通知 |
| REQ-VOL-1 | 音乐/音效独立音量 |
| REQ-VOL-2 | 引擎接线（per-source） |
| REQ-VOL-3 | mod.ini 音量接入 |
| REQ-MENU-1 | 值项描述符（待定值 → 确认提交） |
| REQ-MENU-2 | onCursorChange 钩子 |
| REQ-MENU-3 | 菜单入口位置 |
| REQ-CLEAN-1 | 死代码删除 |
| REQ-COMPAT-1 | 跨版本与跨平台 |

## Design Decisions（摘要）

| ADR | 决策 |
|-----|------|
| ADR-AS-001 | 三层优先级 + 点分命名空间键（`audio.music`） |
| ADR-AS-002 | 值项用**待定值 + 确认提交**，不做边调边听（防误触） |
| ADR-AS-003 | **量程 0-128 + 增益线性 `value/128`**；音量 per-source；显示原始值不做百分比 |
| ADR-AS-004 | INI + 写后回读校验（无 rename 原语，不做原子写） |
| ADR-AS-005 | mod.ini 音量**原样**注入 Settings **mod 层**（零换算），保留文件不动 |
| ADR-AS-006 | 3 层菜单：大地图「系统」+ 开始菜单「设置」，小场景不提供 |
| ADR-AS-007 | 菜单 ↔ 引擎经 `Settings.onChange` 解耦，菜单不碰 `EngineAPI` |
| ADR-AS-008 | `onCursorChange` 与值项分离；前者**不用于**音量 |
| ADR-AS-009 | 框宽只对值项按显示宽度算，既有菜单不变 |
