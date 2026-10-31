---
status: active
created: 2026-10-18
---
# 逆向分析报告: kys-loving（问情篇）

> games.ini index 10 —「问情篇（好像不太正常）」

## 1. 现象（深度审计复现）

与其余 4 个 MOD 不同，loving 的**字段级数据完全干净**：

| 段 | FFFD | CTRL | EMPTY |
|---|---|---|---|
| Person | 0 | 0 | 0 |
| Thing | 0 | 0 | 0 |
| Scene | 0 | 0 | 0 |
| Wugong | 0 | 0 | 0 |

但深度审计发现一个**结构性异常**：`BEGIN_SCENE = -1`。

## 2. 关键证据：kysmod.ini 的负值索引

`reference/allmods/kys-loving/kysmod.ini`：

```ini
31: ITEM_BEGIN_PIC = 3501
33: BEGIN_EVENT = -1
35: BEGIN_SCENE = -1
37: BEGIN_Sx = 20
38: BEGIN_Sy = 19
40: SOFTSTAR_BEGIN_TALK = 2547
50: BEGIN_LEAVE_EVENT = 950
```

`BEGIN_SCENE = -1` 与 `BEGIN_EVENT = -1` 是 MOD 作者声明「**不指定**新游戏起始场景/事件」（让启动器沿用默认）。

## 3. 根因：引擎无条件索引数组

引擎启动链路：

```lua
-- game/script/jymain.lua:192
JY.SubScene=CC.NewGameSceneID;         -- 新游戏直接进入场景

-- game/framework/jymain_adapter.lua:346
JY.SubScene = CC.NewGameSceneID
```

随后（`jymain.lua` 的 `Game_SMap` 路径）会执行 `JY.Scene[JY.SubScene]["名称"]`。

如果 `ModIni` 把 `BEGIN_SCENE = -1` 照搬到 `CC.NewGameSceneID`：

- `JY.SubScene = -1`
- `JY.Scene[-1]` → **nil**
- `nil["名称"]` → **崩溃**（`attempt to index a nil value`）

## 4. 对照：原版 `base` 的行为

- 原版 C 引擎（`base` 分支）**不读取 `kysmod.ini`**（`git grep kysmod base` 无结果）。
- `base:bin/script/jyconst.lua` 硬编码 `CC.NewGameSceneID=70`、`CC.NewGameEvent=691`。
- `kysmod.ini` 是 `AllMod-Launcher.exe` 的配置，`-1` 在启动器语义里表示「未设置」。

因此：**负值应当被视为「不覆盖」，保持引擎默认值（70/691）。**

## 5. 结论与修复方向

在 `ModIni.Map` 增加「不可为负」守卫（**数据驱动：只按值是否为负判定，与 MOD 名无关**）：

```lua
local NON_NEGATIVE_KEYS = {
    ["CC.NewGameSceneID"]    = true,
    ["CC.NewGameEvent"]      = true,
    ["CC.SoftStarBeginTalk"] = true,
    ["CC.BeginLeaveEvent"]   = true,
}
```

映射时若 `NON_NEGATIVE_KEYS[qualified]` 且 `tonumber(v) < 0` → **跳过**（不覆盖）。

- `-1` → 跳过 → `CC.NewGameSceneID` 保持引擎默认 70 ✓
- `0` 或正数 → 正常覆盖 ✓（`BEGIN_SCENE = 0` 是合法场景索引）

## 6. 验证

- 单元测试 `testNegativeSceneIndexIgnored`：`BEGIN_SCENE = -1` → `result.CC.NewGameSceneID == nil`；`BEGIN_SCENE = 5` → `result.CC.NewGameSceneID == 5`。
- `MOD_SLUG=loving lua tools/mod_check_one.lua` → `STRINGS=OK EVENTS=OK SAVE=OK`，HERO=莫言。
- `test_mod_ini.lua` 81/81 通过。
- 全 20 MOD 零回归。
