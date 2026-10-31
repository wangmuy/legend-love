# Spec: allmods-file-inventory

> Change: `allmods-slice0c-file-inventory` · Slice: `allmods-slice0c`
> 需求前缀：`REQ-INV-*`（与 `proposal.md` 一一对应）

## 概述

对 20 个 MOD 的**全部源文件**（11220 个）产出唯一归类记录，并以"未归类 = 失败"
的机制保证无遗漏。

---

## [REQ-INV-1] 穷举遍历，无遗漏

系统必须遍历 `reference/allmods/kys-*/` 下的全部文件，不得依赖白名单目录列表。

#### Scenario: 遍历总数等于文件系统实际值
- **GIVEN** `reference/allmods/kys-*/` 目录树
- **WHEN** 调用 `mod_audit.auditAll()`
- **THEN** 返回记录数 == `find reference/allmods/kys-* -type f | wc -l` 的结果（11220）

#### Scenario: 嵌套子目录不被跳过
- **GIVEN** 某 MOD 含 `resource/subdir/nested.grp`（假设存在）
- **WHEN** 审计
- **THEN** 该文件出现在记录中（`path == "resource/subdir/nested.grp"`）

#### Scenario: 无扩展名文件被收录
- **GIVEN** `resource/sdx` 无扩展名
- **WHEN** 审计
- **THEN** 记录存在且 `ext == ""`

---

## [REQ-INV-2] 每条记录恰好一个类别，无兜底

`category` 必须 ∈ `CATEGORY` 枚举。无法归类时必须非 0 退出。

#### Scenario: 未归类文件导致失败
- **GIVEN** 判据表被临时移除某 `(topdir, ext)` 组合
- **WHEN** 运行 `lua tools/mod_audit.lua --all`
- **THEN** 退出码 ≠ 0，stderr 列出未覆盖的 `topdir/ext` 组合

#### Scenario: 枚举中不存在兜底类别
- **GIVEN** `CATEGORY` 枚举
- **WHEN** 检查
- **THEN** 不含 `OTHER`、`UNKNOWN`、`MISC`、`*_OTHER` 任何形式

---

## [REQ-INV-3] 类别枚举穷举且稳定

枚举必须恰好为以下 10 项。

#### Scenario: 枚举项数正确
- **GIVEN** `CATEGORY` 已定义
- **WHEN** 统计
- **THEN** 恰好 10 项：`REQUIRED`, `REQUIRED_CONVERTED`, `DESIGNED_FALLBACK`,
  `DEAD_PARAM`, `LEGACY`, `DEAD_FILE`, `EDITOR_DUMP`, `BUILD_INPUT`,
  `PLATFORM_ARTIFACT`, `PENDING`

#### Scenario: 所有记录的类别都在枚举内
- **GIVEN** `auditAll()` 返回 11220 条记录
- **WHEN** 检查每条 `category`
- **THEN** 全部 ∈ `CATEGORY`

---

## [REQ-INV-4] `needed=false` 必有证据

#### Scenario: 不需要的文件都有证据
- **GIVEN** `auditAll()` 返回的记录中所有 `needed == false` 的项
- **WHEN** 检查
- **THEN** 每项 `#evidence >= 1`

#### Scenario: 证据结构合法
- **GIVEN** 任意 `evidence` 元素
- **WHEN** 检查
- **THEN** 含 `kind` ∈ {`code`,`strings`,`offset_table`,`format`,`external`,`manual`}，
  且含 `ref` 或 `text` 之一

---

## [REQ-INV-5] `in_product` 可交叉验证

#### Scenario: 进产物的记录能在产物中找到
- **GIVEN** 记录 `{mod="mingdong", path="resource/sdx", in_product=true}`
- **WHEN** 在 `game/mods/mingdong/data/` 查找
- **THEN** 存在 `smap.idx`（别名目标）或 `sdx`（原名）

#### Scenario: 未进产物的记录不在产物中
- **GIVEN** 记录 `{mod="mingdong", path="head/hdgrp001.png", in_product=false}`
- **WHEN** 在 `game/mods/mingdong/` 查找
- **THEN** 不存在对应文件

---

## [REQ-INV-6] 人类可读报告

#### Scenario: 报告含分组与汇总
- **GIVEN** 审计完成
- **WHEN** 生成 `audit.md`
- **THEN** 含 10 个类别分组，每组含文件数、代表文件、证据摘要；
  含汇总表 `类别 | 文件数 | 占比 | 是否进产物`

#### Scenario: 报告数字与 JSON 一致
- **GIVEN** `audit.json` 与 `audit.md` 均已生成
- **WHEN** 比对汇总表与 JSON 统计
- **THEN** 每个类别的文件数完全一致

---

## [REQ-INV-7] 零回归

#### Scenario: 全量测试仍全绿
- **GIVEN** 本 change 已实施
- **WHEN** 运行 `cd game && lua tests/test_runner.lua`
- **THEN** 全部通过（449 + 本 change 新增）

#### Scenario: 构建与基线不受影响
- **GIVEN** 本 change 已实施
- **WHEN** 运行 `lua tools/mod_build.lua --all` 与 `--verify-pascal`
- **THEN** `0 build failures`，pascal baseline `PASS`
