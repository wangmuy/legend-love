## 为什么

Web MUD 需要一个 EngineAPI 的 Web 实现，将图形/音频/输入等操作映射为浏览器终端的等效操作。

## 变更内容

- 新增 `www/engine/engine_web.lua`，实现所有 37 个 EngineAPI 函数
- 所有 sprite/map/audio 函数为 no-op
- render 函数输出 ANSI 转义码
- input 函数通过 JS 桥接读取键盘输入
- file 函数通过预加载的数据表读取

## 能力

### 新增能力
- `engine-web-core`: EngineAPI 的 Web/终端实现

### 修改的能力
- 无

## 影响

- 新增 `www/engine/engine_web.lua`
- 设置 `_G.EngineAPI` 和 `_G.lib`
- 依赖 JS 桥接函数（由 web-frontend-shell 提供）