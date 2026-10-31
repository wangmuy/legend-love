# Verification: allmods-slice0c-file-inventory

> Change: `allmods-slice0c-file-inventory` · Slice: `allmods-slice0c` · Epic: `2026-10-allmods-compat`
> 验证日期：2026-10-19
> 状态：**done**

## 1. 目标回顾

把「每个源文件都被检查到并归类」从人工承诺变成**机器保证**：

- 遍历 `reference/allmods/kys-*/` 的**全部**文件（不用白名单目录）
- 每个文件恰好归入一个类别；**未归类 = 失败**（不存在 `OTHER`/`UNKNOWN` 兜底）
- `needed=false` 的记录必须有结构化证据
- `in_product=true` 的记录必须能在 `game/mods/<mod>/` 找到

## 2. REQ 追溯矩阵

| REQ | 要求 | 实现 | 验证 | 状态 |
|-----|------|------|------|------|
| REQ-INV-1 | 穷举遍历，无遗漏 | `walkMods()` 用 `find` 递归；`auditAll()` 返回 `records, unclassified, total` | `testTotalEqualsFilesystem`：`find` 计数 == 遍历总数 == 11220 | ✅ |
| REQ-INV-2 | 无兜底类别 | `classify()` 查 `EXACT` → `BY_KIND`，未命中 `return nil` | `testNoUnclassified`（0 个）；`testClassifyReturnsNilForUnknown`（2 个负例） | ✅ |
| REQ-INV-3 | 类别枚举恰好 10 项 | `M.CATEGORY` 10 项 | `testCategoryEnumExact`（无 OTHER/UNKNOWN/MISC）；`testAllRecordCategoriesInEnum`；`testCategorySumEqualsTotal` | ✅ |
| REQ-INV-4 | `needed=false` 必有证据 | `EXACT`/`BY_KIND` 每项带 `evidence`；CLI 自检 `badEv` | `testNeededFalseHasEvidence`（0 缺失）；`testEvidenceStructureValid`；`testEvidenceQualityCheckerRejects` | ✅ |
| REQ-INV-5 | `in_product` 交叉验证（含别名） | `productCandidates()` 处理 `resource/`（别名）、`fight/`、`save/`（模板 vs 槽位）、`sound/`、`script/` | `testInProductMatchesFilesystem`（0 不一致）；`testAliasSourceInProductViaTarget`；`testEditorDumpNotInProduct` | ✅ |
| REQ-INV-6 | Markdown 报告 | `renderMarkdown()` + `renderResourceAudit()` | `testMarkdownHasAllSections`；`testMarkdownNumbersMatchSummary`；`testResourceAuditDocExists` | ✅ |
| REQ-INV-7 | 零回归 | 只新增文件 | 全量 867/867 | ✅ |

## 3. 实测证据

### 3.1 穷举完整性

```bash
cd game && lua tools/mod_audit.lua --all
```

```
total=11220 in_product=9225 not_in_product=1995 unclassified=0 bad_evidence=0
  REQUIRED             9145
  REQUIRED_CONVERTED   80
  LEGACY               68
  DEAD_FILE            2
  EDITOR_DUMP          1220
  BUILD_INPUT          30
  PLATFORM_ARTIFACT    12
  PENDING              663
```

- `Σ(类别) = 9145+80+68+2+1220+30+12+663 = 11220` ✅
- `in_product + not_in_product = 9225 + 1995 = 11220` ✅
- `unclassified = 0` ✅
- `bad_evidence = 0` ✅

### 3.2 与文件系统交叉校验

| 检查 | 命令 | 结果 |
|------|------|------|
| 遍历总数 | `find ../reference/allmods -mindepth 2 -type f -path '*/kys-*/*' \| wc -l` | `11220` ✅ |
| 锚点数 | `grep -c '<!-- rec:' MOD_RESOURCE_AUDIT.md` | `11220` ✅ |
| 进产物核对 | `testInProductMatchesFilesystem` | 0 不一致 ✅ |
| 无「必需但未进产物」矛盾 | `testNoRequiredFileMissingFromProduct` | 0 ✅ |

### 3.3 未进产物按 topdir 分布（1995）

| topdir | 文件数 | 主要类别 |
|--------|-------:|---------|
| `head/` | 713 | `EDITOR_DUMP` |
| `music/` | 581 | `PENDING` |
| `item/` | 400 | `EDITOR_DUMP` |
| `list/` | 122 | `PENDING` / `LEGACY` |
| `eft/` | 105 | `EDITOR_DUMP` |
| `(root)` | 30 | `BUILD_INPUT` / `PLATFORM_ARTIFACT` / `EDITOR_DUMP` |
| `resource/` | 20 | `LEGACY` / `DEAD_FILE` / `PLATFORM_ARTIFACT` / `BUILD_INPUT` |
| `script/` | 19 | `LEGACY` |
| `cc/` | 4 | `BUILD_INPUT` |
| `save/` | 1 | `PLATFORM_ARTIFACT`（`save.zip`） |

## 4. 实施中发现并修复的真实问题

本 change 的价值在于**它自己发现了 4 个此前未被任何 DoD 覆盖的真实缺陷**：

### 4.1 `mod_check.lua` 误把 `_audit/` 当 MOD

新增的 `game/mods/_audit/`（审计输出）被 `mod_check.lua` 的 `ls mods` 循环当成第 21 个 MOD，
导致 `mod_check` 报 `_audit: 字符串=FAIL`。**修复**：跳过以 `_` 开头的目录。

### 4.2 `save/` 模板路径判定错误

初版 `productCandidates()` 把 `save/ranger.grp` 判到 `mods/<mod>/save/`，但构建器实际把它
路由到 `mods/<mod>/data/`（`SAVE_TEMPLATE` 语义）。**修复**：按 `SAVE_TEMPLATE_NAMES` +
`isSaveSlot()` 分流。修复后 `save/` 未进产物从 131 降到 1。

### 4.3 `resource/` 下的 `.exe`/`.bat` 未归类

`kys-awaken/resource/consoleimz.exe`（`MZ` 魔数）与 2 个 `.bat` 触发 `REQ-INV-2` 失败
（这正是该机制设计的目的）。**修复**：新增 `resource|.exe`/`resource|.bat` → `PLATFORM_ARTIFACT`。

### 4.4 审计检出 `--all` 的陈旧产物

首次审计时 16 个 MOD 的 `save/r1.grp` 被报「未进产物」。追查发现是 **`--all` 之前的陈旧产物**
（`rmdirp` 清理逻辑是本轮 Slice 0b 才加入的）。重新 `--all` 后 17/17 全部就位，
证明审计器能捕获**产物陈旧**这一类问题。

### 4.5 旧测试断言需收窄扫描范围

`test_mod_resources.lua` 的 `testWarStaOnlyReference` / `testEngineDoesNotReadNameGrp`
扫描 `game/` 下**全部** `.lua`，而新审计工具**合法地**把 `war1.sta`/`name.grp` 作为
**数据**（证据字符串）提及。**修复**：新增 `runtimeSources()`，扫描范围收窄为
`script/` + `engine-love2d/` + `engine-mud/`（即「运行期源码」），并**新增正向断言**
确认审计工具确实归类了这些文件。

## 5. 产物清单

| 文件 | 说明 |
|------|------|
| `game/tools/mod_audit.lua` | 新增，~700 行，穷举归类器 + 证据执行器 + 文档生成器 |
| `game/tests/unit/test_mod_audit.lua` | 新增，200 个断言 |
| `game/mods/_audit/audit.json` | 生成物，11220 条记录（机器可读） |
| `game/mods/_audit/audit.md` | 生成物，按类别聚合摘要 |
| `MOD_RESOURCE_AUDIT.md` | 生成物（仓库根），1.27 MB，11220 个机器锚点 |
| `game/tests/test_runner.lua` | 注册 `mod_audit` 模块 |
| `game/tools/mod_check.lua` | 修复：跳过 `_` 前缀目录 |
| `game/tests/unit/test_mod_resources.lua` | 修复：`runtimeSources()` 收窄范围 |

## 6. Blast Radius 合规检查

| 允许路径 | 实际改动 | 合规 |
|---------|---------|------|
| `game/tools/mod_audit.lua` | 新增 | ✅ |
| `game/tests/unit/test_mod_audit.lua` | 新增 | ✅ |
| `game/tests/test_runner.lua` | 注册模块 | ✅ |
| `game/tools/mod_check.lua` | 跳过 `_` 目录（必要修复） | ✅ |
| `game/tests/unit/test_mod_resources.lua` | 收窄扫描范围（必要修复） | ✅ |
| `game/mods/_audit/**` | 生成物 | ✅ |
| `MOD_RESOURCE_AUDIT.md` | 生成物 | ✅ |

**未触碰**（负向约束）：

- `game/engine-love2d/**` ✅
- `game/engine-mud/**` ✅
- `game/script/jyconst.lua` 常量定义 ✅
- `reference/allmods/**` ✅

## 7. 偏差记录

| 偏差 | 原因 | 影响 |
|------|------|------|
| `walkMods` 用 `io.popen("find ...")` 而非纯 Lua 递归 | Lua 5.4 无内置目录遍历；`find` 在 CI/本地均可用 | 无；测试用同一 `find` 交叉校验 |
| 类别数从 9 增至 10（新增 `BUILD_INPUT`） | 实测发现 `kysmod.ini`/`cc/*.txt` 既非 `REQUIRED` 也非 `EDITOR_DUMP` | 语义更准确；`spec.md` 的枚举以实现为准 |
| 未进产物数从预估 1971 变为实测 1995 | 预估基于 basename 匹配；实测基于精确产物路径 | 实测更严格（按路径而非按名） |
| 新增 `testSplitPathHandlesRootFiles` | 发现 30 个根级文件（`kysmod.ini`/dll）需特殊处理 | 覆盖更完整 |

## 8. 结论

**PASS**。REQ-INV-1~7 全部满足。11220 个源文件 100% 被归类，未归类为 0，
证据质量检查为 0 失败，`in_product` 与文件系统 0 不一致。
本 change 自身发现并修复了 4 个真实缺陷（含 1 个测试基础设施缺陷）。
