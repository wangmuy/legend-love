---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice-zheng — 魏征传奇（kys-zheng）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — 问题 MOD 专修（games.ini index 9「魏征传奇（好像不太正常）」）

## Slice Type

Bug fix（数据逆向 + 流水线修复）

## User Story

玩家激活 MOD「魏征传奇」（kys-zheng）后，引擎能正确加载其 `ranger.grp` 的全部人物/物品/场景/武功定义（320/200/84/93 条），所有中文字段正确渲染为 UTF-8，不出现 `�`（U+FFFD）或控制符，并可完整跑通启动 → 读档 → 场景 → 存档路径。

## 问题陈述（逆向分析起点）

`games.ini` 标注 zheng 为「好像不太正常」。深度审计（`/tmp/deep_audit.lua`）确认真实缺陷：

| 段 | 缺陷 |
|---|---|
| Thing | 196 个 U+FFFD + 47 个控制符 |
| Scene | 54 个空值 + 24 个控制符 |
| Wugong | 214 个空值 |

**根因（已定位）**：zheng 出厂的 `save/ranger.idx` **描述的不是它自己的 `ranger.grp`**。

```
zheng ranger.idx  末值 = 138596
zheng ranger.grp  大小 = 114242
```

zheng 的 `save/` 目录里同时存在 `r1.grp`/`r6.grp`/`r11.grp`（均 138596 字节）——出厂 idx 取自这些**存档**，而不是 114242 字节的 `ranger.grp`。

**决定性证据**：zheng 的 `ranger.grp` 前 16 字节与 kys-pascal **逐字节相同**，且两者同为 114242 字节：

```
zheng [0..16]: 000000006501eb002d001d0001006d00
pascal[0..16]: 000000006501eb002d001d0001006d00
```

用正确的 idx `836,59076,97076,101444,114092,114242` 解码 zheng：

- Person 320 条、Thing 200 条、Scene 84 条、Wugong 93 条、Shop 3 条
- **全部零 U+FFFD、零空值**
- `Person[0].姓名=小蝦米`、`Person[0].外号=天下奇男子`、`Thing[0].物品名=康倍特`、`Scene[0].名称=胡斐居`、`Wugong[0].名称=普通攻擊`

**结论：zheng 从未结构损坏，只是 idx 损坏。** 之前「复合布局」理论是 idx 损坏造成的红鲱鱼。

## In Scope

1. **逆向分析**：确认 zheng 的缺陷来自 idx 而非布局；建立「从字节推断分段边界」的数据驱动算法（不硬编码 MOD 名）。
2. **确认修改**：在 `game/tools/mod_encoding.lua` 实现 `M.IdxIsConsistent` / `M.DetectLayout` / `M.RepairIdx`；在 `game/tools/mod_build.lua` 构建期调用并把修复后的 idx 写入产物 `data/ranger.idx`。
3. **测试验证**：`game/tests/unit/test_mod_encoding.lua` 断言 zheng 的 idx 被识别为不一致、修复结果等于标准布局、转换后无 U+FFFD / 无控制符。
4. **DoD 核实**：`lua tools/mod_check.lua` 全 20 MOD 通过；`lua tools/mod_build.lua --verify-pascal` PASS；全量测试全绿。

## Out of Scope

- 其余 4 个问题 MOD（各自独立 slice）
- 修改 zheng 的源数据（只修构建期 idx，源 `reference/allmods/` 只读）
- 引擎运行时的 idx 修复（改为构建期产出正确 idx，运行时零成本）
- 原版 `base` 分支

## Acceptance Criteria

#### Scenario: 检测 zheng 出厂 idx 不一致
- **GIVEN** `reference/allmods/kys-zheng/save/ranger.idx` 末值为 138596
- **AND** `reference/allmods/kys-zheng/save/ranger.grp` 大小为 114242
- **WHEN** 调用 `E.IdxIsConsistent(idx, 114242)`
- **THEN** 返回 `false`

#### Scenario: 从字节还原 zheng 的正确布局
- **GIVEN** zheng 的 `ranger.grp`
- **WHEN** 调用 `E.RepairIdx(grp, shippedIdx)`
- **THEN** 返回 `836,59076,97076,101444,114092,114242`
- **AND** 返回非 nil 的修复原因字符串
- **AND** `E.IdxIsConsistent(修复结果, 114242)` 为 `true`

#### Scenario: zheng 全部字符串字段正确转换为 UTF-8
- **GIVEN** 修复后的 idx
- **WHEN** `E.ConvertRanger(grp, fixedIdx)`
- **THEN** 输出文件大小与输入完全相同（114242）
- **AND** 旁路表 `ranger.str` 中 0 个 U+FFFD、0 个控制符、0 个空值

#### Scenario: 构建产物带正确 idx
- **GIVEN** `lua tools/mod_build.lua kys-zheng`
- **WHEN** 读取 `game/mods/zheng/data/ranger.idx`
- **THEN** 其 6 个小端 uint32 为 `836,59076,97076,101444,114092,114242`

#### Scenario: 引擎按正确分段加载 zheng
- **GIVEN** 激活 zheng（`ModData.SetActive("zheng")`）
- **WHEN** 走 `lib.init` → `JYMainAdapter.init` → `LoadRecord(0)`
- **THEN** `JY.PersonNum=320`、`JY.ThingNum=200`、`JY.SceneNum=84`、`JY.WugongNum=93`
- **AND** `JY.Person[0]["姓名"]="小蝦米"`
- **AND** 字符串自检 `STRINGS=OK`（无非法 UTF-8、无 hint 泄漏）

#### Scenario: 完好 MOD 零回归
- **GIVEN** kys-pascal 的出厂 idx
- **WHEN** `E.RepairIdx(pascalGrp, pascalIdx)`
- **THEN** 返回的 idx 与出厂 idx 逐值相同
- **AND** 修复原因为 `nil`（未被触碰）

## Negative Constraints

- **不得按 MOD 名分支**：`RepairIdx`/`DetectLayout` 只依据字节与 UPedit 记录大小判定。
- **不得改变源数据**：`reference/allmods/` 只读。
- **不得弱化一致性判据**：`IdxIsConsistent` 只允许「尾部 padding」这一项放宽（pineapple 需要），其余（递增、段对齐、不越界）必须保留。
- **不得在运行时修复 idx**：修复必须发生在构建期。

## Review Checklist

- [ ] `IdxIsConsistent` 对 zheng 返回 false，对 pascal/pineapple 返回 true
- [ ] `DetectLayout` 对 zheng 精确得到标准布局
- [ ] `RepairIdx` 对完好 idx 返回原值且 reason=nil
- [ ] zheng 构建产物 idx 正确、大小不变
- [ ] `mod_check.lua` 全 20 MOD 通过
- [ ] `--verify-pascal` PASS
- [ ] 全量测试全绿（含新增 `test_mod_encoding`）
