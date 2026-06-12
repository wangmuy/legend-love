## 为什么

engine_web.lua 和 data_loader.lua 已实现，但缺乏自动化测试保障。
手动使用 agent-browser 验证了功能，但不可重复。需要一套 Playwright E2E
测试，确保后续修改不破坏现有行为。同时需要纯 Lua 单元测试覆盖 core 逻辑。

## 变更内容

- `game/engine-web/tests/playwright.config.js` — Playwright 配置
- `game/engine-web/tests/page-load.spec.js` — 页面加载基础测试 (Layer 1)
- `game/engine-web/tests/lua-vm.spec.js` — Lua VM 初始化测试 (Layer 2)
- `game/engine-web/tests/engine-api.spec.js` — API 表面 + 功能测试 (Layer 3-4)
- `game/engine-web/tests/data-integrity.spec.js` — 数据完整性测试 (Layer 5-6)
- `game/engine-web/tests/interaction.spec.js` — 交互流程测试 (Layer 7)
- `game/engine-web/tests/error-handling.spec.js` — 错误场景测试 (Layer 8)
- `game/engine-web/tests/state-persistence.spec.js` — 状态持久化测试 (Layer 9)
- `game/engine-web/tests/helpers/setup.js` — 测试通用工具（waitForPageReady、luaEval、getLuaGlobal）
- `game/engine-web/package.json` — 新增 `@playwright/test` devDependency + test script

## 能力

### 新增能力
- `engine-web-tests`: 59 条自动化测试用例覆盖 7 个 spec 文件（含状态持久化 9 条）

### 修改的能力
- 无

## 影响

- 新增 `game/engine-web/tests/` 目录（8 个 spec 文件 + helpers）
- `package.json` 新增 `@playwright/test` devDependency
- `package.json` 新增 `npm run test` / `npm run test:ui` 脚本
- 依赖 Playwright（浏览器自动化）
- 不影响现有代码，纯新增