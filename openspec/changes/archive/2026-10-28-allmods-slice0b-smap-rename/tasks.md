# Tasks: allmods-slice0b-smap-rename

## 1. 别名映射实现
Traceability: [REQ-ALIAS-1], [REQ-ALIAS-2], [REQ-ALIAS-3]

- [x] 1.1 在 `tools/mod_build.lua` 新增 `ALIAS_MAP` 常量与 `applyAlias(rel)` 函数
  Blast Radius: `["game/tools/mod_build.lua"]`
  DoD:
    - [x] `ALIAS_MAP` 含 `sdx→smap.idx`、`smp→smap.grp`、`wdx→wmap.idx`、`wmp→wmap.grp`
    - [x] `ALIAS_MAP` 上方注释引用 `UPedit.ini` 的 `File2`/`File3`/`SMAPIDX`/`SMAPGRP` 作为权威来源
    - [x] `applyAlias` 对非映射名返回原值

- [x] 1.2 在 `flattenResources()` 中接入别名（仅 `kind=="data"`）
  Blast Radius: `["game/tools/mod_build.lua"]`
  DoD:
    - [x] `destRel` 计算后、`writeFile` 前应用 `applyAlias`
    - [x] 仅当 `f.kind == "data"` 时应用；`save`/`save-template` 分支不受影响
    - [x] 文件内容不被修改（只改目标名）

- [x] 1.3 冲突检测：映射后目标名已存在 → 报错退出
  Blast Radius: `["game/tools/mod_build.lua"]`
  DoD:
    - [x] 构建器维护本次构建的已写目标名集合
    - [x] 冲突时 `error`/返回错误，主流程以非 0 退出码结束
    - [x] stderr 含冲突的两个名字

## 2. diff 报告改名识别
Traceability: [REQ-ALIAS-4]

- [x] 2.1 `buildDiff()` 新增「资源别名转换」小节
  Blast Radius: `["game/tools/mod_build.lua"]`
  DoD:
    - [x] `diff.md` 含 `## 资源别名转换` 小节
    - [x] 小节列出 4 条映射（`sdx → smap.idx` 等）

- [x] 2.2 「基准独有」/「MOD 独有」列表过滤别名对
  Blast Radius: `["game/tools/mod_build.lua"]`
  DoD:
    - [x] `smap.idx`/`smap.grp`/`wmap.idx`/`wmap.grp` 不出现在「基准独有」
    - [x] `sdx`/`smp`/`wdx`/`wmp` 不出现在「MOD 独有」

## 3. 单元测试
Traceability: [REQ-ALIAS-1], [REQ-ALIAS-3], [REQ-ALIAS-4]

- [x] 3.1 新增/扩展 `tests/unit/test_mod_build.lua`：别名映射与冲突
  Blast Radius: `["game/tests/unit/test_mod_build.lua", "game/tests/test_runner.lua"]`
  DoD:
    - [x] 用临时目录伪造 MOD 树（`resource/sdx` 等），断言产物名为 `smap.idx` 等
    - [x] 断言冲突场景返回错误
    - [x] 断言 `sdx` 内容与 `smap.idx` 逐字节相同
    - [x] 测试在 `test_runner.lua` 中注册并通过

- [x] 3.2 新增 diff 断言
  Blast Radius: `["game/tests/unit/test_mod_build.lua"]`
  DoD:
    - [x] 断言 `diff.md` 含「资源别名转换」小节
    - [x] 断言 `smap.*`/`wmap.*` 不在「基准独有」

## 4. 全量重建与运行时证明
Traceability: [REQ-ALIAS-1], [REQ-ALIAS-5], [REQ-ALIAS-6]

- [x] 4.1 重建全部 20 MOD 产物
  Blast Radius: `["game/mods/**"]`
  DoD:
    - [x] `lua tools/mod_build.lua --all` → 0 build failures
    - [x] 全部 `game/mods/*/data/` 含 `smap.*`/`wmap.*`
    - [x] 全部产物 `sdx`/`smp`/`wdx`/`wmp` 计数为 0

- [x] 4.2 运行时证明（激活 mingdong）
  Blast Radius: `["game/tests/unit/test_mod_e2e.lua"]`
  DoD:
    - [x] 断言 `CC.SMAPPicFile[1]` 以 `mods/mingdong/data/smap.idx` 结尾
    - [x] 断言 `CC.WMAPPicFile[1]` 以 `mods/mingdong/data/wmap.idx` 结尾
    - [x] 断言 smap 条目数 = 4635、wmap 条目数 = 3850

- [x] 4.3 零回归与基线验证
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] 无 `active_mod.txt` → `cd game && lua tests/test_runner.lua` 全绿
    - [x] `cd game && lua tools/mod_build.lua --verify-pascal` PASS

## 5. 验证报告
Traceability: [REQ-ALIAS-1]~[REQ-ALIAS-6]

- [x] 5.1 产出 `verification.md`
  Blast Radius: `["openspec/changes/allmods-slice0b-smap-rename/verification.md"]`
  DoD:
    - [x] 含 REQ 追溯矩阵（6 个 REQ 全覆盖）
    - [x] 含 Blast Radius 合规检查（git diff 对比允许路径）
    - [x] 含测试结果（总数/通过/失败）
    - [x] 总体判定 ✓ PASSED
