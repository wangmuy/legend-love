---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice8 — 刘亦纷飞版（kys-lyff）端到端

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic

[2026-10-allmods-compat](../../epics/2026-10-allmods-compat/epic.md) — Slice 8（**第 3 梯队第 2 个**）

## Slice Type

Feature

## User Story

玩家激活 MOD「刘亦纷飞版」（kys-lyff）后，Love2D 引擎按回退链加载 lyff 的数据与脚本、
应用其 `kysmod.ini` 覆盖，完整跑通主菜单 → 读档 → smap 移动/进出场景 → 战斗 → 事件对话 →
存档/读档的游玩路径。

## 为什么是 lyff（排序依据）

第 3 梯队（hdgrp 170~210）第 2 个：

| 维度 | lyff | pascal 基线 | 差异 |
|------|----:|-----------:|------|
| **`hdgrp` 条目** | **178** | 115 | +63 头像 |
| **`Person` 记录数** | **326** | 320 | **+6 角色**（ranger.grp 段长 59332 vs 58240，均整除 182） |
| `eft.grp` | 714 项 | 714 项 | 同形 |
| `warfld.grp` | 26 项 | 26 项 | 同形 |
| `cloud.grp` | 9 项 | 9 项 | 同形 |
| `title.grp` | 9 项 | 9 项 | 同形 |
| `kdef.grp` | 1358 项 | 1018 项 | 内容更多（+340 事件） |
| **fight** | **138** | 92 | **+46 额外战斗** |
| `talk.grp` | 5655 项 | 2977 项 | 内容更多（+2678 对话） |

**独特之处**：
1. **`Person` 记录数 326（+6）**—— 首个 `PersonNum` ≠ 320 的 MOD。段长 59332 字节，
   `59332 / 182 = 326`（整除无余数）。`jymain.lua:1747` 用 `(idx[2]-idx[1])/CC.PersonSize`
   索引驱动推导，**无固定计数依赖**，零引擎改动。
2. **主角 `Person[0].姓名 = "AAA"`（纯 ASCII）**—— 首个主角姓名为纯 ASCII 的 MOD。
   本 slice 发现并修复了 `mod_encoding.lua` 的 **ASCII 字符串丢弃缺陷**（跨 5 个 MOD）：
   原 `hasHighByte` 守卫只转换含 Big5 高字节的字段，纯 ASCII 文本（如 `AAA`/`killer-G`/`PTT`）
   被误判为「数值槽」而丢弃。修复后 `Person[0]` 正确解析为 `AAA`。
3. **+46 额外战斗**（本 epic 目前第 2 多，仅次于 pig 的 45… 实际 pig 45、lyff 46）。
4. `hdgrp` 178 是判据外推的**第 4 个样本**。

## In Scope

1. **MOD 激活接线验证**：`ModData.SetActive("lyff")` 后，验证回退链、`ModIni` 覆盖在真实启动链路上生效。
2. **lyff 数据包构建**：`lua tools/mod_build.lua kys-lyff`。
3. **逐文件穷举审计**：`lua tools/mod_audit.lua --mod lyff` → `unclassified=0`，无「必需但未进产物」矛盾。
4. **字节级覆盖**：`lua tools/format_spec.lua --mod lyff` → `gaps=0`。
5. **真实启动链路端到端验证**（独立进程）：`boot_one_mod.lua lyff 326 200 84 93 AAA`。
6. **`hdgrp` 178 差异验证**（判据第 4 次应用）。
7. **`Person` 326 差异验证**（段长整除 182，索引驱动）。
8. **46 场额外战斗验证**：三重确认（diff.md + 产物 + 审计归类）。
9. **ASCII 字符串缺陷修复验证**（跨 5 MOD：lyff/HeavenSword/GodsDevils/ptt/dream）。
10. **存档验证**：产物存档文件与源逐字节一致。
11. **原版零回归**。

## Out of Scope

- 其余 5 个 MOD（Slice 9-13：ptt/RiverLake/Dragon/pineapple/books）
- `music/*.mid`（27 个 PENDING 项）—— 全局遗留 spike

## 验收标准（DoD，机器可验证）

| # | 判据 | 命令 | 期望 |
|---|------|------|------|
| 1 | 构建成功 | `lua tools/mod_build.lua kys-lyff` | 退出码 0，`events=1358` |
| 2 | 逐文件归类完整 | `lua tools/mod_audit.lua --mod lyff` | `total=425 unclassified=0 bad_evidence=0` |
| 3 | 无「必需未进产物」矛盾 | `mod_audit.auditAll("lyff")` | 矛盾数 = 0 |
| 4 | 字节级无缺口 | `lua tools/format_spec.lua --mod lyff` | `gaps=0` |
| 5 | 产物四项检查 | `MOD_SLUG=lyff lua tools/mod_check_one.lua` | `PERSON=326 STRINGS/EVENTS/SAVE=OK` |
| 6 | 真实启动链路 | `lua tests/unit/boot_one_mod.lua lyff 326 200 84 93 AAA` | `RESULT lyff: OK` |
| 7 | `hdgrp` 差异判定 | `hdgrp.idx` 178 条目，`gaps=0` | 内容差异 |
| 8 | `Person` 326 判定 | `ranger.grp` 段长 59332 = 326×182 | 内容差异（索引驱动） |
| 9 | 46 场额外战斗 | 产物 `fight*.grp` = 138 | 三重确认 |
| 10 | ASCII 字符串修复 | `Person[0].姓名 = "AAA"` | 正确解析 |
| 11 | 存档完好 | 产物存档与源逐字节一致 | 一致 |
| 12 | 无回归 | `lua tests/test_runner.lua` | 全绿 |

## 依赖

- **Slice 0 / 0b / 0c**（回退链、别名映射、穷举审计工具链）
- **Slice 2~7**（定型模板 + 工具缺陷修复 + `hdgrp` 判据）

## 子 change 分解

| 子 change | 职责 |
|-----------|------|
| `allmods-lyff-activate` | 构建 + 逐文件/字节级审计 + 真实启动链路 + `hdgrp`/`Person` 差异 + 额外战斗 + ASCII 缺陷修复验证 |
| `allmods-lyff-verify` | `diff.md` 逐条审计 + MOD 独有内容验证 + 报告 + 零回归 |
