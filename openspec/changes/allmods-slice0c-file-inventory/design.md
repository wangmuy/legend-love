---
status: done
parent_slice: allmods-slice0c
---
# Design: allmods-slice0c-file-inventory

## Context

需要把"是否每个源文件都被检查到并归类"从人工承诺变成机器保证。
核心难点：**如何证明"没有遗漏"**——遍历本身不能证明，只有"归类函数对任意输入
都有定义"才能证明。

## ADR-001: 用「无兜底枚举」而非「默认归类」来暴露遗漏

### Context
朴素做法是 `category = classify(path) or "OTHER"`。但 `OTHER` 会静默吸收
未预期文件，重现 `sdx/smp` 式的漏判。

### Decision
`classify()` 对无法归类的输入返回 `nil`，调用方**立即非 0 退出**并列出未覆盖的
`topdir/ext` 组合。`CATEGORY` 枚举中**不存在** `OTHER`/`UNKNOWN`/`MISC`。

### Alternatives
1. **`OTHER` 兜底 + 警告** — 否决：警告会被忽略，等同漏判。
2. **只白名单已知目录** — 否决：白名单外的目录被静默跳过，正是当前 bug。
3. **断言集合相等** — 采纳（本方案）：未归类 = 失败。

### Consequences
- 新增格式/目录时**必须**更新判据表，否则测试红 → 强制性维护。
- 判据表成为"资源类型的单一真相源"。

## ADR-002: 判据表按 `topdir × ext` 分派，而非按文件名

### Context
11220 个文件不能逐个硬编码。但按 `topdir` 单独分派又太粗
（`resource/` 下同时有 `.grp/.idx/.png/.002/.col/.sta/.txt/.ttf/.bat/.exe` 和无扩展名）。

### Decision
主键 = `(topdir, ext)`，辅以少量精确文件名覆盖（如 `resource/sdx` 无扩展名但有 4 个特例）。
判据表结构：

```lua
-- 精确文件名优先
EXACT = {
  ["resource/sdx"] = { category="REQUIRED_CONVERTED", needed=true, content_type="smap_index",
                       evidence={{kind="code", ref="tools/mod_build.lua:ALIAS_MAP"}} },
  -- ... smp, wdx, wmp
}
-- 然后 (topdir, ext)
BY_KIND = {
  ["fight", ".grp"] = { category="REQUIRED", needed=true, content_type="fight_sprite_rle" },
  ["head",  ".png"] = { category="EDITOR_DUMP", needed=false, content_type="png_image",
                        evidence={{kind="code", ref="tools/mod_build.lua:IGNORE_DIRS"}} },
  -- ...
}
```

### Alternatives
1. **纯扩展名** — 否决：`.idx` 在 `resource/` 是必需、在 `eft/` 是副产物。
2. **纯文件名 glob** — 否决：`fight/` 有 6173 个文件，glob 会爆炸。
3. **按 `topdir × ext`** — 采纳：11220 文件收敛到 ~30 个组合。

### Consequences
- 判据表约 30 行，可人工审阅。
- 新增 MOD 若引入新组合 → 报错（符合 ADR-001）。

## ADR-003: 审计产物写入 `game/mods/_audit/` 且不提交

### Context
审计输出（`audit.json`）包含绝对路径与生成时间，且是派生物。

### Decision
输出到 `game/mods/_audit/`（已被 `.gitignore` 的 `game/mods/` 覆盖）。
测试通过**调用工具 API**（非读文件）获取记录，避免依赖生成物存在。

### Alternatives
1. **写入 `openspec/`** — 否决：派生物污染 artifacts。
2. **只 stdout** — 否决：11220 条无法阅读，且测试需要结构化数据。
3. **写 `game/mods/_audit/`** — 采纳。

### Consequences
- 测试必须 `dofile`/`require` 工具模块拿 `M.auditAll()` 返回值。
- CI 无需缓存审计产物。

## Negative Constraints

- **禁止**引入 `OTHER`/`UNKNOWN`/`MISC`/`*_OTHER` 兜底类别
- **禁止**在判据表中使用"前缀匹配"以外的模糊规则（如 `f:match("fight")` 会误匹配 `fightXXX_02`）
- **禁止**修改 `reference/allmods/**`（只读）
- **禁止**修改 `game/engine-love2d/**`、`game/engine-mud/**`
- **禁止**让审计工具写任何非 `game/mods/_audit/` 的路径

## Alignment

- 复用 `tools/mod_build.lua` 的 `IGNORE_DIRS`、`ALIAS_MAP` 作为判据依据（不重复定义）
- 复用 `framework/mod_data.lua` 的常量名作为 `content_type` 命名参考
- 类别命名与 Slice 0b `DATA_FILES.md` §8 的分类表保持一致

## Review Checklist

- [ ] `CATEGORY` 无 `OTHER` 类
- [ ] 判据表覆盖全部 `(topdir, ext)` 组合（测试断言）
- [ ] `needed=false` → `evidence` 非空（测试断言）
- [ ] `in_product=true` → 产物中存在（测试断言）
- [ ] 未归类 → 非 0 退出（负例测试）
- [ ] 未修改 `reference/` 与引擎层
