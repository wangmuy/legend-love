## ADDED Requirements

### Requirement: REQ-MS3-1 悬停高亮

系统 SHALL 在鼠标位于地图内时，在所指格子绘制菱形高亮，
并在不满足条件时不绘制。

#### Scenario: 大地图悬停绘制
- **WHEN** `JY.Status == GAME_MMAP`、无菜单、鼠标开关开启，鼠标位于地图内
- **THEN** 在鼠标所指格子绘制菱形（`drawTinted(0, 0, x, y, {0,0,0}, 64)`）

#### Scenario: 小场景悬停绘制
- **WHEN** `JY.Status == GAME_SMAP` 且其余条件满足
- **THEN** 同样绘制菱形

#### Scenario: 有菜单时不绘制
- **WHEN** `MenuAsync.hasActiveMenu()` 为真
- **THEN** **不**绘制悬停菱形

#### Scenario: 阻塞输入时不绘制
- **WHEN** `InputManager.disableInput == true`
- **THEN** **不**绘制悬停菱形

#### Scenario: 非地图状态不绘制
- **WHEN** `JY.Status` 为 `GAME_WMAP`（战斗）/ `GAME_START` / `GAME_DEAD`
- **THEN** **不**绘制悬停菱形

#### Scenario: 鼠标出屏不绘制
- **WHEN** 鼠标坐标不在 `[0, CC.ScreenW) × [0, CC.ScreenH)` 内
- **THEN** **不**绘制悬停菱形

#### Scenario: 鼠标开关关闭不绘制
- **WHEN** `Settings.get("input.mouse") == false`
- **THEN** **不**绘制悬停菱形

#### Scenario: 绘制位置在状态绘制之后
- **WHEN** 检查 `EventBridge:draw()` 的调用顺序
- **THEN** 悬停绘制必须在 `StateMachine.getInstance():draw()` **之后**、
  `SceneNameAsync.draw()` **之前**

### Requirement: REQ-MS3-2 屏幕坐标反解

系统 SHALL 提供屏幕坐标到格坐标的反解，且在格中心采样时 100% 准确。

#### Scenario: 格中心精确往返
- **WHEN** 取任意格 `(gx, gy)` 的屏幕中心 `tileToScreen(gx, gy)`，
  再反解 `screenToTile(...)`
- **THEN** 必须返回 `(gx, gy)`，误差为 0
- **AND** 对 `gx, gy ∈ [-8, 8]` 的全部 289 格成立

#### Scenario: 菱形内部采样命中正确格
- **WHEN** 在格 `(gx, gy)` 的菱形内部（`|ox|/18 + |oy|/9 <= 1`）采样点并反解
- **THEN** 命中率必须是 **100%**（不允许出现半格错位）

#### Scenario: 负坐标区域同样正确
- **WHEN** 格坐标为负数（`gx < 0` 或 `gy < 0`）
- **THEN** 反解同样精确（不能用 `floor` 的朴素实现，见 ADR-MS3-001）

#### Scenario: 反解使用 round 而非 floor
- **WHEN** 检查 `screenToTile` 的实现
- **THEN** 必须对 `(u+v)/2` 与 `(v-u)/2` 加 `0.5` 后再 `floor`
- **AND** 若去掉 `+0.5`，菱形内部采样测试必须失败（约 75% 偏离）

### Requirement: REQ-MS3-3 点击寻路移动

系统 SHALL 在点击可达格时计算路径并沿路径自动移动，
点击不可达格时给出红闪反馈且不移动。

#### Scenario: 点击可达格自动移动
- **WHEN** 点击一个 `isWalkable` 为真的格子且与当前位置连通
- **THEN** 角色沿路径逐格移动到该格
- **AND** 到达后回到 IDLE 状态

#### Scenario: 点击不可达格红闪
- **WHEN** 点击一个 `isWalkable` 为假的格子（墙/水/越界）
- **THEN** 播放红闪（`drawTinted` 红色）
- **AND** 角色**不**移动

#### Scenario: 点击不连通区域红闪
- **WHEN** 点击可站立但与当前位置不连通的格子（A* 返回 nil）
- **THEN** 播放红闪，角色**不**移动

#### Scenario: 红闪节流 200ms
- **WHEN** 连续点击不可达格多次（间隔 < 200ms）
- **THEN** 红闪只在首次触发，200ms 内的后续点击不重复触发

#### Scenario: 点击当前所在格
- **WHEN** 点击角色当前所在的格子
- **THEN** 无动作（不移动、不红闪）

#### Scenario: 自动移动中再次点击
- **WHEN** 角色正在自动移动时点击另一个格
- **THEN** 中断当前路径，重新计算到新目标的路径

### Requirement: REQ-MS3-4 寻路不在 update 中执行

系统 SHALL 只在点击瞬间执行一次 A*，`update` 每帧只做 O(1) 的路径队列消费。

#### Scenario: A* 只在点击时调用
- **WHEN** 角色在自动移动中
- **THEN** `update` 每帧不得调用 `Pathfind.find`
- **AND** 只从 `JY.AutoMove.path` 取出下一个路径点

#### Scenario: 路径队列消费是 O(1)
- **WHEN** 检查 `update` 中的自动移动分支
- **THEN** 每帧只有一个 `path[index]` 下标访问与递增

#### Scenario: A* 有 maxNodes 上限
- **WHEN** 调用 `Pathfind.find` 时目标在另一个连通区
- **THEN** 扩展节点数达到 `maxNodes`（默认 5000）后立即返回 `nil`
- **AND** 返回第二个值说明原因（`"exceeded-max-nodes"`）

### Requirement: REQ-MS3-5 中断语义

系统 SHALL 在按键、事件触发、进入子场景三种情况下中断自动移动，
并遵循明确的恢复语义。

#### Scenario: 按键中断并吃掉全部 repeat
- **WHEN** 自动移动中玩家按下方向键
- **THEN** 自动移动立即中断
- **AND** 该按键**不**被响应为方向移动
- **AND** 后续的 repeat 事件全部被吃掉，直到 `keyreleased`
- **AND** 松开后，新的按键正常响应

#### Scenario: 事件触发中断且不恢复路径
- **WHEN** 自动移动途中触发路过事件（`d_pass`）
- **THEN** 自动移动立即中断
- **AND** 事件正常执行
- **AND** 事件结束后**不**恢复剩余路径（玩家需重新点击）

#### Scenario: 进入子场景清空路径
- **WHEN** 自动移动走到场景入口并进入子场景
- **THEN** 自动移动中断
- **AND** 剩余路径被清空（坐标系已改变）

#### Scenario: 点击场景入口直接进入
- **WHEN** 点击的格子是场景入口且可达
- **THEN** 角色走到该格并进入子场景
- **AND** 即使还有其他路径点也丢弃

#### Scenario: 进入战斗清空状态
- **WHEN** 自动移动途中进入战斗
- **THEN** `JY.AutoMove` 被清空

#### Scenario: drain 状态有超时保护
- **WHEN** `drain` 已激活但长时间收不到 `keyreleased`（如窗口失焦）
- **THEN** 超时（2 秒）后自动解除，避免永久卡住

### Requirement: REQ-MS3-6 鼠标开关联动

系统 SHALL 在鼠标开关关闭时，禁用悬停高亮与点击寻路。

#### Scenario: 关闭后不响应点击
- **WHEN** `Settings.get("input.mouse") == false`，点击地图
- **THEN** 角色**不**移动，**不**红闪

#### Scenario: 关闭后不绘制悬停
- **WHEN** 鼠标开关关闭，鼠标在地图上移动
- **THEN** 不绘制悬停菱形

#### Scenario: 移动中途关闭开关
- **WHEN** 角色正在自动移动时鼠标开关被关闭
- **THEN** 当前移动**继续完成**（不强行中断，因为那是键盘/事件的事）

### Requirement: REQ-MS3-7 走法判定必须复用既有逻辑

系统 SHALL 复用既有的可走性判定，不得重写判定条件。

#### Scenario: SMAP 复用 SceneCanPass
- **WHEN** 检查 `smapWalkable` 的实现
- **THEN** 必须调用 `SceneCanPass(x, y)`
- **AND** 不得自行重写「水面 / 物品 / 事件」三条判定

#### Scenario: MMAP 判定与 Game_MMap 逐字一致
- **WHEN** 检查 `mmapWalkable` 的实现
- **THEN** 判定表达式必须是
  `lib.GetMMap(x,y,3)==0 and lib.GetMMap(x,y,4)==0`
- **AND** 边界必须是 `[10, CC.MWidth-10] × [10, CC.MHeight-10]`
  （与 `Game_MMap` 的 `limitX` 一致）

#### Scenario: 寻路结果与键盘走路一致
- **WHEN** 用 A* 从 A 走到 B
- **THEN** 路径上每一步都必须满足 `isWalkable`
- **AND** 用键盘逐格沿同一路径走，也应全部可走
