## 1. 加载 EventExecutor
Traceability: [REQ-001]

- [x] 1.1 加载 event_executor + 依赖模块
  Blast Radius: `["game/engine-web/web_game_bridge.lua"]`
  DoD:
    - [x] `require("framework.event_executor")` 不报错
    - [x] `require("framework.async_globals")` 不报错
    - [x] `require("framework.script_loader")` 不报错
    - [x] `_G.EventExecutor` 为 table 类型

- [x] 1.2 将 oldevent 脚本注册到 FrameworkSources
  Blast Radius: `["game/engine-web/worker.js", "game/engine-web/index.js"]`
  DoD:
    - [x] `FrameworkSources["script/oldevent/oldevent_691.lua"]` 存在
    - [x] `ScriptLoader.load("script/oldevent/oldevent_691.lua")` 返回函数

- [x] 1.3 修复 smapNpcTalk 中 EventExecutor 调用
  Blast Radius: `["game/engine-web/mmap_smap_handlers.lua"]`
  DoD:
    - [x] `EventExecutor.startEvent(eventId, 0, callback)` 正常执行
    - [x] 回调后回到场景
