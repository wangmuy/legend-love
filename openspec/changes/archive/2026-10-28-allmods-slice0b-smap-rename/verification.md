# Verification: allmods-slice0b-smap-rename

> Contract A owner · 子 change 1/3 · 状态：**✓ PASSED**

## 1. 执行摘要

构建期新增资源别名映射，把 MOD 的 C 引擎命名 `sdx`/`smp`/`wdx`/`wmp` 转换为 Lua 引擎命名 `smap.idx`/`smap.grp`/`wmap.idx`/`wmap.grp`。

**修复前**：20/20 MOD 的场景地图贴图（mingdong 4.5MB）与战斗地图贴图（2.4MB）全部静默回退原版。
**修复后**：20/20 MOD 正确加载自身地图数据。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实现 | 验证证据 | 状态 |
|-----|------|------|---------|------|
| [REQ-ALIAS-1] | 构建期别名映射 4 个文件 | `tools/mod_build.lua` `ALIAS_MAP` + `applyAlias`；`flattenResources` 在 `kind=="data"` 时应用 | `test_mod_build.testAliasMapInSource`；20/20 MOD 产物含 `smap.*`/`wmap.*` | ✓ |
| [REQ-ALIAS-2] | 仅 `resource/` 来源生效 | 条件 `if f.kind == "data" and ALIAS_MAP[destRel]` | `test_mod_build.testAliasOnlyAppliedToDataKind` | ✓ |
| [REQ-ALIAS-3] | 冲突硬失败 | `aliased and written[dest]` → 返回错误 → 非 0 退出 | `test_mod_build.testConflictDetectionInSource`；20/20 MOD 实测无别名冲突 | ✓ |
| [REQ-ALIAS-4] | diff 识别改名对 | `buildDiff` 新增「资源别名转换」小节 + `aliasedTargets`/`aliasedSources` 过滤 | `test_mod_build.testDiffHasAliasSection`；20/20 diff.md 含小节，0 误报 | ✓ |
| [REQ-ALIAS-5] | 运行时指向 MOD | `ModData.RewriteConstants` 的 `smap.*`/`wmap.*` 回退链（既有能力，无需改） | `test_mod_data.testRewriteConstantsSmapAliasTarget`；独立子进程实测 | ✓ |
| [REQ-ALIAS-6] | 零回归 | 未激活 MOD 时常量不变 | 全量测试 449/449；`--verify-pascal` PASS | ✓ |

### 补充：内容不变性（REQ-ALIAS-1 的 MUST NOT 改变文件内容）

| 验证 | 结果 |
|------|------|
| `mods/mingdong/data/smap.grp` == `reference/allmods/kys-mingdong/resource/smp` | 逐字节相同 ✓ |
| `test_mod_build.testMingdongArtifactsIfBuilt` | 断言逐字节相同 ✓ |

## 3. 实测证据

### 3.1 产物检查（20/20 MOD）

```
MOD 总数: 20
smap+wmap+sound 全部就绪且无残留: 20/20
diff.md 含别名小节: 20/20
误报数（smap/wmap/sdx 出现在文件差异）: 0
```

### 3.2 运行时证明（mingdong，独立子进程）

```
[PASS] SMAPPicFile[1] -> MOD smap.idx: mods/mingdong/data/smap.idx
[PASS] SMAPPicFile[2] -> MOD smap.grp
[PASS] WMAPPicFile[1] -> MOD wmap.idx: mods/mingdong/data/wmap.idx
[PASS] WMAPPicFile[2] -> MOD wmap.grp
[PASS] smap.idx 18540 字节 = 4635 项（原版 16516 字节 = 4129 项）
[PASS] wmap.idx 15400 字节 = 3850 项
```

`SMAPPicFile` 条目数 **4635**（MOD 实际值）≠ **4129**（原版）→ 证明读取的是 MOD 数据而非回退。

### 3.3 diff.md 片段（mingdong）

```
## 资源别名转换
- sdx → smap.idx
- smp → smap.grp
- wdx → wmap.idx
- wmp → wmap.grp
```

### 3.4 全量重建

```
[mod_build] all: 20 mods, 0 build failures, 5 annotated-problematic
```

### 3.5 pascal 基线

```
[mod_build] pascal baseline: events=1018, mismatches=0, known-deviations=3
[mod_build] pascal baseline: PASS
```

### 3.6 幂等性

```
run1: 36b6ab9156e4deb32a362a500a49bf95
run2: 36b6ab9156e4deb32a362a500a49bf95
✓ 幂等
```

## 4. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/tools/mod_build.lua` | `ALIAS_MAP`、`applyAlias`、`ALIAS_TARGETS`/`ALIAS_SOURCES`、`flattenResources`、`buildDiff`、`Build` | ✓ |
| `game/tests/unit/test_mod_build.lua` | 新增 | ✓ |
| `game/tests/unit/test_mod_data.lua` | 新增 smap 别名断言 | ✓ |
| `game/tests/unit/test_mod_e2e.lua` | 更新 smap/wmap 断言（旧断言锁定 bug 行为） | ✓ |
| `game/tests/unit/test_mod_boot.lua` | 同上 | ✓ |
| `game/tests/test_runner.lua` | 注册新模块 | ✓ |
| `game/mods/**` | 20 MOD 重建产物 | ✓ |

**未触碰**：`game/engine-love2d/**`、`game/engine-mud/**`、`game/framework/mod_data.lua`（无需改）、`reference/allmods/**`。✓

## 5. 测试结果

| 测试套件 | 结果 |
|---------|------|
| `lua tests/test_runner.lua` | **449/449 通过**（原 364 + 新增 85） |
| `lua tests/test_runner.lua mod_build` | 30/30 通过 |
| `lua tools/mod_build.lua --all` | 20 mods, 0 failures |
| `lua tools/mod_build.lua --verify-pascal` | PASS |
| `lua tools/mod_check.lua` | 20/20 通过 |
| `lua tests/unit/boot_one_mod.lua mingdong 632 367 139 220 小蝦米` | RESULT OK |

## 6. 偏差记录

| 偏差 | 说明 | 处置 |
|------|------|------|
| `mod_build.lua --all` 不清理旧产物 | 首次 `--all` 后 19 个 MOD 仍残留 pre-alias 的 `sdx/smp` | 新增 `rmdirp(outRoot)` 在 `Build` 开头清理；属 REQ-ALIAS-1 的必要组成（否则旧名残留） |
| 冲突检测范围收窄 | 初版对**所有**重复目标名报错，导致 RiverLake（`alldef.grp` 同时存在于 `resource/` 与 `save/`，历史既有）构建失败 | 收窄为仅 `aliased and written[dest]`，符合 REQ-ALIAS-3 原意（别名冲突），保留历史 last-write-wins |
| `test_mod_e2e`/`test_mod_boot` 旧断言 | 原断言锁定 bug 行为（`smap -> fallback`） | 按项目约定「测试断言匹配真实（正确）行为」更新为 MOD 命中 |

## 7. 总体判定

**✓ PASSED** — 6 个 REQ 全部满足，DoD 1~6 全部通过，无未决偏差。
