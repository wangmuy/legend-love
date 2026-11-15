# Tasks: audio-settings

## Blast Radius

### 新增

- `game/framework/settings.lua`
- `game/framework/settings_store.lua`
- `game/framework/audio_settings.lua`
- `game/framework/audio_menu.lua`
- `game/tests/unit/test_settings.lua`
- `game/tests/unit/test_settings_store.lua`
- `game/tests/unit/test_audio_settings.lua`
- `game/tests/unit/test_audio_menu.lua`

### 修改

- `game/framework/menu_state_machine.lua`
- `game/engine-love2d/engine_api.lua`
- `game/engine-love2d/engine_love2d.lua`
- `game/engine-love2d/lib_love.lua`
- `game/engine-mud/engine_mud.lua`
- `game/engine-web/engine_web.lua`
- `game/tests/engine_test.lua`
- `game/framework/jymain_async.lua`
- `game/framework/jymain_adapter.lua`
- `game/framework/mod_ini.lua`
- `game/tests/unit/test_mod_ini.lua`
- `game/tests/test_runner.lua`
- `game/framework/config.lua`
- `game/script/jymodify.lua`

### 不得触碰

- `game/tests/unit/test_version_compat.lua`（既有回归基线）
- `reference/allmods/**`（gitignored 上游素材，只读）
- `game/engine-web/**`（除 `engine_web.lua` 的 4 个 no-op）

---

## T1: `framework/settings.lua` — 设置核心（纯逻辑）

- [x] `Settings.define(key, spec)`：注册 schema（`default/type/min/max/label`）
- [x] `Settings.get(key)`：三层解析 `user > mod > default`（REQ-SET-1）
- [x] `Settings.set(key, value)`：写 user 层，钳制到 `[min,max]`，触发通知（REQ-SET-2）
- [x] `Settings.setMod(key, value)`：写 mod 层（供 `mod_ini` 用）
- [x] `Settings.setUser(key, value)` / `Settings.getLayer(key, layer)`：分层读写，便于测试
- [x] `Settings.onChange(key, fn)`：订阅；值未变不触发；监听器用 `pcall` 隔离（REQ-SET-4）
- [x] `Settings.keys()` / `Settings.spec(key)`：枚举能力（通用设置界面用）
- [x] `Settings.load()` / `Settings.save()`：委托 store，不自己碰 IO（REQ-SET-3）
- [x] `Settings.injectStore(store)`：测试注入点
- [x] `Settings.reset()`：清空状态（测试用）
- [x] **DoD**: 文件内 **零** `EngineAPI` / `love.` / `CC.` / `JY.` 引用
  （`grep -E "EngineAPI|love\.|CC\.|JY\." game/framework/settings.lua` 为空）

## T2: `framework/settings_store.lua` — INI 读写

- [x] `Store.read(path)` → `{sections}` 或 `nil, err`（INI 解析，含 BOM/CRLF/注释）
- [x] `Store.write(path, sections)` → `ok, err`（写后**回读校验**）
- [x] 只依赖 `EngineAPI.file.read` / `.write` / `.exists`，**不得** `io.open`（REQ-COMPAT-1）
- [x] `EngineAPI.file.write` 为空实现时 → 返回 false 且不抛错（web 降级）
- [x] 文件含 `[meta] version=1`
- [x] 复用 `mod_ini.lua` 的解析语义（大小写不敏感、`;`/`#` 注释、行尾注释）
- [x] **DoD**: `grep "io.open" game/framework/settings_store.lua` 为空

## T3: `menu_state_machine.lua` — 值项描述符 + onCursorChange

- [x] `createMenu`：值项的 `desc.pending` 从 `Settings.get(desc.key)` 初始化
- [x] `handleInput`：值项的 `VK_UP`/`VK_DOWN` 只改 `desc.pending`（钳制），
      **不调用** `Settings.set`（REQ-MENU-1）
- [x] `handleInput`：值项的 `VK_RETURN`/`VK_SPACE` → `Settings.set(desc.key, desc.pending)`
      + `closeMenu(item[4])`（唯一副作用点）
- [x] `handleInput`：值项的 `VK_ESCAPE` → 走既有 `isEsc` 分支，pending 自然丢弃
- [x] 值项上的上下键**不得**触发菜单导航
- [x] `draw()`：值项文本按 **`desc.pending`** 重算（**不是** `Settings.get`）
- [x] 多行文本项：`item[1]` 含 `\n` 时逐行 `DrawString`，行高 `size + CC.RowPixel`
- [x] `createMenu` 宽度：**仅值项**用 `TextBoxLayout.textWidth`（显示宽度）；
      既有菜单保持 `string.len` 语义不变（ADR-AS-009）
- [x] `menu.onCursorChange(menu, newCurrent, oldCurrent)` 钩子，`pcall` 包裹（REQ-MENU-2）
- [x] `onCursorChange` **不**接到音量菜单（ADR-AS-008 明确约束）
- [x] **DoD**: 既有 20+ 个菜单零影响 —— 全量测试零回归
- [x] **DoD**: 既有菜单框宽与改动前逐像素一致（可用截图或宽度断言验证）

## T4: `EngineAPI.audio` 音量四函数

- [x] `engine_api.lua`：`setMusicVolume` / `getMusicVolume` / `setSFXVolume` / `getSFXVolume`
      四个接口定义 + 注释（**`value` 0-128**，与原版 SDL_mixer 同量程）
- [x] `lib_love.lua`：模块级 `musicVolume` / `sfxVolume`（默认取自 Settings，即 64 / 90）
- [x] `lib_love.lua`：`PlayMIDI` 的 `newSource` 后应用 music 音量（拉）
- [x] `lib_love.lua`：`PlayWAV` 的 `newSource` 后应用 sfx 音量（拉）
- [x] `lib_love.lua`：`setMusicVolume` 对**正在播放**的 `currentMusic` 立即生效（推）
- [x] 增益映射 **线性** `value / 128`（REQ-VOL-2；**不得用平方**）
- [x] `engine_love2d.lua`：4 个函数委托 `lib.*`
- [x] `engine_mud.lua` / `engine_web.lua`：4 个 no-op
- [x] `tests/engine_test.lua`：4 个函数记录调用（如 `logCall("audio.setMusicVolume", v)`）
- [x] **DoD**: 四版本全量测试全绿
- [x] **DoD**: 断言 `setMusicVolume(64)` → 增益 `0.5`、`setMusicVolume(32)` → `0.25`、
      `setMusicVolume(128)` → `1.0`（线性，非平方）

## T5: `mod_ini.lua` 音量接入 Settings mod 层

- [x] `SECTION_MAP.music.volume` → `{ settings = "audio.music" }`（**无 `scale`**）
- [x] `SECTION_MAP.music.volumewav` → `{ settings = "audio.sfx" }`
- [x] `SECTION_MAP.system.volume` / `.volume2` 同步改为 settings 目标
- [x] `Map()`：支持 `settings` 目标类型，产出 `result.settings[key]`（原样搬入）
- [x] `Apply()`：把 `result.settings` 写入 `Settings.setMod`（**零换算**）
- [x] 删除 `CONFIG.MasterVolume` 相关的 `NUMERIC_KEYS` 条目（该字段退役）
- [x] **DoD**: mingdong 的 `VOLUME=22` → `audio.music` mod 层 = **22**；
      `VOLUMEWAV=26` → `audio.sfx` mod 层 = **26**（原样，REQ-VOL-3）
- [x] **DoD**: 20 个 MOD 逐个断言「mod 层值 == ini 原值」，无一例外

## T6: `audio_settings.lua` — 音量定义与引擎接线

- [x] `Settings.define("audio.music", {default=64, min=0, max=128, label="音乐音量"})`
- [x] `Settings.define("audio.sfx", {default=90, min=0, max=128, label="音效音量"})`
- [x] `init()`：注册 `onChange` 订阅 → 调 `EngineAPI.audio.setMusicVolume` 等（REQ-AS-007）
- [x] `init()`：启动时把当前值推一次到引擎（避免"注册前已设值"的漏推）
- [x] 幂等：重复 `init()` 不得重复注册监听器
- [x] **DoD**: `grep "EngineAPI" game/framework/audio_menu.lua` 为空

## T7: `audio_menu.lua` — 菜单构建

- [x] `buildVolumeMenu()` → 返回菜单项数组（音乐/音效两行值项）
- [x] 值项描述符形如 `{ "音乐音量  %d/128", {kind="number", key="audio.music", step=1}, 1 }`
      （**显示原始值，不换算百分比**）
- [x] **每次调用返回新表**（不得缓存复用，否则 `pending` 残留）
- [x] 三行箭头布局（形态 2）：`▲` / 值行 / `▼` 的文本拼装
      （`simsun.ttf` 实测含 `▲ U+25B2` / `▼ U+25BC`，不含 `▶ U+25B6`）
- [x] **不注册** `onCursorChange`（音量只走 Enter 确认）
- [x] **DoD**: 模块可脱离引擎单测（注入假 Settings）
- [x] **DoD**: `grep "EngineAPI" game/framework/audio_menu.lua` 为空

## T8: 菜单接入

- [x] `jymain_async.lua` `Menu_System`：在「保存进度」后插入音乐/音效音量两项（REQ-MENU-3）
- [x] `jymain_adapter.lua` `showStartMenuCoroutine`：新增「设置」项 → 其下挂两项
- [x] 小场景（`GAME_SMAP`）**不提供**入口（既有 `menu[5][3]=0; menu[6][3]=0` 不动）
- [x] `jymain_adapter.lua` 初始化：`Settings.load()` 必须在 `ModData.LoadIni()`
      **之前**（否则 user 层被 mod 层覆盖，优先级颠倒）
- [x] **DoD**: 大地图 系统→音乐音量→值调节 三层可达；开始菜单 设置→音乐音量 可达

## T9: 删死代码

- [x] 删除 `script/jymodify.lua` 的 `Menu_System_new`
- [x] 删除 `Menu_SetMusic` / `Menu_SetSound`
- [x] 删除 `SetModify()` 中 `Menu_System_old = Menu_System` 与 `Menu_System = Menu_System_new`
- [x] **保留** `JY.ThingUseFunction[182]` / `[0]` / `JY.SceneNewEventFunction[1]`
- [x] **DoD**: 全量测试零回归（REQ-CLEAN-1）

## T10: `config.lua` 音量字段退役

- [x] `CONFIG.MusicVolume` / `CONFIG.SoundVolume` 改为注释说明已迁移
- [x] 注释写明：默认值现在由 `audio_settings.lua` 的 `Settings.define` 提供
- [x] 注释写明：原 0-128 语义，MOD ini 值按 128 换算
- [x] **DoD**: `grep -rn "CONFIG.MusicVolume\|CONFIG.SoundVolume" game/` 只剩注释

## T11: 测试

- [x] `test_settings.lua`：三层优先级 / 钳制 / 通知 / 枚举 / 值未变不触发
- [x] `test_settings_store.lua`：INI 往返 / BOM / CRLF / 注释 / 回读校验失败路径
- [x] `test_audio_settings.lua`：`onChange` 真的调到假 `EngineAPI` / 幂等 init
- [x] `test_audio_menu.lua`：菜单项结构 / format 渲染 / 箭头字符 / 每次返回新表
- [x] `test_menu_state_machine.lua`（或既有菜单测试）：值项待定值语义
  - 上/下键只改 pending，`Settings.set` 调用 0 次
  - Enter 提交后才 `set`（调用 1 次）
  - ESC 放弃后值不变、`onChange` 未触发
  - 连按 50 次上键，`set` 仍为 0 次
  - 钳制到 0/128 不回绕
  - **既有菜单框宽不变**（回归断言）
- [x] `test_audio_engine` 相关：增益为线性
  - `setMusicVolume(64)` → gain `0.5`
  - `setMusicVolume(32)` → gain `0.25`
  - `setMusicVolume(128)` → gain `1.0`
  - 断言**不是**平方（`0.5` 而非 `0.25`）
- [x] `test_mod_ini.lua`：补充 `settings` 目标类型的断言（20 个 MOD 原样搬入）
- [x] `test_runner.lua`：注册新模块 + 更新帮助文本的模块列表
- [x] 负向对照：回退 `settings.lua` 的优先级逻辑 → 相关测试必须失败
- [x] 负向对照：把值项的上下键改成直接 `Settings.set` → 「连按不产生副作用」
      与「ESC 放弃」两条测试必须失败
- [x] 负向对照：把增益改回平方 → 线性映射断言必须失败
- [x] **DoD**: `lua tests/test_runner.lua` 四版本全绿，断言数不低于 2540

## DoD 汇总（change 级）

1. [x] Lua 5.1 / 5.3 / 5.4 / 5.5 全量测试全绿（各自记录断言数）
2. [x] `luac5.1 -p` 与 `luac5.5 -p` 全仓零失败
3. [x] 干净 Windows PATH 下测试结果与完整 PATH 一致
4. [x] `settings.lua` 零引擎依赖（`grep` 为空）
5. [x] `settings_store.lua` 无 `io.open`（`grep` 为空）
6. [x] mingdong 音量**原样搬入**断言通过（22→22 / 26→26，零换算）
7. [x] 大地图与小场景的入口差异断言通过
8. [x] **待定值语义闭环**：上下键 0 次 `set`、Enter 1 次 `set`、ESC 0 次影响
9. [x] **既有菜单零视觉变化**：框宽与改动前一致
10. [x] **增益为线性**：`value/128`，不是平方（MOD 音量保真）
11. [x] **显示无跳字**：0→128 逐次按键，每次显示都不同
12. [x] LÖVE 11.5 启动冒烟无报错
13. [x] 负向对照：至少 3 处（优先级 / 待定值 / 平方增益）能被"回退即失败"证明
