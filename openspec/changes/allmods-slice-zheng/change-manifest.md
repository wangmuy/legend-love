---
status: done
parent_epic: 2026-10-allmods-compat
---
# Change Manifest: allmods-slice-zheng — 魏征传奇端到端

## Change Assignments

### Change: allmods-zheng-reverse — 逆向分析

- **Repository**: this repo
- **Scope**: infra（逆向 + 报告）
- **Responsibility**: 用 `/tmp/deep_audit.lua` 式深度审计复现 zheng 的 Thing 196 U+FFFD / Scene 54 空 / Wugong 214 空；证明根因是 `save/ranger.idx` 描述的是 138596 字节的存档而非 114242 字节的 `ranger.grp`；用 `zheng[0..16] == pascal[0..16]` 与标准 idx 全量解码（零 U+FFFD）证明 zheng 布局本来就是标准的。产出 `reports/reverse.md`。
- **Depends On**: —
- **Status**: [x] Done

### Change: allmods-zheng-fix — 确认修改

- **Repository**: this repo
- **Scope**: fullstack（`tools/mod_encoding.lua` + `tools/mod_build.lua`）
- **Responsibility**: 实现数据驱动的 idx 修复：
  - `M.IdxIsConsistent(idx, grpSize)`：递增 + 段对齐 + 不越界；**容忍尾部 padding**
  - `M.DetectLayout(grp)`：对每段按「Big5 串位置 − 字段偏移」枚举候选起点，按 stride 测量最长连续记录；链式成单调布局；末段按自身 run 收尾；Shop 用剩余字节整数条补齐
  - `M.RepairIdx(grp, idx)`：一致则原样返回（reason=nil），否则返回探测布局
  - `mod_build.lua` 的 `convertRangerFile` 调用 `RepairIdx`；把修复后的 idx 写入产物 `data/ranger.idx`（在拷贝循环之后写，避免被源 idx 覆盖）
- **Depends On**: allmods-zheng-reverse
- **Status**: [x] Done

### Change: allmods-zheng-test — 测试验证

- **Repository**: this repo
- **Scope**: infra（单元 + 端到端）
- **Responsibility**: 新增 `game/tests/unit/test_mod_encoding.lua`（41 断言）覆盖 `TrimControl`/`IdxIsConsistent`/`DetectLayout`/`RepairIdx`/`ConvertRanger`；在 `test_runner.lua` 注册 `mod_encoding` 模块；断言 zheng 修复后零 U+FFFD、零控制符、大小不变；断言完好 MOD（pascal）零回归。
- **Depends On**: allmods-zheng-fix
- **Status**: [x] Done

### Change: allmods-zheng-dod — DoD 核实

- **Repository**: this repo
- **Scope**: infra（验收）
- **Responsibility**: 运行并记录：`lua tools/mod_check.lua`（20/20 通过）、`lua tools/mod_build.lua --verify-pascal`（PASS）、`lua tools/mod_build.lua --all`（20 mods, 0 failures）、`MOD_SLUG=zheng lua tools/mod_check_one.lua`（PERSON=320 THING=200 SCENE=84 WUGONG=93 STRINGS=OK EVENTS=OK SAVE=OK）、`lua tests/test_runner.lua`（全绿）。产出 `reports/dod.md`。
- **Depends On**: allmods-zheng-test
- **Status**: [x] Done

### Change: allmods-zheng-format-dod — 逐 MOD 字段/格式 DoD

- **Repository**: this repo
- **Scope**: docs（DoD 留痕）
- **Responsibility**: 补齐本 MOD 的逐格式实测表 + 20-MOD 横向对照 + slice0c REQ-FMT 追溯。本 MOD 的 reverse/fix/test/dod 产生于 `format_spec.lua` 成形前，原无任何字段级 DoD 断言。
- **Depends On**: allmods-slice0c-format-spec
- **Status**: [x] Done（`lua tools/format_spec.lua --mod zheng -> gaps=0`）

## Shared Contract Stubs

### Contract Z1: idx 修复接口

```
# allmods-zheng-fix 拥有；allmods-zheng-test / allmods-zheng-dod 消费
E.IdxIsConsistent(idx, grpSize) -> boolean
E.DetectLayout(grp)             -> newIdx, det, err, padding
E.RepairIdx(grp, idx)           -> newIdx, reason    -- reason=nil 表示未改动

# 不变量：
#   * idx[1] <= idx[2] <= ... <= idx[6] <= #grp
#   * 每段长度 % SEG_REC[i] == 0
#   * 结果与 MOD 名无关
```

**Contract Z 1 状态**: [x] Fulfilled

### Contract Z2: 构建产物 idx

```
# allmods-zheng-fix 拥有；引擎（jymain.lua LoadRecord）消费
game/mods/zheng/data/ranger.idx == 小端 uint32 [836,59076,97076,101444,114092,114242]
```

**Contract Z2 状态**: [x] Fulfilled

## Integration Test Plan

1. **零回归**：无 `active_mod.txt` → `lua tests/test_runner.lua` 全绿。
2. **idx 一致性**：zheng=false，pascal=true，pineapple=true。
3. **修复正确性**：zheng → `836,59076,97076,101444,114092,114242`。
4. **完好不触碰**：pascal → 原值 + reason=nil。
5. **转换洁净**：zheng 旁路表 0 FFFD / 0 CTRL / 0 EMPTY。
6. **构建产物**：`mods/zheng/data/ranger.idx` 小端值正确。
7. **引擎加载**：`MOD_SLUG=zheng lua tools/mod_check_one.lua` → 320/200/84/93 + STRINGS=OK。
8. **全 MOD 自检**：`lua tools/mod_check.lua` → 20/20。
9. **pascal 基线**：`--verify-pascal` PASS。
