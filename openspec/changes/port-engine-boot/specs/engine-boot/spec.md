# engine-boot Delta

## ADDED Requirements

### Requirement: REQ-BOOT-001：启动必须是引擎契约

系统 SHALL 提供一个引擎无关的启动入口，使得「写一个新引擎」不需要阅读
`game/main.lua` 的实现细节。

#### Scenario: 新引擎只需实现一个启动契约

- **GIVEN** 一个只实现了 `engine_api.lua` 全部函数的引擎
- **WHEN** 宿主调用 `EngineAPI.app.install({})`
- **THEN** framework SHALL 完成配置加载、全局初始化、require 别名注册、
  事件桥接器初始化、游戏逻辑加载、游戏适配器初始化
- **AND** 返回值 SHALL 是 boolean（失败不抛错，已记日志）

#### Scenario: 最小宿主（无任何能力）

- **GIVEN** 宿主不提供 `quit` / `onError` / `requestFullscreen` 任一钩子
- **WHEN** 调用 `EngineAPI.app.install(nil)`
- **THEN** 系统 SHALL 用降级实现替代（不抛错）
- **AND** `app.requestQuit()` SHALL 返回 false（而不是崩）

### Requirement: REQ-BOOT-002：装配顺序不可变

`framework/boot.lua` 的 `Boot.install` SHALL 按以下顺序执行，因为每一步
都依赖前一步的产物：

1. `require "framework.config"` → 提供 `CONFIG`
2. `require "framework.lib_Byte"` 并设全局 `Byte`
3. `require "framework.require_aliases"` → 裸名 require 可用
4. `EngineAPI.init()` → 引擎自身初始化
5. `EventBridge.getInstance():init()` → 状态机 / 输入 / 调度器 / 对话框
6. `require(CONFIG.ScriptPath .. "jymain")` → 加载游戏逻辑（内部得到 `CC`）
7. `JYMainAdapter.init()` → 起启动菜单协程

#### Scenario: 顺序被破坏时会失败

- **GIVEN** `require_aliases` 被排到 `jymain` 之后
- **WHEN** `Boot.install` 执行到第 6 步
- **THEN** `require "lib_file"` SHALL 失败（`module 'lib_file' not found`）
- **AND** `Boot.install` SHALL 返回 false 并记日志

### Requirement: REQ-BOOT-003：每帧更新顺序固定

`Boot.update(dt)` SHALL 按 `JYMainAdapter.update` → `EventBridge:update` →
`MenuAsync.update` 的顺序调用。

#### Scenario: dt 单位

- **GIVEN** 宿主传入 dt
- **WHEN** dt 是秒（LÖVE / Godot / Unreal 一致）
- **THEN** 游戏逻辑 SHALL 按秒解释
- **AND** `nil` / 非数字 dt SHALL 被当作 0（不抛错）

### Requirement: REQ-BOOT-004：绘制边界必须成对且异常安全

系统 SHALL 提供 `render.beginFrame()` / `render.endFrame()` 成对契约。

#### Scenario: 绘制中途出错

- **GIVEN** `Boot.draw()` 内部的绘制抛错
- **WHEN** 异常向上传播
- **THEN** `endFrame()` SHALL 仍然被调用（否则引擎绘制状态跨帧泄漏）
- **AND** 错误 SHALL NOT 被静默吞掉：若宿主提供 `runtime.onError`，
  交给它处理；否则重新抛出

#### Scenario: 在帧回调外绘制

- **GIVEN** 宿主（如 Godot）在 `_draw()` 之外调用 `render.text`
- **WHEN** 引擎实现按立即模式语义处理
- **THEN** 绘制 SHALL 静默无效（Godot 的 `draw_string` 行为）
- **AND** 契约注释 SHALL 明确警告这一行为，使宿主知道必须包在 `_draw()` 内

### Requirement: REQ-BOOT-005：裸名 require 别名的唯一来源

`framework/require_aliases.lua` SHALL 是 5 个裸名别名
（`lib_file` / `script_loader` / `coroutine_scheduler` / `war_async` /
`event_executor`）的唯一注册点。

#### Scenario: 引擎不再各自维护

- **GIVEN** 4 个引擎实现（LÖVE / MUD / Web / 测试桩）
- **WHEN** 任一引擎被加载
- **THEN** 它 SHALL `require("framework.require_aliases")`
- **AND** SHALL NOT 自己维护一份别名表

#### Scenario: 幂等

- **GIVEN** 某个别名已被注册（`package.preload["lib_file"]` 存在）
- **WHEN** 再次 `install()`
- **THEN** 已有条目 SHALL NOT 被覆盖

### Requirement: REQ-BOOT-006：主路径不得依赖被沙箱禁用的 stdlib

framework 的运行时路径（不含 `fs_compat.lua` 这类「仅测试/工具」模块）
SHALL NOT 在「EngineAPI 能力可用时」仍走 `io.*` / `os.clock` 主路径。

#### Scenario: 沙箱环境（Godot / Unreal 的 Lua VM 禁 io）

- **GIVEN** 宿主环境里 `io` 为 nil
- **WHEN** framework 需要读一个 MOD ini 文件
- **THEN** SHALL 走 `EngineAPI.file.read`
- **AND** SHALL NOT 因 `io == nil` 而崩

#### Scenario: 纯 Lua 测试环境（无 EngineAPI.file）

- **GIVEN** 一个只有 `io.open` 的纯 Lua 环境
- **WHEN** 需要读文件
- **THEN** SHALL 回退到 `io.open`（兜底必须保留）
