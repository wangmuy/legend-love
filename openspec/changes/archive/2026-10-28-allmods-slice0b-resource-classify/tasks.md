# Tasks: allmods-slice0b-resource-classify

## 1. 分类断言测试
Traceability: [REQ-CLASSIFY-1], [REQ-CLASSIFY-2], [REQ-CLASSIFY-4]

- [x] 1.1 新建 `tests/unit/test_mod_resources.lua`（骨架 + 注册到 runner）
  Blast Radius: `["game/tests/unit/test_mod_resources.lua", "game/tests/test_runner.lua"]`
  DoD:
    - [x] 文件存在，使用与现有 `test_mod_*.lua` 相同的测试框架风格
    - [x] 在 `test_runner.lua` 注册（顺序在 `test_mod_data` 之后）

- [x] 1.2 断言 `thing.*` 设计性回退
  Blast Radius: `["game/tests/unit/test_mod_resources.lua"]`
  DoD:
    - [x] 扫描 20 MOD 源，断言 0 个提供 `thing.idx`/`thing.grp`
    - [x] 断言激活 MOD 后 `CC.ThingPicFile` 回退 `data/thing.*`

- [x] 1.3 断言 `allsinbk.grp` 死参数
  Blast Radius: `["game/tests/unit/test_mod_resources.lua"]`
  DoD:
    - [x] 扫描 20 MOD 源，断言 0 个提供 `allsinbk.grp`
    - [x] 断言 `LoadSMap` 函数体内 `tmpfilename` 0 引用（源码扫描）
    - [x] 断言 `game/` 中 `allsinbk`/`TempS_Filename` 仅出现在定义与实参位置

- [x] 1.4 断言死文件不可达
  Blast Radius: `["game/tests/unit/test_mod_resources.lua"]`
  DoD:
    - [x] 断言 `string.format("fight%03d.grp", n)` 不含 `..`/`_02`
    - [x] 断言 `game/` 源码无 `war1.sta` 引用
    - [x] 断言 `new.idx`/`fight23.idx` 不在引擎引用中

## 2. 编辑器副产物与遗留断言
Traceability: [REQ-CLASSIFY-3], [REQ-CLASSIFY-5]

- [x] 2.1 断言 `IGNORE_DIRS` 与产物无编辑器目录
  Blast Radius: `["game/tests/unit/test_mod_resources.lua"]`
  DoD:
    - [x] 断言 `IGNORE_DIRS` 含 `head`/`item`/`eft`
    - [x] 断言已构建的 `game/mods/*/` 无 `head`/`item`/`eft` 目录

- [x] 2.2 断言 `name.grp` 遗留
  Blast Radius: `["game/tests/unit/test_mod_resources.lua"]`
  DoD:
    - [x] 断言恰好 4 个 MOD 提供 `name.grp`，且集合 = {BookCalamity, Dragon, pineapple, RiverLake}
    - [x] 断言 `game/` 源码无 `name.grp` 读取引用

## 3. 文档固化
Traceability: [REQ-CLASSIFY-1]~[REQ-CLASSIFY-5]

- [x] 3.1 更新 `resource-type-audit.md` 结论汇总表
  Blast Radius: `["openspec/changes/allmods-slice0/reports/resource-type-audit.md"]`
  DoD:
    - [x] 汇总表新增「最终处置」列
    - [x] 8 类资源全部有明确状态（已修复/设计性回退/死参数/遗留/死文件/编辑器副产物/待决策）
    - [x] 引用本 change 与 smap-rename/sound-fallback 的对应关系

- [x] 3.2 `DATA_FILES.md` 新增「资源分类」章节
  Blast Radius: `["DATA_FILES.md"]`
  DoD:
    - [x] 列出 7 个分类（REQUIRED/DESIGNED_FALLBACK/DEAD_PARAM/LEGACY/DEAD_FILE/EDITOR_DUMP/PENDING）
    - [x] 每类附判据（证据来源）
    - [x] 说明「缺文件 ≠ bug」「多余文件 ≠ 需移植」

- [x] 3.3 TODO.md 勘误 + music spike 条目
  Blast Radius: `["openspec/epics/2026-10-allmods-compat/TODO.md"]`
  DoD:
    - [x] `name.grp` 使用 MOD 列表勘误在位（BookCalamity/Dragon/pineapple/RiverLake，非 books）
    - [x] 新增 `music/*.mid` 待决策 spike 条目，含三重不匹配说明

## 4. 集成验证
Traceability: [REQ-CLASSIFY-6]

- [x] 4.1 全量测试与零回归
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] 无 `active_mod.txt` → `cd game && lua tests/test_runner.lua` 全绿
    - [x] `cd game && lua tools/mod_build.lua --verify-pascal` PASS
    - [x] `git diff game/engine-love2d/ game/framework/ game/script/ game/tools/mod_build.lua` 为空

## 5. 验证报告
Traceability: [REQ-CLASSIFY-1]~[REQ-CLASSIFY-6]

- [x] 5.1 产出 `verification.md`
  Blast Radius: `["openspec/changes/allmods-slice0b-resource-classify/verification.md"]`
  DoD:
    - [x] 含 REQ 追溯矩阵（6 个 REQ 全覆盖）
    - [x] 含 Blast Radius 合规检查
    - [x] 含测试结果
    - [x] 总体判定 ✓ PASSED
