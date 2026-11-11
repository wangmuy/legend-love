---
status: active
created: 2026-10-18
---
# DoD 核实报告: allmods-awaken — 真龙苏醒

> Slice: `openspec/changes/allmods-slice-awaken/slice-proposal.md`
> 步骤链: 逆向分析 → 确认修改 → 测试验证 → **DoD 核实**

## 1. 缺陷与根因（逆向分析）

| 项 | 内容 |
|---|---|
| 缺陷 | Thing 6 个控制符（尾部 + **内部** CRLF） |
| 根因 | 同 BookCalamity：作者把换行粘进定长字段；awaken 特殊在于 r89 是**内部** CRLF |
| 修复 | `M.TrimControl` 同时折叠内部与尾部 CR/LF（含孤立 `\r`） |

## 2. 修改前 / 修改后（确认修改）

| | 结果 |
|---|---|
| 修改前 | `須彌山神掌\r\n` / `七傷拳\r\n譜` / `五毒秘傳\r\n` / `…醫書\r` |
| **修改后** | **`須彌山神掌` / `七傷拳譜` / `五毒秘傳` / `…醫書`** |

## 3. 验收命令与实测输出

### 3.1 全 MOD 自检 — `lua tools/mod_check.lua`

```
总计: 20 MOD, 通过 20, 失败 0
awaken: OK  720/237/153/163  STRINGS=OK  EVENTS=OK  SAVE=OK
```

### 3.2 单 MOD 端到端 — `MOD_SLUG=awaken lua tools/mod_check_one.lua`

```
PERSON=720
THING=237
SCENE=153
WUGONG=163
HERO=北辰月
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

直接解析构建产物 `mods/awaken/data/ranger.str`：

```
awaken: 字段级 FFFD=0  CTRL=0  EMPTY=0  → CLEAN
```

### 3.7 尺寸不变与幂等

| 项 | 结果 |
|---|---|
| 源 `ranger.grp` 大小 vs 产物 | 完全一致 |
| 连续两次 `--all` | 结果逐字节相同 |
| 连续两次全量测试 | 340/340 |
| idx | （idx 本就一致，未改动） |

### 关键证据：内部 CRLF 证明必须折叠而非仅剥尾

| 记录 | 字段 | 原始 | 说明 |
|---|---|---|---|
| r88 | 物品名(@2) | `b6b7c0b1a473afabb478` `0d0a` | 尾部 CRLF |
| **r89** | 物品名(@2) | `a443b6cbaeb1` `0d0a` `c3d0` | **内部** CRLF（`七傷拳\r\n譜`）|
| r110 | 物品名(@2) | `a4adac72a9b4b6c7` `0d0a` | 尾部 CRLF |
| r187 | 物品说明(@42) | `…b3e6b473` `0d` | **孤立 CR**（无 `\n`）|

只剥尾部会把 r89 变成 `七傷拳\r\n` + 丢失 `譜`；只找 `\r\n` 两字节序列会漏掉 r187 的孤立 `\r`。


### 3.8 真实启动链路（独立进程，最强证据）

`tests/unit/boot_one_mod.lua` 在**独立进程**中真实执行
`lib.init → JYMainAdapter.init → LoadRecord(0) → 10 帧运行时`：

```
[PASS] lib.init 无报错: nil
[PASS] JYMainAdapter.init 无报错: nil
[PASS] CC.PersonSize=182 / ThingSize=190 / SceneSize=52 / WugongSize=136（MOD 布局生效）
[PASS] LoadRecord(0) 无报错: true
[PASS] PersonNum=720 ThingNum=237 SceneNum=153 WugongNum=163
[PASS] 主角姓名 = 北辰月
[PASS] 扫描字段数 > 100（实际 2467）
[PASS] 全量字符串无 U+FFFD (期望 0, 实际 0)
[PASS] 全量字符串无控制符 (期望 0, 实际 0)
[PASS] 运行时 10 帧无报错: nil
RESULT awaken: OK
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

`testTrimControlInteriorCrLf`（`大剪刀\r\n刀法` → `大剪刀刀法`）、`testTrimControlStripsTrailingNulLikeControls`、`testConvertRangerNoControlCharsAllMods`

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

**结论：真龙苏醒（kys-awaken）已成功逆向并修复验证通过。**
