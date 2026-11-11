---
status: done
parent_slice: allmods-slice0c
---
# Design: allmods-slice0c-format-spec

## Context

需要把"每个文件的每个字节都被归类"从人工承诺变成机器保证。
难点：变长记录（RLE/文本/指令流）没有固定字段表，字节边界只能由 offset 表推导。

## ADR-001: 用「区间覆盖」模型统一表达定长与变长格式

### Context
定长格式（`.002`、`.sta`、`.col`、`list/*.bin`）可直接写字段表；
变长格式（`hdgrp.grp` 的 RLE 记录）边界来自 `.idx`。若两套模型，验证逻辑会分裂。

### Decision
统一模型：每个格式由**有序的不重叠区间列表**构成。

```lua
-- 区间来源二选一
-- A. 静态：{ name, offset=100, size=50 }
-- B. 动态：{ name="records", from="offsets", to="offsets+1" }   -- 由 offset 表展开
```

`verifyCoverage` 先把所有区间（含动态展开）物化为 `[start, end)` 列表，
排序后断言：
1. 无重叠：`prev.end <= cur.start`
2. 无缺口：`cur.start == prev.end`
3. 全覆盖：`first.start == 0` 且 `last.end == filesize`

### Alternatives
1. **定长/变长两套验证器** — 否决：逻辑重复，易不一致。
2. **只验证"最后 offset == filesize"** — 否决：无法发现中间缺口。
3. **区间覆盖模型** — 采纳。

### Consequences
- `verifyCoverage` 是**唯一**的覆盖判定入口，定长与变长共用。
- 缺口报告为 `{start, end}` 列表，便于定位。

## ADR-002: offset 表的"段"必须显式建模

### Context
实测 `mmap.idx` 是**两段拼接**：前 3731 项单调递增到某值，第 3731 项回落到 0，
后 5000 项重新递增。朴素"单段"假设会导致 `verifyCoverage` 报大缺口。

### Decision
规格中显式声明段：

```lua
mmap = {
  idx = { segments = {
    { name="seg1", offset=0,     count=3731, type="uint32[]" },
    { name="seg2", offset=3731*4, count=5000, type="uint32[]" },
  }},
}
```

段的 `count` 由实测确定，并在 spec 中附 `evidence` 说明来源。

### Alternatives
1. **假设单段** — 否决：会误报缺口。
2. **自动探测段边界**（找 offset 回落点）— 否决：隐蔽且可能误判。
3. **显式声明段** — 采纳：可审阅、可断言。

### Consequences
- 每个多段格式必须在 spec 中列出段数与项数。
- 测试断言 `Σ(段字节) == idx 文件大小`。

## ADR-003: `tail` 字段必须显式存在（可为 0 字节）

### Context
`last_offset == filesize` 时尾部无字节。若字段表省略 `tail`，
"无缺口"证明不完整（无法区分"确实无尾字节"与"忘了写"）。

### Decision
每个变长格式的 grp 规格**必须**含 `tail` 字段，即使 `size == 0`：

```lua
grp = {
  records = { name="records", from="offsets" },
  tail    = { name="tail", offset="last_offset", size="rest", needed=false,
              evidence={kind="offset_table", text="实测 last offset == grp size，tail=0"} },
}
```

### Alternatives
1. **省略 tail** — 否决：覆盖证明有洞。
2. **tail 为可选** — 否决：可选即可能被忘。
3. **强制 tail** — 采纳。

### Consequences
- `needed=false` 的 tail 必须有 evidence（与 REQ-INV-4 一致）。
- 若某格式 tail > 0，会被显式发现并归类。

## ADR-004: 规格表按「格式名」组织，不按文件路径

### Context
`hdgrp.grp` 在 20 个 MOD 中路径相同但大小不同。规格必须与具体文件解耦。

### Decision
`SPEC.<format_name>` 是**纯结构描述**；文件路径由 `verifyAll()` 从 MOD 目录解析。
同一格式在不同 MOD 共用一份 spec。

### Alternatives
1. **按路径注册** — 否决：20 MOD 重复 20 份。
2. **按格式名** — 采纳。

### Consequences
- 新增 MOD 无需新增 spec（除非引入新格式）。
- spec 数量 == 格式族数量（~13）。

## Negative Constraints

- **禁止**在 spec 中使用"剩余全部字节"作为**唯一**字段（如 `{name="data", size="rest"}`）——
  必须拆到可命名的字段（`.002` 需拆到网格行/列语义，`list/*.bin` 需拆到记录字段）
- **禁止**修改 `reference/allmods/**`、`game/mods/**`（只读）
- **禁止**修改 `game/engine-love2d/**`、`game/engine-mud/**`
- **禁止**让 `verifyCoverage` 静默通过有缺口的输入
- **禁止**在 spec 中硬编码某个 MOD 的大小（须由 `verifyAll` 从实际文件推导）

## Alignment

- 字段命名复用 `DATA_FILES.md` 已有术语（`Base_S`、`Person_S` 等）
- 段偏移语义复用 `game/tools/mod_encoding.lua` 的 `ParseIdx`/`SEG_REC`
- `kdef` 指令流复用 `allmods-slice0` 逆向的 arity 表结论
- `hdgrp` RLE 复用 `lib_love.LoadPic` 的 `rle_header` 结构

## Review Checklist

- [ ] 每个格式 spec 含 `tail`（变长族）
- [ ] 多段 offset 表（`mmap`）显式建模
- [ ] 无"剩余全部字节"式懒字段
- [ ] 每字段含 `needed` 与 `consumer`
- [ ] 负例测试证明缺口会被报告
- [ ] 未修改 `reference/`、引擎层、`game/mods/`
