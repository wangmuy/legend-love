const { test, expect } = require('@playwright/test');
const { waitForPageReady, luaEval } = require('./helpers/setup');

test.describe('State persistence', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('initGameState 创建 JY.* 表', async ({ page }) => {
    const ok = await luaEval(page, [
      'initGameState()',
      'return _G.JY ~= nil and _G.JY.Base ~= nil and _G.JY.Person ~= nil',
    ].join('; '));
    expect(ok).toBe(true);
  });

  test('encodeSimpleJSON 数字/字符串/布尔', async ({ page }) => {
    const json = await luaEval(page, [
      'local e = encodeSimpleJSON',
      'return e(42) .. "|" .. e("hello") .. "|" .. e(true) .. "|" .. e(false)',
    ].join('; '));
    expect(json).toBe('42|"hello"|true|false');
  });

  test('encodeSimpleJSON 数组', async ({ page }) => {
    const json = await luaEval(page, [
      'local e = encodeSimpleJSON',
      'return e({10, 20, 30})',
    ].join('; '));
    expect(json).toBe('[10,20,30]');
  });

  test('encodeSimpleJSON 对象（含中文 key）', async ({ page }) => {
    const json = await luaEval(page, [
      'local e = encodeSimpleJSON',
      'return e({["代号"]=1, ["姓名"]="x"})',
    ].join('; '));
    expect(json).toBe('{"代号":1,"姓名":"x"}');
  });

  test('encodeSimpleJSON 嵌套', async ({ page }) => {
    const json = await luaEval(page, [
      'local e = encodeSimpleJSON',
      'return e({name="test", vals={1,2,3}})',
    ].join('; '));
    expect(json).toBe('{"name":"test","vals":[1,2,3]}');
  });

  test('JSBridge.save/load 往返', async ({ page }) => {
    const result = await luaEval(page, [
      'JSBridge.save("test_key", \'{"a":1}\')',
      'local v = JSBridge.load("test_key")',
      'return v',
    ].join('; '));
    expect(result).toBe('{"a":1}');
  });

  test('saveGameState → loadGameState 往返', async ({ page }) => {
    const result = await luaEval(page, [
      'if not _G.JY then _G.JY = {} end',
      '_G.JY.Base = { ["人X"] = 100, ["人Y"] = 200, ["乘船"] = 0 }',
      '_G.JY.Person = { [0] = { ["代号"] = 0, ["姓名"] = "测试", ["攻击力"] = 50 } }',
      'local ok = saveGameState(0)',
      'if not ok then return "save_failed" end',
      'local raw = JSBridge.load("save_0")',
      'if not raw then return "no_raw_after_save" end',
      'local parsed_ok, parsed = pcall(parseJSON, raw)',
      'if not parsed_ok then return "parse_fail:" .. tostring(parsed) end',
      'if not parsed.base then return "no_base_in_save:" .. raw:sub(1,80) end',
      '_G.JY = nil',
      'local loaded = loadGameState(0)',
      'if not loaded then return "load_failed" end',
      'local bx = _G.JY.Base and _G.JY.Base["人X"]',
      'local pn = _G.JY.Person and _G.JY.Person[0] and _G.JY.Person[0]["姓名"]',
      'return tostring(bx) .. "|" .. tostring(pn)',
    ].join('; '));
    expect(result).toBe('100|测试');
  });

  test('存档槽独立: save_1 不影响 save_2', async ({ page }) => {
    const result = await luaEval(page, [
      'if not _G.JY then _G.JY = {} end',
      '_G.JY.Base = { ["人X"] = 1, ["人Y"] = 2 }',
      'saveGameState(1)',
      '_G.JY.Base = { ["人X"] = 99, ["人Y"] = 88 }',
      'saveGameState(2)',
      '_G.JY = nil',
      'loadGameState(1)',
      'local x1 = _G.JY.Base["人X"]',
      '_G.JY = nil',
      'loadGameState(2)',
      'local x2 = _G.JY.Base["人X"]',
      'return tostring(x1) .. "|" .. tostring(x2)',
    ].join('; '));
    expect(result).toBe('1|99');
  });

  test('deleteSaveSlot 删除存档', async ({ page }) => {
    const result = await luaEval(page, [
      'if not _G.JY then _G.JY = {} end',
      '_G.JY.Base = { ["人X"] = 1 }',
      'local ok = saveGameState(3)',
      'if not ok then return "save_failed" end',
      'local saves = listSaveSlots()',
      'local before = 0',
      'for _ in pairs(saves) do before = before + 1 end',
      'deleteSaveSlot(3)',
      'local after_raw = JSBridge.load("save_3")',
      'local saves2 = listSaveSlots()',
      'local after = 0',
      'for _ in pairs(saves2) do after = after + 1 end',
      'return tostring(before) .. "|" .. tostring(after) .. "|" .. tostring(after_raw == nil)',
    ].join('; '));
    expect(result).toBe('1|0|true');
  });
});
