# Tasks: allmods-slice0c-unneeded-evidence

## 1. 证据收集

- [x] 1.1 实现 `checkEvidenceQuality(ev)` → bool
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] `kind="code"` 必须有 `cmd`
    - [x] `text` 长度 ≥ 10（若有）
    - [x] `kind="manual"` 必须有 `cmd`
    - [x] 返回 `false` 时给出原因

- [x] 1.2 实现 `runEvidence(ev)`：执行 `cmd`，断言输出含 `expect`
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 用 `io.popen` 执行，超时保护
    - [x] 返回 `ok, output`
    - [x] `cmd` 含路径时用相对 `game/` 的路径

- [x] 1.3 为 `head/`、`item/`、`eft/`、`cc/` 收集 `code` 证据
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] `ref="game/tools/mod_build.lua:IGNORE_DIRS"`
    - [x] `cmd="grep -n IGNORE_DIRS game/tools/mod_build.lua"`
    - [x] `expect` 含目录名

- [x] 1.4 为 `music/*.mid` 收集 `external` 证据
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 证明魔数 `MThd` ≠ 引擎期望
    - [x] 说明槽位不匹配（66 vs 25）
    - [x] `category="PENDING"`、`needed=nil`

- [x] 1.5 为死文件收集 `format` 证据
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] `fightNNN..grp`/`fightNNN_02.grp`：`%03d` 不可生成
    - [x] `new.idx`/`fight23.idx`/`war1.sta`：命名规则证明

- [x] 1.6 为 `name.grp`、`allsinbk.grp`、`thing.*` 收集证据
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] `name.grp`：`kys.exe` strings 0 引用 + 引擎 grep 0 引用
    - [x] `allsinbk.grp`：`LoadSMap` 形参 0 引用
    - [x] `thing.*`：0/20 MOD 提供 + 引擎回退原版

- [x] 1.7 为 `PLATFORM_ARTIFACT`（dll/exe/bat/zip）收集证据
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 文件类型判定（魔数 `MZ`/`PK`）
    - [x] 说明为 C 引擎运行时

- [x] 1.8 为 `save/` 的 17 个未进产物文件收集证据
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 逐个说明为何不进产物（如非存档槽文件）

## 2. 权威文档

- [x] 2.1 实现 `MOD_RESOURCE_AUDIT.md` 生成器
  Blast Radius: `["game/tools/mod_audit.lua", "MOD_RESOURCE_AUDIT.md"]`
  DoD:
    - [x] 按类别分组，含汇总表
    - [x] 每行含 `<!-- rec:<mod>:<path> -->` 锚点
    - [x] 含证据列（kind + 摘要）

- [x] 2.2 生成 `MOD_RESOURCE_AUDIT.md` 并提交仓库
  Blast Radius: `["MOD_RESOURCE_AUDIT.md"]`
  DoD:
    - [x] 文件存在于仓库根目录
    - [x] 行数与类别数一致
    - [x] 含"如何复现"章节（命令清单）

- [x] 2.3 更新 `DATA_FILES.md` §8 交叉引用
  Blast Radius: `["DATA_FILES.md"]`
  DoD:
    - [x] 指向 `MOD_RESOURCE_AUDIT.md`
    - [x] 说明两者关系（§8 是摘要，MOD_RESOURCE_AUDIT.md 是穷举）

## 3. 测试

- [x] 3.1 证据质量断言（REQ-EVID-1/3）
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] 所有 `needed=false` 有 ≥1 条非空壳证据
    - [x] 3 个负例（过短文本 / 缺 cmd / 合法）

- [x] 3.2 证据可复现断言（REQ-EVID-2）
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] 执行 `IGNORE_DIRS` 证据的 `cmd`，输出含 `head`
    - [x] 执行 `format` 证据的 `cmd`，输出 ≠ 死文件名

- [x] 3.3 文档可追溯断言（REQ-EVID-4）
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] 文档中每个锚点可在 JSON 找到
    - [x] 汇总数字一致

- [x] 3.4 未进产物全部有理由（REQ-EVID-5）
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] `#(in_product=false) == 1971`
    - [x] 每条有 `category` 与非空 `evidence`

- [x] 3.5 `PENDING` 类断言（ADR-004）
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] `PENDING` 记录数 > 0
    - [x] 每条 `needed == nil` 且有 `evidence`

## 4. 进度同步

- [x] 4.1 更新 epic `TODO.md`（Slice 0c 条目）
  Blast Radius: `["openspec/epics/2026-10-allmods-compat/TODO.md"]`
  DoD:
    - [x] Slice 0c 3 个子 change 条目
    - [x] `music` spike 条目指向 `PENDING` 记录

- [x] 4.2 更新 epic `epic.md`（注册 Slice 0c）
  Blast Radius: `["openspec/epics/2026-10-allmods-compat/epic.md"]`
  DoD:
    - [x] 范围表 + DoD + 依赖图加入 Slice 0c

## 5. 验证

- [x] 5.1 跑 `lua tools/mod_audit.lua --all`，确认证据全部通过校验
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] 退出码 0
    - [x] 输出 `unclassified=0 evidence_ok=all`

- [x] 5.2 跑全量测试与构建基线
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] `test_runner.lua` 全绿；`--all` 0 failures；`--verify-pascal` PASS

- [x] 5.3 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-slice0c-unneeded-evidence/verification.md"]`
  DoD:
    - [x] 含 REQ 追溯矩阵（EVID-1~6）
    - [x] 含 1971 个未进产物文件的类别分布表
    - [x] 含 Blast Radius 合规检查
