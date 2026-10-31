---
status: done
created: 2026-10-26
---

# Proposal: allmods-pineapple-verify

> 父切片：[`allmods-slice12`](../allmods-slice12/slice-proposal.md)（pineapple / 再破菠萝）
> 前序子 change：[`allmods-pineapple-activate`](../allmods-pineapple-activate/proposal.md)（已 13/13 通过）
> 父 epic：[`2026-10-allmods-compat`](../../epics/2026-10-allmods-compat/epic.md)

---

## 1 为什么需要本 change

`allmods-pineapple-activate` 已证明 **「MOD 能被正确构建、审计、加载、启动」**，
但它回答的是「产物对不对」，**不回答**「产物与基线到底差在哪、每一处差异是否都有正当理由」。

本 change 补上后半段：**逐项审计 `diff.md` 的 161 条差异**
（140 条 MOD 独有 + 21 条基线独有），为每条给出归类与理由，并验证
**集合双向相等**（`diff.md` 的条目集合必须与实测集合完全一致，不多不少）。

---

## 2 In Scope

| 项 | 内容 |
|----|------|
| REQ-PINV-1 | `diff.md` 双向集合相等（140 / 21，两个方向都 set-equal） |
| REQ-PINV-2 | 140 条 MOD 独有逐项归类（124 fight + 16 非 fight） |
| REQ-PINV-3 | 21 条基线独有逐项归类（存档槽 + 模板 + 死文件） |
| REQ-PINV-4 | 16 条非 fight 的内容溯源（15 字节一致 + 1 构建生成） |
| REQ-PINV-5 | 154 个 fight 的四象限分解（同名同容 / 同名异容 / MOD 独有 / 零字节） |
| REQ-PINV-6 | 零字节 fight 的**被清零**性质（非「新增空文件」） |
| REQ-PINV-7 | `ranger.str` 为构建生成的证明（源中不存在） |
| REQ-PINV-8 | 21 条基线独有的三类归属（存档槽 / 模板改道 / 真死文件） |
| REQ-PINV-9 | 产出 `reports/pineapple-verify.md` |
| REQ-PINV-10 | 8 道门禁复跑 |

## 3 Out of Scope

| 项 | 理由 |
|----|------|
| 修改任何构建产物 | 只审计，不修复；差异均已判定为正当 |
| 修改 `game/tools/**` | 本 change 未发现工具缺陷（6 个历史缺陷 A–F 均未复现） |
| 修复 `CC.Effect` 越界 | 归 `allmods-effect-table` spike（四禁改路径） |
| 修复 `not_in_product` 语义 | 独立 change（影响 20 MOD 审计口径） |
| `icon.png` 改判 `LEGACY` | 独立 change（影响 20 MOD 分类计数） |
| Slice 13（books） | 下一 slice |

---

## 4 关键风险

| 风险 | 表现 | 缓解 |
|------|------|------|
| 只比数量不比集合 | `140 vs 140` 就判通过，但集合可能不等 | REQ-PINV-1 强制双向 set-equal，用 Python `set` 比较 |
| 把「同名不同内容」误判为缺陷 | MOD 本就该改贴图 | REQ-PINV-5 四象限分解，逐类给理由 |
| 把「零字节」当成「新增空文件」 | pineapple 的零字节是**把基线文件清零**，性质不同 | REQ-PINV-6 单独验证：115 个零字节中 76 个与基线同名 |
| 把 `ranger.str` 当源文件产物 | 源 `resource/` 中无此文件 | REQ-PINV-7 显式证明源中不存在 |
| 把 `allsinbk.grp` 与 RiverLake 情况混淆 | Dragon 是「未引用」，RiverLake 是「引用但内容不用」，pineapple 是「基线有 MOD 无」 | REQ-PINV-8 三分类，不合并 |

---

## 5 交付物

| 文件 | 内容 |
|------|------|
| `proposal.md` | 本文件 |
| `design.md` | ADR-PINV-001..005 + Negative Constraints |
| `specs/allmods-pineapple-verification/spec.md` | REQ-PINV-1..10 的 Given/When/Then |
| `tasks.md` | 可机器验证的 DoD |
| `verification.md` | 逐条实测证据 |
| `reports/pineapple-verify.md` | 面向人读的差异审计报告 |
