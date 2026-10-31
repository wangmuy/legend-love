---
parent_epic: 2026-10-allmods-compat
status: done
---
# Change Manifest: allmods-slice0c — 资源覆盖穷举审计（文件级 + 字段级）

## Change Assignments

### Change: allmods-slice0c-file-inventory

- **Repository**: this repo
- **Scope**: infra（审计工具 + 测试）
- **Responsibility**: 文件级穷举归类（Contract A）。新增 `tools/mod_audit.lua`：遍历 20 MOD 的全部源文件（11220 个），逐个归类为 `{needed, category, content_type, evidence, in_product}`，输出 `audit.json`（机器可读）与 `audit.md`（人类可读）。强制 `Σ(类别) == 11220` 且 `未归类 == 0`。定义类别枚举与判据表。
- **Depends On**: none
- **Status**: [x] Implemented & verified (verification.md)

### Change: allmods-slice0c-format-spec

- **Repository**: this repo
- **Scope**: infra（格式规格 + 测试）
- **Responsibility**: 字段级格式覆盖（Contract B）。新增 `tools/format_spec.lua`：为每种二进制格式定义字段表（`{name, offset, size, type, consumer, needed}`），提供 `verifyCoverage(path, spec)` 断言 `Σ(size) == 文件大小` 且无重叠无缺口。覆盖 `.grp/.idx`（RLE 图片、offset 表）、`sdx/smp/wdx/wmp`、`.002`、`.sta`、`.col`、`list/*.bin`、`kysmod.ini`、`save/rN.*`、`save/allsin.*`、`save/alldef.*`。
- **Depends On**: allmods-slice0c-file-inventory（文件清单决定需要哪些格式规格）
- **Status**: [x] Implemented & verified (verification.md)

### Change: allmods-slice0c-unneeded-evidence

- **Repository**: this repo
- **Scope**: infra（证据收集 + 文档 + 测试）
- **Responsibility**: 「不需要」的显式列出与证据（Contract C）。对每个 `needed=false` 的文件/字段，收集可复现证据：引擎代码 grep 0 引用的位置、`kys.exe` strings 0 引用、offset 表尾部 `tail` 字节数、`IGNORE_DIRS` 常量位置。产出 `MOD_RESOURCE_AUDIT.md` 权威归类表；新增测试断言每个 `needed=false` 都有非空 `evidence`。
- **Depends On**: allmods-slice0c-file-inventory, allmods-slice0c-format-spec
- **Status**: [x] Implemented & verified (verification.md)

## Shared Contract Stubs

### Contract A: 文件级归类数据结构（allmods-slice0c-file-inventory 拥有）

```lua
-- game/tools/mod_audit.lua 导出的归类记录结构
-- 每个源文件恰好一条记录；Σ(records) == 源文件总数
Record = {
  mod       = "mingdong",           -- MOD slug
  path      = "head/hdgrp001.png",  -- 相对 MOD 根目录
  size      = 12345,                -- 字节数
  topdir    = "head",               -- 顶层目录
  ext       = ".png",
  needed    = false,                -- 引擎是否需要此文件
  category  = "EDITOR_DUMP",        -- 见下枚举
  content_type = "png_image",       -- 内容类型
  in_product = false,               -- 是否进入构建产物
  evidence  = {                     -- 非空；needed=false 时必填
    { kind = "code",   ref = "tools/mod_build.lua:IGNORE_DIRS" },
    { kind = "reason", text = "UPedit 头像导出，引擎读 hdgrp.grp" },
  },
}

-- 类别枚举（穷举，无 "OTHER" 兜底——未归类必须报错）
CATEGORY = {
  "REQUIRED",            -- 引擎必需，已进产物
  "REQUIRED_CONVERTED",  -- 引擎必需，构建期转换后进产物（改名/转码/重排）
  "DESIGNED_FALLBACK",   -- 引擎可选，源不提供是预期
  "DEAD_PARAM",          -- 引擎形参从未引用
  "LEGACY",              -- C 引擎/编辑器遗留，Lua 引擎不读
  "DEAD_FILE",           -- 引擎命名规则无法生成
  "EDITOR_DUMP",         -- 编辑器导出副产物
  "BUILD_INPUT",         -- 构建器消费但引擎不读（如 kysmod.ini）
  "PLATFORM_ARTIFACT",   -- 平台运行时（dll/exe/bat/zip）
  "PENDING",             -- 待决策（需 spike）
}

-- 硬约束
# 1. Σ(#records by category) == 源文件总数
# 2. category 必须 ∈ CATEGORY（无兜底）
# 3. needed == false → evidence 非空
# 4. in_product == true → 必须在 game/mods/<mod>/ 下找到对应文件
```

#### Contract A 实测验证（文件级穷举）

| 硬约束 | 实测命令 | 实测结果 | 结论 |
|--------|----------|----------|------|
| `Σ(类别) == 11220` | `lua tools/mod_audit.lua --all --evidence` | `total=11220`，类别合计 9145+80+68+2+1220+30+12+663 = **11220** | ✅ |
| 未归类 == 0 | 同上 | `unclassified=0` | ✅ |
| 每个 `needed=false` 有 evidence | 同上 | `bad_evidence=0`，`checked=17 failed=0` | ✅ |
| 总数独立对照 | `find ../reference/allmods/kys-*/ -type f \| wc -l` | **11220**（与工具输出精确相等） | ✅ |

**Negative control（证明归类器不兜底）**：

```lua
CATEGORY 项数 = 10，含 OTHER/UNKNOWN/MISC/DEFAULT ? false false false false
A.classify({path="zzz/x.qqq"}) --> nil  (unclassified，不落兜底类)
A.classify({path="data/person.grp"}) --> nil  (产物路径非源路径，正确拒绝)
A.classify({path="resource/sdx"}) --> REQUIRED_CONVERTED needed=true
A.classify({path="head/1.png"})   --> EDITOR_DUMP needed=false
```

未使用的 2 个类别 `DESIGNED_FALLBACK` / `DEAD_PARAM` 是「源侧本就不提供」的
预期缺失，经 `M.ABSENT_EXPECTED`（3 条）+ `testAbsentExpectedDocuments` 表达，
不产生记录 ⇒ 计数 0 属正确语义，非漏判。

### Contract B: 字段级格式规格（allmods-slice0c-format-spec 拥有）

```lua
-- game/tools/format_spec.lua
-- 每个格式一条 spec；字段区间必须完整覆盖文件
Spec = {
  name = "hdgrp",
  kind = "idx_grp",              -- 格式族
  idx  = { file = "hdgrp.idx", field = { name="offsets", offset=0, size="*4",
                                          type="uint32[]", consumer="lib_love.LoadPic", needed=true } },
  grp  = { file = "hdgrp.grp",
           header = { name="header", offset=0, size=8, type="rle_header", needed=true },
           records = { name="rle_records", offset="offsets", size="*",
                       type="rle_rows", needed=true },
           tail   = { name="tail", offset="*", size=0, needed=false,
                      evidence={kind="offset_table", text="last offset == grp size"} } },
}

-- 覆盖校验（核心断言）
function M.verifyCoverage(path, spec)
  -- 返回 ok, gaps
  -- 要求：Σ(字段区间) == 文件大小；无重叠；无缺口
  -- 缺口 = 未被任何字段区间覆盖的 [start, end)
end

-- 硬约束
# 1. verifyCoverage 对 20 MOD × 每种格式 全部通过
# 2. 任何缺口 → 测试失败并列出 [start, end)
# 3. needed == false 的字段必须有 evidence
```

#### Contract B 实测验证（2026-10-28 复核 + 补全）

| 硬约束 | 实测命令 | 实测结果 | 结论 |
|--------|----------|----------|------|
| #1 20 MOD × 每格式全通过 | `lua tools/format_spec.lua --all` | `formats=14 checked=6826 gaps=0` | ✅ |
| #2 缺口必须被报告 | `lua tests/unit/test_format_spec.lua`（REQ-FMT-7 负例） | 6/6 病态输入均 `ok=false` | ✅ |
| #3 needed=false 需 evidence | `lua tools/mod_audit.lua --all --evidence` | `bad_evidence=0` | ✅ |

**Negative control（证明断言有鉴别力，不是空跑通过）**：

```lua
-- F.verifyIntervals(intervals, filesize)
{{0,40},{40,100}} @100 --> true            完好
{{0,40},{60,100}} @100 --> false gaps=1    中间缺口
{{0,80}}          @100 --> false gaps=1    尾部缺口
{{0,60},{40,100}} @100 --> false overlaps=1 重叠
{}                @100 --> false gaps=1    空表（零字段）
{{10,100}}        @100 --> false gaps=1    首部缺口
```

六种病态输入全部被抓 ⇒ 断言非空转。

> **勘误（2026-10-28）**：Contract B 初版只注册 `ranger`，`save_grid`
> （`allsin`/`alldef`）与 `save_slot`（`rN/sN/dN`）**未实现**，与
> proposal 格式族表声明的范围不符，导致 `save/` 的 451 个源文件中
> **411 个从未做字段级验证**。现已补注册（`formats=12→14`，
> `checked=6773→6826`，`gaps` 两侧均 0），复用既有 `verifyPair`
> （与 ranger 同构，零新解析器），详见
> `allmods-slice0c-format-spec/verification.md` §9。


### Contract C: 「不需要」的证据（allmods-slice0c-unneeded-evidence 拥有）

```
# 证据种类（kind 枚举）
code        -- 引擎代码中的具体位置（文件:符号），如 0 引用或 IGNORE_DIRS
strings     -- kys.exe strings 中的 0 引用
offset_table-- offset 表推导（如 last offset == grp size → tail=0）
format      -- 格式层面的证明（如 %03d 生成不出 "fight030_02"）
external    -- 外部工具依赖（如 .mid 需 MIDI→OGG 转换器）
manual      -- 人工判定（必须附可复现命令）

# 硬约束
# 1. 每个 needed=false 的记录 evidence 非空
# 2. 每条 evidence 必须可复现（code/strings/format 类附命令）
# 3. MOD_RESOURCE_AUDIT.md 的每行判定都能追溯到 audit.json
```

## Integration Test Plan

| 测试 | 断言 |
|------|------|
| `test_mod_audit.lua` | 11220 == Σ(归类)；未归类 == 0；每个 needed=false 有 evidence |
| `test_mod_audit.lua` | in_product==true 的记录都能在 `game/mods/` 找到 |
| `test_format_spec.lua` | 20 MOD × 每种格式 verifyCoverage 通过（无缺口） |
| `test_format_spec.lua` | 故意构造缺口 → verifyCoverage 必须报错（负例） |
| `test_mod_audit.lua` | 产物侧 `Σ(byte-exact)+Σ(converted) == 产物总数` |
| 全量回归 | `test_runner.lua` 全绿；`--verify-pascal` PASS；`--all` 0 failures |
