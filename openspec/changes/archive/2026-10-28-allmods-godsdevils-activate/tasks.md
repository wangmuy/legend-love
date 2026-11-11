# Tasks: allmods-godsdevils-activate

## 1. 构建（REQ-GD-1）

- [x] 1.1 构建 GodsDevils 数据包
  Blast Radius: `["game/mods/GodsDevils/**"]`
  DoD:
    - [x] `lua tools/mod_build.lua kys-GodsDevils` 退出码 0
    - [x] `data files=219, saves=9, sound=78, events=1123, talk=4640`
    - [x] `game/mods/GodsDevils/diff.md` 生成

- [x] 1.2 确认产物目录结构
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `script/oldevent/` 含 1123 个 `.lua`
    - [x] `script/oldtalk.grp`/`.idx` 存在
    - [x] `save/` 含 9 个文件
    - [x] `sound/` 含 78 个文件
    - [x] `data/` 含 220 个文件（219 + `kysmod.ini`）

- [x] 1.3 确认 `head/`/`item/` 不进产物
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `game/mods/GodsDevils/head` 不存在
    - [x] `game/mods/GodsDevils/item` 不存在

## 2. 逐文件穷举审计（REQ-GD-2）

- [x] 2.1 运行穷举审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `total=615 in_product=306 not_in_product=309 unclassified=0 bad_evidence=0`
    - [x] `Σ(类别) = 301+4+3+279+1+27 = 615`

- [x] 2.2 确认无「必需但未进产物」矛盾
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 矛盾数 = 0

- [x] 2.3 逐条核对 309 个未进产物文件
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 279 个 `head/`/`item/` PNG（`EDITOR_DUMP`）
    - [x] 27 个 `music/*.mid`（`PENDING`）
    - [x] 4 个 `list/*.bin`（`PENDING`）
    - [x] 2 个 `list/{end,start}.txt`（`LEGACY`）
    - [x] 1 个 `script/1.lua`（`LEGACY`）

## 3. 字节级覆盖（REQ-GD-3）

- [x] 3.1 运行字节级审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `formats=12 checked=475 gaps=0`

## 4. `hdgrp` 差异验证（REQ-GD-4）

- [x] 4.1 应用 Slice 5 判据（首次外推）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `hdgrp.idx` = 516 字节 = 129 条目（pascal 115）
    - [x] `CC.HeadPicFile[1]` = `mods/GodsDevils/data/hdgrp.idx`
    - [x] 索引驱动（`PicLoadFile` 用 `idxlen/4`）
    - [x] 无固定计数常量
    - [x] 判定为**内容差异**，非结构异常
    - [x] `gaps=0` 佐证

## 5. `EDITOR_DUMP` 确认（REQ-GD-5）

- [x] 5.1 确认 279 个 PNG 归类与证据
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `head/` 79 PNG + `item/` 200 PNG = 279
    - [x] 归类 `EDITOR_DUMP`，`needed=false`
    - [x] 证据 `EV_UPEDIT_DUMP` 引用 `mod_build.lua:IGNORE_DIRS`
    - [x] `IGNORE_DIRS = { head=true, item=true, eft=true }`
    - [x] `grep "head/\|item/"` 在 `script/`/`framework/` → 0 命中
    - [x] 产物中不存在这两个目录

## 6. 产物四项检查

- [x] 6.1 `MOD_SLUG=GodsDevils lua tools/mod_check_one.lua`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `PERSON=320 THING=200 SCENE=84 WUGONG=93`
    - [x] `HERO=蝦米`
    - [x] `STRINGS=OK EVENTS=OK SAVE=OK`

## 7. 真实启动链路（REQ-GD-6）

- [x] 7.1 独立进程启动验证
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `lua tests/unit/boot_one_mod.lua GodsDevils 320 200 84 93 蝦米`
    - [x] `RESULT GodsDevils: OK`
    - [x] 16 项断言全 PASS

## 8. 存档验证（REQ-GD-7）

- [x] 8.1 验证 6 个源自带存档完好
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 产物 `save/` 9 个文件全部与源逐字节一致
    - [x] `CC.D_Filename[1]`/`CC.R_GRPFilename[1]`/`CC.S_Filename[1]` 指向 MOD save
    - [x] 运行 `mod_check` 后仍一致
    - [x] 全量测试后仍一致（缺陷 D 修复持久性）

## 9. 零回归（REQ-GD-8）

- [x] 9.1 全部门禁
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `test_runner.lua` 1612/1612
    - [x] `--verify-pascal` `mismatches=0`
    - [x] `--all` `0 build failures`
    - [x] `mod_check` 20/20
    - [x] `mod_audit --all` `unclassified=0`
    - [x] `mod_audit --all --evidence` `failed=0`
    - [x] `format_spec --all` `gaps=0`
    - [x] 全量测试后全 MOD `save/` 与源一致（不一致 = 0）

## 10. 验证

- [x] 10.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-godsdevils-activate/verification.md"]`
  DoD:
    - [x] 含 REQ-GD-1~8 追溯矩阵
    - [x] 含 `hdgrp` 判据外推验证
    - [x] 含 Blast Radius 合规检查
