---
status: done
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice-pig3dos — 金庸水浒传dos版端到端

## Change Assignments

### Change: allmods-pig3dos-reverse — 逆向分析

- **Repository**: this repo
- **Scope**: infra（逆向 + 报告）
- **Responsibility**: 复现 金庸水浒传dos版 的真实缺陷（565 个控制符 + 42 个空值（外号槽位）），定位根因（pig3dos 的 Person 记录**没有外号字段**；`@18` 槽位是 int16 数值 stat 数组（`07），产出 `reports/reverse.md`。
- **Depends On**: —
- **Status**: [x] Done

### Change: allmods-pig3dos-fix — 确认修改

- **Repository**: this repo
- **Scope**: fullstack（`game/tools/mod_encoding.lua`（`ConvertRanger` 的字符串守卫））
- **Responsibility**: 把字符串字段判定从 `startsBig5Pair(raw)` 改为 `hasHighByte(raw)`：含任意高位字节即为字符串字段，纯数值字段（如 pig3dos 外号槽位）自动跳过
- **Depends On**: allmods-pig3dos-reverse
- **Status**: [x] Done

### Change: allmods-pig3dos-test — 测试验证

- **Repository**: this repo
- **Scope**: infra（单元 + 端到端）
- **Responsibility**: 在 `game/tests/unit/test_mod_encoding.lua`（或 `test_mod_ini.lua`）新增断言覆盖该修复；断言其余 MOD 零回归。
- **Depends On**: allmods-pig3dos-fix
- **Status**: [x] Done

### Change: allmods-pig3dos-dod — DoD 核实

- **Repository**: this repo
- **Scope**: infra（验收）
- **Responsibility**: 运行并记录 `mod_check.lua`（20/20）、`--verify-pascal`（PASS）、`--all`（0 failures）、`MOD_SLUG=pig3dos mod_check_one.lua`、全量测试；产出 `reports/dod.md`。
- **Depends On**: allmods-pig3dos-test
- **Status**: [x] Done

### Change: allmods-pig3dos-format-dod — 逐 MOD 字段/格式 DoD

- **Repository**: this repo
- **Scope**: docs（DoD 留痕）
- **Responsibility**: 补齐本 MOD 的逐格式实测表 + 20-MOD 横向对照 + slice0c REQ-FMT 追溯。本 MOD 的 reverse/fix/test/dod 产生于 `format_spec.lua` 成形前，原无任何字段级 DoD 断言。
- **Depends On**: allmods-slice0c-format-spec
- **Status**: [x] Done（`lua tools/format_spec.lua --mod pig3dos -> gaps=0`）

## Shared Contract Stubs

### Contract PIG3DOS1: 金庸水浒传dos版 修复

```
ConvertRanger 字符串判定:
-- raw ~= '' and hasHighByte(raw)  -> 转换
-- 否则跳过（report.skipped）
-- 副作用修复：混合 ASCII+Big5 字段（'53\xa1A219'、'2008年…'）也被转换
```

**Contract PIG3DOS 1 状态**: [x] Fulfilled

## Integration Test Plan

1. 零回归：无 `active_mod.txt` → 全量测试全绿。
2. 修复生效：`MOD_SLUG=pig3dos lua tools/mod_check_one.lua` → STRINGS=OK。
3. 全 MOD 自检：`lua tools/mod_check.lua` → 20/20。
4. pascal 基线：`--verify-pascal` PASS。
