# Tasks: allmods-lostbook-activate

## 1. 构建（REQ-LOST-1）

- [x] 1.1 构建 lostbook 数据包
  Blast Radius: `["game/mods/lostbook/**"]`
  DoD:
    - [x] `lua tools/mod_build.lua kys-lostbook` 退出码 0
    - [x] `data files=231, saves=3, sound=78, events=1071, talk=3181`
    - [x] `game/mods/lostbook/diff.md` 生成

- [x] 1.2 确认产物目录结构
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `script/oldevent/` 含 1071 个 `.lua`
    - [x] `script/oldtalk.grp`/`.idx` 存在
    - [x] `save/` 含 5 个文件（`d11`/`r11`/`s11` + `d1`/`s1`）
    - [x] `sound/` 含 78 个文件

- [x] 1.3 确认源无 `r1.grp`（首次存档播种）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 源 `save/` 无 `r1.grp`
    - [x] 产物 `save/` 亦无 `r1.grp`

## 2. 逐文件穷举审计（REQ-LOST-2）

- [x] 2.1 运行穷举审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `total=342 in_product=312 not_in_product=30 unclassified=0 bad_evidence=0`
    - [x] `Σ(类别) = 307+4+3+1+27 = 342`

- [x] 2.2 确认无「必需但未进产物」矛盾
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 矛盾数 = 0

- [x] 2.3 逐条核对 30 个未进产物文件
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 27 个 `music/*.mid`（`PENDING`）
    - [x] 4 个 `list/*.bin`（`PENDING`）
    - [x] 2 个 `list/{end,start}.txt`（`LEGACY`）
    - [x] 1 个 `script/1.lua`（`LEGACY`）

## 3. 字节级覆盖（REQ-LOST-3）

- [x] 3.1 运行字节级审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `formats=12 checked=201 gaps=0`

- [x] 3.2 确认内容差异非结构异常
  Blast Radius: `[]`（只读）
  DoD:
    - [x] hdgrp 115 == pascal 115
    - [x] eft 714 == pascal 714
    - [x] warfld 26 == pascal 26
    - [x] cloud 9 == pascal 9
    - [x] title 9 == pascal 9
    - [x] kdef **1071** vs pascal 1018（内容差异）
    - [x] fight **97** vs pascal 92（内容差异）

## 4. 产物四项检查

- [x] 4.1 `MOD_SLUG=lostbook lua tools/mod_check_one.lua`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `PERSON=320 THING=200 SCENE=84 WUGONG=93`
    - [x] `HERO=金迷`
    - [x] `STRINGS=OK EVENTS=OK SAVE=OK`

## 5. 真实启动链路（REQ-LOST-4）

- [x] 5.1 独立进程启动验证
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `lua tests/unit/boot_one_mod.lua lostbook 320 200 84 93 金迷`
    - [x] `RESULT lostbook: OK`
    - [x] 16 项断言全 PASS

## 6. 存档播种（REQ-LOST-5）

- [x] 6.1 验证首次存档播种路径
  Blast Radius: `[]`（只读，验证后恢复）
  DoD:
    - [x] 存档前 `r1.grp` 不存在
    - [x] `CC.R_GRPFilename[1]` = `mods/lostbook/save/r1.grp`
    - [x] `SaveRecord(1)` 后 `r1.grp`/`r1.idx`/`r1.ovr` 存在
    - [x] `LoadRecord(1)` 回读姓名正确
    - [x] 验证后产物恢复至原始状态（无残留）

## 7. 零回归（REQ-LOST-6）

- [x] 7.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 958/958
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `unclassified=0`
    - [x] `mod_audit --all --evidence` `failed=0`
    - [x] `format_spec --all` `gaps=0`

## 8. 验证

- [x] 8.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-lostbook-activate/verification.md"]`
  DoD:
    - [x] 含 REQ-LOST-1~6 追溯矩阵
    - [x] 含实测命令与输出
    - [x] 含 Blast Radius 合规检查
