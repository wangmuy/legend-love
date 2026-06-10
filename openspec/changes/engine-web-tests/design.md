## 测试架构

```
tests/
├── playwright.config.js        ← 浏览器配置（Chromium headless）
├── helpers/
│   ├── setup.js                ← startServer() + waitForPageReady()
│   └── term-reader.js          ← readTermLine(N) 封装 buffer API
├── page-load.spec.js           ← Layer 1: 页面加载基础
├── lua-vm.spec.js              ← Layer 2: Lua VM 初始化
├── engine-api.spec.js          ← Layer 3-4: API 表面 + 功能
├── data-integrity.spec.js      ← Layer 5-6: 数据 + 引用
├── interaction.spec.js         ← Layer 7: 交互流程
└── error-handling.spec.js      ← Layer 8: 错误场景
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
  ├─ 3. 等待终端显示 "System ready" (最长 15s)
  ├─ 4. 逐条执行测试用例
  │    ├─ page.evaluate() 查询 DOM
  │    ├─ page.evaluate() 调 fengari API 检查 Lua 状态
  │    └─ page.evaluate() 输入模拟 + 检查终端输出
  └─ 5. 关闭服务器 + 浏览器 → 输出结果
```

## 读取终端文本

xterm.js 渲染在 canvas/grid 中，不能用 DOM querySelector 可靠读取。
使用 xterm.js buffer API 直接提取行数据：

```javascript
// helpers/term-reader.js
export async function readTermLine(page, lineIndex) {
  return page.evaluate((n) => {
    // 通过 fengari 获取 term 对象的引用
    const term = window.__xterm;
    if (!term) return null;
    return term.buffer.active.getLine(n)?.translateToString(true) || '';
  }, lineIndex);
}

export async function readAllTermLines(page) {
  return page.evaluate(() => {
    const term = window.__xterm;
    if (!term) return [];
    const lines = [];
    for (let y = 0; y < term.rows; y++) {
      const text = term.buffer.active.getLine(y)?.translateToString(true) || '';
      if (text.trim()) lines.push(text);
    }
    return lines;
  });
}
```

在 `index.js` 中将 term 暴露为 `window.__xterm`。

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

### engine-api.spec.js (15 条)

通过 `page.evaluate()` 调用 fengari Lua API，验证：

```javascript
// color.pack/unpack 往返测试
test('color.pack/unpack', async ({ page }) => {
  const result = await page.evaluate(() => {
    const L = fengari.L, lua = fengari.lua;
    const code = [
      'local c = EngineAPI.color',
      'local packed = c.pack(255, 0, 0)',
      'local r, g, b = c.unpack(packed)',
      // 浮点精度容忍
      'return math.abs(r - 1) < 0.01 and math.abs(g) < 0.01 and math.abs(b) < 0.01'
    ].join('; ');
    const fn = fengari.load('return ' .. code, 'test');
    fn(L);
    return fengari.to_jsstring(lua.lua_tostring(L, -1)); // 但这里是 Lua boolean，需要处理
  });
  expect(result).toBe(true);
});
```

### data-integrity.spec.js (10 条)

```javascript
test('7 个数据文件全部加载', async ({ page }) => { ... });
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

### error-handling.spec.js (5 条)

```javascript
test('file.open 不存在文件返回 nil', async ({ page }) => { ... });
test('script.load 不存在脚本返回 nil,error', async ({ page }) => { ... });
test('parseJSON 非法字符串抛错误', async ({ page }) => { ... });
test('控制台无 error/warning', async ({ page }) => {
  const errors = [];
  page.on('console', msg => errors.push(msg));
  // ... 等页面加载完
  expect(errors.filter(m => m.type() === 'error')).toHaveLength(0);
});
test('网络请求无失败', async ({ page }) => { ... });
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
    const fn = fengari.load('return ' .. c, 'eval');
    fn(fengari.L);
    const lua = fengari.lua;
    const t = lua.lua_type(fengari.L, -1);
    let result;
    if (t === lua.LUA_TBOOLEAN) result = lua.lua_toboolean(fengari.L, -1);
    else if (t === lua.LUA_TNUMBER) result = lua.lua_tonumber(fengari.L, -1);
    else if (t === lua.LUA_TSTRING) result = fengari.to_jsstring(lua.lua_tostring(fengari.L, -1));
    else result = 'type=' + t;
    lua.lua_pop(fengari.L, 1);
    return result;
  }, code);
}
```

## npm 脚本

```json
{
  "scripts": {
    "test": "node scripts/start-test-server.js & npx playwright test; kill %1",
    "test:ui": "node scripts/start-test-server.js & npx playwright test --ui; kill %1"
  },
  "devDependencies": {
    "@playwright/test": "^1.52.0"
  }
}
```

或更稳健的 startup 方式——在 Playwright 的 `globalSetup` 中启动服务器。

## 风险

| 风险 | 缓解 |
|------|------|
| fengari 字符串需 luastring 转换 | 封装 `luaEval()` 工具函数统一处理 |
| page.evaluate 中 Lua 代码太长 | 拆成多个小测试，每个只测一个行为 |
| Playwright 安装 Chromium 较大 (300MB+) | CI 中缓存，本地只需安装一次 |
| 服务器端口被占 | 随机端口 + 获取实际端口 |