# Tasks: allmods-stronger-activate

## 1. 构建（REQ-STR-1）

- [x] 1.1 构建 stronger 数据包
  Blast Radius: `["game/mods/stronger/**"]`
  DoD:
    - [x] `lua tools/mod_build.lua kys-stronger` 退出码 0
    - [x] `data files=221, saves=6, sound=78, events=1018, talk=3727`
    - [x] `game/mods/stronger/diff.md` 生成

- [x] 1.2 确认产物目录结构
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `data/` 含 222 个文件（221 计数 + `kysmod.ini`）
    - [x] `script/oldevent/` 含 1018 个 `.lua`
    - [x] `script/oldtalk.grp`/`.idx` 存在
    - [x] `save/` 含 6 个槽
    - [x] `sound/` 含 78 个文件

- [x] 1.3 确认产物 `save/r1.grp` 与源逐字节相同
  Blast Radius: `[]`（只读）
  DoD:
    - [x] md5 `13a6e79648dd8b0e5c85fa74cdfe0e16` == 源 md5

## 2. 逐文件穷举审计（REQ-STR-2）

- [x] 2.1 运行穷举审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `total=335 in_product=305 not_in_product=30 unclassified=0 bad_evidence=0`
    - [x] `Σ(类别) = 300+4+3+1+27 = 335`

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
    - [x] 全部有类别 + 证据

## 3. 字节级覆盖（REQ-STR-3）

- [x] 3.1 运行字节级审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `formats=12 checked=196 gaps=0`

- [x] 3.2 与 pascal 基线结构对比
  Blast Radius: `[]`（只读）
  DoD:
    - [x] hdgrp 115 == pascal 115
    - [x] eft 714 == pascal 714
    - [x] warfld 26 == pascal 26
    - [x] cloud 9 == pascal 9
    - [x] title 9 == pascal 9
    - [x] kdef 1018 == pascal 1018
    - [x] fight 92 == pascal 92

## 4. 产物四项检查

- [x] 4.1 `MOD_SLUG=stronger lua tools/mod_check_one.lua`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `PERSON=320 THING=200 SCENE=84 WUGONG=93`
    - [x] `HERO=韋大寶`
    - [x] `STRINGS=OK EVENTS=OK SAVE=OK`

## 5. 真实启动链路（REQ-STR-4）

- [x] 5.1 独立进程启动验证
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `lua tests/unit/boot_one_mod.lua stronger 320 200 84 93 韋大寶`
    - [x] `RESULT stronger: OK`
    - [x] 16 项断言全 PASS

## 6. MOD 独有内容（REQ-STR-5）

- [x] 6.1 用非基线值证明加载来自 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 主角姓名 = 韋大寶（pascal = 小蝦米）
    - [x] `JY.Person[1]` = 胡斐
    - [x] `JY.Person[2]` = 程靈素
    - [x] 对话条目数 = 3727（与 pascal 2977 不同）

- [x] 6.2 核对资源路径
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `CC.MMAPPicFile[1]` = `mods/stronger/data/mmap.idx`
    - [x] `CC.TalkGrpFile` = `mods/stronger/script/oldtalk.grp`
    - [x] `CC.WarFile` = `mods/stronger/data/war.sta`
    - [x] `CC.ThingPicFile[1]` = `data/thing.idx`（回退原版）

## 7. 零回归（REQ-STR-6）

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
  Blast Radius: `["openspec/changes/allmods-stronger-activate/verification.md"]`
  DoD:
    - [x] 含 REQ-STR-1~6 追溯矩阵
    - [x] 含实测命令与输出
    - [x] 含 Blast Radius 合规检查
