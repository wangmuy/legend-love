## 1. 基础架构搭建

- [x] 1.1 创建state_machine.lua模块，实现游戏状态机基础框架
- [x] 1.2 创建input_manager.lua模块，实现输入事件队列和事件驱动输入处理
- [x] 1.3 创建event_bridge.lua模块，作为新旧架构的适配层

## 2. 主入口重构

- [x] 2.1 重构main.lua，移除自定义love.run，使用标准Love2D回调
- [x] 2.2 在main.lua中初始化状态机和输入管理器
- [x] 2.3 实现love.update回调，调用游戏逻辑更新
- [x] 2.4 实现love.draw回调，调用游戏渲染
- [x] 2.5 实现love.keypressed和love.keyreleased回调

## 3. 游戏循环重构

- [x] 3.1 修改jymain.lua中的Game_Cycle函数，拆分为update和draw逻辑
- [x] 3.2 将Game_MMap中的逻辑更新部分移到状态update
- [x] 3.3 将Game_MMap中的渲染部分移到状态draw
- [x] 3.4 将Game_SMap中的逻辑更新部分移到状态update
- [x] 3.5 将Game_SMap中的渲染部分移到状态draw
- [x] 3.6 移除Game_Cycle中的while循环和lib.Delay调用

## 4. 输入系统改造

- [x] 4.1 修改lib_love.lua中的GetKey函数，改为从事件队列读取
- [x] 4.2 实现输入事件队列，缓存love.keypressed事件
- [x] 4.3 保持EnableKeyRepeat API行为不变
- [x] 4.4 确保按键状态查询与原有行为一致

## 5. 状态管理实现

- [x] 5.1 注册GAME_START状态的update和draw处理器
- [x] 5.2 注册GAME_MMAP状态的update和draw处理器
- [x] 5.3 注册GAME_SMAP状态的update和draw处理器
- [x] 5.4 注册GAME_WMAP状态的update和draw处理器
- [x] 5.5 实现状态切换时的初始化和清理逻辑
- [x] 5.6 确保JY.Status变量与状态机同步

## 6. 渲染系统调整

- [x] 6.1 确保所有渲染调用在love.draw中执行
- [x] 6.2 调整ShowScreen调用位置到draw回调
- [x] 6.3 确保lib.DrawMMap在正确时机调用
- [x] 6.4 处理渐变显示(lib.ShowSlow)的时序

## 7. 定时和帧率控制

- [x] 7.1 使用love.timer.getDelta替代手动帧率控制
- [x] 7.2 调整CC.Frame相关逻辑适应新架构
- [x] 7.3 确保JY.MyTick等定时器正常工作

## 8. 单元测试

- [x] 8.1 编写state_machine.lua单元测试，验证状态注册、切换、清理
- [x] 8.2 编写input_manager.lua单元测试，验证事件队列和按键处理
- [x] 8.3 编写event_bridge.lua单元测试，验证API兼容性
- [x] 8.4 编写测试辅助工具，便于模块独立测试

## 9. 整体测试(手动)

- [x] 9.1 在关键路径添加详细日志输出(lib.Debug)
- [x] 9.2 验证script/oldevent/目录下事件脚本正常运行
- [x] 9.3 验证script/newevent/目录下事件脚本正常运行
- [x] 9.4 测试主地图移动和场景切换
- [x] 9.5 测试战斗系统(如可进入)
- [x] 9.6 测试菜单和对话框
- [x] 9.7 测试存档和读档功能
- [x] 9.8 对比重构前后游戏行为一致性
- [x] 9.9 收集用户测试反馈，通过日志分析问题
- [x] 9.10 修复用户报告的测试问题
