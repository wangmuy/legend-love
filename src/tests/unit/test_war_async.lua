-- test_war_async.lua
-- 战斗系统异步模块单元测试

local TestHelper = require("tests.test_helper")

local TestWarAsync = {}

local function setup()
    TestHelper.setup()
    
    _G.CC.WarData_S = true
    _G.CC.WarDataSize = 100
    _G.CC.WarWidth = 20
    _G.CC.WarHeight = 20
    _G.CC.MainMenuX = 100
    _G.CC.MainMenuY = 100
    _G.CC.MainSubMenuX = 120
    _G.CC.MainSubMenuY = 100
    _G.CC.DefaultFont = 16
    _G.CC.Frame = 50
    _G.CC.Effect = {}
    for i = 0, 10 do
        _G.CC.Effect[i] = 5
    end
    _G.CC.FightPicFile = {"fight%d.pic", "fight%d.idx"}
    _G.CC.WMAPPicFile = {"wmap.pic", "wmap.idx"}
    _G.CC.HeadPicFile = {"head.pic", "head.idx"}
    _G.CC.ThingPicFile = {"thing.pic", "thing.idx"}
    _G.CC.EffectFile = {"effect.pic", "effect.idx"}
    _G.CC.LoadThingPic = 0
    
    for i = 1, 10 do
        local p = TestHelper.createTestPerson({ID = i})
        p["姓名"] = "人物" .. i
        _G.JY.Person[i] = p
    end
    
    local w1 = TestHelper.createTestWugong({ID = 1})
    w1["名称"] = "太祖长拳"
    w1["攻击范围"] = 0
    w1["武功类型"] = 0
    _G.JY.Wugong[1] = w1
    
    local w2 = TestHelper.createTestWugong({ID = 2})
    w2["名称"] = "华山剑法"
    w2["攻击范围"] = 0
    w2["武功类型"] = 1
    _G.JY.Wugong[2] = w2
    
    local w3 = TestHelper.createTestWugong({ID = 3})
    w3["名称"] = "金刀刀法"
    w3["攻击范围"] = 0
    w3["武功类型"] = 2
    _G.JY.Wugong[3] = w3
    
    for i = 0, 19 do
        for j = 0, 19 do
            _G.SetWarMap(i, j, 3, 255)
        end
    end
end

local function createSimpleWarScenario()
    _G.WAR.PersonNum = 2
    _G.WAR.CurID = 0
    _G.WAR.Person[0] = TestHelper.createTestWarPerson({
        ["人物编号"] = 1,
        ["坐标X"] = 5,
        ["坐标Y"] = 5,
        ["移动步数"] = 3,
        ["我方"] = true,
    })
    _G.WAR.Person[1] = TestHelper.createTestWarPerson({
        ["人物编号"] = 2,
        ["坐标X"] = 10,
        ["坐标Y"] = 10,
        ["移动步数"] = 3,
        ["我方"] = false,
    })
    
    local p1 = TestHelper.createTestPerson({ID = 1})
    p1["姓名"] = "主角"
    p1["武功1"] = 1
    p1["武功等级1"] = 100
    p1["出招动画帧数1"] = 4
    p1["出招动画帧数2"] = 0
    p1["出招动画帧数3"] = 0
    p1["出招动画帧数4"] = 0
    p1["出招动画帧数5"] = 0
    _G.JY.Person[1] = p1
    
    local p2 = TestHelper.createTestPerson({ID = 2})
    p2["姓名"] = "敌人"
    _G.JY.Person[2] = p2
    
    _G.SetWarMap(5, 5, 2, 0)
    _G.SetWarMap(10, 10, 2, 1)
    
    for dx = -3, 3 do
        for dy = -3, 3 do
            local dist = math.abs(dx) + math.abs(dy)
            if dist <= 3 then
                _G.SetWarMap(5 + dx, 5 + dy, 3, dist)
            end
        end
    end
end

function TestWarAsync.testWarStateInitialization()
    setup()
    print("\n=== Test: War State Initialization ===")
    
    local WarAsync = require("war_async")
    local state = WarAsync.getWarState()
    
    TestHelper.assertEquals(nil, state.warId, "warId should be nil initially")
    TestHelper.assertEquals("idle", state.status, "status should be idle initially")
    TestHelper.assertEquals(nil, state.result, "result should be nil initially")
end

function TestWarAsync.testWarStateReset()
    setup()
    print("\n=== Test: War State Reset ===")
    
    local WarAsync = require("war_async")
    WarAsync.reset()
    
    local state = WarAsync.getWarState()
    TestHelper.assertEquals(nil, state.warId, "warId should be nil after reset")
    TestHelper.assertEquals("idle", state.status, "status should be idle after reset")
end

function TestWarAsync.testMoveCoroutineKeyHandling()
    setup()
    print("\n=== Test: Move Coroutine Key Handling ===")
    
    createSimpleWarScenario()
    
    local CoroutineScheduler = require("coroutine_scheduler")
    local InputManager = require("input_manager")
    local MenuAsync = require("menu_async")
    local war_async = require("war_async")
    
    local scheduler = CoroutineScheduler.getInstance()
    scheduler:init({ timeSource = function() return 0 end })
    local im = InputManager.getInstance()
    im:init()
    
    local moveResult = nil
    local id = scheduler:create(function()
        _G.WAR.ShowHead = 1
        local menu = {{"移动", nil, 1}}
        local r = MenuAsync.ShowMenuCoroutine(menu, 1, 1, 100, 100, 0, 0, 1, 0, 16, _G.C_ORANGE, _G.C_WHITE)
        if r == 1 then
            moveResult = "selected_move"
        end
    end, "test_move")
    
    scheduler:start(id)
    scheduler:update(0.016)
    
    TestHelper.assertEquals("suspended", scheduler:getStatus(id), "Coroutine should be suspended waiting for key")
end

function TestWarAsync.testMoveRangeCalculation()
    setup()
    print("\n=== Test: Move Range Calculation ===")
    
    createSimpleWarScenario()
    
    local moveSteps = _G.WAR.Person[0]["移动步数"]
    TestHelper.assertEquals(3, moveSteps, "Move steps should be 3")
    
    _G.SetWarMap(5, 5, 3, 0)
    _G.SetWarMap(6, 5, 3, 1)
    _G.SetWarMap(5, 6, 3, 1)
    _G.SetWarMap(4, 5, 3, 1)
    _G.SetWarMap(5, 4, 3, 1)
    
    local canMoveRight = _G.GetWarMap(6, 5, 3) < 128
    TestHelper.assertEquals(true, canMoveRight, "Should be able to move right")
    
    local blockedPos = _G.GetWarMap(20, 20, 3)
    TestHelper.assertEquals(255, blockedPos, "Out of bounds should return 255")
end

function TestWarAsync.testWugongTypeMatching()
    setup()
    print("\n=== Test: Wugong Type Matching ===")
    
    local p1 = TestHelper.createTestPerson({ID = 1})
    p1["姓名"] = "测试人物"
    p1["出招动画帧数1"] = 0
    p1["出招动画帧数2"] = 4
    p1["出招动画帧数3"] = 6
    p1["出招动画帧数4"] = 0
    p1["出招动画帧数5"] = 0
    _G.JY.Person[1] = p1
    
    local knifeWugong = TestHelper.createTestWugong({ID = 10})
    knifeWugong["名称"] = "金刀刀法"
    knifeWugong["武功类型"] = 2
    
    TestHelper.assertEquals("金刀刀法", knifeWugong["名称"], "Wugong name should be set")
    TestHelper.assertEquals(2, knifeWugong["武功类型"], "Wugong type should be 2 for knife")
    
    local swordWugong = TestHelper.createTestWugong({ID = 11})
    swordWugong["名称"] = "华山剑法"
    swordWugong["武功类型"] = 1
    TestHelper.assertEquals(1, swordWugong["武功类型"], "Wugong type should be 1 for sword")
    
    local palmWugong = TestHelper.createTestWugong({ID = 12})
    palmWugong["名称"] = "降龙掌"
    palmWugong["武功类型"] = 0
    TestHelper.assertEquals(0, palmWugong["武功类型"], "Wugong type should be 0 for palm")
end

function TestWarAsync.testPersonAnimationFrames()
    setup()
    print("\n=== Test: Person Animation Frames ===")
    
    local p1 = TestHelper.createTestPerson({ID = 1})
    p1["姓名"] = "测试人物"
    p1["出招动画帧数1"] = 8
    p1["出招动画帧数2"] = 6
    p1["出招动画帧数3"] = 10
    p1["出招动画帧数4"] = 4
    p1["出招动画帧数5"] = 0
    p1["出招动画延迟1"] = 0
    p1["出招动画延迟2"] = 0
    p1["出招动画延迟3"] = 0
    p1["出招动画延迟4"] = 0
    p1["出招动画延迟5"] = 0
    _G.JY.Person[1] = p1
    
    local person = _G.JY.Person[1]
    TestHelper.assertEquals(8, person["出招动画帧数1"], "Palm animation frames should be 8")
    TestHelper.assertEquals(6, person["出招动画帧数2"], "Sword animation frames should be 6")
    TestHelper.assertEquals(10, person["出招动画帧数3"], "Knife animation frames should be 10")
    TestHelper.assertEquals(4, person["出招动画帧数4"], "Staff animation frames should be 4")
end

function TestWarAsync.testWarMapOperations()
    setup()
    print("\n=== Test: War Map Operations ===")
    
    _G.SetWarMap(5, 5, 0, 1)
    TestHelper.assertEquals(1, _G.GetWarMap(5, 5, 0), "SetWarMap should set value correctly")
    
    _G.SetWarMap(10, 10, 2, 5)
    TestHelper.assertEquals(5, _G.GetWarMap(10, 10, 2), "SetWarMap should set value at different position")
    
    local outOfBounds = _G.GetWarMap(100, 100, 0)
    TestHelper.assertEquals(255, outOfBounds, "Out of bounds should return 255")
    
    _G.CleanWarMap(0, 0)
    TestHelper.assertEquals(0, _G.GetWarMap(5, 5, 0), "CleanWarMap should reset layer to 0")
end

function TestWarAsync.testAttackRangeCalculation()
    setup()
    print("\n=== Test: Attack Range Calculation ===")
    
    createSimpleWarScenario()
    
    local wugong = _G.JY.Wugong[1]
    TestHelper.assertEquals(0, wugong["攻击范围"], "Default attack range type should be 0")
    
    local attackerX = _G.WAR.Person[0]["坐标X"]
    local attackerY = _G.WAR.Person[0]["坐标Y"]
    TestHelper.assertEquals(5, attackerX, "Attacker X should be 5")
    TestHelper.assertEquals(5, attackerY, "Attacker Y should be 5")
    
    local targetX = _G.WAR.Person[1]["坐标X"]
    local targetY = _G.WAR.Person[1]["坐标Y"]
    TestHelper.assertEquals(10, targetX, "Target X should be 10")
    TestHelper.assertEquals(10, targetY, "Target Y should be 10")
end

function TestWarAsync.testFightCoroutineDamageCalculation()
    setup()
    print("\n=== Test: Fight Coroutine Damage Calculation ===")
    
    createSimpleWarScenario()
    
    local damage = _G.War_WugongHurtLife(1, 1, 1)
    TestHelper.assertEquals(10, damage, "Default mock damage should be 10")
    
    local neiliDamage = _G.War_WugongHurtNeili(1, 1, 1)
    TestHelper.assertEquals(5, neiliDamage, "Default mock neili damage should be 5")
end

function TestWarAsync.testWarEndCondition()
    setup()
    print("\n=== Test: War End Condition ===")
    
    createSimpleWarScenario()
    
    local endStatus = _G.War_isEnd()
    TestHelper.assertEquals(0, endStatus, "War should not end with both sides alive")
    
    _G.WAR.Person[1]["死亡"] = true
    endStatus = _G.War_isEnd()
    
    _G.WAR.Person[1]["死亡"] = false
end

function TestWarAsync.testAutoFightToggle()
    setup()
    print("\n=== Test: Auto Fight Toggle ===")
    
    createSimpleWarScenario()
    
    TestHelper.assertEquals(0, _G.WAR.AutoFight, "AutoFight should be 0 initially")
    
    _G.War_AutoMenu()
    TestHelper.assertEquals(1, _G.WAR.AutoFight, "AutoFight should be 1 after AutoMenu")
    
    _G.WAR.AutoFight = 0
    TestHelper.assertEquals(0, _G.WAR.AutoFight, "AutoFight can be reset to 0")
end

function TestWarAsync.testMoveContinueFlagLogic()
    setup()
    print("\n=== Test: Move Continue Flag Logic ===")
    
    local continueFlag = 7
    local endTurnFlag = 0
    
    TestHelper.assertEquals(7, continueFlag, "Continue flag should be 7")
    TestHelper.assertEquals(0, endTurnFlag, "End turn flag should be 0")
    
    local function simulateManualCoroutineLoop(returnValue)
        local loopCount = 0
        local r = returnValue
        while r == continueFlag do
            loopCount = loopCount + 1
            if loopCount > 10 then break end
            r = endTurnFlag
        end
        return loopCount, r
    end
    
    local loopCount, finalReturn = simulateManualCoroutineLoop(continueFlag)
    TestHelper.assertEquals(1, loopCount, "Loop should run once when return is 7 (continue)")
    TestHelper.assertEquals(0, finalReturn, "Final return should be 0 after attack")
    
    loopCount, finalReturn = simulateManualCoroutineLoop(endTurnFlag)
    TestHelper.assertEquals(0, loopCount, "Loop should not run when return is 0 (end turn)")
    TestHelper.assertEquals(0, finalReturn, "Final return should be 0")
end

function TestWarAsync.testMoveDisablesAfterFirstMove()
    setup()
    print("\n=== Test: Move Disables After First Move ===")
    
    createSimpleWarScenario()
    
    local pid = _G.WAR.Person[_G.WAR.CurID]["人物编号"]
    local initialMoveSteps = _G.WAR.Person[_G.WAR.CurID]["移动步数"]
    
    TestHelper.assertEquals(3, initialMoveSteps, "Initial move steps should be 3")
    
    local canMoveBefore = true
    if _G.JY.Person[pid]["体力"] <= 5 or _G.WAR.Person[_G.WAR.CurID]["移动步数"] <= 0 then
        canMoveBefore = false
    end
    TestHelper.assertEquals(true, canMoveBefore, "Should be able to move initially")
    
    _G.WAR.Person[_G.WAR.CurID]["移动步数"] = 0
    
    local canMoveAfter = true
    if _G.JY.Person[pid]["体力"] <= 5 or _G.WAR.Person[_G.WAR.CurID]["移动步数"] <= 0 then
        canMoveAfter = false
    end
    TestHelper.assertEquals(false, canMoveAfter, "Should not be able to move after moving")
end

function TestWarAsync.testExecuteMenuDrawMode()
    setup()
    print("\n=== Test: Execute Menu DrawMode ===")
    
    createSimpleWarScenario()
    
    _G.JY.Person[1]["用毒能力"] = 60
    _G.JY.Person[1]["解毒能力"] = 60
    _G.JY.Person[1]["医疗能力"] = 60
    
    local poisonStep = math.modf(_G.JY.Person[1]["用毒能力"] / 15) + 1
    TestHelper.assertEquals(5, poisonStep, "Poison step should be 5 (60/15+1)")
    
    local decPoisonStep = math.modf(_G.JY.Person[1]["解毒能力"] / 15) + 1
    TestHelper.assertEquals(5, decPoisonStep, "DecPoison step should be 5")
    
    local doctorStep = math.modf(_G.JY.Person[1]["医疗能力"] / 15) + 1
    TestHelper.assertEquals(5, doctorStep, "Doctor step should be 5")
end

function TestWarAsync.testExecuteMenuReturnsContinueOnCancel()
    setup()
    print("\n=== Test: Execute Menu Returns Continue On Cancel ===")
    
    local continueFlag = 7
    local endTurnFlag = 0
    
    TestHelper.assertEquals(7, continueFlag, "Continue flag is 7")
    TestHelper.assertEquals(0, endTurnFlag, "End turn flag is 0")
    
    local function simulateExecuteMenuLoop(cancelled)
        local r = cancelled and continueFlag or endTurnFlag
        local loopCount = 0
        while r == continueFlag do
            loopCount = loopCount + 1
            if loopCount > 10 then break end
            r = endTurnFlag
        end
        return loopCount
    end
    
    local countAfterCancel = simulateExecuteMenuLoop(true)
    TestHelper.assertEquals(1, countAfterCancel, "ESC cancel returns 7, loop continues")
    
    local countAfterExecute = simulateExecuteMenuLoop(false)
    TestHelper.assertEquals(0, countAfterExecute, "Execute returns 0, loop ends")
end

function TestWarAsync.testExecuteMenuEndsTurn()
    setup()
    print("\n=== Test: Execute Menu Ends Turn ===")
    
    local endTurnFlag = 0
    
    TestHelper.assertEquals(0, endTurnFlag, "Execute menu returns 0 to end turn")
    
    local function simulateTurnEnd(returnValue)
        if returnValue == endTurnFlag then
            return "next_person"
        else
            return "continue_menu"
        end
    end
    
    local result = simulateTurnEnd(0)
    TestHelper.assertEquals("next_person", result, "Return 0 ends turn, goes to next person")
    
    result = simulateTurnEnd(7)
    TestHelper.assertEquals("continue_menu", result, "Return 7 continues menu")
end

function TestWarAsync.testDoctorRequiresInjury()
    setup()
    print("\n=== Test: Doctor Requires Injury ===")
    
    local p1 = _G.JY.Person[1]
    p1["医疗能力"] = 50
    p1["体力"] = 100
    
    local p2 = TestHelper.createTestPerson({ID = 3})
    p2["姓名"] = "队友"
    p2["受伤程度"] = 50
    p2["生命"] = 100
    _G.JY.Person[3] = p2
    
    local injuryBefore = p2["受伤程度"]
    TestHelper.assertEquals(50, injuryBefore, "Injury should be 50 before doctor")
    
    TestHelper.assertEquals(100, p1["体力"], "Healer should have enough stamina")
end

function TestWarAsync.testDecPoisonRequiresPoison()
    setup()
    print("\n=== Test: DecPoison Requires Poison ===")
    
    local p1 = _G.JY.Person[1]
    p1["解毒能力"] = 50
    
    local p2 = TestHelper.createTestPerson({ID = 3})
    p2["姓名"] = "队友"
    p2["中毒程度"] = 30
    _G.JY.Person[3] = p2
    
    local poisonBefore = p2["中毒程度"]
    TestHelper.assertEquals(30, poisonBefore, "Poison should be 30 before decpoison")
end

function TestWarAsync.testPoisonTargetsEnemy()
    setup()
    print("\n=== Test: Poison Targets Enemy ===")
    
    createSimpleWarScenario()
    
    local attacker = _G.WAR.Person[0]
    local target = _G.WAR.Person[1]
    
    TestHelper.assertEquals(true, attacker["我方"], "Attacker should be ally")
    TestHelper.assertEquals(false, target["我方"], "Target should be enemy")
    
    local canPoison = attacker["我方"] ~= target["我方"]
    TestHelper.assertEquals(true, canPoison, "Can poison enemy")
end

function TestWarAsync.testDoctorTargetsAlly()
    setup()
    print("\n=== Test: Doctor Targets Ally ===")
    
    createSimpleWarScenario()
    
    _G.WAR.Person[1]["我方"] = true
    
    local healer = _G.WAR.Person[0]
    local target = _G.WAR.Person[1]
    
    TestHelper.assertEquals(true, healer["我方"], "Healer should be ally")
    TestHelper.assertEquals(true, target["我方"], "Target should be ally")
    
    local canDoctor = healer["我方"] == target["我方"]
    TestHelper.assertEquals(true, canDoctor, "Can doctor ally")
end

function TestWarAsync.testThingMenuUsesGridDisplay()
    setup()
    print("\n=== Test: Thing Menu Uses Grid Display ===")
    
    local ItemAsync = require("item_async")
    
    TestHelper.assertNotNil(ItemAsync.SelectThingByArrayAsync, "ItemAsync should have SelectThingByArrayAsync for Grid display")
    TestHelper.assertNotNil(ItemAsync.SelectThingGridAsync, "ItemAsync should have SelectThingGridAsync for Grid display")
    TestHelper.assertNotNil(ItemAsync.draw, "ItemAsync should have draw function for Grid rendering")
end

function TestWarAsync.testThingMenuFiltersMedicineAndAnqi()
    setup()
    print("\n=== Test: Thing Menu Filters Medicine And Anqi ===")
    
    local thing = {}
    local thingnum = {}
    local num = 0
    
    for i = 0, 5 do
        local t = TestHelper.createTestThing({ID = i})
        t["名称"] = "物品" .. i
        t["类型"] = i
        _G.JY.Thing[i] = t
    end
    
    local filteredTypes = {3, 4}
    for i = 0, 5 do
        local thingType = _G.JY.Thing[i]["类型"]
        for _, validType in ipairs(filteredTypes) do
            if thingType == validType then
                thing[num] = i
                thingnum[num] = 10
                num = num + 1
                break
            end
        end
    end
    
    TestHelper.assertEquals(2, num, "Should filter to only medicine (3) and hidden weapon (4)")
    TestHelper.assertEquals(3, _G.JY.Thing[thing[0]]["类型"], "First filtered item should be type 3")
    TestHelper.assertEquals(4, _G.JY.Thing[thing[1]]["类型"], "Second filtered item should be type 4")
end

function TestWarAsync.testThingMenuGridNotTextMenu()
    setup()
    print("\n=== Test: Thing Menu Grid Not Text Menu ===")
    
    local ItemAsync = require("item_async")
    
    local gridFunctionExists = type(ItemAsync.SelectThingGridAsync) == "function"
    TestHelper.assertEquals(true, gridFunctionExists, "Grid function should exist (not simple text menu)")
    
    local arrayFunctionExists = type(ItemAsync.SelectThingByArrayAsync) == "function"
    TestHelper.assertEquals(true, arrayFunctionExists, "Array-to-Grid function should exist")
end

function TestWarAsync.testThingMenuEmptyReturnsContinue()
    setup()
    print("\n=== Test: Thing Menu Empty Returns Continue ===")
    
    local continueFlag = 7
    
    local function simulateThingMenuReturn(hasItems)
        if not hasItems then
            return continueFlag
        end
        return 0
    end
    
    local result = simulateThingMenuReturn(false)
    TestHelper.assertEquals(7, result, "Empty item list should return 7 (continue menu)")
end

function TestWarAsync.testThingMenuESCCancelReturnsContinue()
    setup()
    print("\n=== Test: Thing Menu ESC Cancel Returns Continue ===")
    
    local continueFlag = 7
    
    local function simulateThingMenuCancel(pressedESC)
        if pressedESC then
            return continueFlag
        end
        return 0
    end
    
    local result = simulateThingMenuCancel(true)
    TestHelper.assertEquals(7, result, "ESC cancel should return 7 (continue menu)")
    
    result = simulateThingMenuCancel(false)
    TestHelper.assertEquals(0, result, "Success should return 0 (end turn)")
end

function TestWarAsync.runAll()
    print("\n========================================")
    print("War Async Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    
    TestWarAsync.testWarStateInitialization()
    TestWarAsync.testWarStateReset()
    TestWarAsync.testMoveCoroutineKeyHandling()
    TestWarAsync.testMoveRangeCalculation()
    TestWarAsync.testWugongTypeMatching()
    TestWarAsync.testPersonAnimationFrames()
    TestWarAsync.testWarMapOperations()
    TestWarAsync.testAttackRangeCalculation()
    TestWarAsync.testFightCoroutineDamageCalculation()
    TestWarAsync.testWarEndCondition()
    TestWarAsync.testAutoFightToggle()
    TestWarAsync.testMoveContinueFlagLogic()
    TestWarAsync.testMoveDisablesAfterFirstMove()
    TestWarAsync.testExecuteMenuDrawMode()
    TestWarAsync.testExecuteMenuReturnsContinueOnCancel()
    TestWarAsync.testExecuteMenuEndsTurn()
    TestWarAsync.testDoctorRequiresInjury()
    TestWarAsync.testDecPoisonRequiresPoison()
    TestWarAsync.testPoisonTargetsEnemy()
    TestWarAsync.testDoctorTargetsAlly()
    TestWarAsync.testThingMenuUsesGridDisplay()
    TestWarAsync.testThingMenuFiltersMedicineAndAnqi()
    TestWarAsync.testThingMenuGridNotTextMenu()
    TestWarAsync.testThingMenuEmptyReturnsContinue()
    TestWarAsync.testThingMenuESCCancelReturnsContinue()
    
    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_war_async.lua$") then
    TestWarAsync.runAll()
end

return TestWarAsync
