# Tasks: allmods-slice0c-file-inventory

## 1. 类别枚举与判据表

- [x] 1.1 定义 `CATEGORY` 枚举（10 类，无兜底）
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 恰好 10 项，无 `OTHER`/`UNKNOWN`/`MISC`
    - [x] 导出为 `M.CATEGORY`（供测试断言）

- [x] 1.2 建立 `EXACT` 精确文件名判据（`resource/sdx|smp|wdx|wmp` 等）
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 4 个无扩展名文件归类为 `REQUIRED_CONVERTED`
    - [x] 每项含 `evidence`，`ref` 指向 `mod_build.lua:ALIAS_MAP`

- [x] 1.3 建立 `BY_KIND`（`topdir × ext`）判据表
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 覆盖实测全部 ~30 个 `(topdir, ext)` 组合
    - [x] 每项含 `category/needed/content_type`
    - [x] `needed=false` 的项含 `evidence`

## 2. 遍历与归类

- [x] 2.1 实现 `walkMods()`：递归遍历 `reference/allmods/kys-*/`
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 不用白名单目录；用 `find` 或递归 `io.popen`
    - [x] 返回 `{mod, relpath, size}` 列表
    - [x] 实测总数 == 11220

- [x] 2.2 实现 `classify(rec)`：查 `EXACT` → `BY_KIND`，未命中返回 `nil`
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 未命中返回 `nil`（不返回兜底类别）
    - [x] 命中时返回 `category/needed/content_type/evidence`

- [x] 2.3 实现 `auditAll()`：遍历 + 归类，未归类则收集并返回错误
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 返回 `records, unclassified`
    - [x] `unclassified` 为 `{topdir, ext}` 去重列表

- [x] 2.4 实现 `in_product` 判定（含别名转换）
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] `resource/sdx` → 检查 `game/mods/<mod>/data/smap.idx`
    - [x] `save/rN.grp` → 检查 `game/mods/<mod>/save/rN.grp`
    - [x] `sound/*.wav` → 检查 `game/mods/<mod>/sound/*.wav`

## 3. 输出

- [x] 3.1 实现 JSON 序列化 → `game/mods/_audit/audit.json`
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 无外部依赖（自写最小 JSON writer）
    - [x] 含 `total`/`by_category`/`records`

- [x] 3.2 实现 Markdown 报告 → `game/mods/_audit/audit.md`
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 10 个类别分组 + 汇总表
    - [x] 汇总数字与 JSON 一致

- [x] 3.3 实现 CLI 入口（`--all`、`--mod <slug>`）
  Blast Radius: `["game/tools/mod_audit.lua"]`
  DoD:
    - [x] 未归类 → `os.exit(1)` 并打印组合
    - [x] 成功 → 打印 `total=11220 unclassified=0`

## 4. 测试

- [x] 4.1 `test_mod_audit.lua`：穷举完整性
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] 记录数 == 11220
    - [x] `Σ(by_category) == 11220`
    - [x] 所有 `category` ∈ `CATEGORY`

- [x] 4.2 负例：构造未覆盖组合 → `classify` 返回 `nil`
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] `classify({topdir="nonexistent", ext=".xyz"}) == nil`

- [x] 4.3 `needed=false` → `evidence` 非空
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] 遍历所有记录断言

- [x] 4.4 `in_product=true` → 产物中存在
  Blast Radius: `["game/tests/unit/test_mod_audit.lua"]`
  DoD:
    - [x] 抽样 + 全量断言

- [x] 4.5 注册进 `test_runner.lua`
  Blast Radius: `["game/tests/test_runner.lua"]`
  DoD:
    - [x] `require` + `runAll` + `runModule` 分支
    - [x] 更新"可用模块"字符串

## 5. 验证

- [x] 5.1 跑 `lua tools/mod_audit.lua --all`，确认 `unclassified=0`
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] 退出码 0
    - [x] 输出 `total=11220 unclassified=0`

- [x] 5.2 跑全量测试，确认无回归
  Blast Radius: `[]`（只读验证）
  DoD:
    - [x] `lua tests/test_runner.lua` 全绿

- [x] 5.3 写 `verification.md`
  Blast Radius: `["openspec/changes/allmods-slice0c-file-inventory/verification.md"]`
  DoD:
    - [x] 含 REQ 追溯矩阵（INV-1~7）
    - [x] 含 Blast Radius 合规检查
    - [x] 含实测数字与命令
