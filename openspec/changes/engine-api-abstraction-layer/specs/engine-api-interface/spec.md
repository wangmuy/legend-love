## ADDED Requirements

### Requirement: EngineAPI 接口定义文件

系统 SHALL 提供 `game/engine_api.lua` 作为 EngineAPI 的接口定义文件，包含所有 11 个模块的函数签名和文档注释，不包含实现代码。

#### Scenario: 接口文件包含 render 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.render` 表
- **THEN** 该表 SHALL 包含 `text`、`fillRect`、`rectOutline`、`drawBackground`、`setClip`、`present`、`presentAndWait` 函数

#### Scenario: 接口文件包含 sprite 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.sprite` 表
- **THEN** 该表 SHALL 包含 `initSprites`、`loadArchive`、`getSize`、`draw` 函数

#### Scenario: 接口文件包含 map 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.map` 表
- **THEN** 该表 SHALL 包含 `loadMain`、`loadScene`、`saveScene`、`loadBattle`、`drawMain`、`drawScene`、`drawBattle` 函数

#### Scenario: 接口文件包含 input 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.input` 表
- **THEN** 该表 SHALL 包含 `getKey`、`waitForKey`、`setKeyRepeat` 函数

#### Scenario: 接口文件包含 audio 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.audio` 表
- **THEN** 该表 SHALL 包含 `playMusic`、`playSFX`、`stopMusic` 函数

#### Scenario: 接口文件包含 time 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.time` 表
- **THEN** 该表 SHALL 包含 `sleep`、`getTime` 函数

#### Scenario: 接口文件包含 file 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.file` 表
- **THEN** 该表 SHALL 包含 `open`、`remove`、`getSize`、`exists` 函数

#### Scenario: 接口文件包含 script 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.script` 表
- **THEN** 该表 SHALL 包含 `load` 函数

#### Scenario: 接口文件包含 font 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.font` 表
- **THEN** 该表 SHALL 包含 `get` 函数

#### Scenario: 接口文件包含 color 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.color` 表
- **THEN** 该表 SHALL 包含 `pack`、`unpack` 函数

#### Scenario: 接口文件包含 debug 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.debug` 表
- **THEN** 该表 SHALL 包含 `log` 函数

#### Scenario: 接口文件包含 coroutine 模块
- **WHEN** 读取 `engine_api.lua` 中的 `EngineAPI.coroutine` 表
- **THEN** 该表 SHALL 包含 `isRunning`、`yieldPoint`、`waitFor` 函数

### Requirement: yieldable 函数标记

EngineAPI 接口定义 SHALL 在文档注释中标记哪些函数是 yieldable（调用时可能触发 coroutine.yield）。

#### Scenario: yieldable 函数列表
- **WHEN** 检查 EngineAPI 接口文档
- **THEN** 以下函数 SHALL 被标记为 yieldable：`input.waitForKey`、`time.sleep`、`render.presentAndWait`

#### Scenario: 非 yieldable 函数
- **WHEN** 检查 EngineAPI 接口文档
- **THEN** 以下函数 SHALL NOT 被标记为 yieldable：`render.text`、`sprite.draw`、`audio.playMusic`、`file.open`、`debug.log`

### Requirement: 颜色参数使用 0-1 浮点数

EngineAPI 所有渲染相关函数的颜色参数 SHALL 接受 0-1 范围的浮点数。

#### Scenario: render.text 接受 0-1 颜色
- **WHEN** 调用 `EngineAPI.render.text(x, y, str, {1.0, 0.5, 0.2}, size)`
- **THEN** 引擎实现 SHALL 正确解析 0-1 浮点数颜色

#### Scenario: color.unpack 返回 0-1
- **WHEN** 调用 `EngineAPI.color.unpack(packedColor)`
- **THEN** 返回值 SHALL 是三个 0-1 范围的浮点数

#### Scenario: color.pack 接受 0-255
- **WHEN** 调用 `EngineAPI.color.pack(236, 236, 236)`
- **THEN** 返回值 SHALL 是与现有 `RGB()` 兼容的 packed int

### Requirement: 精灵系统 API 命名

EngineAPI 精灵系统 SHALL 使用 `initSprites` 而非 `initPalette`。

#### Scenario: initSprites 存在
- **WHEN** 检查 `EngineAPI.sprite` 表
- **THEN** `initSprites` SHALL 存在，`initPalette` SHALL NOT 存在