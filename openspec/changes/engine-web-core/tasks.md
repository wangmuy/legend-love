## 1. EngineAPI Web 实现

- [x] 1.1 实现 render 模块（text、fillRect、rectOutline、drawBackground、setClip、present、presentAndWait）
- [x] 1.2 实现 input 模块（getKey、waitForKey、setKeyRepeat）
- [x] 1.3 实现 time 模块（sleep、getTime、getTimeSeconds）
- [x] 1.4 实现 file 模块（open、openFile、remove、getSize、exists、read、write、lines、createDirectory）
- [x] 1.5 实现 script 模块（load）
- [x] 1.6 实现 font 模块（get）
- [x] 1.7 实现 color 模块（pack、unpack）
- [x] 1.8 实现 debug 模块（log）
- [x] 1.9 实现 coroutine 模块（isRunning、yieldPoint、waitFor）
- [x] 1.10 实现 sprite 模块（全部 no-op）
- [x] 1.11 实现 map 模块（全部 no-op）
- [x] 1.12 实现 audio 模块（全部 no-op）
- [x] 1.13 实现 app 模块（quit — no-op）
- [x] 1.14 设置 `_G.EngineAPI` 和 `_G.lib` 全局变量
- [x] 1.15 ANSI 颜色映射函数（colorToAnsi）

> 共计 45 个函数，13 个模块。

## 2. 验证

- [x] 2.1 E2E 测试：engine-api.spec.js 验证所有 45 个函数签名
- [x] 2.2 验证 render.text 产出 ANSI 转义码
- [x] 2.3 验证 color.pack/unpack 往返正确
- [x] 2.4 验证 time.sleep yield 后立即恢复（不阻塞）
- [x] 2.5 验证 file.open / file.exists / file.lines / file.getSize / script.load
- [x] 2.6 验证 debug.log 写入终端、app.quit no-op
