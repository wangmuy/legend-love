## 1. 输入处理

- [x] 1.1 processEventQueue 从 JSBridge 拉取输入事件
- [x] 1.2 choose N + 有活动菜单 → MenuAsync.closeMenu(N)
- [x] 1.3 其他命令 → CommandEngine.dispatchCommand

## 2. processEventQueue 集成

- [x] 2.1 processEventQueue 调用 CoroutineScheduler:update(dt)
- [x] 2.2 processEventQueue 调用 StateMachine:update(dt)
- [x] 2.3 选择 N 处理（有/无菜单两种分支）

## 3. framework 模块加载

- [x] 3.1 建立 package.preload 映射加载所有 framework/*.lua
- [x] 3.2 加载 jymain.lua / jyconst.lua / jymodify.lua 脚本
- [x] 3.3 处理 require 循环依赖（如 coroutine_scheduler 依赖 input_manager）
- [x] 3.4 脚本错误处理：pcall 保护 + 日志输出

## 4. 兼容函数映射

- [x] 4.1 Cls / ShowScreen / DrawString / DrawBox 映射到 EngineAPI.render
- [x] 4.2 DrawMMap / DrawSMap 重定向到 WebUI 函数
- [x] 4.3 DrawHead / DrawHeadPic 等人物头像函数 no-op

## 5. 开始菜单 + 属性选择文字版

- [x] 5.1 开始菜单文字渲染：显示 1.重新开始 2.载入进度 3.离开游戏
- [x] 5.2 choose N 选择菜单项
- [x] 5.3 属性选择界面文字渲染：随机属性 + 是/否 选择（覆盖 JYMainAdapter.startNewGame）
- [x] 5.4 JYMainAdapter.init() 完整流程可运行到进入大地图
- [x] 5.5 排版修复：xterm.js convertEol: true，WebUI.title/separator 使用 JSBridge.write
- [x] 5.6 idle 状态不清屏，避免输出被 drawBackground 清除

## 6. 验证

- [x] 6.1 E2E 测试：开始菜单 → 属性选择 → 进入大地图
- [x] 6.2 E2E 测试：choose N 关闭菜单
- [x] 6.3 E2E 测试：choose N 无菜单时提示
- [x] 6.4 E2E 测试：按 ESC 返回开始菜单（choose 0）

## 7. Web MUD 集成稳定性

- [x] 7.1 属性选择提示添加 choose 0 返回开始菜单选项
- [x] 7.2 覆写 loadGame：无存档时显示提示并返回开始菜单
- [x] 7.3 覆写 Init_MMap/Init_SMap/CleanMemory 为 MUD 安全版本（仅设状态变量，不加载文件）
- [x] 7.4 覆写 MMAP/SMAP 状态处理器为 no-op，防止 game_states 渲染/更新出错
- [x] 7.5 lib 添加桩函数：LoadMMap, GetMMap, UnloadMMap, PicLoadFile, GetS, SetS, GetD, SetD