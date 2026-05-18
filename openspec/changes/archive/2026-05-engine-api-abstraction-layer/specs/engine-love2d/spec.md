## ADDED Requirements

### Requirement: Love2D 引擎实现

系统 SHALL 提供 `game/engine_love2d.lua`，实现全部 EngineAPI 接口，使用 Love2D API。

#### Scenario: 实现全部接口
- **WHEN** 加载 `engine_love2d.lua`
- **THEN** 返回的 EngineAPI 表 SHALL 包含所有 11 个模块的全部函数

#### Scenario: render.text 使用 love.graphics
- **WHEN** 调用 `EngineAPI.render.text(x, y, str, color, size)`
- **THEN** 内部 SHALL 调用 `love.graphics.print` 或 `love.graphics.printf`

#### Scenario: render.fillRect 使用 love.graphics
- **WHEN** 调用 `EngineAPI.render.fillRect(x1, y1, x2, y2, color)`
- **THEN** 内部 SHALL 调用 `love.graphics.rectangle("fill", ...)`

#### Scenario: sprite.draw 使用 love.graphics.draw
- **WHEN** 调用 `EngineAPI.sprite.draw(archiveId, spriteId, x, y, flags, alpha)`
- **THEN** 内部 SHALL 调用 `love.graphics.draw` 绘制缓存的纹理

#### Scenario: audio.playMusic 使用 love.audio
- **WHEN** 调用 `EngineAPI.audio.playMusic(filename)`
- **THEN** 内部 SHALL 调用 `love.audio.newSource(filename, "stream")` 并播放

#### Scenario: audio.playSFX 使用 love.audio
- **WHEN** 调用 `EngineAPI.audio.playSFX(filename)`
- **THEN** 内部 SHALL 调用 `love.audio.newSource(filename, "static")` 并播放

#### Scenario: file.exists 使用 love.filesystem
- **WHEN** 调用 `EngineAPI.file.exists(filename)`
- **THEN** 内部 SHALL 调用 `love.filesystem.getInfo(filename)`

#### Scenario: script.load 使用 love.filesystem.load
- **WHEN** 调用 `EngineAPI.script.load(path)`
- **THEN** 内部 SHALL 优先使用 `love.filesystem.load(path)`，回退到 `loadfile(path)`

### Requirement: 向后兼容

`engine_love2d.lua` SHALL 保持与现有 `lib_love.lua` 相同的行为，现有代码调用 `lib.*` 时 SHALL 能正常工作。

#### Scenario: lib 全局变量可用
- **WHEN** 加载 `engine_love2d.lua`
- **THEN** 全局 `lib` 变量 SHALL 被赋值，包含所有 EngineAPI 函数

#### Scenario: 现有 lib.Delay 行为不变
- **WHEN** 调用 `lib.Delay(100)`
- **THEN** 行为 SHALL 与当前 `lib_love.lua` 中的 `Delay` 一致

### Requirement: 消除 jymain.lua 中的 love 直接调用

`game/script/jymain.lua` 中 SHALL NOT 直接调用 `love.*` API，所有引擎操作 SHALL 通过 EngineAPI 进行。

#### Scenario: 无 love.filesystem 调用
- **WHEN** 搜索 `jymain.lua` 中的 `love.` 模式
- **THEN** SHALL NOT 存在任何匹配

#### Scenario: 使用 EngineAPI.file.exists
- **WHEN** `jymain.lua` 需要检查文件是否存在
- **THEN** SHALL 调用 `EngineAPI.file.exists()` 而非 `love.filesystem.getInfo()`

### Requirement: 消除 script_loader.lua 中的 love 直接调用

`game/script_loader.lua` SHALL 使用 `EngineAPI.script.load` 而非直接调用 `love.filesystem.load`。

#### Scenario: script_loader 使用 EngineAPI
- **WHEN** 加载 `script_loader.lua`
- **THEN** 内部 SHALL 调用 `EngineAPI.script.load()` 而非 `love.filesystem.load()`