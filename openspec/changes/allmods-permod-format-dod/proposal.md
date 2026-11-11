---
status: done
created: 2026-10-29
---
# Proposal: allmods-permod-format-dod — 5 个 MOD 补齐逐 MOD 字段/格式 DoD

## Why

`allmods-slice0c-format-spec` 提供了**全局**字段级验证工具
（`format_spec.lua`，实测 `formats=14 checked=6838 gaps=0`），
但**逐 MOD** 的 change 文档中，只有 14/19 个 MOD 引用了它。

实测（`grep -liE "format_spec|字段级|格式族|idx_grp|save_grid|bare_idx"`）：

| MOD | 提及格式字段的文档数 | 结构 |
|-----|---------------------|------|
| books / dragon / dream / godsdevils / heavensword / lostbook / lyff / pig / ptt / riverlake / stronger / sweeOan / loving / pineapple | 4 ~ 7 | activate + verify（有 `design.md` + `specs/`） |
| **awaken** | **0** | reverse / fix / test / dod |
| **bookcalamity** | **0** | reverse / fix / test / dod |
| **pig3dos** | **0** | reverse / fix / test / dod |
| **zheng** | **0** | reverse / fix / test / dod |
| **mingdong** | **0** | activate / verify（**唯一有 activate 却无格式 DoD 的**） |

这 5 个 MOD 走的是**早期 reverse/fix/test/dod 四段式**（`change-manifest.md` 已声明
且全部 `[x] Done`），当时 `format_spec.lua` 尚未成形，因此**没有任何
「本 MOD 的每个字段/格式都被验证」的 DoD 断言**。

**它们的功能是通的**（实测 `format_spec --mod <m>` 全部 `gaps=0`），
缺的是**可追溯的、逐 MOD 的 DoD 记录**——即「这个 MOD 通过」这件事
没有留痕于该 MOD 自己的 change 里。

## What Changes

为这 5 个 MOD 各新增一个 `format-dod` 子 change，内容一致：

1. 该 MOD 的**逐格式实测表**（每个格式族 × checked 数 × gaps）
2. 该 MOD 特有的**格式异常记录**（若有）
3. 与 `allmods-slice0c-format-spec` 的 REQ-FMT-1~7 追溯
4. 该 MOD 在 20 MOD 中的**横向对照**（避免只报自身数字）

## In Scope

- `openspec/changes/allmods-{awaken,bookcalamity,mingdong,pig3dos,zheng}-format-dod/**`（新增）
- 各 MOD slice manifest 的 `## Change Assignments` 追加一行
- `openspec/epics/2026-10-allmods-compat/{TODO,epic}.md` 状态更新

## Out of Scope

- 不改任何 `game/**` 代码（功能已通过，本 change 只补文档与 DoD 留痕）
- 不改 `reference/allmods/**`
- 不改其余 14 个 MOD 的既有文档

## 跟踪 ID

| ID | 需求 |
|----|------|
| [REQ-PFD-1] | 5 个 MOD 各产出逐格式实测表 |
| [REQ-PFD-2] | 每个 MOD 的 `gaps=0` 有可复现命令 + 输出 |
| [REQ-PFD-3] | 与 slice0c 的 REQ-FMT-* 建立追溯 |
| [REQ-PFD-4] | 每个 MOD 有 20-MOD 横向对照，禁止只报自身数字 |

## 实测前提（本 proposal 的依据）

```
$ for m in awaken BookCalamity mingdong pig3dos zheng; do
    lua tools/format_spec.lua --mod $m | tail -1
  done
awaken:       formats=13 checked=342 gaps=0
BookCalamity: formats=13 checked=589 gaps=0
mingdong:     formats=13 checked=831 gaps=0
pig3dos:      formats=14 checked=328 gaps=0
zheng:        formats=13 checked=197 gaps=0
```

`pig3dos` 是唯一 `formats=14`（它有全部 save 槽），其余 `formats=13`。
