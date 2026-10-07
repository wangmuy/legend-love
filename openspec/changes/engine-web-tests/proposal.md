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
- `game/engine-web/tests/helpers/walkthrough.js` — 攻略测试工具（saveTestState、loadTestState、gotoScene）
- `game/engine-web/tests/helpers/term.js` — 终端操作助手（cmd、getT、noE）
- `game/engine-web/tests/walkthrough-p1.spec.js` ~ `p7` — 7 个攻略 E2E 测试，覆盖 50+ 场景
- `game/engine-web/package.json` — 新增 `@playwright/test` devDependency + test script

## 能力

### 新增能力
- `engine-web-tests`: 59+ 条自动化测试用例覆盖 7+ 个 spec 文件
- `walkthrough-p1~p7`: 7 个攻略 E2E 测试，按 quick_pass_game.md 顺序覆盖 50+ 场景
- 每个测试在 5 分钟内完成，开始加载存档，结束保存存档
- bridge cache 链式传递机制（P1→bridge-p1.json→P2→...→P7→bridge-p7.json）

### 已修复的 Bug
- web_game_bridge.lua: HEAD_NAME_MAP 添加 [4]="阎基"
- wmap_handlers.lua: 战斗系统 3 个 bug（攻击距离用错变量、伤害公式忽略攻击力、队友属性缺失）
- state_manager.lua: save/load 默认值（JY.Status 默认为 2）

### 游戏完成度
- 14天书中 12 个场景有数据，2 个缺失（雪山飞狐/闯王山洞、鸳鸯刀/鸳鸯岛）
- 圣堂无入口数据，无法导航到达
- **结论**: 需 MUD 数据完善后才能实现完整通关测试（14天书收集 → 圣堂最终战）

## 影响

- 新增 `game/engine-web/tests/` 目录（8 个 spec 文件 + helpers）
- `package.json` 新增 `@playwright/test` devDependency
- `package.json` 新增 `npm run test` / `npm run test:ui` 脚本
- 依赖 Playwright（浏览器自动化）
- 不影响现有代码，纯新增