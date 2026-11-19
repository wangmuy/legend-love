-- test_menu_value_item.lua
-- menu_state_machine 的值项待定值语义 + onCursorChange 钩子
--
-- 这是 REQ-MENU-1 / REQ-MENU-2 的核心回归测试。
-- 最关键的两条：
--   * 上下键调用 Settings.set **0 次**（连按不产生副作用）
--   * ESC 放弃后设置值不变
--
-- 负向对照：把 menu_state_machine 的值项分支改成「上下键直接 Settings.set」，
-- 这两条必须失败。

local TestHelper = require("tests.test_helper")
local TestMenuValueItem = {}

-- 菜单组件依赖的全局桩
local keyQueue = {}

local function installStubs()
    local saved = {
        lib = rawget(_G, "lib"),
        EngineAPI = rawget(_G, "EngineAPI"),
        CC = rawget(_G, "CC"),
        DrawString = rawget(_G, "DrawString"),
        Cls = rawget(_G, "Cls"),
        DrawBox = rawget(_G, "DrawBox"),
        C_WHITE = rawget(_G, "C_WHITE"),
        c_orange = rawget(_G, "C_ORANGE"),
        VK_UP = rawget(_G, "VK_UP"),
        VK_DOWN = rawget(_G, "VK_DOWN"),
        VK_LEFT = rawget(_G, "VK_LEFT"),
        VK_RIGHT = rawget(_G, "VK_RIGHT"),
        VK_RETURN = rawget(_G, "VK_RETURN"),
        VK_SPACE = rawget(_G, "VK_SPACE"),
        VK_ESCAPE = rawget(_G, "VK_ESCAPE"),
    }

    rawset(_G, "lib", {
        GetKey = function()
            local k = table.remove(keyQueue, 1)
            return k or -1
        end,
        Debug = function() end,
    })
    -- framework 已改用 EngineAPI.input.getKey（port-contract-completeness Task 3），
    -- 这里装桩让它读同一个 keyQueue，保持既有断言不变。
    rawset(_G, "EngineAPI", {
        input = {
            getKey = function()
                local k = table.remove(keyQueue, 1)
                return k or -1
            end,
        },
        debug = { log = function() end },
    })
    rawset(_G, "CC", { MenuBorderPixel = 5, RowPixel = 4 })
    rawset(_G, "DrawString", function() end)
    rawset(_G, "Cls", function() end)
    rawset(_G, "DrawBox", function() end)
    rawset(_G, "C_WHITE", 0xFFFFFF)
    rawset(_G, "C_ORANGE", 0xFFA500)
    -- 与 jyconst.lua 一致
    rawset(_G, "VK_ESCAPE", 27)
    rawset(_G, "VK_SPACE", 32)
    rawset(_G, "VK_RETURN", 13)
    rawset(_G, "VK_UP", 1073741906)
    rawset(_G, "VK_DOWN", 1073741905)
    rawset(_G, "VK_LEFT", 1073741904)
    rawset(_G, "VK_RIGHT", 1073741903)

    return saved
end

local function restoreStubs(saved)
    for k, v in pairs(saved) do
        if k == "c_orange" then
            rawset(_G, "C_ORANGE", v)
        else
            _G[k] = v
        end
    end
end

local function pressKeys(keys)
    keyQueue = {}
    for i = 1, #keys do keyQueue[i] = keys[i] end
    -- framework 已改用 EngineAPI.input.getKey（Task 3），
    -- 同步注入到共享队列，否则 lib 桩收不到键
    TestHelper.setKeyQueue(keys)
end

-- 统计 Settings.set 被调用的次数
local function instrumentSet()
    local S = require("framework.settings")
    local realSet = S.set
    local count = 0
    S.set = function(key, value)
        count = count + 1
        return realSet(key, value)
    end
    return function()
        S.set = realSet
        return count
    end
end

local function setupMenu(key, label)
    local S = require("framework.settings")
    local AudioSettings = require("framework.audio_settings")
    local AudioMenu = require("framework.audio_menu")
    local MenuStateMachine = require("framework.menu_state_machine")

    S.reset()
    AudioSettings.resetInit()
    AudioSettings.define()

    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = AudioMenu.buildValueMenu(key, label)
    local menuData = msm:createMenu(items, 1, 0, 10, 10, 0, 0, 1, 1,
        24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menuData)
    return S, msm, menuData
end

-- ============================================================
-- REQ-MENU-1 待定值语义
-- ============================================================

function TestMenuValueItem.testPendingInitializedFromSettings()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")
    TestHelper.assertEquals(64, menu.newMenu[1][2].pending,
        "pending 初始化为当前设置值（进入界面显示真实值）")
    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testUpKeyOnlyChangesPending()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")
    local getCount = instrumentSet()

    pressKeys({ _G.VK_UP, _G.VK_UP, _G.VK_UP })
    msm:handleInput(); msm:handleInput(); msm:handleInput()

    TestHelper.assertEquals(67, menu.newMenu[1][2].pending, "上键 3 次 → 67")
    TestHelper.assertEquals(0, getCount(),
        "上下键调用 Settings.set 0 次（不产生副作用）")
    TestHelper.assertEquals(64, S.get("audio.music"),
        "Settings 值仍为 64（未提交）")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testDownKeyOnlyChangesPending()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")
    local getCount = instrumentSet()

    pressKeys({ _G.VK_DOWN, _G.VK_DOWN })
    msm:handleInput(); msm:handleInput()

    TestHelper.assertEquals(62, menu.newMenu[1][2].pending, "下键 2 次 → 62")
    TestHelper.assertEquals(0, getCount(), "Settings.set 0 次")
    TestHelper.assertEquals(64, S.get("audio.music"), "设置值不变")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testEnterCommits()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")
    local getCount = instrumentSet()

    pressKeys({ _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP })
    for _ = 1, 6 do msm:handleInput() end
    TestHelper.assertEquals(70, menu.newMenu[1][2].pending, "pending = 70")

    pressKeys({ _G.VK_RETURN })
    msm:handleInput()

    TestHelper.assertEquals(1, getCount(), "Enter 提交恰好 1 次 Settings.set")
    TestHelper.assertEquals(70, S.get("audio.music"), "Settings 变为 70")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testSpaceCommits()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")
    pressKeys({ _G.VK_UP, _G.VK_UP })
    msm:handleInput(); msm:handleInput()
    pressKeys({ _G.VK_SPACE })
    msm:handleInput()
    TestHelper.assertEquals(66, S.get("audio.music"), "空格也能提交（与既有菜单一致）")
    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testEscapeDiscards()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")
    local getCount = instrumentSet()

    pressKeys({ _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP,
                _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP })
    for _ = 1, 10 do msm:handleInput() end
    TestHelper.assertEquals(74, menu.newMenu[1][2].pending, "pending = 74")

    pressKeys({ _G.VK_ESCAPE })
    msm:handleInput()

    TestHelper.assertEquals(0, getCount(), "ESC 不调用 Settings.set")
    TestHelper.assertEquals(64, S.get("audio.music"),
        "ESC 后设置值不变（74 被丢弃）")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testContinuousPressNoSideEffect()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")
    local getCount = instrumentSet()

    -- 模拟长按：50 次上键
    local keys = {}
    for _ = 1, 50 do keys[#keys + 1] = _G.VK_UP end
    pressKeys(keys)
    for _ = 1, 50 do msm:handleInput() end

    TestHelper.assertEquals(0, getCount(),
        "连按 50 次 Settings.set 仍为 0 次（不产生任何副作用）")
    TestHelper.assertEquals(64 + 50, menu.newMenu[1][2].pending,
        "pending 累积到 114")
    TestHelper.assertEquals(64, S.get("audio.music"), "实际音量完全不变")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testClampUpperNoWrap()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")

    local keys = {}
    for _ = 1, 200 do keys[#keys + 1] = _G.VK_UP end
    pressKeys(keys)
    for _ = 1, 200 do msm:handleInput() end

    TestHelper.assertEquals(128, menu.newMenu[1][2].pending,
        "钳制在上界 128，不回绕到 0")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testClampLowerNoWrap()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")

    local keys = {}
    for _ = 1, 200 do keys[#keys + 1] = _G.VK_DOWN end
    pressKeys(keys)
    for _ = 1, 200 do msm:handleInput() end

    TestHelper.assertEquals(0, menu.newMenu[1][2].pending,
        "钳制在下界 0，不回绕到 128")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testUpDownNotNavigate()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")

    local before = menu.current
    pressKeys({ _G.VK_UP })
    msm:handleInput()
    TestHelper.assertEquals(before, menu.current,
        "值项上的上键不移动光标（不触发导航）")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testRenderUsesPending()
    -- 显示必须按 pending 渲染，不能读 Settings.get
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")

    pressKeys({ _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP, _G.VK_UP })
    for _ = 1, 6 do msm:handleInput() end

    local format = menu.newMenu[1][2].format
    local text = format(menu.newMenu[1][2].pending)
    TestHelper.assertTrue(text:find("70/128", 1, true) ~= nil,
        "渲染显示 pending=70，而 Settings.get 仍是 64")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testMenuClosesAfterCommit()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")

    pressKeys({ _G.VK_RETURN })
    msm:handleInput()

    TestHelper.assertEquals(nil, msm.activeMenu, "提交后菜单关闭")

    msm:clear()
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MENU-2 onCursorChange
-- ============================================================

function TestMenuValueItem.testCursorHookFires()
    local saved = installStubs()
    local S = require("framework.settings")
    local MenuStateMachine = require("framework.menu_state_machine")
    S.reset()

    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = { {"第一项", nil, 1}, {"第二项", nil, 1} }
    local menuData = msm:createMenu(items, 2, 0, 10, 10, 0, 0, 1, 1,
        24, 0xFFFFFF, 0xFF0000)

    local hookCalls = {}
    menuData.onCursorChange = function(menu, newCurrent, oldCurrent)
        hookCalls[#hookCalls + 1] = { newCurrent, oldCurrent }
    end
    msm:openMenu(menuData)

    pressKeys({ _G.VK_DOWN })
    msm:handleInput()

    TestHelper.assertEquals(1, #hookCalls, "光标换行触发钩子 1 次")
    TestHelper.assertEquals(2, hookCalls[1][1], "新位置 = 2")
    TestHelper.assertEquals(1, hookCalls[1][2], "旧位置 = 1")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testCursorHookErrorIsolated()
    local saved = installStubs()
    local S = require("framework.settings")
    local MenuStateMachine = require("framework.menu_state_machine")
    S.reset()

    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = { {"第一项", nil, 1}, {"第二项", nil, 1} }
    local menuData = msm:createMenu(items, 2, 0, 10, 10, 0, 0, 1, 1,
        24, 0xFFFFFF, 0xFF0000)
    menuData.onCursorChange = function() error("钩子抛错") end
    msm:openMenu(menuData)

    pressKeys({ _G.VK_DOWN })
    local ok = pcall(function() msm:handleInput() end)
    TestHelper.assertTrue(ok, "钩子抛错被 pcall 捕获，不中断主循环")
    TestHelper.assertEquals(2, menuData.current, "光标仍正常移动")

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.testNoHookMeansNoCrash()
    local saved = installStubs()
    local S = require("framework.settings")
    local MenuStateMachine = require("framework.menu_state_machine")
    S.reset()

    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = { {"第一项", nil, 1}, {"第二项", nil, 1} }
    local menuData = msm:createMenu(items, 2, 0, 10, 10, 0, 0, 1, 1,
        24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menuData)

    pressKeys({ _G.VK_DOWN })
    local ok = pcall(function() msm:handleInput() end)
    TestHelper.assertTrue(ok, "未注册钩子时行为不变，不抛错")

    msm:clear()
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MENU-1 框宽（ADR-AS-009）
-- ============================================================

function TestMenuValueItem.testValueItemWidthUsesDisplayWidth()
    local saved = installStubs()
    local S, msm, menu = setupMenu("audio.music", "音乐音量")

    -- 值项按显示宽度算：中文 1.0em + ASCII 0.5em
    -- 最长行是「音乐音量 64/128」= 4 汉字(96) + 空格(12) + 6 ASCII(72) = 180
    -- 加 2*MenuBorderPixel(5) = 190
    local expectedMin = 150
    TestHelper.assertTrue(menu.w >= expectedMin,
        "值项框宽 > " .. expectedMin .. "（按显示宽度，实际 " .. menu.w .. "）")

    msm:clear()
    restoreStubs(saved)
end

-- 既有菜单（非值项）也必须按**显示宽度**算
--
-- 历史：旧实现用 string.len（UTF-8 字节数）→ 「第一项」3 汉字 9 字节被算成
-- 24*9/2 = 108px（真实 72px），框宽多出 50%，文字左对齐后右侧一大片空白。
-- 用户报告「设置菜单还是左对齐」正是这个根因：centeredMenuX 按显示宽度算、
-- createMenu 按字节算，两套度量打架，居中 X 偏了 40px。
function TestMenuValueItem.testExistingMenuWidthUsesDisplayWidth()
    local saved = installStubs()
    local S = require("framework.settings")
    local MenuStateMachine = require("framework.menu_state_machine")
    S.reset()

    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = { {"第一项", nil, 1}, {"第二项", nil, 1} }
    local menuData = msm:createMenu(items, 2, 0, 10, 10, 0, 0, 1, 1,
        24, 0xFFFFFF, 0xFF0000)

    -- 「第一项」= 3 汉字 = 3*24 = 72px（显示宽度）+ 2*5 边框 = 82
    TestHelper.assertEquals(82, menuData.w,
        "既有菜单框宽按显示宽度算（汉字 1.0em），不再用 UTF-8 字节数")

    msm:clear()
    restoreStubs(saved)
end

-- 负向对照：若改回字节度量，框会明显偏宽
function TestMenuValueItem.testByteWidthWouldBeTooWide()
    local saved = installStubs()
    local S = require("framework.settings")
    local MenuStateMachine = require("framework.menu_state_machine")
    S.reset()
    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = { {"第一项", nil, 1} }
    local menuData = msm:createMenu(items, 1, 0, 10, 10, 0, 0, 1, 1,
        24, 0xFFFFFF, 0xFF0000)

    -- 字节度量会给 24*9/2 + 10 = 118，显示宽度给 82。
    -- 断言实际值明显小于字节度量值，证明没有回退。
    local byteWidth = 24 * #"第一项" / 2 + 2 * 5    -- 118
    TestHelper.assertTrue(menuData.w < byteWidth,
        string.format("框宽(%d) 必须小于字节度量(%d)，否则中文框又被算宽 50%%",
            menuData.w, byteWidth))

    msm:clear()
    restoreStubs(saved)
end

function TestMenuValueItem.runAll()
    print("\n" .. string.rep("=", 60))
    print("菜单值项待定值 + onCursorChange 测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestMenuValueItem.testPendingInitializedFromSettings()
    TestMenuValueItem.testUpKeyOnlyChangesPending()
    TestMenuValueItem.testDownKeyOnlyChangesPending()
    TestMenuValueItem.testEnterCommits()
    TestMenuValueItem.testSpaceCommits()
    TestMenuValueItem.testEscapeDiscards()
    TestMenuValueItem.testContinuousPressNoSideEffect()
    TestMenuValueItem.testClampUpperNoWrap()
    TestMenuValueItem.testClampLowerNoWrap()
    TestMenuValueItem.testUpDownNotNavigate()
    TestMenuValueItem.testRenderUsesPending()
    TestMenuValueItem.testMenuClosesAfterCommit()

    TestMenuValueItem.testCursorHookFires()
    TestMenuValueItem.testCursorHookErrorIsolated()
    TestMenuValueItem.testNoHookMeansNoCrash()

    TestMenuValueItem.testValueItemWidthUsesDisplayWidth()
    TestMenuValueItem.testExistingMenuWidthUsesDisplayWidth()
    TestMenuValueItem.testByteWidthWouldBeTooWide()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_menu_value_item.lua$") then
    TestMenuValueItem.runAll()
end

return TestMenuValueItem
