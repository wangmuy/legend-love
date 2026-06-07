## 1. EngineAPI Web 实现

- [ ] 1.1 实现 render 模块（text、fillRect、rectOutline、drawBackground、setClip、present、presentAndWait）
- [ ] 1.2 实现 input 模块（getKey、waitForKey、setKeyRepeat）
- [ ] 1.3 实现 time 模块（sleep、getTime、getTimeSeconds）
- [ ] 1.4 实现 file 模块（open、remove、getSize、exists、read、write、lines、createDirectory）
- [ ] 1.5 实现 script 模块（load）
- [ ] 1.6 实现 font 模块（get）
- [ ] 1.7 实现 color 模块（pack、unpack）
- [ ] 1.8 实现 debug 模块（log）
- [ ] 1.9 实现 coroutine 模块（isRunning、yieldPoint、waitFor）
- [ ] 1.10 实现 sprite 模块（全部 no-op）
- [ ] 1.11 实现 map 模块（全部 no-op）
- [ ] 1.12 实现 audio 模块（全部 no-op）
- [ ] 1.13 实现 app 模块（quit — no-op）
- [ ] 1.14 设置 `_G.EngineAPI` 和 `_G.lib` 全局变量
- [ ] 1.15 ANSI 颜色映射函数

## 2. 验证

- [ ] 2.1 单元测试：在纯 Lua 环境（非浏览器）加载 engine_web.lua
- [ ] 2.2 验证所有 37 个函数存在且签名正确
- [ ] 2.3 验证 render.text 产出 ANSI 转义码
- [ ] 2.4 验证 color.pack/unpack 正确
- [ ] 2.5 验证 sleep 立即返回（不阻塞）