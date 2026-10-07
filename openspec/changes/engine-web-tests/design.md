## 测试架构

```
tests/
├── playwright.config.js        ← 浏览器配置（Chromium headless，1 worker，webServer 管理服务器生命周期）
├── helpers/
│   └── setup.js                ← waitForPageReady() + luaEval() + getLuaGlobal()
├── page-load.spec.js           ← 页面加载基础（4 条）
├── lua-vm.spec.js              ← Lua VM 初始化（4 条）
├── engine-api.spec.js          ← API 表面 + 功能（16 条）
├── data-integrity.spec.js      ← 数据 + 引用（12 条）
├── interaction.spec.js         ← 交互流程（2 条）
├── error-handling.spec.js      ← 错误场景（5 条）
├── state-persistence.spec.js   ← 状态持久化（9 条）
├── mmap-smap.spec.js           ← MMAP/SMAP 命令（9 条）
├── s3-integration.spec.js      ← Slice 3 完整流程集成（7 条）
└── s3-menu-test.spec.js        ← 菜单选择测试（已合并到 s3-integration）
```

## 运行方式

```bash
# 安装 Playwright
cd game/engine-web && npm install && npx playwright install chromium

# 运行所有测试
npm test

# 带 UI 模式调试
npm run test:ui

# 指定文件
npx playwright test tests/engine-api.spec.js
```

## 测试流程

```
npm test
  │
  ├─ 1. 启动 HTTP 服务器 (Node.js, 端口 8088, 无缓存)
  ├─ 2. Playwright 打开 Chromium → localhost:8088
  ├─ 3. 等待终端显示 "System ready" (最长 30s)
  ├─ 4. 逐条执行测试用例
  │    ├─ page.evaluate() 查询 DOM
  │    ├─ page.evaluate() 调 fengari API 检查 Lua 状态
  │    └─ page.evaluate() 输入模拟 + 检查终端输出
  └─ 5. 关闭服务器 + 浏览器 → 输出结果
```

## 读取终端文本

xterm.js 渲染在 canvas/grid 中，不能用 DOM querySelector 可靠读取。
使用 xterm.js buffer API 直接提取行数据。`getTermLines` 和 `hasNoGameErrors` 等辅助函数直接内联在各 spec 文件中，而非独立模块：

```javascript
// 在各 spec 文件中内联
async function getTermLines(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return [];
    const lines = [];
    for (let y = 0; y < term.buffer.active.length; y++) {
      const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (text.trim()) lines.push(text.trimEnd());
    }
    return lines;
  });
}

async function hasNoGameErrors(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return true;
    for (let y = 0; y < term.rows; y++) {
      const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (text.includes('[gameLoop error]')) return false;
    }
    return true;
  });
}
```

注意：使用 `term.buffer.active.length`（全缓冲区）而非 `term.rows`（可见区域），因为启动消息可能滚动出可见区域。在 `index.js` 中将 term 暴露为 `window.__xterm`。

### 示例：验证输入回显

```javascript
test('输入 "hello" 后终端显示回显', async ({ page }) => {
  await page.fill('#command-input', 'hello');
  await page.press('#command-input', 'Enter');
  await page.waitForTimeout(200);
  const lines = await readAllTermLines(page);
  expect(lines.some(l => l.includes('> hello'))).toBe(true);
});
```

### page-load.spec.js (4 条)

```javascript
test('页面标题正确', async ({ page }) => { ... });
test('xterm 终端渲染', async ({ page }) => { ... });
test('输入框存在且可交互', async ({ page }) => { ... });
test('CDN 脚本加载无 404', async ({ page }) => { ... });
```

### lua-vm.spec.js (5 条)

```javascript
test('fengari 全局对象存在', async ({ page }) => { ... });
test('JSBridge 表已注入', async ({ page }) => {
  const bridge = await page.evaluate(() => {
    const L = fengari.L, lua = fengari.lua;
    lua.lua_getglobal(L, 'JSBridge');
    const t = lua.lua_type(L, -1);
    // ... 检查 write/getEvent/getEventCount
    lua.lua_pop(L, 1);
    return { type: t, ... };
  });
});
test('EngineAPI 表存在', async ({ page }) => { ... });
test('lib 表存在（metatable 代理）', async ({ page }) => { ... });
test('dataCache._loaded == true', async ({ page }) => { ... });
```

### engine-api.spec.js (16 条)

通过 `page.evaluate()` 调用 fengari Lua API，验证：

```javascript
// color.pack/unpack 往返测试
test('color.pack/unpack', async ({ page }) => {
  const ok = await luaEval(page, [
    'local c = EngineAPI.color',
    'local p = c.pack(255, 0, 0)',
    'local r, g, b = c.unpack(p)',
    'return math.abs(r - 1) < 0.01 and math.abs(g) < 0.01 and math.abs(b) < 0.01',
  ].join('; '));
  expect(ok).toBe(true);
});
```

### data-integrity.spec.js (12 条)

```javascript
test('10 个数据文件全部加载', async ({ page }) => { ... });
test('dialogues 非空', async ({ page }) => { ... });
// ... 每个 key 一条
test('场景 NPC 引用在 chars 中存在', async ({ page }) => { ... });
test('场景物品引用在 items 中存在', async ({ page }) => { ... });
test('entrances 场景 ID 在 scenes 中存在', async ({ page }) => { ... });
```

### interaction.spec.js (2 条)

```javascript
import { readTermLine, readAllTermLines } from './helpers/term-reader';

test('输入 "hello" 后终端显示回显', async ({ page }) => {
  await page.fill('#command-input', 'hello');
  await page.press('#command-input', 'Enter');
  await page.waitForTimeout(200);
  const lines = await readAllTermLines(page);
  expect(lines.some(l => l.includes('> hello'))).toBe(true);
});

test('Lua 侧能消费输入事件', async ({ page }) => {
  await page.fill('#command-input', 'test');
  await page.press('#command-input', 'Enter');
  await page.waitForTimeout(100);
  const event = await page.evaluate(() => {
    const lua = fengari.lua;
    lua.lua_getglobal(fengari.L, 'JSBridge');
    lua.lua_pushstring(fengari.L, 'getEvent');
    lua.lua_gettable(fengari.L, -2);
    lua.lua_pcall(fengari.L, 0, 1, 0);
    const t = lua.lua_type(fengari.L, -1);
    if (t === lua.LUA_TTABLE) {
      lua.lua_pushstring(fengari.L, 'data');
      lua.lua_gettable(fengari.L, -2);
      const data = fengari.to_jsstring(lua.lua_tostring(fengari.L, -1));
      lua.lua_pop(fengari.L, 2);
      return data;
    }
    lua.lua_pop(fengari.L, 1);
    return null;
  });
  expect(event).toBe('test');
});
```

### error-handling.spec.js + state-persistence.spec.js

error-handling.spec.js:
```javascript
test('file.open 不存在文件返回 nil', async ({ page }) => { ... });
test('script.load 不存在脚本返回 nil,error', async ({ page }) => { ... });
test('parseJSON 非法字符串抛错误', async ({ page }) => { ... });
test('控制台无 error/warning', async ({ page }) => {
  const errors = [];
  page.on('console', msg => errors.push(msg));
  expect(errors.filter(m => m.type() === 'error')).toHaveLength(0);
});
test('网络请求无失败', async ({ page }) => { ... });
```

state-persistence.spec.js (9 条):
```javascript
test('encodeSimpleJSON 往返正确', async ({ page }) => { ... });
test('restoreNumericKeys 恢复 0 键', async ({ page }) => { ... });
test('initGameState 从 dataCache 初始化 JY', async ({ page }) => { ... });
test('save 后 load 往返正确', async ({ page }) => { ... });
test('存档槽隔离', async ({ page }) => { ... });
test('delete 删除存档', async ({ page }) => { ... });
test('保存大表 (>700KB) 无阻塞', async ({ page }) => { ... });
test('listSaves 显示槽位信息', async ({ page }) => { ... });
test('多个游戏周期后存档一致性', async ({ page }) => { ... });
```

## 验证工具

由于 fengari 的字符串类型是 UTF-8 字节数组（luastring），
在 `page.evaluate()` 中获取 Lua 值后，需要用 `fengari.to_jsstring()` 转换。
对于 Lua boolean/number，直接用 `fengari.lua.lua_toboolean` / `lua_tonumber`。
常用的模式：

```javascript
function luaEval(code) {
  // 返回 Lua 执行结果（自动处理类型转换）
  return page.evaluate((c) => {
    const f = window.fengari;
    const lua = f.lua;
    const fn = f.load(c, 'eval');
    const result = fn();
    const t = typeof result;
    return result;
  }, code);
}
```

## npm 脚本

```json
{
  "scripts": {
    "test": "npx playwright test",
    "test:ui": "npx playwright test --ui"
  },
  "devDependencies": {
    "@playwright/test": "^1.52.0"
  }
}
```

服务器生命周期由 Playwright 的 `webServer` 配置管理（在 `playwright.config.js` 中配置），测试结束后通过 `globalTeardown` 脚本（`fuser -k 8088/tcp`）清理端口。

## 风险

| 风险 | 缓解 |
|------|------|
| fengari 字符串需 luastring 转换 | 封装 `luaEval()` 工具函数统一处理，使用 `lua_tolstring()` + `to_jsstring()` |
| page.evaluate 中 Lua 代码太长 | 拆成多个小测试，每个只测一个行为 |
| Playwright 安装 Chromium 较大 (300MB+) | CI 中缓存，本地只需安装一次 |
| 服务器端口被占 | `lsof -i :8088` 检查后 kill，或使用随机端口 |
| 多个 worker 共享 Fengari 状态导致测试干扰 | 使用 1 个 worker（`workers: 1`） |