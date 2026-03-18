## 1. 基础异步函数完善

- [x] 1.1 扩展 AsyncDialog 添加 showMessageCoroutine 函数
- [x] 1.2 扩展 AsyncDialog 添加 showYesNoCoroutine 函数
- [x] 1.3 扩展 InputAsync 添加 WaitKeyCoroutine 函数

## 2. 消息框系统改造

- [x] 2.1 创建 async_message_box.lua 模块
- [x] 2.2 实现 DrawStrBoxWaitKey 的协程版本
- [x] 2.3 实现 DrawStrBoxYesNo 的协程版本
- [x] 2.4 在 jymain.lua 中添加旧函数的废弃警告
- [x] 2.5 替换 jymain.lua 中所有 DrawStrBoxWaitKey 调用
- [x] 2.6 替换 jymain.lua 中所有 DrawStrBoxYesNo 调用
- [x] 2.7 替换 jymodify.lua 中的阻塞调用
- [x] 2.8 替换 newevent/*.lua 中的阻塞调用

## 3. 对话系统改造

- [x] 3.1 分析 TalkEx 函数的执行流程
- [x] 3.2 创建 TalkAsync 模块
- [x] 3.3 实现对话显示的协程版本 TalkExCoroutine
- [x] 3.4 实现对话分页的异步等待
- [x] 3.5 实现头像显示的异步管理
- [x] 3.6 修改 instruct_1 使用协程版本

## 4. 菜单系统完善

- [x] 4.1 确认 MenuAsync.ShowMenuCoroutine 正常工作
- [x] 4.2 确认 MenuAsync.ShowMenu2Coroutine 正常工作
- [x] 4.3 替换 jymain.lua 中所有 ShowMenu 调用为协程版本
- [x] 4.4 替换 jymain.lua 中所有 ShowMenu2 调用为协程版本
- [x] 4.5 替换 jymodify.lua 中的菜单调用
- [x] 4.6 替换 newevent/*.lua 中的菜单调用
- [x] 4.7 改造 MMenu 主菜单为协程版本
- [x] 4.8 在旧 ShowMenu/ShowMenu2 函数中添加废弃警告

## 5. 事件指令系统改造

- [x] 5.1 创建 instruct_async.lua 模块
- [x] 5.2 实现 instruct_1 对话指令的协程版本
- [x] 5.3 实现 instruct_2 得到物品指令的协程版本
- [x] 5.4 实现 instruct_5 选择战斗指令的协程版本
- [x] 5.5 实现 instruct_6 战斗指令的协程版本
- [x] 5.6 实现 instruct_9 加入队伍指令的协程版本
- [x] 5.7 实现 instruct_12 住宿指令的协程版本
- [x] 5.8 实现 instruct_27 显示动画指令的协程版本
- [x] 5.9 实现 instruct_30 主角走动指令的协程版本
- [x] 5.10 实现 instruct_58 武道大会指令的协程版本
- [x] 5.11 实现 instruct_64 小宝卖东西指令的协程版本
- [x] 5.12 改造其他 instruct_XXX 指令（约60个）
- [x] 5.13 修改 EventExecute 支持协程执行

## 6. 战斗状态处理器

- [x] 6.1 创建 GAME_WMAP 状态处理器框架
- [x] 6.2 实现 enter 处理器：加载战斗资源
- [x] 6.3 实现 update 处理器：更新战斗逻辑
- [x] 6.4 实现 draw 处理器：渲染战斗画面
- [x] 6.5 实现 exit 处理器：清理战斗资源
- [x] 6.6 在 GameStates.registerAll 中注册 GAME_WMAP

## 7. 战斗主函数改造

- [x] 7.1 分析 WarMain 战斗主循环结构
- [x] 7.2 创建 WarAsync 模块
- [x] 7.3 将 WarMain 改造为协程入口函数
- [x] 7.4 改造战斗主循环为协程状态驱动
- [x] 7.5 改造 WarSelectTeam 选择队伍
- [x] 7.6 改造 WarSelectEnemy 选择敌人
- [x] 7.7 改造 WarLoadMap 加载战斗地图

## 8. 战斗菜单改造

- [x] 8.1 改造 War_Manual_Sub 手动战斗菜单
- [x] 8.2 改造攻击目标选择菜单
- [x] 8.3 改造移动位置选择
- [x] 8.4 改造 War_ThingMenu 战斗物品菜单
- [x] 8.5 改造 War_StatusMenu 战斗状态显示
- [x] 8.6 改造 War_AutoMenu 自动战斗设置
- [x] 8.7 改造 War_WaitMenu 等待菜单
- [x] 8.8 测试战斗菜单操作

## 9. 战斗执行改造

- [x] 9.1 改造 War_Fight_Sub 执行战斗
- [x] 9.2 改造 War_ShowFight 显示战斗动画
- [x] 9.3 改造 War_Auto 自动战斗
- [x] 9.4 改造战斗结算流程
- [x] 9.5 改造经验分配和升级显示

## 10. 状态机同步完善

- [x] 10.1 确保 StateMachine:update 正确同步 JY.Status
- [x] 10.2 添加状态历史记录功能
- [x] 10.3 实现战斗结束后返回上一状态
- [x] 10.4 处理状态切换时的资源竞争

## 11. 代码清理

- [x] 11.1 移除或标记所有废弃函数
- [x] 11.2 添加代码注释说明异步改造
- [x] 11.3 更新 ARCHITECTURE.md 文档
- [ ] 11.4 清理调试日志
- [ ] 11.5 代码格式化和整理

## 改造总结

### 核心改造完成项

1. **协程调度器** - `coroutine_scheduler.lua`
   - waitForKey()、waitForTime()、waitForCondition()
   
2. **状态机** - `state_machine.lua`
   - 自动同步 JY.Status
   - 状态历史记录
   - returnToPrevious() 战斗结束返回

3. **输入系统** - `input_manager.lua` + `input_async.lua`
   - 事件驱动输入
   - WaitKeyCoroutine

4. **菜单系统** - `menu_async.lua` + `menu_state_machine.lua`
   - ShowMenuCoroutine
   - ShowMenu2Coroutine

5. **对话系统** - `talk_async.lua`
   - TalkExCoroutine
   - 分页、头像显示

6. **战斗系统** - `war_async.lua`
   - WarMainCoroutine
   - 所有战斗菜单协程版本

7. **事件指令** - `instruct_async.lua`
   - 所有 67 个 instruct_XXX 协程版本

8. **全局替换** - `async_globals.lua`
   - 自动检测协程环境
   - 替换 DrawStrBoxWaitKey、DrawStrBoxYesNo、WaitKey、ShowMenu、ShowMenu2、TalkEx、lib.Delay

9. **事件执行器** - `event_executor.lua`
   - EventExecuteSync
   - 自动安装/卸载 AsyncGlobals

10. **游戏状态** - `game_states.lua`
    - GAME_START, GAME_MMAP, GAME_SMAP, GAME_WMAP, GAME_FIRSTMMAP
    - startMenuCoroutine 替代 MMenu
    - EventExecuteSync 替代 EventExecute