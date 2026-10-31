---
status: active
created: 2026-10-26
---

# 再破菠萝（pineapple）资源差异审计报告

> 子 change：[`allmods-pineapple-verify`](../proposal.md)
> 前序：[`allmods-pineapple-activate`](../../allmods-pineapple-activate/verification.md)（13/13 通过）
> 父切片：[`allmods-slice12`](../../allmods-slice12/slice-proposal.md)
> 工作目录 `game/`，源 MOD `../reference/allmods/kys-pineapple`

---

## 摘要

| 维度 | 数值 |
|------|------|
| 源文件总数 | **529** |
| 构建产物（`data/`） | **349** 个文件 |
| `diff.md` 声明 | MOD 独有 **140** / 基线独有 **21** |
| 双向集合相等 | ✅ **True / True** |
| fight 四象限 | `A=2 / B=90 / C=62 / D=115` |
| 基线独有三分类 | `18 槽 + 3 回退 + 0 真删除` |
| 非 fight 溯源 | `15 IDENTICAL + 1 GENERATED` |
| **真实缺陷** | **0** |

**结论：161 条差异全部有正当理由，无一条无法解释。**

---

## 1 `diff.md` 可靠性：双向 set-equal

不只比数量（`140 = 140`），而是比**集合相等**：

```
diff.md added: 140  removed: 21
实测 MOD 独有: 140  实测 基线独有: 21
add == 实测MOD独有 ? True
rem == 实测基线独有 ? True
```

> **为什么必须比集合**：若 `diff.md` 有「1 个错项 + 1 个漏项」，总数仍为 140，
> 计数校验会通过而缺陷被掩盖。`set ==` 才能暴露。

---

## 2 两套口径必须分离（本报告最重要的方法论点）

存在两套**互不相同**的分类方式，混用会产生错误结论。

### 口径 ① `diff.md`：「基线中是否同名存在」

| 类别 | 条数 | 说明 |
|------|-----:|------|
| MOD 独有 fight | **124** | = 62 组 × 2（`.grp` + `.idx`） |
| MOD 独有 非 fight | **16** | §4 |
| **合计** | **140** | |

### 口径 ② 四象限：「同名 × 内容 × 零字节」（仅 `.grp`）

| 象限 | 条数 | 性质 |
|------|-----:|------|
| A 同名同容 | **2** | `fight000.grp`、`fight015.grp` 未改 |
| B 同名异容 | **90** | MOD 改写（76 个清零） |
| C MOD 独有 | **62** | MOD 新增编号 |
| **合计** | **154** | = MOD fight 总数 |

### 关键关系

```
124 = 62 × 2     口径①按「文件」计，口径②按「组」计
```

### ⚠ 只看 `diff.md` 会漏掉 90 处改写

`diff.md` 的生成逻辑只列「基线中**无此名**」的文件。同名但内容不同的文件
（B 类 90 个）**不会出现**在 `diff.md` 中：

```
A 在 diff 中: []      ← 完全无差异，理应不出现
B 在 diff 中: 0       ← 90 处改写，diff.md 看不见
```

⇒ **必须用四象限补全 `diff.md` 的盲区**，这是本 change 的核心发现。

---

## 3 fight 四象限完整分解

```
MOD fight*.grp: 154  基线: 92
同名共有: 92  MOD独有: 62  基线独有: 0
共有中内容相同: 2  内容不同: 90
MOD 零字节 grp: 115
零字节中与基线同名: 76
```

### 自洽校验（全部通过）

| 校验 | 等式 | 结果 |
|------|------|:----:|
| A + B = 基线 fight 数 | `2 + 90 = 92` | ✅ |
| A + B + C = MOD fight 数 | `2 + 90 + 62 = 154` | ✅ |
| D 的象限归属 | `D∩B(76) + D∩C(39) = D(115)`，`D∩A = 0` | ✅ |

### A 象限的价值

`A = 2`（`fight000.grp`、`fight015.grp` md5 与基线相同）证明
**MOD 并非全量替换 fight**，而是有选择地保留部分基线贴图。
若 `A = 0`，则「保留基线」这一结论无法成立。

---

## 4 零字节 115 个：源侧决定性证据

### 4.1 问题

115 个零字节 `fight*.grp` 若被描述为「构建工具生成了 115 个垃圾文件」，
会导向对 `mod_build.lua` 的错误修复。

### 4.2 决定性证据

```
产物零字节 grp: 115
源中找不到: 0
源也 0B: 115
源非 0B: 0
```

⇒ **115/115 源文件本身即 0 字节**。`mod_build.lua` 只是忠实复制。

### 4.3 两层性质分解

| 层 | 判据 | 条数 | 性质 |
|----|------|-----:|------|
| 基线侧 | 零字节 ∩ 与基线同名 | **76** | MOD **清零**了基线的非零贴图 |
| 基线侧 | 零字节 ∩ 基线无此名 | **39** | MOD **新增**空编号占位 |
| **合计** | | **115** | |

`76 + 39 = 115` ✅

### 4.4 与引擎行为一致

`allmods-pineapple-activate` REQ-PIN-8 已完成三分支实测：

| 分支 | 条数 | 引擎行为 |
|------|-----:|----------|
| `OK` | 36 | 正常返回 `w×h` |
| `ZERO_BYTE` | **115** | `getPic` 索引缺失（`lib_love.lua:270`），返回 `nil` → `0,0` |
| `FILE_MISSING` | 0 | 本 MOD 无实例 |

引擎**饱和降级，不崩溃**。故无需生成占位图。

---

## 5 21 条基线独有三分类

```
总数: 21  槽类: 18  非槽: 3
非槽明细: ['allsinbk.grp', 'thing.grp', 'thing.idx']
```

| 类 | 条数 | 判据 | 性质 |
|----|-----:|------|------|
| ① 存档槽改道 | **18** | `mods/pineapple/save/<n>` 存在且长度 == 源 | 设计内路由 |
| ② 模板回退 | **3** | 产物无；`ModData.Resolve` 回退基线 | 设计内回退 |
| ③ 真删除 | **0** | 三处皆无 | **不存在** |

`18 + 3 + 0 = 21` ✅

### 5.1 ① 存档槽 18 个（9 组 × 2）

```
d1/d2/d3.grp = 519200 ; .idx = 476
r1/r2/r3.grp = 228210 ; .idx = 24
s1/s2/s3.grp = 5799936 ; .idx = 476
槽类长度不一致: []
```

依据 `tools/mod_build.lua:626-631` 的 `isSaveSlotFile` + `:665-670` 路由，
`[rds]\d+\.(grp|idx)` 应落 `save/` 而非 `data/`。

### 5.2 ② 模板回退 3 个（实测生效）

```bash
$ find ../reference/allmods/kys-pineapple \( -name 'allsinbk*' -o -name 'thing.*' \) | wc -l
0
```

源中**不存在**。但运行时：

```
thing.grp      -> data/thing.grp          EXISTS (345600 B)
thing.idx      -> data/thing.idx          EXISTS (800 B)
allsinbk.grp   -> data/allsinbk.grp       EXISTS (4128768 B)
```

`ModData.Resolve` 回退到基线 `game/data/`，文件存在可用。
属 `framework/mod_data.lua`（`allmods-data-fallback`）的**设计内回退**。

### 5.3 ③ 真删除 = 0

**没有任何基线文件被真正删除。** 任何「MOD 删除了 21 个基线文件」的表述均为错误。

> **与 RiverLake 的区别**：RiverLake 的 `allsinbk.grp` 是「路径被引用、
> 内容未被使用」（fallen-back dead file）；pineapple 是「MOD 未提供、回退基线」。
> 语义不同，**不合并**。

---

## 6 16 条非 fight 溯源

```
字节完全一致: 15  不同: 0
```

| 文件 | 产物大小 | 源大小 | 判定 |
|------|--------:|-------:|------|
| `cloud.grp` | 38120 | 38120 | IDENTICAL |
| `cloud.idx` | 36 | 36 | IDENTICAL |
| `end.png` | 490590 | 490590 | IDENTICAL |
| `icon.png` | 9383 | 9383 | IDENTICAL |
| `kdef.grp` | 608388 | 608388 | IDENTICAL |
| `kdef.idx` | 4272 | 4272 | IDENTICAL |
| `kysmod.ini` | 1666 | 1666 | IDENTICAL |
| `name.grp` | 152082 | 152082 | IDENTICAL |
| `name.idx` | 14384 | 14384 | IDENTICAL |
| `open.png` | 152850 | 152850 | IDENTICAL |
| `ranger.str` | 21987 | — | **GENERATED** |
| `talk.grp` | 152098 | 152098 | IDENTICAL |
| `talk.idx` | 14384 | 14384 | IDENTICAL |
| `talkutf8.txt` | 223454 | 223454 | IDENTICAL |
| `title.grp` | 8179 | 8179 | IDENTICAL |
| `title.idx` | 36 | 36 | IDENTICAL |

### 6.1 `ranger.str` 是构建生成物

```bash
$ find ../reference/allmods/kys-pineapple -name 'ranger.str' | wc -l
0
```

源中**不存在**（0 命中）。由 `tools/mod_encoding.lua` 从 `ranger.grp` 的
hint 字段提取生成，格式 `index,segment,record,field,value`，648 行。
**有真实消费者，不是多余产物。**

### 6.2 0 条 DIFFERS 的意义

15 条非 fight **全部字节完全一致**，说明构建对 MOD 自带的
非 fight 资源是**纯复制**（无转码、无改写）。
这与 `ranger.grp`（Big5→UTF-8 转换）形成对照 —— 需要转码的只有记录数据。

---

## 7 差异全量账目

### 7.1 `diff.md` 口径（文件级）

| 项 | 条数 |
|----|-----:|
| MOD 独有 fight `.grp` | 62 |
| MOD 独有 fight `.idx` | 62 |
| MOD 独有非 fight | 16 |
| **MOD 独有小计** | **140** |
| 基线独有 → 存档槽 | 18 |
| 基线独有 → 模板回退 | 3 |
| 基线独有 → 真删除 | 0 |
| **基线独有小计** | **21** |
| **总计** | **161** |

### 7.2 四象限口径（fight 组级，补 `diff.md` 盲区）

| 项 | 条数 |
|----|-----:|
| A 同名同容（不在 diff） | 2 |
| B 同名异容（不在 diff） | **90** |
| C MOD 独有（= diff 的 62 `.grp`） | 62 |
| **合计 = MOD fight 数** | **154** |

⇒ `diff.md` 的 62 `.grp` + 隐藏的 `2 + 90` = `154` MOD fight 全部覆盖。

---

## 8 门禁复跑

| # | 门禁 | 结果 |
|---|------|:----:|
| 1 | 单元测试 1842 | ✅ |
| 2 | pascal baseline `mismatches=0` | ✅ |
| 3 | 20 MOD 构建 0 失败 | ✅ |
| 4 | `mod_check` 20/20 | ✅ |
| 5 | `mod_audit --all` `bad_evidence=0` | ✅ |
| 6 | `format_spec --all` `gaps=0` | ✅ |
| 7 | 槽 341 + 模板 110 = 451，真实问题 0 | ✅ |
| 8 | 四禁改路径零改动 | ✅ |

---

## 9 结论与建议

### 9.1 结论

1. **161 条差异全部正当**，真实缺陷 **0**。
2. **115 个零字节 fight 的源文件全部也是 0B** —— MOD 设计如此，非构建缺陷。
3. **无基线文件被真正删除**（真删除 = 0）。
4. **`diff.md` 存在结构性盲区**：只报「基线无此名」，漏掉 90 处同名改写。

### 9.2 建议（均不在本 change 范围）

| 建议 | 归属 | 理由 |
|------|------|------|
| `diff.md` 增加「同名异容」段落 | 独立工具 change | 当前会漏 90 处改写，影响全部 20 MOD |
| `CC.Effect` 仅 53 项 / 越界 62 条 | `allmods-effect-table` spike | 四禁改路径，需 `list/effect.bin` |
| `icon.png` 改判 `LEGACY` | 独立 change | 影响 20 MOD 分类计数 |
| `not_in_product` 改名 `needed_in_product` | 独立 change | 影响 20 MOD 审计口径 |
