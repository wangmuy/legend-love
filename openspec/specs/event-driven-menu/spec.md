## ADDED Requirements

### Requirement: 菜单系统使用状态机管理
系统 SHALL 使用状态机管理菜单状态，替代阻塞式while循环。

#### Scenario: 菜单初始化
- **WHEN** 调用ShowMenu初始化菜单
- **THEN** 菜单状态机进入菜单状态
- **AND** 菜单选项被正确渲染

#### Scenario: 菜单导航
- **WHEN** 用户按下方向键
- **THEN** 菜单状态机更新当前选项
- **AND** 菜单重新渲染显示新选项

#### Scenario: 菜单选择
- **WHEN** 用户按下确认键
- **THEN** 菜单状态机返回选中项索引
- **AND** 菜单状态机退出菜单状态

#### Scenario: 菜单取消
- **WHEN** 用户按下取消键
- **THEN** 菜单状态机返回0
- **AND** 菜单状态机退出菜单状态

### Requirement: 菜单支持动画效果
系统 SHALL 支持菜单显示和切换的动画效果。

#### Scenario: 菜单显示动画
- **WHEN** 菜单首次显示
- **THEN** 播放菜单显示动画
- **AND** 动画完成后菜单可交互

#### Scenario: 菜单选项切换动画
- **WHEN** 切换菜单选项
- **THEN** 播放选项高亮动画
- **AND** 动画不影响菜单响应

### Requirement: 菜单支持嵌套
系统 SHALL 支持嵌套菜单，子菜单返回后父菜单继续显示。

#### Scenario: 打开子菜单
- **WHEN** 在父菜单中打开子菜单
- **THEN** 子菜单状态机接管输入和渲染
- **AND** 父菜单状态被保存

#### Scenario: 子菜单返回
- **WHEN** 子菜单关闭
- **THEN** 恢复父菜单状态
- **AND** 父菜单继续显示

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
