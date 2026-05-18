## ADDED Requirements

### Requirement: 命令行测试引擎

系统 SHALL 提供 `game/engine_test.lua`，实现全部 EngineAPI 接口，但所有渲染和音频操作为空操作，输入返回预设值。

#### Scenario: 实现全部接口
- **WHEN** 加载 `engine_test.lua`
- **THEN** 返回的 EngineAPI 表 SHALL 包含所有 11 个模块的全部函数

#### Scenario: 无窗口创建
- **WHEN** 加载 `engine_test.lua`
- **THEN** SHALL NOT 创建任何窗口或显示设备

#### Scenario: render 函数为空操作
- **WHEN** 调用任何 `EngineAPI.render.*` 函数
- **THEN** SHALL NOT 产生任何图形输出

#### Scenario: audio 函数为空操作
- **WHEN** 调用任何 `EngineAPI.audio.*` 函数
- **THEN** SHALL NOT 产生任何音频输出

#### Scenario: sprite 函数记录尺寸但不加载纹理
- **WHEN** 调用 `EngineAPI.sprite.loadArchive(idx, grp, id)`
- **THEN** SHALL 解析 idx/grp 文件头获取尺寸信息，但不创建纹理对象

#### Scenario: sprite.draw 为空操作
- **WHEN** 调用 `EngineAPI.sprite.draw(archiveId, spriteId, x, y, flags, alpha)`
- **THEN** SHALL NOT 产生任何图形输出

#### Scenario: map.draw 为空操作
- **WHEN** 调用任何 `EngineAPI.map.draw*` 函数
- **THEN** SHALL NOT 产生任何图形输出

### Requirement: 模拟输入

测试引擎 SHALL 支持预设按键队列，`waitForKey` 从队列中返回按键值。

#### Scenario: waitForKey 返回预设值
- **WHEN** 预设按键队列包含 `VK_SPACE`，然后调用 `EngineAPI.input.waitForKey()`
- **THEN** 返回 `VK_SPACE`

#### Scenario: getKey 返回 -1
- **WHEN** 调用 `EngineAPI.input.getKey()`
- **THEN** 返回 -1（表示无按键）

#### Scenario: 空队列时 waitForKey 立即返回
- **WHEN** 预设按键队列为空，然后调用 `EngineAPI.input.waitForKey()`
- **THEN** 返回 -1（不阻塞）

### Requirement: 计时行为

测试引擎的 `time.sleep` SHALL 直接返回而不等待。

#### Scenario: sleep 不等待
- **WHEN** 调用 `EngineAPI.time.sleep(1000)`
- **THEN** 立即返回，不阻塞

#### Scenario: getTime 返回 os.clock
- **WHEN** 调用 `EngineAPI.time.getTime()`
- **THEN** 返回 `os.clock() * 1000`

### Requirement: 文件操作正常

测试引擎的 `file.*` 函数 SHALL 执行真实的文件操作。

#### Scenario: file.open 正常
- **WHEN** 调用 `EngineAPI.file.open("test.txt", "r")`
- **THEN** 返回真实的文件句柄或 nil

#### Scenario: file.exists 正常
- **WHEN** 调用 `EngineAPI.file.exists("script/jyconst.lua")`
- **THEN** 返回 true

### Requirement: 调用日志记录

测试引擎 SHALL 可选记录所有 EngineAPI 调用到日志表，用于测试验证。

#### Scenario: 启用调用日志
- **WHEN** 设置 `EngineAPI._logEnabled = true`，然后调用 `EngineAPI.render.text(...)`
- **THEN** `EngineAPI._callLog` 表中 SHALL 包含一条 `{func="render.text", args={...}}` 记录

#### Scenario: 禁用调用日志
- **WHEN** 设置 `EngineAPI._logEnabled = false`
- **THEN** `EngineAPI._callLog` SHALL NOT 新增记录