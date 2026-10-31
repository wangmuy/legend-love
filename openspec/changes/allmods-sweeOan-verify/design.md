---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice2
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Design: allmods-sweeOan-verify

## Context

`diff.md` 由 `mod_build.lua` 生成，只比对 `data/` 目录（Slice 0c 已确认这是盲区）。
因此本 change 必须**不依赖 `diff.md` 单独下结论**，而要用 Slice 0c 的穷举审计交叉验证。

## ADR-001: 「基准独有」项必须逐项定性，不得笼统归为「回退原版」

**Context**：`diff.md` 的「基准独有」列出 23 项（pascal 有而 SweeOan 无）。初看都可归为
「引擎回退原版」，但其中混杂了 3 种不同性质：

| 性质 | 例子 | 引擎行为 |
|------|------|---------|
| 回退原版 | `thing.grp`、`allsinbk.grp` | 从 `game/data/` 读取 |
| 用户存档槽 | `d1.grp`、`s1.grp` | 从 `mods/SweeOan/save/` 读取 |
| 死文件 | `alldef.idx`、`allsin.idx` | 引擎从不读 |

**Decision**：逐项用**文件系统事实**定性（检查产物 `data/` 与 `save/` 的实际位置），
并与 `mod_audit` 的分类交叉验证。

**Alternatives**：
1. 笼统写「均回退原版」—— 会掩盖「用户存档槽」与「死文件」的区别。
2. 只看 `diff.md` —— 无法区分上述 3 种。

**Consequences**：
- 需要额外的文件系统检查步骤。
- 换取「23 项无一未解释」的严格性。

## ADR-002: MOD 独有内容用「非基线值」证明

**Context**：资源路径指向 MOD 目录**不充分** —— 引擎可能在读取后回退。

**Decision**：用**内容证据**证明加载来自 MOD：
- 主角姓名 = 王小石（pascal = 小蝦米）
- `JY.Person[1]/[2]` = 衛悲回/伊小深（pascal 无此人物）
- 对话条目 = 2977（与 pascal 同数但内容不同）

即：**选择 pascal 与 SweeOan 取值不同的字段**作为判据。

**Alternatives**：
1. 只断言路径前缀 `mods/SweeOan/` —— 无法排除读取后回退。
2. 只断言记录数 —— 两者相同（320/200/84/93），无区分度。

**Consequences**：
- 需要知道 pascal 的对应值（用于对比）。
- 判据有区分度，能真正证明「来自 MOD」。

## ADR-003: 发现缺陷的修复边界

**Context**：本 slice 发现 `mod_check_one.lua` 会**删除** MOD 产物的 `r1.grp`。

**Decision**：修复该工具（备份 + 恢复），并新增**回归测试**（`test_mod_resources.lua`
的两个新测试）。修复位置在 `game/tools/`，属允许路径。

**Alternatives**：
1. 只修工具不加测试 —— 未来可能回归。
2. 让 `mod_check_one` 改用临时目录 —— 改动更大，且 `SaveDir()` 由 `ModData` 决定，
   不易注入。

**Consequences**：
- 工具行为：自检前后产物 `save/` 字节级不变。
- 回归测试：`testCheckOneDoesNotDeleteProductSaves` + `testProductSaveSlotMatchesSource`。

## Negative Constraints（负向约束）

1. **不得修改** `game/engine-love2d/**`、`game/engine-mud/**`。
2. **不得修改** `game/script/jyconst.lua` 常量定义。
3. **不得修改** `reference/allmods/**`。
4. **不得**在报告中使用「均回退原版」这类笼统表述（REQ-SWEEV-2）。
5. **不得**用「记录数相同」作为 MOD 内容已加载的证据（无区分度）。

## Review Checklist

- [ ] `diff.md` 的 14 项 MOD 独有全部有判定
- [ ] `diff.md` 的 23 项基准独有全部有判定（无「未解释」）
- [ ] MOD 独有内容用非基线值证明
- [ ] 零引擎改动
- [ ] 发现的缺陷已修复 + 有回归测试
- [ ] 报告含实测输出
