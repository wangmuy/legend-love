# Tasks: allmods-ini-parser

## Blast Radius

- `game/framework/mod_ini.lua`（新增）
- `game/tests/unit/test_mod_ini.lua`（新增）
- `game/tests/test_runner.lua`（注册测试模块）

## Tasks

### T1: 实现 `game/framework/mod_ini.lua`
- [x] `ModIni.Load(path)` / `ModIni.ParseText(text)` → `{CONFIG, CC, unknown, raw}`（Contract A）
- [x] `ModIni.Apply(parsed)` 只覆盖出现的键，未出现保持默认（REQ-INI-3）
- [x] 键名映射表 `SECTION_MAP`（system/music/constant），大小写不敏感
- [x] typo 键名 `SCENCEAMI` 显式登记（与 `SCENEAMI` 并存，均 → `CC.SceneAmi`）（REQ-INI-2）
- [x] 拼写变体 `BEGIN_SCENCE`/`BEGIN_SCENE` 均 → `CC.NewGameSceneID`
- [x] `BEGIN_Sx`/`BEGIN_Sy` 的 x/y 反转映射（原版 x/y 与 love2d 相反）
- [x] `MaxProList43..58` 动态映射 → `CC.MaxProListNN`
- [x] 容错：BOM、CRLF、`;`/`#` 注释、行尾注释、空行、缺段、未知键（→ unknown）
- **DoD**: 模块可独立加载（纯 framework，无引擎依赖）

### T2: 单元测试覆盖 19 个真实 ini
- [x] 19 个 MOD 的 `kysmod.ini` 全部解析成功（REQ-INI-1）
- [x] 抽样值断言：mingdong 960x660 / `SCENCEAMI=2` / `MAX_ITEM_AMOUNT=330` / `MAX_HP=9999`
- [x] 抽样值断言：GodsDevils `EXP_RATE=4`
- [x] 抽样值断言：pascal 640x440 / `EXP_RATE=100` / `MAX_WEAPON_MATCH=7` / `MIN_KNOWLEDGE=80`
- [x] 容错路径：空文件、缺段、未知键、BOM、行尾注释
- [x] 已知键不泄漏到 `unknown`
- [x] 注册到 `tests/test_runner.lua`（`mod_ini` 模块）
- **DoD**: `lua tests/test_runner.lua mod_ini` 全绿

## DoD 汇总（change 级）

1. [x] `lua tests/test_runner.lua mod_ini` 全绿（73 tests, 73 passed）
2. [x] 19 个 MOD 的 `kysmod.ini` 全部解析成功（含 typo 键名），无报错
3. [x] 抽样值断言通过（mingdong 分辨率、GodsDevils `EXP_RATE`）
4. [x] 无 `active_mod.txt` 时全量测试零回归（110 tests, 110 passed）
