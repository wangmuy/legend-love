## ADDED Requirements

### Requirement:  EngineAPI 完整性

engine_web.lua SHALL 实现 engine_api.lua 定义的所有 37 个函数。

#### Scenario: 所有 render 函数存在
- **WHEN** engine_web.lua 加载完成
- **THEN** EngineAPI.render.text 存在
- **AND** EngineAPI.render.fillRect 存在
- **AND** EngineAPI.render.rectOutline 存在
- **AND** EngineAPI.render.drawBackground 存在
- **AND** EngineAPI.render.setClip 存在
- **AND** EngineAPI.render.present 存在
- **AND** EngineAPI.render.presentAndWait 存在

#### Scenario:  sprite/map/audio 函数为 no-op
- **WHEN** 调用 sprite.draw
- **THEN** 函数立即返回，不产生输出
- **WHEN** 调用 map.drawMain
- **THEN** 函数立即返回，不产生输出
- **WHEN** 调用 audio.playMusic
- **THEN** 函数立即返回，不产生输出

### Requirement:  ANSI 输出

render.text SHALL 将输出转换为 ANSI 转义码。

#### Scenario: 普通文本输出
- **WHEN** 调用 EngineAPI.render.text(0, 0, "Hello", nil, nil)
- **AND** 随后调用 EngineAPI.render.present()
- **THEN** 通过 JSBridge.write 输出 ANSI 字符串
- **AND** 字符串包含 "\027[37mHello\027[0m"（默认白色）

#### Scenario: 彩色文本输出
- **WHEN** 调用 EngineAPI.render.text(0, 0, "Error", {216/255, 20/255, 24/255}, nil)
- **AND** 随后调用 EngineAPI.render.present()
- **THEN** 输出包含 ANSI 红色转义码

### Requirement:  输入处理

input.waitForKey SHALL 等待用户输入后恢复协程。

#### Scenario: 等待按键
- **WHEN** 协程调用 EngineAPI.input.waitForKey()
- **THEN** 协程 yield
- **WHEN** JS 侧 pushEvent({type="input", key=65})
- **THEN** waitForKey 返回 65

### Requirement:  时间处理

time.sleep SHALL 立即 yield 并返回，不等待真实时间。

#### Scenario: sleep 不阻塞
- **WHEN** 协程调用 EngineAPI.time.sleep(1000)
- **THEN** 协程 yield
- **AND** 下一个 tick 立即恢复
- **AND** 不等待 1000ms 真实时间