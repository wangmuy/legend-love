-- test_robustness.lua
-- 原版健壮性缺陷的回归测试（根因修复验收）
--
-- 守 5 类缺陷：
--   ① Rnd(0) 跨版本不一致（5.4/5.5 返回巨数而非报错）
--   ② War_WugongHurtLife 的 while-true 无显式下界（可无限循环）
--   ③ War_WugongHurtNeili 缺 level 钳制（nil 算术错误）
--   ④ War_AutoMove 回溯循环无进度守卫（不可达目标 → 死循环）
--   ⑤ War_EndPersonData 除 liveNum 无零守卫（inf 污染经验）

local TestHelper = require("tests.test_helper")
local TestRobustness = {}

local function readSource(rel)
    for _, p in ipairs({ rel, "../game/" .. rel }) do
        local f = io.open(p, "r")
        if f then
            local s = f:read("*a")
            f:close()
            return s
        end
    end
    return nil
end

-- ------------------------------------------------------------ ① Rnd

function TestRobustness.testRndHandlesNonPositive()
    print("\n=== Test: Rnd(n<=0) 不抛错、不返回巨数 ===")
    -- 根因：math.random(0) 在 Lua 5.1/5.3 抛错，在 5.4/5.5 返回巨数。
    -- 修法：Rnd 内部把参数钳到 >= 1，于是 Rnd(<=0) 恒返回 0。
    TestHelper.assertNotNil(rawget(_G, "Rnd"), "Rnd 应已定义")

    for _, bad in ipairs({ 0, -1, -100 }) do
        local ok, v = pcall(Rnd, bad)
        TestHelper.assertTrue(ok, "Rnd(" .. bad .. ") 不应抛错")
        TestHelper.assertEquals(0, v, "Rnd(" .. bad .. ") 应返回 0（区间为空的退化）")
    end
end

function TestRobustness.testRndHandlesNonNumber()
    print("\n=== Test: Rnd(nil/字符串) 不抛错 ===")
    local ok1, v1 = pcall(Rnd, nil)
    TestHelper.assertTrue(ok1, "Rnd(nil) 不应抛错")
    TestHelper.assertEquals(0, v1, "Rnd(nil) 应返回 0")

    local ok2, v2 = pcall(Rnd, "abc")
    TestHelper.assertTrue(ok2, "Rnd('abc') 不应抛错")
    TestHelper.assertEquals(0, v2, "Rnd('abc') 应返回 0")
end

function TestRobustness.testRndNormalRange()
    print("\n=== Test: Rnd 正常范围不变（[0, n-1]）===")
    math.randomseed(12345)
    for _, n in ipairs({ 1, 2, 3, 10, 100 }) do
        local seen, outOfRange = {}, nil
        -- **聚合断言**：循环内不逐次断言（否则 1000 条断言会淹没报告）
        for _ = 1, 200 do
            local v = Rnd(n)
            if not (v >= 0 and v <= n - 1) then outOfRange = v end
            seen[v] = true
        end
        TestHelper.assertNil(outOfRange,
            "Rnd(" .. n .. ") 应恒在 [0, " .. (n - 1) .. "]，越界样本 " .. tostring(outOfRange))

        if n >= 2 then
            local distinct = 0
            for _ in pairs(seen) do distinct = distinct + 1 end
            TestHelper.assertTrue(distinct >= 2,
                "Rnd(" .. n .. ") 应能取到多个值，实测只取到 " .. distinct)
        end
    end
end

function TestRobustness.testRndTruncatesFloat()
    print("\n=== Test: Rnd(小数) 向下取整不崩 ===")
    -- Rnd(3.7) 应等价 Rnd(3)（math.random 在 5.1 要求整数区间）
    local ok, v = pcall(Rnd, 3.7)
    TestHelper.assertTrue(ok, "Rnd(3.7) 不应抛错")
    TestHelper.assertTrue(v >= 0 and v <= 2, "Rnd(3.7) 应在 [0,2]，实测 " .. tostring(v))
end

-- ------------------------------------------------------------ ② HurtLife 循环

function TestRobustness.testHurtLifeLoopTerminatesWithZeroConsume()
    print("\n=== Test: 消耗内力=0 且 内力为负时循环仍能退出 ===")
    -- 根因：原 while true 靠 level 递减到负退出，若 消耗=0 且 内力<0 则
    -- `0 > -1` 恒真 → 无限循环。修法：加显式下界 `while level > 1`。
    local function fixedLoop(level, consume, neili)
        local iters = 0
        while level > 1 do
            iters = iters + 1
            if iters > 10000 then return nil, iters end
            if math.modf((level + 1) / 2) * consume <= neili then break end
            level = level - 1
        end
        if level <= 0 then level = 1 end
        return level, iters
    end

    local level, iters = fixedLoop(4, 0, -1)
    TestHelper.assertNotNil(level, "修复后的循环必须能退出")
    TestHelper.assertTrue(iters <= 5, "迭代次数应有界（实测 " .. iters .. "）")
    TestHelper.assertTrue(level >= 1, "退出时 level 应 >= 1（实测 " .. level .. "）")
end

function TestRobustness.testHurtLifePreservesNormalSemantics()
    print("\n=== Test: 修复后语义与原版一致（正常数据）===")
    local function oldf(level, consume, neili)
        local n = 0
        while true do
            n = n + 1
            if n > 10000 then return "INF" end
            if math.modf((level + 1) / 2) * consume > neili then
                level = level - 1
            else
                break
            end
        end
        if level <= 0 then level = 1 end
        return level
    end
    local function newf(level, consume, neili)
        while level > 1 do
            if math.modf((level + 1) / 2) * consume <= neili then break end
            level = level - 1
        end
        if level <= 0 then level = 1 end
        return level
    end

    local cases = {
        { 5, 10, 100 }, { 5, 10, 30 }, { 5, 10, 0 }, { 1, 10, 0 },
        { 10, 0, 0 }, { 3, 7, 100 }, { 2, 5, 1 }, { 4, 3, 50 },
    }
    for _, t in ipairs(cases) do
        local a = oldf(t[1], t[2], t[3])
        local b = newf(t[1], t[2], t[3])
        TestHelper.assertEquals(a, b,
            string.format("level=%d consume=%d neili=%d 结果应一致", t[1], t[2], t[3]))
    end
end

function TestRobustness.testHurtLifeSourceHasBoundedLoop()
    print("\n=== Test: 源码里 while true 已改为有界形式 ===")
    local src = readSource("script/battle/battle_action.lua")
    TestHelper.assertNotNil(src, "应能读到 battle_action.lua")
    TestHelper.assertNotNil(src:find("while level > 1 do", 1, true),
        "应使用有界循环 while level > 1")
end

-- ------------------------------------------------------------ ③ HurtNeili 钳制

function TestRobustness.testHurtNeiliClampLogic()
    print("\n=== Test: level 钳制逻辑对非法输入有效 ===")
    local function clamp(level)
        level = tonumber(level) or 1
        if level < 1 then level = 1 end
        return level
    end
    for _, bad in ipairs({ 0, -1, -100, nil, "x" }) do
        local v = clamp(bad)
        TestHelper.assertTrue(v >= 1, "level=" .. tostring(bad) .. " 应钳到 >=1，实测 " .. v)
    end
end

function TestRobustness.testHurtNeiliSourceHasClamp()
    print("\n=== Test: 源码里 HurtNeili 有 level 钳制 + 字段判空 ===")
    local src = readSource("script/battle/battle_action.lua")
    TestHelper.assertNotNil(src, "应能读到 battle_action.lua")

    local fnStart = src:find("function War_WugongHurtNeili", 1, true)
    TestHelper.assertNotNil(fnStart, "应找到 War_WugongHurtNeili")
    local body = src:sub(fnStart, fnStart + 2000)

    TestHelper.assertNotNil(body:find("if level < 1 then level = 1", 1, true),
        "应有 level < 1 的钳制")
    TestHelper.assertNotNil(body:find("addvalue = tonumber(addvalue) or 0", 1, true),
        "应对 addvalue 判空（字段缺失时不参与算术）")
end

-- ------------------------------------------------------------ ④ 回溯循环守卫

function TestRobustness.testBacktrackSourceHasGuard()
    print("\n=== Test: script 版 War_AutoMove 回溯循环有进度守卫 ===")
    local src = readSource("script/battle/battle_ai.lua")
    TestHelper.assertNotNil(src, "应能读到 battle_ai.lua")

    TestHelper.assertNotNil(src:find("local prevI = nil", 1, true),
        "应有 prevI 进度记录")
    TestHelper.assertNotNil(src:find("if prevI ~= nil and i >= prevI then", 1, true),
        "应有「无进展则放弃」守卫")
    TestHelper.assertNotNil(src:find("guard > 4 *", 1, true),
        "应有迭代硬上限")
end

function TestRobustness.testBacktrackTerminatesOnUnreachable()
    print("\n=== Test: 不可达目标时回溯循环能退出（行为复刻）===")
    local map = { ["10,5"] = 255 }
    local function GetWarMap(x, y) return map[x .. "," .. y] or 255 end

    local function backtrackGuarded(x, y, moveSteps)
        local prevI = nil
        local guard = 0
        while true do
            local i = GetWarMap(x, y)
            if i <= moveSteps then return "break-progress", x, y end
            if prevI ~= nil and i >= prevI then return "break-noguard", x, y end
            prevI = i
            guard = guard + 1
            if guard > 4 * moveSteps + 16 then return "break-hardlimit", x, y end
            if GetWarMap(x - 1, y) == i - 1 then x = x - 1
            elseif GetWarMap(x + 1, y) == i - 1 then x = x + 1
            elseif GetWarMap(x, y - 1) == i - 1 then y = y - 1
            elseif GetWarMap(x, y + 1) == i - 1 then y = y + 1
            end
        end
    end

    local reason = backtrackGuarded(10, 5, 3)
    TestHelper.assertNotNil(reason, "必须能退出")
    TestHelper.assertTrue(type(reason) == "string" and reason:find("break") ~= nil,
        "应通过某个 break 退出，实测 " .. tostring(reason))
end

-- ------------------------------------------------------------ ⑤ liveNum 零守卫

function TestRobustness.testEndPersonDataSourceHasZeroGuard()
    print("\n=== Test: liveNum=0 时有守卫 ===")
    local src = readSource("script/battle/battle_flow.lua")
    TestHelper.assertNotNil(src, "应能读到 battle_flow.lua")

    TestHelper.assertNotNil(src:find("local liveNumForExp = (liveNum > 0) and liveNum or 1", 1, true),
        "应有 liveNum 零守卫")
    TestHelper.assertNotNil(src:find("if liveNum > 0 and JY.Person[pid]", 1, true),
        "应只在 liveNum > 0 时分配经验")
end

function TestRobustness.testDivByZeroProducesInf()
    print("\n=== Test: 记录 Lua 除零得 inf 的事实（根因证据）===")
    local inf = 1 / 0
    TestHelper.assertTrue(inf > 1e300, "1/0 应得 inf（Lua 不抛错）")
    -- 关键：inf 经 limitX 会被钳到最大值 → 静默污染
    local clamped = math.max(0, math.min(inf, 60000))
    TestHelper.assertEquals(60000, clamped, "inf 会被钳到属性最大值（这就是污染机制）")
end

-- ------------------------------------------------------------ 套件入口

function TestRobustness.runAll()
    print("\n" .. string.rep("=", 60))
    print("原版健壮性缺陷回归（5 类根因修复）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    -- **必须装真实的 Rnd**：TestHelper.mockGlobals 会把 _G.Rnd 设成
    -- `function(n) return 0 end` 的桩，用它测"取值范围"毫无意义。
    -- 所以这里用 loadfile 加载真实的 jymain.lua，让 Rnd 覆盖桩。
    do
        local chunk = loadfile("script/jymain.lua")
        if not chunk then chunk = loadfile("../game/script/jymain.lua") end
        if chunk then pcall(chunk) end
    end
    TestHelper.assertNotNil(rawget(_G, "Rnd"), "Rnd 应已定义")
    -- 确认拿到的不是桩（真实 Rnd(10) 不该恒为 0）
    local distinct = {}
    for _ = 1, 50 do distinct[Rnd(10)] = true end
    local nd = 0
    for _ in pairs(distinct) do nd = nd + 1 end
    TestHelper.assertTrue(nd >= 2,
        "拿到的 Rnd 应是真实实现（不是恒 0 的桩），实测取值数 " .. nd)

    TestRobustness.testRndHandlesNonPositive()
    TestRobustness.testRndHandlesNonNumber()
    TestRobustness.testRndNormalRange()
    TestRobustness.testRndTruncatesFloat()

    TestRobustness.testHurtLifeLoopTerminatesWithZeroConsume()
    TestRobustness.testHurtLifePreservesNormalSemantics()
    TestRobustness.testHurtLifeSourceHasBoundedLoop()

    TestRobustness.testHurtNeiliClampLogic()
    TestRobustness.testHurtNeiliSourceHasClamp()

    TestRobustness.testBacktrackSourceHasGuard()
    TestRobustness.testBacktrackTerminatesOnUnreachable()

    TestRobustness.testEndPersonDataSourceHasZeroGuard()
    TestRobustness.testDivByZeroProducesInf()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_robustness.lua$") then
    TestRobustness.runAll()
end

return TestRobustness
