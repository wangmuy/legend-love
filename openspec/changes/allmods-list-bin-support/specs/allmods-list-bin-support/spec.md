---
status: done
created: 2026-10-29
---
# Spec: allmods-list-bin-support

## [REQ-LBIN-1] `list/*.bin` 进产物 `data/`

**背景**：实测 `game/mods/pascal/data/list/` 为空，源侧有 6 个文件。
`effect.bin` 与 `match.bin` 有引擎消费方（硬编码替代），应进产物。

### Scenario: pascal 构建后 effect.bin 在产物中
- **Given** 源侧 `reference/allmods/kys-pascal/list/effect.bin`（128 字节）
- **When** 执行 `lua tools/mod_build.lua kys-pascal`
- **Then** `game/mods/pascal/data/effect.bin` 存在
- **And** 其 md5 与源侧**逐字节相同**

### Scenario: 无消费方的 bin 不进产物
- **Given** `list/leave.bin` 与 `list/levelup.bin` 在引擎中零引用
- **When** 执行 `lua tools/mod_build.lua kys-pascal`
- **Then** `game/mods/pascal/data/leave.bin` **不存在**
- **And** `game/mods/pascal/data/levelup.bin` **不存在**

### Scenario: 20 个 MOD 全部一致
- **Given** 20 个源侧 MOD 都有 `list/effect.bin`
- **When** 执行 `lua tools/mod_build.lua --all`
- **Then** 产物 `data/effect.bin` 数量 = **20**
- **And** 逐字节比对 20/20 全部相同

## [REQ-LBIN-2] `effect.bin` 运行时惰性装载

**背景**：`CC.Effect`（`jyconst.lua:439`）硬编码 53 项，而 `effect.bin` 有 64~200 项。
`jyconst.lua` 是禁改路径，故采用「读入后覆盖」而非「改字面量」。

### Scenario: 有 effect.bin 时按 MOD 生效
- **Given** 产物 `game/mods/pascal/data/effect.bin`（64 项）
- **When** 启动游戏（pascal 激活）
- **Then** `CC.Effect` 项数为 **64**（非 53）
- **And** `CC.Effect[1..52]` 与硬编码值**完全相同**（前 52 项不回归）

### Scenario: 无 effect.bin 时保留硬编码兜底
- **Given** 产物中**不存在** `data/effect.bin`
- **When** 启动游戏
- **Then** `CC.Effect` 项数为 **53**（`jyconst.lua` 原值）
- **And** 行为与改动前**完全一致**

### Scenario: 不修改禁改文件
- **Given** `jyconst.lua` 是禁改路径
- **When** 完成本 change 全部改动
- **Then** `git diff game/script/jyconst.lua` 中 `CC.*=` 新增行数 = **0**

## [REQ-LBIN-3] `.bin` 字段级记录验证

**背景**：`format_spec.lua` 的 `bin_table` 原按「4 字节单元 + tail」验证，
但 `.bin` 实为定长 **uint16** 数组（`effect.bin` 128B = 64 项）。

### Scenario: 偶数字节完全覆盖
- **Given** `effect.bin` 128 字节
- **When** 执行记录级验证
- **Then** 记录数 = **64**
- **And** `gaps=0`、`tail=0`

### Scenario: 奇数字节必须报缺口
- **Given** 构造 3 字节的假 `.bin`
- **When** 执行记录级验证
- **Then** `ok=false`
- **And** 报出 `tail=1`（不静默吞掉）

## [REQ-LBIN-4] `mod_audit` 中 `list/*.bin` 不再是 `PENDING`

**背景**：`PENDING`（needed=nil）语义是「未判定」，对穷举审计体系不可接受。

### Scenario: 有消费方的标 REQUIRED
- **Given** `list/effect.bin` 与 `list/match.bin` 有硬编码消费方
- **When** 执行 `lua tools/mod_audit.lua --all --evidence`
- **Then** 这 40 条记录 `category=REQUIRED`
- **And** `in_product=true`

### Scenario: 无消费方的标 LEGACY 且必须有证据
- **Given** `list/leave.bin`、`list/levelup.bin`、`list/*.txt`
- **When** 执行审计
- **Then** 这 42 条记录 `category=LEGACY`
- **And** 每条 `evidence` 非空，`kind=code`，指向「引擎零引用」的 grep 位置

### Scenario: PENDING 只剩音频类
- **Given** 本 change 完成后
- **When** 执行 `lua tools/mod_audit.lua --all --evidence`
- **Then** `PENDING` = **581**（原 663）
- **And** 581 条全部为 `.mid`/`.mp3`/`.sf2`
- **And** `.bin` 残留 = **0**

## [REQ-LBIN-5] 零回归

### Scenario: 未激活 MOD 行为不变
- **Given** 不指定 MOD（基线 pascal）
- **When** 执行全量测试
- **Then** `lua tests/test_runner.lua` 失败数 = **0**
- **And** `mod_build --verify-pascal` = PASS

### Scenario: 断言语义正确（负向对照）
- **Given** 装载器与验证器都声称「通过」
- **When** 注入病态输入（短文件 / 缺失文件 / 奇数字节 / 错误条目数）
- **Then** 每个病态输入都被判为失败
- **And** 结果记入 `verification.md`，证明断言**有鉴别力**

## 非功能约束

| 约束 | 判据 |
|------|------|
| 禁改路径 | `engine-love2d/`、`engine-mud/`、`jyconst.lua` 常量、`reference/allmods/` 改动数 = 0 |
| 幂等 | 连续两次全量构建，`diff -rq` 为空 |
| 可审计 | 每个 `LEGACY` 判定都有可复现证据 |
