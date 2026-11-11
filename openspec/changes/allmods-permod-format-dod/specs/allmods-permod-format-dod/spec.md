---
status: done
created: 2026-10-29
---
# Spec: allmods-permod-format-dod（总纲）

## [REQ-PFD-0] 19 个 MOD 全部有逐 MOD 字段/格式 DoD 留痕

**背景**：`format_spec.lua` 提供**全局**验证能力（`formats=14 checked=6838 gaps=0`），
但全局通过 ≠ 每个 MOD 都有自己可追溯的 DoD 记录。

### Scenario: 每个 MOD 的 verification 里都有字段/格式段
- **Given** 19 个 MOD（pascal 是基线，不计入）
- **When** 执行覆盖扫描
- **Then** 19/19 的 `verification.md` 含「字段/格式支持复核」或等价段
- **And** 命中数 = **19**

### Scenario: 数字与实测一致
- **Given** 任一 MOD 的 DoD 文档
- **When** 执行 `lua tools/format_spec.lua --mod <m>`
- **Then** 文档记录的 `checked` 与实测**逐字一致**
- **And** `formats` 记为 **14**（不是过时的 12）

### Scenario: 横向对照不得缺
- **Given** 任一 MOD 的字段/格式段
- **When** 检查其横向对照表
- **Then** 表中行数 = **20**（全部 MOD，含基线）
- **And** 本 MOD 有明确排名数字
- **反例禁止**：只报自身 `checked` 而不给横向定位

## [REQ-PFD-5] `bin_table` 缺口必须在每个 MOD 的 DoD 中显式声明

**背景**：`list/*.bin` 是 14 族中唯一**无引擎消费者**的族，
20/20 MOD 都受影响。若某 MOD 的 DoD 声称「全部格式已支持」而不提这一点，即为**不诚实**。

### Scenario: 受影响 MOD 必须标注处置状态
- **Given** 某 MOD 有 N 个 `list/*.bin`
- **When** 阅读其字段/格式段
- **Then** 明确写出每个 `.bin` 的**处置状态**（`effect`/`match` → 已进产物 + 运行时装载；
  `leave`/`levelup`/`*.txt` → `LEGACY` 零消费）
- **And** 指向 `allmods-list-bin-support` 作为统一处置 change

> **勘误（2026-10-29）**：本场景初稿要求写「引擎不读」，那是 `allmods-list-bin-support`
> **实施前**的现状描述。该 change 已落地（`effect.bin`/`match.bin` 20/20 进产物 +
> `ModData.LoadEffectTable` 装载），因此「引擎不读」已不再是事实，
> 要求改为「写清**当前处置状态**」——判据的实质（不得虚假声称全部支持）不变。

### Scenario: 不得把「跑了工具」当作「已支持」
- **Given** 某 MOD 的 DoD 只有 `format_spec --mod <m> gaps=0` 一行
- **When** 审查其是否回答了「字段语义是否有消费者」
- **Then** 该行**不足以**证明支持（`gaps=0` 只证明字节覆盖，不证明语义消费）
- **And** 必须补消费者列

## 非功能约束

| 约束 | 判据 |
|------|------|
| 零代码改动 | 本 change 只新增/追加 openspec 文档 |
| 四禁改 | 改动数 = 0 |
| 一致性 | 所有 MOD 段使用同一模板结构（5 小节） |
