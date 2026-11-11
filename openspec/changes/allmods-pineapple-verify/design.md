---
status: done
created: 2026-10-26
---

# Design: allmods-pineapple-verify

> 关键决策以 ADR 记录（Context / Decision / Alternatives / Consequences）。

---

## ADR-PINV-001 「差异条目集合」必须双向 set-equal，而非数量相等

**Context**
`diff.md` 自带 `MOD 独有: 140` / `基线独有: 21` 两个计数。若只校验
「我数出来的也是 140 / 21」，则 140 个条目里若有 1 个错、另 1 个漏，
总数仍是 140，**缺陷被计数掩盖**。

**Decision**
用 Python `set` 做**双向**比较：

```python
add = {条目 | diff.md 中 "  - + " 行}
rem = {条目 | diff.md 中 "  - - " 行}
实测独有 = set(os.listdir("mods/pineapple/data")) - set(os.listdir("data"))
实测基线 = set(os.listdir("data")) - set(os.listdir("mods/pineapple/data"))
assert add == 实测独有      # 双向相等，不只是 len 相等
assert rem == 实测基线
```

**Alternatives**
- A. 只比 `len()` —— 被否：无法发现「一错一漏」。
- B. 比排序后列表 —— 等价但啰嗦，`set` 语义更直接。

**Consequences**
- 正：任何一错一漏都会使 `==` 为假，缺陷无法被计数掩盖。
- 正：同时验证 `diff.md` 自身生成逻辑（`mod_build.lua` 的 diff 段）无遗漏。
- 负：需要真实列目录，比读 `diff.md` 慢（可忽略）。

---

## ADR-PINV-002 154 个 fight 必须做四象限分解，不能只说「154 个 fight」

**Context**
「154 个 fight 文件」是个无信息量的数字。实际存在四种性质完全不同的情况，
混在一起会把「MOD 故意清零」误判为「构建丢失文件」。

**Decision**
按「是否与基线同名」× 「内容是否相同」× 「是否零字节」做四象限：

| 象限 | 判据 | 实测 | 性质 |
|------|------|-----:|------|
| A 同名同容 | 基线有此名 + md5 相同 | **2** | MOD 未修改该贴图 |
| B 同名异容 | 基线有此名 + md5 不同 | **90** | MOD 改写贴图（含 76 个清零） |
| C MOD 独有 | 基线无此名 | **62** | MOD 新增贴图 |
| D 零字节 | `size == 0` | **115** | 见 ADR-PINV-003 |

校验 `A + B = 92`（= 基线 fight 数）、`B + C` 中零字节 = 115。

**Alternatives**
- A. 只统计总数 154 —— 被否：无法区分清零与丢失。
- B. 按「文件是否存在」二分 —— 被否：零字节文件存在，`exists()` 为真，会归错类。

**Consequences**
- 正：`76 个零字节且与基线同名` 直接证明「MOD 把基线贴图清零」，
  而非「MOD 新增了 115 个空文件」——性质判定完全相反。
- 负：需同时枚举 MOD 与基线两侧目录。

---

## ADR-PINV-003 「零字节」是**被清零**，不是**新增空文件**

**Context**
115 个零字节 fight 若被描述为「新增了 115 个空 fight 包」，会导向
「构建工具生成了垃圾文件」的错误结论，进而触发对 `mod_build.lua` 的错误修复。

**Decision**
必须验证零字节文件与基线同名文件的关系：

```python
zn = {MOD 中 size==0 的 fight 文件名}
bn = {基线 fight 文件名}
zero_and_in_baseline = len(zn & bn)   # 实测 76
```

**实测结果（两层）**：

1. **源侧**：115 个零字节 `fight*.grp` 的源文件**全部也是 0B**
   （`源中找不到 = 0`、`源非 0B = 0`）⇒ 零字节**来自 MOD 作者**，与 `mod_build.lua` 无关。
2. **基线侧**：115 个零字节中，**76 个在基线中同名存在且基线版本非零**
   （如 `fight016.grp` 基线 320B/80 sprites，MOD 0B）；其余 **39 个**基线无此名。

⇒ 判定：MOD 作者对 **76 个基线贴图包做了清零替换**，另 **39 个是新增的空编号占位**。
两种性质都属 MOD 数据设计，`mod_build.lua` 忠实复制 0B 源文件，**无缺陷**。

**Alternatives**
- A. 归为构建缺陷 —— 被否：`mod_build.lua` 只做复制/转码，不产生零字节；
  **实测 115/115 源文件本身即 0B**（`源非 0B = 0`）。
- B. 生成占位图 —— 被否：会偏离源数据，且引擎已饱和降级（activate REQ-PIN-8）。

**Consequences**
- 正：与 activate 的「三分支降级」结论一致，两处证据互相印证。
- 正：避免了对构建工具的错误修复。
- 负：需读基线目录。

---

## ADR-PINV-004 `ranger.str` 是**构建生成物**，不可与源文件字节比对

**Context**
16 个非 fight 文件中 15 个能与源文件 md5 对上，唯独 `ranger.str` 在
`reference/allmods/kys-pineapple/` 中**不存在**。若按「找不到源 = 构建多产出」处理，
会误报缺陷。

**Decision**
显式验证源中不存在，并说明其生成路径：

```bash
find ../reference/allmods/kys-pineapple -name 'ranger.str'   # 无输出
```

`ranger.str` 由 `tools/mod_encoding.lua` 从 `ranger.grp` 的 hint 字段提取生成，
格式 `index,segment,record,field,value`，用于把 Big5 字段名映射到 UTF-8 显示名。
其 hint 去重行为见 activate REQ-PIN-12。

**Alternatives**
- A. 从产物删掉 `ranger.str` —— 被否：引擎/工具需要它做字段名映射。
- B. 归为 `EDITOR_DUMP` —— 被否：它有真实消费者（`mod_encoding` 读取）。

**Consequences**
- 正：15 IDENTICAL + 1 GENERATED 的分解完整覆盖 16 条。
- 负：需要 `find` 而非仅 `md5sum`。

---

## ADR-PINV-005 21 条基线独有必须分三类，不可合并为「MOD 删了文件」

**Context**
21 条基线独有里混着三种完全不同的情况。若合并为「MOD 删除了 21 个基线文件」，
结论完全错误（实际只有 0 个是真删除）。

**Decision**
按真实路由分三类：

| 类 | 判据 | 实测 | 性质 |
|----|------|-----:|------|
| ① 存档槽改道 | `isSaveSlotFile(name)` 为真 ⇒ 应落 `save/` | **18** | 在 `mods/pineapple/save/` 中，**逐字节一致** |
| ② 模板回退 | 源中不存在，`ModData.Resolve` 回退基线 | **3** | `thing.grp`、`thing.idx`、`allsinbk.grp` |
| ③ 真删除 | `save/` 与 `data/` 都没有，源中也没有 | **0（不存在）** | — |

① 的验证：`d1/d2/d3/r1/r2/r3/s1/s2/s3` 共 **9 组 × 2（`.grp`+`.idx`）= 18 个**，
全部 `size(mods/pineapple/save/`n`) == size(源 save/`n`)`，长度不一致数 = **0**。

实测分类闭合：`18（槽）+ 3（回退）+ 0（真删除） = 21` ✅

② 的验证（实测 `ModData.Resolve`）：

```
thing.grp      -> data/thing.grp          EXISTS (345600 B)
thing.idx      -> data/thing.idx          EXISTS (800 B)
allsinbk.grp   -> data/allsinbk.grp       EXISTS (4128768 B)
```

⇒ 这三个文件**运行时可用**，只是来自基线 `game/data/` 而非 MOD 产物。
属 `ModData.Resolve` 的**设计内回退**（`framework/mod_data.lua` `allmods-data-fallback`）。

**Alternatives**
- A. 合并为「MOD 删除 21 文件」 —— 被否：0 个真删除。
- B. 把 ② 判为构建遗漏 —— 被否：回退机制已实测生效，且源中本就没有。

**Consequences**
- 正：明确「真删除 = 0」，杜绝虚构缺陷。
- 正：与 Slice 10（RiverLake `allsinbk.grp`「引用但内容不用」）区分开 ——
  pineapple 是「MOD 未提供 ⇒ 回退基线」，语义不同，不合并。
- 负：需分别查 `save/`、`data/`、源三处。

---

## Negative Constraints（本 change 不得做的事）

1. **不得**以「140 = 140 / 21 = 21」判定 diff 正确 —— 必须双向 `set` 相等（ADR-001）。
2. **不得**把「同名不同内容」判为缺陷 —— MOD 改写贴图是正当行为（ADR-002 B 象限）。
3. **不得**把零字节 fight 描述为「新增空文件」—— 76/115 是基线文件被清零（ADR-003）。
4. **不得**为零字节 fight 生成占位图 —— 引擎已饱和降级。
5. **不得**把 `ranger.str` 判为「无源多余产物」—— 它是构建生成物（ADR-004）。
6. **不得**把 `thing.*`/`allsinbk.grp` 判为「构建遗漏」—— `ModData.Resolve` 回退已实测（ADR-005 ②）。
7. **不得**把 pineapple 的 `allsinbk.grp` 与 RiverLake 的情况合并 ——
   RiverLake 是「路径被引用、内容未被使用」，pineapple 是「MOD 未提供、回退基线」。
8. **不得**在本 change 修改任何工具（`game/tools/**`）—— 未发现工具缺陷。
9. **不得**在本 change 修改构建产物或源数据。
10. **不得**改四禁改路径：`game/engine-love2d/**`、`game/engine-mud/**`、
    `game/script/jyconst.lua` 常量、`reference/allmods/**`。
11. **不得**把 `CC.Effect` 越界判为本 MOD 数据缺陷 —— 7/20 MOD 共有，归 spike。
12. **不得**用 `mod_audit.lua pineapple` 位置参数取数（会静默审计 20 MOD，`total=11220`）。
13. **不得**用 `name:match("^[rds]%d+%.(grp|idx)$")` —— Lua 模式不支持 `|` 交替。

---

## Review Checklist

- [x] REQ-PINV-1 双向 set-equal 有 Python `assert` 级证据（不是肉眼比对）
- [x] REQ-PINV-2 140 = 124 fight + 16 非 fight，逐项列出
- [x] REQ-PINV-3 21 = **18** 槽 + **3** 回退 + **0** 真删除（已实测闭合：18+3=21）
- [x] REQ-PINV-4 16 = 15 IDENTICAL + 1 GENERATED
- [x] REQ-PINV-5 四象限 `2/90/62/115` 且 `A+B=92`、`A+B+C=154`、`D∩B(76)+D∩C(39)=115` 自洽
- [x] REQ-PINV-6 零字节 115 中 76 与基线同名 + **115/115 源文件也是 0B**（决定性）
- [x] REQ-PINV-7 `find ... -name ranger.str` 无输出
- [x] REQ-PINV-8 两套口径已分离：`124 = 62×2`；B 类 90 不在 `diff.md`（已实测）
- [x] REQ-PINV-9 报告产出且含全部数字
- [x] REQ-PINV-10 8 道门禁复跑
