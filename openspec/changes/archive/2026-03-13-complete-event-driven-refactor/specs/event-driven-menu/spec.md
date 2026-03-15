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
