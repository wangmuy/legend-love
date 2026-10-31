---
status: done
parent_epic: 2026-10-allmods-compat
parent_slice: allmods-slice0c
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Proposal: allmods-slice0c-file-inventory

## Why

DoD 是**抽样驱动**：判定范围由人写的比对目标决定，而非源文件全集。
实测 20 MOD 共 11220 个源文件，其中 1971 个（18%）**没有任何 DoD 断言覆盖**，
且 `diff.md` 只比对 `data/` 目录 → `head/`、`item/`、`eft/`、`music/`、`cc/`、
`list/`、dll 天生在盲区。这正是 `sdx/smp` 漏判（Slice 0b 才修复）的同型根因。

## What Changes

新增 `game/tools/mod_audit.lua`，对 20 MOD 的**每一个源文件**产出唯一归类记录：

```
Record = {
  mod, path, size, topdir, ext,
  needed,        -- 引擎是否需要
  category,      -- 类别枚举（无兜底）
  content_type,  -- 内容类型
  in_product,    -- 是否进产物
  evidence,      -- 非空证据
}
```

输出 `audit.json`（机器可读）+ `audit.md`（人类可读），并强制：
`Σ(各类别文件数) == 11220` 且 **未归类 == 0**（"未归类"是显式失败类别）。

## In Scope

- `tools/mod_audit.lua`：遍历 + 归类 + 输出 JSON/Markdown
- 类别枚举 `CATEGORY`（10 类，无 `OTHER` 兜底）
- 判据表：`topdir × ext` → `category/content_type/needed` 的映射
- `tests/unit/test_mod_audit.lua`：穷举完整性断言
- 注册进 `tests/test_runner.lua`

## Out of Scope

- 字段级覆盖（→ `allmods-slice0c-format-spec`）
- 证据的完整收集（→ `allmods-slice0c-unneeded-evidence`；本 change 只保证 `evidence` 字段存在且非空）
- 修复任何"未进产物"的文件（只审计，不修）

## Requirements

### [REQ-INV-1] 穷举遍历，无遗漏

工具必须遍历 `reference/allmods/kys-*/` 下**全部**文件（含隐藏文件、无扩展名文件、
嵌套子目录），不得依赖白名单目录列表。

- **GIVEN** `reference/allmods/kys-*/` 含 11220 个文件
- **WHEN** 运行 `lua tools/mod_audit.lua --all`
- **THEN** `audit.json` 含恰好 11220 条记录，`Σ(records) == 11220`

### [REQ-INV-2] 每条记录恰好一个类别，无兜底

`category` 必须 ∈ `CATEGORY` 枚举（10 类）。任何无法归类的文件必须
使工具**非 0 退出**并打印该文件路径，不得静默归入 `OTHER`。

- **GIVEN** 判据表未覆盖某文件
- **WHEN** 运行审计
- **THEN** 工具报错退出，列出未覆盖文件的 `topdir/ext`

### [REQ-INV-3] 类别枚举穷举且稳定

```
REQUIRED, REQUIRED_CONVERTED, DESIGNED_FALLBACK, DEAD_PARAM,
LEGACY, DEAD_FILE, EDITOR_DUMP, BUILD_INPUT, PLATFORM_ARTIFACT, PENDING
```

- **GIVEN** `CATEGORY` 已定义
- **WHEN** 测试检查
- **THEN** 枚举恰好 10 项，且 `audit.json` 中出现的类别集合 ⊆ 枚举

### [REQ-INV-4] `needed=false` 必有证据

每条 `needed=false` 记录的 `evidence` 数组非空，且每个元素含
`kind` ∈ {`code`,`strings`,`offset_table`,`format`,`external`,`manual`}
与 `ref`/`text`。

- **GIVEN** 某记录 `needed=false`
- **WHEN** 检查 `audit.json`
- **THEN** `#evidence >= 1` 且每个元素字段合法

### [REQ-INV-5] `in_product` 可交叉验证

`in_product=true` 的记录必须能在 `game/mods/<mod>/` 下找到对应文件
（考虑别名转换：`sdx` → `smap.idx`）。

- **GIVEN** 记录 `in_product=true`
- **WHEN** 测试在产物中查找
- **THEN** 存在对应文件（原名或别名目标名）

### [REQ-INV-6] 人类可读报告

`audit.md` 按 `category` 分组，每组列出文件数 + 代表性文件 + 证据摘要；
并含汇总表 `类别 | 文件数 | 占比 | 是否进产物`。

- **GIVEN** `audit.json` 已生成
- **WHEN** 生成 `audit.md`
- **THEN** 含 10 个类别分组与汇总表，且汇总数字与 JSON 一致

### [REQ-INV-7] 零回归

- **GIVEN** 本 change 只新增审计工具与测试
- **WHEN** 运行 `lua tests/test_runner.lua`
- **THEN** 全绿（449 + 新增）

## Impact

- **新增**：`game/tools/mod_audit.lua`、`game/tests/unit/test_mod_audit.lua`
- **修改**：`game/tests/test_runner.lua`（注册模块）
- **产物**：`game/mods/_audit/audit.json`、`game/mods/_audit/audit.md`（生成物，`.gitignore` 忽略）
- **未触碰**：`game/engine-love2d/**`、`game/engine-mud/**`、`reference/allmods/**`

## DoD

1. `lua tools/mod_audit.lua --all` 退出码 0，输出 `total=11220 unclassified=0`
2. `audit.json` 记录数 == 11220，所有 `category` ∈ 枚举
3. 所有 `needed=false` 记录 `evidence` 非空
4. `test_mod_audit.lua` 全绿
5. `lua tests/test_runner.lua` 全绿（无回归）
