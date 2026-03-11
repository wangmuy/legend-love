## ADDED Requirements

### Requirement: 游戏状态管理
系统 SHALL 使用状态机管理游戏状态(GAME_START, GAME_MMAP, GAME_SMAP, GAME_WMAP等)。

#### Scenario: 状态切换
- **WHEN** 游戏状态需要改变
- **THEN** 调用状态切换函数
- **AND** 执行旧状态清理和新状态初始化

#### Scenario: 状态更新
- **WHEN** love.update被调用
- **THEN** 当前状态执行其update逻辑
- **AND** 根据输入和逻辑决定是否切换状态

#### Scenario: 状态渲染
- **WHEN** love.draw被调用
- **THEN** 当前状态执行其draw逻辑
- **AND** 渲染对应的游戏画面

### Requirement: 状态初始化与清理
每个状态 SHALL 具有初始化和清理函数，在状态切换时调用。

#### Scenario: 进入主地图
- **WHEN** 从其他状态切换到GAME_MMAP
- **THEN** 调用Init_MMap初始化主地图
- **AND** 加载必要的资源

#### Scenario: 离开主地图
- **WHEN** 从GAME_MMAP切换到其他状态
- **THEN** 调用清理函数释放资源
- **AND** 保存必要的状态

### Requirement: 状态注册
系统 SHALL 支持动态注册游戏状态及其处理函数。

#### Scenario: 注册状态
- **WHEN** 定义新状态
- **THEN** 可以注册该状态的update和draw处理器
- **AND** 状态机可以查找并调用对应处理器
