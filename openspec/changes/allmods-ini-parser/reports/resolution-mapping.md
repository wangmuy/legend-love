# RESOLUTIONX / RESOLUTIONY 映射问题分析（画面缩小）

**日期**: 2026-10-17
**关联 change**: `allmods-ini-parser`（修正）、`allmods-encoding-convert`（上下文）
**状态**: 已修复

---

## 1. 现象

选择任意 MOD（含 `kys-pascal`）启动后，游戏窗口比原版**明显缩小**。

| 场景 | 窗口尺寸 |
|------|---------|
| 不选 MOD（原版） | 1024 × 768 |
| 选 `kys-pascal` | **640 × 440**（变小） |
| 选 `kys-mingdong` | **960 × 660**（变小） |
| 选 `kys-dream` | **640 × 480**（变小） |

---

## 2. 根因

`game/framework/mod_ini.lua` 的 `SECTION_MAP.system` 把 `kysmod.ini` 的 `RESOLUTIONX/Y`
映射到了 `CONFIG.Width/Height` 与 `CC.ScreenW/H`：

```lua
resolutionx   = { {"CONFIG", "Width"},  {"CC", "ScreenW"} },
resolutiony   = { {"CONFIG", "Height"}, {"CC", "ScreenH"} },
```

`conf.lua` 用 `CONFIG.Width/Height` 作为 `t.window.width/height`，因此 ini 的值直接
覆盖了窗口尺寸。

各 MOD 的 ini 取值：

| MOD | RESOLUTIONX | RESOLUTIONY |
|-----|-------------|-------------|
| kys-pascal | 640 | 440 |
| kys-awaken / Dragon / GodsDevils / HeavenSword / lostbook / pig3dos / RiverLake / stronger / SweeOan / zheng | 640 | 440 |
| kys-dream / pineapple | 640 | 480 |
| kys-mingdong | 960 | 660 |
| kys-books / loving / lyff / pig | 640（**被 `;` 注释掉**） | 480 / 440 |
| kys-BookCalamity / kys-ptt | （无此项） | |

---

## 3. 证据：原版引擎从不读 `kysmod.ini`

在 `base` 分支（原版 C 引擎）中检索：

```bash
$ git grep -i -n "kysmod\|RESOLUTIONX" base
（无输出）
```

- `base:src/sdlfun.c` 的窗口尺寸来自 `g_ScreenW/g_ScreenH`，其值由 `base:bin/config.lua` 提供。
- `base:bin/config.lua` 中 `CONFIG.Width = 1024`、`CONFIG.Height = 768`，**没有**任何
  `kysmod.ini` 解析代码。
- 在 `base` / `love2d-event-driven` / `master` 三个分支上检索 `kysmod` 均为空。

**结论**：`kysmod.ini` 是 **AllMod-Launcher.exe**（`reference/allmods/AllMod-Launcher.exe`，
一个独立的 Windows 启动器）的配置，用于在启动游戏前设置窗口提示。它**不是游戏引擎的配置**。
原版游戏窗口始终是 `config.lua` 里的 1024×768。

---

## 4. 影响面：分辨率只影响窗口与居中，不影响游戏逻辑

`CC.ScreenW/H` 的全部使用点都是**居中计算**：

| 文件 | 用途 |
|------|------|
| `jymain_adapter.lua:140,235,322,414` | 主菜单居中 |
| `item_async.lua:265-266` | 物品框居中 |
| `async_dialog.lua:59,62,455,458` | 对话框居中 |
| `jymain_async.lua` | 菜单清屏区域 |
| `game_states.lua:161,165,396,561` | 裁剪区 / 坐标调试显示 |
| `war_async.lua:497-498,1215-1217` | 战斗 HUD / 等距投影居中 |
| `jyconst.lua:557-558` | 开始菜单 Y 坐标 |

这些代码用 `CC.ScreenW/H` 做相对计算，**会自动适配任意窗口尺寸**。因此：
- 不存在「MOD 需要特定分辨率」的技术原因；
- 恢复 1024×768 不会造成布局错乱（本就以 1024×768 为基准设计）。

---

## 5. 修复

删除 `SECTION_MAP.system` 中的 `resolutionx` / `resolutiony` 映射。两键落入
`unknown`（无害保留，仅记录），不再覆盖 `CONFIG.Width/Height`。

```lua
system = {
    -- RESOLUTIONX/Y 不映射：
    -- 原版 C 引擎（base 分支）从不读 kysmod.ini，窗口尺寸只来自 config.lua
    -- 的 CONFIG.Width/Height（1024x768）。kysmod.ini 的 RESOLUTIONX/Y
    -- 是 AllMod-Launcher.exe（独立 Windows 启动器）的窗口提示，与游戏逻辑无关。
    -- 映射到 CONFIG.Width/Height 会把窗口缩到 640x440，属错误适配。
    volume        = { {"CONFIG", "MasterVolume"} },
    ...
}
```

### 验证

| MOD | 修复后 `CONFIG.Width×Height` |
|-----|------------------------------|
| pascal | 1024 × 768 |
| mingdong | 1024 × 768 |
| dream | 1024 × 768 |
| pineapple | 1024 × 768 |

单元测试 `tests/unit/test_mod_ini.lua` 更新为断言「不映射」语义（75/75 通过）。

---

## 6. 其他键是否也需要重新评估？

同批映射中，`volume` / `volumewav` 映射到 `CONFIG.MasterVolume` / `CONFIG.SoundVolume`。
这些键在 `base:bin/config.lua` 中对应 `CONFIG.MusicVolume` / `CONFIG.SoundVolume`，
语义相近，属于**合理的适配**（音量是游戏内行为）。本次仅修正分辨率项。

> 注：`volume` 在 `SECTION_MAP.system` 中映射到 `CONFIG.MasterVolume`，但
> `framework/config.lua` 定义的是 `CONFIG.MusicVolume`。这是一个**独立的小问题**
> （映射到了不存在的键，等于无效），不影响本次分辨率修复，留待后续核对。
