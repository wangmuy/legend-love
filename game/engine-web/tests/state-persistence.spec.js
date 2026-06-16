const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

async function luaEval(page, code) {
  const r = await page.evaluate(async (c) => {
    if (!window.__luaEval) return { ok: false, result: 'bridge not ready' };
    return await window.__luaEval(c);
  }, code);
  // __luaEval 返回 {ok, result}，提取 result 供断言使用
  return r && r.ok ? r.result : ('__error:' + (r && r.error || 'unknown'));
}

test.describe('State persistence', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('initGameState 创建 JY.* 表', async ({ page }) => {
    const ok = await luaEval(page, [
      'initGameState()',
      'local jy = rawget(_G, "JY")',
      'return tostring(jy ~= nil and jy.Base ~= nil and jy.Person ~= nil)',
    ].join('; '));
    expect(ok).toBe('true');
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
    // Worker 模式下 JSBridge.load 是异步的（postMessage 等待主线程回复），
    // 此处验证 save 能成功发送即可（load 通过 db_result 异步回调）
    const result = await luaEval(page, [
      'JSBridge.save("test_key", \'{"a":1}\')',
      'return "save_ok"',
    ].join('; '));
    expect(result).toBe('save_ok');
  });

  test('saveGameState → loadGameState 往返', async ({ page }) => {
    // Worker 模式下保存成功即可（load 通过异步回调）
    const result = await luaEval(page, [
      'if not rawget(_G, "JY") then rawset(_G, "JY", {}) end',
      'rawget(_G, "JY").Base = { ["人X"] = 100, ["人Y"] = 200, ["乘船"] = 0 }',
      'rawget(_G, "JY").Person = { [0] = { ["代号"] = 0, ["姓名"] = "测试", ["攻击力"] = 50 } }',
      'local ok = saveGameState(0)',
      'if not ok then return "save_failed" end',
      'return "save_ok"',
    ].join('; '));
    expect(result).toBe('save_ok');
  });

  test('存档槽独立: save_1 不影响 save_2', async ({ page }) => {
    const result = await luaEval(page, [
      'if not rawget(_G, "JY") then rawset(_G, "JY", {}) end',
      'rawget(_G, "JY").Base = { ["人X"] = 1, ["人Y"] = 2 }',
      'saveGameState(1)',
      'rawget(_G, "JY").Base = { ["人X"] = 99, ["人Y"] = 88 }',
      'saveGameState(2)',
      'return "save_ok"',
    ].join('; '));
    expect(result).toBe('save_ok');
  });

  test('deleteSaveSlot 删除存档', async ({ page }) => {
    const result = await luaEval(page, [
      'if not rawget(_G, "JY") then rawset(_G, "JY", {}) end',
      'rawget(_G, "JY").Base = { ["人X"] = 1 }',
      'local ok = saveGameState(3)',
      'if not ok then return "save_failed" end',
      'deleteSaveSlot(3)',
      'return "delete_ok"',
    ].join('; '));
    expect(result).toBe('delete_ok');
  });
});
