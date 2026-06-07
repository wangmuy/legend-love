# 标准：建议性编码规范

## 命名规范

| 作用域 | 约定 | 示例 |
|--------|------|------|
| 全局常量 | `UPPER_CASE` | `VK_ESCAPE`、`GAME_MMAP` |
| 配置项 | `CONFIG.*` 前缀 | `CONFIG.Debug`、`CONFIG.Width` |
| 游戏常量 | `CC.*` 前缀 | `CC.DefaultFont`、`CC.Person_S` |
| 游戏状态 | `JY.*` 前缀 | `JY.Status`、`JY.Person` |
| 公开函数 | `CamelCase`（首字母大写） | `WarMainCoroutine`、`ShowMenuCoroutine` |
| 局部函数 | `camelCase`（首字母小写） | `getInstance`、`waitForKey` |
| 私有方法 | `_前缀` 下划线 | `self:_debug()`、`self:_peekKeyInternal()` |
| 测试文件 | `test_<模块名>.lua` | `test_state_machine.lua` |
| 测试表 | `Test<模块名>` | `TestStateMachine` |
| 测试函数 | `test<功能描述>()` | `testWaitForKeyWithDisableInput()` |

## 风格

- **缩进**：4 个空格（不制表符）
- **行长度**：最多 120 字符
- **引号**：优先双引号（`"text"`），嵌入引号时用单引号
- **注释**：仅在不直观的逻辑处使用；新代码优先自我说明
- **分号**：可选 — 项目风格混合；新代码建议省略

## 模块结构（framework 模块）

每个框架模块应该遵循以下模式：

```lua
-- 前向声明（如果是协程函数）
local SomeCoroutine

-- 模块状态
local SomeModule = {}
local instance = nil

-- 构造函数 / 单例
function SomeModule.getInstance()
    if not instance then
        instance = setmetatable({}, {__index = SomeModule})
        instance:init()
    end
    return instance
end

-- 测试隔离重置
function SomeModule:reset()
    -- 清除所有模块级状态
end

-- 公开方法（CamelCase）
function SomeModule:DoSomething()
end

-- 私有方法（camelCase，_前缀）
function SomeModule:_internalHelper()
end

return SomeModule
```

## 测试风格

- 每个测试文件使用 `game/tests/test_helper.lua` 进行断言、Mock、Spy
- 每个测试函数首先调用 `setup()` 重置状态
- 测试应该隔离 — 测试间不共享可变状态
- 测试断言应该包含描述性消息字符串
- 测试框架模块前使用 `TestHelper.mockLove()`
- 使用 `TestHelper.mockGlobals()` 设置 CC/JY/WAR/lib Mock

## 协程约定

- `war_async.lua` 中必须使用前向声明声明所有协程函数
- 在 `war_async.lua` 中添加新协程函数：先将名称添加到前向声明
- 避免在 `war_async.lua` 中使用 `local function Fn()` — 使用 `Fn = function()` 语法
- 可 yield 的函数建议命名为 `<Name>Coroutine` 以便发现

## 错误处理

- 使用 `lib.Debug()` 输出调试信息（由 `CONFIG.Debug` 控制）
- 使用 `lib.JY_Error()` 或 `lib.Debug()` 记录错误
- 加载外部脚本时将风险操作包裹在 `pcall()` 中
- 协程抛出的异常由 `CoroutineScheduler` 捕获

## 文件组织

```
game/
├── engine-love2d/   ← 引擎 API 实现
├── engine-mud/      ← 替代引擎（初版）
├── framework/       ← 引擎无关游戏逻辑
├── script/          ← 游戏脚本（旧版）
└── tests/           ← 所有测试
```

新的引擎实现放在 `game/engine-<名称>/` 下。
新的框架模块放在 `game/framework/` 下。
新的测试放在 `game/tests/` 下。