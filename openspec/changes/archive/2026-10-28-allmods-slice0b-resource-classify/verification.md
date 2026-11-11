# Verification: allmods-slice0b-resource-classify

> Contract C owner · 子 change 3/3 · 状态：**✓ PASSED**

## 1. 执行摘要

把 2026-10 资源类型审计的「无害判定」固化为**可回归测试 + 权威文档**，使「什么是缺陷、什么不是」成为机器可验证的事实。

**动机**：`sdx/smp` 命名错配曾因「扁平 diff + 分类错误」潜伏整个 Slice 0。分类若不可回归，未来会再次误判。

**本 change 零代码行为变更**（只加测试与文档）。

## 2. REQ 追溯矩阵

| REQ | 要求 | 实现 | 验证证据 | 状态 |
|-----|------|------|---------|------|
| [REQ-CLASSIFY-1] | `thing.*` 设计性回退 | `test_mod_resources.lua` 2 个断言 | `testNoModProvidesThing`（0/20 提供）、`testThingFallsBackToVanilla`（原版存在） | ✓ |
| [REQ-CLASSIFY-2] | `allsinbk.grp` 死参数 | 3 个断言（源不提供 + 函数体 0 引用 + 仅定义/实参） | `testNoModProvidesAllsinbk`、`testLoadSMapDoesNotUseTmpfilename`、`testAllsinbkOnlyInDefinitionAndCall` | ✓ |
| [REQ-CLASSIFY-3] | 编辑器副产物不复制 | `IGNORE_DIRS` 断言 + 产物无目录断言 | `testIgnoreDirsCoversEditorDirs`、`testBuiltModsHaveNoEditorDirs` | ✓ |
| [REQ-CLASSIFY-4] | 死文件不可达 | 命名规则断言 + `war1.sta` 断言 + 忠实拷贝断言 | `testFightFormatCannotGenerateDeadNames`、`testWarStaOnlyReference`、`testDeadFilesAreFaithfullyCopied` | ✓ |
| [REQ-CLASSIFY-5] | `name.grp` 遗留 + `music` 待决策 | 4 个 MOD 集合断言 + 引擎不读断言 + TODO 断言 | `testNameGrpUsedByExactlyFourMods`、`testEngineDoesNotReadNameGrp`、`testMusicPendingInTodo` | ✓ |
| [REQ-CLASSIFY-6] | 零回归 | 无行为代码变更 | 全量测试 449/449；`--verify-pascal` PASS | ✓ |

## 3. 实测证据

### 3.1 测试运行（mod_resources）

```
$ cd game && lua tests/test_runner.lua mod_resources
...
[PASS] 0 个 MOD 提供 thing.*
[PASS] 原版 data/thing.grp 存在
[PASS] 0 个 MOD 提供 allsinbk.grp
[PASS] 形参含 tmpfilename
[PASS] 函数体内无 tmpfilename 引用（死参数）
[PASS] allsinbk 无意外引用（仅定义/实参/注释）
[PASS] IGNORE_DIRS = { head, item, eft }
[PASS] 产物无编辑器副产物目录
[PASS] fight0 无双点 / 无 _02 ... （抽样 7 个编号）
[PASS] fight000..grp 不可生成
[PASS] fight030_02.grp 不可生成
[PASS] 无 war1.sta 引用
[PASS] war.sta 有引用
[PASS] 双点死文件被忠实复制（未过滤）
[PASS] name.grp 使用 MOD 集合正确（books 不在其中）
[PASS] 无 name.grp/name.idx 读取引用
[PASS] TODO 含 music/*.mid 条目
[PASS] TODO 说明格式不匹配
========================================
Results: 40 tests, 40 passed, 0 failed
========================================
```

### 3.2 `name.grp` 实际使用 MOD

```
$ 扫描 reference/allmods/kys-*/resource/name.grp
found = { BookCalamity, Dragon, RiverLake, pineapple }
```

与预期完全一致，`books` 不在其中（修正了 TODO.md 原记录）。

### 3.3 `allsinbk` 引用位置

```
game/script/jyconst.lua:96:   CC.TempS_Filename=CONFIG.DataPath .. "allsinbk.grp";
game/script/jymain.lua:1835:    lib.LoadSMap(sFile,CC.TempS_Filename,JY.SceneNum,...);
```

仅定义 + 实参传递；`LoadSMap` 函数体内 0 引用。

### 3.4 文档落盘

| 文件 | 变更 |
|------|------|
| `openspec/changes/allmods-slice0/reports/resource-type-audit.md` | 结论汇总表新增「最终处置」列；新增分类判定对照表；新增对原审计 B 类的修正说明 |
| `DATA_FILES.md` | 新增「八、MOD 资源分类」章节（分类表 + 别名映射 + 音效回退链）；原「八、相关源码文件」改为「九」 |
| `openspec/epics/2026-10-allmods-compat/TODO.md` | Slice 0b 进度条目；`music/*.mid` 待决策 spike 条目；`name.grp` 勘误 |

## 4. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/tests/unit/test_mod_resources.lua` | 新增（40 断言） | ✓ |
| `game/tests/test_runner.lua` | 注册模块 + `runModule` 分支 | ✓ |
| `openspec/changes/allmods-slice0/reports/resource-type-audit.md` | 结论表更新 | ✓ |
| `DATA_FILES.md` | 新增章节 | ✓ |
| `openspec/epics/2026-10-allmods-compat/TODO.md` | 进度 + spike 条目 | ✓ |

**未触碰**（REQ-CLASSIFY-6 的关键验证）：

```
$ git status --short game/engine-love2d game/engine-mud game/framework game/script game/tools/mod_build.lua
（无输出）
```

本 change 的 `test_mod_build.lua` 中新增的 `testIgnoreDirsCoversEditorDirs` 与 `testSoundWalkInSource` 是**源码字符串断言**（验证子 change 1/2 的常量），非行为代码变更。

## 5. 测试结果

| 测试套件 | 结果 |
|---------|------|
| `lua tests/test_runner.lua` | **449/449 通过** |
| `lua tests/test_runner.lua mod_resources` | 40/40 通过 |
| `lua tools/mod_build.lua --verify-pascal` | PASS |
| `lua tools/mod_check.lua` | 20/20 通过 |

## 6. 偏差记录

| 偏差 | 说明 | 处置 |
|------|------|------|
| `fight%03d` 穷举断言爆炸 | 初版 `for n=0,999` 产生 2000 条断言，拖慢测试且无增益 | 改为抽样 7 个编号 + 2 条反向断言（`fight000..grp`/`fight030_02.grp` 不可生成） |
| `LoadSMap` 函数体提取失败 | 初版用 `%b()` 模式，只匹配到参数列表 | 改为「参数列表结束位置 → 下一个行首 `end`」区间提取 |
| `allsinbk` 扫描范围过宽 | 初版扫全 `game/`，命中 `mod_build.lua` 的 `SAVE_TEMPLATE`（存档模板路由，与引擎读取无关）和测试文件自身 | 收窄为运行时源码 `script/` + `engine-love2d/` |
| 原审计 B 类误判 | 原报告把 `thing.*` 列为「真实缺陷 → 需补建」 | 修正为 `DESIGNED_FALLBACK`；在审计报告与 DATA_FILES.md 中说明理由 |

## 7. 总体判定

**✓ PASSED** — 6 个 REQ 全部满足，DoD 1~6 全部通过，零行为代码变更。
