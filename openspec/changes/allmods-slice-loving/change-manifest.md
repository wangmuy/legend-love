---
status: done
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice-loving — 问情篇端到端

## Change Assignments

### Change: allmods-loving-reverse — 逆向分析

- **Repository**: this repo
- **Scope**: infra（逆向 + 报告）
- **Responsibility**: 复现 问情篇 的真实缺陷（字段级零缺陷（0 FFFD / 0 控制符 / 0 空值）；`BEGIN_SCENE = -1` / `BEGIN_EVENT = -1`（作者声明「不指定」）），定位根因（字段数据本身完好；异常在 ini 的负值索引——引擎会直接用 `CC.NewGameSceneID` 索引 `JY.Sc），产出 `reports/reverse.md`。
- **Depends On**: —
- **Status**: [x] Done

### Change: allmods-loving-fix — 确认修改

- **Repository**: this repo
- **Scope**: fullstack（`game/framework/mod_ini.lua`）
- **Responsibility**: 在 `ModIni.Map` 增加 `NON_NEGATIVE_KEYS` 守卫：负值索引键（BEGIN_SCENE/BEGIN_EVENT 等）不覆盖引擎默认值
- **Depends On**: allmods-loving-reverse
- **Status**: [x] Done

### Change: allmods-loving-test — 测试验证

- **Repository**: this repo
- **Scope**: infra（单元 + 端到端）
- **Responsibility**: 在 `game/tests/unit/test_mod_encoding.lua`（或 `test_mod_ini.lua`）新增断言覆盖该修复；断言其余 MOD 零回归。
- **Depends On**: allmods-loving-fix
- **Status**: [x] Done

### Change: allmods-loving-dod — DoD 核实

- **Repository**: this repo
- **Scope**: infra（验收）
- **Responsibility**: 运行并记录 `mod_check.lua`（20/20）、`--verify-pascal`（PASS）、`--all`（0 failures）、`MOD_SLUG=loving mod_check_one.lua`、全量测试；产出 `reports/dod.md`。
- **Depends On**: allmods-loving-test
- **Status**: [x] Done

## Shared Contract Stubs

### Contract LOVING1: 问情篇 修复

```
ModIni.Map(sections, order) -> result
-- result.CC.NewGameSceneID == nil 当输入 BEGIN_SCENE < 0
-- result.CC.NewGameSceneID == N   当输入 BEGIN_SCENE = N >= 0
```

**Contract LOVING 1 状态**: [x] Fulfilled

## Integration Test Plan

1. 零回归：无 `active_mod.txt` → 全量测试全绿。
2. 修复生效：`MOD_SLUG=loving lua tools/mod_check_one.lua` → STRINGS=OK。
3. 全 MOD 自检：`lua tools/mod_check.lua` → 20/20。
4. pascal 基线：`--verify-pascal` PASS。
