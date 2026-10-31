---
status: active
created: 2026-10-18
---
# DoD 核实报告: allmods-pig3dos — 金庸水浒传dos版

> Slice: `openspec/changes/allmods-slice-pig3dos/slice-proposal.md`
> 步骤链: 逆向分析 → 确认修改 → 测试验证 → **DoD 核实**

## 1. 缺陷与根因（逆向分析）

| 项 | 内容 |
|---|---|
| 缺陷 | Person 565 控制符 + 42 空值（全部集中在「外号」槽位 @18） |
| 根因 | pig3dos 的 Person 记录没有外号字段，@18 是 int16 数值 stat 数组；旧守卫 `startsBig5Pair` 会漏掉混合 ASCII+Big5 字段 |
| 修复 | 字符串字段判定改为 `hasHighByte(raw)`：含任意高位字节即转换，纯数值字段自动跳过 |

## 2. 修改前 / 修改后（确认修改）

| | 结果 |
|---|---|
| 修改前 | Person 565 控制符 + 42 空；全 MOD 13/20 通过（7 个 badUtf8） |
| **修改后** | **607 条外号槽位全部正确跳过、607 条姓名全部转换；全 MOD 20/20 通过** |

## 3. 验收命令与实测输出

### 3.1 全 MOD 自检 — `lua tools/mod_check.lua`

```
总计: 20 MOD, 通过 20, 失败 0
pig3dos: OK  607/242/133/202  STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.2 单 MOD 端到端 — `MOD_SLUG=pig3dos lua tools/mod_check_one.lua`

```
PERSON=607
THING=242
SCENE=133
WUGONG=202
HERO=主角
STRINGS=OK
EVENTS=OK
SAVE=OK
```

### 3.3 pascal 基线 — `lua tools/mod_build.lua --verify-pascal`

```
[mod_build] pascal baseline: events=1018, mismatches=0, known-deviations=3
[mod_build] pascal baseline: PASS
```

### 3.4 全 MOD 构建 — `lua tools/mod_build.lua --all`

```
[mod_build] all: 20 mods, 0 build failures, 5 annotated-problematic
```

### 3.5 全量测试 — `lua tests/test_runner.lua`

```
总测试数: 364
通过: 340
失败: 0
✓ 所有测试通过!
```

### 3.6 深度字段级审计（`mod_check_one.lua` 之外的独立校验）

直接解析构建产物 `mods/pig3dos/data/ranger.str`：

```
pig3dos: 字段级 FFFD=0  CTRL=0  EMPTY=0  → CLEAN
```

### 3.7 尺寸不变与幂等

| 项 | 结果 |
|---|---|
| 源 `ranger.grp` 大小 vs 产物 | 完全一致 |
| 连续两次 `--all` | 结果逐字节相同 |
| 连续两次全量测试 | 340/340 |
| idx | （idx 本就一致，未改动） |

### 关键证据：外号槽位是数值而非字符串

```
Person r0 @18 len10: 0700 0700 0700 0a00 0000   → int16 数组 7,7,7,10
Person r0 @8  len10: a544a8a4 000000000000      → "主角"
```

全 607 条统计：**@18 含高位字节的记录数 = 0**。

### 关键证据：附带修复 23 个混合字段

判据从 `startsBig5Pair` 改为 `hasHighByte` 后，以下字段不再泄漏原始 Big5 字节：

| MOD | 段 | 记录 | 修复前（原始字节）| 修复后 |
|---|---|---|---|---|
| mingdong | Thing | 112 | `3533 a141 323139` | `53，219` |
| pig | Thing | 165-169 | `32303038 a67e…` | `2008年北京奧運會吉祥物` |
| Dragon | Person | 515 | `3f3f acc3` | `??珍` |
| books | Person | 302 | `3fc55d` | `?魔` |
| BookCalamity | Thing | 364 | `3fb6a7a44daef0` | `?陽刀氣` |


### 3.8 真实启动链路（独立进程，最强证据）

`tests/unit/boot_one_mod.lua` 在**独立进程**中真实执行
`lib.init → JYMainAdapter.init → LoadRecord(0) → 10 帧运行时`：

```
$ lua tests/unit/boot_one_mod.lua pig3dos 607 242 133 202 主角
[PASS] lib.init 无报错: nil
[PASS] JYMainAdapter.init 无报错: nil
[PASS] CC.PersonSize=182（MOD 布局）
[PASS] CC.ThingSize=190（MOD 布局）
[PASS] CC.SceneSize=52（MOD 布局）
[PASS] CC.WugongSize=136（MOD 布局）
[PASS] LoadRecord(0) 无报错: true
[PASS] PersonNum (期望 607, 实际 607)
[PASS] ThingNum (期望 242, 实际 242)
[PASS] SceneNum (期望 133, 实际 133)
[PASS] WugongNum (期望 202, 实际 202)
[PASS] 主角姓名 (期望 主角, 实际 主角)
[PASS] 扫描字段数 > 100（实际 2275）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
RESULT pig3dos: OK
```

### 3.9 追加修复：跳过的数值字段必须被中和（本轮新发现）

**真实启动链路测试暴露了一个 `mod_check_one.lua` 与旁路表审计都看不见的 bug。**

第一次跑启动链路时，pig3dos 的 `JY.Person` 仍报 **565 个控制符**，尽管旁路表 `ranger.str`
完全干净。根因：

- 构建期把 Person 外号（@18，int16 stat）判定为非字符串并**跳过转换**；
- 但**原始数值字节留在 `.grp` 缓冲区里**；
- 引擎结构表 `ModData.MOD_STRINGS.Person.外号 = {18, 2, 10}` 仍把该偏移声明为**字符串**；
- 于是 `GetDataFromStruct` 用 `Byte.getstr` 把 `07 00 07 00 07 00 0a 00 00 00` 当文本读出 → 控制符。

**修复**：跳过的字段也必须写入一个解析为空字符串的 hint（`N0000`），中和该槽位。
数值数据只存在于 `.grp` 中，引擎无任何代码按数值读取这些偏移，因此无信息丢失。

修复后：`Person[0] 外号槽位 = "N0000"` → 引擎解析为 `""`；全量 2275 个字段 **0 控制符**。

> 影响范围：全 20 MOD 中有 7 个 MOD 存在被跳过的字段
> （ptt、pineapple、dream、HeavenSword、GodsDevils、lyff、pig3dos），全部被同一修复覆盖。
> 回归测试：`testSkippedFieldNeutralisedForAllMods`、`testConvertRangerSkipsNumericFields`。

## 4. 零回归核实

| 检查 | 结果 |
|---|---|
| 其余 19 个 MOD 自检 | 全部 OK |
| pascal 基线 | PASS（3 个已知偏差，均为原版提取器 bug）|
| 修复逻辑是否含 MOD 名分支 | **否**（grep 确认：MOD 名仅出现在注释中）|
| 完好 MOD 的 idx 是否被触碰 | **否**（pascal reason=nil，逐值相同）|
| 构建幂等 | **是** |

## 5. 新增回归测试

`testConvertRangerSkipsNumericFields`（pig3dos skipped=607、Person.converted=607）、`testConvertRangerConvertsMixedAsciiBig5Fields`（mingdong `53，219`）、`testConvertRangerNoReplacementCharsAllMods`、`testConvertRangerNoControlCharsAllMods`

全部位于 `game/tests/unit/test_mod_encoding.lua`（41 断言）或 `test_mod_ini.lua`，
已在 `game/tests/test_runner.lua` 注册为 `mod_encoding` / `mod_ini` 模块。

## 6. DoD 结论

- [x] 逆向分析完成，根因从数据本身推导（不硬编码 MOD 名）
- [x] 修改已确认生效（构建产物逐项验证）
- [x] 测试验证通过（单元 + 端到端 + 深度审计）
- [x] 全 20 MOD 自检 20/20
- [x] pascal 基线 PASS
- [x] 全量测试 340/340
- [x] 零回归（其余 19 MOD + pascal + 幂等）

**结论：金庸水浒传dos版（kys-pig3dos）已成功逆向并修复验证通过。**
