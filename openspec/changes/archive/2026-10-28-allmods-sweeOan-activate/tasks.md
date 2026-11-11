# Tasks: allmods-sweeOan-activate

## 1. 构建 SweeOan 数据包

- [x] 1.1 清理旧产物并重建
  Blast Radius: `["game/mods/SweeOan/**"]`
  DoD:
    - [x] `rm -rf game/mods/SweeOan`
    - [x] `cd game && lua tools/mod_build.lua kys-SweeOan` 退出码 0
    - [x] 输出含 `events=1018`

- [x] 1.2 核对产物目录结构
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `data/` = 220 个文件
    - [x] `script/oldevent/` = 1018 个 `.lua`
    - [x] `save/` = 6 个存档槽（`r1/r11/d1/d11/s1/s11.grp`）
    - [x] `sound/` = 78 个 `.wav`
    - [x] `diff.md` 存在

## 2. 逐文件穷举审计（REQ-SWEE-2）

- [x] 2.1 运行 `lua tools/mod_audit.lua --mod SweeOan`
  Blast Radius: `["game/mods/_audit/**"]`
  DoD:
    - [x] `total=334`
    - [x] `unclassified=0`
    - [x] `bad_evidence=0`

- [x] 2.2 断言无「必需类但未进产物」矛盾
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 对每个 `in_product=false` 记录，`IN_PRODUCT_BY_CATEGORY[category]` 不为 `true`
    - [x] 矛盾数 = 0

- [x] 2.3 核对类别分布
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `REQUIRED=298`
    - [x] `REQUIRED_CONVERTED=4`
    - [x] `LEGACY=4`
    - [x] `BUILD_INPUT=1`
    - [x] `PENDING=27`
    - [x] `Σ = 334`

- [x] 2.4 核对 32 个未进产物文件全部有类别 + 证据
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 逐条列出（27 `music/*.mid` + 4 `list/*` + 1 `script/1.lua`）
    - [x] `kysmod.ini` 为 `BUILD_INPUT`
    - [x] `resource/修改档说明.txt` 为 `LEGACY`

## 3. 字节级覆盖（REQ-SWEE-3）

- [x] 3.1 运行 `lua tools/format_spec.lua --mod SweeOan`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `formats=12`
    - [x] `gaps=0`

- [x] 3.2 与 pascal 基线做结构对比
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `hdgrp` = 115 项（同形）
    - [x] `eft` = 714 项（同形）
    - [x] `warfld` = 26 项（同形）
    - [x] `cloud`/`title` = 9 项（同形）
    - [x] `kdef` = 1018 项（同形）
    - [x] `talk` = 2977 项（同形，内容不同）

## 4. 产物四项检查

- [x] 4.1 运行 `MOD_SLUG=SweeOan lua tools/mod_check_one.lua`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `PERSON=320`
    - [x] `THING=200`
    - [x] `SCENE=84`
    - [x] `WUGONG=93`
    - [x] `HERO=王小石`
    - [x] `STRINGS=OK`
    - [x] `EVENTS=OK`
    - [x] `SAVE=OK`

## 5. 真实启动链路（REQ-SWEE-4）

- [x] 5.1 独立进程跑 `boot_one_mod.lua SweeOan 320 200 84 93 王小石`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `lib.init` 无报错
    - [x] `JYMainAdapter.init` 无报错
    - [x] 5 个 MOD 布局常量正确（182/190/52/136）
    - [x] 4 个记录数正确（320/200/84/93）
    - [x] 主角姓名 = 王小石
    - [x] U+FFFD = 0
    - [x] 控制符 = 0
    - [x] 10 帧无报错
    - [x] `RESULT SweeOan: OK`

## 6. MOD 独有内容验证（REQ-SWEE-5）

- [x] 6.1 核对资源路径指向 MOD
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `CC.MMAPPicFile[1]` = `mods/SweeOan/data/mmap.idx`
    - [x] `CC.SMAPPicFile[1]` = `mods/SweeOan/data/smap.idx`
    - [x] `CC.WMAPPicFile[1]` = `mods/SweeOan/data/wmap.idx`
    - [x] `CC.TalkGrpFile` = `mods/SweeOan/script/oldtalk.grp`
    - [x] `CC.WarFile` = `mods/SweeOan/data/war.sta`

- [x] 6.2 核对 MOD 独有内容（非静默回退）
  Blast Radius: `[]`（只读）
  DoD:
    - [x] 对话条目数 = 2977
    - [x] 事件脚本数 = 1018
    - [x] `JY.Person[1]` = 衛悲回（非 pascal）
    - [x] `JY.Person[2]` = 伊小深（非 pascal）

## 7. 零回归（REQ-SWEE-6）

- [x] 7.1 全量测试
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `lua tests/test_runner.lua` 全绿

- [x] 7.2 构建基线
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `--verify-pascal` → `mismatches=0`
    - [x] `--all` → `0 build failures`
    - [x] `mod_check` → `20/20`
    - [x] `mod_audit --all` → `unclassified=0`
    - [x] `format_spec --all` → `gaps=0`

## 8. 验证

- [x] 8.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-sweeOan-activate/verification.md"]`
  DoD:
    - [x] 含 REQ-SWEE-1~6 追溯矩阵
    - [x] 含实测输出（原样粘贴）
    - [x] 含 Blast Radius 合规检查
    - [x] 含偏差记录
