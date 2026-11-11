# Tasks — allmods-mingdong-verify

## Blast Radius

允许修改/新增的文件路径：

- `openspec/changes/allmods-mingdong-verify/reports/mingdong-verify.md`（新增验证报告）
- `openspec/changes/allmods-mingdong-verify/**`

**不允许**修改任何 `game/**` 源码或数据（本 change 为只读验证）。

## 任务

### T1 差异审计（REQ-MDV-1）

- [x] T1.1 审计 `game/mods/mingdong/diff.md` 的基准独有 16 项 → 全部走回退/无影响，回退目标存在
- [x] T1.2 审计 MOD 独有 385 项 → 分类（fight 新增、hdgrp、运行时资源、构建输入、无引用）
- [x] T1.3 hdgrp 条目数 115 = 基准 115（无硬编码）
- [x] T1.4 fight 数量 267（编号不连续）→ 需动态枚举
- [x] T1.5 ini 差异表（960x660、MyThingNum=330、MaxHP=9999）

### T2 提取产物核验（REQ-MDV-2）

- [x] T2.1 事件数 1654 = kdef 条目数 1654
- [x] T2.2 对话数 5183 = talk 条目数 5183
- [x] T2.3 抽样 3 条对话与**独立**二进制解码比对一致
- [x] T2.4 事件 1000 引用的 talk 2978 内容与 MOD 数据吻合

### T3 报告与零回归（REQ-MDV-3）

- [x] T3.1 落盘 `reports/mingdong-verify.md`（覆盖全部差异条目）
- [x] T3.2 原版零回归：`lua tests/test_runner.lua` 全绿
- [x] T3.3 `--verify-pascal` PASS

## DoD 验证记录

| DoD | 要求 | 结果 |
|-----|------|------|
| 1 | 报告存在且覆盖全部差异条目 | ✅ `reports/mingdong-verify.md` §1 |
| 2 | 事件数=1654、对话数=5183，抽样 3 条一致 | ✅ §2 |
| 3 | 原版零回归 | ✅ 221/221；`--verify-pascal` PASS |
