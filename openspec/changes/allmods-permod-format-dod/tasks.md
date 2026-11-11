---
status: done
created: 2026-10-29
---
# Tasks: allmods-permod-format-dod（总纲）

Blast Radius: `[]`（仅 openspec 文档）

## 组 1：5 个缺文档 MOD 补建（[REQ-PFD-0]）

- [x] 1.1 为 `awaken` / `bookcalamity` / `mingdong` / `pig3dos` / `zheng` 各建 `format-dod` 子 change
  DoD:
    - [x] 5 个目录均含 `proposal.md` + `spec.md` + `tasks.md` + `verification.md`
    - [x] 各自 `checked` 与 `lua tools/format_spec.lua --mod <m>` 一致
      （awaken 342 / BookCalamity 589 / mingdong 831 / pig3dos 328 / zheng 197）
- [x] 1.2 每个子 change 含 20-MOD 横向对照（[REQ-PFD-4]）
  DoD:
    - [x] 横行数 = 20（非仅本 MOD）
    - [x] 排名为实测值（awaken 7 / BookCalamity 2 / mingdong 1 / pig3dos 8 / zheng 20）

## 组 2：14 个既有 MOD 文档补「字段/格式支持复核」段（[REQ-PFD-0]）

- [x] 2.1 逐 MOD 追加 5 小节（逐格式表 / 数字勘误 / `list/*.bin` 缺口 / 20-MOD 横向 / 结论）
  DoD:
    - [x] 14 个 MOD 的 `verification.md` 均追加成功
      （dream books pineapple Dragon RiverLake GodsDevils lyff SweeOan stronger lostbook ptt HeavenSword pig loving）
    - [x] `grep -l "字段/格式支持复核" | wc -l` = **14**
- [x] 2.2 纠正陈旧 `formats=12` 记录（[REQ-PFD-5]、数字准确性）
  DoD:
    - [x] 每个 MOD 段内有「旧记录 vs 现值」勘误表
    - [x] 差值全部为 **+2**（`allsin`+`alldef` 补注册），无一例外
- [x] 2.3 `list/*.bin` 缺口逐 MOD 声明（[REQ-PFD-5]）
  DoD:
    - [x] 每个 MOD 段写明其 `list` 记录数 + **当前处置状态**（`effect`/`match` 已进产物并装载；`leave`/`levelup`/`*.txt` = `LEGACY`）+ 指向 `allmods-list-bin-support`
      （**勘误**：初稿写「引擎不读」，`allmods-list-bin-support` 落地后该描述已过期，已逐 MOD 改写为处置状态表）

## 组 3：覆盖核验

- [x] 3.1 19/19 覆盖扫描
  DoD:
    - [x] `for d in allmods-*-{verify,dod,format-dod}; grep -q "字段/格式支持复核\|slice0c 追溯" $d/verification.md` → **19**
- [x] 3.2 8 门禁复跑
  DoD:
    - [x] G1 `lua tests/test_runner.lua` → `1914 / 0 failed`
    - [x] G2 `--verify-pascal` → PASS
    - [x] G3 `--all` → `20 mods, 0 build failures`
    - [x] G4 `mod_check` → `20/20`
    - [x] G5 `mod_audit --all --evidence` → `unclassified=0 bad_evidence=0`
    - [x] G6 `format_spec --all` → `formats=14 checked=6838 gaps=0`
    - [x] G8 四禁改 = **0 处**，`jyconst CC.*=` = **0 处**

## 组 4：遗留（不计入本 change 完成条件）

- [x] 4.1 `allmods-list-bin-support` 实施（`list/*.bin` 进产物 + 惰性装载）
  当前状态：**已完成**（见 `openspec/changes/allmods-list-bin-support/verification.md`）。
  实测：`PENDING` 663 → **581**（只剩 `.mid` 578 + `.mp3` 2 + `.sf2` 1，`.bin` 残留 0）；
  `in_product` 9245 → **9285**（+40 = 20 MOD × effect+match）；
  `effect.bin`/`match.bin` 20/20 MOD 逐字节进 `data/`；
  运行时 `CC.Effect` pascal 64 / BookCalamity 200 项生效；
  全量测试 1914 → **1957**，8 门禁全绿。
