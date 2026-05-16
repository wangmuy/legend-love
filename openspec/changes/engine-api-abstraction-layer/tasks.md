## 1. EngineAPI 接口定义

- [ ] 1.1 创建 `game/engine_api.lua`，定义 EngineAPI 表结构和 11 个模块的空函数签名
- [ ] 1.2 实现 render 模块接口（text/fillRect/rectOutline/drawBackground/setClip/present/presentAndWait）
- [ ] 1.3 实现 sprite 模块接口（initSprites/loadArchive/getSize/draw）
- [ ] 1.4 实现 map 模块接口（loadMain/loadScene/saveScene/loadBattle/drawMain/drawScene/drawBattle）
- [ ] 1.5 实现 input 模块接口（getKey/waitForKey/setKeyRepeat）
- [ ] 1.6 实现 audio 模块接口（playMusic/playSFX/stopMusic）
- [ ] 1.7 实现 time 模块接口（sleep/getTime）
- [ ] 1.8 实现 file 模块接口（open/remove/getSize/exists）
- [ ] 1.9 实现 script 模块接口（load）
- [ ] 1.10 实现 font 模块接口（get）
- [ ] 1.11 实现 color 模块接口（pack/unpack）
- [ ] 1.12 实现 debug 模块接口（log）
- [ ] 1.13 实现 coroutine 模块接口（isRunning/yieldPoint/waitFor）
- [ ] 1.14 在接口文档注释中标记 yieldable 函数
- [ ] 1.15 编写 EngineAPI 接口的单元测试（验证所有函数签名存在）

## 2. Love2D 引擎实现

- [ ] 2.1 创建 `game/engine_love2d.lua`，从 `lib_love.lua` 复制所有实现代码
- [ ] 2.2 重构 render 模块：将 lib_love 中的 DrawStr/FillColor/Background/DrawRect/SetClip/ShowSurface/ShowSlow 迁移到 EngineAPI.render
- [ ] 2.3 重构 sprite 模块：将 PicInit/PicLoadFile/PicGetXY/PicLoadCache 迁移到 EngineAPI.sprite，重命名 initPalette → initSprites
- [ ] 2.4 重构 map 模块：将 LoadMMap/LoadSMap/SaveSMap/LoadWarMap/DrawMMap/DrawSMap/DrawWarMap 迁移到 EngineAPI.map
- [ ] 2.5 重构 input 模块：将 GetKey/EnableKeyRepeat 迁移到 EngineAPI.input
- [ ] 2.6 重构 audio 模块：将 PlayMIDI/PlayWAV/PlayMPEG 迁移到 EngineAPI.audio
- [ ] 2.7 重构 time 模块：将 Delay/GetTime 迁移到 EngineAPI.time
- [ ] 2.8 重构 font 模块：将内部 getFont 函数迁移到 EngineAPI.font
- [ ] 2.9 设置全局 `lib` 变量指向 EngineAPI，保持向后兼容
- [ ] 2.10 修改 `game/script/jymain.lua` 中 3 处 `love.filesystem` 调用为 `EngineAPI.file.*`
- [ ] 2.11 修改 `game/script_loader.lua` 使用 `EngineAPI.script.load`
- [ ] 2.12 验证游戏在 Love2D 下正常运行（人工测试）

## 3. 命令行测试引擎

- [ ] 3.1 创建 `game/engine_test.lua`，实现全部 EngineAPI 接口
- [ ] 3.2 render 模块：所有函数为空操作，可选记录调用日志
- [ ] 3.3 sprite 模块：loadArchive 解析文件头获取尺寸但不创建纹理，draw 为空操作
- [ ] 3.4 map 模块：load* 正常加载数据，draw* 为空操作
- [ ] 3.5 input 模块：getKey 返回 -1，waitForKey 从预设队列返回值
- [ ] 3.6 audio 模块：所有函数为空操作
- [ ] 3.7 time 模块：sleep 直接返回，getTime 返回 os.clock
- [ ] 3.8 file/script/font/color/debug 模块：正常实现
- [ ] 3.9 实现调用日志记录功能（_logEnabled/_callLog）
- [ ] 3.10 编写测试引擎的单元测试

## 4. 事件驱动适配层

- [ ] 4.1 重构 `game/async_globals.lua` 为基于 EngineAPI yieldable 函数
- [ ] 4.2 实现 `EngineAPI.coroutine.isRunning()` 检测是否在协程中
- [ ] 4.3 实现 `EngineAPI.coroutine.yieldPoint()` 标记 yield 点
- [ ] 4.4 实现 `EngineAPI.coroutine.waitFor(condition)` 等待条件满足
- [ ] 4.5 重构 `install()` 函数：基于 EngineAPI 替换全局函数
- [ ] 4.6 重构 `uninstall()` 函数：恢复原始全局函数
- [ ] 4.7 验证 oldevent 脚本在协程中正常执行
- [ ] 4.8 验证 newevent 脚本在协程中正常执行

## 5. 集成测试与验证

- [ ] 5.1 使用 engine_test.lua 运行所有现有单元测试
- [ ] 5.2 编写 EngineAPI 集成测试（验证 Love2D 引擎和测试引擎行为一致）
- [ ] 5.3 验证 `jymain.lua` 中无 `love.*` 直接调用
- [ ] 5.4 验证 `script_loader.lua` 中无 `love.*` 直接调用
- [ ] 5.5 报告不可自动化测试的内容（渲染/音频/性能）
- [ ] 5.6 更新 `ENGINE_API_DESIGN.md` 为最终版本
- [ ] 5.7 更新 `AGENTS.md` 添加 EngineAPI 相关说明