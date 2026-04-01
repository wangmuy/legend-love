## ADDED Requirements

### Requirement: Love2D API Mock
系统 SHALL 提供 Love2D API 的 Mock 实现，用于在无 Love2D 环境时测试。

#### Scenario: Mock love.timer
- **WHEN** 调用 TestHelper.mockLoveTimer()
- **THEN** 创建 love.timer 的 Mock
- **AND** getTime() 返回可控的时间值
- **AND** getDelta() 返回可控的 delta 值

#### Scenario: Mock love.graphics
- **WHEN** 调用 TestHelper.mockLoveGraphics()
- **THEN** 创建 love.graphics 的 Mock
- **AND** 所有绘制函数为空操作
- **AND** 可以验证绘制调用

#### Scenario: Mock love.keyboard
- **WHEN** 调用 TestHelper.mockLoveKeyboard()
- **THEN** 创建 love.keyboard 的 Mock
- **AND** isDown() 返回预设的按键状态
- **AND** 可以模拟按键按下/释放

#### Scenario: 完整 Love2D Mock
- **WHEN** 调用 TestHelper.mockLove()
- **THEN** 创建所有 Love2D API 的 Mock
- **AND** 可以安全地在纯 Lua 环境中运行测试

### Requirement: 游戏数据 Mock
系统 SHALL 提供游戏全局数据的 Mock。

#### Scenario: Mock CC 配置
- **WHEN** 调用 TestHelper.mockCC()
- **THEN** 创建 CC 配置表的 Mock
- **AND** 包含所有必要的配置项（ScreenW, ScreenH, DefaultFont 等）
- **AND** 使用合理的默认值

#### Scenario: Mock JY 数据
- **WHEN** 调用 TestHelper.mockJY()
- **THEN** 创建 JY 数据表的 Mock
- **AND** 包含空的 Person、Thing 等数据表
- **AND** 设置合理的默认状态

#### Scenario: Mock lib 模块
- **WHEN** 调用 TestHelper.mockLib()
- **THEN** 创建 lib 模块的 Mock
- **AND** Debug() 函数为空操作或记录日志
- **AND** 其他常用函数为空操作

### Requirement: 模块重置工具
系统 SHALL 提供重置模块状态的工具。

#### Scenario: 重置单个模块
- **WHEN** 调用 TestHelper.resetModule("module_name")
- **THEN** 从 package.loaded 中移除该模块
- **AND** 下次 require 时重新加载

#### Scenario: 重置所有测试模块
- **WHEN** 调用 TestHelper.resetAllModules()
- **THEN** 从 package.loaded 中移除所有被测试的模块
- **AND** 确保测试之间的完全隔离

#### Scenario: 重置单例实例
- **WHEN** 调用 TestHelper.resetSingleton(module)
- **THEN** 调用该模块的 reset() 方法
- **AND** 清除单例实例的内部状态

### Requirement: Spy 和 Stub 工具
系统 SHALL 提供 Spy 和 Stub 工具用于验证函数调用。

#### Scenario: 创建函数 Stub
- **WHEN** 调用 TestHelper.stub(object, "methodName", returnValue)
- **THEN** 替换 object.methodName 为返回 returnValue 的函数
- **AND** 原函数被保存，可后续恢复

#### Scenario: 创建函数 Spy
- **WHEN** 调用 TestHelper.spy(object, "methodName")
- **THEN** 包装 object.methodName 记录调用信息
- **AND** 原函数仍然执行
- **AND** 可以查询调用次数、参数等

#### Scenario: 验证函数调用
- **WHEN** 调用 spy.wasCalled()
- **THEN** 返回该函数是否被调用过

#### Scenario: 验证调用参数
- **WHEN** 调用 spy.wasCalledWith(arg1, arg2, ...)
- **THEN** 返回函数是否被指定参数调用过

### Requirement: 测试数据工厂
系统 SHALL 提供创建测试数据的工厂函数。

#### Scenario: 创建测试人物数据
- **WHEN** 调用 TestHelper.createTestPerson(overrides)
- **THEN** 返回一个人物数据表
- **AND** 包含合理的默认值
- **AND** overrides 中的值覆盖默认值

#### Scenario: 创建测试物品数据
- **WHEN** 调用 TestHelper.createTestThing(overrides)
- **THEN** 返回一个物品数据表
- **AND** 包含合理的默认值
- **AND** overrides 中的值覆盖默认值

#### Scenario: 创建测试菜单数据
- **WHEN** 调用 TestHelper.createTestMenu(items)
- **THEN** 返回菜单数据结构
- **AND** 格式与 ShowMenu 兼容
