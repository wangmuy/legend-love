-- test_item_status_mouse.lua
-- 物品清单与人物状态页的鼠标交互测试（REQ-MS2-9 / REQ-MS2-10）
--
-- 这两处都是 `while true do WaitKey() end` 的协程，鼠标无法直接让它返回，
-- 采用「记录意图 + 注入唤醒键 + 循环开头消费意图」的模式。
-- 本文件重点验证：
--   ① 布局公式与绘制一致（点了能命中）
--   ② 点击确实产生了正确的意图（选中第 N 个 / 翻下一页）

local TestHelper = require("tests.test_helper")
local TestItemStatusMouse = {}

local function installStubs()
    local saved = {
        CC = rawget(_G, "CC"),
        lib = rawget(_G, "lib"),
        JY = rawget(_G, "JY"),
        VK_SPACE = rawget(_G, "VK_SPACE"),
        VK_ESCAPE = rawget(_G, "VK_ESCAPE"),
        VK_UP = rawget(_G, "VK_UP"),
        VK_DOWN = rawget(_G, "VK_DOWN"),
        VK_LEFT = rawget(_G, "VK_LEFT"),
        VK_RIGHT = rawget(_G, "VK_RIGHT"),
        VK_RETURN = rawget(_G, "VK_RETURN"),
        InputManager = nil,
        EngineAPI = rawget(_G, "EngineAPI"),
        __testClock = rawget(_G, "__testClock"),
    }
    rawset(_G, "CC", {
        ScreenW = 1024, ScreenH = 768,
        DefaultFont = 24, MenuBorderPixel = 5, RowPixel = 4,
        PersonStateRowPixel = 4,
        ThingPicWidth = 40, ThingPicHeight = 40,
        ThingGapIn = 5, ThingGapOut = 10, ThingFontSize = 24,
        MenuThingXnum = 5, MenuThingYnum = 3,
    })
    rawset(_G, "lib", { Debug = function() end })
    rawset(_G, "JY", { Base = {}, Thing = {}, Person = {} })
    rawset(_G, "VK_SPACE", 32)
    rawset(_G, "VK_ESCAPE", 27)
    -- 方向键也要定义：item_async 的键盘分支会读它们
    rawset(_G, "VK_UP", 1073741906)
    rawset(_G, "VK_DOWN", 1073741905)
    rawset(_G, "VK_LEFT", 1073741904)
    rawset(_G, "VK_RIGHT", 1073741903)
    rawset(_G, "VK_RETURN", 13)
    -- **可推进的假时钟**：os.clock() 在纯 CPU 循环里几乎不前进，
    -- 于是 WaitKeyTimeoutBypass 的 50ms 超时永远不到期 ——
    -- 超时轮询的实现根本测不出来。用一个测试可控的计数器。
    local fakeNow = { t = 0 }
    rawset(_G, "EngineAPI", {
        time = {
            getTime = function() return fakeNow.t * 1000 end,
            getTimeSeconds = function() return fakeNow.t end,
        },
    })
    rawset(_G, "__testClock", fakeNow)
    return saved
end

local function restoreStubs(saved)
    for k, v in pairs(saved) do
        if k ~= "InputManager" then rawset(_G, k, v) end
    end
end

-- 推进假时钟并跑一帧调度
local function advance(seconds)
    local clock = rawget(_G, "__testClock")
    if clock then clock.t = clock.t + (seconds or 0.02) end
    local SC = require("framework.coroutine_scheduler")
    SC.getInstance():update(seconds or 0.02)
end

local function freshItem()
    package.loaded["framework.item_async"] = nil
    return require("framework.item_async")
end

local function freshStatus()
    package.loaded["framework.person_status_async"] = nil
    return require("framework.person_status_async")
end

-- ============================================================
-- REQ-MS2-9 物品网格布局
-- ============================================================

function TestItemStatusMouse.testItemLayoutMatchesDraw()
    print("\n=== Test: 物品网格布局公式 ===")
    local saved = installStubs()
    local IA = freshItem()

    local select = {
        xnum = 5, ynum = 3, currentPage = 1, totalPages = 1,
        selectedIndex = 1, pageStart = 1, pageEnd = 7,
        items = {}, itemCount = 7,
    }
    local L = IA.layout(select)

    TestHelper.assertNotNil(L, "layout 返回表")
    -- w = 40*5 + 4*5 + 2*10 = 240
    TestHelper.assertEquals(240, L.w, "宽 = 240（与 draw 公式一致）")
    -- h = 40*3 + 2*5 + 2*10 = 150
    TestHelper.assertEquals(150, L.h, "高 = 150")
    -- dx = (1024-240)/2 = 392
    TestHelper.assertEquals(392, L.dx, "dx 居中")
    restoreStubs(saved)
end

function TestItemStatusMouse.testItemGridHitTest()
    print("\n=== Test: 物品格命中测试（含第二行）===")
    local saved = installStubs()
    local IA = freshItem()

    local select = {
        xnum = 5, ynum = 3, currentPage = 1, totalPages = 1,
        selectedIndex = 1, pageStart = 1, pageEnd = 7,
        items = {}, itemCount = 7,
    }
    local L = IA.layout(select)

    -- 直接调被实现使用的那份 API（不是复刻一份公式），
    -- 否则公式写错时测试也会跟着"正确地"通过。
    local cx0 = L.dx + L.gapOut
    local cy0 = L.y3_1 + L.gapOut

    TestHelper.assertEquals(1, IA.indexAt(select, cx0 + 20, cy0 + 20), "第 1 格")
    TestHelper.assertEquals(2, IA.indexAt(select, cx0 + 45 + 20, cy0 + 20), "第 2 格")
    TestHelper.assertEquals(5, IA.indexAt(select, cx0 + 4 * 45 + 20, cy0 + 20), "第 5 格")
    TestHelper.assertEquals(6, IA.indexAt(select, cx0 + 20, cy0 + 45 + 20),
        "第 6 格（第二行第 1 个）—— 换行公式必须用 floor")
    TestHelper.assertEquals(7, IA.indexAt(select, cx0 + 45 + 20, cy0 + 45 + 20), "第 7 格")
    TestHelper.assertEquals(nil, IA.indexAt(select, L.dx + 20, L.dy + 20),
        "点信息框区域 → nil（不误选）")
    TestHelper.assertEquals(nil, IA.indexAt(select, L.dx - 100, L.dy - 100),
        "网格外 → nil")
    restoreStubs(saved)
end

function TestItemStatusMouse.testItemIndexAtSecondRow()
    print("\n=== Test: 第二行索引（换行公式）===")
    local saved = installStubs()
    local IA = freshItem()

    local select = {
        xnum = 5, ynum = 3, currentPage = 1, totalPages = 1,
        selectedIndex = 1, pageStart = 1, pageEnd = 15,
        items = {}, itemCount = 15,
    }
    local L = IA.layout(select)
    local cx0 = L.dx + L.gapOut
    local cy0 = L.y3_1 + L.gapOut
    local step = L.cellW + L.gapIn       -- 45

    -- 第 2 行：索引 6..10
    TestHelper.assertEquals(6, IA.indexAt(select, cx0 + 20, cy0 + step + 20),
        "第二行第 1 个 = 6")
    TestHelper.assertEquals(10, IA.indexAt(select, cx0 + 4 * step + 20, cy0 + step + 20),
        "第二行第 5 个 = 10")
    -- 第 3 行：索引 11..15
    TestHelper.assertEquals(11, IA.indexAt(select, cx0 + 20, cy0 + 2 * step + 20),
        "第三行第 1 个 = 11")
    restoreStubs(saved)
end

function TestItemStatusMouse.testItemIndexAtSecondPage()
    print("\n=== Test: 第二页的索引偏移 ===")
    local saved = installStubs()
    local IA = freshItem()

    -- 第 2 页：pageStart = 16
    local select = {
        xnum = 5, ynum = 3, currentPage = 2, totalPages = 2,
        selectedIndex = 16, pageStart = 16, pageEnd = 20,
        items = {}, itemCount = 20,
    }
    local L = IA.layout(select)
    local cx0 = L.dx + L.gapOut
    local cy0 = L.y3_1 + L.gapOut

    TestHelper.assertEquals(16, IA.indexAt(select, cx0 + 20, cy0 + 20),
        "第 2 页第 1 格 = 全局索引 16（不是 1）")
    TestHelper.assertEquals(17, IA.indexAt(select, cx0 + 45 + 20, cy0 + 20),
        "第 2 页第 2 格 = 17")
    restoreStubs(saved)
end

function TestItemStatusMouse.testItemHandleClickRequiresActive()
    print("\n=== Test: 未打开物品清单时不处理点击 ===")
    local saved = installStubs()
    local IA = freshItem()

    TestHelper.assertFalse(IA.isActive(), "初始未激活")
    TestHelper.assertFalse(IA.handleMouseClick(500, 400),
        "未打开 → 不处理（让点击落到别处）")
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-10 状态页布局与翻页
-- ============================================================

function TestItemStatusMouse.testStatusLayoutMatchesDraw()
    print("\n=== Test: 状态框布局公式（与 ShowPersonStatus_sub 一致）===")
    local saved = installStubs()
    local PS = freshStatus()

    local L = PS.layout()
    -- width = 18*24 + 15 = 447
    TestHelper.assertEquals(447, L.w, "宽 = 18*font + 15")
    -- h = 24 + 4 = 28；height = 13*28 + 10 = 374
    TestHelper.assertEquals(374, L.h, "高 = 13*(font+rowPix) + 10")
    TestHelper.assertEquals((1024 - 447) / 2, L.dx, "dx 居中")
    restoreStubs(saved)
end

function TestItemStatusMouse.testStatusHandleClickRequiresActive()
    print("\n=== Test: 未打开状态页时不处理点击 ===")
    local saved = installStubs()
    local PS = freshStatus()

    TestHelper.assertFalse(PS.isActive(), "初始未激活")
    TestHelper.assertFalse(PS.handleMouseClick(500, 400),
        "未打开 → 不处理")
    restoreStubs(saved)
end

function TestItemStatusMouse.testStatusPageNum()
    print("\n=== Test: 状态页共 2 页 ===")
    local saved = installStubs()
    local PS = freshStatus()
    TestHelper.assertEquals(2, PS.PAGE_NUM, "与 ShowPersonStatus 的 pagenum 一致")
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-11 物品格悬停（与键盘方向键效果一致）
-- ============================================================

function TestItemStatusMouse.testItemHoverRequiresActive()
    print("\n=== Test: 未打开物品清单时不处理悬停 ===")
    local saved = installStubs()
    local IA = freshItem()

    TestHelper.assertFalse(IA.handleMouseHover(500, 400),
        "未打开 → 不处理")
    restoreStubs(saved)
end

function TestItemStatusMouse.testItemIndexAtDistinguishesRows()
    print("\n=== Test: 悬停命中与点击命中用同一套公式 ===")
    local saved = installStubs()
    local IA = freshItem()

    local select = {
        xnum = 5, ynum = 3, currentPage = 1, totalPages = 1,
        selectedIndex = 1, pageStart = 1, pageEnd = 15,
        items = {}, itemCount = 15,
    }
    local L = IA.layout(select)
    local cx0 = L.dx + L.gapOut
    local cy0 = L.y3_1 + L.gapOut
    local step = L.cellW + L.gapIn

    -- 悬停和点击都走 indexAt，所以命中结果必然一致
    TestHelper.assertEquals(IA.indexAt(select, cx0 + 20, cy0 + 20),
        IA.indexAt(select, cx0 + 20, cy0 + 20), "同一坐标两次调用结果相同")
    TestHelper.assertEquals(1, IA.indexAt(select, cx0 + 20, cy0 + 20), "第 1 格")
    TestHelper.assertEquals(6, IA.indexAt(select, cx0 + 20, cy0 + step + 20),
        "第二行第 1 格 = 6")
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-15 悬停不得注入键（用户实测：悬停一会儿自动卖出物品）
--
-- 根因：悬停靠注入 VK_SPACE 唤醒协程，但协程有 waitForTime 帧不消费键，
-- 注入频率 > 消费频率 → 键积压。等鼠标停在「已选中」格（不再产生 pending），
-- 残留键被消费 → keypress=VK_SPACE、pending=nil → 走确认分支 → 自动卖出。
--
-- 修法：悬停只记录意图；协程改用 WaitKeyTimeoutBypass 周期性醒来。
-- ============================================================

local function setupLiveItemGrid(count)
    local IM = require("framework.input_manager")
    local IA = freshItem()
    local SC = require("framework.coroutine_scheduler")
    local sched = SC.getInstance()
    -- 必须清空调度器：上一个用例留下的协程也在等键，
    -- 会抢走本次注入的唤醒键（实测：点击后 result 仍是 PENDING）
    sched:clear()

    local items = {}
    for i = 1, count do
        items[i] = { id = i - 1, name = "物品" .. i, count = 1,
                     type = 3, desc = "d", user = -1 }
    end

    local result = "PENDING"
    local co = sched:create(function()
        result = IA.SelectThingGridAsync(items, count)
    end, "live_item")
    sched:start(co)

    local L = IA.layout({ xnum = 5, ynum = 3, pageStart = 1, pageEnd = count })
    return IA, IM, sched, L, function() return result end
end

function TestItemStatusMouse.testHoverSourceHasNoEnqueue()
    print("\n=== Test: handleMouseHover 源码里不得有 enqueueKeyEvent ===")
    -- 行为测试难以稳定复现「积压 → 误确认」的时序（依赖帧对齐）。
    -- 直接检查源码：悬停路径不能依赖注入键。
    -- 这不是形式主义 —— 注入键与纯轮询是两种设计，混用必然积压。
    local f = io.open("framework/item_async.lua", "r")
    if not f then
        TestHelper.assertTrue(false, "无法打开 item_async.lua")
        return
    end
    local src = f:read("*a")
    f:close()

    -- 截出 handleMouseHover 的函数体
    local start = src:find("function ItemAsync.handleMouseHover")
    TestHelper.assertNotNil(start, "找到 handleMouseHover")
    local body = src:sub(start, start + 1200)
    -- 到下一个函数定义为止
    local nextFn = body:find("function ItemAsync%.")
    if nextFn and nextFn > 10 then body = body:sub(1, nextFn - 1) end

    TestHelper.assertEquals(nil, body:match("enqueueKeyEvent"),
        "handleMouseHover 不得注入键（会积压并被误当确认 → 自动卖出）")
end

function TestItemStatusMouse.testHoverDoesNotInjectKeys()
    print("\n=== Test: 悬停不往键队列注入任何键 ===")
    local saved = installStubs()
    local IA, IM, sched, L, getResult = setupLiveItemGrid(4)

    local cx0 = L.dx + L.gapOut
    local cy0 = L.y3_1 + L.gapOut
    local step = L.cellW + L.gapIn

    -- 快速划过 24 帧
    local residue = 0
    for f = 1, 24 do
        local t = cx0 + ((f - 1) % 4) * step + 20
        IA.handleMouseHover(t, cy0 + 20)
        advance(0.02)
        if IM.getInstance():_peekKeyInternal() ~= -1 then
            residue = residue + 1
        end
    end

    TestHelper.assertEquals(0, residue,
        "悬停全程队列必须无残留键（残留会被当成玩家确认）")
    TestHelper.assertEquals("PENDING", getResult(),
        "悬停不得触发确认（否则就是「自动卖出」）")
    restoreStubs(saved)
end

function TestItemStatusMouse.testStationaryHoverNeverConfirms()
    print("\n=== Test: 静止悬停 20 帧也不确认（旧的积压路径）===")
    local saved = installStubs()
    local IA, IM, sched, L, getResult = setupLiveItemGrid(4)

    local cx0 = L.dx + L.gapOut
    local cy0 = L.y3_1 + L.gapOut
    local step = L.cellW + L.gapIn

    -- 先划到第 4 格，然后**停住不动**
    for f = 1, 3 do
        IA.handleMouseHover(cx0 + (f - 1) * step + 20, cy0 + 20)
        advance(0.02)
    end

    for _ = 1, 20 do
        IA.handleMouseHover(cx0 + 3 * step + 20, cy0 + 20)
        advance(0.02)
    end

    TestHelper.assertEquals("PENDING", getResult(),
        "静止悬停 20 帧后仍未确认（修复前会在这里自动卖出）")
    restoreStubs(saved)
end

function TestItemStatusMouse.testClickStillConfirms()
    print("\n=== Test: 修复后点击仍能正常确认 ===")
    local saved = installStubs()
    local IA, IM, sched, L, getResult = setupLiveItemGrid(4)

    local cx0 = L.dx + L.gapOut
    local cy0 = L.y3_1 + L.gapOut
    local step = L.cellW + L.gapIn

    IA.handleMouseClick(cx0 + 2 * step + 20, cy0 + 20)   -- 点第 3 格

    -- 点击不再注入键（那会被键盘分支抢走），改为等协程的 50ms 超时轮询消费。
    -- 这里推进足够多的帧让超时到期。
    local EngineAPI = rawget(_G, "EngineAPI")
    for _ = 1, 6 do
        advance(0.02)
    end

    TestHelper.assertEquals(2, getResult(), "点击第 3 格 → 返回 id=2")
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-16 鼠标不动时不得抢走键盘焦点
--
-- 用户实测：悬停在某物品上后，用方向键换到另一项，
-- 下一帧又被鼠标拉回去 → 键盘完全没法用。
-- ============================================================

function TestItemStatusMouse.testKeyboardNotOverriddenWhenMouseStill()
    print("\n=== Test: 鼠标不动时键盘优先 ===")
    local saved = installStubs()

    -- 让 pollHover 能跑：需要鼠标设置开启
    local S = require("framework.settings")
    S.reset(); S.setPlatform("Windows")
    local MM = require("framework.mouse_menu")
    MM.define(); S.set("input.mouse", true)

    local mx, my = 0, 0
    rawget(_G, "EngineAPI").input = {
        mousePosition = function() return mx, my end,
    }

    local IA, IM, sched, L, getResult = setupLiveItemGrid(4)
    local JA = require("framework.jymain_adapter")

    local cx0 = L.dx + L.gapOut
    local cy0 = L.y3_1 + L.gapOut
    local step = L.cellW + L.gapIn

    -- ① 鼠标移到第 2 格
    --
    -- 悬停意图由协程的 50ms 超时轮询消费。
    --
    -- **帧数已从 5 改成 8**（`port-blocking-delay` Task 1）：原来推 5 帧
    -- 能过，是因为 `scheduler:waitForTime(0.05)` 有缺陷（记录 startTime 但
    -- 从未使用，实际只等 1 帧）→ 每轮 50ms超时(3帧) + 1帧 = 4 帧。
    -- 修好后每轮 = 3 + 3 = 6 帧（50ms 轮询 + 50ms 防连按，这才是设计意图）。
    -- 推 8 帧留余量。
    mx, my = cx0 + step + 20, cy0 + 20
    JA.pollHover()
    for _ = 1, 8 do advance(0.02) end
    TestHelper.assertEquals(2, IA.selectedIndex(), "悬停 → 选中第 2 格")

    -- ② 键盘 right → 选中第 3 格
    IM.getInstance():onKeyPressed("right", nil, false)
    for _ = 1, 8 do advance(0.02) end
    TestHelper.assertEquals(3, IA.selectedIndex(), "键盘 → 选中第 3 格")

    -- ③ 鼠标**不动**，连续跑多帧 pollHover → 不该被拉回
    for _ = 1, 6 do
        JA.pollHover()
        advance(0.02)
    end
    TestHelper.assertEquals(3, IA.selectedIndex(),
        "鼠标未移动 → 键盘的选择必须保持（关键修复）")

    -- ④ 鼠标真的移动了 → 才夺回焦点
    mx = mx + 2
    JA.pollHover()
    for _ = 1, 8 do advance(0.02) end
    TestHelper.assertEquals(2, IA.selectedIndex(),
        "鼠标移动后才夺回焦点")

    restoreStubs(saved)
end

function TestItemStatusMouse.runAll()
    print("\n" .. string.rep("=", 60))
    print("物品/状态 鼠标交互测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestItemStatusMouse.testItemLayoutMatchesDraw()
    TestItemStatusMouse.testItemGridHitTest()
    TestItemStatusMouse.testItemIndexAtSecondRow()
    TestItemStatusMouse.testItemIndexAtSecondPage()
    TestItemStatusMouse.testItemHandleClickRequiresActive()

    TestItemStatusMouse.testStatusLayoutMatchesDraw()
    TestItemStatusMouse.testStatusHandleClickRequiresActive()
    TestItemStatusMouse.testStatusPageNum()

    TestItemStatusMouse.testItemHoverRequiresActive()
    TestItemStatusMouse.testItemIndexAtDistinguishesRows()

    TestItemStatusMouse.testHoverSourceHasNoEnqueue()
    TestItemStatusMouse.testHoverDoesNotInjectKeys()
    TestItemStatusMouse.testStationaryHoverNeverConfirms()
    TestItemStatusMouse.testClickStillConfirms()
    TestItemStatusMouse.testKeyboardNotOverriddenWhenMouseStill()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_item_status_mouse.lua$") then
    TestItemStatusMouse.runAll()
end

return TestItemStatusMouse
