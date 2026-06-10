const { test, expect } = require('@playwright/test');
const { waitForPageReady, luaEval } = require('./helpers/setup');

const DATA_KEYS = ['dialogues', 'scenes', 'chars', 'items', 'skills', 'entrances', 'wmap', 'events', 'config', 'shops'];

test.describe('数据完整性', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('_fileCount == 10', async ({ page }) => {
    const count = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, 'dataCache');
      lua.lua_pushstring(f.L, '_fileCount');
      lua.lua_gettable(f.L, -2);
      const v = lua.lua_tonumber(f.L, -1);
      lua.lua_pop(f.L, 2);
      return v;
    });
    expect(count).toBe(10);
  });

  for (const key of DATA_KEYS) {
    test(`${key} 存在且非空`, async ({ page }) => {
      const ok = await page.evaluate((k) => {
        const f = window.fengari;
        const lua = f.lua;
        lua.lua_getglobal(f.L, 'dataCache');
        lua.lua_pushstring(f.L, k);
        lua.lua_gettable(f.L, -2);
        const t = lua.lua_type(f.L, -1);
        if (t !== lua.LUA_TTABLE) { lua.lua_pop(f.L, 2); return false; }
        let c = 0;
        lua.lua_pushnil(f.L);
        while (lua.lua_next(f.L, -2) !== 0) { c++; lua.lua_pop(f.L, 1); }
        lua.lua_pop(f.L, 2);
        return c > 0;
      }, key);
      expect(ok).toBe(true);
    });
  }

  test('dataCachePaths 兼容映射', async ({ page }) => {
    const ok = await page.evaluate(() => {
      const f = window.fengari;
      const lua = f.lua;
      lua.lua_getglobal(f.L, '_G');
      lua.lua_pushstring(f.L, 'dataCachePaths');
      lua.lua_gettable(f.L, -2);
      if (lua.lua_type(f.L, -1) !== lua.LUA_TTABLE) { lua.lua_pop(f.L, 2); return false; }
      lua.lua_pushstring(f.L, 'data-web/dialogues.json');
      lua.lua_gettable(f.L, -2);
      const v = lua.lua_isnil(f.L, -1);
      lua.lua_pop(f.L, 3);
      return !v;
    });
    expect(ok).toBe(true);
  });

  test('场景 NPC 引用在 chars 中存在', async ({ page }) => {
    const ok = await luaEval(page, [
      'local scenes = dataCache.scenes',
      'local chars = dataCache.chars',
      'for _, s in pairs(scenes) do',
      '  if type(s) == "table" and s.npc then',
      '    for _, npc in ipairs(s.npc) do',
      '      local id = tostring(npc.id or npc)',
      '      if not chars[id] then return false end',
      '    end',
      '  end',
      'end',
      'return true',
    ].join('\n'));
    expect(ok).toBe(true);
  });

  test('entrances 场景 ID 在 scenes 中存在', async ({ page }) => {
    const result = await luaEval(page, [
      'local scenes = dataCache.scenes',
      'local entrances = dataCache.entrances',
      'for i = 1, #entrances do',
      '  local e = entrances[i]',
      '  if not scenes[tostring(e.sceneId)] then',
      '    return "missing sceneId=" .. tostring(e.sceneId) .. " at index " .. i',
      '  end',
      'end',
      'return true',
    ].join('\n'));
    expect(result).toBe(true);
  });

  test('D* 事件引用的场景 ID 在 scenes 中存在', async ({ page }) => {
    const ok = await luaEval(page, [
      'local events = dataCache.events',
      'if not events then return "no events" end',
      'local scenes = dataCache.scenes',
      'local sceneIds = {}',
      'for k, _ in pairs(scenes) do',
      '  if type(k) == "number" then sceneIds[tostring(k)] = true end',
      'end',
      'for i = 1, #events do',
      '  local e = events[i]',
      '  if e.sceneId ~= nil and not sceneIds[tostring(e.sceneId)] then',
      '    return "missing sceneId=" .. tostring(e.sceneId)',
      '  end',
      'end',
      'return true',
    ].join('\n'));
    expect(ok).toBe(true);
  });

  test('config 包含主角位置', async ({ page }) => {
    const ok = await luaEval(page, [
      'local cfg = dataCache.config',
      'return cfg ~= nil and cfg.my ~= nil and type(cfg.my.px) == "number"',
    ].join('\n'));
    expect(ok).toBe(true);
  });

  test('shops 物品 ID 在 items 中存在', async ({ page }) => {
    const ok = await luaEval(page, [
      'local shops = dataCache.shops',
      'local items = dataCache.items',
      'if not shops then return "no shops" end',
      'for i = 1, #shops do',
      '  local shop = shops[i]',
      '  for j = 1, #shop.items do',
      '    local it = shop.items[j]',
      '    local itemId = tostring(it.id)',
      '    if it.id > 0 and not items[itemId] then return false end',
      '  end',
      'end',
      'return true',
    ].join('\n'));
    expect(ok).toBe(true);
  });
});