## 1. 修改菜单系统支持ESC返回

- [x] 1.1 修改 `MenuStateMachine:handleInput`，当 `isEsc == 1` 时支持ESC键关闭菜单
- [x] 1.2 修改 `MenuAsync.ShowMenu2Coroutine`，支持通过ESC键返回特殊值
- [ ] 1.3 测试横向菜单的ESC返回功能

## 2. 修改新游戏流程

- [x] 2.1 修改 `jymain_adapter.lua` 中的属性选择菜单调用，设置 `isEsc = 1`
- [x] 2.2 在 `startNewGame` 中处理ESC返回值，返回到开始菜单状态
- [x] 2.3 确保ESC返回时清理资源（清除绘制回调等）
- [ ] 2.4 测试ESC键返回开始菜单功能

## 3. 回归测试

- [ ] 3.1 测试正常属性选择流程（选择"是"进入游戏）
- [ ] 3.2 测试重新随机属性流程（选择"否"）
- [ ] 3.3 测试ESC返回开始菜单流程
- [ ] 3.4 测试其他菜单功能不受影响
