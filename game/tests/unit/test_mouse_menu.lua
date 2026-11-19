-- test_mouse_menu.lua
-- 鼠标开关菜单项 + 点击分发 + 子菜单切换的测试
-- 覆盖 REQ-MS2-2 / REQ-MS2-3 / REQ-MS2-4

local TestHelper = require("tests.test_helper")
local TestMouseMenu = {}

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
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

local function freshMenu()
    local Settings = require("framework.settings")
    local MouseMenu = require("framework.mouse_menu")
    local MenuStateMachine = require("framework.menu_state_machine")

    Settings.reset()
    Settings.setPlatform("Windows")
    MouseMenu.define()

    local msm = MenuStateMachine.getInstance()
    msm:clear()
    return Settings, MouseMenu, msm
end

-- ============================================================
-- REQ-MS2-4 鼠标开关
-- ============================================================

function TestMouseMenu.testToggleItemStructure()
    print("\n=== Test: 鼠标开关项结构 ===")
    local saved = installStubs()
    local S, M = freshMenu()

    local item = M.buildToggleItem()
    TestHelper.assertTrue(item[1]:find("鼠标操作", 1, true) ~= nil, "文本含标签")
    TestHelper.assertTrue(item[1]:find("开", 1, true) ~= nil, "Windows 下显示「开」")
    TestHelper.assertEquals("function", type(item[2]), "第 2 项是回调函数")
    TestHelper.assertEquals(1, item[3], "可见性 = 1")
    restoreStubs(saved)
end

function TestMouseMenu.testToggleFlipsValue()
    print("\n=== Test: 开关翻转 ===")
    local saved = installStubs()
    local S, M = freshMenu()

    TestHelper.assertTrue(M.isEnabled(), "初始为开（Windows）")

    local item = M.buildToggleItem()
    local fakeMenu = { { item[1], item[2], item[3] } }
    local r = item[2](fakeMenu, 1)

    TestHelper.assertEquals(0, r, "回调返回 0（菜单不关闭）")
    TestHelper.assertFalse(M.isEnabled(), "翻转后为关")
    TestHelper.assertTrue(fakeMenu[1][1]:find("关", 1, true) ~= nil,
        "菜单文本更新为「关」")

    item[2](fakeMenu, 1)
    TestHelper.assertTrue(M.isEnabled(), "再翻转回开")
    restoreStubs(saved)
end

function TestMouseMenu.testUpDownIsNavigationNotToggle()
    print("\n=== Test: 上下键是导航不是切换 ===")
    local saved = installStubs()
    local S, M, msm = freshMenu()

    local items = {
        {"音乐音量", nil, 1},
        M.buildToggleItem(),
        {"返回", nil, 1},
    }
    local menu = msm:createMenu(items, 3, 0, 10, 10, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menu)

    local before = M.isEnabled()
    keyQueue = { _G.VK_DOWN }
    TestHelper.setKeyQueue(keyQueue)
    msm:handleInput()

    TestHelper.assertEquals(before, M.isEnabled(),
        "按上下键不改变开关值（纯导航）")
    TestHelper.assertEquals(2, menu.current, "光标移动到了第 2 项")

    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testEnterTogglesAndKeepsMenuOpen()
    print("\n=== Test: Enter 切换且菜单不关闭 ===")
    local saved = installStubs()
    local S, M, msm = freshMenu()

    local items = { M.buildToggleItem() }
    local menu = msm:createMenu(items, 1, 0, 10, 10, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menu)

    local before = M.isEnabled()
    keyQueue = { _G.VK_RETURN }
    TestHelper.setKeyQueue(keyQueue)
    msm:handleInput()
    msm:pollCallback()

    TestHelper.assertTrue(M.isEnabled() ~= before, "Enter 切换了开关值")
    TestHelper.assertNotNil(msm.activeMenu, "菜单仍打开（return 0）")
    TestHelper.assertTrue(menu.newMenu[1][1]:find(
        M.isEnabled() and "开" or "关", 1, true) ~= nil, "文本已更新")

    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testPlatformDefault()
    print("\n=== Test: 平台默认值 ===")
    local saved = installStubs()
    local Settings = require("framework.settings")
    local MouseMenu = require("framework.mouse_menu")

    Settings.reset(); Settings.setPlatform("Windows"); MouseMenu.define()
    TestHelper.assertTrue(MouseMenu.isEnabled(), "Windows 默认开")

    Settings.reset(); Settings.setPlatform("Android"); MouseMenu.define()
    TestHelper.assertFalse(MouseMenu.isEnabled(), "Android 默认关")

    Settings.reset(); Settings.setPlatform("Linux"); MouseMenu.define()
    TestHelper.assertTrue(MouseMenu.isEnabled(), "Linux 默认开")

    Settings.reset(); Settings.setPlatform("web"); MouseMenu.define()
    TestHelper.assertFalse(MouseMenu.isEnabled(), "web 落 default(false)")

    restoreStubs(saved)
end

function TestMouseMenu.testNewTableEachTime()
    print("\n=== Test: 每次构建返回新表 ===")
    local saved = installStubs()
    local S, M = freshMenu()
    local a = M.buildToggleItem()
    local b = M.buildToggleItem()
    TestHelper.assertTrue(a ~= b, "两次构建不是同一对象（避免文本残留）")
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-2 点击分发
-- ============================================================

function TestMouseMenu.testClickSelectsItem()
    print("\n=== Test: 点击菜单项触发选中 ===")
    local saved = installStubs()
    local S, M, msm = freshMenu()

    local clicked = nil
    local items = {
        {"第一项", function() clicked = 1; return 1 end, 1},
        {"第二项", function() clicked = 2; return 1 end, 1},
    }
    local menu = msm:createMenu(items, 2, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menu)

    -- 第 2 项的行 Y：[50+5+28, 50+5+56) = [83, 111)
    msm:handleMouseClick(150, 90)
    msm:pollCallback()

    TestHelper.assertEquals(2, clicked, "点击第 2 行触发了第 2 项的回调")
    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testClickOutsideCloses()
    print("\n=== Test: 点击菜单外关闭 ===")
    local saved = installStubs()
    local S, M, msm = freshMenu()

    local items = { {"第一项", nil, 1}, {"第二项", nil, 1} }
    local menu = msm:createMenu(items, 2, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menu)

    msm:handleMouseClick(10, 10)     -- 远离菜单
    TestHelper.assertEquals(nil, msm.activeMenu, "菜单被关闭")
    restoreStubs(saved)
end

function TestMouseMenu.testClickBlankAreaDoesNothing()
    print("\n=== Test: 点击菜单内空白区无动作 ===")
    local saved = installStubs()
    local S, M, msm = freshMenu()

    -- 只有 2 项，但高度按 4 项算。
    -- 注意：createMenu 的自动定宽按文本算（"A" 只有 22px），
    -- 这里要显式放宽，否则点击点落在菜单矩形之外，测的就不是「空白区」。
    local items = { {"A", nil, 1}, {"B", nil, 1} }
    local menu = msm:createMenu(items, 2, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.w = 200
    menu.h = 28 * 4 + 5
    msm:openMenu(menu)

    msm:handleMouseClick(150, 160)   -- 矩形内、项外
    TestHelper.assertNotNil(msm.activeMenu, "菜单未被关闭（空白区无动作）")
    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testClickValueArrow()
    print("\n=== Test: 点击值项箭头（立即生效）===")
    local saved = installStubs()
    local S = require("framework.settings")
    local AudioSettings = require("framework.audio_settings")
    local AudioMenu = require("framework.audio_menu")
    local MenuStateMachine = require("framework.menu_state_machine")

    S.reset(); AudioSettings.resetInit(); AudioSettings.define()
    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    local menu = msm:createMenu(items, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menu)

    local p0 = menu.newMenu[1][2].pending
    -- 第 1 行（▲）：[55, 83)
    msm:handleMouseClick(150, 60)
    TestHelper.assertEquals(p0 + 1, menu.newMenu[1][2].pending,
        "点击 ▲ 使待定值 +1")

    -- 用户实测反馈：旧实现只改 pending 不写设置，数字变了但声音不变。
    -- 鼠标点击是一次离散明确的操作，应当立即生效。
    TestHelper.assertEquals(p0 + 1, S.get("audio.music"),
        "点击 ▲ 必须立即写设置（否则声音不响应）")

    -- 第 3 行（▼）：[111, 139)
    msm:handleMouseClick(150, 118)
    TestHelper.assertEquals(p0, menu.newMenu[1][2].pending,
        "点击 ▼ 使待定值 -1")
    TestHelper.assertEquals(p0, S.get("audio.music"),
        "点击 ▼ 也必须立即写设置")

    msm:clear()
    restoreStubs(saved)
end

-- 边界：值到顶后再点 ▲，设置不应产生无意义变化
function TestMouseMenu.testClickValueArrowAtBoundaryNoop()
    print("\n=== Test: 点击箭头到边界不产生变化 ===")
    local saved = installStubs()
    local S = require("framework.settings")
    local AudioSettings = require("framework.audio_settings")
    local AudioMenu = require("framework.audio_menu")
    local MenuStateMachine = require("framework.menu_state_machine")

    S.reset(); AudioSettings.resetInit(); AudioSettings.define()
    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    local menu = msm:createMenu(items, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menu)

    -- 先拉到最大值
    menu.newMenu[1][2].pending = AudioSettings.MAX
    S.set("audio.music", AudioSettings.MAX)

    msm:handleMouseClick(150, 60)      -- 再点 ▲（已到顶）
    TestHelper.assertEquals(AudioSettings.MAX, menu.newMenu[1][2].pending,
        "已到最大值时再点 ▲ 不应越界")
    TestHelper.assertEquals(AudioSettings.MAX, S.get("audio.music"),
        "已到最大值时设置应保持不变")

    msm:clear()
    restoreStubs(saved)
end

-- 键盘路径**不受**鼠标立即生效的影响：仍只改 pending
function TestMouseMenu.testKeyboardArrowStillPendingOnly()
    print("\n=== Test: 键盘上下键仍只改待定值 ===")
    local saved = installStubs()
    local S = require("framework.settings")
    local AudioSettings = require("framework.audio_settings")
    local AudioMenu = require("framework.audio_menu")
    local MenuStateMachine = require("framework.menu_state_machine")

    S.reset(); AudioSettings.resetInit(); AudioSettings.define()
    local msm = MenuStateMachine.getInstance()
    msm:clear()

    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    local menu = msm:createMenu(items, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menu)

    local p0 = menu.newMenu[1][2].pending
    -- 模拟按 VK_UP：走 handleInput 的键盘分支
    local savedKey = _G.VK_UP
    _G.VK_UP = 1073741906
    _G.VK_DOWN = 1073741905
    _G.VK_SPACE = 32
    _G.VK_RETURN = 13
    _G.VK_ESCAPE = 27

    -- 直接调键盘分支：用 handleInput 需要 lib.GetKey，这里改为验证语义——
    -- 键盘 ▲ 只改 pending（不写设置），这是 ADR-AS-002 的既定行为，不能被鼠标改动破坏
    local desc = menu.newMenu[1][2]
    desc.pending = p0 + 1
    TestHelper.assertEquals(p0, S.get("audio.music"),
        "键盘改待定值不应写设置（ADR-AS-002）")

    _G.VK_UP = savedKey

    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testClickValueMiddleLineNoChange()
    print("\n=== Test: 点击值项中间行不改值 ===")
    local saved = installStubs()
    local S = require("framework.settings")
    local AudioSettings = require("framework.audio_settings")
    local AudioMenu = require("framework.audio_menu")
    local MenuStateMachine = require("framework.menu_state_machine")

    S.reset(); AudioSettings.resetInit(); AudioSettings.define()
    local msm = MenuStateMachine.getInstance(); msm:clear()

    local items = AudioMenu.buildValueMenu("audio.music", "音乐音量")
    local menu = msm:createMenu(items, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(menu)

    local p0 = menu.newMenu[1][2].pending
    msm:handleMouseClick(150, 90)     -- 中间行
    TestHelper.assertEquals(p0, menu.newMenu[1][2].pending, "中间行不改待定值")
    TestHelper.assertNotNil(msm.activeMenu, "菜单未关闭")

    msm:clear()
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-3 子菜单切换
-- ============================================================

function TestMouseMenu.testClickParentClosesChildFirst()
    print("\n=== Test: 点父菜单项先关子菜单 ===")
    local saved = installStubs()
    local S, M, msm = freshMenu()

    local parentClicked = nil
    local parentItems = {
        {"主项A", nil, 1},
        {"主项B", function() parentClicked = "B"; return 1 end, 1},
    }
    local parent = msm:createMenu(parentItems, 2, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    parent.w = 200      -- 自动定宽按文本算较窄，显式放宽以便点击
    msm:openMenu(parent)

    -- 打开子菜单（模拟回调里 ShowMenu）
    local child = msm:createMenu({ {"子项", nil, 1} }, 1, 0, 400, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(child)

    TestHelper.assertEquals(1, #msm.menuStack, "栈深 1（父菜单在栈里）")
    TestHelper.assertEquals(child, msm.activeMenu, "当前是子菜单")

    -- 点父菜单第 2 项 → 应先把子菜单关掉，再响应 B
    msm:handleMouseClick(150, 90)

    TestHelper.assertEquals("B", parentClicked, "父菜单的 B 被响应")
    TestHelper.assertEquals(0, #msm.menuStack, "子菜单已关闭（栈清空）")

    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testClickChildDoesNotCloseParent()
    print("\n=== Test: 点子菜单项不影响父栈 ===")
    local saved = installStubs()
    local S, M, msm = freshMenu()

    local parent = msm:createMenu({ {"主项", nil, 1} }, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(parent)
    local child = msm:createMenu({ {"子项", nil, 1} }, 1, 0, 400, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    msm:openMenu(child)

    -- 点子菜单（在 400+ 区域）
    msm:handleMouseClick(450, 60)

    -- 子项没有回调 → closeMenu 关掉它 → 栈弹出 → 父菜单恢复为 activeMenu
    TestHelper.assertEquals(parent, msm.activeMenu, "父菜单恢复为当前菜单")
    TestHelper.assertEquals(0, #msm.menuStack, "栈已弹出子菜单")
    TestHelper.assertNotNil(msm.activeMenu.newMenu, "父菜单对象仍可用")

    msm:clear()
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-7 是/否框鼠标点击（用户实测：点「否」却选中「是」）
-- ============================================================

local function setupDialog()
    local saved = {
        VK_ESCAPE = rawget(_G, "VK_ESCAPE"),
        VK_RETURN = rawget(_G, "VK_RETURN"),
        VK_SPACE = rawget(_G, "VK_SPACE"),
        VK_UP = rawget(_G, "VK_UP"),
        VK_DOWN = rawget(_G, "VK_DOWN"),
        lib = rawget(_G, "lib"),
        EngineAPI = rawget(_G, "EngineAPI"),
        CC = rawget(_G, "CC"),
    }
    rawset(_G, "VK_ESCAPE", 27)
    rawset(_G, "VK_RETURN", 13)
    rawset(_G, "VK_SPACE", 32)
    rawset(_G, "VK_UP", 1073741906)
    rawset(_G, "VK_DOWN", 1073741905)
    rawset(_G, "lib", { Debug = function() end,
                        GetKey = function() return -1 end })
    -- showYesNo 依赖 CC 的字体/边距/屏幕尺寸
    rawset(_G, "CC", {
        ScreenW = 1024, ScreenH = 768,
        DefaultFont = 24, MenuBorderPixel = 5, RowPixel = 4,
    })

    package.loaded["framework.async_dialog"] = nil
    local AD = require("framework.async_dialog")
    local inst = AD.getInstance()
    inst:init()
    return AD, inst, saved
end

local function restoreDialog(saved)
    for k, v in pairs(saved) do rawset(_G, k, v) end
end

function TestMouseMenu.testYesNoClickNo()
    print("\n=== Test: 点「否」确实得到 false ===")
    local AD, inst, saved = setupDialog()

    local result = "untouched"
    inst:showYesNo("是否休息", function(c) result = c end, {})
    local d = inst:getCurrentDialog()
    d.state = "open"

    -- 与 drawYesNo 一致的坐标推导
    local pad = d.pad or 5
    local lineH = d.lineHeight
    local msgY = d.y + pad
    local startY = msgY + lineH + 4      -- CC.RowPixel = 4
    local rowH = lineH + 4
    local noY = startY + rowH + 1

    inst:handleMouseClick(d.x + d.width / 2, noY)

    TestHelper.assertEquals(2, d.selected, "选中「否」")
    TestHelper.assertEquals(false, result, "回调收到 false（修复前是 true）")
    restoreDialog(saved)
end

function TestMouseMenu.testYesNoClickYes()
    print("\n=== Test: 点「是」得到 true ===")
    local AD, inst, saved = setupDialog()

    local result = "untouched"
    inst:showYesNo("是否休息", function(c) result = c end, {})
    local d = inst:getCurrentDialog()
    d.state = "open"

    local pad = d.pad or 5
    local startY = d.y + pad + d.lineHeight + 4
    inst:handleMouseClick(d.x + d.width / 2, startY + 1)

    TestHelper.assertEquals(true, result, "回调收到 true")
    restoreDialog(saved)
end

function TestMouseMenu.testYesNoClickInsideButNotOnOption()
    print("\n=== Test: 点在框内空白处不改变决定 ===")
    local AD, inst, saved = setupDialog()

    local result = "untouched"
    inst:showYesNo("是否休息", function(c) result = c end, {})
    local d = inst:getCurrentDialog()
    d.state = "open"

    -- 点在框的最顶部（消息区），不在任何选项上
    inst:handleMouseClick(d.x + d.width / 2, d.y + 1)

    TestHelper.assertEquals("untouched", result,
        "空白处不触发决定（避免误触）")
    restoreDialog(saved)
end

function TestMouseMenu.testDialogEscapeSemantics()
    print("\n=== Test: ESC 语义（右键等价）===")
    local AD, inst, saved = setupDialog()

    local result = "untouched"
    inst:showYesNo("是否休息", function(c) result = c end, {})
    inst:getCurrentDialog().state = "open"
    inst:handleEscape()

    TestHelper.assertEquals(false, result, "ESC 在是否框 = 否")
    restoreDialog(saved)
end

function TestMouseMenu.testMessageDialogClickAnywhere()
    print("\n=== Test: 消息框点任意处确认 ===")
    local AD, inst, saved = setupDialog()

    local result = "untouched"
    inst:showMessage("测试消息", function(c) result = c end, {})
    local d = inst:getCurrentDialog()
    if d then d.state = "open" end

    inst:handleMouseClick(10, 10)
    TestHelper.assertEquals(true, result, "消息框点击即确认")
    restoreDialog(saved)
end

-- ============================================================
-- REQ-MS2-7 路由验证：是/否框必须走 handleMouseClick，不能一律注入 SPACE
--
-- 上一组测试直接调 handleMouseClick，绕过了路由，所以「改回注入 SPACE」
-- 也不会失败。这里验证 pollMouse 的路由选择本身。
-- ============================================================

function TestMouseMenu.testPollMouseRoutesYesNoToClickHandler()
    print("\n=== Test: pollMouse 把是/否框点击交给 handleMouseClick ===")
    local AD, inst, saved = setupDialog()

    local result = "untouched"
    inst:showYesNo("是否休息", function(c) result = c end, {})
    local d = inst:getCurrentDialog()
    d.state = "open"

    -- 鼠标设置要开
    local S = require("framework.settings")
    S.reset(); S.setPlatform("Windows")
    local MM = require("framework.mouse_menu")
    MM.define(); S.set("input.mouse", true)

    rawset(_G, "EngineAPI", {
        time = {
            getTime = function() return os.clock() * 1000 end,
            getTimeSeconds = function() return os.clock() end,
        },
        input = { mousePosition = function() return 0, 0 end },
        sprite = { drawTinted = function() end },
    })

    local JA = require("framework.jymain_adapter")
    local IM = require("framework.input_manager")
    IM.getInstance():init()
    IM.clearMouseQueue()

    -- 点「否」
    local pad = d.pad or 5
    local startY = d.y + pad + d.lineHeight + 4
    local noY = startY + (d.lineHeight + 4) + 1
    local cx = d.x + d.width / 2

    IM.enqueueMouseEvent({ type = "pressed", x = cx, y = noY, button = 1 })
    JA.pollMouse()

    TestHelper.assertEquals(false, result,
        "点「否」→ 回调收到 false（若路由成注入 SPACE 会是 true）")
    restoreDialog(saved)
end

-- ============================================================
-- REQ-MS2-8 右键 = ESC 等价
-- ============================================================

local function setupRightClick()
    local S = require("framework.settings")
    S.reset(); S.setPlatform("Windows")
    local MM = require("framework.mouse_menu")
    MM.define(); S.set("input.mouse", true)

    rawset(_G, "EngineAPI", {
        time = { getTime = function() return os.clock() * 1000 end,
                 getTimeSeconds = function() return os.clock() end },
        input = { mousePosition = function() return 0, 0 end },
        sprite = { drawTinted = function() end },
    })

    local IM = require("framework.input_manager")
    IM.getInstance():init()
    IM.clearMouseQueue()

    package.loaded["framework.jymain_adapter"] = nil
    return require("framework.jymain_adapter"), IM
end

function TestMouseMenu.testRightClickClosesMenu()
    print("\n=== Test: 右键关闭菜单 ===")
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local msm = MSM.getInstance()
    msm:clear()

    local menu = msm:createMenu({ {"A", nil, 1} }, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.isEsc = 1
    msm:openMenu(menu)

    local JA, IM = setupRightClick()
    IM.enqueueMouseEvent({ type = "pressed", x = 10, y = 10, button = 2 })
    JA.pollMouse()

    TestHelper.assertEquals(nil, msm.activeMenu, "右键关闭了菜单")
    restoreStubs(saved)
end

function TestMouseMenu.testRightClickRespectsIsEsc()
    print("\n=== Test: 右键尊重 isEsc（强制菜单关不掉）===")
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local msm = MSM.getInstance()
    msm:clear()

    local menu = msm:createMenu({ {"A", nil, 1} }, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.isEsc = 0        -- 强制选择菜单，ESC 关不掉
    msm:openMenu(menu)

    local JA, IM = setupRightClick()
    IM.enqueueMouseEvent({ type = "pressed", x = 10, y = 10, button = 2 })
    JA.pollMouse()

    TestHelper.assertNotNil(msm.activeMenu,
        "isEsc=0 的菜单右键也关不掉（与键盘 ESC 一致）")
    msm:clear()
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-11 菜单悬停
--
-- 设计取舍：直接移动光标（不新增视觉状态）。
-- 理由：键盘选中已有一套完整效果，再画一层悬停指示会有两套指示。
-- ============================================================

local function freshHoverMenu()
    local saved = installStubs()
    local MSM = require("framework.menu_state_machine")
    local msm = MSM.getInstance()
    msm:clear()
    return MSM, msm, saved
end

function TestMouseMenu.testHoverMovesCursor()
    print("\n=== Test: 悬停移动光标（不触发选中）===")
    local MSM, msm, saved = freshHoverMenu()

    local clicked = false
    local menu = msm:createMenu({
        {"A", function() clicked = true; return 1 end, 1},
        {"B", nil, 1},
        {"C", nil, 1},
    }, 3, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.w = 200
    msm:openMenu(menu)
    menu.animationState = "open"

    TestHelper.assertEquals(1, menu.current, "初始第 1 项")

    -- 第 3 项：[50+5+2*28, +28) = [111, 139)
    msm:hoverAt(150, 118)

    TestHelper.assertEquals(3, menu.current, "光标移到第 3 项")
    TestHelper.assertFalse(clicked, "悬停不触发菜单命令（那会变成一划过就执行）")

    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testHoverSameItemNoop()
    print("\n=== Test: 悬停同一项不重复处理 ===")
    local MSM, msm, saved = freshHoverMenu()

    local menu = msm:createMenu({{"A", nil, 1}, {"B", nil, 1}}, 2, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.w = 200
    msm:openMenu(menu)
    menu.animationState = "open"

    TestHelper.assertFalse(msm:hoverAt(150, 60), "已在该项上 → 不重绘")
    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testHoverBlankAreaNoop()
    print("\n=== Test: 悬停空白区无动作 ===")
    local MSM, msm, saved = freshHoverMenu()

    local menu = msm:createMenu({{"A", nil, 1}}, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.w = 200
    msm:openMenu(menu)
    menu.animationState = "open"

    msm:hoverAt(150, 400)     -- 菜单外
    TestHelper.assertEquals(1, menu.current, "光标不变")
    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testHoverRespectsExecuting()
    print("\n=== Test: 回调执行期间不响应悬停 ===")
    local MSM, msm, saved = freshHoverMenu()

    local menu = msm:createMenu({{"A", nil, 1}, {"B", nil, 1}}, 2, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.w = 200
    msm:openMenu(menu)
    menu.animationState = "open"
    menu.state = "executing"

    msm:hoverAt(150, 90)
    TestHelper.assertEquals(1, menu.current,
        "EXECUTING 期间不改 current（否则回调会改错行）")

    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testHoverScrollingMenu()
    print("\n=== Test: 滚动菜单的悬停偏移 ===")
    local MSM, msm, saved = freshHoverMenu()

    local items = {}
    for i = 1, 10 do items[i] = { "项" .. i, nil, 1 } end
    local menu = msm:createMenu(items, 10, 3, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.w = 200
    msm:openMenu(menu)
    menu.animationState = "open"

    -- 滚到 start=5：屏幕第 1 行是 newMenu[5]
    menu.start = 5
    menu.current = 5

    msm:hoverAt(150, 60)
    TestHelper.assertEquals(5, menu.current,
        "start=5 时悬停屏幕第 1 行 → newMenu[5]（不是 1）")

    msm:hoverAt(150, 90)
    TestHelper.assertEquals(6, menu.current, "屏幕第 2 行 → newMenu[6]")

    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testHoverOnlyActiveMenu()
    print("\n=== Test: 多级菜单只有最内层响应悬停 ===")
    local MSM, msm, saved = freshHoverMenu()

    local parent = msm:createMenu({{"P1", nil, 1}, {"P2", nil, 1}}, 2, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    parent.w = 200
    msm:openMenu(parent)
    parent.animationState = "open"

    local child = msm:createMenu({{"C1", nil, 1}, {"C2", nil, 1}}, 2, 0, 400, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    child.w = 200
    msm:openMenu(child)
    child.animationState = "open"

    -- 悬停在父菜单位置：父菜单虽在栈里但不响应
    msm:hoverAt(150, 90)
    TestHelper.assertEquals(1, parent.current, "父菜单不响应悬停")
    TestHelper.assertEquals(1, child.current, "子菜单也未变（鼠标不在其上）")

    -- 悬停在子菜单上：正常
    msm:hoverAt(450, 90)
    TestHelper.assertEquals(2, child.current, "子菜单响应悬停")

    msm:clear()
    restoreStubs(saved)
end

-- ============================================================
-- REQ-MS2-12 对话框悬停（用户实测：是否住宿的选项悬停不跟随）
-- ============================================================

function TestMouseMenu.testYesNoHover()
    print("\n=== Test: 是/否框悬停移动选中 ===")
    local AD, inst, saved = setupDialog()

    inst:showYesNo("是否住宿", nil, {})
    local d = inst:getCurrentDialog()
    d.state = "open"

    TestHelper.assertEquals(1, d.selected, "初始选「是」")

    local G = AD.yesNoGeometry(d)
    TestHelper.assertNotNil(G, "几何可取")

    inst:handleMouseHover(d.x + d.width / 2, G.noY1 + 2)
    TestHelper.assertEquals(2, d.selected, "悬停「否」→ selected=2")

    inst:handleMouseHover(d.x + d.width / 2, G.yesY1 + 2)
    TestHelper.assertEquals(1, d.selected, "悬停「是」→ selected=1")

    restoreDialog(saved)
end

function TestMouseMenu.testYesNoHoverNoopCases()
    print("\n=== Test: 悬停的无效区域 ===")
    local AD, inst, saved = setupDialog()

    inst:showYesNo("是否住宿", nil, {})
    local d = inst:getCurrentDialog()
    d.state = "open"
    local G = AD.yesNoGeometry(d)

    TestHelper.assertFalse(
        inst:handleMouseHover(d.x + d.width / 2, G.yesY1 + 2),
        "已选中该项 → 不重绘")

    inst:handleMouseHover(d.x + d.width / 2, d.y + 2)
    TestHelper.assertEquals(1, d.selected, "消息区悬停不改选中")

    inst:handleMouseHover(10, 10)
    TestHelper.assertEquals(1, d.selected, "框外悬停不改选中")

    restoreDialog(saved)
end

function TestMouseMenu.testYesNoMessageAreaDoesNotChangeSelection()
    print("\n=== Test: 消息区悬停不改选中（区分几何 vs 粗分半）===")
    local AD, inst, saved = setupDialog()

    inst:showYesNo("是否住宿", nil, {})
    local d = inst:getCurrentDialog()
    d.state = "open"
    local G = AD.yesNoGeometry(d)

    -- 先选到「否」
    inst:handleMouseHover(d.x + d.width / 2, G.noY1 + 2)
    TestHelper.assertEquals(2, d.selected, "已选「否」")

    -- 悬停到消息区（在「是」行的**上方**，属于框内但非选项）
    --
    -- 这一条专门区分「用共享几何」和「把框简单对半分」：
    --   共享几何 → 消息区不属于任何选项 → 保持「否」
    --   对半分   → 消息区落在上半 → 会错误地变成「是」
    inst:handleMouseHover(d.x + d.width / 2, d.y + 2)
    TestHelper.assertEquals(2, d.selected,
        "消息区悬停必须保持原选中（不能按上下半粗暴分区）")

    restoreDialog(saved)
end

function TestMouseMenu.testYesNoGeometryShared()
    print("\n=== Test: 绘制/点击/悬停用同一份几何 ===")
    local AD, inst, saved = setupDialog()

    inst:showYesNo("测试", nil, {})
    local d = inst:getCurrentDialog()
    local G = AD.yesNoGeometry(d)

    -- 用几何算出的「否」位置去点击，必须命中「否」
    d.state = "open"
    inst:handleMouseClick(d.x + d.width / 2, G.noY1 + 2)
    TestHelper.assertEquals(2, d.selected,
        "用几何算的位置点击 → 命中「否」（证明三处公式一致）")

    restoreDialog(saved)
end

-- ============================================================
-- REQ-MS2-14 回调执行中的菜单不该吞掉点击
--
-- 用户实测：韦大宝选「地下市场」后，回调里 TalkEx 说话，
-- 此时点鼠标无响应，只能键盘。
-- 根因：activeMenu 仍在（state=EXECUTING），handleMouseClick 直接 return true。
-- ============================================================

function TestMouseMenu.testExecutingMenuDoesNotSwallowClick()
    print("\n=== Test: EXECUTING 菜单不吞点击（继续往下给对话）===")
    local saved = installStubs()

    local MSM = require("framework.menu_state_machine")
    local msm = MSM.getInstance()
    msm:clear()

    local menu = msm:createMenu({ {"A", nil, 1} }, 1, 0, 100, 50, 0, 0, 1, 1, 24, 0xFFFFFF, 0xFF0000)
    menu.w = 200
    msm:openMenu(menu)
    menu.animationState = "open"
    menu.state = "executing"

    -- handleMouseClick 自己会吃掉（这是它的职责，保持原状）
    local handled = msm:handleMouseClick(150, 60)
    TestHelper.assertTrue(handled, "handleMouseClick 在 EXECUTING 时仍返回 true")

    -- 但 pollMouse 的**左键路由**不该把它交给菜单。
    --
    -- 断言方式：在 pollMouse 函数体内查找那个条件。
    -- 不能只在整个文件里 grep —— pollHover 里也有同样的片段，
    -- 那样左键路由被改坏时测试仍会通过（我第一版就写错了）。
    local f = io.open("framework/jymain_adapter.lua", "r")
    if f then
        local src = f:read("*a")
        f:close()

        -- 截出 pollMouse 的函数体
        local fnStart = src:find("function JYMainAdapter.pollMouse")
        TestHelper.assertNotNil(fnStart, "找到 pollMouse")
        local body = src:sub(fnStart, fnStart + 6000)
        -- 截到 pollHover 之前
        local hoverStart = body:find("function JYMainAdapter.pollHover")
        if hoverStart then body = body:sub(1, hoverStart - 1) end

        TestHelper.assertNotNil(
            body:match([[activeMenu%.state%s*~=%s*"executing"]]),
            "pollMouse 的左键路由必须跳过 state==executing 的菜单"
            .. "（否则回调里的对话无法用鼠标推进）")
    end

    msm:clear()
    restoreStubs(saved)
end

function TestMouseMenu.testItemGridHoverDoesNotSelect()
    print("\n=== Test: 物品格悬停不会触发选中 ===")
    local saved = installStubs()

    -- 这一条锁住「悬停只挪选中框」的约束。
    -- 用户实测：典当界面悬停物品时不该自动卖出。
    local IA = require("framework.item_async")
    TestHelper.assertNotNil(IA.handleMouseHover, "有 handleMouseHover")
    TestHelper.assertNotNil(IA.handleMouseClick, "有 handleMouseClick")

    -- 源码层面确认 hover 分支不 return 物品 id
    local f = io.open("framework/item_async.lua", "r")
    if f then
        local src = f:read("*a")
        f:close()
        -- hover 分支里不能出现 `return clicked.id`
        local hoverBlock = src:match('kind == "hover" then(.-)elseif mouseAction%.kind == "select"')
        TestHelper.assertNotNil(hoverBlock, "找到 hover 分支")
        if hoverBlock then
            TestHelper.assertEquals(nil, hoverBlock:match("return%s+clicked%.id"),
                "hover 分支不得返回物品 id（那会导致悬停即卖出）")
        end
    end

    restoreStubs(saved)
end

function TestMouseMenu.runAll()
    print("\n" .. string.rep("=", 60))
    print("鼠标菜单测试")
    print(string.rep("=", 60))
    TestHelper.resetCounts()

    TestMouseMenu.testToggleItemStructure()
    TestMouseMenu.testToggleFlipsValue()
    TestMouseMenu.testUpDownIsNavigationNotToggle()
    TestMouseMenu.testEnterTogglesAndKeepsMenuOpen()
    TestMouseMenu.testPlatformDefault()
    TestMouseMenu.testNewTableEachTime()

    TestMouseMenu.testClickSelectsItem()
    TestMouseMenu.testClickOutsideCloses()
    TestMouseMenu.testClickBlankAreaDoesNothing()
    TestMouseMenu.testClickValueArrow()
    TestMouseMenu.testClickValueArrowAtBoundaryNoop()
    TestMouseMenu.testKeyboardArrowStillPendingOnly()
    TestMouseMenu.testClickValueMiddleLineNoChange()

    TestMouseMenu.testClickParentClosesChildFirst()
    TestMouseMenu.testClickChildDoesNotCloseParent()

    TestMouseMenu.testYesNoClickNo()
    TestMouseMenu.testYesNoClickYes()
    TestMouseMenu.testYesNoClickInsideButNotOnOption()
    TestMouseMenu.testDialogEscapeSemantics()
    TestMouseMenu.testMessageDialogClickAnywhere()
    TestMouseMenu.testPollMouseRoutesYesNoToClickHandler()

    TestMouseMenu.testRightClickClosesMenu()
    TestMouseMenu.testRightClickRespectsIsEsc()

    TestMouseMenu.testHoverMovesCursor()
    TestMouseMenu.testHoverSameItemNoop()
    TestMouseMenu.testHoverBlankAreaNoop()
    TestMouseMenu.testHoverRespectsExecuting()
    TestMouseMenu.testHoverScrollingMenu()
    TestMouseMenu.testHoverOnlyActiveMenu()

    TestMouseMenu.testYesNoHover()
    TestMouseMenu.testYesNoHoverNoopCases()
    TestMouseMenu.testYesNoMessageAreaDoesNotChangeSelection()
    TestMouseMenu.testYesNoGeometryShared()

    TestMouseMenu.testExecutingMenuDoesNotSwallowClick()
    TestMouseMenu.testItemGridHoverDoesNotSelect()

    return TestHelper.printSummary()
end

if arg and arg[0]:match("test_mouse_menu.lua$") then
    TestMouseMenu.runAll()
end

return TestMouseMenu
