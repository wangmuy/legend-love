---
status: done
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice-bookcalamity — 天书劫端到端

## Change Assignments

### Change: allmods-bookcalamity-reverse — 逆向分析

- **Repository**: this repo
- **Scope**: infra（逆向 + 报告）
- **Responsibility**: 复现 天书劫 的真实缺陷（3 个控制符（字段内 CRLF，来自编辑器换行）），定位根因（MOD 作者把换行粘进了定长字段，字段内出现 `0d 0a`（CRLF）），产出 `reports/reverse.md`。
- **Depends On**: —
- **Status**: [x] Done

### Change: allmods-bookcalamity-fix — 确认修改

- **Repository**: this repo
- **Scope**: fullstack（`game/tools/mod_encoding.lua`（`M.TrimControl`））
- **Responsibility**: 实现 `M.TrimControl`：剥离字段尾部 C0 控制字节并折叠字段内 CR/LF；在 `ConvertRanger` 解码前调用
- **Depends On**: allmods-bookcalamity-reverse
- **Status**: [x] Done

### Change: allmods-bookcalamity-test — 测试验证

- **Repository**: this repo
- **Scope**: infra（单元 + 端到端）
- **Responsibility**: 在 `game/tests/unit/test_mod_encoding.lua`（或 `test_mod_ini.lua`）新增断言覆盖该修复；断言其余 MOD 零回归。
- **Depends On**: allmods-bookcalamity-fix
- **Status**: [x] Done

### Change: allmods-bookcalamity-dod — DoD 核实

- **Repository**: this repo
- **Scope**: infra（验收）
- **Responsibility**: 运行并记录 `mod_check.lua`（20/20）、`--verify-pascal`（PASS）、`--all`（0 failures）、`MOD_SLUG=BookCalamity mod_check_one.lua`、全量测试；产出 `reports/dod.md`。
- **Depends On**: allmods-bookcalamity-test
- **Status**: [x] Done

### Change: allmods-bookcalamity-format-dod — 逐 MOD 字段/格式 DoD

- **Repository**: this repo
- **Scope**: docs（DoD 留痕）
- **Responsibility**: 补齐本 MOD 的逐格式实测表 + 20-MOD 横向对照 + slice0c REQ-FMT 追溯。本 MOD 的 reverse/fix/test/dod 产生于 `format_spec.lua` 成形前，原无任何字段级 DoD 断言。
- **Depends On**: allmods-slice0c-format-spec
- **Status**: [x] Done（`lua tools/format_spec.lua --mod bookcalamity -> gaps=0`）

## Shared Contract Stubs

### Contract BOOKCALAMITY1: 天书劫 修复

```
E.TrimControl(raw) -> raw'
-- 剥离尾部 C0 控制字节；折叠内部 CR/LF
-- 不改动普通文本（无控制符时原样返回）
```

**Contract BOOKCALAMITY 1 状态**: [x] Fulfilled

## Integration Test Plan

1. 零回归：无 `active_mod.txt` → 全量测试全绿。
2. 修复生效：`MOD_SLUG=BookCalamity lua tools/mod_check_one.lua` → STRINGS=OK。
3. 全 MOD 自检：`lua tools/mod_check.lua` → 20/20。
4. pascal 基线：`--verify-pascal` PASS。
