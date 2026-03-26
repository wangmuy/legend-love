## ADDED Requirements

### Requirement: 轻量级单元测试框架
系统 SHALL 提供轻量级单元测试框架，支持测试的组织、运行和报告。

#### Scenario: 运行所有测试
- **WHEN** 执行测试运行器
- **THEN** 运行所有注册的测试模块
- **AND** 输出每个测试的结果（通过/失败）
- **AND** 输出测试统计信息（总数、通过数、失败数）

#### Scenario: 运行单个测试模块
- **WHEN** 指定模块名称执行测试运行器
- **THEN** 仅运行指定的测试模块
- **AND** 输出该模块的测试结果

#### Scenario: 测试失败报告
- **WHEN** 某个测试断言失败
- **THEN** 显示失败的测试名称
- **AND** 显示期望值和实际值
- **AND** 继续运行后续测试

### Requirement: 断言函数
系统 SHALL 提供基本的断言函数用于测试验证。

#### Scenario: 相等断言
- **WHEN** 调用 assertEquals(expected, actual, message)
- **AND** expected 等于 actual
- **THEN** 测试通过

#### Scenario: 相等断言失败
- **WHEN** 调用 assertEquals(expected, actual, message)
- **AND** expected 不等于 actual
- **THEN** 测试失败
- **AND** 显示 message、expected 和 actual

#### Scenario: 真值断言
- **WHEN** 调用 assertTrue(value, message)
- **AND** value 为真
- **THEN** 测试通过

#### Scenario: 假值断言
- **WHEN** 调用 assertFalse(value, message)
- **AND** value 为假
- **THEN** 测试通过

### Requirement: 测试生命周期管理
系统 SHALL 支持测试的初始化和清理。

#### Scenario: 测试前初始化
- **WHEN** 每个测试开始前
- **THEN** 调用 setup() 函数（如果存在）
- **AND** 重置被测模块的状态

#### Scenario: 测试后清理
- **WHEN** 每个测试结束后
- **THEN** 调用 teardown() 函数（如果存在）
- **AND** 清理测试产生的副作用

### Requirement: 测试独立性
系统 SHALL 确保测试之间相互独立。

#### Scenario: 测试隔离
- **WHEN** 运行多个测试
- **THEN** 每个测试在独立的环境中运行
- **AND** 一个测试的失败不影响其他测试
- **AND** 一个测试的状态不影响其他测试
