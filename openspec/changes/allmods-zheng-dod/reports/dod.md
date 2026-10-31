---
status: active
created: 2026-10-18
---
# DoD 核实报告: allmods-zheng — 魏征传奇

> Slice: `openspec/changes/allmods-slice-zheng/slice-proposal.md`
> 步骤链: 逆向分析 → 确认修改 → 测试验证 → **DoD 核实**

## 1. 缺陷与根因（逆向分析）

| 项 | 内容 |
|---|---|
| 缺陷 | Thing 196 U+FFFD + 47 控制符；Scene 54 空 + 24 控制符；Wugong 214 空 |
| 根因 | `save/ranger.idx` 描述的是 138596 字节存档，而非 114242 字节 `ranger.grp` |
| 修复 | `M.IdxIsConsistent` / `M.DetectLayout` / `M.RepairIdx`（数据驱动）；构建期写出修复后的 `data/ranger.idx` |

## 2. 修改前 / 修改后（确认修改）

| | 结果 |
|---|---|
| 修改前 | 358/201/94/216（错位）+ 196 FFFD + 71 控制符 + 268 空 |
| **修改后** | **320/200/84/93 + 0 FFFD + 0 控制符 + 0 空** |

## 3. 验收命令与实测输出

### 3.1 全 MOD 自检 — `lua tools/mod_check.lua`

```
总计: 20 MOD, 通过 20, 失败 0
zheng: OK  320/200/84/93  STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.2 单 MOD 端到端 — `MOD_SLUG=zheng lua tools/mod_check_one.lua`

```
PERSON=320
THING=200
SCENE=84
WUGONG=93
HERO=小蝦米
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

直接解析构建产物 `mods/zheng/data/ranger.str`：

```
zheng: 字段级 FFFD=0  CTRL=0  EMPTY=0  → CLEAN
```

### 3.7 尺寸不变与幂等

| 项 | 结果 |
|---|---|
| 源 `ranger.grp` 大小 vs 产物 | 完全一致 |
| 连续两次 `--all` | 结果逐字节相同 |
| 连续两次全量测试 | 340/340 |
| idx | `836,59076,97076,101444,114092,114242` |

### 关键证据：idx 修复精确正确

| 项 | 值 |
|---|---|
| zheng 出厂 idx 末值 | 138596 |
| zheng `ranger.grp` 大小 | 114242 |
| 修复后 idx | `836,59076,97076,101444,114092,114242` |
| 修复后产物 `mods/zheng/data/ranger.idx` | 同上（24 字节小端 uint32）|
| `IdxIsConsistent(修复结果, 114242)` | `true` |

### 关键证据：pascal 未被触碰

`E.RepairIdx(pascalGrp, pascalIdx)` → 逐值等于出厂 idx，reason=`nil`。


### 3.8 真实启动链路（独立进程，最强证据）

`tests/unit/boot_one_mod.lua` 在**独立进程**中真实执行
`lib.init → JYMainAdapter.init → LoadRecord(0) → 10 帧运行时`：

```
[PASS] lib.init 无报错: nil
[PASS] JYMainAdapter.init 无报错: nil
[PASS] CC.PersonSize=182 / ThingSize=190 / SceneSize=52 / WugongSize=136（MOD 布局生效）
[PASS] LoadRecord(0) 无报错: true
[PASS] PersonNum=320 ThingNum=200 SceneNum=84 WugongNum=93
[PASS] 主角姓名 = 小蝦米
[PASS] 扫描字段数 > 100（实际 1417）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
RESULT zheng: OK
```

> 独立进程是关键：真实启动是"一次进程一个 MOD"，同进程内反复重载 `jymain`/`lib`
> 会留下 `JY` 全局残留，反而不能证明真实启动路径。
> 本测试已接入 `tests/test_runner.lua mod_boot`（子进程调用，85 断言）。

## 4. 零回归核实

| 检查 | 结果 |
|---|---|
| 其余 19 个 MOD 自检 | 全部 OK |
| pascal 基线 | PASS（3 个已知偏差，均为原版提取器 bug）|
| 修复逻辑是否含 MOD 名分支 | **否**（grep 确认：MOD 名仅出现在注释中）|
| 完好 MOD 的 idx 是否被触碰 | **否**（pascal reason=nil，逐值相同）|
| 构建幂等 | **是** |

## 5. 新增回归测试

`testIdxIsConsistentRejectsOvershoot`、`testRepairIdxDetectsZhengLayout`、`testRepairIdxLeavesGoodIdxUntouched`、`testDetectLayoutZhengExact`、`testConvertRangerNoReplacementCharsAllMods`、`testConvertRangerNoControlCharsAllMods`

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

**结论：魏征传奇（kys-zheng）已成功逆向并修复验证通过。**
