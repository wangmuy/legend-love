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

### Requirement: REQ-PORT1-9 编解码归 framework，引擎只上传字节

RLE 与调色板解码 SHALL 住在 framework（`framework/sprite_decoder.lua`），
SHALL NOT 住在引擎实现。引擎 SHALL 只实现「把 RGBA 字节串上传成纹理」。

`rgbaBytes` 的字节顺序 SHALL 一律为 RGBA（R,G,B,A 依次）。
若引擎原生格式不同（如 Unreal 的 `PF_B8G8R8A8` 是 BGRA），
SHALL 在引擎实现内部做一次 swizzle，调用方无需感知。

#### Scenario: sprite_decoder 零引擎依赖

- **GIVEN** `framework/sprite_decoder.lua`
- **WHEN** 执行 `grep -c 'love\.' framework/sprite_decoder.lua`
- **THEN** 命中数 = 0
- **AND** `grep -c 'require("engine' framework/sprite_decoder.lua` = 0

#### Scenario: 解码结果带锚点

- **GIVEN** 一个 RLE 帧，帧头为 `w=15, h=39, xoff=5, yoff=44`
- **WHEN** 调 `SpriteDecoder.decodeRLE(grpBytes, a, b)`
- **THEN** 返回 `{ w=15, h=39, xoff=5, yoff=44, rgba=<15*39*4 字节> }`

#### Scenario: RGBA 字节顺序可验证

- **GIVEN** 一个 1×1 的 RLE 帧，调色板索引指向纯红 `(255,0,0)`
- **WHEN** 解码并检查 `rgba` 的前 4 字节
- **THEN** 依次为 `255, 0, 0, 255`（R,G,B,A）

#### Scenario: Unreal 的 BGRA 差异在引擎内消化

- **GIVEN** 契约要求 RGBA 顺序
- **WHEN** 某引擎原生格式是 BGRA
- **THEN** 该引擎的 `createFromRGBA` 实现内部完成 swizzle，
  framework 传入的字节不变

### Requirement: REQ-PORT1-10 多格式支持（格式标签 + 两条路径）

资产加载 SHALL 支持至少两种编解码路径，由格式标签分发：

- **可纯 Lua 解码的格式**（RLE）→ framework 解码 → `sprite.createFromRGBA`
- **需外部压缩库的格式**（PNG/JPG/WebP）→ 引擎解码 → `sprite.createFromEncoded`

格式嗅探 SHALL 基于字节签名（读前 8 字节），SHALL NOT 依赖文件扩展名。

#### Scenario: PNG 帧走引擎解码路径

- **GIVEN** 一个 `.grp` 容器内的 PNG 帧（实测 `hdgrp.grp` slot 60/112 是合法 PNG：
  100×102 RGBA / 100×93 RGBA）
- **WHEN** 加载该帧
- **THEN** framework 嗅探出格式为 `"png"`，调 `sprite.createFromEncoded(bytes, "png")`

#### Scenario: 混合容器可加载

- **GIVEN** 同一个 `.grp` 里既有 RLE 帧又有 PNG 帧（实测存在）
- **WHEN** 分别加载两种帧
- **THEN** 两条路径都成功，且各自返回正确的 `w/h/xoff/yoff`

#### Scenario: 扩展新格式不需要改引擎

- **GIVEN** 将来要支持 WebP
- **WHEN** 在 framework 的嗅探表里加 WebP 签名，走 `createFromEncoded`
- **THEN** 引擎实现零改动

#### Scenario: 不按扩展名判断格式

- **GIVEN** 一个命名为 `foo.png` 的 RLE 字节段
- **WHEN** 加载它
- **THEN** 按字节签名判定为 RLE，走 framework 解码路径

### Requirement: REQ-PORT1-11 PNG 路径的锚点不再是零

历史缺陷：`lib_love.lua` 的 PNG 分支把 `cache.xoff/yoff` 硬置为 0，
而 RLE 分支保留真实锚点 —— 同一容器内两种格式的锚点语义不一致。

修复后 SHALL：
- packed + RLE → 用帧头的 `xoff/yoff`
- packed + PNG → 无自带锚点，SHALL 按**用途**取值：
  - 头像/立绘（`hdgrp`）→ `xoff = w/2, yoff = h/2`（**中心锚定**）
  - 地图/战斗精灵 → `xoff = w/2, yoff = h`（脚底中心）
  - 未知用途 → `xoff = w/2, yoff = h`（保守默认）
- loose 单文件 → 由调用方显式传 `opts.xoff / opts.yoff`

#### Scenario: 头像 PNG 帧用中心锚点

- **GIVEN** `hdgrp.grp` slot 60 的头像 PNG 帧（100×102）
  （`hdgrp` = `CC.HeadPicFile`，由 `PicLoadFile(..., 1)` 装载为 archive 1）
- **WHEN** 加载后查 `sprite.getMeta(handle)`
- **THEN** `xoff = 50, yoff = 51`（**中心锚定**，不是 0,0 也不是 50,102）

#### Scenario: 锚点改动不影响现有画面

- **GIVEN** 现有头像绘制路径用 `flag=1`（`PicLoadCache(1, ..., 1)` = 忽略 xoff/yoff），
  居中由 `headx = (width/2 - headw)/2` 自己算
- **WHEN** 加载头像并绘制
- **THEN** 画面与改动前完全一致（锚点只影响未来按锚点绘制的调用方）

#### Scenario: RLE 帧锚点不变

- **GIVEN** 主角行走帧（`w=15, h=39, xoff=5, yoff=44`）
- **WHEN** 加载后查 `sprite.getMeta(handle)`
- **THEN** `xoff = 5, yoff = 44`（与改动前完全一致，零回归）

### Requirement: REQ-PORT1-8 零回归

本 change SHALL NOT 引入任何既有功能的回归。

#### Scenario: 四版本全量测试零失败

- **Given** 本 change 完成，基线为 3310 断言（Lua 5.1）
- **When** 在 Lua 5.1 / 5.3 / 5.4 / 5.5 上跑全量测试
- **Then** 失败数 = 0，断言数 ≥ 3310

#### Scenario: 语法检查零失败

- **When** 对全部改动文件执行 `luac5.1 -p` 与 `luac55 -p`
- **Then** 零失败
