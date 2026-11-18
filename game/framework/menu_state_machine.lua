-- menu_state_machine.lua
-- 菜单状态机模块
-- 管理菜单的状态和交互

local MenuStateMachine = {}
MenuStateMachine.__index = MenuStateMachine

-- 值调节项与显示宽度计算需要。
-- Settings 是纯逻辑模块（无引擎依赖），TextBoxLayout 同样（引擎无关纯模块），
-- 引入它们不会让本文件依赖具体引擎。
local Settings = require("framework.settings")
local TextBoxLayout = require("framework.text_box_layout")

-- 菜单状态
local MENU_STATE = {
    IDLE = "idle",           -- 空闲状态
    NAVIGATING = "navigating",  -- 导航状态
    SELECTING = "selecting",    -- 选择状态
    EXECUTING = "executing",    -- 执行菜单项函数
    CLOSING = "closing",        -- 关闭状态
}

-- 动画配置
local ANIMATION_CONFIG = {
    openDuration = 0,       -- 禁用打开动画
    closeDuration = 0,      -- 禁用关闭动画
    selectDuration = 0,     -- 禁用选项切换动画
    enableOpenClose = false, -- 禁用打开/关闭动画
    enableSelect = false,    -- 禁用选项切换动画
}

-- 单例实例
local instance = nil

-- 获取单例
function MenuStateMachine.getInstance()
    if not instance then
        instance = setmetatable({}, MenuStateMachine)
        instance:init()
        instance:_debug("MenuStateMachine: created new instance, id=" .. tostring(instance))
    end
    return instance
end

-- 内部调试方法
function MenuStateMachine:_debug(msg)
    if lib and lib.Debug then
        lib.Debug(msg)
    end
end

--------------------------------------------------------------------
-- 菜单几何（绘制与鼠标命中**共用**，避免两处公式不同步）
-- 见 ADR-MS2-002：命中测试必须与 draw 用同一套行高
--------------------------------------------------------------------

--- 一行的高度（字号 + 行距）
-- @param menu table
-- @return number
local function rowHeight(menu)
    return menu.size + CC.RowPixel
end

--- 第 i 项的绘制起始 Y
--
-- 关键：必须用 `(i - menu.start)`，不是 `(i - 1)`。
-- 滚动菜单（numShow != 0 且 start > 1）时，屏幕第 1 行显示的是
-- newMenu[start]，用错偏移会让点击命中错项。
--
-- @param menu table
-- @param i number 项索引（对应 newMenu 下标）
-- @return number y
local function rowY(menu, i)
    return menu.y1 + CC.MenuBorderPixel + (i - menu.start) * rowHeight(menu)
end

MenuStateMachine._rowHeight = rowHeight
MenuStateMachine._rowY = rowY

-- 初始化
function MenuStateMachine:init()
    self.activeMenu = nil
    self.menuStack = {}
    self.callback = nil
    -- 与 menuStack 一一对应的回调栈。
    --
    -- callback 原先是单槽字段，嵌套菜单时被内层 openMenu 直接覆盖：
    -- 内层关闭后 activeMenu 能从 menuStack 恢复，但外层 callback 永久丢失，
    -- 于是外层 ShowMenuCoroutine 的 menuClosed 永远等不到置位，
    -- `while not menuClosed do scheduler:yield("menu") end` 永久挂起。
    -- 事件协程因此永不结束 → JY.CurrentD 停在触发事件的 tile 编号（不复位 -1）
    -- → GAME_SMAP.update 的 `not (JY.CurrentD >= 0)` 守卫恒为假
    -- → 玩家按键全部被吞，表现为「对话结束后键盘无响应」。
    self.callbackStack = {}
end

-- 创建菜单数据
function MenuStateMachine:createMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    -- 过滤可显示的菜单项
    local newMenu = {}
    local newNumItem = 0
    for i = 1, numItem do
        if menuItem[i][3] > 0 then
            newNumItem = newNumItem + 1
            newMenu[newNumItem] = {menuItem[i][1], menuItem[i][2], menuItem[i][3], i}
        end
    end

    -- 值项初始化待定值（REQ-MENU-1）
    --
    -- pending 存**在描述符上**，所以描述符必须由调用方每次新建
    -- （audio_menu.buildVolumeMenu 每次返回新表）。
    -- 从 Settings.get 起步：进入界面时显示的就是当前真实值。
    for i = 1, newNumItem do
        local desc = newMenu[i][2]
        if type(desc) == "table" and desc.kind == "number" and desc.pending == nil then
            desc.pending = Settings.get(desc.key) or desc.min or 0
        end
    end

    -- 计算实际显示项数
    local num = numShow
    if numShow == 0 or numShow > newNumItem then
        num = newNumItem
    end
    
    -- 计算尺寸
    local w, h
    local maxlength = 0
    if x2 == 0 and y2 == 0 then
        -- 宽度分两条分支（ADR-AS-009）：
        --
        --   值项      → 按**显示宽度**算（汉字 1.0em / ASCII 0.5em）
        --   既有菜单  → 保持原来的 string.len 语义，**一个像素都不改**
        --
        -- 为什么不一并修：string.len 是 UTF-8 字节数，中文框会被算宽约 4.5 倍。
        -- 但 ShowMenu 影响全游戏 20+ 个菜单，全局改会改变它们的所有视觉尺寸，
        -- 超出本 change 边界。值项必然含中文（音乐音量 64/128），所以只给它
        -- 用正确的度量。
        local maxwidth = 0
        local hasValueItem = false
        for i = 1, newNumItem do
            local desc = newMenu[i][2]
            local isValue = type(desc) == "table" and desc.kind == "number"
            if isValue then hasValueItem = true end
            if isValue then
                -- 多行文本取最长行；format 需要 pending 才有意义
                local text = newMenu[i][1] or ""
                if type(desc.format) == "function" then
                    local ok, rendered = pcall(desc.format, desc.pending)
                    if ok and type(rendered) == "string" then text = rendered end
                end
                for line in (text .. "\n"):gmatch("(.-)\n") do
                    local wLine = TextBoxLayout.textWidth(line, size)
                    if wLine > maxwidth then maxwidth = wLine end
                end
            else
                if string.len(newMenu[i][1]) > maxlength then
                    maxlength = string.len(newMenu[i][1])
                end
            end
        end
        if hasValueItem then
            local byteWidth = size * maxlength / 2
            if maxwidth > byteWidth then
                w = maxwidth + 2 * CC.MenuBorderPixel
            else
                w = byteWidth + 2 * CC.MenuBorderPixel
            end
        else
            w = size * maxlength / 2 + 2 * CC.MenuBorderPixel
        end
        -- 值项是三行文本，高度按行数算
        local lineCount = 1
        if hasValueItem then lineCount = 3 end
        h = (size + CC.RowPixel) * num * lineCount + CC.MenuBorderPixel
    else
        w = x2 - x1
        h = y2 - y1
    end
    
    -- 确定初始选中项
    local current = 1
    for i = 1, newNumItem do
        if newMenu[i][3] == 2 then
            current = i
            break
        end
    end
    if numShow ~= 0 then
        current = 1
    end
    
    return {
        newMenu = newMenu,
        newNumItem = newNumItem,
        num = num,
        start = 1,
        current = current,
        x1 = x1,
        y1 = y1,
        w = w,
        h = h,
        isBox = isBox,
        isEsc = isEsc,
        size = size,
        color = color,
        selectColor = selectColor,
        state = MENU_STATE.IDLE,
        returnValue = 0,
        animationTime = 0,
        animationState = "opening",  -- opening, open, closing
        -- 选项切换动画
        prevCurrent = current,     -- 上一个选中项
        selectAnimationTime = 0,   -- 选项切换动画时间
        selectAnimationProgress = 0,  -- 选项切换动画进度
    }
end

-- 打开菜单
function MenuStateMachine:openMenu(menuData, callback)
    self:_debug("MenuStateMachine:openMenu called, self=" .. tostring(self) .. ", activeMenu before=" .. tostring(self.activeMenu))
    
    -- 如果有活动的菜单，先暂停（菜单与回调必须成对压栈）
    if self.activeMenu then
        table.insert(self.menuStack, self.activeMenu)
        self.callbackStack = self.callbackStack or {}
        table.insert(self.callbackStack, self.callback)
    end
    
    self.activeMenu = menuData
    self.callback = callback
    self.activeMenu.state = MENU_STATE.NAVIGATING
    
    -- 处理打开动画
    if ANIMATION_CONFIG.enableOpenClose then
        self.activeMenu.animationState = "opening"
        self.activeMenu.animationTime = 0
    else
        self.activeMenu.animationState = "open"
        self.activeMenu.animationTime = ANIMATION_CONFIG.openDuration
    end
    
    self:_debug("MenuStateMachine:openMenu: activeMenu after=" .. tostring(self.activeMenu))
end

-- 关闭菜单
function MenuStateMachine:closeMenu(returnValue)
    if not self.activeMenu then
        return
    end
    
    self:_debug("MenuStateMachine:closeMenu called, returnValue=" .. tostring(returnValue))
    
    self.activeMenu.returnValue = returnValue or 0
    self.activeMenu.state = MENU_STATE.CLOSING
    
    -- 处理关闭动画
    if ANIMATION_CONFIG.enableOpenClose then
        self.activeMenu.animationState = "closing"
        self.activeMenu.animationTime = 0
    else
        -- 禁用动画时立即关闭
        self:doCloseMenu()
    end
end

-- 更新菜单
function MenuStateMachine:update(dt)
    if not self.activeMenu then
        return
    end
    
    local menu = self.activeMenu
    
    -- 处理打开/关闭动画
    if menu.animationState == "opening" then
        menu.animationTime = menu.animationTime + dt
        if menu.animationTime >= ANIMATION_CONFIG.openDuration then
            menu.animationState = "open"
            menu.animationTime = ANIMATION_CONFIG.openDuration
        end
    elseif menu.animationState == "closing" then
        menu.animationTime = menu.animationTime + dt
        if menu.animationTime >= ANIMATION_CONFIG.closeDuration then
            self:doCloseMenu()
            return
        end
    end
    
    -- 只有在 open 状态才处理输入
    if menu.animationState ~= "open" then
        return
    end
    
    -- 处理选项切换动画
    if ANIMATION_CONFIG.enableSelect and menu.selectAnimationProgress < 1 then
        menu.selectAnimationTime = menu.selectAnimationTime + dt
        menu.selectAnimationProgress = math.min(menu.selectAnimationTime / ANIMATION_CONFIG.selectDuration, 1)
    end
    
    -- 回调协程执行中：只轮询结果，不处理输入（避免重复触发菜单项）
    if menu.state == MENU_STATE.EXECUTING then
        self:pollCallback()
        return
    end

    -- 处理输入
    self:handleInput()
end

--------------------------------------------------------------------
-- 鼠标命中测试（REQ-MS2-2）
--
-- 全部是**纯几何计算**，不依赖状态机实例，可脱离渲染完全单测。
-- 行高与绘制共用 rowY / rowHeight，杜绝两处公式不同步。
--------------------------------------------------------------------

--- 判断点是否落在菜单矩形内（含边框）
-- @param menu table
-- @param x, y number 鼠标坐标（逻辑坐标）
-- @return boolean
function MenuStateMachine.hitMenu(menu, x, y)
    if not menu then return false end
    return x >= menu.x1 and x <= menu.x1 + menu.w
       and y >= menu.y1 and y <= menu.y1 + menu.h
end

--- 返回点命中的菜单项下标（对应 newMenu 的下标，1-based）
--
-- 返回 nil 有两种情况，调用方需区分：
--   * 点在菜单外        → 关闭菜单
--   * 点在菜单内空白区  → 无动作（不关闭）
--
-- @param menu table
-- @param x, y number
-- @return number|nil
function MenuStateMachine.hitItem(menu, x, y)
    if not MenuStateMachine.hitMenu(menu, x, y) then
        return nil
    end
    if menu.isHorizontal then
        -- 横向菜单：按列均分
        local itemWidth = menu.w / menu.num
        for i = menu.start, menu.start + menu.num - 1 do
            if i > menu.newNumItem then break end
            local colX = menu.x1 + CC.MenuBorderPixel
                + (i - menu.start) * itemWidth
            if x >= colX and x < colX + itemWidth then
                return i
            end
        end
        return nil
    end

    -- 注意：每个项占的行数**不一样**。
    --
    -- 普通项占 1 行；值项（kind == "number"）是三行文本
    -- （▲ / 值 / ▼，见 audio_menu.buildThreeLine），占 3 行。
    -- 若一律按 1 行算，值项的第 3 行（▼）会落到下一项的位置，
    -- 导致「点 ▼ 没反应」或「点错项」—— 这是实测踩到的缺陷。
    --
    -- 因此这里按累计高度遍历，不能用 rowY(menu, i) 直接算
    -- （rowY 假设每项 1 行）。
    local rh = rowHeight(menu)
    local yCursor = menu.y1 + CC.MenuBorderPixel
    for i = menu.start, menu.start + menu.num - 1 do
        if i > menu.newNumItem then break end
        local item = menu.newMenu[i]
        local desc = item and item[2]
        local rows = 1
        if type(desc) == "table" and desc.kind == "number" then
            rows = 3
        end
        local itemH = rh * rows
        if y >= yCursor and y < yCursor + itemH then
            return i
        end
        yCursor = yCursor + itemH
    end
    return nil
end

--- 值项的三行布局：判断点命中第几行
--
-- 值项把 `▲ / 值 / ▼` 拼成三行文本（见 audio_menu.buildThreeLine）。
-- @param menu table
-- @param itemIndex number 该值项的下标
-- @param x, y number
-- @return number|nil 1=▲ 2=中间值行 3=▼；nil = 不在该值项内
function MenuStateMachine.hitValueLine(menu, itemIndex, x, y)
    if not menu then return nil end
    local rh = rowHeight(menu)

    -- 累计到该值项的起始 Y（前面可能有普通项占 1 行、其他值项占 3 行）
    local y0 = menu.y1 + CC.MenuBorderPixel
    for i = menu.start, itemIndex - 1 do
        if i > menu.newNumItem then break end
        local item = menu.newMenu[i]
        local desc = item and item[2]
        local rows = 1
        if type(desc) == "table" and desc.kind == "number" then
            rows = 3
        end
        y0 = y0 + rh * rows
    end

    if y < y0 or y >= y0 + rh * 3 then
        return nil
    end
    local line = math.floor((y - y0) / rh) + 1
    if line < 1 then line = 1 end
    if line > 3 then line = 3 end
    return line
end

-- 处理输入
function MenuStateMachine:handleInput()
    if not self.activeMenu then
        return
    end

    -- 回调执行期间不接受输入
    if self.activeMenu.state == MENU_STATE.EXECUTING then
        return
    end
    
    local menu = self.activeMenu
    
    if menu.animationState ~= "open" and menu.animationState ~= "opening" then
        return
    end
    
    local key = lib.GetKey()
    if key == -1 then
        return
    end
    
    -- 处理ESC键
    if key == VK_ESCAPE then
        if menu.isEsc == 1 then
            self:closeMenu(0)
            return
        end
    end

    -- 值项（REQ-MENU-1）：上下键只改「待定值」，确认键才提交
    --
    -- 为什么必须有待定值：
    --   直接把每次上下键写进设置会让误触/连按立即改变音量，
    --   而且无法整体撤销（声音已经变了）。需求方明确要求「按下确认才执行」。
    --
    -- 因此这里的三条规则：
    --   ▲/▼        只改 desc.pending，不调用 Settings.set
    --   Enter/Space 提交（唯一的副作用点）并关闭菜单
    --   ESC         由上面的 isEsc 分支 closeMenu(0)，pending 自然丢弃
    --
    -- 注意：待定值存在描述符上，所以 audio_menu 每次构建必须返回新表。
    if menu.newNumItem == 1 and menu.current == 1 then
        local valueItem = menu.newMenu[1]
        local desc = valueItem and valueItem[2]
        if type(desc) == "table" and desc.kind == "number" then
            if key == VK_UP or key == VK_DOWN then
                local step = desc.step or 1
                if key == VK_DOWN then step = -step end
                local v = (desc.pending or 0) + step
                local lo = desc.min or 0
                local hi = desc.max or 100
                -- 钳制，不回绕：环绕对鼠标点击反直觉，且按住会无限转圈
                if v < lo then v = lo end
                if v > hi then v = hi end
                desc.pending = v
                return
            elseif key == VK_SPACE or key == VK_RETURN then
                -- 唯一的提交点：写 user 层并触发 onChange → 引擎应用音量
                Settings.set(desc.key, desc.pending)
                self:closeMenu(valueItem[4])
                return
            end
        end
    end

    -- 处理方向键
    if key == VK_DOWN then
        menu.prevCurrent = menu.current
        menu.current = menu.current + 1
        if menu.current > (menu.start + menu.num - 1) then
            menu.start = menu.start + 1
        end
        if menu.current > menu.newNumItem then
            menu.start = 1
            menu.current = 1
        end
    elseif key == VK_UP then
        menu.prevCurrent = menu.current
        menu.current = menu.current - 1
        if menu.current < menu.start then
            menu.start = menu.start - 1
        end
        if menu.current < 1 then
            menu.current = menu.newNumItem
            menu.start = menu.current - menu.num + 1
        end
    elseif key == VK_LEFT then
        menu.current = menu.current - 1
        if menu.current < 1 then
            menu.current = menu.newNumItem
        end
        if menu.current < menu.start then
            menu.start = menu.current
        end
    elseif key == VK_RIGHT then
        menu.current = menu.current + 1
        if menu.current > menu.newNumItem then
            menu.current = 1
        end
        if menu.current > (menu.start + menu.num - 1) then
            menu.start = menu.current - menu.num + 1
        end
    elseif key == VK_SPACE or key == VK_RETURN then
        self:selectMenuItem()
    elseif key == VK_Y then
        if menu.newNumItem >= 1 then
            menu.current = 1
            self:selectMenuItem()
        end
    elseif key == VK_N then
        if menu.newNumItem >= 2 then
            menu.current = 2
            self:selectMenuItem()
        end
    end

    -- onCursorChange 钩子（REQ-MENU-2）
    --
    -- 纯通知：光标换行后告诉调用方「从哪到哪」，组件不因它改变任何状态。
    -- 未注册的菜单（既有 20+ 个）零影响。
    --
    -- 明确约束：本钩子**不用于音量变更**。「按键即改音量」会让误触/连按
    -- 瞬间把音量推到极端值且无法撤销 —— 音量只走值项的确认键
    -- （见本函数上方的值项分支）。
    --
    -- 用 pcall 包裹：钩子抛错不得中断主循环（与 globalDrawCallback 一致）。
    if menu.onCursorChange and menu.current ~= menu.prevCurrent then
        local ok, err = pcall(menu.onCursorChange, menu,
            menu.current, menu.prevCurrent)
        if not ok then
            self:_debug("onCursorChange 钩子抛错: " .. tostring(err))
        end
    end
end

-- 选择菜单项
--
-- 回调必须在【独立协程】里执行，不能在本函数（主线程）里直接调用。
--
-- 原版 ShowMenu 是阻塞式的，菜单回调里可以任意写 TalkEx / SelectThing /
-- lib.Delay 这类会「等玩家输入」的调用——因为整个原版事件循环本来就是阻塞的。
-- newevent 脚本正是这么用的，例如
-- script/newevent/scene_1_event_19.lua（韦大宝）：
--     ShowMenu({ {"典当服务", Menu_Sale, 1}, ... })
--     Menu_Sale() → SelectThing(thing, thingnum) → yield
--
-- 本项目的 update() 跑在主线程上，主线程不能 yield。直接调用回调会抛
--   framework/coroutine_scheduler.lua:130: Cannot yield from outside a coroutine
-- 这正是「选『典当』报错」的根因。
--
-- 因此这里改为：把回调扔进调度器协程执行，菜单进入 EXECUTING 状态；
-- 每帧 update() 轮询协程是否结束，结束后再按原版语义收尾：
--   回调返回 1     → closeMenu(-item[4])（原版 returnValue = -newMenu[current][4]）
--   回调返回其它   → 重绘本菜单，继续导航
function MenuStateMachine:selectMenuItem()
    local menu = self.activeMenu
    local item = menu.newMenu[menu.current]

    if not item then
        return
    end

    -- 没有回调：直接返回选中项
    if not item[2] then
        self:closeMenu(item[4])
        return
    end

    menu.state = MENU_STATE.EXECUTING
    menu.pendingCallback = item
    menu.callbackResult = nil
    menu.callbackDone = false

    local CoroutineScheduler = require("framework.coroutine_scheduler")
    local scheduler = CoroutineScheduler.getInstance()
    local currentItem = item
    local menuRef = menu

    local co = scheduler:create(function()
        return currentItem[2](menuRef.newMenu, menuRef.current)
    end, "menu_callback")

    -- 记录到菜单上，供 update() 轮询
    menu.callbackCo = co
    scheduler:start(co)
end

-- 轮询菜单回调协程的结果（由 update() 每帧调用）
function MenuStateMachine:pollCallback()
    local menu = self.activeMenu
    if not menu or not menu.callbackCo then
        return
    end

    local CoroutineScheduler = require("framework.coroutine_scheduler")
    local scheduler = CoroutineScheduler.getInstance()

    if scheduler:isActive(menu.callbackCo) then
        return    -- 回调仍在跑（可能正在等玩家输入）
    end

    -- 协程已结束，取出返回值
    local result = scheduler:getResult(menu.callbackCo)
    local item = menu.pendingCallback
    menu.callbackCo = nil
    menu.pendingCallback = nil
    menu.state = MENU_STATE.NAVIGATING

    if menu ~= self.activeMenu then
        return    -- 回调期间菜单已被换掉，不做事
    end

    if result == 1 then
        self:closeMenu(-item[4])
        return
    end

    -- 子菜单关闭，重绘当前菜单
    Cls(menu.x1, menu.y1, menu.x1 + menu.w, menu.y1 + menu.h)
    if menu.isBox == 1 then
        DrawBox(menu.x1, menu.y1, menu.x1 + menu.w, menu.y1 + menu.h, C_WHITE)
    end
end

--------------------------------------------------------------------
-- 鼠标点击分发（REQ-MS2-2 / REQ-MS2-3）
--
-- 核心原则（ADR-MS2-001）：鼠标点击只做「翻译成已有键盘语义」，
-- 不引入第二套选中逻辑。这样协程隔离、菜单栈恢复、值项待定值语义
-- 全部自动继承。
--------------------------------------------------------------------

-- 点击某一行的等价动作：光标移过去 + 触发选中（等价 Keyboard 的 Enter）
function MenuStateMachine:_clickRow(menu, itemIndex)
    if not menu or not itemIndex then return end
    local item = menu.newMenu[itemIndex]
    if not item then return end

    menu.current = itemIndex
    self:selectMenuItem()
end

-- 点击值项的 ▲/▼：**立即生效**（与键盘的「待定 + 确认」不同）
--
-- 为什么鼠标要立即生效，而键盘不（用户实测反馈）：
--
--   键盘：按住方向键会连发，若每发都写设置，音量会一路冲到底且无法整体撤销，
--         所以键盘维持 ADR-AS-002 的「▲/▼ 只改 pending，Enter 才提交」。
--
--   鼠标：一次点击是一个**离散且明确**的动作，玩家点一下就是要动一格。
--         旧实现让 _clickValueArrow 只改 pending 不写设置，结果是
--         数字在变、**声音不变** —— 用户反馈「点击没有响应」正是这个原因。
--         （实测：点一次 ▲，pending 64→65，Settings 仍 64，音量不动。）
--
--   所以这里额外调用 Settings.set：
--     * onChange → audio_settings → 引擎 setVolume，声音立即变
--     * desc.pending 同步更新，保证 Enter 提交的是同一个值、显示也一致
--
--   副作用是「点完按 ESC 也无法撤销」（声音已经变了）。这是刻意的取舍：
--   鼠标点击的可撤销性远不如键盘连发重要，且玩家点箭头时期望的就是立刻听到。
--
-- 严谨性：本函数**只被鼠标点击路径调用**（handleMouseClick 的两处），
-- 键盘路径走 handleInput 里的独立分支，不受此处影响。
function MenuStateMachine:_clickValueArrow(menu, itemIndex, direction)
    local item = menu.newMenu[itemIndex]
    if not item then return end
    local desc = item[2]
    if type(desc) ~= "table" or desc.kind ~= "number" then return end

    local step = desc.step or 1
    if direction < 0 then step = -step end
    local v = (desc.pending or 0) + step
    local lo = desc.min or 0
    local hi = desc.max or 100
    if v < lo then v = lo end
    if v > hi then v = hi end

    -- 到达边界时值没变，就不必写设置（避免无意义的 onChange 与写盘）
    local old = desc.pending
    desc.pending = v
    if v ~= old and desc.key then
        local ok, err = pcall(Settings.set, desc.key, v)
        if not ok then
            -- 设置写入失败不应让点击崩掉：pending 已更新，显示仍然正确
            self:_debug("_clickValueArrow: Settings.set 失败: " .. tostring(err))
        end
    end
end

--- 逐层关闭菜单，直到菜单栈深度为 depth
--
-- **不能**用 clear() 一把清空：那会丢失所有回调，
-- 而 ShowMenuCoroutine 里的 `while not menuClosed do yield end`
-- 会永久挂起（MenuStateMachine:clear 的注释里已记录这个教训）。
-- 必须逐层 doCloseMenu()，让每层的回调都触发。
--
-- @param depth number 目标深度（栈内保留的菜单数）
function MenuStateMachine:popToDepth(depth)
    local guard = 0
    while #self.menuStack > depth and self.activeMenu do
        guard = guard + 1
        if guard > 16 then
            self:_debug("popToDepth: 超过 16 层，强制停止（可能回调又开了新菜单）")
            break
        end
        self:closeMenu(0)
        -- closeMenu 在动画禁用时立即 doCloseMenu，activeMenu 已恢复为父菜单
        if self.activeMenu and self.activeMenu.state == MENU_STATE.EXECUTING then
            -- 回调协程还在跑，等它结束再继续（避免重入）
            break
        end
    end
end

--- 鼠标悬停：把光标移到所指的项上（REQ-MS2-11）
--
-- 设计取舍（用户问：直接选中 vs 额外画一个悬停效果）：
--
--   选「直接移动光标」，不新增视觉状态。理由：
--     ① 键盘选中已经有一套完整效果（颜色 + 值项预览 + 滚动跟随），
--        再画一层「悬停高亮」就有两套指示，玩家不知道哪个是真的
--     ② 多级菜单天然正确：只有 activeMenu 会被绘制和命中测试，
--        父菜单虽然还在 menuStack 里，但不会响应悬停
--     ③ 实现复用：只改 menu.current，draw 与 onCursorChange 全部自动跟上
--
-- **只移动光标，不触发选中**（那会变成「鼠标一划过就执行菜单命令」）。
-- 触发仍由左键点击负责（handleMouseClick → _clickRow → selectMenuItem）。
--
-- @param x, y number 屏幕坐标
-- @return boolean 是否需要重绘（光标真的移动了）
function MenuStateMachine:hoverAt(x, y)
    local menu = self.activeMenu
    if not menu then return false end

    -- 回调执行期间不接受悬停（与 handleInput / handleMouseClick 一致）
    --
    -- 这不是形式主义：菜单回调里常写 `menu[current]` 来改写自身文本
    -- （例如音量项、鼠标开关），若悬停在这期间改了 current，
    -- 回调就会改错行。
    if menu.state == MENU_STATE.EXECUTING then
        return false
    end
    if menu.animationState ~= "open" and menu.animationState ~= "opening" then
        return false
    end

    local hit = MenuStateMachine.hitItem(menu, x, y)
    if not hit or hit == menu.current then
        return false    -- 空白区或已在该项上：不重绘
    end

    -- 与方向键完全相同的收尾：记录旧位置 → 改 current → 必要时滚动
    menu.prevCurrent = menu.current
    menu.current = hit

    -- 滚动跟随（与 VK_DOWN / VK_UP 的处理一致）
    if menu.current > (menu.start + menu.num - 1) then
        menu.start = menu.current - menu.num + 1
    elseif menu.current < menu.start then
        menu.start = menu.current
    end

    -- 复用同一个 onCursorChange 钩子，让注册过的菜单得到一致通知。
    -- 该钩子只做纯通知（不用于音量，见 ADR-AS-008），所以悬停调用它安全。
    if menu.onCursorChange and menu.current ~= menu.prevCurrent then
        local ok, err = pcall(menu.onCursorChange, menu,
            menu.current, menu.prevCurrent)
        if not ok then
            self:_debug("onCursorChange 钩子抛错（悬停）: " .. tostring(err))
        end
    end

    return true
end

--- 鼠标左键点击的总入口
--
-- 处理优先级（ADR-MS2-003）：
--   ① 点在最内层菜单的项上   → 选中该项
--   ② 点在某层父菜单的项上   → 先关闭更内层的菜单，再选中父菜单那一项
--   ③ 点在所有菜单之外       → 关闭最内层（等价 ESC）
--   ④ 点在菜单内空白区       → 无动作
--
-- @param x, y number 鼠标坐标（逻辑坐标）
-- @return boolean 是否处理了（false = 没有菜单，调用方可另作处理）
function MenuStateMachine:handleMouseClick(x, y)
    local menu = self.activeMenu
    if not menu then return false end

    -- 回调执行期间不接受点击（与 handleInput 一致）
    if menu.state == MENU_STATE.EXECUTING then
        return true
    end
    if menu.animationState ~= "open" and menu.animationState ~= "opening" then
        return true
    end

    -- ① 最内层
    local hit = MenuStateMachine.hitItem(menu, x, y)
    if hit then
        local item = menu.newMenu[hit]
        local desc = item and item[2]
        if type(desc) == "table" and desc.kind == "number" then
            local line = MenuStateMachine.hitValueLine(menu, hit, x, y)
            if line == 1 then
                self:_clickValueArrow(menu, hit, 1)
                return true
            elseif line == 3 then
                self:_clickValueArrow(menu, hit, -1)
                return true
            elseif line == 2 then
                -- 点中间值行：无动作（避免误触改值）
                return true
            end
        end
        self:_clickRow(menu, hit)
        return true
    end

    -- ② 父菜单（由内向外）
    for depth = #self.menuStack, 1, -1 do
        local parent = self.menuStack[depth]
        local parentHit = MenuStateMachine.hitItem(parent, x, y)
        if parentHit then
            -- 先关到只剩 depth-1 层，让 parent 成为 activeMenu
            self:popToDepth(depth - 1)
            if self.activeMenu == parent then
                self:_clickRow(parent, parentHit)
            else
                -- 回调期间换掉了菜单，放弃本次点击
                self:_debug("handleMouseClick: 父菜单切换期间被替换，忽略点击")
            end
            return true
        end
    end

    -- ③ 所有菜单之外 → 关闭最内层（等价 ESC）
    if MenuStateMachine.hitMenu(menu, x, y) then
        -- 在菜单矩形内但没命中任何项（空白区）→ 无动作
        return true
    end
    self:closeMenu(0)
    return true
end

-- 执行关闭
function MenuStateMachine:doCloseMenu()
    if not self.activeMenu then
        return
    end
    
    self:_debug("MenuStateMachine:doCloseMenu called, returnValue=" .. tostring(self.activeMenu.returnValue))
    
    local returnValue = self.activeMenu.returnValue
    
    -- 清理当前菜单区域
    Cls(self.activeMenu.x1, self.activeMenu.y1, 
        self.activeMenu.x1 + self.activeMenu.w + 1, 
        self.activeMenu.y1 + self.activeMenu.h + 1, 0, 1)
    
    -- 本菜单的回调（回调属于「刚关闭的这层」，必须在恢复上层之前取出）
    local closingCallback = self.callback

    -- 恢复上一个菜单（如果有）——回调与菜单同步出栈
    if #self.menuStack > 0 then
        self.activeMenu = table.remove(self.menuStack)
        self.callback = self.callbackStack and table.remove(self.callbackStack) or nil
    else
        self.activeMenu = nil
        self.callback = nil
    end
    
    -- 调用回调
    if closingCallback then
        closingCallback(returnValue)
    end
end

-- 渲染菜单
function MenuStateMachine:draw()
    if not self.activeMenu then
        return
    end
    
    local menu = self.activeMenu

    -- 回调执行期间不绘制菜单。
    --
    -- 原版 ShowMenu 是阻塞实现：选中某项后菜单已完全关闭，回调
    -- （Menu_Sale / Menu_Task / Menu_Go …）是在「屏幕上没有菜单」的状态下跑的。
    -- 本项目把回调交给 menu_callback 协程异步执行，菜单对象仍然存活，
    -- 于是出现这条链路：
    --
    --   外层菜单（典当/地下市场/佣兵行会/瞬息千里）selectMenuItem
    --     → callbackCo 被设置，回调 Menu_Task 在协程里跑
    --     → Menu_Task 内部再 ShowMenu(3 项) → openMenu 把外层压进 menuStack
    --     → 内层关闭时 doCloseMenu 从 menuStack 恢复外层为 activeMenu
    --     → Menu_Task 继续执行 WarMain，战斗全程外层菜单都在 activeMenu
    --
    -- 结果就是「进入战斗后韦大宝的选项单仍显示在战斗画面上」。
    --
    -- 判据用 menu.callbackCo：它由 selectMenuItem（设置）与 pollCallback
    -- （清除）这对事件点维护，生命周期天然成对，draw 只需读字段——
    -- 不遍历协程、不依赖调度器，等价于原版「回调运行时菜单已关闭」的语义。
    if menu.callbackCo then
        return
    end
    
    -- 只有在 open 状态才绘制
    if menu.animationState ~= "open" then
        return
    end
    
    -- 绘制边框
    if menu.isBox == 1 then
        DrawBox(menu.x1, menu.y1, menu.x1 + menu.w, menu.y1 + menu.h, C_WHITE)
    end
    
    -- 绘制菜单项
    for i = menu.start, menu.start + menu.num - 1 do
        if i > menu.newNumItem then
            break
        end
        
        local drawColor = menu.color
        if i == menu.current then
            drawColor = menu.selectColor
        end
        
        -- 根据是否是横向菜单选择绘制方式
        if menu.isHorizontal then
            -- 横向布局：菜单项水平排列
            local itemWidth = menu.w / menu.num
            local x = menu.x1 + CC.MenuBorderPixel + (i - menu.start) * itemWidth
            local y = menu.y1 + CC.MenuBorderPixel
            DrawString(x, y, menu.newMenu[i][1], drawColor, menu.size)
        else
            -- 竖向布局：菜单项垂直排列（默认）
            local y = rowY(menu, i)
            local text = menu.newMenu[i][1]
            local desc = menu.newMenu[i][2]
            local isValue = type(desc) == "table" and desc.kind == "number"

            -- 值项文本必须按 **pending** 重算，不能读 Settings.get：
            -- 若读 get，待定值就无从显示（上下键改了却看不到）。
            if isValue and type(desc.format) == "function" then
                local ok, rendered = pcall(desc.format, desc.pending)
                if ok and type(rendered) == "string" then text = rendered end
            elseif isValue then
                text = tostring(desc.pending or 0)
            end

            -- 多行文本项（值项的 ▲/值/▼ 三行）：按 \n 逐行绘制，行高 size+RowPixel
            if type(text) == "string" and text:find("\n", 1, true) then
                local lineY = y
                for line in (text .. "\n"):gmatch("(.-)\n") do
                    DrawString(menu.x1 + CC.MenuBorderPixel, lineY,
                        line, drawColor, menu.size)
                    lineY = lineY + menu.size + CC.RowPixel
                end
            else
                DrawString(menu.x1 + CC.MenuBorderPixel, y, text, drawColor, menu.size)
            end
        end
    end
end

-- 检查是否有活动的菜单
function MenuStateMachine:hasActiveMenu()
    return self.activeMenu ~= nil
end

-- 获取当前菜单
function MenuStateMachine:getCurrentMenu()
    return self.activeMenu
end

-- 清空所有菜单
function MenuStateMachine:clear()
    self:_debug("MenuStateMachine:clear called, activeMenu before=" .. tostring(self.activeMenu))

    -- 先把所有层级的回调都通知掉，再丢弃菜单。
    --
    -- 直接置 nil 会让 ShowMenuCoroutine 里的
    --     while not menuClosed do scheduler:yield("menu") end
    -- 永久挂起（回调永不触发 → menuClosed 永远 false），
    -- 而挂起的那个协程往往就是事件协程，于是 JY.CurrentD 不复位、
    -- GAME_SMAP 永久吞按键。这里按「由内向外」的顺序逐个回调，
    -- 保证每层 ShowMenuCoroutine 都能醒来。
    local pending = {}
    if self.callback then table.insert(pending, self.callback) end
    if self.callbackStack then
        for i = #self.callbackStack, 1, -1 do
            if self.callbackStack[i] then
                table.insert(pending, self.callbackStack[i])
            end
        end
    end

    self.activeMenu = nil
    self.menuStack = {}
    self.callback = nil
    self.callbackStack = {}

    for _, cb in ipairs(pending) do
        local ok, err = pcall(cb, 0)
        if not ok then
            self:_debug("MenuStateMachine:clear callback error: " .. tostring(err))
        end
    end
end

-- 重置
function MenuStateMachine:reset()
    self:clear()
    instance = nil
end

return MenuStateMachine
