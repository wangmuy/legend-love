---
status: done
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice-awaken — 真龙苏醒端到端

## Change Assignments

### Change: allmods-awaken-reverse — 逆向分析

- **Repository**: this repo
- **Scope**: infra（逆向 + 报告）
- **Responsibility**: 复现 真龙苏醒 的真实缺陷（6 个控制符（字段内 CRLF）），定位根因（同 BookCalamity：作者把换行粘进了定长字段），产出 `reports/reverse.md`。
- **Depends On**: —
- **Status**: [x] Done

### Change: allmods-awaken-fix — 确认修改

- **Repository**: this repo
- **Scope**: fullstack（`game/tools/mod_encoding.lua`（`M.TrimControl`））
- **Responsibility**: 复用 `M.TrimControl`：折叠字段内 CR/LF（awaken Thing r89 有**内部** CRLF）
- **Depends On**: allmods-awaken-reverse
- **Status**: [x] Done

### Change: allmods-awaken-test — 测试验证

- **Repository**: this repo
- **Scope**: infra（单元 + 端到端）
- **Responsibility**: 在 `game/tests/unit/test_mod_encoding.lua`（或 `test_mod_ini.lua`）新增断言覆盖该修复；断言其余 MOD 零回归。
- **Depends On**: allmods-awaken-fix
- **Status**: [x] Done

### Change: allmods-awaken-dod — DoD 核实

- **Repository**: this repo
- **Scope**: infra（验收）
- **Responsibility**: 运行并记录 `mod_check.lua`（20/20）、`--verify-pascal`（PASS）、`--all`（0 failures）、`MOD_SLUG=awaken mod_check_one.lua`、全量测试；产出 `reports/dod.md`。
- **Depends On**: allmods-awaken-test
- **Status**: [x] Done

### Change: allmods-awaken-format-dod — 逐 MOD 字段/格式 DoD

- **Repository**: this repo
- **Scope**: docs（DoD 留痕）
- **Responsibility**: 补齐本 MOD 的逐格式实测表 + 20-MOD 横向对照 + slice0c REQ-FMT 追溯。本 MOD 的 reverse/fix/test/dod 产生于 `format_spec.lua` 成形前，原无任何字段级 DoD 断言。
- **Depends On**: allmods-slice0c-format-spec
- **Status**: [x] Done（`lua tools/format_spec.lua --mod awaken -> gaps=0`）

## Shared Contract Stubs

### Contract AWAKEN1: 真龙苏醒 修复

```
E.TrimControl(raw) -> raw'
-- '七傷拳\r\n譜' -> '七傷拳譜'
```

**Contract AWAKEN 1 状态**: [x] Fulfilled

## Integration Test Plan

1. 零回归：无 `active_mod.txt` → 全量测试全绿。
2. 修复生效：`MOD_SLUG=awaken lua tools/mod_check_one.lua` → STRINGS=OK。
3. 全 MOD 自检：`lua tools/mod_check.lua` → 20/20。
4. pascal 基线：`--verify-pascal` PASS。
