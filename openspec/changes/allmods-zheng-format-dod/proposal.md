---
status: done
created: 2026-10-29
---
# Proposal: allmods-zheng-format-dod — `zheng` 逐 MOD 字段/格式 DoD

## Why

`zheng` 的 change 集（reverse / fix / test / dod）产生于 `format_spec.lua` 成形之前，
其中**没有任何「本 MOD 的每个字段/格式都被验证」的 DoD 断言**。
实测 grep 结果：提及 `format_spec|字段级|格式族|idx_grp|save_grid|bare_idx` 的文档数 = **0**。

功能是通的（下节实测），缺的是**可追溯的 DoD 留痕**：
「zheng 通过字段级验证」这件事没有记录在该 MOD 自己的 change 里，
只能从 `allmods-slice0c-format-spec` 的全局结论间接推断——不符合「每个 MOD 独立验收」的要求。

## 实测依据（本 proposal 的立论基础）

```
$ cd game && lua tools/format_spec.lua --mod zheng
formats=13 checked=197 gaps=0
```

逐格式分布（同一命令的 `verifyEverything({mod="zheng"})` 明细）：

| 格式 | 族 | 记录数 |
|------|-----|--------|
| fight | idx_grp_rle | **92** |
| sound | wav_pcm | **78** |
| png | png_image | 2 |
| list | bin_table | 4 |
| save 槽（rN/sN/dN） | save_slot | 0 |
| 其余 19 个单格式 | 见 spec | 各 1 |
| **合计** | | **197** |

`gaps=0` 意味着每个被验证文件的**每一个字节**都被字段区间覆盖，无缺口、无重叠。

## In Scope

- `openspec/changes/allmods-zheng-format-dod/**`（本 change）
- 追溯：`allmods-slice0c-format-spec` 的 [REQ-FMT-1]~[REQ-FMT-7]

## Out of Scope

- **不改任何 `game/**` 代码**（功能已通过，本 change 是文档/DoD 留痕）
- 不改 `reference/allmods/**`
- 不改本 MOD 既有 reverse/fix/test/dod 文档内容（只在其 manifest 追加一行引用）

## 跟踪 ID

| ID | 需求 |
|----|------|
| [REQ-PFD-1] | 本 MOD 的逐格式实测表（上表口径） |
| [REQ-PFD-2] | `gaps=0` 有可复现命令 + 原始输出 |
| [REQ-PFD-3] | 与 slice0c [REQ-FMT-1]~[REQ-FMT-7] 建立追溯 |
| [REQ-PFD-4] | 与 20 MOD 横向对照，禁止只报自身数字 |
