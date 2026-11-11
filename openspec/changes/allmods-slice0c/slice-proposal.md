---
status: done
parent_epic: 2026-10-allmods-compat
abandoned:
  reason: ""
  date: ""
  replaced_by: ""
---
# Slice Proposal: allmods-slice0c — 资源覆盖穷举审计（文件级 + 字段级）

## Fit-Level Context
本 slice 评估为 vertical-slice（可测试 MVP）。若实施中范围膨胀，通过 /opsx:explore 重新评估。

## Parent Epic
[2026-10-allmods-compat](../../../epics/2026-10-allmods-compat/epic.md)

## Slice Type
foundation（地基补漏）

## 背景：为什么需要 Slice 0c

Slice 0b 修复了 `sdx/smp` 命名错配与音效丢失。但**根因未除**：整个 DoD 体系是
**抽样驱动**——判定范围由"人写的比对目标"决定，而不是由"源文件全集"决定。

2026-10-19 实测（20 MOD 源文件全集）：

```
源文件总数           11220
  进产物（同名）      9165   (82%)
  进产物（转换名）      84   (0.7%)
  ──────────────────────────
  未进产物            1971   (18%)  ← 无任何 DoD 断言覆盖
```

未进产物的 1971 个文件分布：`head/` 713、`music/` 581、`item/` 400、`list/` 122、
`eft/` 105、`cc/` 4、dll/exe/草稿 46。其中**只有 8 类被审计报告"提到"**，
其余（如 `list/*.bin` 82 个、`save/*.zip`、`.sf2`）**从未被任何 artifact 提及**。

字节级更糟：全项目仅对 **`smap.grp` 一个文件**做过逐字节断言；
源侧"每个字节是否被引擎消费"完全没有概念。

`diff.md` 的设计本身就只比对 `data/` 目录（`vs game/data/`），
所以 `head/`、`item/`、`eft/`、`music/`、`cc/`、`list/`、dll 天生在盲区。

**这是 `sdx/smp` 漏判的同型问题**：只要判定表是人工挑的，就必然有未挑到的。

## User Story

系统可以对 20 个 MOD 的**每一个源文件**给出唯一归类（是否需要 / 属于什么内容 /
未进产物的原因），并给出**证据**（`UPedit.ini` 声明 / `kys.exe` strings / 引擎代码引用 / 构建日志）；
对每个二进制格式给出**无缺口的字段覆盖**（`Σ(字段字节数) == 文件大小`），
使"遗漏"从"人可能没想到"变成"机器必然发现"。

## In Scope

1. **文件级穷举归类（Contract A）** — 新增 `game/tools/mod_audit.lua`，对 20 MOD 的
   11220 个源文件逐个归类，输出机器可读清单（`audit.json`）与人类可读报告（`audit.md`）。
   强制约束：`Σ(各类别文件数) == 源文件总数`，且**「未归类」是一个显式的失败类别**。

2. **字段级格式覆盖（Contract B）** — 新增 `game/tools/format_spec.lua`，为每种二进制格式
   定义字段表（name/offset/size/type/consumer/needed），并提供
   `verifyCoverage(path, spec)` 断言 `Σ(字段区间) == 文件大小` 且区间**无重叠、无缺口**。

3. **不需要的字节/字段显式列出 + 证据（Contract C）** — 对每个格式标注哪些字段/尾部字节
   **引擎不消费**，并给出证据（引擎代码 grep 0 引用 / `kys.exe` strings 0 引用 /
   offset 表尾部 `tail` 字节数）。

4. **DoD 升级为穷举驱动** — 新增测试断言：
   - 文件级：`11220 == Σ(归类)`，未归类数 == 0
   - 字段级：20 MOD × 每种格式，覆盖完整（无缺口段）
   - 产物侧字节：`Σ(byte-exact) + Σ(converted) == 产物总数`（每个转换都要有规则记录）

## Out of Scope

- **真正修复** `head/`/`item/`/`eft/`/`music/`/`list/` 的功能（本 slice 只做**审计与归类**）。
  `music/*.mid` 转换仍是独立 spike（见 epic TODO）。
- **逐字节语义**（"这个字节是第几个像素"）—— 粒度定为**字段级**（用户已确认）。
- **非 MOD 相关**的格式（如 `chinese.ttf` 字体内部结构）。
- 修改 `reference/allmods/**`（只读）。
- 修改 `game/engine-love2d/**`、`game/engine-mud/**`。

## Acceptance Criteria

#### Scenario: 文件级穷举无遗漏
- **GIVEN** 20 个 MOD 共 11220 个源文件
- **WHEN** 运行 `lua tools/mod_audit.lua --all`
- **THEN** 输出 `Σ(各类别文件数) == 11220`，且 `未归类 == 0`；
  任一类别的文件在 `audit.json` 中都有 `{path, category, needed, content_type, evidence}`

#### Scenario: 未进产物必须有理由与证据
- **GIVEN** 1971 个源文件未进产物
- **WHEN** 查看 `audit.md`
- **THEN** 每个未进产物的文件（或文件组）都标注 `reason` 与 `evidence`
  （如 `IGNORE_DIRS=head` 的代码位置、`music` 格式不匹配的具体证据）

#### Scenario: 字段级覆盖无缺口
- **GIVEN** `format_spec.lua` 定义了某格式的字段表
- **WHEN** 运行 `verifyCoverage(实际文件, spec)`
- **THEN** `Σ(字段 size) == 文件 size`，且字段区间无重叠、无未覆盖缺口；
  不满足则报错并列出缺口 `[start, end)`

#### Scenario: 不需要的字段有证据
- **GIVEN** 某格式存在引擎不消费的字段/尾部字节
- **WHEN** 查看格式规格
- **THEN** 该字段标注 `needed=false` 并附 `evidence`（引擎代码 0 引用的位置、
  或 `kys.exe` strings 0 引用、或 offset 表 tail 字节数）

#### Scenario: 产物侧字节完整性
- **GIVEN** 20 MOD 的产物共 9003 个文件
- **WHEN** 运行审计
- **THEN** `Σ(byte-exact) + Σ(converted with rule) == 9003`，无未解释文件

#### Scenario: 原版零回归
- **GIVEN** 本 slice 只新增审计工具与测试
- **WHEN** 运行 `lua tests/test_runner.lua` 与 `lua tools/mod_build.lua --verify-pascal`
- **THEN** 全绿，行为与 Slice 0b 完成时完全一致

## Affected Domains

- **devops** — 新增 `tools/mod_audit.lua`、`tools/format_spec.lua`
- **tests** — 新增 `tests/unit/test_mod_audit.lua`、`tests/unit/test_format_spec.lua`
- **docs** — 新增 `MOD_RESOURCE_AUDIT.md`（权威资源归类表）；更新 `DATA_FILES.md`
- **framework** — 无（只读消费引擎代码做证据）
- **game-scripts** — 无
- **legacy-events** — 无

## 与 Slice 0b 的关系

Slice 0b 修复了**已知的 4 类问题**；Slice 0c 建立**发现未知问题的机制**。
0b 的产物是修复；0c 的产物是「穷举审计工具 + 缺口归零的证明」。

0c 完成后，Slice 2-18 的每个 MOD slice 可直接复用 `mod_audit.lua` 做本 MOD 的穷举验收。
