---
status: done
created: 2026-10-26
---

# Spec: allmods-pineapple-verification

> 每个需求唯一 ID `[REQ-PINV-N]`；每个场景 Given/When/Then。

---

## REQ-PINV-1 `diff.md` 条目集合双向 set-equal

**Given** `mods/pineapple/diff.md` 声明 `MOD 独有: 140` / `基线独有: 21`
**When** 用 `set` 比较 `diff.md` 条目集合与实测目录差集
**Then** **两个方向都必须完全相等**（不只是数量相等）：
`set(diff.md 的 "  - + " 行) == set(mods/pineapple/data) - set(game/data)`
**And** `set(diff.md 的 "  - - " 行) == set(game/data) - set(mods/pineapple/data)`

**场景 1.1：一错一漏必须被检出**
**Given** 若 diff.md 有 1 个错项 + 1 个漏项，`len()` 仍为 140
**Then** 仅比数量**不能**通过校验；必须比集合 ⇒ `==` 为假

---

## REQ-PINV-2 140 条 MOD 独有逐项归类

**Given** `set(add) == 实测 MOD 独有` 成立
**When** 按文件名分类
**Then** `124` 条为 `fight\d{3}\.(grp|idx)`，`16` 条为非 fight
**And** 16 条非 fight 必须逐条列出（见 REQ-PINV-4）

**场景 2.1**：`124 + 16 == 140`

---

## REQ-PINV-3 21 条基线独有必须分三类

**Given** 21 条基线独有
**When** 按 `isSaveSlotFile` 与 `ModData.Resolve` 实际行为分类
**Then** 分且仅分为：

| 类 | 条数 | 判据 |
|----|-----:|------|
| ① 存档槽改道 | **18** | `mods/pineapple/save/<n>` 存在且长度 == 源 `save/<n>` |
| ② 模板回退 | **3** | 产物 `save/`、`data/` 均无；`ModData.Resolve` 回退基线且存在 |
| ③ 真删除 | **0** | 三处皆无 |

**And** `18 + 3 + 0 == 21` 必须闭合。

**场景 3.1：不得合并为「MOD 删除 21 文件」**
**Given** 真删除数为 0
**Then** 任何「MOD 删除了基线文件」的表述均为错误

**场景 3.2：② 类必须实测 `ModData.Resolve` 生效**
**Given** `thing.grp`、`thing.idx`、`allsinbk.grp` 在 `reference/allmods/kys-pineapple/` 中**不存在**
**When** 调用 `ModData.Resolve("data/thing.grp")`
**Then** 返回 `data/thing.grp`（基线路径）且该文件**存在**
⇒ 属设计内回退，非构建遗漏

---

## REQ-PINV-4 16 条非 fight 内容溯源

**Given** 16 条非 fight 的 MOD 独有文件
**When** 与 `reference/allmods/kys-pineapple/resource/` 及根目录比对 md5
**Then** `15` 条**字节完全一致**（md5 相同），`1` 条（`ranger.str`）源中不存在
**And** `15 + 1 == 16`

**场景 4.1：逐条 md5 一致清单**
`cloud.grp`、`cloud.idx`、`end.png`、`icon.png`、`kdef.grp`、`kdef.idx`、
`kysmod.ini`、`name.grp`、`name.idx`、`open.png`、`talk.grp`、`talk.idx`、
`talkutf8.txt`、`title.grp`、`title.idx` = 15 条 IDENTICAL。

---

## REQ-PINV-5 154 个 fight 必须四象限分解

**Given** MOD 有 154 个 `fight*.grp`，基线有 92 个
**When** 按「是否同名」×「内容是否相同」×「是否零字节」分解
**Then** 得到四象限且自洽：

| 象限 | 判据 | 期望 | 自洽校验 |
|------|------|-----:|----------|
| A 同名同容 | 基线有此名 + md5 相同 | **2** | — |
| B 同名异容 | 基线有此名 + md5 不同 | **90** | `A + B == 92`（基线 fight 数） |
| C MOD 独有 | 基线无此名 | **62** | `A + B + C == 154` |
| D 零字节 | `size == 0` | **115** | `D ∩ B = 76`，`D ∩ C = 39`，`76 + 39 == 115` |

**场景 5.1：A 象限必须存在**
**Given** 若 A = 0，则所有同名 fight 都被改写
**Then** 无法证明「MOD 部分保留基线贴图」；实测 A = 2（`fight000.grp`、`fight015.grp`）

**场景 5.2：不得只说「154 个 fight」**
**Given** 154 是四类之和
**Then** 单说总数无法区分「清零」「改写」「新增」

---

## REQ-PINV-6 零字节是「被清零」，不是「新增空文件」

**Given** 115 个零字节 `fight*.grp`
**When** 检查这些文件名是否在基线中存在
**Then** **76 个**在基线中同名存在，且基线版本**非零**
（如 `fight016.grp` 基线 320B / 80 sprites，MOD 0B）
**And** 其余 **39 个**在基线中不存在（MOD 新增的空编号占位）
**And** `76 + 39 == 115`

**场景 6.1：源文件本身即 0B（决定性）**
**Given** 若零字节是构建产生的，则源文件非空
**When** 逐个检查 `reference/allmods/kys-pineapple/fight/<n>` 的大小
**Then** 必须得到 `源中找不到 = 0` 且 `源非 0B = 0`，即 **115/115 源文件也是 0B**
⇒ 证明零字节**来自 MOD 作者**，`mod_build.lua` 只是忠实复制，无缺陷

---

## REQ-PINV-7 `ranger.str` 是构建生成物

**Given** `mods/pineapple/data/ranger.str` 存在于产物（21987B，648 行）
**When** 在源目录搜索
**Then** `find ../reference/allmods/kys-pineapple -name 'ranger.str'` **无输出**
**And** 其生成者为 `tools/mod_encoding.lua`（从 `ranger.grp` 的 hint 字段提取）

**场景 7.1：不得判为多余产物**
**Given** 源中无此文件
**Then** 不能按「找不到源 = 构建多产出」判缺陷；它是 UTF-8 字段名映射表，
有真实消费者

---

## REQ-PINV-8 两套口径必须显式分离，不得混用数字

**Given** 存在两套**互不相同**的分类口径：

**口径 ①（`diff.md` 口径 = 「基线中是否同名存在」）**

| 类别 | 条数 | 说明 |
|------|-----:|------|
| MOD 独有 fight（`.grp` + `.idx`） | 124 | = 62 组，每组 2 个文件 |
| MOD 独有 非 fight | 16 | 见 REQ-PINV-4 |
| 基线独有 | 21 | 见 REQ-PINV-3（18 槽 + 3 回退） |
| **`diff.md` MOD 独有合计** | **140** | `124 + 16 = 140` ✅ |

**口径 ②（四象限口径 = 「同名 × 内容 × 零字节」）**

| 象限 | 条数（**仅 `.grp`**） |
|------|-----:|
| A 同名同容 | 2 |
| B 同名异容 | 90 |
| C MOD 独有 | 62 |
| **合计 = MOD fight 数** | **154** ✅ |

**When** 做汇总
**Then** 必须明确：**口径①的 124 是「文件数（grp+idx）」，口径②的 62 是「组数（仅 grp）**；
`124 = 62 × 2`，两者**不矛盾但不可混用**。

**And** 必须说明 B 类（90 个同名异容）**不出现在 `diff.md` 中** ——
因为 `diff.md` 只列「基线中无此名」的文件，同名但内容不同的文件不构成「独有」。
⇒ 若只看 `diff.md` 会**漏掉 90 处改写**，必须用四象限补上。

**场景 8.1：A 类也不在 diff 中**
**Given** `fight000.grp`、`fight015.grp` md5 与基线相同
**Then** 它们既不在 `add` 也不在 `rem` 中 —— 完全无差异，理应不出现 ✅

**场景 8.2：B 类零字节归属**
**Given** B 类 90 个中有 76 个零字节
**Then** 这 76 个是「基线有非零贴图、MOD 清零」，
与 C 类的 39 个「MOD 新增空占位」性质不同，`76 + 39 = 115` 必须闭合 ✅

---

## REQ-PINV-9 产出人读报告

**Given** 上述 8 条需求全部完成
**Then** 必须产出 `reports/pineapple-verify.md`，含：
- 161 条差异的完整分解表
- 四象限 `2/90/62/115` 及其自洽校验
- 21 条基线独有三分类（`18/3/0`）
- 16 条非 fight 的 `15 IDENTICAL + 1 GENERATED`
- 每条结论附实测命令

---

## REQ-PINV-10 8 道门禁复跑

**Given** 审计过程**未修改**任何构建产物或工具
**Then** 复跑 8 道门禁结果必须与 `allmods-pineapple-activate` 一致：

| # | 命令 | 期望 |
|---|------|------|
| 1 | `lua tests/test_runner.lua` | `1842 / 1842 通过 / 0 失败` |
| 2 | `lua tools/mod_build.lua --verify-pascal` | PASS，`mismatches=0` |
| 3 | `lua tools/mod_build.lua --all` | `20 mods, 0 build failures`（退出码 1 属设计） |
| 4 | `lua tools/mod_check.lua` | `通过 20, 失败 0` |
| 5 | `lua tools/mod_audit.lua --all --evidence` | `unclassified=0 bad_evidence=0` |
| 6 | `lua tools/format_spec.lua --all` | `gaps=0` |
| 7 | 门禁 7 脚本 | 槽 341 + 模板 110 = 451，真实问题 0 |
| 8 | 三禁改路径 + `jyconst.lua` | 全空 / 无 `CC.*=` 增删 |

---

## Out of Scope

| 项 | 归属 |
|----|------|
| 修改构建产物或工具 | 本 change 只审计 |
| 修复 `CC.Effect` 越界（62/174） | `allmods-effect-table` spike |
| `not_in_product` 语义 | 独立 change |
| `icon.png` 改判 | 独立 change |
| Slice 13（books） | 下一 slice |
