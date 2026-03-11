-- menu_async.lua
-- 异步菜单函数
-- 提供非阻塞版本的ShowMenu和ShowMenu2

local MenuAsync = {}

-- 导入菜单状态机
local MenuStateMachine = require("menu_state_machine")

-- 当前活动的菜单回调
local currentCallback = nil

-- 显示菜单（异步版本）
-- 参数与ShowMenu相同，但使用回调返回结果
function MenuAsync.ShowMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor, callback)
    local msm = MenuStateMachine.getInstance()
    
    -- 创建菜单数据
    local menuData = msm:createMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    
    -- 保存回调
    currentCallback = callback
    
    -- 打开菜单
    msm:openMenu(menuData, function(returnValue)
        currentCallback = nil
        if callback then
            callback(returnValue)
        end
    end)
    
    return 0  -- 立即返回，不阻塞
end

-- 显示菜单2（横向菜单，异步版本）
function MenuAsync.ShowMenu2(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor, callback)
    local msm = MenuStateMachine.getInstance()
    
    -- 创建横向菜单数据
    local menuData = msm:createMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    
    -- 标记为横向菜单
    menuData.isHorizontal = true
    
    -- 重新计算尺寸（横向布局）
    local maxlength = 0
    for i = 1, menuData.newNumItem do
        if string.len(menuData.newMenu[i][1]) > maxlength then
            maxlength = string.len(menuData.newMenu[i][1])
        end
    end
    menuData.w = (size * maxlength / 2 + CC.RowPixel) * menuData.num + CC.MenuBorderPixel
    menuData.h = size + 2 * CC.MenuBorderPixel
    
    -- 保存回调
    currentCallback = callback
    
    -- 打开菜单
    msm:openMenu(menuData, function(returnValue)
        currentCallback = nil
        if callback then
            callback(returnValue)
        end
    end)
    
    return 0
end

-- 更新菜单（在love.update中调用）
function MenuAsync.update(dt)
    local msm = MenuStateMachine.getInstance()
    msm:update(dt)
end

-- 渲染菜单（在love.draw中调用）
function MenuAsync.draw()
    local msm = MenuStateMachine.getInstance()
    msm:draw()
end

-- 检查是否有活动的菜单
function MenuAsync.hasActiveMenu()
    local msm = MenuStateMachine.getInstance()
    return msm:hasActiveMenu()
end

-- 关闭当前菜单
function MenuAsync.closeMenu(returnValue)
    local msm = MenuStateMachine.getInstance()
    msm:closeMenu(returnValue)
end

-- 清空所有菜单
function MenuAsync.clear()
    local msm = MenuStateMachine.getInstance()
    msm:clear()
    currentCallback = nil
end

-- 包装为协程版本（用于在协程中同步调用）
function MenuAsync.ShowMenuCoroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    local CoroutineScheduler = require("coroutine_scheduler")
    local scheduler = CoroutineScheduler.getInstance()
    
    -- 创建等待菜单关闭的协程
    local result = nil
    local menuClosed = false
    
    -- 显示菜单
    MenuAsync.ShowMenu(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor, function(returnValue)
        result = returnValue
        menuClosed = true
    end)
    
    -- 等待菜单关闭
    while not menuClosed do
        scheduler:yield("menu")
    end
    
    return result
end

-- 包装ShowMenu2为协程版本
function MenuAsync.ShowMenu2Coroutine(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor)
    local CoroutineScheduler = require("coroutine_scheduler")
    local scheduler = CoroutineScheduler.getInstance()
    
    local result = nil
    local menuClosed = false
    
    MenuAsync.ShowMenu2(menuItem, numItem, numShow, x1, y1, x2, y2, isBox, isEsc, size, color, selectColor, function(returnValue)
        result = returnValue
        menuClosed = true
    end)
    
    while not menuClosed do
        scheduler:yield("menu")
    end
    
    return result
end

return MenuAsync
