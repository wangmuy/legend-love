## ADDED Requirements

### Requirement: parseCommand 解析

CommandEngine.parseCommand SHALL 将文本命令解析为结构化数据。

#### Scenario: 基本命令
- **WHEN** parseCommand("look")
- **THEN** 返回 `{cmd="look", args={}, raw="look"}`
- **WHEN** parseCommand("go 河洛客栈")
- **THEN** 返回 `{cmd="go", args={"河洛客栈"}, raw="go 河洛客栈"}`

#### Scenario: 引号参数
- **WHEN** parseCommand('go "河洛客栈"')
- **THEN** 返回 `{cmd="go", args={"河洛客栈"}, raw='go "河洛客栈"'}`

#### Scenario: 空输入
- **WHEN** parseCommand("")
- **THEN** 返回 nil
- **WHEN** parseCommand(nil)
- **THEN** 返回 nil

### Requirement: 命令注册表

命令注册表 SHALL 按 JY.Status 组织命令。

#### Scenario: 注册和查询
- **WHEN** registerCommands(GAME_MMAP, {look={handler=fn, description="查看"}})
- **THEN** getCommands(GAME_MMAP).look 存在
- **WHEN** getCommands(GAME_SMAP)
- **THEN** 返回 nil（未注册）

### Requirement: dispatchCommand

dispatchCommand SHALL 按当前状态分发命令。

#### Scenario: 已知命令
- **GIVEN** `look` 命令已注册到当前状态
- **WHEN** dispatchCommand("look", {})
- **THEN** 返回 true，处理器被调用

#### Scenario: 未知命令
- **GIVEN** `xyz` 未注册
- **WHEN** dispatchCommand("xyz", {})
- **THEN** 返回 false

### Requirement: help 命令

help 命令 SHALL 显示当前状态所有可用命令。

#### Scenario: help 输出
- **GIVEN** MMAP 状态有 list/go/look/where/help/choose 命令
- **WHEN** 用户输入 "help"
- **THEN** 终端列出所有 6 个命令及其描述

### Requirement: choose 命令

choose 命令 SHALL 关闭当前活动菜单并返回选择值。

#### Scenario: 有关联菜单时选择菜单项
- **GIVEN** 有活动菜单（MenuAsync.hasActiveMenu() == true）
- **WHEN** 用户输入 "choose 1"
- **THEN** MenuAsync.closeMenu(1) 被调用
- **AND** ShowMenuCoroutine 返回 1（触发对应菜单项）

#### Scenario: 无菜单时提示
- **GIVEN** 没有活动菜单
- **WHEN** 用户输入 "choose 1"
- **THEN** 输出 "当前没有可选的菜单"

#### Scenario: 非法参数
- **WHEN** 用户输入 "choose abc"
- **THEN** 输出 "用法: choose <编号>"
