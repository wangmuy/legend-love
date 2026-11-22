# Script Decoupling

## ADDED Requirements

### Requirement: REQ-PORT2-1 framework 不得调用 script 定义的全局

`game/framework/*.lua` SHALL NOT 出现对 `game/script/jymain.lua` 定义的
全局函数的直接调用，包括 `DrawString` / `Cls` / `ShowScreen` / `DrawBox` /
`DrawStrBox` / `DrawStrBoxYesNo` / `DrawStrBoxWaitKey` / `ShowMenu` /
`ShowMenu2` / `WaitKey` / `TalkEx` / `GetMyPic` / `AddMyCurrentPic` /
`SceneCanPass` / `PlayMIDI` / `PlayMPEG` / `FillColor` / `DrawRect`。

#### Scenario: framework 里零 script 全局调用

- **GIVEN** 本 change 完成
- **WHEN** 执行 `grep -rhoE '\b(DrawString|Cls|ShowScreen|...)\(' game/framework/*.lua`
- **THEN** 命中数 = 0

#### Scenario: 门禁拦住新增的全局调用

- **GIVEN** 有人新增 framework 代码并写了 `DrawString(...)`
- **WHEN** 运行 `gate_engine_contract.sh`
- **THEN** 门禁 FAIL 并指出文件与行号

### Requirement: REQ-PORT2-2 facade 只转发，不含逻辑

`framework/render_facade.lua` / `framework/flow_facade.lua` /
`framework/game_hooks.lua` 的每个函数 SHALL 是对 `EngineAPI.*`
或既有 framework 模块的直接转发，SHALL NOT 包含业务逻辑、
SHALL NOT 读写 `JY` / `WAR` / `CC` 的游戏状态。

#### Scenario: facade 里无游戏状态访问

- **GIVEN** 三个 facade 文件
- **WHEN** 执行 `grep -c 'JY\.\|WAR\.' game/framework/render_facade.lua`
- **THEN** 命中数 = 0

#### Scenario: facade 是纯转发

- **GIVEN** `RenderFacade.text(x, y, str, color, size)`
- **WHEN** 调用它并注入一个记录参数的 `EngineAPI.render.text` 桩
- **THEN** 桩收到的参数与调用方传入的**完全一致**（无变换、无默认值改写）

### Requirement: REQ-PORT2-3 script 层行为零变化

`game/script/jymain.lua` 的 8 个全局函数 SHALL 保持签名不变、行为不变。
script 层 1000+ 处调用点 SHALL 零改动。

#### Scenario: script 层调用点零改动

- **GIVEN** 本 change 完成
- **WHEN** 检查 `game/script/` 的 git diff
- **THEN** 只有 `jymain.lua` 的 8 个全局函数体发生变化（改薄包装），
  其余 script 文件零改动

#### Scenario: 全部既有测试零回归

- **GIVEN** 前置 change 完成后的基线
- **WHEN** 四版本全量测试
- **THEN** 失败数 = 0，断言数只增不减

### Requirement: REQ-PORT2-4 游戏逻辑回调走注入而非硬依赖

`GetMyPic` / `AddMyCurrentPic` / `SceneCanPass` 属于游戏逻辑，
framework SHALL NOT 硬依赖它们。SHALL 改为注入式：
由 `jymain_adapter` 在启动时把函数注册到 `framework/game_hooks.lua`，
framework 通过 hooks 调用。

#### Scenario: framework 里零游戏逻辑调用

- **GIVEN** 本 change 完成
- **WHEN** 执行 `grep -rhoE '\b(GetMyPic|AddMyCurrentPic|SceneCanPass)\(' game/framework/*.lua`
- **THEN** 命中数 = 0

#### Scenario: 未注入 hooks 时不崩

- **GIVEN** hooks 尚未注册（单元测试环境）
- **WHEN** framework 调 `GameHooks.getMyPic()`
- **THEN** 返回 nil 或哨兵值，SHALL NOT 抛错

### Requirement: REQ-PORT2-5 零回归

本 change SHALL NOT 引入任何既有功能的回归。

#### Scenario: 四版本全量测试零失败

- **WHEN** 在 Lua 5.1 / 5.3 / 5.4 / 5.5 上跑全量测试
- **THEN** 失败数 = 0

#### Scenario: 实机冒烟

- **WHEN** 实机走一遍菜单 / 对话 / 地图 / 战斗 / 商店 / 存档
- **THEN** 画面与操作与改动前一致
