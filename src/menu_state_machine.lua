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
        if lib and lib.Debug then
            lib.Debug("MenuStateMachine: created new instance, id=" .. tostring(instance))
        end
    end
    if lib and lib.Debug then
        lib.Debug("MenuStateMachine.getInstance: returning instance id=" .. tostring(instance))
    end
    return instance
end

-- 初始化
function MenuStateMachine:init()
    self.activeMenu = nil       -- 当前活动的菜单
    self.menuStack = {}         -- 菜单堆栈（支持嵌套）
    self.callback = nil         -- 菜单关闭时的回调
    self.keyProcessed = false   -- 标记当前按键是否已处理（防止按键重复导致菜单快速移动）
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
    if lib and lib.Debug then
        lib.Debug("MenuStateMachine:openMenu called, self=" .. tostring(self) .. ", activeMenu before=" .. tostring(self.activeMenu))
    end
    
    -- 如果有活动的菜单，先暂停
    if self.activeMenu then
        table.insert(self.menuStack, self.activeMenu)
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
    
    if lib and lib.Debug then
        lib.Debug("MenuStateMachine:openMenu: activeMenu after=" .. tostring(self.activeMenu))
    end
end

-- 关闭菜单
function MenuStateMachine:closeMenu(returnValue)
    if not self.activeMenu then
        return
    end
    
    if lib and lib.Debug then
        lib.Debug("MenuStateMachine:closeMenu called, returnValue=" .. tostring(returnValue))
    end
    
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
    
    -- 处理输入
    self:handleInput()
end

-- 处理输入
function MenuStateMachine:handleInput()
    if not self.activeMenu then
        return
    end
    
    local menu = self.activeMenu
    
    -- 在打开或正在打开状态都处理输入
    if menu.animationState ~= "open" and menu.animationState ~= "opening" then
        return
    end
    
    local key = lib.GetKey()
    if lib and lib.Debug then
        lib.Debug("MenuStateMachine:handleInput: key=" .. tostring(key))
    end
    
    -- 如果没有按键，重置处理标志
    if key == -1 then
        self.keyProcessed = false
        return
    end
    
    -- 如果当前按键已处理，等待按键释放
    if self.keyProcessed then
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
        -- 启动选项切换动画
        if ANIMATION_CONFIG.enableSelect then
            menu.selectAnimationTime = 0
            menu.selectAnimationProgress = 0
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
        -- 启动选项切换动画
        if ANIMATION_CONFIG.enableSelect then
            menu.selectAnimationTime = 0
            menu.selectAnimationProgress = 0
        end
    elseif key == VK_LEFT then
        -- ShowMenu2使用左右键
        menu.current = menu.current - 1
        if menu.current < 1 then
            menu.current = menu.newNumItem
        end
        if menu.current < menu.start then
            menu.start = menu.current
        end
    elseif key == VK_RIGHT then
        -- ShowMenu2使用左右键
        menu.current = menu.current + 1
        if menu.current > menu.newNumItem then
            menu.current = 1
        end
        if menu.current > (menu.start + menu.num - 1) then
            menu.start = menu.current - menu.num + 1
        end
    elseif key == VK_SPACE or key == VK_RETURN then
        -- 选择菜单项
        self:selectMenuItem()
    end
    
    -- 标记按键已处理，防止重复触发
    self.keyProcessed = true
end

-- 选择菜单项
function MenuStateMachine:selectMenuItem()
    local menu = self.activeMenu
    local item = menu.newMenu[menu.current]
    
    if not item then
        return
    end
    
    -- 如果菜单项有回调函数，执行它
    if item[2] then
        menu.state = MENU_STATE.EXECUTING
        local result = item[2](menu.newMenu, menu.current)
        menu.state = MENU_STATE.NAVIGATING
        
        if result == 1 then
            -- 子菜单返回，关闭当前菜单
            self:closeMenu(-item[4])
            return
        else
            -- 子菜单关闭，重绘当前菜单
            Cls(menu.x1, menu.y1, menu.x1 + menu.w, menu.y1 + menu.h)
            if menu.isBox == 1 then
                DrawBox(menu.x1, menu.y1, menu.x1 + menu.w, menu.y1 + menu.h, C_WHITE)
            end
        end
    else
        -- 没有回调，直接返回选中项
        self:closeMenu(item[4])
    end
end

-- 执行关闭
function MenuStateMachine:doCloseMenu()
    if not self.activeMenu then
        return
    end
    
    if lib and lib.Debug then
        lib.Debug("MenuStateMachine:doCloseMenu called, returnValue=" .. tostring(self.activeMenu.returnValue))
    end
    
    local returnValue = self.activeMenu.returnValue
    
    -- 清理当前菜单区域
    Cls(self.activeMenu.x1, self.activeMenu.y1, 
        self.activeMenu.x1 + self.activeMenu.w + 1, 
        self.activeMenu.y1 + self.activeMenu.h + 1, 0, 1)
    
    -- 恢复上一个菜单（如果有）
    if #self.menuStack > 0 then
        self.activeMenu = table.remove(self.menuStack)
    else
        self.activeMenu = nil
    end
    
    -- 调用回调
    if self.callback then
        self.callback(returnValue)
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
        
        local y = menu.y1 + CC.MenuBorderPixel + (i - menu.start) * (menu.size + CC.RowPixel)
        DrawString(menu.x1 + CC.MenuBorderPixel, y, menu.newMenu[i][1], drawColor, menu.size)
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
    self.activeMenu = nil
    self.menuStack = {}
    self.callback = nil
end

-- 重置
function MenuStateMachine:reset()
    self:clear()
    instance = nil
end

return MenuStateMachine
