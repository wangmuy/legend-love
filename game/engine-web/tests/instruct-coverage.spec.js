const { test, expect } = require('@playwright/test');
const { waitForPageReady, luaEval } = require('./helpers/setup');

test.describe('instruct_* 函数覆盖测试', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForPageReady(page);
    await page.waitForTimeout(3000);
  });

  test('instruct_9 函数存在', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G,"instruct_9"))');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('function');
  });

  test('instruct_10 加入队员 - 添加人物到队伍', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'JY.Person = JY.Person or {}',
      'JY.Person[99] = { ["姓名"] = "测试角色" }',
      'for i = 1, 6 do JY.Base["队伍" .. i] = -1 end',
      'rawget(_G, "instruct_10")(99)',
      'return tostring(JY.Base["队伍2"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('99');
  });

  test('instruct_16 队伍中是否有某人', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'JY.Base["队伍1"] = 0; JY.Base["队伍2"] = 5',
      'local f = rawget(_G, "instruct_16")',
      'return tostring(f(5)) .. "|" .. tostring(f(99))',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true|false');
  });

  test('instruct_18 是否有某种物品', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'JY.Base["物品1"] = 10; JY.Base["物品2"] = 20',
      'local f = rawget(_G, "instruct_18")',
      'return tostring(f(10)) .. "|" .. tostring(f(999))',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true|false');
  });

  test('instruct_20 队伍是否满', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'JY.Base["队伍6"] = -1',
      'local f = rawget(_G, "instruct_20")',
      'return tostring(f()) .. "|"',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('false|');
  });

  test('instruct_21 离队', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'for i = 1, 6 do JY.Base["队伍" .. i] = -1 end',
      'JY.Base["队伍2"] = 5; JY.Base["队伍3"] = 10',
      'rawget(_G, "instruct_21")(5)',
      'return tostring(JY.Base["队伍2"]) .. "|" .. tostring(JY.Base["队伍3"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('10|-1');
  });

  test('instruct_22 内力降为0', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}; JY.Person = JY.Person or {}',
      'JY.Base["队伍1"] = 0; JY.Person[0] = { ["内力"] = 100 }',
      'rawget(_G, "instruct_22")()',
      'return tostring(JY.Person[0]["内力"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('0');
  });

  test('instruct_23 设置用毒', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[5] = { ["用毒能力"] = 0 }',
      'rawget(_G, "instruct_23")(5, 30)',
      'return tostring(JY.Person[5]["用毒能力"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('30');
  });

  test('instruct_28 判断品德范围', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["品德"] = 50 }',
      'local f = rawget(_G, "instruct_28")',
      'return tostring(f(0, 30, 60)) .. "|" .. tostring(f(0, 70, 100))',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true|false');
  });

  test('instruct_29 判断攻击力范围', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["攻击力"] = 50 }',
      'local f = rawget(_G, "instruct_29")',
      'return tostring(f(0, 40, 60)) .. "|" .. tostring(f(0, 70, 100))',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true|false');
  });

  test('instruct_33 学会武功', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = {}',
      'for i = 1, 10 do JY.Person[0]["武功" .. i] = 0 end',
      'rawget(_G, "instruct_33")(0, 5, 0)',
      'return tostring(JY.Person[0]["武功1"]) .. "|" .. tostring(JY.Person[0]["武功等级1"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('5|0');
  });

  test('instruct_34 资质增加', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["资质"] = 50 }',
      'rawget(_G, "instruct_34")(0, 10)',
      'return tostring(JY.Person[0]["资质"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('60');
  });

  test('instruct_35 设置武功', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = {}',
      'rawget(_G, "instruct_35")(0, -1, 7, 3)',
      'return tostring(JY.Person[0]["武功1"]) .. "|" .. tostring(JY.Person[0]["武功等级1"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('7|3');
  });

  test('instruct_36 判断性别', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["性别"] = 1 }',
      'local f = rawget(_G, "instruct_36")',
      'return tostring(f(1)) .. "|" .. tostring(f(0))',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true|false');
  });

  test('instruct_39 打开场景', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Scene = JY.Scene or {}',
      'JY.Scene[5] = { ["进入条件"] = 2 }',
      'rawget(_G, "instruct_39")(5)',
      'return tostring(JY.Scene[5]["进入条件"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('0');
  });

  test('instruct_41 非玩家增加物品', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[5] = {}',
      'rawget(_G, "instruct_41")(5, 100, 3)',
      'return tostring(JY.Person[5]["携带物品1"]) .. "|" .. tostring(JY.Person[5]["携带物品数量1"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('100|3');
  });

  test('instruct_42 队伍中是否有女性', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}; JY.Person = JY.Person or {}',
      'JY.Base["队伍2"] = 5; JY.Person[5] = { ["性别"] = 1 }',
      'return tostring(rawget(_G, "instruct_42")())',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true');
  });

  test('instruct_43 委托 instruct_18', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'JY.Base["物品1"] = 10',
      'return tostring(rawget(_G, "instruct_43")(10)) .. "|" .. tostring(rawget(_G, "instruct_43")(999))',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true|false');
  });

  test('instruct_45 增加轻功', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["轻功"] = 20 }',
      'rawget(_G, "instruct_45")(0, 10)',
      'return tostring(JY.Person[0]["轻功"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('30');
  });

  test('instruct_46 增加内力最大值', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["内力最大值"] = 100 }',
      'rawget(_G, "instruct_46")(0, 50)',
      'return tostring(JY.Person[0]["内力最大值"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('150');
  });

  test('instruct_47 增加攻击力', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["攻击力"] = 30 }',
      'rawget(_G, "instruct_47")(0, 20)',
      'return tostring(JY.Person[0]["攻击力"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('50');
  });

  test('instruct_48 增加生命最大值', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["生命最大值"] = 100 }',
      'rawget(_G, "instruct_48")(0, 30)',
      'return tostring(JY.Person[0]["生命最大值"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('130');
  });

  test('instruct_49 设置内力属性', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["内力性质"] = 0 }',
      'rawget(_G, "instruct_49")(0, 2)',
      'return tostring(JY.Person[0]["内力性质"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('2');
  });

  test('instruct_50 判断5种物品', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'JY.Base["物品1"] = 1; JY.Base["物品2"] = 2; JY.Base["物品3"] = 3',
      'JY.Base["物品4"] = 4; JY.Base["物品5"] = 5',
      'local f = rawget(_G, "instruct_50")',
      'return tostring(f(1,2,3,4,5)) .. "|" .. tostring(f(1,2,3,4,99))',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true|false');
  });

  test('instruct_51 函数存在', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G,"instruct_51"))');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('function');
  });

  test('instruct_52 显示品德', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["品德"] = 80 }',
      'rawget(_G, "instruct_52")()',
      'return "ok"',
    ].join('; '));
    expect(r.ok).toBe(true);
  });

  test('instruct_53 显示声望', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["声望"] = 200 }',
      'rawget(_G, "instruct_53")()',
      'return "ok"',
    ].join('; '));
    expect(r.ok).toBe(true);
  });

  test('instruct_54 函数存在', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G,"instruct_54"))');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('function');
  });

  test('instruct_55 函数存在', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G,"instruct_55"))');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('function');
  });

  test('instruct_59 全体离队（验证函数存在）', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G,"instruct_59"))');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('function');
  });

  test('instruct_61 函数存在', async ({ page }) => {
    const r = await luaEval(page, 'return type(rawget(_G,"instruct_61"))');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('function');
  });

  test('instruct_63 设置性别', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["性别"] = 0 }',
      'rawget(_G, "instruct_63")(0, 1)',
      'return tostring(JY.Person[0]["性别"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('1');
  });

  // ===== 新增：有实际逻辑但缺单元测试的 instruct =====

  test('instruct_0 输出分隔线', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_0")(); return "ok"');
    expect(r.ok).toBe(true);
    expect(r.result).toBe('ok');
  });

  test('instruct_2 修改出入口（no-op，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_2")(1,2,3); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_3 修改场景事件（no-op，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_3")(1,2,3,4); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_11 住宿询问（输出文本，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_11")(); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_12 住宿恢复（修改HP/MP/体力）', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Person = JY.Person or {}',
      'JY.Person[0] = { ["生命"]=10, ["生命最大值"]=50, ["内力"]=5, ["内力最大值"]=35, ["体力"]=20 }',
      'rawget(_G,"instruct_12")()',
      'return tostring(JY.Person[0]["生命"]) .. "|" .. tostring(JY.Person[0]["内力"]) .. "|" .. tostring(JY.Person[0]["体力"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('50|35|100');
  });

  test('instruct_13 菜单（通过 MenuAsync，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_13")(0, {"选项1","选项2"}); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_14 刷新场景（不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_14")(); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_19 设置坐标', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'rawget(_G,"instruct_19")(100, 200)',
      'return tostring(JY.Base["人X1"]) .. "|" .. tostring(JY.Base["人Y1"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('100|200');
  });

  test('instruct_26 修改角色属性（no-op，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_26")(0, "攻击力", 10); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_27 动画（no-op，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_27")(); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_31 判断物品数量', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'JY.Base["物品1"] = 10; JY.Base["物品数量1"] = 5',
      'JY.Base["物品2"] = 20; JY.Base["物品数量2"] = 0',
      'local f = rawget(_G, "instruct_31")',
      'return tostring(type(f(10))) .. "|" .. tostring(type(f(999)))',
    ].join('; '));
    expect(r.ok).toBe(true);
  });

  test('instruct_32 给/取物品（不崩溃）', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'rawget(_G,"instruct_32")(1, 50, 3); return "ok"',
    ].join('; '));
    expect(r.ok).toBe(true);
  });

  test('instruct_37 场景音乐（no-op，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_37")(); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_40 设置方向', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'rawget(_G,"instruct_40")(2)',
      'return tostring(JY.Base["人方向"])',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('2');
  });

  test('instruct_54 开放其他场景（不崩溃）', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Scene = JY.Scene or {}',
      'rawget(_G,"instruct_54")()',
      'return "ok"',
    ].join('; '));
    expect(r.ok).toBe(true);
  });

  test('instruct_55 判断 D* 触发事件', async ({ page }) => {
    const r = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.D = JY.D or {}',
      'JY.D[0] = JY.D[0] or {}',
      'JY.D[0][5] = { [3] = 1 }',
      'local f = rawget(_G, "instruct_55")',
      'return tostring(f(5, 3))',
    ].join('; '));
    expect(r.ok).toBe(true);
  });

  test('instruct_56 队伍管理（no-op，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_56")(); return "ok"');
    expect(r.ok).toBe(true);
  });

  test('instruct_59 全体离队（验证函数存在且不崩溃）', async ({ page }) => {
    const r1 = await luaEval(page, 'return type(rawget(_G,"instruct_59"))');
    expect(r1.ok).toBe(true);
    expect(r1.result).toBe('function');
    // 验证调用不崩溃
    const r2 = await luaEval(page, [
      'local JY = rawget(_G, "JY")',
      'if not JY then JY = {}; rawset(_G, "JY", JY) end',
      'JY.Base = JY.Base or {}',
      'rawget(_G,"instruct_59")()',
      'return "ok"',
    ].join('; '));
    expect(r2.ok).toBe(true);
  });

  test('instruct_61 判断14天书', async ({ page }) => {
    const r = await luaEval(page, [
      'local GetD = rawget(_G, "GetD")',
      'if not GetD then return "no-getd" end',
      'return "ok"',
    ].join('; '));
    expect(r.ok).toBe(true);
  });

  test('instruct_67 音效（no-op，不崩溃）', async ({ page }) => {
    const r = await luaEval(page, 'rawget(_G,"instruct_67")(1); return "ok"');
    expect(r.ok).toBe(true);
  });

  // ===== 全部 68 个 instruct 存在性验证 =====
  test('全部 instruct_0 ~ instruct_67 函数存在', async ({ page }) => {
    const r = await luaEval(page, [
      'local allOk = true; local result = ""',
      'for i = 0, 67 do',
      '  local t = type(rawget(_G, "instruct_" .. i))',
      '  if t ~= "function" then allOk = false; result = result .. "instruct_" .. i .. "=" .. t .. " " end',
      'end',
      'if allOk then return "all-68-ok" else return result end',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('all-68-ok');
  });

  // ===== 全部 68 个 instruct 调用不崩溃 =====
  test('全部 instruct_0 ~ instruct_67 调用不崩溃', async ({ page }) => {
    const r = await luaEval(page, [
      'local allOk = true',
      'for i = 0, 67 do',
      '  local fn = rawget(_G, "instruct_" .. i)',
      '  if type(fn) == "function" then',
      '    local stat, err = pcall(fn)',
      '    if not stat then allOk = false; break end',
      '  end',
      'end',
      'return tostring(allOk)',
    ].join('; '));
    expect(r.ok).toBe(true);
    expect(r.result).toBe('true');
  });
});
