# 宪法：硬性治理规则

## 核心原则

### 1. EngineAPI 抽象层 — 禁止绕过

`game/script/` 中的所有游戏逻辑必须通过 `EngineAPI.*` 或 `lib.*` 调用。在 `game/script/` 和 `game/framework/` 中禁止直接调用 `love.*` API，仅在 `game/engine-love2d/` 中允许实现层调用。

**检验**：`rg "love\." game/script/` 必须返回 0。`rg "love\." game/framework/` 必须返回 0。

### 2. 非阻塞主循环 — 禁止引入阻塞代码

所有游戏状态循环必须基于协程或事件驱动。`while true` 阻塞 `love.update()` / `love.draw()` 的循环禁止出现在游戏循环路径的任何位置（framework、scripts）。

**检验**：`rg "while true" game/framework/` 对阻塞模式必须返回 0（文档中标记的 yield 异步封装除外）。

### 3. 框架变更的测试覆盖 — 必须维护

对 `game/framework/` 下任何文件的变更必须包含或更新 `game/tests/unit/` 中的单元测试。测试运行器必须在合并前通过。

**检验**：`cd game && lua tests/test_runner.lua` 必须退出码为 0。

### 4. 禁止添加外部 Lua 依赖

所有 Lua 代码必须能在无 luarocks 包的情况下运行。禁止 busted、luacov、luaunit 或其他外部 Lua 库。零第三方依赖。

**检验**：`rg "require\s*\(?\s*['\"]" game/framework/ game/engine-love2d/` 不能匹配任何非标准库 Lua 模块。仅允许 `lib_*`、框架模块和 `love.*` 引擎模块。

### 5. 目录约定 — 必须使用 `game/` 作为根目录

所有游戏源码、资源和测试位于 `game/` 下。项目根目录禁止存在 `src/` 目录。构建输出位于 `builds/`。

**检验**：`test -d src` 必须返回非零（文件不存在）。

### 6. 游戏脚本冻结 — 引擎不得为自身修改 `game/script/`

`game/script/` 下的游戏脚本（`jymain.lua`、`jyconst.lua`、`jymodify.lua`、`oldevent/`、`newevent/`）是纯游戏逻辑，必须对所有引擎保持中立。任何引擎实现（love2d、web/mud 或后续任何引擎）都**不得为了适配引擎本身而修改游戏脚本**。

仅允许以下两种例外情况修改游戏脚本：

1. **脚本自身存在 bug** — 修复脚本自身的逻辑错误，与引擎无关。
2. **等价改写且是通用修改** — 改写前后对所有引擎行为完全等价（语义不变），且该修改对所有引擎通用（不引入任何引擎特有依赖或分支）。

不满足上述任一条件的引擎适配需求，必须通过引擎实现层（`engine-*/`）或 `EngineAPI`/`lib.*` 抽象层解决，而不是改脚本。

**检验**：任何涉及 `game/script/` 的变更，必须能指明其属于"修复脚本自身 bug"或"等价的通用修改"之一；否则驳回，改在引擎层实现。

## 禁止模式

| 模式 | 禁止原因 | 替代方案 |
|------|----------|----------|
| `while true` + `WaitKey()` | 阻塞 Love2D 事件循环 | `InputAsync.WaitKeyCoroutine()` |
| `DrawStrBoxWaitKey()` | 同步阻塞对话框 | `AsyncMessageBox.ShowMessageCoroutine()` |
| `DrawStrBoxYesNo()` | 同步阻塞选择框 | `AsyncMessageBox.ShowYesNoCoroutine()` |
| `love.filesystem.*` in script/ | 破坏引擎可移植性 | `EngineAPI.file.*` 或 `lib.*` |
| 直接调用 `love.timer.getTime()` | 不可测试的硬编码时间源 | 注入 `self.timeSource` |
| 全局 `lib.Debug()` | 不可测试的硬编码日志 | 模块级 `self:_debug()` |

## 必需模式 — 必须遵循

| 模式 | 适用位置 | 理由 |
|------|----------|------|
| 单例 `getInstance():reset()` | 所有带状态框架模块 | 测试隔离 |
| 协程函数前向声明 | `war_async.lua`（local 函数名） | 避免声明顺序导致的运行时错误 |
| 可配置值使用 `CONFIG.*` | `framework/config.lua` | 单一事实来源 |
| UTF-8 编码 | 所有 `.lua` 和 `.md` 文件 | 项目标准 |

## 技术栈约束

| 约束 | 详情 |
|------|------|
| Love2D 版本 | 11.5（冻结）— 不能使用 11.5 之后的 API |
| Lua 版本 | 5.1 — 不能使用 5.2/5.3 特性（goto、bit32 等） |
| 位运算 | 使用 `luabit.lua`（不能使用 Lua 5.3 的 `&`、`\|`） |
| 文件 I/O | 使用 `lib_file.lua`（封装 `love.filesystem`） |
| 归档格式 | 7z 用于 .love 打包 |