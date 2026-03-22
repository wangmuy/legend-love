## 1. 实现纯事件驱动动画系统

- [x] 1.1 添加全局动画状态 `JY.AnimationState`
- [x] 1.2 修改 `GAME_SMAP.update`，添加动画驱动逻辑
- [x] 1.3 修改 `CoroutineScheduler:update`，支持 `waitingFor == "animation"`
- [ ] 1.4 测试动画状态驱动机制

## 2. 修改instruct_27使用动画状态

- [x] 2.1 修改 `instruct_27`，设置 `JY.AnimationState` 而不是直接修改 `JY.MyPic`
- [x] 2.2 使用 `scheduler:yield("animation")` 等待动画完成
- [x] 2.3 移除 `instruct_27` 中的 `DtoSMap()` 和 `waitForTime()` 调用
- [ ] 2.4 测试主角动画正确显示

## 3. 回归测试

- [ ] 3.1 测试软体娃娃动画（id=1）正常
- [ ] 3.2 测试其他场景动画正常
- [ ] 3.3 测试非动画期间主角显示正常
- [ ] 3.4 测试动画帧率符合原版（22帧，约3.3秒）
