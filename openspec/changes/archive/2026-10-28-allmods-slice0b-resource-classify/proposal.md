---
status: done
created: 2026-10-18
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
## Why

2026-10 的资源类型审计（[resource-type-audit.md](../allmods-slice0/reports/resource-type-audit.md)）枚举了 8 类「遗漏/自定义」资源。其中只有 2 类是真实缺陷（已由 `allmods-slice0b-smap-rename` 与 `allmods-slice0b-sound-fallback` 修复）；其余 6 类是**无害的**，但当前只以「审计报告的一段文字」形式存在——没有可回归的测试，也没有权威文档。

风险：未来开发者（或 AI）再次看到 MOD 产物里缺 `thing.grp`、或看到 `allsinbk.grp` 不在源 MOD 里，会**再次误判为 bug**，重蹈本次审计的覆辙（`sdx/smp` 命名错配就曾因「扁平 diff + 分类错误」潜伏了整个 Slice 0）。

本 change 把审计判定**固化为可回归断言 + 权威文档**，使「什么是缺陷、什么不是」成为机器可验证的事实。

## Parent Context

- Epic: `openspec/epics/2026-10-allmods-compat/epic.md`
- Slice: `openspec/changes/allmods-slice0b/slice-proposal.md`（Contract C 的拥有方）
- 依赖: `allmods-slice0b-smap-rename`、`allmods-slice0b-sound-fallback`（分类结论需引用两者的实现结果，确认哪些已修复、哪些保留为预期）

## What Changes

1. **更新审计报告**：`resource-type-audit.md` 的结论汇总表增加「最终处置」列，标注每类的状态（已修复 / 设计性回退 / 死文件 / 编辑器副产物 / 待决策）。
2. **新增可回归测试**（`tests/unit/test_mod_resources.lua`）：
   - `thing.*` 回退原版是设计性行为（断言无 MOD 提供 `thing.*`，且引擎回退路径正确）
   - `allsinbk.grp` 是死参数（断言 `game/` 中除常量定义外无读取调用）
   - `head/`/`item/`/`eft/` 不被复制（断言产物无这些目录）
   - 死文件被识别（断言 `fightNNN..grp`/`fightNNN_02.grp`/`new.idx`/`fight23.idx`/`war1.sta` 如存在则不可达）
   - `IGNORE_DIRS` 内容断言
3. **新增权威文档** `DATA_FILES.md` 补充「资源分类」章节（或新增 `RESOURCE_TYPES.md`）。
4. **epic TODO.md**：勘误 `name.grp` 使用 MOD 列表（已做）；新增 `music/*.mid` 待决策 spike 条目。

## Scope Boundaries

### In Scope

- 资源分类的文档固化与测试固化
- `music/*.mid` 记录为待决策（不实施转换）
- TODO.md 勘误与 spike 条目

### Out of Scope

- **修复 A（smap 改名）与 D（sound）** — 分属其他子 change
- **`music/*.mid` 转换实施** — 需先做 spike（见 TODO）
- **`thing.grp` 从 `item/*.png` 派生** — 源 MOD 不提供，回退是设计行为，不做反向构建
- 过滤产物中的死文件（**决定：保留忠实拷贝**，但在文档中标注；过滤会改变 Slice 0 的「忠实拷贝」契约，风险大于收益）

## Capabilities

### New Capabilities

- `allmods-resource-classification`: MOD 资源分类判定与回归（[REQ-CLASSIFY-1]~[REQ-CLASSIFY-5]）

## Contract Adherence

完全遵守 `change-manifest.md` 的 **Contract C**：

- 分类表 `REQUIRED`/`DESIGNED_FALLBACK`/`DEAD_PARAM`/`LEGACY`/`DEAD_FILE`/`EDITOR_DUMP`/`PENDING` 全部落到测试或文档。
- 死文件策略：**保留拷贝 + 文档标注**（与 Slice 0 的「忠实拷贝」一致）。
- 无代码行为变更（本 change 只加测试与文档）。

无偏离。

## Traceability

| REQ | 说明 |
|-----|------|
| [REQ-CLASSIFY-1] | `thing.*` 设计性回退：断言无 MOD 提供，引擎回退原版是预期 |
| [REQ-CLASSIFY-2] | `allsinbk.grp` 死参数：断言引擎不读取它 |
| [REQ-CLASSIFY-3] | `head/`/`item/`/`eft/`/`cc/` 编辑器副产物：断言不被复制 |
| [REQ-CLASSIFY-4] | 死文件（`fightNNN..`/`fightNNN_02`/`new.idx`/`fight23.idx`/`war1.sta`）：断言不可达 |
| [REQ-CLASSIFY-5] | `name.grp` 遗留 + `music/*.mid` 待决策：文档固化 + TODO 条目 |
| [REQ-CLASSIFY-6] | 零回归：新增测试全绿，无代码行为变更 |

## DoD

1. `game/tests/unit/test_mod_resources.lua` 存在并在 `test_runner.lua` 注册，全部断言通过。
2. `resource-type-audit.md` 结论汇总表含「最终处置」列，8 类资源全部有明确状态。
3. `DATA_FILES.md`（或 `RESOURCE_TYPES.md`）含「资源分类」章节，列出 7 个分类及判据。
4. `openspec/epics/2026-10-allmods-compat/TODO.md` 含 `music/*.mid` 待决策 spike 条目；`name.grp` 勘误在位。
5. 无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿（零回归）。
6. `git diff` 显示本 change 未修改任何 `game/engine-love2d/**`、`game/framework/**`、`game/script/**` 的**行为**代码（只新增测试与文档）。

## Impact

- **代码**：`game/tests/unit/test_mod_resources.lua`（新增）、`game/tests/test_runner.lua`（注册）
- **文档**：`openspec/changes/allmods-slice0/reports/resource-type-audit.md`（更新）、`DATA_FILES.md`（新增章节）、`openspec/epics/2026-10-allmods-compat/TODO.md`（勘误 + spike 条目）
- **依赖**：无新增
- **风险**：极低。纯测试 + 文档，无运行时代码变更。
