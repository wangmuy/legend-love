---
status: done
created: 2026-10-29
---
# Design: allmods-list-bin-support

## 上下文

`list/` 目录在源侧 20 个 MOD 中共 82 个 `.bin` 文件，但：

- 产物 `data/list/` **为空**（构建器不搬）
- 引擎侧全仓 grep 对 `list/` 与 `.bin` 的引用 **为 0**
- `CC.Effect` / `CC.ExtraOffense` 硬编码了其中的数据，且 `effect.bin` 被截断 64→53

`mod_audit` 因此把它们标为 `PENDING`（needed=nil），即「未判定」。
对于一个声称「穷举审计」的体系，`PENDING` 是不可接受的终态。

## ADR-1: `list/*.bin` 的终态归类

### Context

`list/*.bin` 有 4 类：`effect.bin`（武功效果帧数表）、`match.bin`（武器-武功配合）、
`leave.bin`（离队条件）、`levelup.bin`（升级经验表）。再加 2 个 `.txt`（通关/开场字幕）。

实测每个文件都是**定长 uint16 数组**：

| 文件 | pascal 字节 | 项数 | 语义 | 硬编码替代 |
|------|-------------|------|------|-----------|
| `effect.bin` | 128 | 64 | 各武功效果贴图个数 | `CC.Effect`（53 项，**截断**） |
| `match.bin` | 96 | 48 | 武器 id / 武功 id / 攻击力增量（三元组） | `CC.ExtraOffense` |
| `leave.bin` | 200 | 100 | 可离队人物 id | 无（引擎未实现离队） |
| `levelup.bin` | 202 | 101 | 升级经验阈值 | 无（引擎用公式） |
| `end.txt` / `start.txt` | — | — | 字幕文本 | 无 |

### Decision

**分三类处理，不搞一刀切：**

1. `effect.bin` + `match.bin` → **`REQUIRED`，进产物 + 运行时装载**
   理由：引擎**已有**对应硬编码且数据可对齐（`CC.Effect[1..52]` 逐项等于
   `effect.bin[1..52]`）。硬编码是截断的、且无法随 MOD 变化，属于真实缺陷。
2. `leave.bin` + `levelup.bin` → **`LEGACY`，evidence 记录「引擎未实现该功能」**
   理由：引擎既无硬编码也无读取路径。搬进产物也不会被消费，属于
   「原版就有的、本复刻未实现的功能数据」。**不得**为了让分类好看而强行装载。
3. `end.txt` + `start.txt` → **`LEGACY`**，同 2。

### Alternatives

| 方案 | 做法 | 否决理由 |
|------|------|---------|
| A 全部标 `LEGACY` | 承认引擎不读，一律不需要 | `effect.bin` 明明有硬编码消费，标 LEGACY 是**说谎** |
| B 全部进产物 + 全部装载 | 4 个都搬都读 | `leave.bin`/`levelup.bin` 无消费方，装载后是死代码 |
| C 改 `CC.Effect` 字面量 | 直接把 53 改成 64/200 | **禁改路径**（`jyconst.lua` 常量） |
| **D 分类处理（采纳）** | 有消费者的进产物+装载，无消费者的标 LEGACY+证据 | — |

### Consequences

- `mod_audit` 的 `PENDING`（`.bin 82`）**归零**，其中 40 条 → `REQUIRED`，
  42 条 → `LEGACY`
- 20/20 MOD 的 `effect.bin` 帧数表按 MOD 各自生效，`eft >= 53` 不再静默退化
- 零回归：无 `data/effect.bin` 时保留 53 项硬编码兜底

## ADR-2: 运行时装载的实现位置（避开禁改路径）

### Context

`CC.Effect` 是 `jyconst.lua:439` 的字面量，属于**禁改路径**。
但 `CC` 是 `jyconst.lua` 的 `local`，经 `jymain` 初始化链提升为 `_G.CC`。

### Decision

**不修改 `jyconst.lua` 一个字**。在引擎无关层新增装载函数，
在 `CC` 已是全局之后调用，**读入后覆盖 `CC.Effect` 表**：

```
framework/mod_data.lua  已有 Resolve() 回退链
  └─ 新增 M.LoadEffectTable(modSlug)
       ├─ 尝试读 data/effect.bin（产物，按 MOD）
       ├─ 成功 → 构造新表覆盖 _G.CC.Effect
       └─ 失败 → 保留 jyconst.lua 的 53 项兜底（零行为变化）
```

调用点：`framework/jymain_adapter.lua` 的 init 链（`CC` 已就绪之后）。

### Alternatives

| 方案 | 否决理由 |
|------|---------|
| 改 `jyconst.lua` 把 `CC.Effect` 换成函数调用 | 禁改路径，且破坏 `CC` 常量语义 |
| 在 `engine-love2d/` 里装载 | 禁改路径；且 `list/` 是引擎无关数据 |
| 构建期把 `effect.bin` 转成 Lua 表文件 | 引入代码生成，产物不可审计；`.bin` 本身已是权威数据 |

### Consequences

- `format_spec.lua` 的 `bin_table` 家族从「4 字节单元 + tail」升级为
  **记录级**（`.bin` 是定长 uint16 数组，`records = filesize % 2 == 0`）
- 需要新增单测：装载成功 / 文件缺失兜底 / 条目数 > 53 不越界

## Negative Constraints（不得做）

1. **不得**修改 `game/script/jyconst.lua` 中的 `CC.*` 字面量（禁改路径）
2. **不得**修改 `game/engine-love2d/**`、`game/engine-mud/**`
3. **不得**修改 `reference/allmods/**`
4. **不得**把 `leave.bin` / `levelup.bin` 强行装载成死代码来「凑覆盖率」
5. **不得**用「条目数相等」代替「内容相等」宣称 `effect.bin` 与 `CC.Effect` 一致
   ——实测二者**不一致**（64 vs 53，`CC.Effect[0]=9` 是占位、`effect.bin[0]=10` 被丢弃）
6. **不得**为了让 `mod_audit` 的 `PENDING=0` 而把未判定的文件塞进 `LEGACY`
   ——每个 `LEGACY` 必须有 `evidence`
7. **不得**把 `.mid`/`.mp3`/`.sf2`（581 条）纳入本 change 的「支持」范围
   ——它们是音频转换域，`allmods-spike-music-refs` 已判定 defer

## Review Checklist

- [ ] `mod_audit --all --evidence` 的 `PENDING` 从 663 → **581**（仅剩音频）
- [ ] `list/*.bin` 无一条仍是 `PENDING`
- [ ] `effect.bin` 进产物且 `format_spec` 记录级验证 `gaps=0`
- [ ] `jyconst.lua` 的 `CC.*=` 改动数 = **0**
- [ ] 无 `data/effect.bin` 时行为与基线**逐字节一致**（兜底路径）
- [ ] 四禁改路径 `git status --porcelain` 命中数 = **0**
