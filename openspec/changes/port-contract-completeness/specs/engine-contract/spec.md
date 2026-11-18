# Engine Contract Completeness

## ADDED Requirements

### Requirement: REQ-PORT1-1 引擎调用零绕过

`game/framework/*.lua` SHALL NOT 出现 `lib.*` 形式的引擎调用。
所有引擎操作 SHALL 通过 `EngineAPI.<module>.<function>`。

#### Scenario: framework 里无 lib.* 调用

- **Given** framework 的 24 个文件已完成本 change 的改写
- **When** 执行 `grep -rn 'lib\.' game/framework/*.lua`（排除注释行）
- **Then** 命中数为 0

#### Scenario: 未改写的文件会被门禁拦住

- **Given** 有人新增一个 framework 文件并写了 `lib.DrawMMap(...)`
- **When** 运行 `gate_engine_contract.sh`
- **Then** 门禁 FAIL 并指出文件与行号

### Requirement: REQ-PORT1-2 契约必须覆盖实际用法

每个新增契约函数的签名 SHALL 能覆盖 framework 现有的全部调用形式。
SHALL NOT 出现"契约为理想形态、实现却绕过它"的情况。

#### Scenario: dead contract 比例受控

- **Given** 本 change 完成后
- **When** 统计 EngineAPI 契约里从未被 framework/script 调用的函数
- **Then** 数量 < 10（基线 38）

#### Scenario: 每个新契约都有消费者

- **Given** 本 change 新增的 19 个契约函数
- **When** 检查每个函数的调用点
- **Then** 每个都至少有 1 个 framework 调用点（不是为完整性而写）

### Requirement: REQ-PORT1-3 四引擎实现齐全

`engine_api.lua` 声明的每个函数，SHALL 在 LÖVE / MUD / Web / 测试桩
4 个实现里都存在。

#### Scenario: 契约函数在四引擎都存在

- **Given** `engine_api.lua` 声明了 N 个函数
- **When** `test_engine_conformance` 遍历 4 个引擎实现
- **Then** 每个引擎的每个契约函数都非 nil

#### Scenario: 新增契约时遗漏某引擎会被拦住

- **Given** 有人给 `engine_api.lua` 加了 `render.getWidth`
- **When** 只给 LÖVE 与测试桩实现了，忘了 MUD 与 Web
- **Then** `test_engine_conformance` FAIL 并指出缺失的引擎

### Requirement: REQ-PORT1-4 跨引擎行为一致性

同一套行为断言 SHALL 在 MUD 与 Web 上**真实执行**；
对无对应概念的引擎，SHALL 断言其返回**哨兵值**且不抛错。

#### Scenario: MUD 引擎真实执行一致性断言

- **Given** MUD 引擎（无图形、无地图）
- **When** `test_engine_conformance` 在 MUD 上跑真实调用
- **Then** 所有断言 PASS，且 `render.getWidth()` 返回哨兵值（如 0）而非抛错

#### Scenario: 不允许用 skip 掩盖缺失

- **Given** 某引擎缺某能力
- **When** 一致性测试遇到该能力
- **Then** 断言其返回哨兵值而**不是** `skip`（skip 会让缺陷隐身）

### Requirement: REQ-PORT1-5 虚拟手柄必须真实激活

`JYMainAdapter.pollVirtualPad` 在 LÖVE 下 SHALL 能真实返回 true
并产出动作事件（此需求与 virtual-pad-wiring/spec.md 的 REQ-VP-1 互为细目与总则）。

#### Scenario: 注入触摸点后虚拟手柄产出动作

- **Given** `InputSettings.virtualPad = true`，屏幕 1024×768
- **When** 注入触摸点 `{id=1, x=<accept 按钮圆心>, y=<同上>}`
- **Then** `pollVirtualPad()` 返回 true
- **And** 动作队列里出现 `{action="ui.accept", source="touch"}`

#### Scenario: 关闭设置时不激活

- **Given** `InputSettings.virtualPad = false`
- **When** 注入同样的触摸点
- **Then** `pollVirtualPad()` 返回 false，动作队列为空

### Requirement: REQ-PORT1-6 缺失契约的影响可观测

`font.measureText` 缺失时 `TextBoxLayout` SHALL 走 em 估算（保留 fallback）；
有 `measureText` 时 SHALL 优先使用它。

#### Scenario: 有 measureText 时用真实度量

- **Given** 引擎实现了 `font.measureText`，返回 200
- **When** 调 `TextBoxLayout.textWidth("梅庄", 24)`
- **Then** 返回 200（而非 em 估算的 48）

#### Scenario: 无 measureText 时退回 em 估算

- **Given** 引擎未实现 `font.measureText`
- **When** 调 `TextBoxLayout.textWidth("梅庄", 24)`
- **Then** 返回 48（2 汉字 × 24）

### Requirement: REQ-PORT1-7 dead contract 决策留痕

38 个 dead contract 每个 SHALL 有明确处置，记录在 `decisions.md`。

#### Scenario: decisions.md 覆盖全部 38 项

- **Given** 本 change 完成后
- **When** 检查 `decisions.md`
- **Then** 38 个函数每个都有处置结论（保留 / 删除 / 降级）与理由

#### Scenario: 删除的函数有迁移说明

- **Given** `decisions.md` 判定某函数应删除
- **When** 阅读该条目
- **Then** 有明确的「删除理由」与「若有消费者该怎么办」

### Requirement: REQ-PORT1-8 零回归

本 change SHALL NOT 引入任何既有功能的回归。

#### Scenario: 四版本全量测试零失败

- **Given** 本 change 完成，基线为 3310 断言（Lua 5.1）
- **When** 在 Lua 5.1 / 5.3 / 5.4 / 5.5 上跑全量测试
- **Then** 失败数 = 0，断言数 ≥ 3310

#### Scenario: 语法检查零失败

- **When** 对全部改动文件执行 `luac5.1 -p` 与 `luac55 -p`
- **Then** 零失败
