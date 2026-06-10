const { expect } = require('@playwright/test');

async function waitForPageReady(page) {
  await page.waitForFunction(() => {
    try {
      const lua = window.fengari && window.fengari.lua;
      if (!lua) return false;
      lua.lua_getglobal(window.fengari.L, 'dataCache');
      const t = lua.lua_type(window.fengari.L, -1);
      if (t !== lua.LUA_TTABLE) { lua.lua_pop(window.fengari.L, 1); return false; }
      lua.lua_pushstring(window.fengari.L, '_loaded');
      lua.lua_gettable(window.fengari.L, -2);
      const loaded = lua.lua_toboolean(window.fengari.L, -1);
      lua.lua_pop(window.fengari.L, 2);
      return loaded;
    } catch (e) {
      return false;
    }
  }, { timeout: 30000 });
}

async function getLuaGlobal(page, name) {
  return page.evaluate((n) => {
    const f = window.fengari;
    const lua = f.lua;
    lua.lua_getglobal(f.L, n);
    const t = lua.lua_type(f.L, -1);
    let result;
    if (t === lua.LUA_TTABLE) result = { type: 'table' };
    else if (t === lua.LUA_TBOOLEAN) result = { type: 'boolean', value: lua.lua_toboolean(f.L, -1) };
    else if (t === lua.LUA_TNUMBER) result = { type: 'number', value: lua.lua_tonumber(f.L, -1) };
    else if (t === lua.LUA_TSTRING) result = { type: 'string', value: f.to_jsstring(lua.lua_tostring(f.L, -1)) };
    else if (t === lua.LUA_TNIL) result = { type: 'nil' };
    else result = { type: 'unknown', typeCode: t };
    lua.lua_pop(f.L, 1);
    return result;
  }, name);
}

async function luaEval(page, code) {
  return page.evaluate((c) => {
    const f = window.fengari;
    const lua = f.lua;
    try {
      const fn = f.load(c, 'eval');
      return fn();
    } catch (e) {
      return { __error: (e && e.message) || String(e) };
    }
  }, code);
}

module.exports = { waitForPageReady, getLuaGlobal, luaEval };
