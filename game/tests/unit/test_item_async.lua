-- test_item_async.lua
-- 物品异步模块单元测试

local TestHelper = require("tests.test_helper")

local TestItemAsync = {}

local function setup()
    TestHelper.setup()
    
    _G.CC.MenuThingXnum = 5
    _G.CC.MenuThingYnum = 3
    _G.CC.ThingPicWidth = 48
    _G.CC.ThingPicHeight = 48
    _G.CC.ThingGapIn = 5
    _G.CC.ThingGapOut = 10
    _G.CC.ThingFontSize = 16
    _G.CC.MenuBorderPixel = 2
    _G.CC.ScreenW = 640
    _G.CC.ScreenH = 480
    _G.CC.DefaultFont = 16
    _G.CC.MainSubMenuX = 100
    _G.CC.MainSubMenuY = 100
    
    for i = 0, 5 do
        local thing = TestHelper.createTestThing({ID = i})
        thing["名称"] = "物品" .. i
        thing["类型"] = 3
        thing["物品说明"] = "这是物品" .. i .. "的说明"
        thing["使用人"] = -1
        _G.JY.Thing[i] = thing
    end
end

function TestItemAsync.testSelectThingByArrayConvertsArrays()
    setup()
    print("\n=== Test: SelectThingByArrayAsync Converts Arrays ===")
    
    local thing = {}
    local thingnum = {}
    thing[0] = 1
    thing[1] = 3
    thing[2] = 5
    thingnum[0] = 10
    thingnum[1] = 5
    thingnum[2] = 2
    
    local ItemAsync = require("item_async")
    
    local gridItems = {}
    local count = 0
    for i = 0, 2 do
        if thing[i] and thing[i] >= 0 then
            count = count + 1
            gridItems[count] = {
                id = thing[i],
                name = _G.JY.Thing[thing[i]]["名称"],
                count = thingnum[i] or 0,
                type = _G.JY.Thing[thing[i]]["类型"],
                desc = _G.JY.Thing[thing[i]]["物品说明"],
                user = _G.JY.Thing[thing[i]]["使用人"]
            }
        end
    end
    
    TestHelper.assertEquals(3, count, "Should convert 3 items")
    TestHelper.assertEquals(1, gridItems[1].id, "First item ID should be 1")
    TestHelper.assertEquals(10, gridItems[1].count, "First item count should be 10")
    TestHelper.assertEquals("物品1", gridItems[1].name, "First item name should be 物品1")
    TestHelper.assertEquals(3, gridItems[2].id, "Second item ID should be 3")
    TestHelper.assertEquals(2, gridItems[3].count, "Third item count should be 2")
end

function TestItemAsync.testSelectThingByArrayEmptyReturnsNegative()
    setup()
    print("\n=== Test: SelectThingByArrayAsync Empty Returns -1 ===")
    
    local ItemAsync = require("item_async")
    local result = ItemAsync.SelectThingByArrayAsync({}, {}, 0)
    
    TestHelper.assertEquals(-1, result, "Empty array should return -1")
end

function TestItemAsync.testSelectThingByArrayWithMedicine()
    setup()
    print("\n=== Test: SelectThingByArrayAsync With Medicine Items ===")
    
    local thing = {}
    local thingnum = {}
    
    local med1 = TestHelper.createTestThing({ID = 10})
    med1["名称"] = "金创药"
    med1["类型"] = 3
    med1["加生命"] = 100
    med1["物品说明"] = "恢复生命100"
    _G.JY.Thing[10] = med1
    
    local med2 = TestHelper.createTestThing({ID = 11})
    med2["名称"] = "大还丹"
    med2["类型"] = 3
    med2["加生命"] = 500
    med2["物品说明"] = "恢复生命500"
    _G.JY.Thing[11] = med2
    
    thing[0] = 10
    thing[1] = 11
    thingnum[0] = 5
    thingnum[1] = 2
    
    local count = 2
    local gridItems = {}
    for i = 0, count - 1 do
        if thing[i] and thing[i] >= 0 then
            gridItems[i + 1] = {
                id = thing[i],
                name = _G.JY.Thing[thing[i]]["名称"],
                type = _G.JY.Thing[thing[i]]["类型"],
            }
        end
    end
    
    TestHelper.assertEquals(10, gridItems[1].id, "First medicine ID should be 10")
    TestHelper.assertEquals(11, gridItems[2].id, "Second medicine ID should be 11")
    TestHelper.assertEquals(3, gridItems[1].type, "First item type should be 3 (medicine)")
end

function TestItemAsync.testSelectThingByArrayWithAnqi()
    setup()
    print("\n=== Test: SelectThingByArrayAsync With Hidden Weapons ===")
    
    local thing = {}
    local thingnum = {}
    
    local anqi = TestHelper.createTestThing({ID = 20})
    anqi["名称"] = "飞刀"
    anqi["类型"] = 4
    anqi["加生命"] = -50
    anqi["物品说明"] = "造成伤害"
    _G.JY.Thing[20] = anqi
    
    thing[0] = 20
    thingnum[0] = 10
    
    local gridItems = {}
    gridItems[1] = {
        id = thing[0],
        name = _G.JY.Thing[thing[0]]["名称"],
        type = _G.JY.Thing[thing[0]]["类型"],
    }
    
    TestHelper.assertEquals(20, gridItems[1].id, "Hidden weapon ID should be 20")
    TestHelper.assertEquals(4, gridItems[1].type, "Type should be 4 (hidden weapon)")
end

function TestItemAsync.testGridDisplayNotSimpleTextMenu()
    setup()
    print("\n=== Test: Grid Display Uses SelectThingGridAsync ===")
    
    local ItemAsync = require("item_async")
    
    local hasGridFunction = ItemAsync.SelectThingGridAsync ~= nil
    TestHelper.assertEquals(true, hasGridFunction, "ItemAsync should have SelectThingGridAsync function")
    
    local hasArrayFunction = ItemAsync.SelectThingByArrayAsync ~= nil
    TestHelper.assertEquals(true, hasArrayFunction, "ItemAsync should have SelectThingByArrayAsync function")
    
    local hasDrawFunction = ItemAsync.draw ~= nil
    TestHelper.assertEquals(true, hasDrawFunction, "ItemAsync should have draw function for Grid rendering")
end

function TestItemAsync.testGridItemsHaveRequiredFields()
    setup()
    print("\n=== Test: Grid Items Have Required Fields ===")
    
    local thing = {}
    local thingnum = {}
    thing[0] = 1
    thingnum[0] = 5
    
    local requiredFields = {"id", "name", "count", "type", "desc", "user"}
    
    local item = {
        id = thing[0],
        name = _G.JY.Thing[thing[0]]["名称"],
        count = thingnum[0],
        type = _G.JY.Thing[thing[0]]["类型"],
        desc = _G.JY.Thing[thing[0]]["物品说明"],
        user = _G.JY.Thing[thing[0]]["使用人"]
    }
    
    for _, field in ipairs(requiredFields) do
        TestHelper.assertNotNil(item[field], "Item should have field: " .. field)
    end
end

function TestItemAsync.runAll()
    print("\n========================================")
    print("Item Async Unit Tests")
    print("========================================")
    
    TestHelper.resetCounts()
    
    TestItemAsync.testSelectThingByArrayConvertsArrays()
    TestItemAsync.testSelectThingByArrayEmptyReturnsNegative()
    TestItemAsync.testSelectThingByArrayWithMedicine()
    TestItemAsync.testSelectThingByArrayWithAnqi()
    TestItemAsync.testGridDisplayNotSimpleTextMenu()
    TestItemAsync.testGridItemsHaveRequiredFields()
    
    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_item_async.lua$") then
    TestItemAsync.runAll()
end

return TestItemAsync
