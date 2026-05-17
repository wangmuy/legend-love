## 1. EngineAPI 接口定义

- [x] 1.1 创建 `game/engine_api.lua`，定义 EngineAPI 表结构和 11 个模块的空函数签名
- [x] 1.2 实现 render 模块接口（text/fillRect/rectOutline/drawBackground/setClip/present/presentAndWait）
- [x] 1.3 实现 sprite 模块接口（initSprites/loadArchive/getSize/draw）
- [x] 1.4 实现 map 模块接口（loadMain/loadScene/saveScene/loadBattle/drawMain/drawScene/drawBattle）
- [x] 1.5 实现 input 模块接口（getKey/waitForKey/setKeyRepeat）
- [x] 1.6 实现 audio 模块接口（playMusic/playSFX/stopMusic）
- [x] 1.7 实现 time 模块接口（sleep/getTime）
- [x] 1.8 实现 file 模块接口（open/remove/getSize/exists）
- [x] 1.9 实现 script 模块接口（load）
- [x] 1.10 实现 font 模块接口（get）
- [x] 1.11 实现 color 模块接口（pack/unpack）
- [x] 1.12 实现 debug 模块接口（log）
- [x] 1.13 实现 coroutine 模块接口（isRunning/yieldPoint/waitFor）
- [x] 1.14 在接口文档注释中标记 yieldable 函数
- [x] 1.15 编写 EngineAPI 接口的单元测试（验证所有函数签名存在）

## 2. Love2D 引擎实现

- [x] 2.1 创建 `game/engine_love2d.lua`，从 `lib_love.lua` 复制所有实现代码
- [x] 2.2 重构 render 模块：将 lib_love 中的 DrawStr/FillColor/Background/DrawRect/SetClip/ShowSurface/ShowSlow 迁移到 EngineAPI.render
- [x] 2.3 重构 sprite 模块：将 PicInit/PicLoadFile/PicGetXY/PicLoadCache 迁移到 EngineAPI.sprite，重命名 initPalette → initSprites
- [x] 2.4 重构 map 模块：将 LoadMMap/LoadSMap/SaveSMap/LoadWarMap/DrawMMap/DrawSMap/DrawWarMap 迁移到 EngineAPI.map
- [x] 2.5 重构 input 模块：将 GetKey/EnableKeyRepeat 迁移到 EngineAPI.input
- [x] 2.6 重构 audio 模块：将 PlayMIDI/PlayWAV/PlayMPEG 迁移到 EngineAPI.audio
- [x] 2.7 重构 time 模块：将 Delay/GetTime 迁移到 EngineAPI.time
- [x] 2.8 重构 font 模块：将内部 getFont 函数迁移到 EngineAPI.font
- [x] 2.9 设置全局 `lib` 变量指向 EngineAPI，保持向后兼容
- [x] 2.10 修改 `game/script/jymain.lua` 中 3 处 `love.filesystem` 调用为 `EngineAPI.file.*`
- [x] 2.11 修改 `game/script_loader.lua` 使用 `EngineAPI.script.load`
- [ ] 2.12 验证游戏在 Love2D 下正常运行（人工测试）

## 3. 命令行测试引擎

- [x] 3.1 创建 `game/engine_test.lua`，实现全部 EngineAPI 接口
- [x] 3.2 render 模块：所有函数为空操作，可选记录调用日志
- [x] 3.3 sprite 模块：loadArchive 解析文件头获取尺寸但不创建纹理，draw 为空操作
- [x] 3.4 map 模块：load* 正常加载数据，draw* 为空操作
- [x] 3.5 input 模块：getKey 返回 -1，waitForKey 从预设队列返回值
- [x] 3.6 audio 模块：所有函数为空操作
- [x] 3.7 time 模块：sleep 直接返回，getTime 返回 os.clock
- [x] 3.8 file/script/font/color/debug 模块：正常实现
- [x] 3.9 实现调用日志记录功能（_logEnabled/_callLog）
- [x] 3.10 编写测试引擎的单元测试

## 4. 事件驱动适配层

- [x] 4.1 重构 `game/async_globals.lua` 为基于 EngineAPI yieldable 函数
- [x] 4.2 实现 `EngineAPI.coroutine.isRunning()` 检测是否在协程中
- [x] 4.3 实现 `EngineAPI.coroutine.yieldPoint()` 标记 yield 点
- [x] 4.4 实现 `EngineAPI.coroutine.waitFor(condition)` 等待条件满足
- [x] 4.5 重构 `install()` 函数：基于 EngineAPI 替换全局函数
- [x] 4.6 重构 `uninstall()` 函数：恢复原始全局函数
- [ ] 4.7 验证 oldevent 脚本在协程中正常执行
- [ ] 4.8 验证 newevent 脚本在协程中正常执行

## 5. 集成测试与验证

- [x] 5.1 使用 engine_test.lua 运行所有现有单元测试
- [x] 5.2 编写 EngineAPI 集成测试（验证 Love2D 引擎和测试引擎行为一致）
- [x] 5.3 验证 `jymain.lua` 中无 `love.*` 直接调用
- [x] 5.4 验证 `script_loader.lua` 中无 `love.*` 直接调用
- [x] 5.5 报告不可自动化测试的内容（渲染/音频/性能）
- [x] 5.6 更新 `ENGINE_API_DESIGN.md` 为最终版本
- [x] 5.7 更新 `AGENTS.md` 添加 EngineAPI 相关说明

## 6. 目录结构调整

- [x] 6.1 删除废弃文件 event_coroutine.lua、instruct_async.lua、convert.lua
- [x] 6.2 创建 `game/engine-love2d/`，移入 engine_api.lua、engine_love2d.lua、lib_love.lua
- [x] 6.3 创建 `game/engine-mud/`，以 engine_test.lua 为初版创建 engine_mud.lua（文本命令行界面引擎）
- [x] 6.4 将 engine_test.lua 移入 `game/tests/`
- [x] 6.5 创建 `game/framework/`，移入所有框架层文件（event_bridge / state_machine / 异步模块 / 工具模块 / config.lua / script_loader.lua / jymain_adapter.lua）
- [x] 6.6 更新所有文件的 require 路径指向新目录
- [x] 6.7 从 main.lua 中抽取 Love2D 特有初始化到 engine-love2d/ 的 init()
- [x] 6.8 更新测试文件中的 require 路径
- [x] 6.9 运行全部测试验证
- [x] 6.10 人工验证游戏正常运行（修复 lib_love.lua 中 package.loaded 路径不匹配问题）

## 7. 消除 framework/ 中的 Love2D 直接引用

- [ ] 7.1 将 input_manager.lua 中的 `love.timer.getTime()` 替换为 `EngineAPI.time.getTime()`
- [ ] 7.2 将 input_async.lua 中的 `love.timer.getTime()` 替换为 `EngineAPI.time.getTime()`
- [ ] 7.3 将 coroutine_scheduler.lua 中的 `love.timer.getTime` 替换为 `EngineAPI.time.getTime`
- [ ] 7.4 将 perf_log.lua 中的 `love.timer.getTime()` 替换为 `EngineAPI.time.getTime()`
- [ ] 7.5 将 lib_file.lua 中的 `love.filesystem.*` 替换为 `EngineAPI.file.*`
- [ ] 7.6 将 script_loader.lua 中的 `love.filesystem.load` 替换为 `EngineAPI.script.load`
- [ ] 7.7 在 EngineAPI 中新增 `quit()` 函数，替换 `love.event.quit()`
- [ ] 7.8 将 jymain_adapter.lua、game_states.lua、war_async.lua 中的 `love.event.quit()` 替换为 `EngineAPI.quit()`
- [ ] 7.9 运行全部测试验证
- [ ] 7.10 人工验证游戏正常运行