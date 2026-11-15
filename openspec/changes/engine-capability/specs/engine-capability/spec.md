## ADDED Requirements

### Requirement: REQ-MS1-1 平台查询引擎无关

系统 SHALL 提供 `EngineAPI.system.getOS()`，在三个引擎下都存在且不抛错，
返回值限定在固定集合内。

#### Scenario: love2d 返回真实平台
- **WHEN** 在 Love2D 引擎下调用 `EngineAPI.system.getOS()`
- **THEN** 返回 `love.system.getOS()` 的值（如 `"Windows"`）

#### Scenario: web 引擎返回 "web"
- **WHEN** 在 `engine-web` 下调用 `getOS()`
- **THEN** 返回 `"web"`（**硬编码**，不透传 `love.system`）
- **AND** 不依赖 `love.system` 是否存在

#### Scenario: mud 引擎返回 "unknown"
- **WHEN** 在 `engine-mud` 下调用 `getOS()`
- **THEN** 返回 `"unknown"`

#### Scenario: 测试引擎可注入
- **WHEN** 设置 `EngineAPI.system._os = "Android"` 后调用 `getOS()`
- **THEN** 返回 `"Android"`

#### Scenario: 返回值限定集合
- **WHEN** 任意引擎下调用 `getOS()`
- **THEN** 返回值必须是 `Windows|Linux|macOS|Android|iOS|web|unknown` 之一

### Requirement: REQ-MS1-2 鼠标坐标是逻辑坐标

系统 SHALL 提供 `EngineAPI.input.mousePosition()`，返回与绘图同一坐标空间的坐标。
引擎负责消化 DPI 换算，调用方无需感知。

#### Scenario: love2d 在 150% 缩放下与绘图坐标 1:1
- **WHEN** Windows 系统缩放的 150%、`conf.lua` 开启 `usedpiscale` 的情况下，
  调用 `love.mouse.setPosition(1023, 767)` 后读 `EngineAPI.input.mousePosition()`
- **THEN** 返回 `(1023, 767)`（比值 1.000），与 `love.graphics.getDimensions()`
  的 1024×768 同一空间

#### Scenario: 无鼠标引擎返回 -1
- **WHEN** 在 `engine-mud` / `engine-web` 下调用 `mousePosition()`
- **THEN** 返回 `-1, -1`（而非 nil，避免调用方做 nil 判断）

#### Scenario: 鼠标按键状态查询
- **WHEN** 调用 `EngineAPI.input.mouseButton(1)`
- **THEN** 返回布尔值（1=左键 2=右键 3=中键）
- **AND** 无鼠标引擎下恒返回 `false`

#### Scenario: 契约写在接口注释里
- **WHEN** 检查 `engine_api.lua` 的 `mousePosition` 声明
- **THEN** 注释必须包含「逻辑坐标」「与 DrawString 同一空间」「引擎内部消化 DPI」
- **AND** 记录 Windows 150% 的实测结论

### Requirement: REQ-MS1-3 染色绘制通用化

系统 SHALL 提供 `EngineAPI.sprite.drawTinted(archiveId, spriteId, x, y, color, alpha)`，
支持任意精灵与任意 RGB 颜色。

#### Scenario: 接受颜色表
- **WHEN** 调用 `drawTinted(0, 0, 512, 384, {r=1, g=0, b=0}, 180)`
- **THEN** 不抛错，且把 `color` 与 `alpha` 传给底层绘制

#### Scenario: love2d 真实染色
- **WHEN** 在 love2d 下调用 `drawTinted` 并传入 `{r=1,g=0,b=0}`
- **THEN** 底层实际调用 `love.graphics.setColor(1, 0, 0, alpha/255)` 后绘制该精灵

#### Scenario: 损坏参数不抛错
- **WHEN** `color` 为 nil 或缺少分量
- **THEN** 退化为原色绘制，不抛错

#### Scenario: 无渲染引擎不抛错
- **WHEN** 在 `engine-mud` / `engine-web` 下调用 `drawTinted`
- **THEN** 记录调用且不抛错

#### Scenario: 任意 spriteId 可用
- **WHEN** 传 `spriteId = 0`（菱形）
- **THEN** 正常绘制；传其他 spriteId 同样正常（不硬编码 0）

### Requirement: REQ-MS1-4 设置支持平台默认值

系统 SHALL 在 `settings.lua` 新增第四层 `platform`，解析顺序为
`user > mod > platform > default`，且保持零引擎依赖。

#### Scenario: 平台默认值生效
- **WHEN** `Settings.setPlatform("Android")` 且
  `define("input.mouse", {default=false, platformDefaults={Windows=true, Android=false}})`
- **THEN** `Settings.get("input.mouse")` 返回 `false`

#### Scenario: 桌面平台默认开
- **WHEN** `Settings.setPlatform("Windows")` 且同上定义
- **THEN** `Settings.get("input.mouse")` 返回 `true`

#### Scenario: 未知平台用 default
- **WHEN** `Settings.setPlatform("unknown")`
- **THEN** `Settings.get("input.mouse")` 返回 `default`（false）

#### Scenario: 用户设置覆盖平台默认
- **WHEN** `Settings.setPlatform("Android")` 且 `Settings.set("input.mouse", true)`
- **THEN** `Settings.get("input.mouse")` 返回 `true`（user 层优先）

#### Scenario: mod 层优先于平台层
- **WHEN** `setPlatform("Android")`、`setMod("input.mouse", true)`、无 user 值
- **THEN** 返回 `true`

#### Scenario: 平台层不落盘
- **WHEN** 调用 `Settings.save()`
- **THEN** 写出的 `settings.ini` **不含** platformDefaults 的值
  （只有 user 层落盘）

#### Scenario: settings.lua 零引擎依赖
- **WHEN** 执行 `grep -E "EngineAPI|love\.|CC\.[A-Za-z]|JY\.[A-Za-z]" game/framework/settings.lua`
  （排除注释行）
- **THEN** 结果为空

### Requirement: REQ-MS1-5 鼠标事件队列与键盘隔离

系统 SHALL 提供独立于键盘的鼠标事件队列，现有 `getKey()` 行为完全不变。

#### Scenario: 鼠标事件不污染 getKey
- **WHEN** 入队一个鼠标事件后调用 `lib.GetKey()`
- **THEN** 返回 `-1`（鼠标事件不被当作按键）

#### Scenario: 键盘事件不污染 getMouseEvent
- **WHEN** 入队一个键盘事件后调用 `getMouseEvent()`
- **THEN** 返回 `nil`

#### Scenario: 鼠标事件按顺序消费
- **WHEN** 依次入队 `{x=1}`、`{x=2}`
- **THEN** 两次 `getMouseEvent()` 分别返回 `x=1`、`x=2`

#### Scenario: 队列满时不崩
- **WHEN** 连续入队超过容量上限的鼠标事件
- **THEN** 不抛错（丢弃最旧的，与键盘队列同策略）

#### Scenario: 现有键盘路径零回归
- **WHEN** 运行全量测试
- **THEN** 所有既有 `input_manager` 测试不变通过

### Requirement: REQ-MS1-6 跨版本与跨平台

系统 SHALL 在四个 Lua 版本与干净 Windows PATH 下保持全绿。

#### Scenario: 四版本全绿
- **WHEN** 在 Lua 5.1 / 5.3 / 5.4 / 5.5 下运行 `lua tests/test_runner.lua`
- **THEN** 四个版本都全绿

#### Scenario: 双版本语法检查
- **WHEN** 对全仓执行 `luac5.1 -p` 与 `luac5.5 -p`
- **THEN** 零失败

#### Scenario: 干净 PATH 一致
- **WHEN** 在干净 Windows PATH（无 msys2）下运行全量测试
- **THEN** 结果与完整 PATH 下一致

#### Scenario: LÖVE 启动无报错
- **WHEN** 用 LÖVE 11.5 启动游戏
- **THEN** 无报错、无崩溃

### Requirement: REQ-MS1-7 文档计数同步

系统 SHALL 让三个文档的 EngineAPI 计数与实际一致。

#### Scenario: 模块数更新
- **WHEN** 检查 `AGENTS.md`
- **THEN** 不得再写「12 个模块」，应为「15 个模块」

#### Scenario: 函数数更新
- **WHEN** 检查 `SRC_FILES.md` / `ENGINE_API_DESIGN.md`
- **THEN** 函数计数应为 55（原 51 + 本 change 新增 4）
