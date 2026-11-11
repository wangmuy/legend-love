---
status: done
parent_slice: allmods-slice0c
---
# Design: allmods-slice0c-unneeded-evidence

## Context

"不需要"这个判定本身没有价值——**有证据的"不需要"**才有价值。
问题是：什么样的证据算数？

`sdx/smp` 漏判的教训：当时清单里**确实列出了** `sdx`/`smp`，
但没有任何机制要求说明"它们对应引擎的什么"。于是被归类为"小写归一"。

## ADR-001: 证据必须机器可校验，而非自由文本

### Context
朴素做法：`evidence = "编辑器副产物，不用管"`。但自由文本无法验证真伪，
也无法在代码变动后自动失效。

### Decision
证据结构化，且**可机器校验**：

```lua
evidence = {
  kind = "code",                              -- 枚举
  ref  = "game/tools/mod_build.lua:IGNORE_DIRS",
  cmd  = "grep -n IGNORE_DIRS game/tools/mod_build.lua",
  expect = "head, item, eft",                 -- cmd 输出必须包含
  text = "构建器显式忽略这些目录，故不复制到产物",
}
```

测试执行 `cmd`，断言输出包含 `expect`。

### Alternatives
1. **自由文本** — 否决：不可验证，会退化。
2. **仅引用代码位置** — 否决：位置可能失效（重构后 grep 不到）。
3. **结构化 + 可执行校验** — 采纳。

### Consequences
- 证据可能因重构而失效 → 测试红 → 强制更新。这正是想要的。
- `cmd` 必须幂等、快速、无副作用。

## ADR-002: 证据种类按"证明方式"划分，而非按"资源类型"

### Context
若按资源类型分（`head` 的证据、`music` 的证据），新增类型时无章可循。

### Decision
按**证明方式**划 6 类，每类有固定的校验方法：

| kind | 证明什么 | 校验方法 |
|------|---------|---------|
| `code` | 引擎代码不引用 | 执行 `cmd`，断言输出含/不含 `expect` |
| `strings` | C 引擎不引用 | `strings kys.exe \| grep <name>` 为空 |
| `offset_table` | 结构上不存在该区域 | 数值断言（如 `last_offset == grpsize`） |
| `format` | 命名规则无法生成 | 执行格式化函数，断言 ≠ 目标名 |
| `external` | 需外部工具/格式不兼容 | 断言文件头魔数 ≠ 引擎期望格式 |
| `manual` | 人工判定 | 必须附 `cmd`，且 `cmd` 输出非空 |

### Alternatives
1. **按资源类型分** — 否决：无章可循。
2. **按证明方式分** — 采纳。

### Consequences
- 新增证据时先问"我怎么证明"，再选 kind。
- `manual` 被限制为"必须有可复现命令"，避免成为逃避口。

## ADR-003: 文档与 JSON 双向可追溯

### Context
若 `MOD_RESOURCE_AUDIT.md` 与 `audit.json` 各自维护，必然漂移。

### Decision
`MOD_RESOURCE_AUDIT.md` 由 `mod_audit.lua` **生成**（非手写），
每行含 `<!-- rec:<mod>:<path> -->` 注释锚点指向 JSON 记录。
测试断言：文档中每个锚点都能在 JSON 找到，且证据字段一致。

### Alternatives
1. **手写文档** — 否决：必然漂移。
2. **只留 JSON** — 否决：人类不可读，且用户要求"列出来"。
3. **生成 + 锚点** — 采纳。

### Consequences
- 文档不可手改（会被覆盖）；修改需求要改生成器。
- `MOD_RESOURCE_AUDIT.md` 是否提交仓库？→ **提交**（它是权威交付物，非派生物）。
  但生成源 `audit.json` 不提交（含绝对路径/时间戳）。

## ADR-004: `PENDING` 类必须显式存在且不被当作 `needed=false`

### Context
`music/*.mid` 既不是"引擎需要"（格式不兼容），也不是"确定不需要"（需 spike 决策）。

### Decision
引入 `PENDING` 作为独立类别：
- `needed = nil`（未知，非 `false`）
- 必须含 `evidence`（说明为何未决 + 需什么决策）
- 测试断言 `PENDING` 的记录数 > 0 且每条有 `evidence`

### Alternatives
1. **归入 `needed=false`** — 否决：掩盖"待决策"与"确定不要"的区别。
2. **归入 `needed=true`** — 否决：会误导为"应该复制"。
3. **独立 `PENDING` 类** — 采纳。

### Consequences
- `PENDING` 是 epic TODO 的机器可读镜像。
- 决策后必须改为 `needed=true/false` 并补证据。

## Negative Constraints

- **禁止** `evidence` 为空数组（`needed=false` 时）
- **禁止** `evidence.text` 长度 < 10（空壳）
- **禁止** `kind="code"` 的证据缺少 `cmd`
- **禁止**手改 `MOD_RESOURCE_AUDIT.md`（会被生成器覆盖）
- **禁止**修改 `reference/allmods/**`、`game/mods/**`、引擎层
- **禁止**把 `PENDING` 静默当作 `needed=false` 或 `needed=true`

## Alignment

- 证据类别与 Slice 0b `DATA_FILES.md` §8 的分类表一一对应
- `PENDING` 条目与 epic `TODO.md` 的 `music/*.mid` spike 条目互为镜像
- `code` 证据的 `ref` 格式复用 `文件:符号` 约定

## Review Checklist

- [ ] 每个 `needed=false` 有 ≥1 条结构化证据
- [ ] `code` 类证据含可执行 `cmd`
- [ ] `PENDING` 类存在且不被混入 `needed=false`
- [ ] `MOD_RESOURCE_AUDIT.md` 由生成器产出且含锚点
- [ ] 1971 个未进产物文件全部有理由
- [ ] 未修改 `reference/`、引擎层、`game/mods/`
