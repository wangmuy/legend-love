---
status: done
created: 2026-10-29
---
# Tasks: allmods-awaken-format-dod

Blast Radius: `[]`（仅新增 openspec 文档，不改任何代码）

- [x] 1.1 产出 `awaken` 逐格式实测表（[REQ-PFD-1]）
  DoD:
    - [x] `spec.md` 含逐格式表，行数 = 13 + 汇总行
    - [x] `checked=342` 与 `lua tools/format_spec.lua --mod awaken` 输出一致
- [x] 1.2 附可复现命令与原始输出（[REQ-PFD-2]）
  DoD:
    - [x] `verification.md` 含两条命令的**原始输出**（`--mod awaken` 与 `--all`）
    - [x] 逐字复跑一致
- [x] 1.3 与 slice0c [REQ-FMT-1]~[REQ-FMT-7] 建立追溯（[REQ-PFD-3]）
  DoD:
    - [x] 7 个 REQ 每个都有「本 MOD 的满足方式」一行
    - [x] 无空占位（每行都有具体数字或符号名）
- [x] 1.4 附 20 MOD 横向对照表（[REQ-PFD-4]）
  DoD:
    - [x] 表含全部 **20** 行（非仅本 MOD）
    - [x] 本 MOD 的排名有明确数字
    - [x] 至少 3 条横向观察（众数/差异来源）
- [x] 1.5 切片 manifest 追加引用
  DoD:
    - [x] `allmods-slice-awaken/change-manifest.md` 的 `## Change Assignments` 多一行
    - [x] 该行 `Status: [x] Done`
- [x] 1.6 全量门禁复跑
  DoD:
    - [x] `lua tests/test_runner.lua` 失败 **0**
    - [x] `lua tools/format_spec.lua --all` → `gaps=0`
    - [x] 四禁改 `git status --porcelain | grep -cE 'engine-love2d/|engine-mud/|reference/allmods/'` = **0**
