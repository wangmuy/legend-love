## ADDED Requirements

### Requirement: REQ-MS2-1 右键呼出菜单

系统 SHALL 只在大地图（`GAME_MMAP`）与小场景（`GAME_SMAP`）响应右键呼出菜单，
并在事件执行中、阻塞输入期间、战斗状态下一律不呼出。

#### Scenario: 大地图右键呼出
- **WHEN** `JY.Status == GAME_MMAP`、无菜单、鼠标开关开启，按下鼠标右键
- **THEN** 主菜单被打开（等价于按 ESC）

#### Scenario: 小场景右键呼出
- **WHEN** `JY.Status == GAME_SMAP`、无菜单、鼠标开关开启，按下鼠标右键
- **THEN** 主菜单被打开

#### Scenario: 战斗中不呼出
- **WHEN** `JY.Status == GAME_WMAP`（战斗），按下鼠标右键
- **THEN** **不**呼出菜单（战斗状态不在 MMAP/SMAP 分支内）

#### Scenario: 事件执行中不呼出
- **WHEN** `JY.CurrentD >= 0`（事件/强制对话执行中），按下鼠标右键
- **THEN** **不**呼出菜单（继承既有 ESC 的屏蔽条件）

#### Scenario: 阻塞输入期间不呼出
- **WHEN** `InputManager.disableInput == true`（动画/物品选择等），按下鼠标右键
- **THEN** **不**呼出菜单

#### Scenario: 已有菜单时不重复呼出
- **WHEN** 已有菜单打开，按下鼠标右键
- **THEN** 不打开新菜单（不产生嵌套的重复菜单）

#### Scenario: 鼠标开关关闭时不呼出
- **WHEN** `Settings.get("input.mouse") == false`，按下鼠标右键
- **THEN** **不**呼出菜单

### Requirement: REQ-MS2-2 菜单项点击

系统 SHALL 把鼠标点击翻译成已有的键盘菜单语义，不引入第二套选中逻辑。

#### Scenario: 点击菜单项触发选中
- **WHEN** 菜单打开，点击第 N 行的文本区域
- **THEN** 该行被选中并触发其回调（等价于光标移到第 N 行后按 Enter）

#### Scenario: 点击值项的 ▲ 箭头
- **WHEN** 值项（`kind == "number"`）的三行布局中，点击第 1 行的 `▲`
- **THEN** 待定值 `+step`（等价于按 `VK_UP`）
- **AND** `Settings` 值不变（仍是待定值语义）

#### Scenario: 点击值项的 ▼ 箭头
- **WHEN** 点击第 3 行的 `▼`
- **THEN** 待定值 `-step`（等价于按 `VK_DOWN`）

#### Scenario: 点击值项中间行
- **WHEN** 点击值项的第 2 行（值文本）
- **THEN** 不改变待定值（不误触发调整）

#### Scenario: 点击菜单外部关闭
- **WHEN** 菜单打开，点击菜单矩形 `(x1,y1,w,h)` 之外的区域
- **THEN** 菜单被关闭（等价于按 ESC，返回 0）

#### Scenario: 滚动菜单的点击命中偏移正确
- **WHEN** 菜单 `numShow != 0` 且 `menu.start > 1`（已滚动），点击可视区域的第 1 行
- **THEN** 命中 `menu.start` 对应的那一项（不是第 1 项）
- **AND** 行号计算必须用 `(i - menu.start)` 而非 `(i - 1)`

#### Scenario: 点击不可见项无反应
- **WHEN** 点击菜单矩形内但对应 `i > menu.newNumItem` 的空白区域
- **THEN** 无任何动作（不关闭菜单、不选中）

### Requirement: REQ-MS2-3 子菜单切换

系统 SHALL 在子菜单打开时，若点击主菜单的其他项，先关闭当前子菜单再响应新项。

#### Scenario: 子菜单打开时点主菜单其他项
- **WHEN** 主菜单打开 → 选中「系统」进入子菜单 → 点击主菜单（在子菜单下方仍可见）
  的「物品」项
- **THEN** 当前子菜单被关闭
- **AND** 然后响应「物品」
- **AND** 最终菜单栈不残留多余层级

#### Scenario: 子菜单打开时点子菜单自身项
- **WHEN** 子菜单打开，点击子菜单内的某项
- **THEN** 正常响应，不影响父菜单栈

#### Scenario: 点击关闭最内层
- **WHEN** 两级子菜单（菜单栈深度 2），点击菜单外
- **THEN** 只有最内层被关闭（与 ESC 语义一致），父菜单恢复

### Requirement: REQ-MS2-4 鼠标操作开关

系统 SHALL 在开始菜单「设置」与大地图「系统」提供「鼠标操作」开关，
切换立即生效并持久化。

#### Scenario: 开始菜单可切换
- **WHEN** 开始菜单 →「设置」→ 光标在「鼠标操作」行，按 Enter
- **THEN** `Settings.get("input.mouse")` 取反
- **AND** 该行文本在「开」/「关」之间变化
- **AND** 菜单**不关闭**（可连续切换）

#### Scenario: 大地图系统菜单可切换
- **WHEN** 大地图 →「系统」→ 选中「鼠标操作」
- **THEN** 同上

#### Scenario: 上下键是导航不是切换
- **WHEN** 光标在「鼠标操作」行，按 `VK_UP` 或 `VK_DOWN`
- **THEN** 光标移动到相邻行（`Settings.get("input.mouse")` **不变**）

#### Scenario: 关闭后立即不响应
- **WHEN** 鼠标开关从开切到关
- **THEN** 后续右键不再呼出菜单
- **AND** 后续点击不再选中菜单项

#### Scenario: 默认值按平台
- **WHEN** `Settings.setPlatform("Windows")` 且用户未改过该设置
- **THEN** 鼠标开关默认 `true`
- **WHEN** `Settings.setPlatform("Android")`
- **THEN** 默认 `false`

#### Scenario: 持久化
- **WHEN** 切换鼠标开关后保存
- **THEN** `settings.ini` 含 `[input] mouse=1` 或 `mouse=0`
- **AND** 重启后恢复该值

### Requirement: REQ-MS2-5 键盘零回归

系统 SHALL 保证所有既有键盘菜单操作行为完全不变。

#### Scenario: 既有菜单测试全绿
- **WHEN** 运行全量测试
- **THEN** 既有 `menu_value_item` / `audio_settings` / 相关测试全部通过

#### Scenario: 键盘菜单路径未变
- **WHEN** 用键盘打开菜单、导航、选中、ESC 关闭
- **THEN** 行为与改动前完全一致

#### Scenario: 无鼠标引擎下菜单正常
- **WHEN** 在 `engine-mud`（`mousePosition` 返回 `-1,-1`）下操作菜单
- **THEN** 菜单完全由键盘工作，鼠标相关代码不产生副作用
