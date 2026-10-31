---
status: done
created: 2026-10-29
---
# Spec: allmods-mingdong-format-dod

## [REQ-PFD-1] `mingdong` 逐格式实测表

### Scenario: 全部格式族均产生记录
- **Given** 源侧 `reference/allmods/kys-mingdong/`
- **When** 执行 `lua tools/format_spec.lua --mod mingdong`
- **Then** `formats=13`（不含 save_slot 族，源侧无语存槽）
- **And** `checked=831`
- **And** `gaps=0`

### Scenario: 每个文件被验证且字节全覆盖
- **Given** 上一步的 831 条记录
- **When** 检查每条记录的 `verifyIntervals`
- **Then** 每条 `ok=true`
- **And** 无 `gaps` 无 `overlaps`

## [REQ-PFD-2] `gaps=0` 可复现

### Scenario: 命令与输出可复现
- **Given** 干净工作树
- **When** 执行下列命令
- **Then** 输出与下表逐字一致

```
$ cd game && lua tools/format_spec.lua --mod mingdong
formats=13 checked=831 gaps=0

$ cd game && lua tools/format_spec.lua --all
formats=14 checked=6838 gaps=0
```

## [REQ-PFD-3] 与 slice0c 追溯

| slice0c REQ | 本 MOD 的满足方式 |
|-------------|------------------|
| [REQ-FMT-1] 每个格式族有 spec | `mingdong` 使用 13 个族，全部在 `M.FORMATS` / `M.SIMPLE_FORMATS` / `verifyMultiFile` 注册 |
| [REQ-FMT-2] `Σ字段 == 文件大小` 且无重叠无缺口 | `verifyPair` / `verifySaveGrid` / `verifyGrid` / `verifyFixedRecords` 全部 `gaps=0` |
| [REQ-FMT-3] idx → grp 分段展开 | `fight 267` 条 + `hdgrp/eft/mmap/talk/kdef` 等各 1 条 |
| [REQ-FMT-4] 多段格式 | `mmap` 双段（seg0/seg1）验证通过 |
| [REQ-FMT-5] consumer 符号可解析 | `testConsumerSymbolsResolve` 全绿（含 `mingdong`） |
| [REQ-FMT-6] 批量验证 | `--mod mingdong` 定向 + `--all` 全量均 `gaps=0` |
| [REQ-FMT-7] 缺口必须被报告 | 负向对照 6/6 病态输入均被判失败（见 slice0c verification §9） |

## [REQ-PFD-4] 20 MOD 横向对照

**禁止只报自身数字**——下表是同一命令对全部 20 个 MOD 的实测（按 total 降序）：

| MOD | total | fight | sound | png | list | slots |
|-----|-------|-------|-------|-----|------|-------|
| mingdong | 831 | 267 | 201 | 338 | 4 | 0 |
| BookCalamity | 589 | 327 | 234 | 2 | 5 | 0 |
| Dragon | 537 | 209 | 80 | 222 | 5 | 0 |
| pascal | 483 | 92 | 78 | 288 | 4 | 0 |
| GodsDevils | 477 | 92 | 78 | 282 | 4 | 0 |
| RiverLake | 415 | 219 | 170 | 1 | 4 | 0 |
| awaken | 342 | 237 | 79 | 1 | 4 | 0 |
| pig3dos | 328 | 180 | 111 | 3 | 4 | 9 |
| ptt | 319 | 162 | 78 | 54 | 4 | 0 |
| pineapple | 300 | 154 | 109 | 3 | 4 | 9 |
| books | 295 | 178 | 84 | 2 | 4 | 6 |
| lyff | 244 | 138 | 78 | 3 | 4 | 0 |
| pig | 243 | 137 | 78 | 3 | 4 | 0 |
| dream | 227 | 123 | 77 | 2 | 4 | 0 |
| loving | 212 | 107 | 77 | 3 | 4 | 0 |
| lostbook | 203 | 97 | 78 | 3 | 4 | 0 |
| HeavenSword | 200 | 93 | 78 | 3 | 4 | 1 |
| SweeOan | 198 | 92 | 78 | 3 | 4 | 0 |
| stronger | 198 | 92 | 78 | 3 | 4 | 0 |
| zheng | 197 | 92 | 78 | 2 | 4 | 0 |

`total=831`，在 20 个 MOD 中排**第 1**（20 MOD 按 total 降序实测）。

关键观察：

- `list=4` 是 20 MOD 的**众数**（14/20），`BookCalamity`/`Dragon` 为 5（多一个 `match - 复制.bin`）
- `slots=0`：源侧不提供 save 槽（仅 books 6 / pig3dos 9 / pineapple 9 / HeavenSword 1）
- `png` 数差异极大（1 ~ 338），因为 `head/` 下的 UPedit 导出 PNG 数量随 MOD 作者习惯变化

## 非功能约束

| 约束 | 判据 |
|------|------|
| 零代码改动 | 本 change 只新增 openspec 文档 |
| 四禁改 | `engine-love2d/`、`engine-mud/`、`jyconst.lua`、`reference/allmods/` 改动数 = 0 |
