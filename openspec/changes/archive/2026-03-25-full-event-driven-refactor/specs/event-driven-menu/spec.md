## ADDED Requirements

### Requirement: ShowMenu协程版本
系统 SHALL 提供 ShowMenu 的协程版本 MenuAsync.ShowMenuCoroutine。

#### Scenario: 协程调用菜单
- **WHEN** 在协程中调用 MenuAsync.ShowMenuCoroutine
- **THEN** 显示菜单并等待选择
- **AND** 协程暂停直到菜单关闭
- **AND** 返回选中的菜单项索引

#### Scenario: 替代原有ShowMenu
- **WHEN** 游戏代码需要显示菜单
- **THEN** 使用 MenuAsync.ShowMenuCoroutine 替代 ShowMenu
- **AND** 行为与原版一致

### Requirement: ShowMenu2协程版本
系统 SHALL 提供 ShowMenu2 的协程版本 MenuAsync.ShowMenu2Coroutine。

#### Scenario: 横向菜单
- **WHEN** 在协程中调用 MenuAsync.ShowMenu2Coroutine
- **THEN** 显示横向菜单
- **AND** 支持左右键选择

### Requirement: 主菜单异步
主菜单 MMenu SHALL 改造为异步版本，支持在协程中调用。

#### Scenario: 打开主菜单
- **WHEN** 玩家按下ESC打开主菜单
- **THEN** 显示主菜单（异步）
- **AND** 游戏暂停但不阻塞

#### Scenario: 主菜单操作
- **WHEN** 在主菜单中选择操作
- **THEN** 执行对应功能
- **AND** 功能完成后菜单正确关闭

### Requirement: 菜单函数废弃标记
原版 ShowMenu 和 ShowMenu2 函数 SHALL 标记为废弃。

#### Scenario: 废弃警告
- **WHEN** 调用原版 ShowMenu
- **THEN** 输出废弃警告日志
- **AND** 仍然正常执行（兼容模式）