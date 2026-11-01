-- menu_state_machine.lua
-- 菜单状态机模块
-- 管理菜单的状态和交互

local MenuStateMachine = {}
MenuStateMachine.__index = MenuStateMachine

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
    
    -- 计算实际显示项数
    local num = numShow
    if numShow == 0 or numShow > newNumItem then
        num = newNumItem
    end
    
    -- 计算尺寸
    local w, h
    local maxlength = 0
    if x2 == 0 and y2 == 0 then
        for i = 1, newNumItem do
            if string.len(newMenu[i][1]) > maxlength then
                maxlength = string.len(newMenu[i][1])
            end
        end
        w = size * maxlength / 2 + 2 * CC.MenuBorderPixel
        h = (size + CC.RowPixel) * num + CC.MenuBorderPixel
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
            local y = menu.y1 + CC.MenuBorderPixel + (i - menu.start) * (menu.size + CC.RowPixel)
            DrawString(menu.x1 + CC.MenuBorderPixel, y, menu.newMenu[i][1], drawColor, menu.size)
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
