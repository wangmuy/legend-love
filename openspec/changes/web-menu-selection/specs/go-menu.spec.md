## ADDED Requirements

### Requirement: go 无参弹出场景菜单 [REQ-001]

当玩家在 GAME_MMAP 状态下输入 `go` 且不带参数时，系统 SHALL 弹出场景选择菜单。

#### Scenario: go 无参 → 显示场景列表
- **GIVEN** 玩家在 GAME_MMAP 状态
- **WHEN** 玩家输入 `go`
- **THEN** 系统显示场景选择菜单，每项包括编号和场景名称

#### Scenario: choose N 选择场景
- **GIVEN** 场景菜单已显示
- **WHEN** 玩家输入 `choose 1`
- **THEN** 系统执行 `go <第1项的场景名>`，进入该场景

#### Scenario: ESC 关闭菜单
- **GIVEN** 场景菜单已显示
- **WHEN** 玩家输入 `choose 0`（ESC）
- **THEN** 菜单关闭，玩家返回 MMAP 状态，不做任何操作

#### Scenario: go 有参行为不变
- **GIVEN** 玩家在 GAME_MMAP 状态
- **WHEN** 玩家输入 `go 河洛客栈`
- **THEN** 系统执行原有精确匹配/模糊匹配逻辑，不弹菜单

### Requirement: list 改为菜单模式 [REQ-002]

`list` 命令 SHALL 改为菜单模式，展示场景列表供 choose N 选择。

#### Scenario: list 显示场景菜单
- **GIVEN** 玩家在 GAME_MMAP 状态
- **WHEN** 玩家输入 `list`
- **THEN** 系统显示场景选择菜单（同 go 无参）

#### Scenario: choose N 选择场景
- **GIVEN** 场景菜单已从 list 显示
- **WHEN** 玩家输入 `choose 1`
- **THEN** 系统执行 `go <第1项的场景名>`，进入该场景

### Requirement: 菜单辅助模式可复用 [REQ-003]

菜单构建和调用方式 SHALL 封装为可复用形式，供后续 `heal`/`give`/`take`/`wugong` 等命令使用。

#### Scenario: 复用菜单函数
- **GIVEN** 一个需要菜单选择的命令
- **WHEN** 调用 `CommandEngine.showMenu(items, title, callback)`
- **THEN** 菜单显示，用户通过 choose N 选择
- **AND** 回调返回用户选择的索引，或 nil（ESC）

## MODIFIED Requirements

### Requirement: go 命令注册 [REQ-004]（来自 slice3）

`go` 命令在 GAME_MMAP / GAME_SMAP 下注册，处理器 SHALL 支持有参（原行为）和无参（菜单）两种模式。

#### Scenario: go 菜单仅在 MMAP/SMAP 可用
- **GIVEN** 玩家在 GAME_START（开始菜单）
- **WHEN** 玩家输入 `go`
- **THEN** 系统提示"未知命令"