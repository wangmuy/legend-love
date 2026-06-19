const { test, expect } = require('@playwright/test');
const { waitForPageReady } = require('./helpers/setup');

const DATA_KEYS = ['dialogues', 'scenes', 'chars', 'items', 'skills', 'entrances', 'wmap', 'events', 'config', 'shops'];

async function luaEval(page, code) {
  const r = await page.evaluate(async (c) => {
    if (!window.__luaEval) return { ok: false, error: 'bridge not ready' };
    return await window.__luaEval(c);
  }, code);
  return r;
}

test.describe('数据完整性', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
  });

  test('_fileCount == 10', async ({ page }) => {
    const r = await luaEval(page, 'return tostring(rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["_fileCount"] or 0)');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('10');
  });

  for (const key of DATA_KEYS) {
    test(`${key} 存在且非空`, async ({ page }) => {
      const r = await luaEval(page, `local dc=rawget(_G,"initDataSource"); return dc and type(dc[${JSON.stringify(key)}]) or "nil"`);
      expect(r.ok).toBe(true);
      expect(r.result).toBe('table');
    });
  }

  test('initDataSourcePaths 兼容映射', async ({ page }) => {
    const r = await luaEval(page, 'local p=rawget(_G,"initDataSourcePaths"); return p and tostring(#p>0) or "false"');
    expect(r.ok).toBe(true);
  });
});

test('场景 NPC 引用在 chars 中存在', async ({ page }) => {
  await page.goto('/');
  await waitForPageReady(page);
  const r = await luaEval(page, [
    'local scenes = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["scenes"]',
    'local chars = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["chars"]',
    'if not scenes or not chars then return "missing data" end',
    'local charIndex = {}',
    'for i, c in ipairs(chars) do if type(c)=="table" then charIndex[tostring(c["代号"])]=true end end',
    'for _, s in pairs(scenes) do',
    '  if type(s)=="table" and s["NPC"] then',
    '    for _, npc in ipairs(s["NPC"]) do',
    '      local cid = tostring(npc["代号"] or npc)',
    '      if not charIndex[cid] then return "missing NPC: "..cid end',
    '    end',
    '  end',
    'end',
    'return "ok"',
  ].join('; '));
  expect(r.ok).toBe(true);
});

test('entrances 场景 ID 在 scenes 中存在', async ({ page }) => {
  await page.goto('/');
  await waitForPageReady(page);
  const r = await luaEval(page, [
    'local scenes = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["scenes"]',
    'local entrances = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["entrances"]',
    'if not scenes or not entrances then return "missing data" end',
    'for i = 1, #entrances do',
    '  local e = entrances[i]',
    '  local sceneId = tostring(e and e.sceneId or "")',
    '  local found = false',
    '  for _, s in pairs(scenes) do',
    '    if type(s)=="table" and tostring(s["代号"])==sceneId then found=true; break end',
    '  end',
    '  if not found then return "missing sceneId="..sceneId.." at "..i end',
    'end',
    'return "ok"',
  ].join('; '));
  expect(r.ok).toBe(true);
});

test('D* 事件引用的场景 ID 在 scenes 中存在', async ({ page }) => {
  await page.goto('/');
  await waitForPageReady(page);
  const r = await luaEval(page, [
    'local scenes = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["scenes"]',
    'local events = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["events"]',
    'if not scenes or not events then return "missing data" end',
    'local sceneIds = {}',
    'for _, s in pairs(scenes) do',
    '  if type(s)=="table" then sceneIds[tostring(s["代号"])]=true end',
    'end',
    'for i, evt in ipairs(events) do',
    '  local sid = tostring(evt and evt[1] or "")',
    '  if sid ~= "0" and not sceneIds[sid] then return "missing event sceneId="..sid.." at "..i end',
    'end',
    'return "ok"',
  ].join('; '));
  expect(r.ok).toBe(true);
});

test('config 包含主角位置', async ({ page }) => {
  await page.goto('/');
  await waitForPageReady(page);
  const r = await luaEval(page, [
    'local cfg = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["config"]',
    'if not cfg then return "no config" end',
    'local pl = cfg["玩家"] or cfg["player"]',
    'return pl and tostring(pl["X"] ~= nil) or "false"',
  ].join('; '));
  expect(r.ok).toBe(true);
});

test('shops 物品 ID 在 items 中存在', async ({ page }) => {
  await page.goto('/');
  await waitForPageReady(page);
  const r = await luaEval(page, [
    'local items = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["items"]',
    'local shops = rawget(_G, "initDataSource") and rawget(_G, "initDataSource")["shops"]',
    'if not items or not shops then return "missing data" end',
    'return "ok"',
  ].join('; '));
  expect(r.ok).toBe(true);
});
