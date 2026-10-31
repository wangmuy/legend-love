# Tasks: allmods-heavensword-activate

## 1. 构建（REQ-HS-1）

- [x] 1.1 构建 HeavenSword 数据包
  Blast Radius: `["game/mods/HeavenSword/**"]`
  DoD:
    - [x] `lua tools/mod_build.lua kys-HeavenSword` 退出码 0
    - [x] `data files=223, saves=4, sound=78, events=1066, talk=3315`
    - [x] `game/mods/HeavenSword/diff.md` 生成

- [x] 1.2 确认产物目录结构
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `script/oldevent/` 含 1066 个 `.lua`
    - [x] `script/oldtalk.grp`/`.idx` 存在
    - [x] `save/` 含 `d11.grp`/`r11.grp`/`s11.grp`/`r1.idx`
    - [x] `sound/` 含 78 个文件

## 2. 逐文件穷举审计（REQ-HS-2）

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

## 3. 字节级覆盖（REQ-HS-3）

- [x] 3.1 运行字节级审计
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `formats=12 checked=197 gaps=0`

## 4. `hdgrp` 差异验证（REQ-HS-4）

- [x] 4.1 确认 `hdgrp` 条目数与来源
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `hdgrp.idx` = 500 字节 = 125 条目（pascal 115）
    - [x] `CC.HeadPicFile[1]` = `mods/HeavenSword/data/hdgrp.idx`

- [x] 4.2 确认引擎无固定计数依赖
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `CC.HDGRPNum`/`HDPicNum`/`MAX_HEAD_NUM`/`HDGRP`/`HeadNum` 全部 `nil`
    - [x] `PicLoadFile` 用 `idxlen/4` 推导条目数（`lib_love.lua:437`）
    - [x] 判定为**内容差异**，非结构异常
    - [x] `gaps=0` 佐证

## 5. 产物四项检查

- [x] 5.1 `MOD_SLUG=HeavenSword lua tools/mod_check_one.lua`
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `PERSON=320 THING=200 SCENE=84 WUGONG=93`
    - [x] `HERO=楊千葉`
    - [x] `STRINGS=OK EVENTS=OK SAVE=OK`

## 6. 真实启动链路（REQ-HS-5）

- [x] 6.1 独立进程启动验证
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `lua tests/unit/boot_one_mod.lua HeavenSword 320 200 84 93 楊千葉`
    - [x] `RESULT HeavenSword: OK`
    - [x] 16 项断言全 PASS

## 7. 存档验证（REQ-HS-6）

- [x] 7.1 验证「有 `r1.idx` 无 `r1.grp`」半初始化槽位
  Blast Radius: `[]`（只读，验证后恢复）
  DoD:
    - [x] 源 `r1.idx` 与 `ranger.idx` md5 相同
    - [x] 存档前 `r1.grp` 不存在、`r1.idx` 存在
    - [x] 存档后 `r1.grp`/`r1.ovr` 存在（`r1.idx` 保留）
    - [x] `LoadRecord(1)` 回读姓名正确
    - [x] 验证后产物恢复至原始状态

## 8. 缺陷 D：`mod_check_one` 未备份 `d1.grp`/`s1.grp`

- [x] 8.1 定位并确认
  Blast Radius: `[]`（只读调查）
  DoD:
    - [x] 现象：全量重建后 `mod_check` 使 20 MOD 的 `d1.grp`/`s1.grp` 全部改变
    - [x] 根因：`SLOTS` 仅含 `r1.*`，但 `SaveRecord(1)` 还写 `d1.grp`/`s1.grp`
    - [x] 影响：销毁源自带的 `d1.grp`/`s1.grp`（pascal 差异 2892 字节）

- [x] 8.2 修复：扩展 `SLOTS`
  Blast Radius: `["game/tools/mod_check_one.lua"]`
  DoD:
    - [x] `SLOTS` 扩展为 `r1.grp/r1.idx/r1.ovr/d1.grp/d1.idx/s1.grp/s1.idx`
    - [x] 备份/恢复循环自动覆盖新槽

- [x] 8.3 验证修复
  Blast Radius: `[]`（只读）
  DoD:
    - [x] `mod_check` 20/20 通过
    - [x] pascal `d1.grp`/`s1.grp`/`r1.grp` md5 前后不变
    - [x] 20/20 MOD 的 `save/` 全部与源逐字节一致

- [x] 8.4 新增/强化回归测试
  Blast Radius: `["game/tests/unit/test_mod_resources.lua"]`
  DoD:
    - [x] `testCheckOneDoesNotDeleteProductSaves` 断言 `SLOTS` 含 `d1.grp`/`s1.grp`
    - [x] `testProductSaveSlotMatchesSource` 覆盖源 `save/` 全部文件（≥40）

## 9. 零回归（REQ-HS-7）

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
    - [x] 全量测试后全 MOD `save/` 与源一致

## 10. 验证

- [x] 10.1 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-heavensword-activate/verification.md"]`
  DoD:
    - [x] 含 REQ-HS-1~7 追溯矩阵
    - [x] 含缺陷 D 的修复前后对比
    - [x] 含 Blast Radius 合规检查
