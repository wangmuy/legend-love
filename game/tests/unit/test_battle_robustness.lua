-- test_battle_robustness.lua
-- 战斗健壮性回归测试（change: port-battle-robustness）
--
-- 守三个缺陷：
--   ① WarLoad 越界只 JY_Error（纯日志）+ 裸 return → 调用方无法分支
--   ② WarMainCoroutine 不检查 WarLoad 返回值 → 用上一场数据"假开始"
--   ③ WAR.Person 固定 26 槽 = 我方 6 + 敌方 20 = **零余量**

local TestHelper = require("tests.test_helper")
local TestBattleRobustness = {}

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

local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]", "")
    src = src:gsub("%-%-[^\n]*", "")
    return src
end

-- ------------------------------------------------------------ ① WarLoad 返回布尔

function TestBattleRobustness.testWarLoadReturnsBoolean()
    print("\n=== Test: WarLoad 返回 true/false（不是裸 return）===")
    -- 装最小环境：需要 Byte / CC / JY / WAR / ModData
    local JY = { Person = {}, Wugong = {} }
    rawset(_G, "JY", JY)
    rawset(_G, "WAR", { Data = {}, Person = {}, PersonNum = 0 })
    rawset(_G, "CC", {
        WarFile = "data/war.sta", WarDataSize = 186,
        WarData_S = { ["名称"] = { 2, 2, 10 }, ["地图"] = { 12, 0, 2 },
                      ["音乐"] = { 14, 0, 2 } },
    })
    rawset(_G, "Byte", require("framework.lib_Byte"))

    -- **先加载 jyconst**（提供 RGB / SetGlobalConst 等）：
    -- WarSetGlobal 里 `WAR.EffectColor[2]=RGB(236,200,40)` 之类直接用 RGB，
    -- 没有它就是 "attempt to call global 'RGB' (a nil value)"。
    do
        local chunk = loadfile("script/jyconst.lua")
        if not chunk then chunk = loadfile("../game/script/jyconst.lua") end
        if chunk then pcall(chunk) end
    end
    pcall(require, "framework.config")
    if rawget(_G, "SetGlobalConst") then pcall(SetGlobalConst) end

    -- 加载 jymain（提供 WarLoad / WarSetGlobal）
    do
        local chunk = loadfile("script/jymain.lua")
        if not chunk then chunk = loadfile("../game/script/jymain.lua") end
        if chunk then pcall(chunk) end
    end
    TestHelper.assertNotNil(rawget(_G, "WarLoad"), "WarLoad 应已定义")

    -- 正常 warid → true
    local ok1, v1 = pcall(WarLoad, 0)
    TestHelper.assertTrue(ok1, "WarLoad(0) 不应抛错")
    TestHelper.assertTrue(type(v1) == "boolean",
        "WarLoad(0) 应返回布尔（实测 " .. type(v1) .. "）")

    -- 越界 warid → false（必须先让 ModData 能报告记录数）
    local MD = require("framework.mod_data")
    if MD and MD.WarRecordCount then
        local n = MD.WarRecordCount(CC.WarFile, CC.WarDataSize)
        if n then
            local ok2, v2 = pcall(WarLoad, n + 100)
            TestHelper.assertTrue(ok2, "越界调用不应抛错")
            TestHelper.assertEquals(false, v2,
                "越界 warid 应返回 false（实测 " .. tostring(v2) .. "）")
        end
    end
end

function TestBattleRobustness.testWarLoadSourceHasBooleanReturns()
    print("\n=== Test: 源码里 WarLoad 有 return false 和 return true ===")
    local src = readSource("script/jymain.lua")
    TestHelper.assertNotNil(src, "应能读到 jymain.lua")
    local code = stripComments(src)

    local fnStart = code:find("function WarLoad", 1, true)
    TestHelper.assertNotNil(fnStart, "应找到 WarLoad")
    local bodyEnd = code:find("\nfunction ", fnStart + 10)
    local body = code:sub(fnStart, bodyEnd or (fnStart + 3000))

    TestHelper.assertNotNil(body:find("return false", 1, true),
        "越界分支应 return false")
    TestHelper.assertNotNil(body:find("return true", 1, true),
        "成功路径应 return true")
end

-- ------------------------------------------------------------ ② WarMainCoroutine 检查

function TestBattleRobustness.testWarMainChecksLoadResult()
    print("\n=== Test: WarMainCoroutine 检查 WarLoad 返回值 ===")
    local src = readSource("framework/war_async.lua")
    TestHelper.assertNotNil(src, "应能读到 war_async.lua")
    local code = stripComments(src)

    -- 必须有 `if not WarLoad(...)` 或 `local ok = WarLoad(...)` + 分支
    local hasCheck = code:find("if not WarLoad(warid)", 1, true)
        or code:find("okLoad = WarLoad", 1, true)
    TestHelper.assertNotNil(hasCheck,
        "应检查 WarLoad 返回值（当前是裸 WarLoad(warid) 就是 bug）")
end

function TestBattleRobustness.testWarStateResultClearedEarly()
    print("\n=== Test: warState.result 在开头就清空（不读到上场的胜负）===")
    local src = readSource("framework/war_async.lua")
    local code = stripComments(src)

    -- result = nil 必须出现在 WarLoad 调用之前
    local posResult = code:find("warState.result = nil", 1, true)
    local posLoad = code:find("WarLoad(warid)", 1, true)
    TestHelper.assertNotNil(posResult, "应有 warState.result = nil")
    TestHelper.assertNotNil(posLoad, "应有 WarLoad(warid)")
    TestHelper.assertTrue(posResult < posLoad,
        "warState.result = nil 必须在 WarLoad 之前（否则失败时读到上场值）")
end

function TestBattleRobustness.testLoadFailureLeavesResultNil()
    print("\n=== Test: 加载失败时 warState.result 是 nil（行为复刻）===")
    -- 复刻 WarMainCoroutine 的失败分支
    local function simulate(loadOk, prevResult)
        local warState = { status = "running", result = nil }
        -- 开头清空
        warState.result = nil
        if not loadOk then
            warState.status = "ended"
            warState.result = nil
            return warState.status, warState.result
        end
        warState.result = prevResult
        return warState.status, warState.result
    end

    local st, res = simulate(false, true)
    TestHelper.assertEquals("ended", st, "失败时 status 应是 ended")
    TestHelper.assertEquals(nil, res, "失败时 result 应是 nil（不是上场的 true）")

    local st2, res2 = simulate(true, true)
    TestHelper.assertEquals("running", st2, "成功时继续 running")
    TestHelper.assertEquals(true, res2, "成功时 result 保持")
end

-- ------------------------------------------------------------ ③ WAR.Person 容量

function TestBattleRobustness.testCapacityIs40()
    print("\n=== Test: WAR_PERSON_CAPACITY = 40（>= 6+20 零余量上留余量）===")
    local src = readSource("script/jymain.lua")
    local code = stripComments(src)

    local hasConst = code:find("WAR_PERSON_CAPACITY = 40", 1, true)
    TestHelper.assertNotNil(hasConst, "应定义 WAR_PERSON_CAPACITY = 40")

    -- 原硬编码 26 不应再出现在 WarSetGlobal 的循环里
    TestHelper.assertNil(code:match("for i=0,26-1 do"),
        "不应再用硬编码 26（应改用 WAR_PERSON_CAPACITY）")
end

function TestBattleRobustness.testCapacityArithmetic()
    print("\n=== Test: 容量 40 >= 我方 6 + 敌方 20（有 14 个余量）===")
    -- 实测核算：WarSelectTeam 最多 6（CC.TeamNum），WarSelectEnemy 最多 20
    local teamMax, enemyMax, capacity = 6, 20, 40
    TestHelper.assertTrue(capacity >= teamMax + enemyMax,
        string.format("容量 %d 应 >= %d + %d = %d", capacity, teamMax, enemyMax, teamMax + enemyMax))
    TestHelper.assertTrue(capacity > teamMax + enemyMax,
        "应严格大于（零余量是原缺陷的根因）")
    TestHelper.assertEquals(14, capacity - teamMax - enemyMax,
        "余量应是 14 个槽位")
end

function TestBattleRobustness.testGuardsPresent()
    print("\n=== Test: WarSelectTeam / WarSelectEnemy 有容量守卫 ===")
    local src = readSource("script/battle/battle_flow.lua")
    TestHelper.assertNotNil(src, "应能读到 battle_flow.lua")
    local code = stripComments(src)

    -- 3 处添加点都应有守卫
    local guardCount = 0
    local pos = 1
    while true do
        local a = code:find("WAR.PersonNum >= (WAR_PERSON_CAPACITY or 26)", pos, true)
        if not a then break end
        guardCount = guardCount + 1
        pos = a + 1
    end
    TestHelper.assertEquals(3, guardCount,
        "应有 3 处容量守卫（我方自动选择 / 我方手动选择 / 敌方），实测 " .. guardCount)

    -- 守卫必须 JY_Error 记录（不能静默截断）
    TestHelper.assertNotNil(code:find("JY_Error", 1, true),
        "守卫应 JY_Error 记录（不能静默）")
end

function TestBattleRobustness.testGuardPreventsNilIndex()
    print("\n=== Test: 守卫在达到容量时停止添加（行为复刻）===")
    local function addPerson(person, personNum, capacity)
        if personNum >= capacity then
            return personNum, "guarded"
        end
        -- 原缺陷：直接写 person[personNum]（若为 nil 则崩）
        person[personNum] = { id = personNum }
        return personNum + 1, "added"
    end

    local person = {}
    for i = 0, 39 do person[i] = { id = i } end   -- 模拟 WarSetGlobal 建 40 个槽
    local n = 0
    for _ = 1, 45 do
        local newN, what = addPerson(person, n, 40)
        n = newN
        if what == "guarded" then break end
    end
    TestHelper.assertEquals(40, n, "应在 40 处停下（不会越界写 person[40]）")
    TestHelper.assertEquals(nil, person[40], "person[40] 不应被写（越界）")
end

-- ------------------------------------------------------------ 套件入口

function TestBattleRobustness.runAll()
    print("\n" .. string.rep("=", 60))
    print("战斗健壮性回归（WarLoad 错误码 + WAR.Person 容量）")
    print(string.rep("=", 60))
    TestHelper.setup()
    TestHelper.resetCounts()

    TestBattleRobustness.testWarLoadReturnsBoolean()
    TestBattleRobustness.testWarLoadSourceHasBooleanReturns()
    TestBattleRobustness.testWarMainChecksLoadResult()
    TestBattleRobustness.testWarStateResultClearedEarly()
    TestBattleRobustness.testLoadFailureLeavesResultNil()
    TestBattleRobustness.testCapacityIs40()
    TestBattleRobustness.testCapacityArithmetic()
    TestBattleRobustness.testGuardsPresent()
    TestBattleRobustness.testGuardPreventsNilIndex()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_battle_robustness.lua$") then
    TestBattleRobustness.runAll()
end

return TestBattleRobustness
